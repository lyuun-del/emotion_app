import SwiftUI

@main
struct MoodLandWatchApp: App {
    @StateObject private var healthStore = WatchHealthStore()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(healthStore)
        }
    }
}
