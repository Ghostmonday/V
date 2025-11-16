import SwiftUI

/// Chat view with message send and AI feedback
struct ChatView: View {
    let room: Room?
    @StateObject private var viewModel = RoomViewModel()
    @StateObject private var subManager = SubscriptionManager.shared
    @State private var input: String = ""
    @State private var showFlaggedToast = false
    @State private var flaggedSuggestion: String = ""
    @State private var showPaywall = false
    @State private var haptic = UIImpactFeedbackGenerator(style: .light)
    
    init(room: Room? = nil) {
        self.room = room
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                
                // Input area
                HStack(spacing: 12) {
                    TextField("Message...", text: $input)
                        .textFieldStyle(.roundedBorder)
                        .font(.body) // Dynamic Type support
                        .accessibilityLabel("Message input")
                        .accessibilityHint("Type your message here")
                    
                    Button("Send") {
                        // Check entitlement before sending AI message
                        if !subManager.hasEntitlement(for: "pro_monthly") && !subManager.hasEntitlement(for: "pro_annual") {
                            showPaywall = true
                            return
                        }
                        sendMessage()
                        haptic.impactOccurred()
                        withAnimation(.easeOut(duration: 0.4)) {
                            showFlaggedToast = false // Trigger glow animation
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("VibeZGold"))
                    .disabled(input.isEmpty)
                    .accessibilityLabel("Send message")
                    .accessibilityHint(input.isEmpty ? "Message cannot be empty" : "Double tap to send")
                    .accessibilityAddTraits(.isButton)
                    .overlay(
                        Circle()
                            .fill(Color("VibeZGlow"))
                            .frame(width: 60, height: 60)
                            .scaleEffect(input.isEmpty ? 0.01 : 0.8)
                            .opacity(input.isEmpty ? 0 : 0.3)
                            .animation(.easeOut(duration: 0.4), value: input.isEmpty)
                    )
                }
                .padding()
            }
            .navigationTitle(room?.name ?? "Chat")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) {
                SubscriptionView()
            }
        }
        .task {
            if let roomId = room?.id {
                viewModel.loadRoom(id: roomId)
            }
        }
    }
    
    private func sendMessage() {
        guard !input.isEmpty, let room = room else { return }
        
        let messageText = input
        input = ""
        
        Task {
            do {
                // Get current user ID from auth token
                guard let userId = AuthTokenManager.shared.token.flatMap({ token in
                    // Extract user ID from JWT token (simplified - in production, decode JWT properly)
                    // For now, use a placeholder UUID - should be extracted from token claims
                    return UUID() // TODO: Extract from JWT claims
                }) else {
                    print("Failed to get user ID")
                    return
                }
                
                // Create message object
                let message = Message(
                    id: UUID(),
                    senderId: userId,
                    content: messageText,
                    type: "text",
                    timestamp: Date(),
                    emotion: nil,
                    renderedHTML: nil,
                    reactions: nil,
                    seenAt: nil
                )
                
                // Send message via MessageService
                try await MessageService.sendMessage(message, to: room)
                
                // Check for moderation flags in response (if API returns moderation info)
                // Note: Backend moderation happens server-side, but we can check response
                // For now, moderation warnings come via WebSocket or separate API call
                
            } catch {
                print("Failed to send message: \(error)")
                // Check if error contains moderation info
                if let errorMessage = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String,
                   errorMessage.contains("moderation") || errorMessage.contains("flagged") {
                    flaggedSuggestion = "Please keep conversations respectful"
                    withAnimation {
                        showFlaggedToast = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showFlaggedToast = false
                        }
                    }
                }
            }
        }
    }
}


#Preview {
    ChatView()
}
