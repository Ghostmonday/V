import SwiftUI

/// Tier selection - cards stack like album art
struct RoomTierView: View {
    @Environment(\.dismiss) var dismiss
    @State private var haptic = UIImpactFeedbackGenerator(style: .light)
    let onComplete: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    RoomTierCard(
                        title: "Free",
                        desc: "Join rooms.",
                        icon: "person.fill",
                        color: .gray,
                        action: { selectFree() }
                    )
                    
                    RoomTierCard(
                        title: "Pro",
                        desc: "Temp rooms (24h). $5/mo.",
                        icon: "⏳",
                        color: .yellow,
                        action: { goPro() }
                    )
                    
                    RoomTierCard(
                        title: "Enterprise",
                        desc: "Permanent. Self-host or deploy.",
                        icon: "server.rack",
                        color: .green,
                        action: { goEnterprise() }
                    )
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Choose Your Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        selectFree()
                    }
                }
            }
        }
    }
    
    private func selectFree() {
        haptic.impactOccurred()
        onComplete()
        dismiss()
    }
    
    private func goPro() {
        haptic.impactOccurred()
        // TODO: Handle Pro subscription
        onComplete()
        dismiss()
    }
    
    private func goEnterprise() {
        haptic.impactOccurred()
        // TODO: Handle Enterprise subscription
        onComplete()
        dismiss()
    }
}

struct RoomTierCard: View {
    let title: String
    let desc: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var haptic = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        Button(action: {
            haptic.impactOccurred()
            action()
        }) {
            VStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 40))
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RoomTierView(onComplete: {
        print("Preview complete")
    })
}

