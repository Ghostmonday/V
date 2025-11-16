import Foundation

@MainActor
class AuthService {
    static func login(username: String, password: String) async throws -> User {
        struct LoginRequest: Codable {
            let username: String
            let password: String
        }
        
        struct LoginResponse: Codable {
            let jwt: String
            let user: User?
        }
        
        let request = LoginRequest(username: username, password: password)
        let response: LoginResponse = try await APIClient.shared.request(
            endpoint: APIClient.Endpoint.authLogin,
            method: "POST",
            body: request
        )
        
        // Store JWT token
        AuthTokenManager.shared.token = response.jwt
        
        // Return user if provided, otherwise create from token
        if let user = response.user {
            return user
        } else {
            // Fallback: create user from available data
            return User(id: UUID(), name: username, avatar: "", mood: "calm")
        }
    }
    
    static func loginWithApple(token: String, ageVerified: Bool) async throws -> User {
        struct AppleAuthRequest: Codable {
            let token: String
            let ageVerified: Bool
        }
        
        struct AppleAuthResponse: Codable {
            let jwt: String
            let livekitToken: String?
            let user: User?
        }
        
        let request = AppleAuthRequest(token: token, ageVerified: ageVerified)
        let response: AppleAuthResponse = try await APIClient.shared.request(
            endpoint: APIClient.Endpoint.authApple,
            method: "POST",
            body: request
        )
        
        AuthTokenManager.shared.token = response.jwt
        
        if let user = response.user {
            return user
        } else {
            return User(id: UUID(), name: "Apple User", avatar: "", mood: "calm")
        }
    }
    
    static func loginWithGoogle(idToken: String, email: String?, ageVerified: Bool) async throws -> User {
        struct GoogleAuthRequest: Codable {
            let idToken: String
            let email: String?
            let ageVerified: Bool
        }
        
        struct GoogleAuthResponse: Codable {
            let jwt: String
            let livekitToken: String?
            let user: User?
        }
        
        let request = GoogleAuthRequest(idToken: idToken, email: email, ageVerified: ageVerified)
        let response: GoogleAuthResponse = try await APIClient.shared.request(
            endpoint: APIClient.Endpoint.authGoogle,
            method: "POST",
            body: request
        )
        
        AuthTokenManager.shared.token = response.jwt
        
        if let user = response.user {
            return user
        } else {
            return User(id: UUID(), name: email ?? "Google User", avatar: "", mood: "calm")
        }
    }
}

