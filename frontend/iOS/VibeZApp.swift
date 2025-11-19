import SwiftUI
import UIKit
import Foundation

/// Helper extension to detect UI testing mode
extension ProcessInfo {
    /// Returns true if the app is running in UI testing mode
    static var isUITesting: Bool {
        return ProcessInfo.processInfo.arguments.contains("--uitesting")
    }
    
    /// Returns true if app state should be reset (for UI testing)
    static var shouldResetState: Bool {
        return ProcessInfo.processInfo.environment["RESET_STATE"] == "true"
    }
}

// UI Test Mode Bypass - Hack to keep app open for testing
@available(iOS 17.0, *)
struct UITestAppBypass {
    static func setupIfNeeded() {
        // Check for UI test mode flag
        if CommandLine.arguments.contains("-ui-test-mode") || ProcessInfo.processInfo.arguments.contains("--uitesting") {
            return
        }
    }
}

@main
@available(iOS 17.0, *)
struct VibeZApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    init() {
        // Setup UI test mode bypass if needed
        UITestAppBypass.setupIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingV2()
            }
        }
    }
}
