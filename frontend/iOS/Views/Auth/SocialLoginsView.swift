//
//  SocialLoginsView.swift
//  VibeZ iOS
//
//  Social login buttons (Google, Apple) with VibeZ theme
//

import SwiftUI
import AuthenticationServices

struct SocialLoginsView: View {
	@EnvironmentObject var authViewModel: FirebaseAuthViewModel
	@Environment(\.colorScheme) var colorScheme
	
	var body: some View {
		VStack(spacing: 15) {
			// Google Sign In
			Button {
				Task { await signInWithGoogle() }
			} label: {
				HStack {
					// Google icon - use SF Symbol or placeholder
					Image(systemName: "globe")
						.font(.system(size: 18))
						.foregroundColor(.white)
					
					Text("Continue with Google")
						.foregroundColor(.white)
						.font(.headline)
				}
				.frame(maxWidth: .infinity)
				.padding()
				.background(
					RoundedRectangle(cornerRadius: 12)
						.fill(Color.white.opacity(0.1))
						.overlay(
							RoundedRectangle(cornerRadius: 12)
								.stroke(Color.white.opacity(0.3), lineWidth: 1)
						)
				)
			}
			.disabled(authViewModel.isLoading)
			
			// Apple Sign In
			SignInWithAppleButton(
				.continue,
				onRequest: { request in
					request.requestedScopes = [.fullName, .email]
				},
				onCompletion: { result in
					if case .success = result {
						Task { await signInWithApple() }
					}
				}
			)
			.signInWithAppleButtonStyle(.white)
			.frame(height: 50)
			.cornerRadius(12)
			.disabled(authViewModel.isLoading)
		}
	}
	
	private func signInWithGoogle() async {
		await authViewModel.login(with: .signInWithGoogle)
	}
	
	private func signInWithApple() async {
		await authViewModel.login(with: .signInWithApple)
	}
}

#Preview {
	SocialLoginsView()
		.environmentObject(FirebaseAuthViewModel(
			authRepository: FirebaseAuthRepository()
		))
}

