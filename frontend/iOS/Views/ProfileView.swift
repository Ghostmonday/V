import SwiftUI
import Foundation

@available(iOS 15.0, *)
struct ProfileView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPricingSheet = false
    @State private var showUpgradeAlert = false
    @State private var upgradeFeature: Feature?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar section
                    VStack(spacing: 12) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: subscriptionManager.currentTier.color).opacity(0.6),
                                        Color(hex: subscriptionManager.currentTier.color).opacity(0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: subscriptionManager.currentTier.icon)
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: Color(hex: subscriptionManager.currentTier.color).opacity(0.3), radius: 10)
                        
                        Text("Your Profile")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        // Tier badge
                        HStack {
                            Image(systemName: subscriptionManager.currentTier.icon)
                                .foregroundColor(Color(hex: subscriptionManager.currentTier.color))
                            Text(subscriptionManager.currentTier.displayName)
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(hex: subscriptionManager.currentTier.color).opacity(0.15))
                        )
                    }
                    .padding(.top, 20)
                    
                    // Subscription status card
                    SubscriptionStatusCard(
                        subscriptionManager: subscriptionManager,
                        onUpgrade: {
                            showPricingSheet = true
                        }
                    )
                    .padding(.horizontal, 16)
                    
                    // Feature access preview
                    FeatureAccessPreview(
                        subscriptionManager: subscriptionManager,
                        onUpgradeRequested: { feature in
                            upgradeFeature = feature
                            showUpgradeAlert = true
                        }
                    )
                    .padding(.horizontal, 16)
                    
                    // Quick actions
                    VStack(spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        
                        QuickActionButton(
                            icon: "creditcard.fill",
                            title: "Manage Subscription",
                            subtitle: "View billing and plan details",
                            color: .blue
                        ) {
                            showPricingSheet = true
                        }
                        
                        QuickActionButton(
                            icon: "arrow.clockwise",
                            title: "Restore Purchases",
                            subtitle: "Restore previous subscriptions",
                            color: .green
                        ) {
                            Task {
                                await subscriptionManager.restorePurchases()
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showPricingSheet) {
                // PricingSheet(subscriptionManager: subscriptionManager, isPresented: $showPricingSheet)
                SubscriptionView()
            }
            .alert("Upgrade Required", isPresented: $showUpgradeAlert) {
                Button("View Plans") {
                    showUpgradeAlert = false
                    showPricingSheet = true
                }
                Button("Cancel", role: .cancel) {
                    upgradeFeature = nil
                }
            } message: {
                if let feature = upgradeFeature {
                    Text(subscriptionManager.upgradeMessage(for: feature))
                }
            }
        }
        /// UX: Avatar + subscription actions + feature gates
    }
}

/// Subscription Status Card
@available(iOS 15.0, *)
struct SubscriptionStatusCard: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    let onUpgrade: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(subscriptionManager.currentTier.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: subscriptionManager.currentTier.color))
                }
                
                Spacer()
                
                if subscriptionManager.currentTier == .starter {
                    Button(action: onUpgrade) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Upgrade")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }
            
            // Usage preview
            HStack(spacing: 20) {
                UsageMetric(
                    icon: "bolt.fill",
                    label: "Daily Tokens",
                    value: "\(subscriptionManager.currentTier.maxDailyTokens / 1000)K"
                )
                
                UsageMetric(
                    icon: "brain.head.profile",
                    label: "Assistants",
                    value: subscriptionManager.currentTier.maxAssistants == Int.max ? "∞" : "\(subscriptionManager.currentTier.maxAssistants)"
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

/// Usage Metric Component
struct UsageMetric: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Feature Access Preview
@available(iOS 15.0, *)
struct FeatureAccessPreview: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    let onUpgradeRequested: (Feature) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feature Access")
                .font(.headline)
            
            VStack(spacing: 8) {
                FeatureAccessRow(
                    feature: .abTesting,
                    subscriptionManager: subscriptionManager,
                    onUpgradeRequested: onUpgradeRequested
                )
                
                FeatureAccessRow(
                    feature: .gpt4Access,
                    subscriptionManager: subscriptionManager,
                    onUpgradeRequested: onUpgradeRequested
                )
                
                FeatureAccessRow(
                    feature: .fullAutonomy,
                    subscriptionManager: subscriptionManager,
                    onUpgradeRequested: onUpgradeRequested
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

/// Feature Access Row
@available(iOS 15.0, *)
struct FeatureAccessRow: View {
    let feature: Feature
    @ObservedObject var subscriptionManager: SubscriptionManager
    let onUpgradeRequested: (Feature) -> Void
    
    private var featureName: String {
        switch feature {
        case .abTesting: return "A/B Testing"
        case .gpt4Access: return "GPT-4 Access"
        case .fullAutonomy: return "Full Autonomy"
        default: return feature.rawValue
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: subscriptionManager.canAccess(feature) ? "checkmark.circle.fill" : "lock.fill")
                .foregroundColor(subscriptionManager.canAccess(feature) ? .green : .gray)
            
            Text(featureName)
                .font(.subheadline)
            
            Spacer()
            
            if !subscriptionManager.canAccess(feature) {
                Button(action: {
                    onUpgradeRequested(feature)
                }) {
                    Text("Upgrade")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                }
            }
        }
    }
}

/// Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.glassBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    if #available(iOS 15.0, *) {
        ProfileView()
    } else {
        Text("iOS 15.0+ required")
    }
}

