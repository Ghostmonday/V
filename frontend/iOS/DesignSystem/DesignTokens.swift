/**
 * VibeZ Design System - Design Tokens
 * 
 * A comprehensive, production-ready design system with semantic tokens,
 * improved accessibility, and enhanced visual hierarchy.
 * 
 * Improvements over spec:
 * - Enhanced semantic color system with better contrast ratios
 * - Improved typography scale with better line heights
 * - Comprehensive spacing system with semantic names
 * - Enhanced shadow system with multiple elevation levels
 * - Better dark mode support with adaptive colors
 */

import SwiftUI

// MARK: - Color Tokens

/// Design System Color Tokens
/// Semantic color system with light/dark variants
enum DSColor: String, CaseIterable {
    // Backgrounds
    case bgDefault = "bg.default"
    case bgElevated = "bg.elevated"
    case bgOverlay = "bg.overlay"
    case bgCard = "bg.card"
    case bgInput = "bg.input"
    
    // Text
    case textPrimary = "text.primary"
    case textSecondary = "text.secondary"
    case textTertiary = "text.tertiary"
    case textInverse = "text.inverse"
    case textPlaceholder = "text.placeholder"
    
    // Brand
    case brandPrimary = "brand.primary"
    case brandPrimaryHover = "brand.primary.hover"
    case brandPrimaryActive = "brand.primary.active"
    case brandAccent = "brand.accent"
    
    // State Colors
    case stateSuccess = "state.success"
    case stateWarning = "state.warning"
    case stateDanger = "state.danger"
    case stateInfo = "state.info"
    
    // Presence
    case presenceOnline = "presence.online"
    case presenceAway = "presence.away"
    case presenceBusy = "presence.busy"
    case presenceOffline = "presence.offline"
    
    // Controls
    case controlFill = "control.fill"
    case controlStroke = "control.stroke"
    case controlHover = "control.hover"
    case controlDisabled = "control.disabled"
    
    // Special
    case separator = "separator"
    case shimmer = "shimmer"
}

extension Color {
    /// Design System Color Accessor
    /// Returns the semantic color token with automatic light/dark support
    static func ds(_ token: DSColor) -> Color {
        Color(token.rawValue)
    }
    
    /// Convenience initializer for hex colors
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography Tokens

/// Design System Typography
/// Improved typography scale with better line heights and tracking
struct DSTypography {
    // Display (Marketing/Onboarding only)
    static let displayLarge = Font.system(size: 48, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 40, weight: .bold, design: .rounded)
    static let displaySmall = Font.system(size: 34, weight: .bold, design: .rounded)
    
    // Titles
    static let title1 = Font.system(size: 28, weight: .semibold, design: .default)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .default)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
    
    // Body
    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 15, weight: .regular, design: .default)
    
    // Labels
    static let labelLarge = Font.system(size: 15, weight: .semibold, design: .default)
    static let label = Font.system(size: 13, weight: .semibold, design: .default)
    static let labelSmall = Font.system(size: 12, weight: .semibold, design: .default)
    
    // Captions
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let captionSmall = Font.system(size: 11, weight: .regular, design: .default)
    
    // Mono (for code/IDs)
    static let mono = Font.system(size: 14, weight: .regular, design: .monospaced)
    static let monoSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
    
    // Line Heights (for manual text layout)
    static let lineHeightTight: CGFloat = 1.2
    static let lineHeightNormal: CGFloat = 1.5
    static let lineHeightRelaxed: CGFloat = 1.75
}

// MARK: - Spacing Tokens

/// Design System Spacing Scale
/// 4pt base grid system with semantic names
enum DSSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let base: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
    static let hero: CGFloat = 48
    static let section: CGFloat = 64
}

// MARK: - Corner Radius Tokens

/// Design System Corner Radius
/// Consistent rounding across components
enum DSRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let base: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let round: CGFloat = 9999 // Full round
}

// MARK: - Shadow Tokens

/// Design System Shadows
/// Multiple elevation levels for depth hierarchy
enum DSShadow {
    // Subtle shadows for cards
    static let card = Shadow(
        color: .black.opacity(0.08),
        radius: 8,
        x: 0,
        y: 2
    )
    
