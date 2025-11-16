import SwiftUI

/// Onboarding tier selection - first screen after launch
struct TierSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedTier: SubscriptionTier?
    @State private var haptic = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                Text("Choose Your Plan")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Start free, upgrade anytime")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            // Tier cards with images
            VStack(spacing: 16) {
                TierSelectionCard(
                    tier: .starter,
                    title: "Free",
                    price: "$0",
                    features: ["Create chat", "Basic features"],
                    isSelected: selectedTier == .starter,
                    imageName: "TierCardStarter"
                ) {
                    selectTier(.starter)
                }
                
                TierSelectionCard(
                    tier: .professional,
                    title: "Pro",
                    price: "$5/mo",
                    features: ["Temp rooms", "24hr expiry", "Faster bots"],
                    isSelected: selectedTier == .professional,
                    imageName: "TierCardPro"
                ) {
                    selectTier(.professional)
                }
                
                TierSelectionCard(
                    tier: .enterprise,
                    title: "Enterprise",
                    price: "$19/mo",
                    features: ["Full control", "AI mod", "No limits", "Self-host"],
                    isSelected: selectedTier == .enterprise,
                    imageName: "TierCardEnterprise"
                ) {
                    selectTier(.enterprise)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue button
            Button(action: {
                haptic.impactOccurred()
                dismiss()
            }) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        selectedTier != nil
                            ? LinearGradient(colors: [.primaryVibeZ, .blue], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(12)
            }
            .disabled(selectedTier == nil)
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [Color.voidBlack.opacity(0.9), Color.primaryVibeZ.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
    
    private func selectTier(_ tier: SubscriptionTier) {
        haptic.impactOccurred()
        selectedTier = tier
    }
}

struct TierSelectionCard: View {
    let tier: SubscriptionTier
    let title: String
    let price: String
    let features: [String]
    let isSelected: Bool
    let imageName: String?
    let action: () -> Void
    
    init(tier: SubscriptionTier, title: String, price: String, features: [String], isSelected: Bool, imageName: String? = nil, action: @escaping () -> Void) {
        self.tier = tier
        self.title = title
        self.price = price
        self.features = features
        self.isSelected = isSelected
        self.imageName = imageName
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                // Icon or Image
                if let imageName = imageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                } else {
                    Image(systemName: tier.icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : tierColor)
                        .frame(width: 40)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(isSelected ? .white : .primary)
                        
                        Spacer()
                        
                        Text(price)
                            .font(.headline)
                            .foregroundColor(isSelected ? .white : tierColor)
                    }
                    
                    // One-line features
                    Text(features.joined(separator: " • "))
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                        .lineLimit(1)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [tierColor, tierColor.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? tierColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var tierColor: Color {
        switch tier {
        case .starter: return .gray
        case .professional: return .blue
        case .enterprise: return .yellow
        }
    }
}

#Preview {
    TierSelectionView(selectedTier: .constant(nil))
}

