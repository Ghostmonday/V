/**
 * Design System - Divider Component
 * 
 * Consistent separator component with multiple variants.
 */

import SwiftUI

struct DSDivider: View {
    let variant: DividerVariant
    let spacing: CGFloat
    
    enum DividerVariant {
        case full
        case inset
        case middle
        
        var horizontalPadding: CGFloat {
            switch self {
            case .full: return 0
            case .inset: return DSSpacing.base
            case .middle: return DSSpacing.xxl
            }
        }
    }
    
    init(variant: DividerVariant = .full, spacing: CGFloat = DSSpacing.base) {
        self.variant = variant
        self.spacing = spacing
    }
    
    var body: some View {
        Rectangle()
            .fill(Color.ds(.separator))
            .frame(height: 0.5)
            .padding(.horizontal, variant.horizontalPadding)
            .padding(.vertical, spacing)
    }
}

// MARK: - Section Header

struct DSSectionHeader: View {
    let title: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(_ title: String, action: (() -> Void)? = nil, actionTitle: String? = nil) {
        self.title = title
        self.action = action
        self.actionTitle = actionTitle
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(DSTypography.label)
                .foregroundColor(.ds(.textSecondary))
                .textCase(.uppercase)
            
            Spacer()
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(DSTypography.labelSmall)
                        .foregroundColor(.ds(.brandPrimary))
                }
            }
        }
        .padding(.horizontal, DSSpacing.base)
        .padding(.vertical, DSSpacing.sm)
    }
}

