import SwiftUI
import StoreKit

/// Paywall view for subscription purchases
struct PaywallView: View {
    @EnvironmentObject var subManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss
    var onPurchaseComplete: () -> Void
    
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Programmatic Paywall Hero - Glass morphism
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color("VibeZGold").opacity(0.2),
                                    Color("VibeZGoldDark").opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 200)
                        .blur(radius: 15)
                    
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color("VibeZGold"))
                        
                        Text("Unlock Premium")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                
                // Header
                VStack(spacing: 8) {
                    Text("Upgrade to Pro")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color("VibeZGold"))
                    
                    Text("Unlock premium features")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Products list
                if subManager.products.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading products...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(subManager.products) { product in
                                ProductCard(
                                    product: product,
                                    isPurchasing: isPurchasing,
                                    onPurchase: {
                                        await purchaseProduct(product)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Restore purchases button
                Button("Restore Purchases") {
                    Task {
                        await restorePurchases()
                    }
                }
                .foregroundColor(Color("VibeZGold"))
                .padding(.bottom, 20)
                
                // Error message
                if let error = purchaseError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color("VibeZDeep"),
                        Color("VibeZGoldDark").opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color("VibeZGold"))
                }
            }
            .task {
                await subManager.loadProducts()
            }
        }
    }
    
    private func purchaseProduct(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        
        do {
            try await subManager.purchase(product)
            onPurchaseComplete()
            dismiss()
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
        
        isPurchasing = false
    }
    
    private func restorePurchases() async {
        isPurchasing = true
        purchaseError = nil
        
        await subManager.restorePurchases()
        
        if subManager.hasEntitlement(for: "pro_monthly") || subManager.hasEntitlement(for: "pro_annual") {
            onPurchaseComplete()
            dismiss()
        } else {
            purchaseError = "No purchases found to restore"
        }
        
        isPurchasing = false
    }
}

/// Product card component
struct ProductCard: View {
    let product: Product
    let isPurchasing: Bool
    let onPurchase: () async -> Void
    
    var body: some View {
        Button {
            Task {
                await onPurchase()
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(product.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(product.displayPrice)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color("VibeZGold"))
                        
                        if let subscription = product.subscription {
                            Text(subscription.subscriptionPeriod.unit == .month ? "per month" : "per year")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if isPurchasing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("VibeZDeep").opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("VibeZGold").opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .disabled(isPurchasing)
    }
}

#Preview {
    PaywallView(onPurchaseComplete: {})
        .environmentObject(SubscriptionManager.shared)
}

