import Foundation
import Combine
import SwiftUI

/// Global Access Mode Manager
/// Manages network optimization settings for restricted regions.
/// Handles auto-detection of connection failures and user preferences.
@MainActor
class GlobalAccessManager: ObservableObject {
    static let shared = GlobalAccessManager()
    
    // MARK: - Published State
    
    /// Whether Global Access Mode is currently enabled by the user
    @AppStorage("gamEnabled") var isGAMEnabled: Bool = false
    
    /// Whether the system has detected potential network restrictions
    @Published var isRestrictionDetected: Bool = false
    
    /// Connection failure counter for auto-detection
    @Published private(set) var connectionFailureCount: Int = 0
    
    // MARK: - Configuration
    
    private let maxFailuresBeforePrompt = 3
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Initialize detection logic if needed
    }
    
    // MARK: - Public API
    
    /// Toggle Global Access Mode
    func toggleGAM(_ enabled: Bool) {
        isGAMEnabled = enabled
        // Reset failure count when manually toggled
        if enabled {
            connectionFailureCount = 0
            isRestrictionDetected = false
        }
        
        // Log change (Telemetry)
        print("[GAM] Global Access Mode set to: \(enabled)")
    }
    
    /// Report a connection failure to the manager
    /// Triggers detection logic if failures accumulate
    func reportConnectionFailure() {
        connectionFailureCount += 1
        print("[GAM] Connection failure reported. Count: \(connectionFailureCount)")
        
        if connectionFailureCount >= maxFailuresBeforePrompt && !isGAMEnabled {
            isRestrictionDetected = true
        }
    }
    
    /// Report a successful connection
    /// Resets failure counters
    func reportConnectionSuccess() {
        if connectionFailureCount > 0 {
            connectionFailureCount = 0
            print("[GAM] Connection successful. Failure count reset.")
        }
    }
    
    /// Get the recommended ICE transport policy based on GAM state
    /// Returns "relay" if GAM is enabled, otherwise "all"
    var recommendedIceTransportPolicy: String {
        return isGAMEnabled ? "relay" : "all"
    }
    
    /// Get the recommended protocol version
    /// Always prefer modern protocols, but GAM might enforce specific fallbacks in future
    var recommendedProtocolVersion: String {
        return "v9"
    }
    
    /// Check if we should recommend enabling GAM to the user
    var shouldRecommendGAM: Bool {
        return isRestrictionDetected && !isGAMEnabled
    }
    
    /// Dismiss the recommendation (user declined)
    func dismissRecommendation() {
        isRestrictionDetected = false
        // Reset count to avoid immediate re-prompting
        connectionFailureCount = 0
    }
}
