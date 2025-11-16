import SwiftUI

/// Subscription upsell with gradient cards
struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var haptic = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Unlock Pro or Enterprise")
                    .foregroundColor(.white)
                    .font(.headline)
                    .bold()
                    .padding(.top, 40)
                
                SubscriptionCard(
                    title: "Pro",
                    price: "$5/mo",
                    features: ["Temp rooms", "faster AI", "no ads"],
                    icon: "⏳",
                    action: { upgrade(.professional) }
                )
                
                SubscriptionCard(
                    title: "Enterprise",
                    price: "$19/mo",
                    features: ["Permanent rooms", "Self-hosting", "Full control"],
                    icon: "server.rack",
                    action: { upgrade(.enterprise) }
                )
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color("VibeZDeep"),
                        Color("VibeZGoldDark").opacity(0.3)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func upgrade(_ tier: SubscriptionTier) {
        haptic.impactOccurred()
        
        Task {
            await SubscriptionManager.shared.purchaseTier(tier)
            
            // Dismiss after purchase attempt
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        }
    }
}

struct SubscriptionCard: View {
    let title: String
    let price: String
    let features: [String]
    let icon: String
    let action: () -> Void
    
    @State private var haptic = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        Button(action: {
            haptic.impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(icon)
                        .font(.system(size: 32))
                    
                    VStack(alignment: .leading) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(price)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                }
                
                Text(features.joined(separator: " • "))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.2))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SubscriptionView()
}

