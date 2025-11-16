/**
 * Design System - Empty State Component
 * 
 * Consistent empty states with SF Symbols (no image assets needed).
 * Updated to use SwiftUI-generated icons instead of raster images.
 */

import SwiftUI

struct DSEmptyState: View {
    let type: EmptyStateType
    let title: String
    let message: String
    let action: EmptyStateAction?
    
    struct EmptyStateAction {
        let title: String
        let icon: String?
        let handler: () -> Void
    }
    
    enum EmptyStateType {
        case rooms
        case messages
        case search
        case error
        
        var systemImage: String {
            switch self {
            case .rooms: return "door.left.hand.open"
            case .messages: return "message"
            case .search: return "magnifyingglass"
            case .error: return "exclamationmark.triangle"
            }
        }
        
        var size: CGFloat {
            switch self {
            case .rooms, .messages, .search: return 64
            case .error: return 48
            }
        }
    }
    
    init(
        type: EmptyStateType,
        title: String,
        message: String,
        action: EmptyStateAction? = nil
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: DSSpacing.base) {
            Image(systemName: type.systemImage)
                .font(.system(size: type.size))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.ds(.brandPrimary), .ds(.brandAccent)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .ds(.brandPrimary).opacity(0.3), radius: 10)
            
            VStack(spacing: DSSpacing.sm) {
                Text(title)
                    .font(DSTypography.title2)
                    .foregroundColor(.ds(.textPrimary))
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(DSTypography.body)
                    .foregroundColor(.ds(.textSecondary))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.xl)
            }
            
            if let action = action {
                DSPrimaryButton(action.title, icon: action.icon, size: .medium) {
                    action.handler()
                }
                .padding(.horizontal, DSSpacing.xl)
            }
        }
        .padding(DSSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Predefined Empty States

extension DSEmptyState {
    static func rooms(action: @escaping () -> Void) -> DSEmptyState {
        DSEmptyState(
            type: .rooms,
            title: "No rooms yet",
            message: "Create a room to start a conversation",
            action: EmptyStateAction(
                title: "Create Room",
                icon: "plus.circle.fill",
                handler: action
            )
        )
    }
    
    static func messages() -> DSEmptyState {
        DSEmptyState(
            type: .messages,
            title: "Say hi",
            message: "Messages appear here"
        )
    }
    
    static func search() -> DSEmptyState {
        DSEmptyState(
            type: .search,
            title: "Try searching",
            message: "Search for a room name, user, or keyword"
        )
    }
    
    static func error(_ error: String) -> DSEmptyState {
        DSEmptyState(
            type: .error,
            title: "Something went wrong",
            message: error
        )
    }
}

