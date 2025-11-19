import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var guestService: GuestService
    @State private var showSignupSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                VibezBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        HStack {
                            Spacer()
                            NavigationLink(destination: SettingsView()) {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(Color.Vibez.textPrimary)
                                    .font(.system(size: 20))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 60)
                        
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color.Vibez.deepVoid)
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Circle()
                                        .stroke(guestService.isGuest ? AnyShapeStyle(Color.gray.opacity(0.5)) : AnyShapeStyle(Color.Vibez.primaryGradient), lineWidth: 2)
                                )
                            
                            Image(systemName: guestService.isGuest ? "person.crop.circle.badge.questionmark" : "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(Color.Vibez.textSecondary)
                        }
                        
                        if guestService.isGuest {
                            VStack(spacing: 8) {
                                Text("Guest User")
                                    .vibezHeaderMedium()
                                Text(guestService.guestHandle)
                                    .vibezBody()
                            }
                            
                            // Guest CTA
                            Button(action: { showSignupSheet = true }) {
                                GlassCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Initialize Identity")
                                                .font(VibezTypography.button)
                                                .foregroundColor(Color.Vibez.textPrimary)
                                            Text("Secure your name and stats.")
                                                .font(VibezTypography.caption)
                                                .foregroundColor(Color.Vibez.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                            .foregroundColor(Color.Vibez.electricBlue)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                        } else {
                            Text(guestService.guestHandle)
                                .vibezHeaderMedium()
                            
                            Text("@\(guestService.guestHandle.lowercased())")
                                .vibezBody()
                            
                            // Stats
                            HStack(spacing: 40) {
                                StatColumn(value: "1.2k", label: "Followers")
                                StatColumn(value: "450", label: "Following")
                                StatColumn(value: "89", label: "Vibes")
                            }
                            .padding(.vertical)
                        }
                        
                        // Menu
                        VStack(spacing: 16) {
                            MenuRow(icon: "bell.fill", title: "Notifications")
                            
                            NavigationLink(destination: PrivacySettingsView()) {
                                MenuRow(icon: "lock.fill", title: "Privacy & Security")
                            }
                            
                            NavigationLink(destination: SelfHostSettingsView()) {
                                MenuRow(icon: "server.rack", title: "Self-Hosted Node")
                            }
                            
                            MenuRow(icon: "creditcard.fill", title: "Subscription")
                            MenuRow(icon: "questionmark.circle.fill", title: "Help & Support")
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .sheet(isPresented: $showSignupSheet) {
            LazySignupView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

// Placeholder for general settings if needed, or route directly to specific settings
struct SettingsView: View {
    var body: some View {
        ZStack {
            VibezBackground()
            Text("General Settings")
                .vibezHeaderMedium()
        }
    }
}

struct StatColumn: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(VibezTypography.headerSmall)
                .foregroundColor(Color.Vibez.textPrimary)
            Text(label)
                .font(VibezTypography.caption)
                .foregroundColor(Color.Vibez.textSecondary)
        }
    }
}

struct MenuRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color.Vibez.electricBlue)
                    .frame(width: 24)
                Text(title)
                    .font(VibezTypography.bodyMedium)
                    .foregroundColor(Color.Vibez.textPrimary)
                    .padding(.leading, 12)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Color.Vibez.textSecondary)
                    .font(.system(size: 14))
            }
        }
    }
}
