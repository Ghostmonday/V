import SwiftUI

/// Chat Input View
/// Migrated from src/components/ChatInput.vue
/// Text input with slash command detection and bot autocomplete
struct ChatInputView: View {
    @State private var input: String = ""
    @State private var showCommands: Bool = false
    @State private var commands: [BotCommand] = []
    @FocusState private var isFocused: Bool
    @State private var haptic = UIImpactFeedbackGenerator(style: .medium)
    
    let onSend: ((String) -> Void)?
    let onFlagged: ((String) -> Void)? // Callback for flagged messages
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Command suggestions overlay
            if showCommands && !commands.isEmpty {
                commandSuggestionsView
            }
            
            // Text input
            HStack {
                TextField("Type a message...", text: $input)
                    .focused($isFocused)
                    .textFieldStyle(.plain)
                    .font(.body) // Dynamic Type support
                    .padding(12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(20)
                    .onChange(of: input) { oldValue, newValue in
                        handleInputChange(newValue)
                    }
                    .onSubmit {
                        handleSend()
                    }
                    .accessibilityLabel("Message input")
                    .accessibilityHint("Type your message or use slash commands")
                
                Button(action: handleSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color("VibeZGold"))
                }
                .disabled(input.isEmpty)
                .accessibilityLabel("Send message")
                .accessibilityHint(input.isEmpty ? "Enter a message first" : "Double tap to send")
                .accessibilityAddTraits(.isButton)
                .overlay(
                    Circle()
                        .fill(Color("VibeZGlow"))
                        .frame(width: 40, height: 40)
                        .scaleEffect(input.isEmpty ? 0.01 : 0.7)
                        .opacity(input.isEmpty ? 0 : 0.3)
                        .animation(.easeOut(duration: 0.4), value: input.isEmpty)
                )
            }
        }
    }
    
    private var commandSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(commands) { command in
                Button(action: {
                    selectCommand(command)
                }) {
                    HStack {
                        Text(command.command)
                            .font(.body.monospaced())
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(command.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 4)
        .padding(.bottom, 8)
    }
    
    // MARK: - Methods
    
    private func handleInputChange(_ newValue: String) {
        // Detect slash command
        if newValue.hasPrefix("/") {
            Task {
                await loadBotCommands()
            }
        } else {
            showCommands = false
        }
        
        // Log typing events
        if newValue.isEmpty {
            UXTelemetryService.logTypingStop()
        } else if input.isEmpty {
            UXTelemetryService.logTypingStart()
        }
    }
    
    private func loadBotCommands() async {
        do {
            guard let url = URL(string: "\(APIClient.baseURL)/api/bots/commands") else { return }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let fetchedCommands = try JSONDecoder().decode([BotCommand].self, from: data)
            
            await MainActor.run {
                self.commands = fetchedCommands
                self.showCommands = true
            }
        } catch {
            print("[ChatInput] Error loading commands: \(error)")
            UXTelemetryService.logAPIFailure(
                endpoint: "/api/bots/commands",
                statusCode: 0,
                metadata: ["error": error.localizedDescription]
            )
        }
    }
    
    private func selectCommand(_ command: BotCommand) {
        input = command.command
        showCommands = false
        
        UXTelemetryService.logClick(
            componentId: "ChatInput-CommandSuggestion",
            metadata: ["command": command.command]
        )
    }
    
    private func handleSend() {
        guard !input.isEmpty else { return }
        
        let message = input
        
        // Haptic feedback on send
        haptic.impactOccurred()
        
        // Log telemetry
        UXTelemetryService.logClick(
            componentId: "ChatInput-SendButton",
            metadata: ["messageLength": message.count]
        )
        
        // Send command if it's a slash command
        if message.hasPrefix("/") {
            Task {
                await sendCommand(message)
            }
        } else {
            // Check for flagged content (simplified - would call moderation API)
            Task {
                await sendMessage(message)
            }
        }
        
        // Clear input
        input = ""
    }
    
    private func sendMessage(_ message: String) async {
        do {
            // Get current user ID
            guard let userId = AuthTokenManager.shared.token.flatMap({ _ in UUID() }) else {
                print("[ChatInput] No auth token available")
                return
            }
            
            // Call moderation API via Supabase Edge Function
            // First check if message should be moderated
            let moderationResponse: ModerationResponse? = try? await APIClient.shared.request(
                endpoint: "/functions/v1/moderation-check",
                method: "POST",
                body: ["content": message]
            )
            
            if let moderation = moderationResponse, moderation.flagged {
                // Message was flagged - call callback
                onFlagged?(moderation.suggestion ?? "Please keep conversations respectful")
                UXTelemetryService.logValidationError(
                    componentId: "ChatInput-Message",
                    errorType: "moderation_flagged",
                    metadata: ["suggestion": moderation.suggestion ?? ""]
                )
            } else {
                // Message is clean - proceed with send
                onSend?(message)
            }
        } catch {
            print("[ChatInput] Error checking moderation: \(error)")
            // On error, still send message (fail-open for better UX)
            onSend?(message)
        }
    }
    
    private func sendCommand(_ command: String) async {
        do {
            guard let url = URL(string: "\(APIClient.baseURL)/api/bots/slash") else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body = ["command": command]
            request.httpBody = try JSONEncoder().encode(body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                UXTelemetryService.logMessageSendAttempted(metadata: ["type": "slash_command"])
            } else {
                UXTelemetryService.logMessageSendFailed(
                    error: "Invalid response",
                    metadata: ["command": command]
                )
            }
        } catch {
            print("[ChatInput] Error sending command: \(error)")
            UXTelemetryService.logMessageSendFailed(
                error: error.localizedDescription,
                metadata: ["command": command]
            )
        }
    }
}

// MARK: - Supporting Types

struct BotCommand: Codable, Identifiable {
    let id: String
    let command: String
    let description: String
}

struct ModerationResponse: Codable {
    let flagged: Bool
    let suggestion: String?
    let score: Double?
}

#Preview {
    VStack {
        Spacer()
        ChatInputView(
            onSend: { message in
                print("Send: \(message)")
            },
            onFlagged: { suggestion in
                print("Flagged: \(suggestion)")
            }
        )
        .padding()
    }
}