    // Medium elevation
    static let elevated = Shadow(
        color: .black.opacity(0.12),
        radius: 16,
        x: 0,
        y: 4
    )
    
    // High elevation (sheets/modals)
    static let overlay = Shadow(
        color: .black.opacity(0.24),
        radius: 24,
        x: 0,
        y: 8
    )
    
    // Special: Glow effect for presence/brand
    static let glow = Shadow(
        color: Color.ds(.brandPrimary).opacity(0.4),
        radius: 12,
        x: 0,
        y: 0
    )
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        
        static var card: Shadow { DSShadow.card }
        static var elevated: Shadow { DSShadow.elevated }
        static var overlay: Shadow { DSShadow.overlay }
        static var glow: Shadow { DSShadow.glow }
    }
}

// MARK: - Animation Tokens

/// Design System Animation Durations & Easings
/// Consistent motion language
enum DSAnimation {
    // Durations
    static let instant: CGFloat = 0
    static let fast: CGFloat = 0.1
    static let quick: CGFloat = 0.15
    static let normal: CGFloat = 0.25
    static let slow: CGFloat = 0.35
    static let slower: CGFloat = 0.5
    
    // Easings
    static let easeInOut = Animation.easeInOut(duration: normal)
    static let easeOut = Animation.easeOut(duration: normal)
    static let easeIn = Animation.easeIn(duration: normal)
    
    // Spring animations
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let springBouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    static let springSmooth = Animation.spring(response: 0.3, dampingFraction: 0.9)
}

// MARK: - Icon Tokens

/// Design System Icon Mapping
/// SF Symbols with consistent weights
enum DSIcon {
    // Navigation
    static let home = "house.fill"
    static let search = "magnifyingglass"
    static let profile = "person.crop.circle.fill"
    static let settings = "gearshape.fill"
    
    // Communication
    static let rooms = "bubble.left.and.bubble.right.fill"
    static let threads = "text.bubble.fill"
    static let message = "message.fill"
    static let voice = "waveform"
    static let mic = "mic.fill"
    static let micSlash = "mic.slash.fill"
    
    // Actions
    static let plus = "plus.circle.fill"
    static let send = "arrow.up.circle.fill"
    static let attach = "paperclip"
    static let emoji = "face.smiling"
    static let more = "ellipsis"
    
    // Status
    static let checkmark = "checkmark.circle.fill"
    static let checkmarkCircle = "checkmark.circle"
    static let xmark = "xmark.circle.fill"
    static let warning = "exclamationmark.triangle.fill"
    static let info = "info.circle.fill"
    
    // Presence
    static let presenceOnline = "circle.fill"
    static let presenceAway = "moon.fill"
    static let presenceBusy = "minus.circle.fill"
    
    // Subscription
    static let seal = "seal.fill"
    static let crown = "crown.fill"
    static let sparkles = "sparkles"
    static let star = "star.fill"
    
    // Media
    static let photo = "photo.fill"
    static let video = "video.fill"
    static let play = "play.circle.fill"
    
    // System
    static let chevronRight = "chevron.right"
    static let chevronDown = "chevron.down"
    static let share = "square.and.arrow.up"
}

// MARK: - Haptic Tokens

/// Design System Haptic Feedback
/// Consistent tactile feedback patterns
enum DSHaptic {
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply design system shadow
    func dsShadow(_ shadow: DSShadow.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    /// Apply design system card styling
    func dsCard(radius: CGFloat = DSRadius.md) -> some View {
        self
            .background(Color.ds(.bgCard))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .dsShadow(.card)
    }
    
    /// Apply design system elevated card styling
    func dsElevatedCard(radius: CGFloat = DSRadius.md) -> some View {
        self
            .background(Color.ds(.bgElevated))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .dsShadow(.elevated)
    }
    
    /// Apply design system overlay styling
    func dsOverlay(radius: CGFloat = DSRadius.lg) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .dsShadow(.overlay)
    }
}

