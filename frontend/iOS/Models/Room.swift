import Foundation

struct Room: Codable, Identifiable {
    let id: UUID
    let name: String?
    let owner_id: UUID?
    let is_public: Bool?
    let users: [User]?
    let maxOrbs: Int? /// UX: Organic scalability limit
    let activityLevel: String? /// UX: Triggers ambient feedback
    
    // New tier and moderation fields
    let room_tier: String? // "free", "pro", "enterprise"
    let ai_moderation: Bool?
    let expires_at: String? // ISO timestamp for temp rooms
    let is_self_hosted: Bool? // Custom field for self-hosted indicator
    
    // Backend response mapping
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case owner_id
        case is_public
        case users
        case maxOrbs = "max_orbs"
        case activityLevel = "activity_level"
        case room_tier
        case ai_moderation
        case expires_at
        case is_self_hosted
    }
    
    // Computed properties
    var isTemp: Bool {
        room_tier == "pro" && expires_at != nil
    }
    
    var isModerated: Bool {
        ai_moderation == true
    }
    
    var timeUntilExpiry: TimeInterval? {
        guard let expiresAt = expires_at,
              let expiryDate = ISO8601DateFormatter().date(from: expiresAt) else {
            return nil
        }
        return expiryDate.timeIntervalSinceNow
    }
    
    var expiryCountdown: String? {
        guard let timeUntil = timeUntilExpiry, timeUntil > 0 else {
            return nil
        }
        let hours = Int(timeUntil / 3600)
        let minutes = Int((timeUntil.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
}

// Backend API response wrapper
struct RoomsResponse: Codable {
    let status: String
    let rooms: [Room]
}

struct RoomResponse: Codable {
    let status: String
    let room: Room
}

