import SwiftUI

/// Thread View
/// Migrated from src/components/ThreadView.vue
/// Displays threaded messages with reactions and emoji picker
struct ThreadView: View {
    let threadId: String
    
    @State private var messages: [Message] = []
    @State private var showEmojiPicker: Bool = false
    @State private var selectedMessageId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(messages) { message in
                        messageRow(message)
                    }
                }
                .padding()
            }
            
            // Emoji picker
            if showEmojiPicker {
                EmojiPickerView { emoji in
                    handleEmojiSelect(emoji)
                }
                .transition(.move(edge: .bottom))
            }
        }
        .task {
            await loadThread()
        }
        .onChange(of: threadId) { _, _ in
            Task {
                await loadThread()
            }
        }
    }
    
    @ViewBuilder
    private func messageRow(_ message: Message) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Message bubble
            MessageBubbleView(message: message)
            
            // Reactions
            if let reactions = message.reactions, !reactions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(reactions) { reaction in
                        reactionButton(reaction, messageId: message.id)
                    }
                    
                    // Add reaction button
                    Button(action: {
                        selectedMessageId = message.id
                        withAnimation {
                            showEmojiPicker.toggle()
                        }
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            } else {
                // No reactions yet - show add button
                Button(action: {
                    selectedMessageId = message.id
                    withAnimation {
                        showEmojiPicker.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "face.smiling")
                            .font(.caption)
                        Text("React")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func reactionButton(_ reaction: MessageReaction, messageId: UUID) -> some View {
        Button(action: {
            addReaction(to: messageId, emoji: reaction.emoji)
        }) {
            HStack(spacing: 4) {
                Text(reaction.emoji)
                    .font(.caption)
                Text("\(reaction.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Methods
    
    private func loadThread() async {
        do {
            guard let url = URL(string: "\(APIClient.baseURL)/api/threads/\(threadId)") else { return }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ThreadResponse.self, from: data)
            
            await MainActor.run {
                self.messages = response.recentMessages ?? []
            }
            
            // Log telemetry
            UXTelemetryService.logThreadCreated(
                threadId: threadId,
                metadata: ["messageCount": messages.count]
            )
        } catch {
            print("[ThreadView] Error loading thread: \(error)")
            UXTelemetryService.logAPIFailure(
                endpoint: "/api/threads/\(threadId)",
                statusCode: 0,
                metadata: ["error": error.localizedDescription]
            )
        }
    }
    
    private func addReaction(to messageId: UUID, emoji: String) {
        Task {
            do {
                guard let url = URL(string: "\(APIClient.baseURL)/api/reactions") else { return }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body = ReactionRequest(messageId: messageId.uuidString, emoji: emoji)
                request.httpBody = try JSONEncoder().encode(body)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    // Reload thread to get updated reactions
                    await loadThread()
                    
                    UXTelemetryService.logClick(
                        componentId: "Thread-Reaction",
                        metadata: ["emoji": emoji, "messageId": messageId.uuidString]
                    )
                }
            } catch {
                print("[ThreadView] Error adding reaction: \(error)")
            }
        }
    }
    
    private func handleEmojiSelect(_ emoji: String) {
        guard let messageId = selectedMessageId else { return }
        
        addReaction(to: messageId, emoji: emoji)
        
        withAnimation {
            showEmojiPicker = false
        }
        selectedMessageId = nil
    }
}

// MARK: - Supporting Types

private struct ThreadResponse: Codable {
    let recentMessages: [Message]?
    
    enum CodingKeys: String, CodingKey {
        case recentMessages = "recent_messages"
    }
}

private struct ReactionRequest: Codable {
    let messageId: String
    let emoji: String
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case emoji
    }
}

#Preview {
    ThreadView(threadId: UUID().uuidString)
}

