//
//  SocialLoginsView.swift
//  VibeZ iOS
//
//  Social login buttons (Apple) with VibeZ theme
//

import SwiftUI
import AuthenticationServices

struct SocialLoginsView: View {
	@StateObject private var authService = SupabaseAuthService.shared
	@State private var showErrorAlert: Bool = false
	@State private var errorMessage: String = ""
	
	var body: some View {
		VStack(spacing: 15) {
			// Apple Sign In
			SignInWithAppleButton(
				.continue,
				onRequest: { request in
					request.requestedScopes = [.fullName, .email]
				},
				onCompletion: { result in
					if case .success = result {
						Task { await signInWithApple() }
					} else if case .failure(let error) = result {
						errorMessage = error.localizedDescription
						showErrorAlert = true
					}
				}
			)
			.signInWithAppleButtonStyle(.white)
			.frame(height: 50)
			.cornerRadius(12)
			.disabled(authService.isAuthenticated)
			.accessibilityIdentifier("Sign In with Apple")
		}
		.alert("Error", isPresented: $showErrorAlert) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(errorMessage)
		}
	}
	
	private func signInWithApple() async {
		do {
			_ = try await authService.signInWithApple()
			// Success - navigation handled by parent view
		} catch let error as AuthError {
			errorMessage = error.localizedDescription ?? "Apple Sign-In failed"
			showErrorAlert = true
		} catch {
			errorMessage = error.localizedDescription
			showErrorAlert = true
		}
	}
}

#Preview {
	SocialLoginsView()
}
