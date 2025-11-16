/**
 * Design System - Button Components
 * 
 * Comprehensive button system with multiple variants, sizes, and states.
 * Improved accessibility and haptic feedback.
 */

import SwiftUI

// MARK: - Button Variants

enum DSButtonVariant {
    case primary
    case secondary
    case tertiary
    case danger
    case ghost
}

enum DSButtonSize {
    case small
    case medium
    case large
    
    var height: CGFloat {
        switch self {
        case .small: return 32
        case .medium: return 44
        case .large: return 52
        }
    }
    
    var fontSize: Font {
        switch self {
        case .small: return DSTypography.labelSmall
        case .medium: return DSTypography.label
        case .large: return DSTypography.labelLarge
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small: return DSSpacing.md
        case .medium: return DSSpacing.base
        case .large: return DSSpacing.xl
        }
    }
}

// MARK: - Primary Button

struct DSPrimaryButton: View {
    let title: String
    let icon: String?
    let size: DSButtonSize
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        _ title: String,
        icon: String? = nil,
        size: DSButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            DSHaptic.light()
            action()
        }) {
            HStack(spacing: DSSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(size.fontSize)
                }
                Text(title)
                    .font(size.fontSize)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.ds(.textInverse))
            .frame(height: size.height)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, size.horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.base, style: .continuous)
                    .fill(Color.ds(.brandPrimary))
                    .opacity(isPressed ? 0.8 : 1.0)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(DSAnimation.spring, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Secondary Button

struct DSSecondaryButton: View {
    let title: String
    let icon: String?
    let size: DSButtonSize
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        _ title: String,
        icon: String? = nil,
        size: DSButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            DSHaptic.light()
            action()
        }) {
            HStack(spacing: DSSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(size.fontSize)
                }
                Text(title)
                    .font(size.fontSize)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.ds(.brandPrimary))
            .frame(height: size.height)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, size.horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.base, style: .continuous)
                    .fill(Color.ds(.controlFill))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.base, style: .continuous)
                            .stroke(Color.ds(.controlStroke), lineWidth: 1)
                    )
            )
            .opacity(isPressed ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(DSAnimation.spring, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Icon Button

struct DSIconButton: View {
    let icon: String
    let size: DSButtonSize
    let variant: DSButtonVariant
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        icon: String,
        size: DSButtonSize = .medium,
        variant: DSButtonVariant = .tertiary,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.variant = variant
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            DSHaptic.light()
            action()
        }) {
            Image(systemName: icon)
                .font(size.fontSize)
                .foregroundColor(foregroundColor)
                .frame(width: size.height, height: size.height)
                .background(backgroundColor)
                .clipShape(Circle())
                .opacity(isPressed ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(DSAnimation.spring, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary: return .ds(.textInverse)
        case .secondary, .tertiary, .ghost: return .ds(.textPrimary)
        case .danger: return .ds(.stateDanger)
        }
    }
    
    private var backgroundColor: Color {
        switch variant {
        case .primary: return .ds(.brandPrimary)
        case .secondary: return .ds(.controlFill)
        case .tertiary, .ghost: return .clear
        case .danger: return .ds(.stateDanger).opacity(0.1)
        }
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Apply button style with design system
    func dsButton(variant: DSButtonVariant = .primary, size: DSButtonSize = .medium) -> some View {
        // This is a placeholder - actual implementation uses the button components above
        self
    }
}

