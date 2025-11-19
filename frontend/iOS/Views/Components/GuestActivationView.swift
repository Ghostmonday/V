import SwiftUI

struct GuestActivationView: View {
    @EnvironmentObject var guestService: GuestService
    @State private var progress: CGFloat = 0.0
    
    // Mock state for checklist items
    @State private var hasJoinedRoom = false
    @State private var hasShared = false
    @State private var hasClaimedHandle = false
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("VIBE CHECK")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.Vibez.neonCyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.Vibez.neonCyan.opacity(0.1))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(VibezTypography.caption)
                        .foregroundColor(Color.Vibez.textSecondary)
                }
                
                Text("Complete your setup")
                    .font(VibezTypography.headerSmall)
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    ChecklistItem(
                        title: "Tune In",
                        subtitle: "Join a room and listen for 30s",
                        isCompleted: hasJoinedRoom,
                        action: { /* Navigate to room */ }
                    )
                    
                    ChecklistItem(
                        title: "Pass the Vibe",
                        subtitle: "Share a room with a friend",
                        isCompleted: hasShared,
                        action: { shareVibe() }
                    )
                    
                    ChecklistItem(
                        title: "Claim Identity",
                        subtitle: "Choose your unique handle",
                        isCompleted: !guestService.isGuest,
                        action: { /* Open Signup */ }
                    )
                }
            }
            .padding(20)
        }
        .onAppear {
            updateProgress()
        }
        .onChange(of: guestService.isGuest) { _, _ in
            updateProgress()
        }
    }
    
    private func updateProgress() {
        var completed = 0.0
        if hasJoinedRoom { completed += 1 }
        if hasShared { completed += 1 }
        if !guestService.isGuest { completed += 1 }
        withAnimation {
            progress = completed / 3.0
        }
    }
    
    private func shareVibe() {
        // Simulate share action
        let activityVC = UIActivityViewController(
            activityItems: ["Check out this vibe on VIBEZ: https://vibez.app/room/123"],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true) {
                hasShared = true
                updateProgress()
            }
        }
    }
}

struct ChecklistItem: View {
    let title: String
    let subtitle: String
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.Vibez.success)
                            .font(.system(size: 24))
                            .transition(.scale)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VibezTypography.bodyMedium)
                        .foregroundColor(isCompleted ? Color.Vibez.textSecondary : .white)
                        .strikethrough(isCompleted)
                    
                    Text(subtitle)
                        .font(VibezTypography.caption)
                        .foregroundColor(Color.Vibez.textSecondary)
                }
                
                Spacer()
                
                if !isCompleted {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color.Vibez.textSecondary)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .disabled(isCompleted)
    }
}

