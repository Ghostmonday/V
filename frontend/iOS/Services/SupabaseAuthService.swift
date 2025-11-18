//
//  SupabaseAuthService.swift
//  VibeZ iOS
//
//  Supabase authentication service with retry logic and exponential backoff
//  Stores sessions in Keychain and enables automatic session refresh
//

import Foundation
import AuthenticationServices
import OSLog
import UIKit

@MainActor
class SupabaseAuthService: ObservableObject {
    static let shared = SupabaseAuthService()
    
    private let logger = Logger(subsystem: "com.vibez.app", category: "SupabaseAuth")
    private let keychain = KeychainHelper.shared
    private let networkReachability = NetworkReachability.shared
    
    // Helper to check network availability
    private var isNetworkAvailable: Bool {
        return networkReachability.isNetworkAvailable
    }
    
    // Keychain keys
    private let accessTokenKey = "supabase_access_token"
    private let refreshTokenKey = "supabase_refresh_token"
    private let sessionKey = "supabase_session"
    
    // Supabase configuration
    private var supabaseURL: String {
        #if DEBUG
        return ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? 
               Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? 
               ""
        #else
        return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
        #endif
    }
    
    private var supabaseAnonKey: String {
        #if DEBUG
        return ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? 
               Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? 
               ""
        #else
        return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
        #endif
    }
    
    // Session state
    @Published var currentSession: UserSession?
    @Published var isAuthenticated: Bool = false
    
    private var refreshTimer: Timer?
    
    private init() {
        // Skip session restoration in UI testing mode to avoid blocking
        if !ProcessInfo.isUITesting {
            // Restore session on init
            Task {
                await restoreSession()
            }
            
            // Setup automatic session refresh
            setupSessionRefresh()
        } else {
            // In UI testing mode, ensure we start with a clean unauthenticated state
            currentSession = nil
            isAuthenticated = false
        }
    }
    
    // MARK: - Configuration
    
    private func validateConfiguration() throws {
        guard !supabaseURL.isEmpty else {
            throw AuthError.configurationError("SUPABASE_URL not configured")
        }
        guard !supabaseAnonKey.isEmpty else {
            throw AuthError.configurationError("SUPABASE_ANON_KEY not configured")
        }
    }
    
    // MARK: - Sign In with Email
    
    func signInWithEmail(email: String, password: String) async throws -> UserSession {
        try validateConfiguration()
        
        // Check network availability
        guard isNetworkAvailable else {
            throw AuthError.networkError("No network connection")
        }
        
        return try await withRetry(maxAttempts: 3) {
            try await self.performEmailSignIn(email: email, password: password)
        }
    }
    
    private func performEmailSignIn(email: String, password: String) async throws -> UserSession {
        guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password") else {
            throw AuthError.configurationError("Invalid Supabase URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 400 {
                throw AuthError.invalidCredentials("Invalid email or password")
            }
            throw AuthError.networkError("Sign in failed with status: \(httpResponse.statusCode)")
        }
        
        let sessionData = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
        let session = UserSession(
            accessToken: sessionData.access_token,
            refreshToken: sessionData.refresh_token,
            userId: sessionData.user.id,
            email: sessionData.user.email
        )
        
        // Store session
        try await storeSession(session)
        
