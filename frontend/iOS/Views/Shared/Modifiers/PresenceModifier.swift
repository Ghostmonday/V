import SwiftUI

/// Presence Status (matches backend presence types)
enum PresenceStatus: String, Codable {
    case online
    case offline
    case away
    case busy
}

/// Presence Indicator Modifier
struct PresenceModifier: ViewModifier {
    let status: PresenceStatus
    let size: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .fill(statusColor)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .shadow(radius: 2)
                , alignment: .bottomTrailing
            )
    }
    
    private var statusColor: Color {
        switch status {
        case .online:
            return Color.green
        case .offline:
            return Color.gray
        case .away:
            return Color.yellow
        case .busy:
            return Color.red
        }
    }
}

extension View {
    func presenceIndicator(status: PresenceStatus, size: CGFloat = 12) -> some View {
        modifier(PresenceModifier(status: status, size: size))
    }
}

