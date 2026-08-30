import SwiftUI
import WatchKit

private let watchHealthRefreshTaskIdentifier = "com.Xinyu.MoodLand.watch-health-refresh"

private func scheduleWatchHealthRefresh() {
    WKApplication.shared().scheduleBackgroundRefresh(
        withPreferredDate: Date(timeIntervalSinceNow: 30 * 60),
        userInfo: watchHealthRefreshTaskIdentifier as NSString
    ) { _ in }
}

@main
struct MoodLandWatchApp: App {
    @StateObject private var healthStore = WatchHealthStore()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(healthStore)
                .task {
                    scheduleWatchHealthRefresh()
                }
        }
        .backgroundTask(.appRefresh(watchHealthRefreshTaskIdentifier)) {
            await healthStore.refreshIfNeeded(minimumInterval: 30 * 60)
            scheduleWatchHealthRefresh()
        }
    }
}
