import Foundation
import SwiftUI
import Combine

/// Telemetry extensions for communication dashboard events
extension UXTelemetryService {
    /// Log gesture events with velocity and distance tracking
    func logGesture(
        type: String,
        velocity: CGFloat? = nil,
        distance: CGFloat? = nil,
        componentId: String
    ) {
        var metadata: [String: Any] = ["gestureType": type]
        
        if let velocity = velocity {
            metadata["velocity"] = abs(velocity)
        }
        
        if let distance = distance {
            metadata["distance"] = abs(distance)
        }
        
        let eventType: UXEventType
        switch type {
        case "swipe":
            eventType = .metricsCardSwipeGesture
        default:
            eventType = .metricsCardSwipeGesture
        }
        
        logEvent(
            eventType: eventType,
            category: .clickstream,
            componentId: componentId,
            metadata: metadata
        )
    }
    
    /// Log tap rate with sliding window calculation
    func logTapRate(componentId: String, tapCount: Int, timeWindow: TimeInterval) {
        let tapRate = timeWindow > 0 ? Double(tapCount) / timeWindow : 0.0
        
        logEvent(
            eventType: .uiClick,
            category: .clickstream,
            componentId: componentId,
            metadata: [
                "tapCount": tapCount,
                "timeWindow": timeWindow,
                "tapRate": tapRate
            ]
        )
    }
    
    /// Log message velocity viewed event
    func logMessageVelocityViewed(velocity: Double) {
        logEvent(
            eventType: .messageVelocityViewed,
            category: .clickstream,
            componentId: "DashboardView",
            metadata: [
                "velocity": velocity
            ]
        )
    }
    
    /// Log presence distribution viewed event
    func logPresenceDistributionViewed(distribution: [String: Int]) {
        logEvent(
            eventType: .presenceDistributionViewed,
            category: .clickstream,
            componentId: "DashboardView",
            metadata: distribution.mapValues { AnyCodable($0) }
        )
    }
    
    /// Log room activity viewed event
    func logRoomActivityViewed(roomCount: Int, activeParticipants: Int) {
        logEvent(
            eventType: .roomActivityViewed,
            category: .clickstream,
            componentId: "DashboardView",
            metadata: [
                "roomCount": roomCount,
                "activeParticipants": activeParticipants
            ]
        )
    }
    
    /// Log system health viewed event
    func logSystemHealthViewed(component: String, status: String) {
        logEvent(
            eventType: .systemHealthViewed,
            category: .system,
            componentId: component,
            metadata: [
                "status": status
            ]
        )
    }
}

/// Tap rate tracker for monitoring tap frequency
@MainActor
class TapRateTracker {
    private var tapTimestamps: [Date] = []
    private let windowSize = 10 // Last 10 taps
    private let timeWindow: TimeInterval = 5.0 // 5 seconds
    
    func recordTap() {
        let now = Date()
        tapTimestamps.append(now)
        
        // Keep only recent taps
        tapTimestamps = tapTimestamps.filter { now.timeIntervalSince($0) <= timeWindow }
        
        // Limit to window size
        if tapTimestamps.count > windowSize {
            tapTimestamps.removeFirst()
        }
    }
    
    func calculateRate() -> Double {
        guard !tapTimestamps.isEmpty else { return 0.0 }
        
        let now = Date()
        let recentTaps = tapTimestamps.filter { now.timeIntervalSince($0) <= timeWindow }
        
        guard !recentTaps.isEmpty else { return 0.0 }
        
        let oldestTap = recentTaps.first!
        let windowDuration = now.timeIntervalSince(oldestTap)
        
        return windowDuration > 0 ? Double(recentTaps.count) / windowDuration : 0.0
    }
    
    func getTapCount() -> Int {
        let now = Date()
        return tapTimestamps.filter { now.timeIntervalSince($0) <= timeWindow }.count
    }
}
