import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var guestService: GuestService
    @State private var showSignupSheet = false
    @State private var showEditProfile = false
    
    // Local state for profile fields (in a real app, this would come from a UserService)
    @State private var userBio: String = ""
    @State private var userGender: String = ""
    
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
                            
                            // Dynamic Avatar Logic based on Gender
                            if guestService.isGuest {
                                Image("avatar_placeholder_guest") // Using asset name
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(
                                        Image(systemName: "questionmark") // Fallback if asset missing
                                            .font(.system(size: 50))
                                            .foregroundColor(Color.Vibez.textSecondary)
                                            .opacity(0) // Hidden if image loads
                                    )
                            } else {
                                // User Avatar Logic
                                let avatarImageName: String = {
                                    if userGender == "male" { return "avatar_male" }
                                    if userGender == "female" { return "avatar_female" }
                                    return "avatar_neutral"
                                }()
                                
                                Image(avatarImageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            }
                        }
                        
                        if guestService.isGuest {
                            VStack(spacing: 8) {
                                Text("Just browsing")
                                    .vibezHeaderMedium()
                                Text(guestService.guestHandle)
                                    .vibezBody()
                            }
                            
                            // Guest CTA
                            Button(action: { showSignupSheet = true }) {
                                GlassCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Pick your name")
                                                .font(VibezTypography.button)
                                                .foregroundColor(Color.Vibez.textPrimary)
                                            Text("Keep your name and activity private.")
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
                            // Registered User Profile
                            VStack(spacing: 8) {
                                Text(guestService.guestHandle)
                                    .vibezHeaderMedium()
                                
                                Text("@\(guestService.guestHandle.lowercased())")
                                    .vibezBody()
                                    .foregroundColor(Color.Vibez.textSecondary)
                                
                                if !userBio.isEmpty {
                                    Text(userBio)
                                        .vibezBody()
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                        .padding(.top, 4)
                                }
                                
                                // Edit Profile Button (Only for registered users)
                                Button(action: { showEditProfile = true }) {
                                    Text("Edit Profile")
                                        .font(VibezTypography.label)
                                        .foregroundColor(Color.Vibez.electricBlue)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.Vibez.electricBlue.opacity(0.1))
                                        .cornerRadius(20)
                                }
                                .padding(.top, 8)
                            }
                            
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
                                MenuRow(icon: "server.rack", title: "Your own server")
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
        .sheet(isPresented: $showEditProfile) {
            ProfileEditView(bio: $userBio, gender: $userGender, isPresented: $showEditProfile)
        }
    }
}

// Placeholder for general settings if needed, or route directly to specific settings
struct SettingsView: View {
    var body: some View {
        ZStack {
            VibezBackground()
            Text("Settings")
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
