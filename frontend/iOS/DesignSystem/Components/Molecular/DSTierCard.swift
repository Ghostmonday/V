/**
 * Design System - Tier Card Component
 * 
 * Enhanced subscription tier card with improved visual hierarchy,
 * feature list, and purchase flow integration.
 */

import SwiftUI

struct DSTierCard: View {
    let tier: TierViewModel
    let isSelected: Bool
    let onSelect: () -> Void
    let onPurchase: () -> Void
    
    @State private var isPressed = false
    
    struct TierViewModel {
        let id: String
        let name: String
        let subtitle: String
        let icon: String
        let price: String
        let period: String
        let features: [FeatureItem]
        let cta: String
        let color: Color
        let isPopular: Bool
        
        struct FeatureItem {
            let icon: String
            let text: String
        }
    }
    
    var body: some View {
        Button(action: {
            DSHaptic.selection()
            onSelect()
        }) {
            VStack(alignment: .leading, spacing: DSSpacing.base) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        HStack(spacing: DSSpacing.sm) {
                            Image(systemName: tier.icon)
                                .font(DSTypography.title3)
                                .foregroundColor(tier.color)
                            
                            Text(tier.name)
                                .font(DSTypography.title2)
                                .foregroundColor(.ds(.textPrimary))
                            
                            if tier.isPopular {
                                DSBadge(text: "Popular", variant: .info)
                            }
                        }
                        
                        Text(tier.subtitle)
                            .font(DSTypography.body)
                            .foregroundColor(.ds(.textSecondary))
                    }
                    
                    Spacer()
                    
                    // Selection indicator
                    if isSelected {
                        Image(systemName: DSIcon.checkmarkCircle)
                            .font(DSTypography.title3)
                            .foregroundColor(.ds(.brandPrimary))
                    }
                }
                
                // Features
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    ForEach(Array(tier.features.enumerated()), id: \.offset) { _, feature in
                        HStack(spacing: DSSpacing.sm) {
                            Image(systemName: feature.icon)
                                .font(DSTypography.body)
                                .foregroundColor(.ds(.brandPrimary))
                                .frame(width: 20)
                            
                            Text(feature.text)
                                .font(DSTypography.body)
                                .foregroundColor(.ds(.textPrimary))
                        }
                    }
                }
                
                DSDivider(variant: .full, spacing: DSSpacing.sm)
                
                // Price and CTA
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: DSSpacing.xs) {
                        Text(tier.price)
                            .font(DSTypography.displaySmall)
                            .foregroundColor(.ds(.textPrimary))
                        
                        Text(tier.period)
                            .font(DSTypography.body)
                            .foregroundColor(.ds(.textSecondary))
                    }
                    
                    DSPrimaryButton(tier.cta, size: .medium) {
                        DSHaptic.medium()
                        onPurchase()
                    }
                }
            }
            .padding(DSSpacing.base)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.xl, style: .continuous)
                    .fill(isSelected ? Color.ds(.bgElevated) : Color.ds(.bgCard))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.xl, style: .continuous)
                            .stroke(
                                isSelected ? tier.color : Color.ds(.controlStroke),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .dsShadow(isSelected ? .elevated : .card)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(DSAnimation.spring, value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Feature List Component

struct DSFeatureList: View {
    let items: [DSTierCard.TierViewModel.FeatureItem]
    let style: FeatureListStyle
    
    enum FeatureListStyle {
        case compact
        case detailed
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: item.icon)
                        .font(style == .compact ? DSTypography.caption : DSTypography.body)
                        .foregroundColor(.ds(.brandPrimary))
                        .frame(width: style == .compact ? 16 : 20)
                    
                    Text(item.text)
                        .font(style == .compact ? DSTypography.caption : DSTypography.body)
                        .foregroundColor(.ds(.textPrimary))
                }
            }
        }
    }
}

