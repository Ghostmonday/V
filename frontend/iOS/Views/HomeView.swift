import SwiftUI

struct HomeView: View {
    @EnvironmentObject var guestService: GuestService
    @State private var showToast = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        HStack {
                            Text("VIBEZ")
                                .vibezHeaderLarge()
                            
                            if guestService.isGuest {
                                Text("GUEST MODE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color.Vibez.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .stroke(Color.Vibez.textSecondary.opacity(0.5), lineWidth: 1)
                                    )
                            }
                            
                            Spacer()
                            
                            // Status Orb
                            Circle()
                                .fill(Color.Vibez.electricBlue)
                                .frame(width: 12, height: 12)
                                .shadow(color: Color.Vibez.electricBlue, radius: 5)
                                .overlay(
                                    Circle()
                                        .stroke(Color.Vibez.electricBlue.opacity(0.5), lineWidth: 2)
                                        .scaleEffect(1.5)
                                        .opacity(0.5)
                                )
                        }
                        .padding(.horizontal)
                        .padding(.top, 60)
                        
                        // Guest Activation Checklist (Gamification)
                        if guestService.isGuest {
                            GuestActivationView()
                                .padding(.horizontal)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Active Rooms
                        Text("Live Now")
                            .vibezHeaderSmall()
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(0..<3) { _ in
                                    NavigationLink(destination: RoomDetailPlaceholder()) {
                                        RoomCard()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Recent Activity
                        Text("Recent Vibes")
                            .vibezHeaderSmall()
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            ForEach(0..<5) { _ in
                                ActivityRow()
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 100) // For floating tab bar
                    }
                }
                
                // Soft Save Prompt (4-hour trigger)
                if guestService.showSavePrompt {
                    VStack {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enjoying VibeZ?")
                                    .font(VibezTypography.bodyMedium)
                                    .foregroundColor(Color.Vibez.textPrimary)
                                Text("Save your session to keep your history.")
                                    .font(VibezTypography.caption)
                                    .foregroundColor(Color.Vibez.textSecondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                // Trigger signup flow (could open sheet)
                                // For now, we'll just dismiss to simulate "Maybe Later" or handle via Profile
                                // Ideally this opens LazySignupView
                            }) {
                                Text("Save")
                                    .font(VibezTypography.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.Vibez.electricBlue)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: { guestService.dismissSavePrompt() }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(Color.Vibez.textSecondary)
                                    .padding(8)
                            }
                        }
                        .padding()
                        .glassCard()
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
    }
}

// Temporary placeholder for navigation testing
struct RoomDetailPlaceholder: View {
    var body: some View {
        ZStack {
            VibezBackground()
            Text("Room Detail")
                .vibezHeaderLarge()
        }
    }
}

struct RoomCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(Color.Vibez.neonCyan)
                        .frame(width: 8, height: 8)
                    Text("LIVE")
                        .font(VibezTypography.caption)
                        .foregroundColor(Color.Vibez.neonCyan)
                    Spacer()
                    Text("124 listening")
                        .font(VibezTypography.caption)
                        .foregroundColor(Color.Vibez.textSecondary)
                }
                
                Text("Late Night Lo-Fi & Chill")
                    .vibezHeaderSmall()
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    ForEach(0..<3) { _ in
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .frame(width: 200)
        }
    }
}

struct ActivityRow: View {
    var body: some View {
        GlassCard {
            HStack {
                Circle()
                    .fill(Color.Vibez.plasmaPurple)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading) {
                    Text("Cyberpunk 2077 Discussion")
                        .font(VibezTypography.bodyMedium)
                        .foregroundColor(Color.Vibez.textPrimary)
                    Text("Started 5 mins ago")
                        .font(VibezTypography.caption)
                        .foregroundColor(Color.Vibez.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Color.Vibez.textSecondary)
            }
        }
    }
}
