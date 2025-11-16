/**
 * Design System - Chip Component
 * 
 * Versatile chip component for tags, filters, and quick actions.
 * Supports selection state, icons, and multiple sizes.
 */

import SwiftUI

struct DSChip: View {
    let title: String
    let icon: String?
    let size: DSButtonSize
    let isSelected: Bool
    let action: (() -> Void)?
    
    @State private var isPressed = false
    
    init(
        _ title: String,
        icon: String? = nil,
        size: DSButtonSize = .small,
        isSelected: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Group {
            if let action = action {
                Button(action: {
                    DSHaptic.selection()
                    action()
                }) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(DSAnimation.spring, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    private var content: some View {
        HStack(spacing: DSSpacing.xs) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(size.fontSize)
            }
            Text(title)
                .font(size.fontSize)
                .fontWeight(.medium)
        }
        .foregroundColor(isSelected ? .ds(.textInverse) : .ds(.textPrimary))
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, DSSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                .fill(isSelected ? Color.ds(.brandPrimary) : Color.ds(.controlFill))
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                        .stroke(
                            isSelected ? Color.clear : Color.ds(.controlStroke),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Badge Variant

struct DSBadge: View {
    let text: String
    let variant: BadgeVariant
    
    enum BadgeVariant {
        case default_
        case success
        case warning
        case danger
        case info
        
        var backgroundColor: Color {
            switch self {
            case .default_: return .ds(.controlFill)
            case .success: return .ds(.stateSuccess).opacity(0.2)
            case .warning: return .ds(.stateWarning).opacity(0.2)
            case .danger: return .ds(.stateDanger).opacity(0.2)
            case .info: return .ds(.stateInfo).opacity(0.2)
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .default_: return .ds(.textPrimary)
            case .success: return .ds(.stateSuccess)
            case .warning: return .ds(.stateWarning)
            case .danger: return .ds(.stateDanger)
            case .info: return .ds(.stateInfo)
            }
        }
    }
    
    var body: some View {
        Text(text)
            .font(DSTypography.captionSmall)
            .fontWeight(.semibold)
            .foregroundColor(variant.foregroundColor)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(
                Capsule()
                    .fill(variant.backgroundColor)
            )
    }
}

// MARK: - Tag Component

struct DSTag: View {
    let text: String
    let color: Color
    
    init(_ text: String, color: Color = .ds(.brandPrimary)) {
        self.text = text
        self.color = color
    }
    
    var body: some View {
        Text(text)
            .font(DSTypography.caption)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }
}

