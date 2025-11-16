import Foundation

struct Message: Codable, Identifiable {
    let id: UUID
    let senderId: UUID
    let content: String
    let type: String // "voice" or "text"
    let timestamp: Date
    let emotion: String? /// UX: For resonance layers
    let renderedHTML: String? /// Rendered HTML/Markdown for mentions and formatting
    let reactions: [MessageReaction]? /// Emoji reactions
    let seenAt: Date? /// Read receipt timestamp
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case content
        case type
        case timestamp
        case emotion
        case renderedHTML = "rendered_html"
        case reactions
        case seenAt = "seen_at"
    }
    
    /// Check if message is from current user
    var isOwn: Bool {
        // TODO: Compare with actual current user ID from AuthService
        return false // Placeholder
    }
}

struct MessageReaction: Codable, Identifiable {
    let id: UUID
    let emoji: String
    let count: Int
    let userIds: [UUID]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case emoji
        case count
        case userIds = "user_ids"
    }
}

// Request/Response DTOs
struct SendMessageRequest: Codable {
    let roomId: String
    let senderId: String
    let content: String
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case roomId = "roomId"
        case senderId = "senderId"
        case content
        case type
    }
}

