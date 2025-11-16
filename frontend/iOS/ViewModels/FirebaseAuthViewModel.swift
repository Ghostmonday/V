//
//  FirebaseAuthViewModel.swift
//  VibeZ iOS
//
//  Firebase authentication view model with backend JWT exchange
//

import SwiftUI
import FirebaseAuth
import Combine

@MainActor
class FirebaseAuthViewModel: ObservableObject {
	
	// Published properties
	@Published var state: AuthState = .signedOut
	@Published var error: FirebaseAuthError?
	@Published var isLoading: Bool = false
	@Published var signInMethod: String = "Unknown"
	@Published var currentFirebaseUser: FirebaseAuth.User?
	@Published var currentAppUser: User?
	
	// Dependencies
	private let authRepository: FirebaseAuthRepositoryProtocol
	private var cancellables = Set<AnyCancellable>()
	private var tokenRefreshTimer: Timer?
	
	// Initializer with dependency injection
	init(authRepository: FirebaseAuthRepositoryProtocol = FirebaseAuthRepository()) {
		self.authRepository = authRepository
		checkAuthenticationState()
		setupAuthStateListener()
		setupTokenRefresh()
	}
	
	// MARK: - Token Refresh
	
	/// Setup periodic token refresh (every 50 minutes, Firebase tokens expire after 1 hour)
	private func setupTokenRefresh() {
		// Refresh token every 50 minutes to prevent expiration
		tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: 50 * 60, repeats: true) { [weak self] _ in
			Task { @MainActor in
				await self?.refreshTokenIfNeeded()
			}
		}
	}
	
	/// Refresh Firebase token and backend JWT if user is signed in
	@MainActor
	private func refreshTokenIfNeeded() async {
		guard let firebaseUser = currentFirebaseUser, state == .signedIn else {
			return
		}
		
		do {
			// Refresh Firebase ID token (forces token refresh)
			_ = try await firebaseUser.getIDToken(forcingRefresh: true)
			
			// Exchange refreshed token for backend JWT
			_ = try await exchangeFirebaseTokenForJWT(firebaseUser: firebaseUser)
		} catch {
			// Log error but don't block - token might still be valid
			print("Token refresh failed: \(error.localizedDescription)")
		}
	}
	
	deinit {
		tokenRefreshTimer?.invalidate()
	}
	
	// Listen for Firebase auth state changes
	private func setupAuthStateListener() {
		Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
			guard let self = self else { return }
			
			// Update current Firebase user
			self.currentFirebaseUser = user
			
			// Update auth state
			self.state = user != nil ? .signedIn : .signedOut
			
			// Update sign in method if signed in
			if let user = user {
				self.determineSignInMethod(for: user)
				// Sync with backend when user changes
				Task {
					await self.syncWithBackend(firebaseUser: user)
				}
			} else {
				// Clear backend token on sign out
				AuthTokenManager.shared.token = nil
				self.currentAppUser = nil
			}
		}
	}
	
	// Determine how the user signed in
	private func determineSignInMethod(for user: FirebaseAuth.User) {
		if let providerData = user.providerData.first?.providerID {
			switch providerData {
			case "google.com":
				signInMethod = "Google"
			case "apple.com":
				signInMethod = "Apple"
			case "password":
				signInMethod = "Email / Password"
			default:
				signInMethod = providerData
			}
		}
	}
	
	// Check if user is already signed in
	private func checkAuthenticationState() {
		self.currentFirebaseUser = authRepository.getCurrentUser()
		
		if let user = currentFirebaseUser {
			self.state = .signedIn
			determineSignInMethod(for: user)
			// Sync with backend
			Task {
				await self.syncWithBackend(firebaseUser: user)
			}
		} else {
			self.state = .signedOut
		}
	}
	
	// MARK: - Backend Integration
	
	/// Exchange Firebase ID token for backend JWT token
	private func exchangeFirebaseTokenForJWT(firebaseUser: FirebaseAuth.User) async throws -> String {
		// Get Firebase ID token
		let idToken = try await firebaseUser.getIDToken()
		
		// Exchange with backend
		struct FirebaseAuthRequest: Codable {
			let idToken: String
		}
		
		struct FirebaseAuthResponse: Codable {
			let jwt: String
			let user: User?
		}
		
		let request = FirebaseAuthRequest(idToken: idToken)
		let response: FirebaseAuthResponse = try await APIClient.shared.request(
			endpoint: APIClient.Endpoint.authFirebase,
			method: "POST",
			body: request
		)
		
		// Store JWT token
		AuthTokenManager.shared.token = response.jwt
		
		// Update app user if provided
		if let user = response.user {
			self.currentAppUser = user
		} else {
			// Convert Firebase user to app user
			self.currentAppUser = convertFirebaseUserToAppUser(firebaseUser)
		}
		
		return response.jwt
	}
	
	/// Sync Firebase user with backend
	private func syncWithBackend(firebaseUser: FirebaseAuth.User) async {
		do {
			_ = try await exchangeFirebaseTokenForJWT(firebaseUser: firebaseUser)
		} catch {
			// Log error but don't block auth flow
			print("Failed to sync with backend: \(error.localizedDescription)")
			// Still convert Firebase user to app user for local use
			self.currentAppUser = convertFirebaseUserToAppUser(firebaseUser)
		}
	}
	
	/// Convert Firebase User to app User model
	private func convertFirebaseUserToAppUser(_ firebaseUser: FirebaseAuth.User) -> User {
		return User.from(firebaseUser: firebaseUser)
	}
	
	// MARK: - Authentication Methods
	
	/// Master login function that will handle multiple login types
	func login(with loginOption: LoginOption) async {
		isLoading = true
		error = nil
		
		defer { isLoading = false }
		
		do {
			let firebaseUser: FirebaseAuth.User
			
			switch loginOption {
			case .signInWithApple:
				firebaseUser = try await signInWithApple()
			case let .emailAndPassword(email, password):
				firebaseUser = try await signInWithEmail(email: email, password: password)
			case .signInWithGoogle:
				firebaseUser = try await signInWithGoogle()
			}
			
			// Exchange Firebase token for backend JWT
			_ = try await exchangeFirebaseTokenForJWT(firebaseUser: firebaseUser)
			
			// Save login state to UserDefaults
			UserDefaults.standard.set(true, forKey: "isLoggedIn")
			
		} catch let authError as FirebaseAuthError {
			self.error = authError
		} catch {
			self.error = .signInFailed(description: error.localizedDescription)
		}
	}
	
	func signInWithEmail(email: String, password: String) async throws -> FirebaseAuth.User {
		let user = try await authRepository.signInWithEmail(email: email, password: password)
		self.currentFirebaseUser = user
		return user
	}
	
	func signUp(email: String, password: String) async throws {
		let user = try await authRepository.signUpWithEmail(email: email, password: password)
		self.currentFirebaseUser = user
		// Exchange token for backend JWT
		_ = try await exchangeFirebaseTokenForJWT(firebaseUser: user)
	}
	
	func signInWithGoogle() async throws -> FirebaseAuth.User {
		let user = try await authRepository.signInWithGoogle()
		self.currentFirebaseUser = user
		return user
	}
	
	func signInWithApple() async throws -> FirebaseAuth.User {
		return try await withCheckedThrowingContinuation { continuation in
			authRepository.signInWithApple { result in
				switch result {
				case .success(let user):
					Task { @MainActor in
						self.currentFirebaseUser = user
						continuation.resume(returning: user)
					}
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}
	
	func signOut() async {
		isLoading = true
		error = nil
		
		do {
			try await authRepository.signOut()
			UserDefaults.standard.set(false, forKey: "isLoggedIn")
			state = .signedOut
			currentFirebaseUser = nil
			currentAppUser = nil
			AuthTokenManager.shared.token = nil
		} catch {
			self.error = error as? FirebaseAuthError ?? .signOutFailed(description: error.localizedDescription)
		}
		
		isLoading = false
	}
	
	// MARK: - User Profile Methods
	
	func sendPasswordReset(email: String) async {
		isLoading = true
		error = nil
		
		do {
			try await authRepository.sendPasswordReset(email: email)
		} catch {
			self.error = error as? FirebaseAuthError ?? .passwordResetFailed(description: error.localizedDescription)
		}
		
		isLoading = false
	}
	
	func sendEmailVerification() async {
		isLoading = true
		error = nil
		
		do {
			try await authRepository.sendEmailVerification()
		} catch {
			self.error = error as? FirebaseAuthError
		}
		
		isLoading = false
	}
	
	func updateProfile(displayName: String?, photoURL: URL?) async {
		isLoading = true
		error = nil
		
		do {
			try await authRepository.updateUserProfile(displayName: displayName, photoURL: photoURL)
			// Refresh current user
			if let user = authRepository.getCurrentUser() {
				self.currentFirebaseUser = user
				self.currentAppUser = convertFirebaseUserToAppUser(user)
			}
		} catch {
			self.error = error as? FirebaseAuthError
		}
		
		isLoading = false
	}
	
	func updateEmail(email: String) async {
		isLoading = true
		error = nil
		
		do {
			try await authRepository.updateEmail(email: email)
			// Refresh current user
			if let user = authRepository.getCurrentUser() {
				self.currentFirebaseUser = user
				self.currentAppUser = convertFirebaseUserToAppUser(user)
			}
		} catch {
			self.error = error as? FirebaseAuthError
		}
		
		isLoading = false
	}
	
	func updatePassword(password: String) async {
		isLoading = true
		error = nil
		
		do {
			try await authRepository.updatePassword(password: password)
		} catch {
			self.error = error as? FirebaseAuthError
		}
		
		isLoading = false
	}
	
	func deleteAccount() async {
		isLoading = true
		error = nil
		
		do {
			try await authRepository.deleteAccount()
			UserDefaults.standard.set(false, forKey: "isLoggedIn")
			state = .signedOut
			currentFirebaseUser = nil
			currentAppUser = nil
			AuthTokenManager.shared.token = nil
		} catch {
			self.error = error as? FirebaseAuthError
		}
		
		isLoading = false
	}
	
	func reauthenticate(email: String, password: String) async {
		isLoading = true
		error = nil
		
		do {
			try await authRepository.reauthenticate(email: email, password: password)
		} catch {
			self.error = error as? FirebaseAuthError
		}
		
		isLoading = false
	}
}

