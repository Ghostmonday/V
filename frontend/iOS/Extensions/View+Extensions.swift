import SwiftUI

extension View {
    func ambientFeedback() -> some View {
        self.modifier(AmbientParticlesModifier())
    }
    
    #if canImport(UIKit)
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    #endif
}

struct AmbientParticlesModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay(AmbientParticles())
    }
}

