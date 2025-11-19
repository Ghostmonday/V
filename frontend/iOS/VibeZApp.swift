import SwiftUI

@main
struct VibezApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var guestService = GuestService.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .environmentObject(guestService)
                .preferredColorScheme(.dark)
        }
    }
}
