import SwiftUI
import PhotosUI

/// Chat view with message send and AI feedback
struct ChatView: View {
    let room: Room?
    @StateObject private var viewModel = RoomViewModel()
    @StateObject private var subManager = SubscriptionManager.shared
    @StateObject private var roomManager = LiveKitRoomManager.shared
    
    @State private var showFlaggedToast = false
    @State private var flaggedSuggestion: String = ""
    @State private var showPaywall = false
    @State private var showVoicePanel = true
    @State private var liveKitToken: String?
    @State private var liveKitServerUrl: String?
    
    @State private var haptic = UIImpactFeedbackGenerator(style: .light)
    
    init(room: Room? = nil) {
        self.room = room
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Voice/Video Panel (Collapsible or persistent)
                if let roomName = room?.name, let token = liveKitToken, let serverUrl = liveKitServerUrl {
                    if showVoicePanel {
                        VoiceVideoPanelView(roomName: roomName, token: token, serverUrl: serverUrl)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .transition(.move(edge: .top))
                    }
                } else if room != nil {
                    // Join Audio Button Area
                    Button(action: joinVoiceRoom) {
                        HStack {
                            Image(systemName: "waveform")
                            Text("Join Voice")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(16)
                    }
                    .padding(.top, 8)
                }
                
                // Message list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                        }
                    }
                    .padding()
                }
                
                // AI feedback toast
                if showFlaggedToast {
                    HStack {
                        Text("AI: \(flaggedSuggestion)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                // Input area (using ChatInputView)
                ChatInputView(
                    onSend: sendMessage,
                    onFlagged: { suggestion in
                        flaggedSuggestion = suggestion
                        withAnimation { showFlaggedToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { showFlaggedToast = false }
                        }
                    },
                    onFileSelect: uploadFile
                )
            }
            .navigationTitle(room?.name ?? "Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if liveKitToken != nil {
                        Button(action: { withAnimation { showVoicePanel.toggle() } }) {
                            Image(systemName: showVoicePanel ? "mic.fill" : "mic.slash")
                                .foregroundColor(showVoicePanel ? .green : .secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                SubscriptionView()
            }
        }
        .task {
            if let roomId = room?.id {
                viewModel.loadRoom(id: roomId)
                // Auto-fetch token if desired, or wait for user action
            }
        }
    }
    
    // MARK: - Actions
    
    private func sendMessage(_ content: String) {
        guard let room = room else { return }
        
        // Check entitlement
        if !subManager.hasEntitlement(for: "pro_monthly") && !subManager.hasEntitlement(for: "pro_annual") {
            // Simple check - for MVP we might allow free users to chat but limit features
            // For now, keep existing logic but maybe relax it for basic chat
            // showPaywall = true 
            // return
        }
        
        Task {
            do {
                guard let session = SupabaseAuthService.shared.currentSession,
                      let userId = UUID(uuidString: session.userId) else { return }
                
                let message = Message(
                    id: UUID(),
                    senderId: userId,
                    content: content,
                    type: "text",
                    timestamp: Date(),
                    emotion: nil,
                    renderedHTML: nil,
                    reactions: nil,
                    seenAt: nil
                )
                
                try await MessageService.sendMessage(message, to: room)
            } catch {
                print("Failed to send message: \(error)")
            }
        }
    }
    
    private func uploadFile(_ data: Data) {
        guard let room = room else { return }
        Task {
            do {
                // 1. Upload File
                let filename = "upload-\(UUID().uuidString).jpg" // Assume image for MVP
                let url = try await FileService.shared.uploadFile(
                    data: data,
                    filename: filename,
                    mimeType: "image/jpeg"
                )
                
                // 2. Send Message with Image URL
                guard let session = SupabaseAuthService.shared.currentSession,
                      let userId = UUID(uuidString: session.userId) else { return }
                
                // Use a special message type or markdown for image
                let content = "![Image](\(url))" 
                
                let message = Message(
                    id: UUID(),
                    senderId: userId,
                    content: content,
                    type: "image", // Use image type
                    timestamp: Date(),
                    emotion: nil,
                    renderedHTML: nil,
                    reactions: nil,
                    seenAt: nil
                )
                
                try await MessageService.sendMessage(message, to: room)
                
            } catch {
                print("Failed to upload file: \(error)")
            }
        }
    }
    
    private func joinVoiceRoom() {
        guard let roomId = room?.id.uuidString, let roomName = room?.name else { return }
        
        Task {
            do {
                // Call backend to get LiveKit token and server URL
                // Endpoint: POST /video/join
                let response: VideoJoinResponse = try await APIClient.shared.request(
                    endpoint: "/video/join",
                    method: "POST",
                    body: [
                        "roomName": roomName,
                        "userName": "User" // TODO: Get from user profile
                    ]
                )
                
                await MainActor.run {
                    self.liveKitToken = response.token
                    self.liveKitServerUrl = response.serverUrl
                    self.showVoicePanel = true
                }
            } catch {
                print("Failed to join voice room: \(error)")
            }
        }
    }
}

struct VideoJoinResponse: Codable {
    let token: String
    let roomName: String
    let serverUrl: String
}


#Preview {
    ChatView()
}
