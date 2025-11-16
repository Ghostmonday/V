import SwiftUI
import AVFoundation

/// Agora Room View - Simple, addictive, stranger-friendly video/voice room
@available(iOS 17.0, *)
struct AgoraRoomView: View {
    let roomId: String
    @StateObject private var agoraManager = AgoraRoomManager.shared
    @State private var isVideoEnabled = true
    @State private var isMuted = false
    @State private var members: [RoomMember] = []
    @State private var isConnecting = false
    @State private var connectionError: String?
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Video grid or audio waveform
                if agoraManager.isVoiceOnly {
                    audioOnlyView
                } else {
                    videoGridView
                }
                
                // User list with mic icons
                userListView
                
                // Controls bar
                controlsBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Room")
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            joinRoom()
        }
        .onDisappear {
            leaveRoom()
        }
        .alert("Connection Error", isPresented: .constant(connectionError != nil)) {
            Button("OK") {
                connectionError = nil
            }
        } message: {
            if let error = connectionError {
                Text(error)
            }
        }
    }
    
    // MARK: - Video Grid View
    
    private var videoGridView: some View {
        GeometryReader { geometry in
            let columns = members.count <= 1 ? 1 : (members.count <= 4 ? 2 : 3)
            let itemSize = geometry.size.width / CGFloat(columns) - 8
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                    ForEach(members) { member in
                        VideoTileView(
                            member: member,
                            size: itemSize,
                            isLocal: member.userId == agoraManager.currentUserId
                        )
                    }
                }
                .padding(8)
            }
        }
    }
    
    // MARK: - Audio Only View
    
    private var audioOnlyView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Waveform visualization
            AudioWaveformView(members: members)
                .frame(height: 200)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - User List View
    
    private var userListView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(members) { member in
                    UserAvatarView(member: member)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.black.opacity(0.3))
    }
    
    // MARK: - Controls Bar
    
    private var controlsBar: some View {
        HStack(spacing: 24) {
            // Mute toggle
            Button(action: toggleMute) {
                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isMuted ? .red : .white)
                    .frame(width: 56, height: 56)
                    .background(isMuted ? Color.red.opacity(0.2) : Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            
            // Video toggle (hidden in voice-only mode)
            if !agoraManager.isVoiceOnly {
                Button(action: toggleVideo) {
                    Image(systemName: isVideoEnabled ? "video.fill" : "video.slash.fill")
                        .font(.system(size: 24))
                        .foregroundColor(isVideoEnabled ? .white : .red)
                        .frame(width: 56, height: 56)
                        .background(isVideoEnabled ? Color.white.opacity(0.2) : Color.red.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            
            Spacer()
            
            // Leave button
            Button(action: leaveRoom) {
                Text("Leave")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.5))
    }
    
    // MARK: - Actions
    
    private func joinRoom() {
        isConnecting = true
        Task {
            do {
                let result = try await agoraManager.joinRoom(roomId: roomId)
                if result.success {
                    isVideoEnabled = result.isVideoEnabled
                    isMuted = result.isMuted
                    members = result.members
                } else {
                    connectionError = result.error ?? "Failed to join room"
                }
            } catch {
                connectionError = error.localizedDescription
            }
            isConnecting = false
        }
    }
    
    private func toggleMute() {
        Task {
            let newMutedState = !isMuted
            let success = await agoraManager.toggleMute(roomId: roomId, isMuted: newMutedState)
            if success {
                isMuted = newMutedState
                // Update local member in list
                if let index = members.firstIndex(where: { $0.userId == agoraManager.currentUserId }) {
                    members[index].isMuted = newMutedState
                }
            }
        }
    }
    
    private func toggleVideo() {
        Task {
            let newVideoState = !isVideoEnabled
            let success = await agoraManager.toggleVideo(roomId: roomId, isVideoEnabled: newVideoState)
            if success {
                isVideoEnabled = newVideoState
                // Update local member in list
                if let index = members.firstIndex(where: { $0.userId == agoraManager.currentUserId }) {
                    members[index].isVideoEnabled = newVideoState
                }
            }
        }
    }
    
    private func leaveRoom() {
        Task {
            await agoraManager.leaveRoom(roomId: roomId)
        }
    }
}

// MARK: - Video Tile View

struct VideoTileView: View {
    let member: RoomMember
    let size: CGFloat
    let isLocal: Bool
    
    var body: some View {
        ZStack {
            // Video view placeholder (replace with Agora video view)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)
            
            // User info overlay
            VStack {
                Spacer()
                HStack {
                    // Avatar
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(member.userId.prefix(1)).uppercased())
                                .foregroundColor(.white)
                                .font(.headline)
                        )
                    
                    // Name and mic icon
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.userId.prefix(8))
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 4) {
                            Image(systemName: member.isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 10))
                                .foregroundColor(member.isMuted ? .red : .green)
                        }
                    }
                    
                    Spacer()
                }
                .padding(8)
                .background(Color.black.opacity(0.5))
            }
            .frame(width: size, height: size)
            .cornerRadius(12)
        }
    }
}

// MARK: - Audio Waveform View

struct AudioWaveformView: View {
    let members: [RoomMember]
    @State private var waveformData: [CGFloat] = Array(repeating: 0.3, count: 40)
    @State private var animationTimer: Timer?
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<waveformData.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.green)
                    .frame(width: 4)
                    .frame(height: waveformData[index] * 200)
            }
        }
        .onAppear {
            startWaveformAnimation()
        }
        .onDisappear {
            stopWaveformAnimation()
        }
    }
    
    private func startWaveformAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                waveformData = waveformData.map { _ in
                    CGFloat.random(in: 0.2...1.0)
                }
            }
        }
    }
    
    private func stopWaveformAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

// MARK: - User Avatar View

struct UserAvatarView: View {
    let member: RoomMember
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(member.userId.prefix(1)).uppercased())
                            .foregroundColor(.white)
                            .font(.headline)
                    )
                
                // Mic status indicator
                Circle()
                    .fill(member.isMuted ? Color.red : Color.green)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: member.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                    )
            }
            
            Text(member.userId.prefix(6))
                .font(.caption2)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Room Member Model

struct RoomMember: Identifiable {
    let id: String
    let userId: String
    let uid: Int
    var isMuted: Bool
    var isVideoEnabled: Bool
    let joinedAt: Int
}

// MARK: - Preview

#Preview {
    NavigationView {
        AgoraRoomView(roomId: "test-room")
    }
}

