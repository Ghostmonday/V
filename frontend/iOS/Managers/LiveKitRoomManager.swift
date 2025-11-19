import Foundation
import Combine
#if canImport(LiveKit)
import LiveKit
#endif
import UIKit
import AVFoundation

/// LiveKit Room Manager
/// Wraps LiveKit Swift SDK for voice/video functionality
/// Provides high-level API matching Vue VideoRoomManager
@MainActor
class LiveKitRoomManager: ObservableObject {
    static let shared = LiveKitRoomManager()

    @Published var isConnected: Bool = false
    @Published var participants: [ParticipantInfo] = []
    @Published var localAudioEnabled: Bool = false
    @Published var localVideoEnabled: Bool = false
    @Published var isPushToTalkMode: Bool = false
    @Published var cameraPosition: CameraPosition = .front
    
    #if canImport(LiveKit)
    private var room: Room?
    #else
    private var room: Any?
    #endif
    
    struct ParticipantInfo: Identifiable, Equatable {
        let id: String
        let identity: String
        let name: String?
        let isLocal: Bool
        var audioEnabled: Bool
        var videoEnabled: Bool
        var isSpeaking: Bool
        #if canImport(LiveKit)
        var videoTrack: VideoTrack?
        #else
        // Use a simple type that can be compared for Equatable conformance
        var videoTrack: String?
        #endif
    }
    
    struct JoinConfig {
        let url: String
        let token: String
        let audioEnabled: Bool
        let videoEnabled: Bool
        let pushToTalk: Bool
    }
    
    enum CameraPosition {
        case front
        case back
    }
    
    private init() {
    }
    
    // MARK: - Connection
    
    func joinRoom(config: JoinConfig) async throws {
        #if canImport(LiveKit)
        // Request permissions before joining room
        if config.audioEnabled {
            await requestMicrophonePermission()
        }
        if config.videoEnabled {
            await requestCameraPermission()
        }
        
        // Disconnect if already connected
        if room != nil {
            await leaveRoom()
        }
        
        let roomOptions = RoomOptions(
            defaultCameraCaptureOptions: CameraCaptureOptions(
                position: .front
            ),
            defaultAudioCaptureOptions: AudioCaptureOptions(
                echoCancellation: true,
                noiseSuppression: true
            ),
            adaptiveStream: true,
            dynacast: true
        )
        
        let newRoom = Room(delegate: self, roomOptions: roomOptions)
        self.room = newRoom
        
        do {
            try await newRoom.connect(url: config.url, token: config.token)
        
            self.isConnected = true
            self.isPushToTalkMode = config.pushToTalk
            
            // Publish local tracks based on config
            try await newRoom.localParticipant.setMicrophone(enabled: config.audioEnabled && !config.pushToTalk)
            try await newRoom.localParticipant.setCamera(enabled: config.videoEnabled)
            
            self.localAudioEnabled = config.audioEnabled && !config.pushToTalk
            self.localVideoEnabled = config.videoEnabled
            
            self.updateParticipants()
        
            print("[LiveKit] Joined room successfully")
        
            UXTelemetryService.logRoomEntry(roomId: newRoom.name ?? "unknown", metadata: [
                "audioEnabled": "\(config.audioEnabled)",
                "videoEnabled": "\(config.videoEnabled)",
                "pushToTalk": "\(config.pushToTalk)"
        ])
            
        } catch {
            print("[LiveKit] Failed to join room: \(error)")
            self.room = nil
            throw error
        }
        #else
        // Stub implementation when LiveKit is not available
        print("[LiveKit] LiveKit not available - stub implementation")
        self.isConnected = false
        #endif
    }
    
    func leaveRoom() async {
        #if canImport(LiveKit)
        guard let room = room as? Room else { return }
        
        await room.disconnect()
        self.room = nil
        self.isConnected = false
        self.participants.removeAll()
        
        print("[LiveKit] Left room")
        #else
        self.room = nil
        self.isConnected = false
        self.participants.removeAll()
        #endif
    }
    
    // MARK: - Audio Control
    
    func toggleAudio() async -> Bool {
        #if canImport(LiveKit)
        guard let room = room as? Room, let localParticipant = room.localParticipant else { return false }
        
        let newState = !localParticipant.isMicrophoneEnabled()
        do {
            try await localParticipant.setMicrophone(enabled: newState)
            self.localAudioEnabled = newState
        
        UXTelemetryService.logStateTransition(
            componentId: "AudioControl",
                stateBefore: !newState ? "enabled" : "muted",
                stateAfter: newState ? "enabled" : "muted",
            category: .voiceAV
        )
        
            return newState
        } catch {
            print("[LiveKit] Failed to toggle audio: \(error)")
            return localParticipant.isMicrophoneEnabled()
        }
        #else
        localAudioEnabled.toggle()
        return localAudioEnabled
        #endif
    }
    
    func enableAudio() async {
        #if canImport(LiveKit)
        guard let room = room as? Room, let localParticipant = room.localParticipant else { return }
        if !localParticipant.isMicrophoneEnabled() {
        _ = await toggleAudio()
        }
        #else
        if !localAudioEnabled {
            _ = await toggleAudio()
        }
        #endif
    }
    
