import SwiftUI

struct PrivacyOnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    
    var body: some View {
        ZStack {
            VibezBackground()
            
            TabView(selection: $currentStep) {
                WelcomeStep(nextAction: { withAnimation { currentStep = 1 } })
                    .tag(0)
                
                PrivacyConsentStep(nextAction: { withAnimation { currentStep = 2 } })
                    .tag(1)
                
                CompletionStep(finishAction: {
                    withAnimation {
                        appState.hasCompletedOnboarding = true
                    }
                })
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)
        }
    }
}

// MARK: - Step 1: Welcome
struct WelcomeStep: View {
    let nextAction: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Logo / Icon
            Circle()
                .fill(Color.Vibez.deepVoid)
                .frame(width: 120, height: 120)
                .overlay(
                    Circle()
                        .stroke(Color.Vibez.electricBlue, lineWidth: 2)
                        .shadow(color: Color.Vibez.electricBlue, radius: 10)
                )
                .overlay(
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Color.Vibez.textPrimary)
                )
            
            Text("Welcome to VIBEZ")
                .vibezHeaderLarge()
            
            Text("A social experience designed around\nabsolute privacy and control.")
                .vibezBody()
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: nextAction) {
                Text("Begin Setup")
                    .font(VibezTypography.button)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.Vibez.electricBlue)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }
}

// MARK: - Step 2: Privacy Consent (Opt-In)
struct PrivacyConsentStep: View {
    @EnvironmentObject var appState: AppState
    let nextAction: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Your Data, Your Rules")
                .vibezHeaderMedium()
                .padding(.top, 60)
            
            Text("We don't track you by default. Enable only what you're comfortable with.")
                .vibezBody()
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 16) {
                    PrivacyToggleRow(
                        title: "Crash Reporting",
                        description: "Help us fix bugs by sending anonymous crash logs.",
                        isOn: $appState.allowCrashReporting
                    )
                    
                    PrivacyToggleRow(
                        title: "Discoverability",
                        description: "Allow others to find you by your handle.",
                        isOn: $appState.allowDiscoverability
                    )
                    
                    PrivacyToggleRow(
                        title: "Usage Analytics",
                        description: "Share anonymous usage data to improve the app.",
                        isOn: $appState.allowUsageAnalytics
                    )
                }
                .padding()
            }
            
            Button(action: nextAction) {
                Text("Continue")
                    .font(VibezTypography.button)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.Vibez.success)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }
}

struct PrivacyToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(VibezTypography.bodyLarge)
                        .foregroundColor(Color.Vibez.textPrimary)
                    Text(description)
                        .font(VibezTypography.caption)
                        .foregroundColor(Color.Vibez.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(Color.Vibez.electricBlue)
            }
        }
    }
}

// MARK: - Step 3: Completion
struct CompletionStep: View {
    let finishAction: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(Color.Vibez.success)
                .shadow(color: Color.Vibez.success.opacity(0.5), radius: 20)
            
            Text("You're All Set")
                .vibezHeaderLarge()
            
            Text("Your privacy preferences have been saved.\nYou can change them anytime in Settings.")
                .vibezBody()
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: finishAction) {
                Text("Enter VIBEZ")
                    .font(VibezTypography.button)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.Vibez.textPrimary)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }
}

