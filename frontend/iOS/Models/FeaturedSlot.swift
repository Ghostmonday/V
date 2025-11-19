import Foundation

struct FeaturedSlot: Identifiable, Codable {
    let id: UUID
    let roomId: UUID
    let tier: FeaturedTier
    let startTime: Date
    let endTime: Date
    let status: FeatureStatus
    
    enum FeatureStatus: String, Codable {
        case active
        case scheduled
        case expired
    }
}

enum FeaturedTier: Int, Codable, CaseIterable {
    case boost = 1
    case spotlight = 2
    case headline = 3
    case takeover = 4
    
    var title: String {
        switch self {
        case .boost: return "Boost"
        case .spotlight: return "Spotlight"
        case .headline: return "Headline"
        case .takeover: return "Takeover"
        }
    }
    
    var duration: TimeInterval {
        switch self {
        case .boost: return 86400 // 24h
        case .spotlight: return 259200 // 3 days
        case .headline: return 604800 // 1 week
        case .takeover: return 86400 // 24h
        }
    }
    
    var price: Decimal {
        switch self {
        case .boost: return 4.99
        case .spotlight: return 19.99
        case .headline: return 99.99
        case .takeover: return 149.99
        }
    }
}

