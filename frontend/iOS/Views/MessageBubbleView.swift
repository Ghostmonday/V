import SwiftUI

/// Message Bubble View
/// Migrated from src/components/MessageBubble.vue
/// Displays a message with support for rendered HTML/Markdown and mentions
struct MessageBubbleView: View {
    let message: Message
    
    private var currentUserId: UUID {
        getCurrentUserId()
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                // Message content with AttributedString for HTML/Markdown rendering
                if let rendered = message.renderedHTML, !rendered.isEmpty {
                    Text(parseHTML(rendered))
                        .font(.body)
                } else {
                    Text(message.content)
                        .font(.body)
                }
            }
            .padding(12)
            .background(bubbleBackground)
            .foregroundColor(message.senderId == getCurrentUserId() ? .black : .white)
            .cornerRadius(12)
            
            // Read receipt indicator for own messages
            // TODO: Add ReadReceiptIndicator.swift to Xcode project, then uncomment:
            // if message.senderId == getCurrentUserId() {
            //     ReadReceiptIndicator(message: message, currentUserId: currentUserId)
            //         .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
            // }
        }
    }
    
    private var bubbleBackground: some View {
        Group {
            if message.senderId == getCurrentUserId() {
                // Outgoing (user) - golden vibez
                Color("VibeZGold")
            } else if message.senderId.uuidString == "system" || message.type == "ai" {
                // AI responses - subtle golden gradient
                LinearGradient(
                    colors: [
                        Color("VibeZGold").opacity(0.15),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                // Incoming (others) - subtle white
                Color.white.opacity(0.12)
            }
        }
    }
    
    // MARK: - HTML/Markdown Parsing
    
    private func parseHTML(_ html: String) -> AttributedString {
        // Basic HTML to AttributedString conversion
        // Handles mentions styling: <span class="mention">@username</span>
        
        if let data = html.data(using: .utf8),
           let attributed = try? NSAttributedString(
               data: data,
               options: [
                   .documentType: NSAttributedString.DocumentType.html,
                   .characterEncoding: String.Encoding.utf8.rawValue
               ],
               documentAttributes: nil
           ) {
            var attributedString = AttributedString(attributed)
            
            // Apply mention styling - golden vibez theme
            if let range = attributedString.range(of: "@") {
                attributedString[range].foregroundColor = Color("VibeZGold")
                attributedString[range].font = .body.bold()
            }
            
            return attributedString
        }
        
        return AttributedString(html)
    }
    
    private func getCurrentUserId() -> UUID {
        // Get user ID from Supabase session
        if let session = SupabaseAuthService.shared.currentSession,
           let userId = UUID(uuidString: session.userId) {
            return userId
        }
        return UUID() // Fallback
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubbleView(message: Message(
            id: UUID(),
            senderId: UUID(),
            content: "Hello, this is a test message!",
            type: "text",
            timestamp: Date(),
            emotion: "neutral",
            renderedHTML: nil,
            reactions: nil,
            seenAt: nil
        ))
        
        MessageBubbleView(message: Message(
            id: UUID(),
            senderId: UUID(),
            content: "Message with <span class=\"mention\">@username</span>",
            type: "text",
            timestamp: Date(),
            emotion: "neutral",
            renderedHTML: "Message with <span class=\"mention\">@username</span>",
            reactions: nil,
            seenAt: nil
        ))
    }
    .padding()
}

