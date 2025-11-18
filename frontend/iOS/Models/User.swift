import Foundation
import SwiftUI

struct User: Codable, Identifiable {
    let id: UUID
    let name: String
    let avatar: String
    let mood: String /// UX: For emotional attunement and tone mirroring
    var presenceStatus: PresenceStatus? /// Presence status (online/offline/away/busy)
    
    enum CodingKeys: String, CodingKey {
        case id, name, avatar, mood
        case presenceStatus = "presence_status"
    }
    
    init(id: UUID, name: String, avatar: String, mood: String, presenceStatus: PresenceStatus? = nil) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.mood = mood
        self.presenceStatus = presenceStatus
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        avatar = try container.decode(String.self, forKey: .avatar)
        mood = try container.decode(String.self, forKey: .mood)
        
        if let statusString = try? container.decode(String.self, forKey: .presenceStatus) {
            presenceStatus = PresenceStatus(rawValue: statusString)
        } else {
            presenceStatus = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(avatar, forKey: .avatar)
        try container.encode(mood, forKey: .mood)
        if let status = presenceStatus {
            try container.encode(status.rawValue, forKey: .presenceStatus)
        }
    }
}

// MARK: - Supabase User Conversion Extension

extension User {
    /// Convert Supabase user data to app User model
    static func from(supabaseUserId: String, email: String?, displayName: String? = nil, avatar: String? = nil) -> User {
        // Use Supabase user ID as UUID (or generate from string)
        let userId: UUID
        if let uuid = UUID(uuidString: supabaseUserId) {
            userId = uuid
        } else {
            // Generate deterministic UUID from Supabase user ID
            let uid = supabaseUserId
            let formattedUID = String(format: "%@-%@-%@-%@-%@",
                String(uid.prefix(8)),
                String(uid.dropFirst(8).prefix(4)),
                String(uid.dropFirst(12).prefix(4)),
                String(uid.dropFirst(16).prefix(4)),
                String(uid.dropFirst(20)))
            userId = UUID(uuidString: formattedUID) ?? UUID()
        }
        
        let name = displayName ?? email?.components(separatedBy: "@").first ?? "User"
        let avatarURL = avatar ?? ""
        
        return User(
            id: userId,
            name: name,
            avatar: avatarURL,
            mood: "calm"
        )
    }
}

