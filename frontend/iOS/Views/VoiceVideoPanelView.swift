import SwiftUI
import LiveKit

/// Panel for Voice and Video Controls
struct VoiceVideoPanelView: View {
    @StateObject private var roomManager = LiveKitRoomManager.shared
    let roomName: String
    let token: String // LiveKit token to join
    let serverUrl: String // LiveKit server URL
    
    var body: some View {
        VStack(spacing: 16) {
            if roomManager.isConnected {
                // Active Call Controls
                HStack(spacing: 24) {
                    // Mute Toggle
                    Button(action: {
                        Task {
                            _ = await roomManager.toggleAudio()
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: roomManager.localAudioEnabled ? "mic.fill" : "mic.slash.fill")
                                .font(.title2)
                                .foregroundColor(roomManager.localAudioEnabled ? .primary : .red)
                                .frame(width: 50, height: 50)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                            
                            Text(roomManager.localAudioEnabled ? "Mute" : "Unmute")
                                .font(.caption)
                        }
                    }
                    
                    // Leave Button
                    Button(action: {
                        Task {
                            await roomManager.leaveRoom()
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "phone.down.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.red)
                                .clipShape(Circle())
                            
                            Text("Leave")
                                .font(.caption)
                        }
                    }
                    
                    // Video Toggle
                    Button(action: {
                        Task {
                            _ = await roomManager.toggleVideo()
    }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: roomManager.localVideoEnabled ? "video.fill" : "video.slash.fill")
                                .font(.title2)
                                .foregroundColor(roomManager.localVideoEnabled ? .primary : .secondary)
                                .frame(width: 50, height: 50)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                            
                            Text("Video")
                                .font(.caption)
                        }
                    }
                }
                .transition(.scale)
                
                if roomManager.localVideoEnabled {
                    Button("Switch Camera") {
                        Task {
                            await roomManager.switchCamera()
                        }
                    }
                    .font(.caption)
                }
                
            } else {
                // Join Button
                Button(action: {
                    joinRoom()
                }) {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text("Join Audio")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .animation(.spring(), value: roomManager.isConnected)
    }
    
    private func joinRoom() {
        Task {
            do {
                let config = LiveKitRoomManager.JoinConfig(
                    url: serverUrl,
                    token: token,
                    audioEnabled: true,
                    videoEnabled: false,
                    pushToTalk: false
                )
                
                try await roomManager.joinRoom(config: config)
            } catch {
                print("Failed to join room: \(error)")
            }
        }
    }
}
