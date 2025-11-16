/**
 * Design System - Message Bubble Component
 * 
 * Enhanced message bubble with validation states, read receipts,
 * reactions, and improved accessibility.
 */

import SwiftUI

struct DSMessageBubble: View {
    let message: MessageViewModel
    let isGrouped: Bool
    let onLongPress: (() -> Void)?
    let onReaction: ((String) -> Void)?
    
    struct MessageViewModel {
        let id: UUID
        let text: String
        let author: AuthorViewModel
        let timestamp: Date
        let isMine: Bool
        let readState: ReadState
        let reactions: [ReactionViewModel]
        let isEdited: Bool
        let isValid: Bool
        let validationError: String?
        
        struct AuthorViewModel {
            let id: UUID
            let name: String
            let avatar: String?
        }
        
        enum ReadState {
            case none
            case sent
            case delivered
            case read
            
            var icon: String {
                switch self {
                case .none: return ""
                case .sent: return "checkmark"
                case .delivered: return "checkmark.circle"
                case .read: return "checkmark.circle.fill"
                }
            }
            
            var color: Color {
                switch self {
                case .none, .sent: return .ds(.textSecondary)
                case .delivered: return .ds(.textSecondary)
                case .read: return .ds(.brandPrimary)
                }
            }
        }
        
        struct ReactionViewModel {
            let emoji: String
            let count: Int
            let isMine: Bool
        }
    }
    
    init(
        message: MessageViewModel,
        isGrouped: Bool = false,
        onLongPress: (() -> Void)? = nil,
        onReaction: ((String) -> Void)? = nil
    ) {
        self.message = message
        self.isGrouped = isGrouped
        self.onLongPress = onLongPress
        self.onReaction = onReaction
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: DSSpacing.sm) {
            if !message.isMine && !isGrouped {
                DSAvatar(
                    url: message.author.avatar,
                    name: message.author.name,
                    size: .sm
                )
            } else if !message.isMine {
                Spacer()
                    .frame(width: 32)
            }
            
            VStack(alignment: message.isMine ? .trailing : .leading, spacing: DSSpacing.xs) {
                // Author name (for group chats)
                if !message.isMine && !isGrouped {
                    Text(message.author.name)
                        .font(DSTypography.caption)
                        .foregroundColor(.ds(.textSecondary))
                        .padding(.horizontal, DSSpacing.sm)
                }
                
                // Message bubble
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    // Validation error indicator
                    if let error = message.validationError {
                        HStack(spacing: DSSpacing.xs) {
                            Image(systemName: DSIcon.warning)
                                .font(DSTypography.captionSmall)
                                .foregroundColor(.ds(.stateDanger))
                            
                            Text(error)
                                .font(DSTypography.captionSmall)
                                .foregroundColor(.ds(.stateDanger))
                        }
                        .padding(.horizontal, DSSpacing.sm)
                        .padding(.top, DSSpacing.xs)
                    }
                    
                    // Message text
                    Text(message.text)
                        .font(DSTypography.body)
                        .foregroundColor(message.isMine ? .ds(.textInverse) : .ds(.textPrimary))
                        .textSelection(.enabled)
                        .padding(DSSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                                .fill(
                                    message.isMine
                                        ? Color.ds(.brandPrimary)
                                        : Color.ds(.bgElevated)
                                )
                                .overlay(
                                    // Validation border
                                    RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                                        .stroke(
                                            message.isValid
                                                ? Color.clear
                                                : Color.ds(.stateDanger).opacity(0.5),
                                            lineWidth: message.isValid ? 0 : 1
                                        )
                                )
                        )
                    
                    // Reactions
                    if !message.reactions.isEmpty {
                        HStack(spacing: DSSpacing.xs) {
                            ForEach(message.reactions, id: \.emoji) { reaction in
                                Button(action: {
                                    onReaction?(reaction.emoji)
                                }) {
                                    HStack(spacing: DSSpacing.xs) {
                                        Text(reaction.emoji)
                                            .font(DSTypography.caption)
                                        
                                        Text("\(reaction.count)")
                                            .font(DSTypography.captionSmall)
                                            .foregroundColor(.ds(.textSecondary))
                                    }
                                    .padding(.horizontal, DSSpacing.sm)
                                    .padding(.vertical, DSSpacing.xs)
                                    .background(
                                        Capsule()
                                            .fill(
                                                reaction.isMine
                                                    ? Color.ds(.brandPrimary).opacity(0.2)
                                                    : Color.ds(.controlFill)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, DSSpacing.sm)
                    }
                }
                
                // Footer (timestamp, read receipt, edited)
                HStack(spacing: DSSpacing.xs) {
                    Text(message.timestamp, style: .time)
                        .font(DSTypography.captionSmall)
                        .foregroundColor(.ds(.textTertiary))
                    
                    if message.isEdited {
                        Text("edited")
                            .font(DSTypography.captionSmall)
                            .foregroundColor(.ds(.textTertiary))
                            .italic()
                    }
                    
                    if message.isMine, message.readState != .none {
                        Image(systemName: message.readState.icon)
                            .font(DSTypography.captionSmall)
                            .foregroundColor(message.readState.color)
                    }
                }
                .padding(.horizontal, DSSpacing.sm)
            }
            
            if message.isMine {
                Spacer(minLength: DSSpacing.xl)
            }
        }
        .padding(.horizontal, DSSpacing.base)
        .padding(.vertical, isGrouped ? DSSpacing.xs : DSSpacing.sm)
        .contentShape(Rectangle())
        .onLongPressGesture {
            DSHaptic.medium()
            onLongPress?()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
    
    private var accessibilityLabel: String {
        var label = message.isMine ? "Your message" : "\(message.author.name)'s message"
        label += ": \(message.text)"
        if message.isEdited {
            label += ", edited"
        }
        if let error = message.validationError {
            label += ", error: \(error)"
        }
        return label
    }
    
    private var accessibilityHint: String {
        if message.isMine {
            return "Double tap and hold to react or edit"
        } else {
            return "Double tap and hold to react"
        }
    }
}

// MARK: - Read Receipt Indicator

struct DSReadReceiptIndicator: View {
    let state: DSMessageBubble.MessageViewModel.ReadState
    let showDetails: Bool
    
    init(state: DSMessageBubble.MessageViewModel.ReadState, showDetails: Bool = false) {
        self.state = state
        self.showDetails = showDetails
    }
    
    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            if state != .none {
                Image(systemName: state.icon)
                    .font(DSTypography.captionSmall)
                    .foregroundColor(state.color)
                    .scaleEffect(state == .read ? 1.0 : 0.9)
                    .animation(DSAnimation.spring, value: state)
            }
            
            if showDetails {
                Text(state.label)
                    .font(DSTypography.captionSmall)
                    .foregroundColor(.ds(.textTertiary))
            }
        }
    }
}

extension DSMessageBubble.MessageViewModel.ReadState {
    var label: String {
        switch self {
        case .none: return ""
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .read: return "Read"
        }
    }
}

