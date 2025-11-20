import SwiftUI

@main
struct VibezApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var guestService = GuestService.shared
    
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-StressTest") {
                StressTestView()
            } else {
                MainView()
                    .environmentObject(appState)
                    .environmentObject(guestService)
                    .preferredColorScheme(.dark)
            }
        }
    }
}
