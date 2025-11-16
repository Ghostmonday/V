import SwiftUI

// MARK: - Animation Utilities

/// Smooth state transition animation matching Vue transitions
extension View {
    func stateTransition() -> some View {
        self.animation(.easeInOut(duration: 0.2), value: UUID())
    }
    
    func smoothTransition() -> some View {
        self.transition(.opacity.combined(with: .scale))
    }
    
    func slideInTransition() -> some View {
        self.transition(.move(edge: .trailing).combined(with: .opacity))
    }
}

/// Button press animation
struct ButtonPressModifier: ViewModifier {
    let isPressed: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
    }
}

extension View {
    func buttonPress(isPressed: Bool) -> some View {
        modifier(ButtonPressModifier(isPressed: isPressed))
    }
}

/// Loading spinner animation
struct LoadingSpinnerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(0))
            .animation(
                .linear(duration: 1.0).repeatForever(autoreverses: false),
                value: UUID()
            )
    }
}

extension View {
    func spinningLoader() -> some View {
        modifier(LoadingSpinnerModifier())
    }
}

/// Pulse animation for speaking indicators
struct PulseModifier: ViewModifier {
    let isActive: Bool
    @State private var scale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? scale : 1.0)
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        scale = 1.2
                    }
                } else {
                    withAnimation {
                        scale = 1.0
                    }
                }
            }
    }
}

extension View {
    func pulse(isActive: Bool) -> some View {
        modifier(PulseModifier(isActive: isActive))
    }
}

/// Shake animation for errors
struct ShakeModifier: ViewModifier {
    let shake: Bool
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: shake) { _, shouldShake in
                if shouldShake {
                    // Create repeating animation manually
                    let animation = Animation.easeInOut(duration: 0.1)
                    withAnimation(animation) {
                        offset = 10
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(animation) {
                            offset = -10
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(animation) {
                            offset = 10
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(animation) {
                            offset = 0
                        }
                    }
                }
            }
    }
}

extension View {
    func shake(when shake: Bool) -> some View {
        modifier(ShakeModifier(shake: shake))
    }
}

/// Fade in/out animation
struct FadeModifier: ViewModifier {
    let isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.3), value: isVisible)
    }
}

extension View {
    func fade(isVisible: Bool) -> some View {
        modifier(FadeModifier(isVisible: isVisible))
    }
}

/// Matched geometry effect namespace helper
extension View {
    func matchedTransition(id: String, namespace: Namespace.ID) -> some View {
        self.matchedGeometryEffect(id: id, in: namespace)
    }
}

