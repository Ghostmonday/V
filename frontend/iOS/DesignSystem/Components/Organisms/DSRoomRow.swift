/**
 * Design System - Room Row Component
 * 
 * Enhanced room list item with presence indicators, validation states,
 * and improved visual hierarchy.
 */

import SwiftUI

struct DSRoomRow: View {
    let room: RoomViewModel
    let onTap: () -> Void
    let onLongPress: (() -> Void)?
    
    struct RoomViewModel {
        let id: UUID
        let name: String
        let lastMessage: LastMessageViewModel?
        let unreadCount: Int
        let members: [MemberViewModel]
        let tier: SubscriptionTier
        let isTemp: Bool
        let expiresAt: Date?
        let isValid: Bool
        let validationError: String?
        
        struct LastMessageViewModel {
            let text: String
            let author: String
            let timestamp: Date
        }
        
        struct MemberViewModel {
            let id: UUID
            let name: String
            let avatar: String?
            let presenceStatus: DSAvatar.PresenceStatus
        }
    }
    
    init(
        room: RoomViewModel,
        onTap: @escaping () -> Void,
        onLongPress: (() -> Void)? = nil
    ) {
        self.room = room
        self.onTap = onTap
        self.onLongPress = onLongPress
    }
    
    var body: some View {
        Button(action: {
            DSHaptic.light()
            onTap()
        }) {
            HStack(spacing: DSSpacing.base) {
                // Avatar stack
                DSAvatarStack(
                    avatars: room.members.prefix(4).map { member in
                        DSAvatar(
                            url: member.avatar,
                            name: member.name,
                            size: .md,
                            presenceStatus: member.presenceStatus
                        )
                    },
                    maxVisible: 4,
                    size: .md
                )
                
                // Content
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    // Title row
                    HStack {
                        Text(room.name)
                            .font(DSTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.ds(.textPrimary))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Tier badge
                        if room.tier != .starter {
                            DSTag(room.tier.displayName, color: Color(hex: room.tier.color))
                        }
                        
                        // Temp indicator
                        if room.isTemp, let expiresAt = room.expiresAt {
                            HStack(spacing: DSSpacing.xs) {
                                Image(systemName: "clock")
                                    .font(DSTypography.captionSmall)
                                Text(timeUntilExpiry(expiresAt))
                                    .font(DSTypography.captionSmall)
                            }
                            .foregroundColor(.ds(.stateWarning))
                        }
                        
                        // Validation error indicator
                        if let error = room.validationError {
                            Image(systemName: DSIcon.warning)
                                .font(DSTypography.captionSmall)
                                .foregroundColor(.ds(.stateDanger))
                        }
                    }
                    
                    // Last message
                    if let lastMessage = room.lastMessage {
                        HStack(spacing: DSSpacing.xs) {
                            Text("\(lastMessage.author):")
                                .font(DSTypography.caption)
                                .foregroundColor(.ds(.textSecondary))
                                .lineLimit(1)
                            
                            Text(lastMessage.text)
                                .font(DSTypography.caption)
                                .foregroundColor(.ds(.textSecondary))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(lastMessage.timestamp, style: .relative)
                                .font(DSTypography.captionSmall)
                                .foregroundColor(.ds(.textTertiary))
                        }
                    }
                }
                
                // Unread badge
                if room.unreadCount > 0 {
                    DSBadge(text: "\(room.unreadCount)", variant: .default_)
                }
            }
            .padding(DSSpacing.base)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                    .fill(Color.ds(.bgCard))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                            .stroke(
                                room.isValid ? Color.clear : Color.ds(.stateDanger).opacity(0.3),
                                lineWidth: room.isValid ? 0 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onLongPressGesture {
            DSHaptic.medium()
            onLongPress?()
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
    
    private func timeUntilExpiry(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval < 0 { return "Expired" }
        
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var accessibilityLabel: String {
        var label = "Room: \(room.name)"
        if room.unreadCount > 0 {
            label += ", \(room.unreadCount) unread messages"
        }
        if let error = room.validationError {
            label += ", error: \(error)"
        }
        return label
    }
    
    private var accessibilityHint: String {
        "Double tap to open room, long press for options"
    }
}

