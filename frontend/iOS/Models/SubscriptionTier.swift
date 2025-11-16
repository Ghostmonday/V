import Foundation

/// Subscription Tier Model
/// Based on PRICING_TIERS.md: Starter ($9), Professional ($29), Enterprise ($99)
enum SubscriptionTier: String, Codable, CaseIterable {
    case starter = "STARTER"
    case professional = "PROFESSIONAL"
    case enterprise = "ENTERPRISE"
    
    var displayName: String {
        switch self {
        case .starter: return "Starter"
        case .professional: return "Pro"
        case .enterprise: return "Enterprise"
        }
    }
    
    var monthlyPrice: Double {
        switch self {
        case .starter: return 9.0
        case .professional: return 29.0
        case .enterprise: return 99.0
        }
    }
    
    var productId: String {
        switch self {
        case .starter: return "com.vibez.starter.monthly"
        case .professional: return "com.vibez.pro.monthly"
        case .enterprise: return "com.vibez.enterprise.monthly"
        }
    }
    
    var color: String {
        switch self {
        case .starter: return "#9E9E9E" // Gray
        case .professional: return "#2196F3" // Blue
        case .enterprise: return "#FFD700" // Gold
        }
    }
    
    var icon: String {
        switch self {
        case .starter: return "star.fill"
        case .professional: return "crown.fill"
        case .enterprise: return "sparkles"
        }
    }
    
    // Feature gates based on PRICING_TIERS.md
    var maxDailyTokens: Int {
        switch self {
        case .starter: return 50_000 // ~$5/day
        case .professional: return 250_000 // ~$25/day
        case .enterprise: return 1_000_000 // ~$100/day
        }
    }
    
    var maxResponseLength: Int {
        switch self {
        case .starter: return 500
        case .professional: return 1_500
        case .enterprise: return 4_000
        }
    }
    
    var availableModels: [String] {
        switch self {
        case .starter: return ["gpt-3.5-turbo"]
        case .professional: return ["gpt-3.5-turbo", "gpt-4"]
        case .enterprise: return ["gpt-3.5-turbo", "gpt-4", "deepseek-chat", "claude-3"]
        }
    }
    
    var maxAssistants: Int {
        switch self {
        case .starter: return 1
        case .professional: return 5
        case .enterprise: return Int.max // Unlimited
        }
    }
    
    var autonomyLevel: AutonomyLevel {
        switch self {
        case .starter: return .disabled
        case .professional: return .recommendations
        case .enterprise: return .fullAuto
        }
    }
    
    var canCreateABTests: Bool {
        switch self {
        case .starter: return false
        case .professional: return true
        case .enterprise: return true
        }
    }
    
    var maxABTests: Int {
        switch self {
        case .starter: return 0
        case .professional: return 5
        case .enterprise: return Int.max
        }
    }
    
    var hasEmotionalMonitoring: Bool {
        return true // All tiers have basic monitoring
    }
    
    var hasAdvancedEmotionalMonitoring: Bool {
        switch self {
        case .starter: return false
        case .professional: return true
        case .enterprise: return true
        }
    }
    
    var hasPredictiveAnalytics: Bool {
        return self == .enterprise
    }
    
    var hasCustomEmbeddings: Bool {
        return self == .enterprise
    }
    
    var hasPrioritySupport: Bool {
        return self == .enterprise
    }
}

/// Autonomy Level Enum
enum AutonomyLevel: String, Codable {
    case disabled = "DISABLED"
    case recommendations = "RECOMMENDATIONS"
    case fullAuto = "FULL_AUTO"
}

/// Feature Gate Utilities
struct FeatureGate {
    /// Check if user can access a feature based on tier
    static func canAccess(_ feature: Feature, tier: SubscriptionTier) -> Bool {
        switch feature {
        case .abTesting:
            return tier.canCreateABTests
        case .advancedEmotionalMonitoring:
            return tier.hasAdvancedEmotionalMonitoring
        case .predictiveAnalytics:
            return tier.hasPredictiveAnalytics
        case .customEmbeddings:
            return tier.hasCustomEmbeddings
        case .prioritySupport:
            return tier.hasPrioritySupport
        case .autonomyExecutor:
            return tier.autonomyLevel != .disabled
        case .fullAutonomy:
            return tier.autonomyLevel == .fullAuto
        case .multipleAssistants:
            return tier.maxAssistants > 1
        case .gpt4Access:
            return tier.availableModels.contains("gpt-4")
        case .enterpriseModels:
            return tier.availableModels.contains("deepseek-chat") || tier.availableModels.contains("claude-3")
        }
    }
    
    /// Get upgrade message for locked feature
    static func upgradeMessage(for feature: Feature) -> String {
        switch feature {
        case .abTesting:
            return "Upgrade to Pro to create A/B tests"
        case .advancedEmotionalMonitoring:
            return "Upgrade to Pro for real-time emotional curves"
        case .predictiveAnalytics:
            return "Upgrade to Enterprise for predictive analytics"
        case .customEmbeddings:
            return "Upgrade to Enterprise for custom embeddings"
        case .prioritySupport:
            return "Upgrade to Enterprise for priority support"
        case .autonomyExecutor:
            return "Upgrade to Pro to enable automation"
        case .fullAutonomy:
            return "Upgrade to Enterprise for fully autonomous operations"
        case .multipleAssistants:
            return "Upgrade to Pro for multiple AI assistants"
        case .gpt4Access:
            return "Upgrade to Pro for GPT-4 access"
        case .enterpriseModels:
            return "Upgrade to Enterprise for DeepSeek and Claude models"
        }
    }
}

/// Feature Enum
enum Feature: String, Codable {
    case abTesting = "A/B_TESTING"
    case advancedEmotionalMonitoring = "ADVANCED_EMOTIONAL_MONITORING"
    case predictiveAnalytics = "PREDICTIVE_ANALYTICS"
    case customEmbeddings = "CUSTOM_EMBEDDINGS"
    case prioritySupport = "PRIORITY_SUPPORT"
    case autonomyExecutor = "AUTONOMY_EXECUTOR"
    case fullAutonomy = "FULL_AUTONOMY"
    case multipleAssistants = "MULTIPLE_ASSISTANTS"
    case gpt4Access = "GPT4_ACCESS"
    case enterpriseModels = "ENTERPRISE_MODELS"
}

