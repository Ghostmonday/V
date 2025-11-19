import SwiftUI

struct LazySignupView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var guestService: GuestService
    @State private var handle: String = ""
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            VibezBackground()
            
            VStack(spacing: 30) {
                // Handle Bar
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 20)
                
                // Header
                VStack(spacing: 12) {
                    Text("Claim Your Vibe")
                        .vibezHeaderMedium()
                    
                    Text("Save your session, host rooms, and\nbuild your reputation.")
                        .vibezBody()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                // One-Click OAuth Options
                VStack(spacing: 12) {
                    Button(action: { performOAuthSignup(provider: "Apple") }) {
                        HStack {
                            Image(systemName: "apple.logo")
                            Text("Continue with Apple")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                    }
                    
                    Button(action: { performOAuthSignup(provider: "Google") }) {
                        HStack {
                            // Placeholder icon for Google
                            Image(systemName: "g.circle.fill")
                            Text("Continue with Google")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 30)
                
                HStack {
                    Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                    Text("OR").font(.caption).foregroundColor(.gray)
                    Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                }
                .padding(.horizontal, 30)
                
                // Manual Handle Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("CHOOSE A HANDLE")
                        .font(VibezTypography.caption)
                        .foregroundColor(Color.Vibez.textSecondary)
                        .padding(.leading, 4)
                    
                    HStack {
                        Text("@")
                            .foregroundColor(Color.Vibez.textSecondary)
                        TextField("username", text: $handle)
                            .foregroundColor(Color.Vibez.textPrimary)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.Vibez.deepVoid.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Actions
                VStack(spacing: 16) {
                    Button(action: createIdentity) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text("Create Identity")
                                    .font(VibezTypography.button)
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(handle.isEmpty ? Color.gray : Color.Vibez.electricBlue)
                        .cornerRadius(16)
                    }
                    .disabled(handle.isEmpty || isLoading)
                    
                    Button(action: { dismiss() }) {
                        Text("Maybe Later")
                            .font(VibezTypography.bodyMedium)
                            .foregroundColor(Color.Vibez.textSecondary)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Pre-fill with guest handle if it's not the default random one, or leave empty
            if !guestService.guestHandle.starts(with: "VibeGuest_") {
                handle = guestService.guestHandle
            }
        }
    }
    
    private func performOAuthSignup(provider: String) {
        isLoading = true
        // Simulate OAuth delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // In real app, this would get the email/name from provider
            let generatedHandle = "User_\(Int.random(in: 100...999))"
            guestService.upgradeToUser(handle: generatedHandle)
            isLoading = false
            dismiss()
        }
    }
    
    private func createIdentity() {
        guard !handle.isEmpty else { return }
        isLoading = true
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guestService.upgradeToUser(handle: handle)
            isLoading = false
            dismiss()
        }
    }
}
