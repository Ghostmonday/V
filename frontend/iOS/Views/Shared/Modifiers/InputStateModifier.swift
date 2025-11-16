import SwiftUI

/// Input State Enum (matches TypeScript InputState)
enum InputState: String {
    case idle
    case focus
    case filled
    case error
    case disabled
    case loading
}

/// Input State Styling Modifier
struct InputStateModifier: ViewModifier {
    let state: InputState
    
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .opacity(state == .disabled ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: state)
    }
    
    private var backgroundColor: Color {
        switch state {
        case .disabled:
            return Color.gray.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        case .focus:
            return Color.blue.opacity(0.05)
        default:
            return Color(UIColor.systemBackground)
        }
    }
    
    private var borderColor: Color {
        switch state {
        case .focus:
            return Color.blue
        case .error:
            return Color.red
        case .filled:
            return Color.green.opacity(0.5)
        case .disabled:
            return Color.gray.opacity(0.3)
        default:
            return Color.gray.opacity(0.3)
        }
    }
    
    private var borderWidth: CGFloat {
        state == .focus ? 2.0 : 1.0
    }
}

extension View {
    func inputState(_ state: InputState) -> some View {
        modifier(InputStateModifier(state: state))
    }
}

