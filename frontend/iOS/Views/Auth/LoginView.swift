//
//  LoginView.swift
//  VibeZ iOS
//
//  Supabase authentication login view with VibeZ theme
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
	@StateObject private var authService = SupabaseAuthService.shared
	@State private var email: String = ""
	@State private var password: String = ""
	@State private var showResetPasswordAlert: Bool = false
	@State private var resetPasswordEmail: String = ""
	@State private var showPasswordResetConfirmation: Bool = false
	@State private var showErrorAlert: Bool = false
	@State private var errorMessage: String = ""
	@State private var isLoading: Bool = false
	@FocusState private var emailIsFocused: Bool
	@FocusState private var passwordIsFocused: Bool
	
	var body: some View {
		ZStack {
			// VibeZ gradient background
			LinearGradient(
				colors: [
					Color(red: 0.05, green: 0.03, blue: 0.00), // Deep black-brown
					Color(red: 0.15, green: 0.10, blue: 0.02), // Rich dark brown
					Color("VibeZDeep") // VibeZDeep
				],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
			.ignoresSafeArea()
			
			VStack(spacing: 0) {
				Spacer()
				
				// Logo and Title
				VStack(spacing: 16) {
					Text("VibeZ")
						.font(.system(size: 48, weight: .bold))
						.foregroundColor(Color("VibeZGold"))
						.shadow(color: Color("VibeZGlow").opacity(0.6), radius: 8)
						.accessibilityIdentifier("VibeZ")
					
					Text("Welcome back")
						.font(.system(size: 24, weight: .medium))
						.foregroundColor(.white.opacity(0.8))
						.accessibilityIdentifier("Welcome back")
				}
				.padding(.bottom, 40)
				
				// Form Fields
				VStack(spacing: 20) {
					TextField("Email Address", text: $email)
						.withVibeZLoginStyles()
						.textContentType(.emailAddress)
						.keyboardType(.emailAddress)
						.submitLabel(.next)
						.focused($emailIsFocused)
						.accessibilityIdentifier("Email Address")
						.onSubmit {
							emailIsFocused = false
							passwordIsFocused = true
						}
					
					SecureField("Password", text: $password)
						.withVibeZSecureFieldStyles()
						.submitLabel(.go)
						.focused($passwordIsFocused)
						.accessibilityIdentifier("Password")
						.onSubmit {
							signIn()
						}
					
					// Forgot Password Link
					HStack {
						Spacer()
						Button {
							showResetPasswordAlert = true
						} label: {
							Text("Forgot Password?")
								.foregroundColor(Color("VibeZGold"))
								.font(.footnote)
						}
					}
					.padding(.bottom, 8)
					
					// Error Display
					if !errorMessage.isEmpty {
						Text(errorMessage)
							.font(.footnote)
							.foregroundColor(.red)
							.padding(.vertical, 8)
							.padding(.horizontal, 12)
							.background(Color.red.opacity(0.1))
							.cornerRadius(8)
							.transition(.opacity)
					}
					
					// Sign In Button
					Button(action: signIn) {
						if isLoading {
							ProgressView()
								.tint(.white)
								.accessibilityIdentifier("Loading Indicator")
						} else {
							Text("Sign In")
								.foregroundColor(.black)
								.font(.headline)
								.frame(maxWidth: .infinity)
								.padding()
						}
					}
					.disabled(email.isEmpty || password.isEmpty || isLoading)
					.accessibilityIdentifier("Sign In")
					.background(
						Capsule()
							.fill(Color("VibeZGold"))
							.shadow(color: Color("VibeZGoldDark").opacity(0.6), radius: 6, y: 3)
					)
					.padding(.bottom, 12)
					
					// Sign Up Button
					Button(action: signUp) {
						Text("Sign Up")
							.foregroundColor(Color("VibeZGold"))
							.font(.headline)
							.frame(maxWidth: .infinity)
							.padding()
							.overlay(
								Capsule()
									.stroke(Color("VibeZGold"), lineWidth: 2)
							)
					}
					.disabled(email.isEmpty || password.isEmpty || isLoading)
					.accessibilityIdentifier("Sign Up")
				}
				.padding(.horizontal, 32)
				
				// OR Divider
				HStack {
					VStack { Divider().background(Color.white.opacity(0.3)) }
					Text("OR")
						.font(.footnote)
						.foregroundColor(.white.opacity(0.6))
						.padding(.horizontal, 12)
					VStack { Divider().background(Color.white.opacity(0.3)) }
				}
				.padding(.vertical, 30)
				.padding(.horizontal, 32)
				
				// Social Login Options
				SocialLoginsView()
					.padding(.horizontal, 32)
				
				Spacer()
			}
		}
		.alert("Reset Password", isPresented: $showResetPasswordAlert) {
			TextField("Enter your email", text: $resetPasswordEmail)
				.autocapitalization(.none)
				.keyboardType(.emailAddress)
			
			Button("Cancel", role: .cancel) {}
			
			Button("Reset") {
				Task {
					await resetPassword()
				}
			}
		} message: {
			Text("Enter your email address and we'll send you a link to reset your password.")
		}
		.alert("Password Reset Email Sent", isPresented: $showPasswordResetConfirmation) {
			Button("OK", role: .cancel) {}
		} message: {
			Text("Check your email for a link to reset your password.")
		}
		.alert("Error", isPresented: $showErrorAlert) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(errorMessage)
		}
		.onAppear {
			// Skip auto-login in UI testing mode
			if !ProcessInfo.isUITesting {
				// Auto-login if session can be restored
				Task {
					await authService.restoreSession()
					if authService.isAuthenticated {
						// Session restored, user will be navigated automatically
					}
				}
			}
		}
		.onTapGesture {
			hideKeyboard()
		}
	}
	
	// MARK: - Helper Methods
	
	private func signIn() {
		guard !email.isEmpty && !password.isEmpty else { return }
		
		isLoading = true
		errorMessage = ""
		
		Task {
			do {
				_ = try await authService.signInWithEmail(email: email, password: password)
				// Success - navigation handled by parent view based on authService.isAuthenticated
			} catch let error as AuthError {
				errorMessage = error.localizedDescription ?? "Sign in failed"
				showErrorAlert = true
			} catch {
				errorMessage = error.localizedDescription
				showErrorAlert = true
			}
			
			isLoading = false
		}
	}
	
	private func signUp() {
		guard !email.isEmpty && !password.isEmpty else { return }
		
		isLoading = true
		errorMessage = ""
		
		Task {
			do {
				try await authService.signUpWithEmail(email: email, password: password)
				// After sign up, automatically sign in
				_ = try await authService.signInWithEmail(email: email, password: password)
			} catch let error as AuthError {
				errorMessage = error.localizedDescription ?? "Sign up failed"
				showErrorAlert = true
			} catch {
				errorMessage = error.localizedDescription
				showErrorAlert = true
			}
			
			isLoading = false
		}
	}
	
	private func resetPassword() async {
		guard !resetPasswordEmail.isEmpty else { return }
		
		// TODO: Implement password reset via Supabase
		// For now, show confirmation
		showPasswordResetConfirmation = true
	}
}

// Text field styling extensions for VibeZ theme
extension TextField {
	func withVibeZLoginStyles() -> some View {
		self.padding()
			.background(
				RoundedRectangle(cornerRadius: 12)
					.fill(Color.white.opacity(0.1))
			)
			.overlay(
				RoundedRectangle(cornerRadius: 12)
					.stroke(Color("VibeZGold").opacity(0.5), lineWidth: 1.5)
			)
			.foregroundColor(.white)
			.disableAutocorrection(true)
			.autocapitalization(.none)
	}
}

extension SecureField {
	func withVibeZSecureFieldStyles() -> some View {
		self.padding()
			.background(
				RoundedRectangle(cornerRadius: 12)
					.fill(Color.white.opacity(0.1))
			)
			.overlay(
				RoundedRectangle(cornerRadius: 12)
					.stroke(Color("VibeZGold").opacity(0.5), lineWidth: 1.5)
			)
			.foregroundColor(.white)
			.disableAutocorrection(true)
			.autocapitalization(.none)
	}
}

#Preview {
	LoginView()
}
