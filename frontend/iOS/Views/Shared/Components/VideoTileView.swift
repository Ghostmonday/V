import SwiftUI
import AVFoundation

/// Video Tile Component
/// Reusable video tile for displaying participant video with info overlay
struct VideoTileView: View {
    let participant: ParticipantInfo
    let isLocal: Bool
    @State private var videoLayer: AVPlayerLayer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video background
                Color.gray.opacity(0.3)
                
                // Video layer (placeholder - requires AVPlayerLayer integration)
                if !participant.videoEnabled {
                    videoMutedOverlay
                }
                
                // Participant info overlay
                VStack {
                    Spacer()
                    participantInfoBar
                }
            }
            .cornerRadius(8)
            .aspectRatio(16/9, contentMode: .fit)
        }
    }
    
    private var videoMutedOverlay: some View {
        VStack(spacing: 8) {
            Text("📹")
                .font(.system(size: 24))
            Text("Camera Off")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGray4))
    }
    
    private var participantInfoBar: some View {
        HStack(spacing: 8) {
            Text(participant.name ?? participant.identity)
                .font(.caption)
                .foregroundColor(.white)
            
            if participant.isSpeaking {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .pulse(isActive: true)
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(4)
        .padding(8)
    }
}

/// Participant Info Model
struct ParticipantInfo: Identifiable {
    let id: String
    let identity: String
    let name: String?
    let isLocal: Bool
    var audioEnabled: Bool
    var videoEnabled: Bool
    var isSpeaking: Bool
}

#Preview {
    VideoTileView(
        participant: ParticipantInfo(
            id: "1",
            identity: "user123",
            name: "John Doe",
            isLocal: false,
            audioEnabled: true,
            videoEnabled: false,
            isSpeaking: true
        ),
        isLocal: false
    )
    .frame(width: 300, height: 169)
}