        logger.info("Email sign in successful for user: \(sessionData.user.email ?? "unknown")")
        return session
    }
    
    // MARK: - Sign Up with Email
    
    func signUpWithEmail(email: String, password: String) async throws {
        try validateConfiguration()
        
        guard networkReachability.isNetworkAvailable else {
            throw AuthError.networkError("No network connection")
        }
        
        return try await withRetry(maxAttempts: 3) {
            try await self.performEmailSignUp(email: email, password: password)
        }
    }
    
    private func performEmailSignUp(email: String, password: String) async throws {
        guard let url = URL(string: "\(supabaseURL)/auth/v1/signup") else {
            throw AuthError.configurationError("Invalid Supabase URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            if httpResponse.statusCode == 400 {
                throw AuthError.invalidCredentials("Email already registered or invalid")
            }
            throw AuthError.networkError("Sign up failed with status: \(httpResponse.statusCode)")
        }
        
        logger.info("Email sign up successful for: \(email)")
    }
    
    // MARK: - Sign In with Apple
    
    func signInWithApple() async throws -> UserSession {
        try validateConfiguration()
        
        guard networkReachability.isNetworkAvailable else {
            throw AuthError.networkError("No network connection")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate { [weak self] result in
                Task { @MainActor in
                    do {
                        let session = try await self?.handleAppleSignIn(result: result) ?? {
                            throw AuthError.appleSignInFailed("Apple Sign-In failed")
                        }()
                        continuation.resume(returning: session)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            
            DispatchQueue.main.async {
                controller.performRequests()
            }
            
            // Store delegate to prevent deallocation
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) async throws -> UserSession {
        let authorization = try result.get()
        
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.appleSignInFailed("Invalid Apple credential")
        }
        
        return try await withRetry(maxAttempts: 3) {
            try await self.performAppleSignIn(token: tokenString)
        }
    }
    
    private func performAppleSignIn(token: String) async throws -> UserSession {
        guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=id_token") else {
            throw AuthError.configurationError("Invalid Supabase URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "provider": "apple",
            "id_token": token
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.appleSignInFailed("Apple Sign-In failed with status: \(httpResponse.statusCode)")
        }
        
        let sessionData = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
        let session = UserSession(
            accessToken: sessionData.access_token,
            refreshToken: sessionData.refresh_token,
            userId: sessionData.user.id,
            email: sessionData.user.email
        )
        
        // Store session
        try await storeSession(session)
        
        logger.info("Apple sign in successful")
        return session
    }
    
    // MARK: - Session Management
    
    func restoreSession() async {
        // Skip network operations in UI testing mode
        if ProcessInfo.isUITesting {
            logger.info("UI testing mode - skipping session restoration")
            return
        }
        
        guard let sessionData = keychain.retrieve(key: sessionKey),
              let data = sessionData.data(using: .utf8),
              let session = try? JSONDecoder().decode(UserSession.self, from: data) else {
            logger.info("No stored session found")
            return
        }
        
        // Verify session is still valid
        if await verifySession(session) {
            currentSession = session
            isAuthenticated = true
            logger.info("Session restored successfully")
        } else {
            // Try to refresh
            if let refreshedSession = try? await refreshSession(refreshToken: session.refreshToken) {
                currentSession = refreshedSession
                isAuthenticated = true
                logger.info("Session refreshed on restore")
            } else {
                // Clear invalid session
                await logout()
                logger.warning("Stored session invalid, cleared")
            }
        }
    }
    
    private func verifySession(_ session: UserSession) async -> Bool {
        // Skip network verification in UI testing mode
        if ProcessInfo.isUITesting {
            return false
        }
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/user") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
    
    func refreshSession(refreshToken: String) async throws -> UserSession {
        try validateConfiguration()
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token") else {
            throw AuthError.configurationError("Invalid Supabase URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "refresh_token": refreshToken
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.invalidCredentials("Session expired")
        }
        
        let sessionData = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
        let session = UserSession(
            accessToken: sessionData.access_token,
            refreshToken: sessionData.refresh_token,
            userId: sessionData.user.id,
            email: sessionData.user.email
        )
        
        try await storeSession(session)
        return session
    }
    
    private func storeSession(_ session: UserSession) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(session)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw AuthError.networkError("Failed to encode session")
        }
        
        try keychain.store(key: sessionKey, value: jsonString)
        try keychain.store(key: accessTokenKey, value: session.accessToken)
        try keychain.store(key: refreshTokenKey, value: session.refreshToken)
        
        currentSession = session
        isAuthenticated = true
    }
    
    func logout() async {
        keychain.delete(key: sessionKey)
        keychain.delete(key: accessTokenKey)
        keychain.delete(key: refreshTokenKey)
        
        currentSession = nil
        isAuthenticated = false
        
        refreshTimer?.invalidate()
        refreshTimer = nil
        
        logger.info("User logged out")
    }
    
    // MARK: - Automatic Session Refresh
    
    private func setupSessionRefresh() {
        // Refresh session every 50 minutes (Supabase tokens typically expire after 1 hour)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 50 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshSessionIfNeeded()
            }
        }
    }
    
    private func refreshSessionIfNeeded() async {
        guard let session = currentSession else {
            return
        }
        
        // Check network availability
        guard isNetworkAvailable else {
            return
        }
        
        do {
            let refreshedSession = try await refreshSession(refreshToken: session.refreshToken)
            logger.info("Session automatically refreshed")
        } catch {
            logger.error("Failed to refresh session: \(error.localizedDescription)")
            // If refresh fails, try to restore session
            await restoreSession()
        }
    }
    
    // MARK: - Retry Logic with Exponential Backoff
    
    private func withRetry<T>(maxAttempts: Int, delay: TimeInterval = 1.0, _ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Don't retry on certain errors
                if let authError = error as? AuthError {
                    switch authError {
                    case .invalidCredentials, .configurationError:
                        throw error
                    default:
                        break
                    }
                }
                
                if attempt < maxAttempts {
                    let backoffDelay = delay * pow(2.0, Double(attempt - 1))
                    logger.info("Retry attempt \(attempt)/\(maxAttempts) after \(backoffDelay)s")
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? AuthError.networkError("Operation failed after \(maxAttempts) attempts")
    }
}

// MARK: - Supporting Types

struct UserSession: Codable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let email: String?
}

struct SupabaseAuthResponse: Codable {
    let access_token: String
    let refresh_token: String
    let user: SupabaseUser
}

struct SupabaseUser: Codable {
    let id: String
    let email: String?
}

enum AuthError: LocalizedError {
    case networkError(String)
    case invalidCredentials(String)
    case appleSignInFailed(String)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return message
        case .invalidCredentials(let message):
            return message
        case .appleSignInFailed(let message):
            return message
        case .configurationError(let message):
            return message
        }
    }
}

// MARK: - Apple Sign-In Delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<ASAuthorization, Error>) -> Void
    
    init(completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        completion(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}

