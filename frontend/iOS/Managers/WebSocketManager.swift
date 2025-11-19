import Foundation
import Combine
import OSLog
import UIKit

// Import Message type from Models
// Note: Message is defined in Models/Message.swift, not GlassApp.swift
// Since both are in the same module, we'll use the one from Models/Message.swift
// The GlassApp.swift Message is commented out, so this should work

// EmotionPulse and EmotionPulseEvent are defined in Models/UXEventType.swift
// ⚠️ DO NOT REDEFINE - You have been warned. This will haunt you.

/// WebSocket Manager for Real-Time Communication
/// Enhanced with exponential backoff, state machine, message outbox, and network reachability
/// Replaces Vue socket listeners with URLSessionWebSocketTask
/// Provides AsyncStream and Combine publishers for events
@MainActor
class WebSocketManager: ObservableObject {
    private static let logger = Logger(subsystem: "com.vibez.app", category: "WebSocket")
    static let shared = WebSocketManager()
    
    @Published var isConnected: Bool = false
    @Published var connectionState: ConnectionState = .disconnected
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var pongTimeoutTimer: Timer?
    
    // Reconnection state
    private var reconnectAttempts: Int = 0
    private var reconnectTimer: Timer?
    private var maxReconnectAttempts: Int = 10
    private let baseRetryDelay: TimeInterval = 1.0 // 1 second
    private let maxRetryDelay: TimeInterval = 30.0 // 30 seconds
    
    // Connection credentials (stored for reconnection)
    private var storedUserId: String?
    private var storedToken: String?
    
    // Message outbox queue
    private struct OutboxMessage {
        let event: String
        let payload: [String: Any]
        let timestamp: Date
    }
    private var outboxQueue: [OutboxMessage] = []
    private let maxOutboxSize: Int = 100
    private let outboxTTL: TimeInterval = 60.0 // 60 seconds
    
    // Ping/pong tracking
    private var lastPingTime: Date?
    private var lastSuccessfulReceiveTime: Date?
    private let pingInterval: TimeInterval = 30.0
    private let connectionTimeout: TimeInterval = 90.0 // 90 seconds without any activity
    
    // Services
    private let networkReachability = NetworkReachability.shared
    private let roomRestoration = RoomRestorationService.shared
    
    // Message streams - using Message from Models/Message.swift
    private let messageSubject = PassthroughSubject<Message, Never>()
    private let presenceSubject = PassthroughSubject<PresenceUpdate, Never>()
    private let voiceEventSubject = PassthroughSubject<VoiceEvent, Never>()
    private let typingSubject = PassthroughSubject<TypingEvent, Never>()
    private let emotionPulseSubject = PassthroughSubject<EmotionPulseEvent, Never>()
    
    var messagePublisher: AnyPublisher<Message, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    
    var presencePublisher: AnyPublisher<PresenceUpdate, Never> {
        presenceSubject.eraseToAnyPublisher()
    }
    
    var voiceEventPublisher: AnyPublisher<VoiceEvent, Never> {
        voiceEventSubject.eraseToAnyPublisher()
    }
    
    var typingPublisher: AnyPublisher<TypingEvent, Never> {
        typingSubject.eraseToAnyPublisher()
    }
    
    var emotionPulsePublisher: AnyPublisher<EmotionPulseEvent, Never> {
        emotionPulseSubject.eraseToAnyPublisher()
    }
    
