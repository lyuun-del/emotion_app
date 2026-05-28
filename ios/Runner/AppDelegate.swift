import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var appIconChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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
  }
}
