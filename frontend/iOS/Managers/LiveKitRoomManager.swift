import Foundation
import Combine
import LiveKit
import UIKit

/// LiveKit Room Manager
/// Wraps LiveKit Swift SDK for voice/video functionality
/// Provides high-level API matching Vue VideoRoomManager
@MainActor
class LiveKitRoomManager: ObservableObject, RoomDelegate {
    static let shared = LiveKitRoomManager()

    @Published var isConnected: Bool = false
    @Published var participants: [ParticipantInfo] = []
    @Published var localAudioEnabled: Bool = false
    @Published var localVideoEnabled: Bool = false
    @Published var isPushToTalkMode: Bool = false
    @Published var cameraPosition: CameraPosition = .front
    
    private var room: Room?
    
    struct ParticipantInfo: Identifiable, Equatable {
        let id: String
        let identity: String
        let name: String?
        let isLocal: Bool
        var audioEnabled: Bool
        var videoEnabled: Bool
        var isSpeaking: Bool
        var videoTrack: VideoTrack?
    }
    
    struct JoinConfig {
        let url: String
        let token: String
        let audioEnabled: Bool
        let videoEnabled: Bool
        let pushToTalk: Bool
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - Connection
    
    func joinRoom(config: JoinConfig) async throws {
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
    }
    
    func leaveRoom() async {
        guard let room = room else { return }
        
        await room.disconnect()
        self.room = nil
        self.isConnected = false
        self.participants.removeAll()
        
        print("[LiveKit] Left room")
    }
    
    // MARK: - Audio Control
    
    func toggleAudio() async -> Bool {
        guard let room = room, let localParticipant = room.localParticipant else { return false }
        
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
    }
    
    func enableAudio() async {
        guard let room = room, let localParticipant = room.localParticipant else { return }
        if !localParticipant.isMicrophoneEnabled() {
            _ = await toggleAudio()
        }
    }
    
    func setPushToTalkMode(_ enabled: Bool) async {
        isPushToTalkMode = enabled
        
        if enabled {
            // Mute immediately when entering PTT mode
            if let room = room, let localParticipant = room.localParticipant {
                try? await localParticipant.setMicrophone(enabled: false)
                self.localAudioEnabled = false
            }
        }
        
        UXTelemetryService.logStateTransition(
            componentId: "PushToTalk",
            stateBefore: isPushToTalkMode ? "disabled" : "enabled",
            stateAfter: enabled ? "enabled" : "disabled",
            category: .voiceAV
        )
    }
    
    func activatePushToTalk() async {
        guard isPushToTalkMode, let room = room, let localParticipant = room.localParticipant else { return }
        try? await localParticipant.setMicrophone(enabled: true)
        self.localAudioEnabled = true
    }
    
    func deactivatePushToTalk() async {
        guard isPushToTalkMode, let room = room, let localParticipant = room.localParticipant else { return }
        try? await localParticipant.setMicrophone(enabled: false)
        self.localAudioEnabled = false
    }
    
    // MARK: - Video Control
    
    func toggleVideo() async -> Bool {
        guard let room = room, let localParticipant = room.localParticipant else { return false }
        
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
    }
    
    func switchCamera() async {
        guard let room = room, let localParticipant = room.localParticipant else { return }
        
        // LiveKit handles camera switching internally based on available devices
        // Simplified toggle logic for iOS (typically toggles front/back)
        
        // Note: LiveKit Swift SDK's CameraCapturer usually handles this.
        // We would access the video track's capturer if we need specific control,
        // but usually `setCamera` options or internal toggle methods work.
        // For MVP, we'll assume standard behavior or add specific track manipulation if needed.
        
        // A more robust way often involves:
        // localParticipant.firstVideoTrack?.capturer as? CameraCapturer ... switchCamera()
        
        if let track = localParticipant.firstCameraVideoTrack as? LocalVideoTrack,
           let capturer = track.capturer as? CameraCapturer {
            do {
                try await capturer.switchCameraPosition()
                self.cameraPosition = capturer.options.position
            } catch {
                print("[LiveKit] Failed to switch camera: \(error)")
            }
        }
    }

    // MARK: - Participant Management
    
    private func updateParticipants() {
        guard let room = room else {
            self.participants = []
            return
        }
        
        var allParticipants: [Participant] = Array(room.remoteParticipants.values)
        if let local = room.localParticipant {
            allParticipants.append(local)
        }
        
        self.participants = allParticipants.map { p in
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
        }
    }
    
    // MARK: - RoomDelegate
    
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
}
