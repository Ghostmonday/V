import SwiftUI

/// Read Receipt Indicator Component
/// Shows checkmark status for sent messages (delivered/read)
struct ReadReceiptIndicator: View {
    let message: Message
    let currentUserId: UUID
    
    init(message: Message, currentUserId: UUID) {
        self.message = message
        self.currentUserId = currentUserId
    }
    
    var body: some View {
        if message.senderId == currentUserId {
            if let seenAt = message.seenAt {
                // Message has been read
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.caption2)
                    .accessibilityLabel("Read at \(formatTime(seenAt))")
            } else {
                // Message delivered but not read
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.secondary)
                    .font(.caption2)
                    .accessibilityLabel("Delivered")
            }
        } else {
            // Not user's message, no indicator
            EmptyView()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    HStack {
        Text("Hello, this is a test message!")
            .font(.body)
        ReadReceiptIndicator(
            message: Message(
                id: UUID(),
                senderId: UUID(),
                content: "Test",
                type: "text",
                timestamp: Date(),
                emotion: nil,
                renderedHTML: nil,
                reactions: nil,
                seenAt: Date()
            ),
            currentUserId: UUID()
        )
    }
    .padding()
}

