import Foundation

@MainActor
class MessageManager {
    static let shared = MessageManager()
    
    func sendVoiceMessage(data: Data, to room: Room) async {
        // AI transcription service removed - placeholder for future implementation
        let transcript = "Voice message transcription not available"
        let message = Message(
            id: UUID(),
            senderId: UUID(), // TODO: Get from authenticated user
            content: transcript,
            type: "voice",
            timestamp: Date(),
            emotion: "neutral",
            renderedHTML: nil,
            reactions: nil,
            seenAt: nil
        )
        try? await MessageService.sendMessage(message, to: room)
    }
}

