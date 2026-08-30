import BackgroundTasks
import Flutter
import UIKit
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var appIconChannel: FlutterMethodChannel?
  private var watchSyncChannel: FlutterMethodChannel?
  private let watchSyncManager = WatchSyncManager()
  private let healthRefreshTaskIdentifier = "com.Xinyu.MoodLand.health-refresh"
  private var activeHealthRefreshTask: BGAppRefreshTask?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: healthRefreshTaskIdentifier,
      using: nil
    ) { [weak self] task in
      guard let refreshTask = task as? BGAppRefreshTask else {
        task.setTaskCompleted(success: false)
        return
      }
      self?.handleHealthRefreshTask(refreshTask)
    }
    watchSyncManager.onWatchPayload = { [weak self] payload in
      DispatchQueue.main.async {
        self?.watchSyncChannel?.invokeMethod(
          "watchHealthDataUpdated",
          arguments: payload
        )
      }
    }
    watchSyncManager.activate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "moodland/app_icon",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setAlternateIcon":
        guard UIApplication.shared.supportsAlternateIcons else {
          result(FlutterError(
            code: "UNSUPPORTED",
            message: "Alternate app icons are not supported on this device.",
            details: nil
          ))
          return
        }

        let arguments = call.arguments as? [String: Any]
        let iconName = arguments?["iconName"] as? String
        let nextIconName = iconName?.isEmpty == true ? nil : iconName
        if UIApplication.shared.alternateIconName == nextIconName {
          result(nil)
          return
        }

        DispatchQueue.main.async {
          UIApplication.shared.setAlternateIconName(nextIconName) { error in
            if let error = error {
              result(FlutterError(
                code: "ICON_CHANGE_FAILED",
                message: error.localizedDescription,
                details: nil
              ))
              return
            }
            result(nil)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    appIconChannel = channel

    let syncChannel = FlutterMethodChannel(
      name: "moodland/watch_sync",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    syncChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "syncHealthData":
        guard var payload = call.arguments as? [String: Any] else {
          result(FlutterError(
            code: "INVALID_PAYLOAD",
            message: "Watch health payload is invalid.",
            details: nil
          ))
          return
        }
        payload["source"] = "iphone"

        do {
          try self?.watchSyncManager.sync(payload)
          result(nil)
        } catch {
          result(FlutterError(
            code: "WATCH_SYNC_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
        }
      case "getLatestWatchHealthData":
        result(self?.watchSyncManager.latestWatchPayload)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    watchSyncChannel = syncChannel
  }

  func scheduleHealthRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: healthRefreshTaskIdentifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      // iOS may reject a duplicate or defer scheduling; the next background entry retries.
    }
  }

  private func handleHealthRefreshTask(_ task: BGAppRefreshTask) {
    scheduleHealthRefresh()
    activeHealthRefreshTask?.setTaskCompleted(success: false)
    activeHealthRefreshTask = task

    task.expirationHandler = { [weak self, weak task] in
      guard let self, self.activeHealthRefreshTask === task else { return }
      self.activeHealthRefreshTask = nil
      task?.setTaskCompleted(success: false)
    }

    guard let watchSyncChannel else {
      activeHealthRefreshTask = nil
      task.setTaskCompleted(success: false)
      return
    }
    watchSyncChannel.invokeMethod(
      "backgroundHealthRefreshRequested",
      arguments: nil
    ) { [weak self, weak task] result in
      guard let self, let task, self.activeHealthRefreshTask === task else { return }
      self.activeHealthRefreshTask = nil
      task.setTaskCompleted(success: (result as? Bool) == true)
    }
  }
}

private final class WatchSyncManager: NSObject, WCSessionDelegate {
  private let watchPayloadCacheKey = "moodland.iphone.watch.payload.v2"
  var onWatchPayload: (([String: Any]) -> Void)?

  var latestWatchPayload: [String: Any]? {
    guard let data = UserDefaults.standard.data(forKey: watchPayloadCacheKey),
          let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return value
  }

  private var session: WCSession? {
    WCSession.isSupported() ? .default : nil
  }

  func activate() {
    guard let session else { return }
    session.delegate = self
    session.activate()
  }

  func sync(_ payload: [String: Any]) throws {
    guard let session else { return }
    if session.activationState == .notActivated {
      activate()
    }

    try session.updateApplicationContext(payload)
    if session.isReachable {
      session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {}

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    receiveWatchPayload(applicationContext)
  }

  func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any]
  ) {
    receiveWatchPayload(message)
  }

  func session(
    _ session: WCSession,
    didReceiveUserInfo userInfo: [String: Any] = [:]
  ) {
    receiveWatchPayload(userInfo)
  }

  private func receiveWatchPayload(_ payload: [String: Any]) {
    guard payload["source"] as? String == "watch" else { return }
    if JSONSerialization.isValidJSONObject(payload),
       let data = try? JSONSerialization.data(withJSONObject: payload) {
      UserDefaults.standard.set(data, forKey: watchPayloadCacheKey)
    }
    onWatchPayload?(payload)
  }
}