    /// Enhanced connection state machine
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case restoring
        case ready
    }
    
    private init() {
        setupBackgroundObservers()
        setupNetworkReachability()
    }
    
    // MARK: - Network Reachability
    
    private func setupNetworkReachability() {
        // Set callback for when network becomes available
        networkReachability.onNetworkAvailable = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                if self.connectionState == .disconnected {
                    Self.logger.info("[WebSocket] Network available, attempting reconnection")
                    self.attemptReconnection()
                }
            }
        }
        
        // Set callback for when network becomes unavailable
        networkReachability.onNetworkUnavailable = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                Self.logger.warning("[WebSocket] Network unavailable, stopping reconnection attempts")
                self.cancelReconnection()
            }
        }
    }
    
    // MARK: - Connection Management
    
    func connect(userId: String, token: String) {
        guard connectionState != .connected && connectionState != .ready else { return }
        
        // Store credentials for reconnection
        storedUserId = userId
        storedToken = token
        
        // Reset reconnection attempts
        reconnectAttempts = 0
        
        // Check network availability
        guard networkReachability.checkNetworkAvailability() else {
            Self.logger.warning("[WebSocket] Cannot connect - network unavailable")
            connectionState = .disconnected
            return
        }
        
        connectionState = .connecting
        Self.logger.info("[WebSocket] Connecting...")
        
        // Construct WebSocket URL
        guard let url = URL(string: "\(APIClient.wsBaseURL)?userId=\(userId)&token=\(token)") else {
            Self.logger.error("[WebSocket] Invalid URL")
            connectionState = .disconnected
            return
        }
        
        // Create WebSocket task
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Transition to connected state
        connectionState = .connected
        isConnected = true
        
        // Start receiving messages
        receiveMessage()
        
        // Start ping/pong heartbeat
        startPing()
        
        Self.logger.info("[WebSocket] Connected")
        
        // Begin room restoration
        restoreRooms()
    }
    
    func disconnect() {
        cancelReconnection()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        pingTimer?.invalidate()
        pingTimer = nil
        pongTimeoutTimer?.invalidate()
        pongTimeoutTimer = nil
        connectionState = .disconnected
        isConnected = false
        
        // Clear stored credentials
        storedUserId = nil
        storedToken = nil
        
        Self.logger.info("[WebSocket] Disconnected")
    }
    
    // MARK: - Reconnection Logic
    
    private func handleConnectionLost() {
        isConnected = false
        
        // Cancel ping timers
        pingTimer?.invalidate()
        pingTimer = nil
        pongTimeoutTimer?.invalidate()
        pongTimeoutTimer = nil
        
        // Update state
        connectionState = .disconnected
        
        Self.logger.info("[WebSocket] Connection lost, attempting reconnection")
        
        // Attempt reconnection with exponential backoff
        attemptReconnection()
    }
    
    private func attemptReconnection() {
        // Check network availability
        guard networkReachability.checkNetworkAvailability() else {
            Self.logger.warning("[WebSocket] Cannot reconnect - network unavailable")
            return
        }
        
        // Check max attempts
        guard reconnectAttempts < maxReconnectAttempts else {
            Self.logger.error("[WebSocket] Max reconnection attempts reached")
            connectionState = .disconnected
            return
        }
        
        // Check if we have stored credentials
        guard let userId = storedUserId, let token = storedToken else {
            Self.logger.error("[WebSocket] Cannot reconnect - no stored credentials")
            return
        }
        
        // Calculate exponential backoff delay with jitter
        let delay = calculateBackoffDelay(attempt: self.reconnectAttempts)
        self.reconnectAttempts += 1
        
        Self.logger.info("[WebSocket] Reconnecting in \(delay)s (attempt \(self.reconnectAttempts)/\(self.maxReconnectAttempts))")
        
        // Schedule reconnection
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.reconnect(userId: userId, token: token)
            }
        }
    }
    
    private func reconnect(userId: String, token: String) {
        guard connectionState == .disconnected else { return }
        
        connectionState = .connecting
        Self.logger.info("[WebSocket] Reconnecting...")
        
        // Construct WebSocket URL
        guard let url = URL(string: "\(APIClient.wsBaseURL)?userId=\(userId)&token=\(token)") else {
            Self.logger.error("[WebSocket] Invalid URL during reconnect")
            connectionState = .disconnected
            attemptReconnection() // Retry
            return
        }
        
        // Create new WebSocket task
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Transition to connected state
        connectionState = .connected
        isConnected = true
        
        // Start receiving messages
        receiveMessage()
        
        // Start ping/pong heartbeat
        startPing()
        
        Self.logger.info("[WebSocket] Reconnected successfully")
        
        // Reset reconnection attempts on successful reconnect
        reconnectAttempts = 0
        
        // Begin room restoration
        restoreRooms()
        
        // Flush outbox queue
        flushOutbox()
    }
    
    private func cancelReconnection() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    /// Calculate exponential backoff delay with jitter
    private func calculateBackoffDelay(attempt: Int) -> TimeInterval {
        // Exponential backoff: baseDelay * 2^attempt
        let exponentialDelay = baseRetryDelay * pow(2.0, Double(attempt))
        
        // Add jitter: ±10% randomization to prevent thundering herd
        let jitterRange = exponentialDelay * 0.1
        let jitter = (Double.random(in: 0...1) * 2 - 1) * jitterRange // -10% to +10%
        
        // Calculate final delay with jitter
        let delay = exponentialDelay + jitter
        
        // Bound by maximum delay
        return min(maxRetryDelay, max(0, delay))
    }
    
    // MARK: - Room Restoration
    
    private func restoreRooms() {
        guard connectionState == .connected || connectionState == .ready else { return }
        
        let roomsToRestore = roomRestoration.getJoinedRooms()
        guard !roomsToRestore.isEmpty else {
            // No rooms to restore, transition to ready
            connectionState = .ready
            return
        }
        
        connectionState = .restoring
        Self.logger.info("[WebSocket] Restoring \(roomsToRestore.count) rooms")
        
        // Batch rejoin rooms (max 10 per batch)
        let batchSize = 10
        var processedCount = 0
        
        for i in stride(from: 0, to: roomsToRestore.count, by: batchSize) {
            let endIndex = min(i + batchSize, roomsToRestore.count)
            let batch = Array(roomsToRestore[i..<endIndex])
            
            // Send rejoin messages for batch
            for roomId in batch {
                send(event: "room_join", payload: ["roomId": roomId])
                processedCount += 1
            }
            
            // Small delay between batches to avoid overwhelming server
            if endIndex < roomsToRestore.count {
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                }
            }
        }
        
        Self.logger.info("[WebSocket] Room restoration initiated for \(processedCount) rooms")
        
        // Transition to ready state after restoration
        // Note: Actual room join confirmations will come via WebSocket messages
        // For now, transition after a short delay
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
            if connectionState == .restoring {
                connectionState = .ready
                Self.logger.info("[WebSocket] Room restoration complete, state: ready")
            }
        }
    }
    
    // MARK: - Message Receiving
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                Task { @MainActor in
                    // Update last successful receive time
                    self.lastSuccessfulReceiveTime = Date()
                    
                    switch message {
                    case .string(let text):
                        self.handleIncomingMessage(text)
                    case .data(let data):
                        self.handleIncomingData(data)
                    @unknown default:
                        break
                    }
                    
                    // Continue receiving
                    self.receiveMessage()
                }
                
            case .failure(let error):
                Task { @MainActor in
                    Self.logger.error("[WebSocket] Receive error: \(error.localizedDescription)")
                    self.handleConnectionLost()
                }
            }
        }
    }
    
    private func handleIncomingMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let envelope = try JSONDecoder().decode(WSEnvelope.self, from: data)
            
            // Handle reconnect_guidance message from server
            if envelope.type == "reconnect_guidance" {
                if let guidanceData = try? JSONSerialization.jsonObject(with: envelope.payload) as? [String: Any],
                   let backoffMs = guidanceData["backoff_ms"] as? Double {
                    Self.logger.info("[WebSocket] Received reconnect guidance: \(backoffMs)ms")
                    // Server is suggesting backoff, but we'll use our own exponential backoff
                }
                return
            }
            
            switch envelope.type {
            case "message":
                if let message = try? JSONDecoder().decode(Message.self, from: envelope.payload) {
                    messageSubject.send(message)
                }
            case "presence_update":
                if let presence = try? JSONDecoder().decode(PresenceUpdate.self, from: envelope.payload) {
                    presenceSubject.send(presence)
                }
            case "voice_event":
                if let voice = try? JSONDecoder().decode(VoiceEvent.self, from: envelope.payload) {
                    voiceEventSubject.send(voice)
                }
            case "typing":
                if let typing = try? JSONDecoder().decode(TypingEvent.self, from: envelope.payload) {
                    typingSubject.send(typing)
                }
            case "emotion_pulse":
                if let pulseEvent = try? JSONDecoder().decode(EmotionPulseEvent.self, from: envelope.payload) {
                    emotionPulseSubject.send(pulseEvent)
                }
            case "room_joined":
                // Room join confirmation
                if let roomData = try? JSONSerialization.jsonObject(with: envelope.payload) as? [String: Any],
                   let roomId = roomData["roomId"] as? String {
                    roomRestoration.addRoom(roomId)
                    Self.logger.info("[WebSocket] Room joined confirmed: \(roomId)")
                }
            default:
                Self.logger.warning("[WebSocket] Unknown message type: \(envelope.type)")
            }
        } catch {
            Self.logger.error("[WebSocket] Parse error: \(error.localizedDescription)")
        }
    }
    
    private func handleIncomingData(_ data: Data) {
        // Handle binary data if needed
        Self.logger.debug("[WebSocket] Received binary data: \(data.count) bytes")
    }
    
    // MARK: - Message Sending with Outbox
    
    func send(event: String, payload: [String: Any]) {
        // If connected and ready, send immediately
        if connectionState == .ready && isConnected {
            sendImmediately(event: event, payload: payload)
        } else {
            // Queue in outbox
            queueInOutbox(event: event, payload: payload)
        }
    }
    
    private func sendImmediately(event: String, payload: [String: Any]) {
        let envelope: [String: Any] = [
            "type": event,
            "payload": payload,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: envelope)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let message = URLSessionWebSocketTask.Message.string(jsonString)
                webSocketTask?.send(message) { error in
                    if let error = error {
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            Self.logger.error("[WebSocket] Send error: \(error.localizedDescription)")
                            // Queue failed message in outbox for retry
                            self.queueInOutbox(event: event, payload: payload)
                        }
                    }
                }
            }
        } catch {
            Self.logger.error("[WebSocket] Encoding error: \(error.localizedDescription)")
            // Queue failed message in outbox
            queueInOutbox(event: event, payload: payload)
        }
    }
    
    private func queueInOutbox(event: String, payload: [String: Any]) {
        // Remove expired messages from outbox
        let now = Date()
        outboxQueue.removeAll { now.timeIntervalSince($0.timestamp) > outboxTTL }
        
        // Check outbox size limit
        if outboxQueue.count >= maxOutboxSize {
            // Drop oldest message
            let dropped = outboxQueue.removeFirst()
            Self.logger.warning("[WebSocket] Outbox full, dropping oldest message: \(dropped.event)")
        }
        
        // Add to outbox
        let message = OutboxMessage(event: event, payload: payload, timestamp: now)
        self.outboxQueue.append(message)
        Self.logger.info("[WebSocket] Queued message in outbox: \(event) (outbox size: \(self.outboxQueue.count))")
    }
    
    private func flushOutbox() {
        guard connectionState == .ready && isConnected else { return }
        
        let messagesToSend = outboxQueue
        outboxQueue.removeAll()
        
        Self.logger.info("[WebSocket] Flushing outbox: \(messagesToSend.count) messages")
        
        for message in messagesToSend {
            sendImmediately(event: message.event, payload: message.payload)
        }
    }
    
    func sendTypingStart(roomId: String) {
        send(event: "typing_start", payload: ["roomId": roomId])
    }
    
    func sendTypingStop(roomId: String) {
        send(event: "typing_stop", payload: ["roomId": roomId])
    }
    
    func sendPresenceUpdate(status: String) {
        send(event: "presence_update", payload: ["status": status])
    }
    
    // MARK: - Ping/Pong with Timeout Detection
    
    private func startPing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendPing()
            }
        }
    }
    
    private func sendPing() {
        guard connectionState == .connected || connectionState == .ready else { return }
        
        lastPingTime = Date()
        
        webSocketTask?.sendPing { [weak self] error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    Self.logger.error("[WebSocket] Ping error: \(error.localizedDescription)")
                    self.handleConnectionLost()
                } else {
                    // Ping sent successfully
                    // Note: URLSessionWebSocketTask handles pong automatically
                    // We detect connection issues via receive failures or timeout
                    self.checkConnectionHealth()
                }
            }
        }
    }
    
    private func checkConnectionHealth() {
        // Cancel existing timeout
        pongTimeoutTimer?.invalidate()
        
        // Check if we've received any messages recently
        let now = Date()
        if let lastReceive = lastSuccessfulReceiveTime {
            let timeSinceReceive = now.timeIntervalSince(lastReceive)
            
            // If no messages received for too long, check connection
            if timeSinceReceive > connectionTimeout {
                Self.logger.warning("[WebSocket] No activity for \(timeSinceReceive)s, checking connection")
                // Connection might be dead, but let receiveMessage() handle it
            }
        }
        
        // Set up timeout to check connection health
        pongTimeoutTimer = Timer.scheduledTimer(withTimeInterval: connectionTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                
                // Check if we've received any messages
                if let lastReceive = self.lastSuccessfulReceiveTime {
                    let timeSinceReceive = Date().timeIntervalSince(lastReceive)
                    if timeSinceReceive > self.connectionTimeout {
                        Self.logger.error("[WebSocket] Connection timeout - no activity for \(timeSinceReceive)s")
                        self.handleConnectionLost()
                    }
                } else {
                    // Never received a message, connection might be dead
                    Self.logger.error("[WebSocket] Connection timeout - no messages received")
                    self.handleConnectionLost()
                }
            }
        }
    }
    
    // MARK: - Background Observers
    
    private func setupBackgroundObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        // Keep connection alive in background (iOS limitations apply)
        Self.logger.info("[WebSocket] App entering background")
        // Note: iOS may suspend WebSocket connections in background
        // Reconnection will happen when app enters foreground
    }
    
    @objc private func appWillEnterForeground() {
        Self.logger.info("[WebSocket] App entering foreground")
        
        // Check connection state and reconnect if needed
        if connectionState == .disconnected {
            if let userId = storedUserId, let token = storedToken {
                reconnect(userId: userId, token: token)
            } else {
                Self.logger.warning("[WebSocket] Cannot reconnect - no stored credentials")
            }
        } else if connectionState == .connected || connectionState == .ready {
            // Verify connection is still alive
            sendPing()
        }
    }
    
    deinit {
        // Ensure WebSocket is disconnected when manager is deallocated
        // Note: Can't access non-Sendable Timer types from nonisolated deinit
        // WebSocket will be cleaned up when the object is deallocated
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        // Timers will be invalidated automatically when object is deallocated
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types

struct WSEnvelope: Codable {
    let type: String
    let payload: Data
    let timestamp: String?
}

struct PresenceUpdate: Codable {
    let userId: String
    let status: String
    let timestamp: Date
}

struct VoiceEvent: Codable {
    let type: String
    let userId: String
    let metadata: [String: String]?
}

struct TypingEvent: Codable {
    let userId: String
    let roomId: String
    let isTyping: Bool
}

struct EmotionPulseEvent: Codable {
    let userId: String
    let roomId: String
    let emotion: String
    let intensity: Double?
    let timestamp: Date
}
