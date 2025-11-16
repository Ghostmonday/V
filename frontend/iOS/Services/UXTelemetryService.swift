import Foundation
import UIKit

/// UX Telemetry Service
/// Wraps SystemService with UX telemetry event types
/// Maintains session/trace IDs, batches events, and integrates with rate limiter
@MainActor
class UXTelemetryService {
    static let shared = UXTelemetryService()
    
    private var sessionId: String
    private var eventQueue: [UXTelemetryEvent] = []
    private let batchSize = 10
    private let flushInterval: TimeInterval = 5.0
    private var flushTimer: Timer?
    
    // Sequence tracking
    private var eventSequencePath: [(eventType: String, timestamp: Date)] = []
    
    // Burst detection
    private var recentActions: [Date] = []
    private let burstThreshold = 5
    private let burstWindowSeconds: TimeInterval = 10.0
    
    // Idle detection
    private var lastActivityTime: Date = Date()
    private let idleThresholdSeconds: TimeInterval = 30.0
    private var wasIdle: Bool = false
    
    // State loop detection
    private var stateHistory: [(state: String, timestamp: Date)] = []
    private let stateHistoryLimit = 20
    
    private init() {
        self.sessionId = Self.generateSessionId()
        startFlushTimer()
        setupBackgroundHandlers()
    }
    
    // MARK: - Session Management
    
    private static func generateSessionId() -> String {
        if let stored = UserDefaults.standard.string(forKey: "ux_telemetry_session_id") {
            return stored
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "ux_telemetry_session_id")
        return newId
    }
    
    private static func generateTraceId() -> String {
        return UUID().uuidString
    }
    
    func resetSession() {
        sessionId = Self.generateSessionId()
    }
    
    // MARK: - Background Handlers
    
