import SwiftUI

/// Button State Enum (matches TypeScript ButtonState)
enum ButtonState: String {
    case idle
    case hover
    case pressed
    case loading
    case error
    case disabled
}

/// Button State Styling Modifier
struct ButtonStateModifier: ViewModifier {
    let state: ButtonState
    let buttonType: ButtonType
    
    enum ButtonType {
        case primary
        case secondary
        case icon
        case danger
    }
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(8)
            .opacity(state == .disabled ? 0.5 : 1.0)
            .scaleEffect(state == .pressed ? 0.95 : 1.0)
            .overlay(loadingOverlay)
            .animation(.easeInOut(duration: 0.2), value: state)
    }
    
    private var backgroundColor: Color {
        switch (buttonType, state) {
        case (_, .disabled):
            return Color.gray.opacity(0.3)
        case (_, .error):
            return Color.red
        case (.primary, _):
            return Color.blue
        case (.secondary, _):
            return Color.gray
        case (.icon, _):
            return Color.clear
        case (.danger, _):
            return Color.red
        }
    }
    
    private var foregroundColor: Color {
        switch (buttonType, state) {
        case (_, .disabled):
            return Color.gray
        case (.icon, _):
            return Color.primary
        default:
            return Color.white
        }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if state == .loading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
        }
    }
}

extension View {
    func buttonState(_ state: ButtonState, type: ButtonStateModifier.ButtonType = .primary) -> some View {
        modifier(ButtonStateModifier(state: state, buttonType: type))
    }
}

