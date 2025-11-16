import SwiftUI

/// Pricing Sheet View
/// Displays all three tiers with feature comparison and upgrade CTAs
@available(iOS 15.0, *)
struct PricingSheet: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Binding var isPresented: Bool
    @State private var selectedTier: SubscriptionTier?
    @State private var isPurchasing: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Choose Your Plan")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Unlock powerful AI features")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Current tier badge
                    if subscriptionManager.currentTier != .starter {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Current: \(subscriptionManager.currentTier.displayName)")
                                .font(.headline)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Tier cards
                    VStack(spacing: 16) {
                        ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                            TierCard(
                                tier: tier,
                                isCurrentTier: subscriptionManager.currentTier == tier,
                                isSelected: selectedTier == tier,
                                onSelect: {
                                    selectedTier = tier
                                },
                                onPurchase: {
                                    Task {
                                        await purchaseTier(tier)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Feature comparison
                    FeatureComparisonView()
                        .padding(.horizontal, 16)
                    
                    // Footer
                    Text("All plans include basic features. Upgrade to unlock advanced capabilities.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle("Pricing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func purchaseTier(_ tier: SubscriptionTier) async {
        guard tier != subscriptionManager.currentTier else {
            print("[PricingSheet] Already subscribed to \(tier.displayName)")
            return
        }
        
        isPurchasing = true
        print("[PricingSheet] Purchasing tier: \(tier.displayName)")
        
        await subscriptionManager.purchaseTier(tier)
        
        isPurchasing = false
        
        // Dismiss sheet after successful purchase - instant feedback
        if subscriptionManager.currentTier == tier {
            isPresented = false
        }
    }
}

/// Tier Card Component
@available(iOS 15.0, *)
struct TierCard: View {
    let tier: SubscriptionTier
    let isCurrentTier: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onPurchase: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: tier.icon)
                    .font(.title2)
                    .foregroundColor(Color(hex: tier.color))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("$\(Int(tier.monthlyPrice))/month")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isCurrentTier {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
            
            // Key features
            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(
                    icon: "bolt.fill",
                    text: "\(tier.maxDailyTokens / 1000)K tokens/day"
                )
                
                FeatureRow(
                    icon: "text.word.spacing",
                    text: "\(tier.maxResponseLength) token responses"
                )
                
                FeatureRow(
                    icon: "brain.head.profile",
                    text: "\(tier.maxAssistants == Int.max ? "Unlimited" : "\(tier.maxAssistants)") AI assistants"
                )
                
                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    text: autonomyDescription
                )
            }
            
            // CTA Button
            Button(action: {
                if isCurrentTier {
                    // Already subscribed
                } else {
                    onPurchase()
                }
            }) {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isCurrentTier ? "Current Plan" : "Upgrade to \(tier.displayName)")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isCurrentTier ? Color.gray.opacity(0.3) : Color(hex: tier.color))
                .foregroundColor(isCurrentTier ? .secondary : .white)
                .cornerRadius(12)
            }
            .disabled(isCurrentTier || isPurchasing)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color(hex: tier.color) : Color.glassBorder, lineWidth: isSelected ? 2 : 1)
                )
        )
        .onTapGesture {
            if !isCurrentTier {
                onSelect()
            }
        }
    }
    
    private var autonomyDescription: String {
        switch tier.autonomyLevel {
        case .disabled:
            return "Manual control only"
        case .recommendations:
            return "Automated recommendations"
        case .fullAuto:
            return "Fully autonomous operations"
        }
    }
    
    @State private var isPurchasing = false
}

/// Feature Row Component
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

/// Feature Comparison View
@available(iOS 15.0, *)
struct FeatureComparisonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Feature Comparison")
                .font(.headline)
                .padding(.bottom, 8)
            
            VStack(spacing: 12) {
                ComparisonRow(
                    feature: "A/B Testing",
                    starter: false,
                    professional: true,
                    enterprise: true
                )
                
                ComparisonRow(
                    feature: "GPT-4 Access",
                    starter: false,
                    professional: true,
                    enterprise: true
                )
                
                ComparisonRow(
                    feature: "Advanced Emotional Monitoring",
                    starter: false,
                    professional: true,
                    enterprise: true
                )
                
                ComparisonRow(
                    feature: "Predictive Analytics",
                    starter: false,
                    professional: false,
                    enterprise: true
                )
                
                ComparisonRow(
                    feature: "Custom Embeddings",
                    starter: false,
                    professional: false,
                    enterprise: true
                )
                
                ComparisonRow(
                    feature: "Priority Support",
                    starter: false,
                    professional: false,
                    enterprise: true
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.glassBorder, lineWidth: 1)
                )
        )
    }
}

/// Comparison Row Component
struct ComparisonRow: View {
    let feature: String
    let starter: Bool
    let professional: Bool
    let enterprise: Bool
    
    var body: some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                CheckmarkView(checked: starter)
                CheckmarkView(checked: professional)
                CheckmarkView(checked: enterprise)
            }
        }
    }
}

/// Checkmark View Component
struct CheckmarkView: View {
    let checked: Bool
    
    var body: some View {
        Image(systemName: checked ? "checkmark" : "xmark")
            .foregroundColor(checked ? .green : .gray.opacity(0.3))
            .font(.caption)
            .frame(width: 20)
    }
}

#Preview {
    PricingSheet(
        subscriptionManager: SubscriptionManager.shared,
        isPresented: .constant(true)
    )
}

