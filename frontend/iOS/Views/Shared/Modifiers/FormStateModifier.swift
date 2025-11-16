import SwiftUI

/// Form State Enum (matches TypeScript FormState)
enum FormState: String {
    case idle
    case submitting
    case success
    case error
}

/// Form State Styling Modifier
struct FormStateModifier: ViewModifier {
    let state: FormState
    
    func body(content: Content) -> some View {
        content
            .disabled(state == .submitting)
            .opacity(state == .submitting ? 0.7 : 1.0)
            .overlay(successOverlay)
            .overlay(errorOverlay)
            .animation(.easeInOut(duration: 0.2), value: state)
    }
    
    @ViewBuilder
    private var successOverlay: some View {
        if state == .success {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green, lineWidth: 2)
                .background(Color.green.opacity(0.1).cornerRadius(8))
                .transition(.opacity)
        }
    }
    
    @ViewBuilder
    private var errorOverlay: some View {
        if state == .error {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red, lineWidth: 2)
                .background(Color.red.opacity(0.1).cornerRadius(8))
                .shake(when: state == .error)
                .transition(.opacity)
        }
    }
}

extension View {
    func formState(_ state: FormState) -> some View {
        modifier(FormStateModifier(state: state))
    }
}