    private func setupBackgroundHandlers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        flush()
    }
    
    // MARK: - Flush Timer
    
    private func startFlushTimer() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            self?.flush()
        }
    }
    
    func flush() {
        guard !eventQueue.isEmpty else { return }
        
        let batch = eventQueue
        eventQueue.removeAll()
        
        // Send batch to server
        Task {
            await sendBatch(batch)
        }
    }
    
    private func sendBatch(_ events: [UXTelemetryEvent]) async {
        guard let url = URL(string: "\(APIClient.baseURL)/api/ux-telemetry") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(events)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("[UX Telemetry] Batch send failed: HTTP \(httpResponse.statusCode)")
            }
        } catch {
            print("[UX Telemetry] Error sending batch: \(error)")
        }
    }
    
    // MARK: - Activity Tracking
    
    private func trackActivity() {
        let now = Date()
        let timeSinceLastActivity = now.timeIntervalSince(lastActivityTime)
        
        // Check if user was idle and is now active again
        if wasIdle && timeSinceLastActivity < idleThresholdSeconds {
            logEvent(
                eventType: .sessionIdleThenRetry,
                category: .behaviorModeling,
                metadata: ["idleDuration": Int(timeSinceLastActivity * 1000)]
            )
            wasIdle = false
        }
        
        // Update idle status
        if timeSinceLastActivity > idleThresholdSeconds {
            wasIdle = true
        }
        
        lastActivityTime = now
    }
    
    // MARK: - Burst Detection
    
    private func detectBurst() {
        let now = Date()
        
        // Add current action
        recentActions.append(now)
        
        // Remove actions outside the window
        recentActions = recentActions.filter { now.timeIntervalSince($0) < burstWindowSeconds }
        
        // Detect burst
        if recentActions.count >= burstThreshold {
            let burstDuration = now.timeIntervalSince(recentActions.first!)
            logEvent(
                eventType: .userActionBurst,
                category: .behaviorModeling,
                metadata: [
                    "burstCount": recentActions.count,
                    "duration": Int(burstDuration * 1000)
                ]
            )
            // Reset to avoid duplicate burst events
            recentActions.removeAll()
        }
    }
    
    // MARK: - State Loop Detection
    
    private func detectStateLoop(stateBefore: String, stateAfter: String) {
        let now = Date()
        let stateKey = "\(stateBefore)->\(stateAfter)"
        
        // Add to state history
        stateHistory.append((state: stateKey, timestamp: now))
        
        // Keep history limited
        if stateHistory.count > stateHistoryLimit {
            stateHistory.removeFirst()
        }
        
        // Detect loops (same transition occurring 3+ times in short succession)
        let recentWindow = now.addingTimeInterval(-30.0) // 30 seconds
        let recentTransitions = stateHistory.filter { $0.timestamp > recentWindow && $0.state == stateKey }
        
        if recentTransitions.count >= 3 {
            let states = stateHistory
                .filter { $0.timestamp > recentWindow }
                .map { $0.state }
            
            logEvent(
                eventType: .repeatedStateLoopDetected,
                category: .journeyAnalytics,
                metadata: [
                    "loopCount": recentTransitions.count,
                    "statesInLoop": Array(Set(states)),
                    "pattern": stateKey
                ]
            )
            
            // Clear history to avoid duplicate detections
            stateHistory.removeAll()
        }
    }
    
    // MARK: - Core Logging
    
    func logEvent(
        eventType: UXEventType,
        category: UXEventCategory,
        metadata: [String: Any] = [:],
        componentId: String? = nil,
        stateBefore: String? = nil,
        stateAfter: String? = nil,
        userId: String? = nil,
        roomId: String? = nil
    ) {
        // Track activity
        trackActivity()
        
        // Detect bursts for user actions
        if category == .clickstream || category == .uiState {
            detectBurst()
        }
        
        // Detect state loops
        if let before = stateBefore, let after = stateAfter {
            detectStateLoop(stateBefore: before, stateAfter: after)
        }
        
        // Track sequence
        trackSequence(eventType: eventType)
        
        // Create event
        let event = UXTelemetryEvent(
            traceId: Self.generateTraceId(),
            sessionId: sessionId,
            eventType: eventType,
            category: category,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            componentId: componentId,
            stateBefore: stateBefore,
            stateAfter: stateAfter,
            metadata: metadata.mapValues { AnyCodable($0) },
            deviceContext: captureDeviceContext(),
            samplingFlag: false, // Simplified for iOS
            userId: userId,
            roomId: roomId
        )
        
        // Add to queue
        eventQueue.append(event)
        
        // Flush if batch size reached
        if eventQueue.count >= batchSize {
            flush()
        }
    }
    
    private func trackSequence(eventType: UXEventType) {
        eventSequencePath.append((eventType: eventType.rawValue, timestamp: Date()))
        
        // Keep sequence path limited to last 100 events
        if eventSequencePath.count > 100 {
            eventSequencePath.removeFirst()
        }
        
        // Periodically log sequence path
        if eventSequencePath.count % 20 == 0 {
            let recent = eventSequencePath.suffix(20).map {
                ["eventType": $0.eventType, "timestamp": $0.timestamp.timeIntervalSince1970 * 1000]
            }
            logEvent(
                eventType: .eventSequencePath,
                category: .journeyAnalytics,
                metadata: ["sequencePath": recent]
            )
        }
    }
    
    private func captureDeviceContext() -> DeviceContext {
        let screen = UIScreen.main.bounds
        return DeviceContext(
            userAgent: "iOS/\(UIDevice.current.systemVersion)",
            screenWidth: screen.width,
            screenHeight: screen.height,
            viewportWidth: screen.width,
            viewportHeight: screen.height,
            pixelRatio: UIScreen.main.scale,
            platform: UIDevice.current.systemName,
            language: Locale.current.languageCode,
            connectionType: nil,
            timezone: TimeZone.current.identifier
        )
    }
    
    // MARK: - Public API: State Transitions
    
    static func logStateTransition(
        componentId: String,
        stateBefore: String,
        stateAfter: String,
        category: UXEventCategory,
        metadata: [String: Any] = [:]
    ) {
        shared.logEvent(
            eventType: .uiStateTransition,
            category: category,
            metadata: metadata,
            componentId: componentId,
            stateBefore: stateBefore,
            stateAfter: stateAfter
        )
    }
    
    static func logClick(componentId: String, metadata: [String: Any] = [:]) {
        shared.logEvent(
            eventType: .uiClick,
            category: .clickstream,
            metadata: metadata,
            componentId: componentId
        )
    }
    
    static func logValidationError(componentId: String, errorType: String, metadata: [String: Any] = [:]) {
        var meta = metadata
        meta["errorType"] = errorType
        shared.logEvent(
            eventType: .uiValidationError,
            category: .validation,
            metadata: meta,
            componentId: componentId
        )
    }
    
    // MARK: - AI Feedback
    
    static func logAISuggestionAccepted(
        suggestionId: String,
        acceptanceMethod: String,
        metadata: [String: Any] = [:]
    ) {
        var meta = metadata
        meta["suggestionId"] = suggestionId
        meta["acceptanceMethod"] = acceptanceMethod
        shared.logEvent(
            eventType: .aiSuggestionAccepted,
            category: .aiFeedback,
            metadata: meta
        )
    }
    
    static func logAISuggestionRejected(
        suggestionId: String,
        rejectionReason: String? = nil,
        metadata: [String: Any] = [:]
    ) {
        var meta = metadata
        meta["suggestionId"] = suggestionId
        if let reason = rejectionReason {
            meta["rejectionReason"] = reason
        }
        shared.logEvent(
            eventType: .aiSuggestionRejected,
            category: .aiFeedback,
            metadata: meta
        )
    }
    
    static func logAIAutoFixApplied(
        fixType: String,
        outcome: String,
        metadata: [String: Any] = [:]
    ) {
        var meta = metadata
        meta["fixType"] = fixType
        meta["outcome"] = outcome
        shared.logEvent(
            eventType: .aiAutoFixApplied,
            category: .aiFeedback,
            metadata: meta
        )
    }
    
    static func logAIEditUndone(undoLatency: Int, metadata: [String: Any] = [:]) {
        var meta = metadata
        meta["undoLatency"] = undoLatency
        shared.logEvent(
            eventType: .aiEditUndone,
            category: .aiFeedback,
            metadata: meta
        )
    }
    
    static func logAIHelpRequested(contextQuery: String, metadata: [String: Any] = [:]) {
        var meta = metadata
        meta["contextQuery"] = "[REDACTED_QUERY]" // PII scrubbed
        shared.logEvent(
            eventType: .aiHelpRequested,
            category: .aiFeedback,
            metadata: meta
        )
    }
    
    static func logAgentHandoffFailed(
        failureStage: String,
        metadata: [String: Any] = [:]
    ) {
        var meta = metadata
        meta["failureStage"] = failureStage
        shared.logEvent(
            eventType: .agentHandoffFailed,
            category: .aiFeedback,
            metadata: meta
        )
    }
    
    // MARK: - Emotional & Cognitive State
    
    static func logSentiment(
        sentimentScore: Double,
        beforeAfter: String,
        metadata: [String: Any] = [:]
    ) {
        var meta = metadata
        meta["sentimentScore"] = sentimentScore
        let eventType: UXEventType = beforeAfter == "before" ? .messageSentimentBefore : .messageSentimentAfter
        shared.logEvent(
            eventType: eventType,
            category: .cognitiveState,
            metadata: meta
        )
    }
    
    static func logEmotionCurve(
        emotionCurve: [[String: Any]],
        metadata: [String: Any] = [:]
    ) {
        var meta = metadata
        meta["emotionCurve"] = emotionCurve
        shared.logEvent(
            eventType: .sessionEmotionCurve,
            category: .cognitiveState,
            metadata: meta
        )
    }
    
    static func logEmotionContradiction(
        detectedTone: String,
        inferredIntent: String,
        metadata: [String: Any] = [:]
    ) {
        var meta = metadata
        meta["detectedTone"] = detectedTone
        meta["inferredIntent"] = inferredIntent
        shared.logEvent(
            eventType: .messageEmotionContradiction,
            category: .cognitiveState,
            metadata: meta
        )
    }
    
    static func logValidationIrritationScore(
        errorCount: Int,
        retryInterval: Int,
        metadata: [String: Any] = [:]
    ) {
        var meta = metadata
        meta["errorCount"] = errorCount
        meta["retryInterval"] = retryInterval
        shared.logEvent(
            eventType: .validationReactIrritationScore,
            category: .cognitiveState,
            metadata: meta
        )
    }
    
    // MARK: - Journey Analytics
    
    static func logFunnelCheckpoint(checkpointId: String, metadata: [String: Any] = [:]) {
        var meta = metadata
        meta["checkpointId"] = checkpointId
        shared.logEvent(
            eventType: .funnelCheckpointHit,
            category: .journeyAnalytics,
            metadata: meta
        )
    }
    
    static func logDropoffPoint(lastEvent: String, sessionDuration: Int, metadata: [String: Any] = [:]) {
        var meta = metadata
        meta["lastEvent"] = lastEvent
        meta["sessionDuration"] = sessionDuration
        shared.logEvent(
            eventType: .dropoffPointDetected,
            category: .journeyAnalytics,
            metadata: meta
        )
    }
    
    // MARK: - Performance
    
    static func logPerformance(
        perceivedMs: Int,
        actualMs: Int,
        componentId: String? = nil,
        metadata: [String: Any] = [:]
    ) async {
        var meta = metadata
        meta["perceivedMs"] = perceivedMs
        meta["actualMs"] = actualMs
        meta["delta"] = abs(perceivedMs - actualMs)
        shared.logEvent(
            eventType: .loadTimePerceivedVsActual,
            category: .performance,
            metadata: meta,
            componentId: componentId
        )
    }
    
    static func logStutteredInput(retryCount: Int, metadata: [String: Any] = [:]) {
        var meta = metadata
        meta["retryCount"] = retryCount
        shared.logEvent(
            eventType: .stutteredInput,
            category: .performance,
            metadata: meta
        )
    }
    
    static func logLongStateWithoutProgress(
        stateDuration: Int,
        state: String,
        metadata: [String: Any] = [:]
    ) {
        var meta = metadata
        meta["stateDuration"] = stateDuration
        meta["state"] = state
        shared.logEvent(
            eventType: .longStateWithoutProgress,
            category: .performance,
            metadata: meta
        )
    }
    
    // MARK: - Behavior Modeling
    
    static func logFirstSessionStallPoint(stallEvent: String, metadata: [String: Any] = [:]) {
        var meta = metadata
        meta["stallEvent"] = stallEvent
        meta["isFirstSession"] = true
        shared.logEvent(
            eventType: .firstSessionStallPoint,
            category: .behaviorModeling,
            metadata: meta
        )
    }
    
    static func logRetryAfterError(
        intervalMs: Int,
        errorType: String,
        metadata: [String: Any] = [:]
    ) {
        var meta = metadata
        meta["intervalMs"] = intervalMs
        meta["errorType"] = errorType
        shared.logEvent(
            eventType: .retryAfterErrorInterval,
            category: .behaviorModeling,
            metadata: meta
        )
    }
    
    static func logFeatureToggleHoverNoUse(
        featureId: String,
        hoverDuration: Int,
        metadata: [String: Any] = [:]
    ) {
        var meta = metadata
        meta["featureId"] = featureId
        meta["hoverDuration"] = hoverDuration
        shared.logEvent(
            eventType: .featureToggleHoverNoUse,
            category: .behaviorModeling,
            metadata: meta
        )
    }
    
    // MARK: - Messaging
    
    static func logMessageSendAttempted(metadata: [String: Any] = [:]) {
        shared.logEvent(
            eventType: .messageSendAttempted,
            category: .messaging,
            metadata: metadata
        )
    }
    
    static func logMessageSendFailed(error: String, metadata: [String: Any] = [:]) {
        var meta = metadata
        meta["error"] = error
        shared.logEvent(
            eventType: .messageSendFailed,
            category: .messaging,
            metadata: meta
        )
    }
    
    static func logMessageRollback(metadata: [String: Any] = [:]) {
        shared.logEvent(
            eventType: .messageRollback,
            category: .messaging,
            metadata: metadata
        )
    }
    
    // MARK: - Engagement
    
    static func logRoomEntry(roomId: String, metadata: [String: Any] = [:]) {
        shared.logEvent(
            eventType: .roomEntry,
            category: .engagement,
            metadata: metadata,
            roomId: roomId
        )
    }
    
    static func logRoomExit(roomId: String, metadata: [String: Any] = [:]) {
        shared.logEvent(
            eventType: .roomExit,
            category: .engagement,
            metadata: metadata,
            roomId: roomId
        )
    }
    
    // MARK: - Voice/AV
    
    static func logVoiceCaptureFailed(error: String, metadata: [String: Any] = [:]) {
        var meta = metadata
        meta["error"] = error
        shared.logEvent(
            eventType: .voiceCaptureFailed,
            category: .voiceAV,
            metadata: meta
        )
    }
    
    // MARK: - System
    
    static func logAPIFailure(endpoint: String, statusCode: Int, metadata: [String: Any] = [:]) {
        var meta = metadata
        meta["endpoint"] = endpoint
        meta["statusCode"] = statusCode
        shared.logEvent(
            eventType: .apiFailure,
            category: .system,
            metadata: meta
        )
    }
    
    static func logClientCrash(error: String, metadata: [String: Any] = [:]) {
        var meta = metadata
        meta["error"] = error
        shared.logEvent(
            eventType: .clientCrash,
            category: .system,
            metadata: meta
        )
    }
    
    // MARK: - Threading
    
    static func logThreadCreated(threadId: String, metadata: [String: Any] = [:]) {
        var meta = metadata
        meta["threadId"] = threadId
        shared.logEvent(
            eventType: .threadCreated,
            category: .threading,
            metadata: meta
        )
    }
    
    // MARK: - Typing
    
    static func logTypingStart(metadata: [String: Any] = [:]) {
        shared.logEvent(
            eventType: .typingStart,
            category: .typing,
            metadata: metadata
        )
    }
    
    static func logTypingStop(metadata: [String: Any] = [:]) {
        shared.logEvent(
            eventType: .typingStop,
            category: .typing,
            metadata: metadata
        )
    }
    
    // MARK: - Presence
    
    static func logPresencePing(status: String, metadata: [String: Any] = [:]) {
        var meta = metadata
        meta["status"] = status
        shared.logEvent(
            eventType: .presencePing,
            category: .presence,
            metadata: meta
        )
    }
    
    nonisolated deinit {
        // Timer cleanup handled by @MainActor context
        // Flush handled by timer and explicit calls
    }
}

