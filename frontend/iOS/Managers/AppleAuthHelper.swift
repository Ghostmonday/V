import Foundation
import AuthenticationServices
import UIKit

@MainActor
class AppleAuthHelper: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var isAvailable = false
    private var continuation: CheckedContinuation<ASAuthorization, Error>?
    
    override init() {
        super.init()
        isAvailable = true
    }
    
    func signIn(ageVerified: Bool) async {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        
        // Store ageVerified for use in delegate
        self.ageVerified = ageVerified
        
        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
                self.continuation = continuation
                controller.performRequests()
            }
        } catch {
            print("Apple Sign-In error: \(error)")
        }
    }
    
    private var ageVerified: Bool = false
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task {
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                do {
                    if let identityToken = credential.identityToken {
                        let tokenString = identityToken.base64EncodedString()
                        _ = try await AuthService.loginWithApple(token: tokenString, ageVerified: ageVerified)
                    }
                } catch {
                    print("Apple Sign-In backend error: \(error)")
                }
            }
        }
        continuation?.resume(returning: authorization)
        continuation = nil
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple Sign-In error: \(error)")
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
