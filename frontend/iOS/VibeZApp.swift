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
    init() {
        // CHUNK 1: REMOVED everything - testing if init() itself is the problem
        // Empty init to see if app stays open
    }
    
    var body: some Scene {
        WindowGroup {
            // CHUNK 5: Simplest possible - no ProcessInfo checks
            Text("TEST MODE ON - SIMPLEST")
        }
    }
}
