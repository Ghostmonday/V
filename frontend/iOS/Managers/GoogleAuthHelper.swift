import Foundation
import UIKit

#if canImport(GoogleSignIn)
import GoogleSignIn

@MainActor
class GoogleAuthHelper {
    func signIn(ageVerified: Bool) async throws -> GIDGoogleUser {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            throw NSError(domain: "GoogleAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "GIDClientID not found in Info.plist"])
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "GoogleAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller"])
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        let user = result.user
        
        Task {
            do {
                if let idToken = user.idToken?.tokenString {
                    _ = try await AuthService.loginWithGoogle(idToken: idToken, email: user.profile?.email, ageVerified: ageVerified)
                }
            } catch {
                print("Google Sign-In backend error: \(error)")
            }
        }
        
        return user
    }
}
#else
class GoogleAuthHelper {
    func signIn(ageVerified: Bool) async throws -> Any {
        throw NSError(domain: "GoogleAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "GoogleSignIn SDK not available"])
    }
}
#endif
