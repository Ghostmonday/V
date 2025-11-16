import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var firebaseAuthViewModel: FirebaseAuthViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showContent = false
    @State private var pulseAnimation = false
    @State private var ageVerified = false
    
    // Check auth state - if already logged in, skip onboarding instantly
    private var isAuthenticated: Bool {
        firebaseAuthViewModel.state == .signedIn || AuthTokenManager.shared.token != nil
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
                
                // Welcome Hero Image
                Image("WelcomeHero")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 300)
                    .clipped()
                    .opacity(showContent ? 1.0 : 0.0)
                    .scaleEffect(showContent ? 1.0 : 0.9)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showContent)
                
                // App Icon/Logo area
                VStack(spacing: 16) {
                    // Actual logo from assets
                    Image(VibeZColors.logoImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .shadow(color: VibeZColors.glow.opacity(0.5), radius: 20)
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
                    Text("Connect. Communicate. Collaborate.")
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
                    Text("I confirm I'm 18+")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 8)
                .offset(y: showContent ? 0 : 30)
                .opacity(showContent ? 1.0 : 0.0)
                
                // Auth buttons row - Use Firebase auth
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
                                    await firebaseAuthViewModel.login(with: .signInWithApple)
                                    if firebaseAuthViewModel.state == .signedIn {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            hasCompletedOnboarding = true
                                        }
                                    }
                                }
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(8)
                    .accessibilityLabel("Sign In With Apple")
                    .accessibilityHint("Double tap to sign in with your Apple ID")
                    
                    // Sign In With Google button
                    Button(action: {
                        Task { @MainActor in
                            await firebaseAuthViewModel.login(with: .signInWithGoogle)
                            if firebaseAuthViewModel.state == .signedIn {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    hasCompletedOnboarding = true
                                }
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "globe")
                                .font(.system(size: 18))
                            Text("Sign in with Google")
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(8)
                    }
                    .accessibilityLabel("Sign In With Google")
                    .accessibilityHint("Double tap to sign in with your Google account")
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
    OnboardingView()
}

