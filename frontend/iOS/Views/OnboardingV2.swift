import SwiftUI
import AuthenticationServices

struct OnboardingV2: View {
    @StateObject private var authService = SupabaseAuthService.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showContent = false
    @State private var pulseAnimation = false
    @State private var ageVerified = false
    
    // Check auth state - if already logged in, skip onboarding instantly
    private var isAuthenticated: Bool {
        authService.isAuthenticated
    }
    
    var body: some View {
        ZStack {
            // Modern gradient background with golden vibez theme
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.03, blue: 0.00), // Deep black-brown
                    Color(red: 0.15, green: 0.10, blue: 0.02), // Rich dark brown
                    Color(red: 0.10, green: 0.06, blue: 0.00)  // VibeZDeep
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Glass blur backdrop asset
            Image("glass/BlurBackdrop")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.6)
            
            // Glass gradient overlay asset
            Image("glass/GradientOverlay")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .blendMode(.overlay)
            
            // Animated golden glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color("VibeZGold").opacity(0.3),
                            Color("VibeZGold").opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(y: -100)
                .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                .opacity(pulseAnimation ? 0.6 : 0.8)
                .animation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true),
                    value: pulseAnimation
                )
            
            VStack(spacing: 32) {
                Spacer()
                
                // Programmatic Hero - Glass morphism circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color("VibeZGold").opacity(0.3),
                                    Color("VibeZGold").opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)
                        .opacity(showContent ? 1.0 : 0.0)
                        .scaleEffect(showContent ? 1.0 : 0.9)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showContent)
                }
                .frame(height: 300)
                
                // App Icon/Logo area - Programmatic
                VStack(spacing: 16) {
                    // Programmatic logo - SF Symbol with glass effect
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color("VibeZGold").opacity(0.4),
                                        Color("VibeZGoldDark").opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .blur(radius: 10)
                        
                        Image(systemName: "message.fill")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(Color("VibeZGold"))
                    }
                    .shadow(color: Color("VibeZGlow").opacity(0.5), radius: 20)
                    .scaleEffect(showContent ? 1.0 : 0.8)
                    .opacity(showContent ? 1.0 : 0.0)
                    
                    // App name with glow effect
                    Text("VibeZ")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(Color("VibeZGold"))
                        .shadow(color: Color("VibeZGlow").opacity(0.8), radius: 12)
                        .offset(y: showContent ? 0 : 20)
                        .opacity(showContent ? 1.0 : 0.0)
                    
                    // Tagline
                    Text("Experience Connection Reimagined.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .offset(y: showContent ? 0 : 20)
                        .opacity(showContent ? 1.0 : 0.0)
                }
                
                Spacer()
                
                // Age verification checkbox
                HStack(spacing: 12) {
                    Button(action: {
                        ageVerified.toggle()
                    }) {
                        Image(systemName: ageVerified ? "checkmark.square.fill" : "square")
                            .foregroundColor(ageVerified ? Color("VibeZGold") : .white.opacity(0.6))
                            .font(.system(size: 20))
                    }
                    Text("I am 18 years or older")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 8)
                .offset(y: showContent ? 0 : 30)
                .opacity(showContent ? 1.0 : 0.0)
                
                // Auth buttons row - Use Supabase auth
                VStack(spacing: 12) {
                    // Sign In With Apple button
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            if case .success = result {
                                Task { @MainActor in
                                    do {
                                        _ = try await authService.signInWithApple()
                                        if authService.isAuthenticated {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                hasCompletedOnboarding = true
                                            }
                                        }
                                    } catch {
                                        // Error handling is done in the service
                                    }
                                }
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Sign In With Apple")
                    .accessibilityHint("Double tap to sign in with your Apple ID")
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                .offset(y: showContent ? 0 : 30)
                .opacity(showContent ? 1.0 : 0.0)
                
                // Get Started button (skip auth)
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        hasCompletedOnboarding = true
                    }
                }) {
                    HStack(spacing: 12) {
                        Text("Get Started")
                            .font(.title3.bold())
                        Image(systemName: "arrow.right")
                            .font(.title3.bold())
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color("VibeZGold"),
                                        Color("VibeZGoldDark")
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: Color("VibeZGold").opacity(0.5), radius: 12, y: 4)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
                .offset(y: showContent ? 0 : 30)
                .opacity(showContent ? 1.0 : 0.0)
                .accessibilityLabel("Get Started")
                .accessibilityHint("Double tap to begin using VibeZ")
            }
        }
        .onAppear {
            // If already authenticated, skip onboarding instantly
            if isAuthenticated {
                hasCompletedOnboarding = true
                return
            }
            
            // Show content instantly - no delays
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .onChange(of: isAuthenticated) { authenticated in
            // Snap off instantly when auth state changes - no prompts, no emails
            if authenticated {
                withAnimation(.easeOut(duration: 0.2)) {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}

#Preview {
    OnboardingV2()
}

