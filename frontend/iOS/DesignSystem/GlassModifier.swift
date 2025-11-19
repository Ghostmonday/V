/**
 * Glass Polymorphism Modifier System
 * 
 * Creates premium frosted glass effects that surpass Discord and WhatsApp
 * Uses SwiftUI materials with custom blur, tint, and border effects
 * 
 * Competitive Advantage:
 * - Discord: Flat, solid colors → VibeZ: Depth, premium glass
 * - WhatsApp: Simple backgrounds → VibeZ: Modern iOS design language
 */

import SwiftUI

// MARK: - Glass Material Variants

/// Glass material intensity levels
public enum GlassMaterial: CGFloat, CaseIterable {
    case ultraThin = 10.0    // Subtle blur for input fields
    case thin = 20.0         // Standard blur for cards
    case regular = 30.0      // Medium blur for panels
    case thick = 40.0        // Heavy blur for modals
    case frosted = 60.0      // Maximum blur for overlays
    
    /// Material type for SwiftUI
    var material: Material {
        switch self {
        case .ultraThin:
            return .ultraThinMaterial
        case .thin:
            return .thinMaterial
        case .regular:
            return .regularMaterial
        case .thick:
            return .thickMaterial
        case .frosted:
            return .ultraThickMaterial
        }
    }
}

// MARK: - Glass Background Tints

/// Background tint options for glass effects
public enum GlassTint {
    case none
    case light          // White tint (light mode)
    case dark           // Black tint (dark mode)
    case brand          // VibeZGold brand color
    case custom(Color)  // Custom color tint
    
    var color: Color? {
        switch self {
        case .none:
            return nil
        case .light:
            return .white.opacity(0.1)
        case .dark:
            return .black.opacity(0.1)
        case .brand:
            return Color("VibeZGold").opacity(0.1) // Reduced opacity for subtlety
        case .custom(let color):
            return color.opacity(0.1)
        }
    }
}

// MARK: - Glass Border Styles

/// Border styles for glass components
public enum GlassBorder {
    case none
    case subtle         // Gradient border (top-left light, bottom-right dark)
    case standard       // Stronger gradient border
    case glow(Color)    // Colored glow effect
    
    var strokeStyle: (style: AnyShapeStyle, width: CGFloat)? {
        switch self {
        case .none:
            return nil
        case .subtle:
            return (AnyShapeStyle(
                LinearGradient(
                    colors: [.white.opacity(0.3), .white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ), 0.5)
        case .standard:
            return (AnyShapeStyle(
                LinearGradient(
                    colors: [.white.opacity(0.5), .white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ), 1.0)
        case .glow(let color):
            return (AnyShapeStyle(color.opacity(0.5)), 1.5)
        }
    }
}

// MARK: - Glass Modifier

/// Main glass polymorphism modifier
struct GlassModifier: ViewModifier {
    let material: GlassMaterial
    let tint: GlassTint
    let border: GlassBorder
    let cornerRadius: CGFloat
    let shadow: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base material
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(material.material)
                    
                    // Optional tint overlay
                    if let tintColor = tint.color {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tintColor)
                    }
                }
            )
            .overlay(
                // Optional border
                Group {
                    if let stroke = border.strokeStyle {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(stroke.style, lineWidth: stroke.width)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: shadow ? .black.opacity(0.15) : .clear,
                radius: shadow ? 12 : 0,
                x: 0,
                y: shadow ? 6 : 0
            )
    }
}

// MARK: - View Extension

extension View {
    /// Apply glass polymorphism effect
    /// 
    /// - Parameters:
    ///   - material: Blur intensity level
    ///   - tint: Background color tint
    ///   - border: Border style
    ///   - cornerRadius: Corner radius (default: 16)
    ///   - shadow: Enable shadow (default: true)
    /// 
    /// - Returns: Modified view with glass effect
    /// 
    /// Example:
    /// ```swift
    /// Text("Hello")
    ///     .glass(material: .regular, tint: .brand, border: .glow(.gold))
    /// ```
    func glass(
        material: GlassMaterial = .regular,
        tint: GlassTint = .none,
        border: GlassBorder = .subtle,
        cornerRadius: CGFloat = 16,
        shadow: Bool = true
    ) -> some View {
        modifier(GlassModifier(
            material: material,
            tint: tint,
            border: border,
            cornerRadius: cornerRadius,
            shadow: shadow
        ))
    }
    
    /// Quick glass card modifier (common use case)
    func glassCard(
        tint: GlassTint = .none,
        cornerRadius: CGFloat = 16
    ) -> some View {
        glass(
            material: .thin,
            tint: tint,
            border: .subtle,
            cornerRadius: cornerRadius,
            shadow: true
        )
    }
    
    /// Glass input field modifier
    func glassInput(
        tint: GlassTint = .light
    ) -> some View {
        glass(
            material: .ultraThin,
            tint: tint,
            border: .subtle,
            cornerRadius: 20,
            shadow: false
        )
    }
    
    /// Glass panel modifier (for voice/video panels)
    func glassPanel(
        tint: GlassTint = .brand
    ) -> some View {
        glass(
            material: .thick,
            tint: tint,
            border: .glow(Color("VibeZGold")),
            cornerRadius: 20,
            shadow: true
        )
    }
}

// MARK: - Previews

#Preview("Glass Variants") {
    VStack(spacing: 20) {
        Text("Ultra Thin")
            .padding()
            .glass(material: .ultraThin, tint: .light)
        
        Text("Thin")
            .padding()
            .glass(material: .thin, tint: .none)
        
        Text("Regular")
            .padding()
            .glass(material: .regular, tint: .brand)
        
        Text("Thick")
            .padding()
            .glass(material: .thick, tint: .dark)
        
        Text("Frosted")
            .padding()
            .glass(material: .frosted, tint: .brand, border: .glow(.blue))
    }
    .padding()
    .background(
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

#Preview("Glass Card") {
    VStack(alignment: .leading, spacing: 8) {
        Text("Room Name")
            .font(.headline)
            .foregroundColor(.primary)
        Text("Last message preview...")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
    .glassCard(tint: .none)
    .padding()
    .background(Color.gray.opacity(0.2))
}

#Preview("Glass Input") {
    TextField("Type a message...", text: .constant(""))
    .padding()
    .glassInput(tint: .light)
    .padding()
    .background(Color.gray.opacity(0.2))
}

#Preview("Glass Panel") {
    HStack {
        Image(systemName: "mic.fill")
        Text("Voice Active")
    }
    .padding()
    .glassPanel(tint: .brand)
    .padding()
    .background(Color.black)
}