    func setPushToTalkMode(_ enabled: Bool) async {
        isPushToTalkMode = enabled
        
        #if canImport(LiveKit)
        if enabled {
            // Mute immediately when entering PTT mode
            if let room = room as? Room, let localParticipant = room.localParticipant {
                try? await localParticipant.setMicrophone(enabled: false)
                self.localAudioEnabled = false
            }
        }
        #else
        if enabled {
            self.localAudioEnabled = false
        }
        #endif
        
        UXTelemetryService.logStateTransition(
            componentId: "PushToTalk",
            stateBefore: isPushToTalkMode ? "disabled" : "enabled",
            stateAfter: enabled ? "enabled" : "disabled",
            category: .voiceAV
        )
    }
    
    func activatePushToTalk() async {
        #if canImport(LiveKit)
        guard isPushToTalkMode, let room = room as? Room, let localParticipant = room.localParticipant else { return }
        try? await localParticipant.setMicrophone(enabled: true)
        self.localAudioEnabled = true
        #else
        guard isPushToTalkMode else { return }
        self.localAudioEnabled = true
        #endif
    }
    
    func deactivatePushToTalk() async {
        #if canImport(LiveKit)
        guard isPushToTalkMode, let room = room as? Room, let localParticipant = room.localParticipant else { return }
        try? await localParticipant.setMicrophone(enabled: false)
        self.localAudioEnabled = false
        #else
        guard isPushToTalkMode else { return }
        self.localAudioEnabled = false
        #endif
    }
    
    // MARK: - Video Control
    
    func toggleVideo() async -> Bool {
        #if canImport(LiveKit)
        guard let room = room as? Room, let localParticipant = room.localParticipant else { return false }
        
        let newState = !localParticipant.isCameraEnabled()
        do {
            try await localParticipant.setCamera(enabled: newState)
            self.localVideoEnabled = newState
        
        UXTelemetryService.logStateTransition(
            componentId: "VideoControl",
                stateBefore: !newState ? "enabled" : "disabled",
                stateAfter: newState ? "enabled" : "disabled",
            category: .voiceAV
        )
        
            return newState
        } catch {
            print("[LiveKit] Failed to toggle video: \(error)")
            return localParticipant.isCameraEnabled()
        }
        #else
        localVideoEnabled.toggle()
        return localVideoEnabled
        #endif
    }
    
    func switchCamera() async {
        #if canImport(LiveKit)
        guard let room = room as? Room, let localParticipant = room.localParticipant else { return }
        
        if let track = localParticipant.firstCameraVideoTrack as? LocalVideoTrack,
           let capturer = track.capturer as? CameraCapturer {
            do {
                try await capturer.switchCameraPosition()
                self.cameraPosition = capturer.options.position == .front ? .front : .back
            } catch {
                print("[LiveKit] Failed to switch camera: \(error)")
            }
        }
        #else
        cameraPosition = cameraPosition == .front ? .back : .front
        #endif
    }
    
    // MARK: - Permissions
    
    private func requestMicrophonePermission() async {
        #if os(iOS)
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if !granted {
                    print("[LiveKit] Microphone permission denied")
                }
                continuation.resume()
            }
        }
        #endif
    }
    
    private func requestCameraPermission() async {
        #if os(iOS)
        let status = await AVCaptureDevice.requestAccess(for: AVMediaType.video)
        if !status {
            print("[LiveKit] Camera permission denied")
        }
        #endif
    }

    // MARK: - Participant Management
    
    private func updateParticipants() {
        #if canImport(LiveKit)
        guard let room = room as? Room else {
            self.participants = []
            return
        }
        
        var allParticipants: [Participant] = Array(room.remoteParticipants.values)
        if let local = room.localParticipant {
            allParticipants.append(local)
        }
        
        self.participants = allParticipants.map { p in
            #if canImport(LiveKit)
            ParticipantInfo(
                id: p.sid ?? p.identity ?? UUID().uuidString,
                identity: p.identity ?? "Unknown",
                name: p.name,
                isLocal: p is LocalParticipant,
                audioEnabled: p.isMicrophoneEnabled(),
                videoEnabled: p.isCameraEnabled(),
                isSpeaking: p.isSpeaking,
                videoTrack: p.firstCameraVideoTrack as? VideoTrack
            )
            #else
            ParticipantInfo(
                id: UUID().uuidString,
                identity: "Unknown",
                name: nil,
                isLocal: false,
                audioEnabled: false,
                videoEnabled: false,
                isSpeaking: false,
                videoTrack: nil
            )
            #endif
        }
        #else
        // Stub implementation
        self.participants = []
        #endif
    }
    
    // MARK: - RoomDelegate Methods
    // These methods implement RoomDelegate when LiveKit is available
    #if canImport(LiveKit)
    nonisolated func room(_ room: Room, didUpdate connectionState: ConnectionState, oldValue: ConnectionState) {
        Task { @MainActor in
            self.isConnected = (connectionState == .connected)
            if connectionState == .disconnected {
                self.room = nil
                self.participants = []
            }
        }
    }
    
    nonisolated func room(_ room: Room, participantDidJoin participant: RemoteParticipant) {
        Task { @MainActor in
            self.updateParticipants()
        }
    }
    
    nonisolated func room(_ room: Room, participantDidLeave participant: RemoteParticipant) {
        Task { @MainActor in
            self.updateParticipants()
        }
    }
    
    nonisolated func room(_ room: Room, participant: Participant, didUpdate publication: TrackPublication, muted: Bool) {
        Task { @MainActor in
            self.updateParticipants()
        }
    }

    nonisolated func room(_ room: Room, participant: Participant, didUpdate speakStatus: Bool) {
        Task { @MainActor in
            self.updateParticipants()
        }
    }
    #endif
}

#if canImport(LiveKit)
extension LiveKitRoomManager: RoomDelegate {}
#endif
