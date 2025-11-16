import Foundation
import Combine
import OSLog
import UIKit

// EmotionPulse and EmotionPulseEvent are defined in Models/UXEventType.swift
// ⚠️ DO NOT REDEFINE - You have been warned. This will haunt you.

/// WebSocket Manager for Real-Time Communication
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
    
    // Message streams
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
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case reconnecting
    }
    
    private init() {
        setupBackgroundObservers()
    }
    
    // MARK: - Connection Management
    
    func connect(userId: String, token: String) {
        guard connectionState != .connected else { return }
        
        connectionState = .connecting
        
        // Construct WebSocket URL
        guard let url = URL(string: "\(APIClient.wsBaseURL)?userId=\(userId)&token=\(token)") else {
            Self.logger.error("[WebSocket] Invalid URL")
            connectionState = .disconnected
            return
        }
        
        // Create WebSocket task
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        
        connectionState = .connected
        isConnected = true
        
        // Start receiving messages
        receiveMessage()
        
        // Start ping/pong heartbeat
        startPing()
        
        Self.logger.info("[WebSocket] Connected")
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        pingTimer?.invalidate()
        pingTimer = nil
        connectionState = .disconnected
        isConnected = false
        
        Self.logger.info("[WebSocket] Disconnected")
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
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
                
            case .failure(let error):
                Self.logger.error("[WebSocket] Receive error: \(error.localizedDescription)")
                self.handleConnectionLost()
            }
        }
    }
    
    private func handleIncomingMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let envelope = try JSONDecoder().decode(WSEnvelope.self, from: data)
            
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
    
    private func handleConnectionLost() {
        isConnected = false
        connectionState = .disconnected
        
        // Attempt reconnection after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.reconnect()
        }
    }
    
    private func reconnect() {
        guard connectionState == .disconnected else { return }
        
        connectionState = .reconnecting
        
        // TODO: Get userId and token from AuthService
        // For now, this is a placeholder
        Self.logger.info("[WebSocket] Reconnecting...")
    }
    
    // MARK: - Sending Messages
    
    func send(event: String, payload: [String: Any]) {
        guard isConnected else {
            Self.logger.warning("[WebSocket] Cannot send - not connected")
            return
        }
        
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
                        Self.logger.error("[WebSocket] Send error: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            Self.logger.error("[WebSocket] Encoding error: \(error.localizedDescription)")
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
    
    // MARK: - Ping/Pong
    
    private func startPing() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func sendPing() {
        webSocketTask?.sendPing { error in
            if let error = error {
                Self.logger.error("[WebSocket] Ping error: \(error.localizedDescription)")
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
    }
    
    @objc private func appWillEnterForeground() {
        // Reconnect if needed
        if connectionState == .disconnected {
            reconnect()
        }
        Self.logger.info("[WebSocket] App entering foreground")
    }
    
    deinit {
        // Ensure WebSocket is disconnected when manager is deallocated
        Task { @MainActor in
            disconnect()
        }
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

