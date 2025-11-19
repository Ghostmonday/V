import SwiftUI
import PhotosUI

/// Chat Input View
/// Migrated from src/components/ChatInput.vue
/// Text input with slash command detection, bot autocomplete, and file upload
struct ChatInputView: View {
    @State private var input: String = ""
    @State private var showCommands: Bool = false
    @State private var commands: [BotCommand] = []
    @FocusState private var isFocused: Bool
    @State private var haptic = UIImpactFeedbackGenerator(style: .medium)
    
    // File selection state
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    
    let onSend: ((String) -> Void)?
    let onFlagged: ((String) -> Void)? // Callback for flagged messages
    let onFileSelect: ((Data) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Command suggestions overlay
            if showCommands && !commands.isEmpty {
                commandSuggestionsView
            }
            
            // Main Input Bar
            HStack(spacing: 12) {
                // File Upload Button
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "paperclip.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Upload file")
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            onFileSelect?(data)
                            selectedItem = nil // Reset
                        }
                    }
                }
                
                // Text Input
                TextField("Type a message...", text: $input)
                    .focused($isFocused)
                    .textFieldStyle(.plain)
                    .font(.body) // Dynamic Type support
                    .padding(10)
                    .background(
                        GlassView(material: .ultraThin, tint: .light, border: .subtle, cornerRadius: 20, shadow: false, padding: 0) { Color.clear }
                    )
                    .onChange(of: input) { _, newValue in
                        handleInputChange(newValue)
                    }
                    .onSubmit {
                        handleSend()
                    }
                    .accessibilityLabel("Message input")
                    .accessibilityHint("Type your message or use slash commands")
                
                // Send Button
                Button(action: handleSend) {
                    Image(systemName: input.isEmpty ? "circle" : "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(input.isEmpty ? .secondary : Color("VibeZGold"))
                }
                .disabled(input.isEmpty)
                .accessibilityLabel("Send message")
                .accessibilityHint(input.isEmpty ? "Enter a message first" : "Double tap to send")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
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
        .background(
            GlassView(material: .thin, tint: .none, border: .subtle, cornerRadius: 8, shadow: true, padding: 0) { Color.clear }
        )
        .padding(.bottom, 8)
        .padding(.horizontal)
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
            // Get current user ID from Supabase session
            guard let session = SupabaseAuthService.shared.currentSession,
                  let userId = UUID(uuidString: session.userId) else {
                print("[ChatInput] No auth session available")
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
            },
            onFileSelect: { _ in
                print("File Selected")
            }
        )
        .padding()
    }
}
