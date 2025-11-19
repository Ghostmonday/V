/**
 * Glass View Component
 * 
 * Reusable glass container view for consistent glass polymorphism
 * Use this for panels, cards, and overlays that need glass effects
 */

import SwiftUI

/// Glass container view with customizable content
public struct GlassView<Content: View>: View {
    let material: GlassMaterial
    let tint: GlassTint
    let border: GlassBorder
    let cornerRadius: CGFloat
    let shadow: Bool
    let padding: CGFloat
    let content: Content
    
    public init(
        material: GlassMaterial = .regular,
        tint: GlassTint = .none,
        border: GlassBorder = .subtle,
        cornerRadius: CGFloat = 16,
        shadow: Bool = true,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.material = material
        self.tint = tint
        self.border = border
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.padding = padding
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(padding)
            .glass(
                material: material,
                tint: tint,
                border: border,
                cornerRadius: cornerRadius,
                shadow: shadow
            )
    }
}

// MARK: - Convenience Factory

@MainActor
public enum Glass {
    /// Glass card variant
    public static func card<Content: View>(
        tint: GlassTint = .none,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) -> GlassView<Content> {
        GlassView(
            material: .thin,
            tint: tint,
            border: .subtle,
            cornerRadius: 16,
            shadow: true,
            padding: padding,
            content: content
        )
    }
    
    /// Glass panel variant (for voice/video)
    public static func panel<Content: View>(
        tint: GlassTint = .brand,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) -> GlassView<Content> {
        GlassView(
            material: .thick,
            tint: tint,
            border: .glow(Color("VibeZGold")),
            cornerRadius: 20,
            shadow: true,
            padding: padding,
            content: content
        )
    }
    
    /// Glass input variant
    public static func input<Content: View>(
        tint: GlassTint = .light,
        padding: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) -> GlassView<Content> {
        GlassView(
            material: .ultraThin,
            tint: tint,
            border: .subtle,
            cornerRadius: 20,
            shadow: false,
            padding: padding,
            content: content
        )
    }
}

// MARK: - Previews

#Preview("Glass Card") {
    GlassView(
        material: .thin,
        tint: .none,
        border: .subtle,
        cornerRadius: 16,
        shadow: true
    ) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Room Name")
                .font(.headline)
            Text("Last message preview...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}

#Preview("Glass Panel") {
    GlassView(
        material: .thick,
        tint: .brand,
        border: .glow(Color("VibeZGold")),
        cornerRadius: 20,
        shadow: true
    ) {
        HStack {
            Image(systemName: "mic.fill")
                .foregroundColor(.white)
            Text("Voice Active")
                .foregroundColor(.white)
        }
    }
    .padding()
    .background(Color.black)
}

#Preview("Glass Input") {
    GlassView(
        material: .ultraThin,
        tint: .light,
        border: .subtle,
        cornerRadius: 20,
        shadow: false
    ) {
        TextField("Type a message...", text: .constant(""))
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}

