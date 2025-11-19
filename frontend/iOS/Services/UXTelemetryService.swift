import Foundation
import OSLog

/// UX Event Categories
enum UXEventCategory: String, Codable {
    case uiState = "ui_state"
    case clickstream = "clickstream"
    case validation = "validation"
    case system = "system"
    case performance = "performance"
    case voiceAV = "voice_av"
    case messaging = "messaging"
    case engagement = "engagement"
    case emotional = "emotional"
    case presence = "presence"
    case threading = "threading"
    case typing = "typing"
    case featureUse = "feature_use"
    case aiFeedback = "ai_feedback"
    case cognitiveState = "cognitive_state"
    case journeyAnalytics = "journey_analytics"
    case behaviorModeling = "behavior_modeling"
}

/// UX Event Types
enum UXEventType: String, Codable {
    // UI State Events
    case uiStateTransition = "ui_state_transition"
    case uiClick = "ui_click"
    case uiValidationError = "ui_validation_error"
    
    // System Events
    case apiFailure = "api_failure"
    case clientCrash = "client_crash"
    
    // Performance Events
    case latencyBucket = "latency_bucket"
    
    // Voice/AV Events
    case voiceCaptureFailed = "voice_capture_failed"
    
    // Messaging Events
    case messageSendAttempted = "message_send_attempted"
    case messageSendFailed = "message_send_failed"
    
    // Engagement Events
    case roomEntry = "room_entry"
    case roomExit = "room_exit"
    
    // Emotional Events
    case messageSentiment = "message_sentiment"
    
    // Presence Events
    case presencePing = "presence_ping"
    
    // Threading Events
    case threadCreated = "thread_created"
    
    // Typing Events
    case typingStart = "typing_start"
    case typingStop = "typing_stop"
    
    // Feature Use Events
    case screenShareStart = "screen_share_start"
    
    // AI Feedback & Trust Signals
    case aiSuggestionAccepted = "ai_suggestion_accepted"
    case aiSuggestionRejected = "ai_suggestion_rejected"
    case aiAutoFixApplied = "ai_auto_fix_applied"
    case aiEditUndone = "ai_edit_undone"
    case aiHelpRequested = "ai_help_requested"
    case agentHandoffFailed = "agent_handoff_failed"
}

/// UX Telemetry Service
/// Handles logging of UX telemetry events for product observability
@MainActor
class UXTelemetryService {
    static let shared = UXTelemetryService()
    
    private let logger = Logger(subsystem: "com.vibez.app", category: "UXTelemetry")
    private var sessionId: String = UUID().uuidString
    
    private init() {}
    
    // MARK: - Instance Methods
    
    /// Log a generic event
    func logEvent(
        eventType: UXEventType,
        category: UXEventCategory,
        metadata: [String: Any] = [:]
    ) {
        let event: [String: Any] = [
            "eventType": eventType.rawValue,
            "category": category.rawValue,
            "metadata": metadata,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "sessionId": sessionId
        ]
        
        // Log locally
        logger.info("UX Event: \(eventType.rawValue) [\(category.rawValue)]")
        
        // TODO: Send to backend API endpoint /api/ux-telemetry
        Task {
            await sendEventToBackend(event)
        }
    }
    
    // MARK: - Static Convenience Methods
    
    /// Log room entry event
    static func logRoomEntry(roomId: String, metadata: [String: String] = [:]) {
        Task { @MainActor in
            var eventMetadata: [String: Any] = ["roomId": roomId]
            for (key, value) in metadata {
                eventMetadata[key] = value
            }
            shared.logEvent(
                eventType: .roomEntry,
                category: .engagement,
                metadata: eventMetadata
            )
        }
    }
    
    /// Log state transition event
    static func logStateTransition(
        componentId: String,
        stateBefore: String,
        stateAfter: String,
        category: UXEventCategory
    ) {
        Task { @MainActor in
            shared.logEvent(
                eventType: .uiStateTransition,
                category: category,
                metadata: [
                    "componentId": componentId,
                    "stateBefore": stateBefore,
                    "stateAfter": stateAfter
                ]
            )
        }
    }
    
    /// Log typing start event
    static func logTypingStart() {
        Task { @MainActor in
            shared.logEvent(
                eventType: .typingStart,
                category: .typing
            )
        }
    }
    
    /// Log typing stop event
    static func logTypingStop() {
        Task { @MainActor in
            shared.logEvent(
                eventType: .typingStop,
                category: .typing
            )
        }
    }
    
    /// Log API failure event
    static func logAPIFailure(
        endpoint: String,
        statusCode: Int,
        metadata: [String: String] = [:]
    ) {
        Task { @MainActor in
            var eventMetadata: [String: Any] = [
                "endpoint": endpoint,
                "statusCode": String(statusCode)
            ]
            for (key, value) in metadata {
                eventMetadata[key] = value
            }
            shared.logEvent(
                eventType: .apiFailure,
                category: .system,
                metadata: eventMetadata
            )
        }
    }
    
    /// Log click event
    static func logClick(
        componentId: String,
        metadata: [String: Any] = [:]
    ) {
        Task { @MainActor in
            var eventMetadata: [String: Any] = ["componentId": componentId]
            for (key, value) in metadata {
                eventMetadata[key] = value
            }
            shared.logEvent(
                eventType: .uiClick,
                category: .clickstream,
                metadata: eventMetadata
            )
        }
    }
    
    /// Log validation error event
    static func logValidationError(
        componentId: String,
        errorType: String,
        metadata: [String: String] = [:]
    ) {
        Task { @MainActor in
            var eventMetadata: [String: Any] = [
                "componentId": componentId,
                "errorType": errorType
            ]
            for (key, value) in metadata {
                eventMetadata[key] = value
            }
            shared.logEvent(
                eventType: .uiValidationError,
                category: .validation,
                metadata: eventMetadata
            )
        }
    }
    
    /// Log message send attempted event
    static func logMessageSendAttempted(metadata: [String: String] = [:]) {
        Task { @MainActor in
            shared.logEvent(
                eventType: .messageSendAttempted,
                category: .messaging,
                metadata: metadata
            )
        }
    }
    
    /// Log message send failed event
    static func logMessageSendFailed(
        error: String,
        metadata: [String: String] = [:]
    ) {
        Task { @MainActor in
            var eventMetadata: [String: Any] = ["error": error]
            for (key, value) in metadata {
                eventMetadata[key] = value
            }
            shared.logEvent(
                eventType: .messageSendFailed,
                category: .messaging,
                metadata: eventMetadata
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func sendEventToBackend(_ event: [String: Any]) async {
        // TODO: Implement actual backend API call
        // For now, just log locally
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: event)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                logger.debug("Sending UX event: \(jsonString)")
            }
        } catch {
            logger.error("Failed to serialize UX event: \(error.localizedDescription)")
        }
    }
}

