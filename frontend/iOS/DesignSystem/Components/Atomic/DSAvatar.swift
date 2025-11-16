/**
 * Design System - Avatar Component
 * 
 * Enhanced avatar component with presence indicators, status rings,
 * and improved accessibility.
 */

import SwiftUI

struct DSAvatar: View {
    let url: String?
    let name: String
    let size: AvatarSize
    let presenceStatus: PresenceStatus?
    let isTyping: Bool
    
    enum AvatarSize {
        case xs
        case sm
        case md
        case lg
        case xl
        
        var dimension: CGFloat {
            switch self {
            case .xs: return 24
            case .sm: return 32
            case .md: return 44
            case .lg: return 64
            case .xl: return 96
            }
        }
        
        var ringWidth: CGFloat {
            switch self {
            case .xs, .sm: return 2
            case .md, .lg: return 3
            case .xl: return 4
            }
        }
    }
    
    enum PresenceStatus {
        case online
        case away
        case busy
        case offline
        
        var color: Color {
            switch self {
            case .online: return .ds(.presenceOnline)
            case .away: return .ds(.presenceAway)
            case .busy: return .ds(.presenceBusy)
            case .offline: return .ds(.presenceOffline)
            }
        }
    }
    
    init(
        url: String? = nil,
        name: String,
        size: AvatarSize = .md,
        presenceStatus: PresenceStatus? = nil,
        isTyping: Bool = false
    ) {
        self.url = url
        self.name = name
        self.size = size
        self.presenceStatus = presenceStatus
        self.isTyping = isTyping
    }
    
    var body: some View {
        ZStack {
            // Avatar circle
            Circle()
                .fill(avatarGradient)
                .frame(width: size.dimension, height: size.dimension)
                .overlay(
                    Group {
                        if let url = url, !url.isEmpty {
                            AsyncImage(url: URL(string: url)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                placeholderView
                            }
                            .clipShape(Circle())
                        } else {
                            placeholderView
                        }
                    }
                )
            
            // Presence ring (if online/away/busy)
            if let status = presenceStatus, status != .offline {
                Circle()
                    .stroke(status.color, lineWidth: size.ringWidth)
                    .frame(width: size.dimension + size.ringWidth * 2, height: size.dimension + size.ringWidth * 2)
                    .opacity(isTyping ? 0.8 : 1.0)
                    .scaleEffect(isTyping ? 1.1 : 1.0)
                    .animation(
                        isTyping ? Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default,
                        value: isTyping
                    )
            }
            
            // Typing indicator pulse
            if isTyping {
                Circle()
                    .fill(Color.ds(.brandPrimary))
                    .frame(width: 8, height: 8)
                    .offset(x: size.dimension / 2 - 4, y: size.dimension / 2 - 4)
                    .opacity(0.9)
                    .scaleEffect(isTyping ? 1.2 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: isTyping
                    )
            }
        }
        .accessibilityLabel("Avatar for \(name)")
        .accessibilityHint(presenceStatus?.accessibilityHint ?? "")
    }
    
    private var avatarGradient: LinearGradient {
        let colors = [
            Color.ds(.brandPrimary),
            Color.ds(.brandAccent)
        ]
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var placeholderView: some View {
        Text(initials)
            .font(.system(size: size.dimension * 0.4, weight: .semibold))
            .foregroundColor(.ds(.textInverse))
    }
    
    private var initials: String {
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else if !name.isEmpty {
            return String(name.prefix(2)).uppercased()
        }
        return "??"
    }
}

extension DSAvatar.PresenceStatus {
    var accessibilityHint: String {
        switch self {
        case .online: return "Online"
        case .away: return "Away"
        case .busy: return "Busy"
        case .offline: return "Offline"
        }
    }
}

// MARK: - Avatar Stack (for room members)

struct DSAvatarStack: View {
    let avatars: [DSAvatar]
    let maxVisible: Int
    let size: DSAvatar.AvatarSize
    
    init(
        avatars: [DSAvatar],
        maxVisible: Int = 4,
        size: DSAvatar.AvatarSize = .sm
    ) {
        self.avatars = avatars
        self.maxVisible = maxVisible
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: -size.dimension * 0.3) {
            ForEach(Array(avatars.prefix(maxVisible).enumerated()), id: \.offset) { index, avatar in
                avatar
                    .overlay(
                        Circle()
                            .stroke(Color.ds(.bgDefault), lineWidth: 2)
                    )
                    .zIndex(Double(maxVisible - index))
            }
            
            if avatars.count > maxVisible {
                // Overflow indicator
                ZStack {
                    Circle()
                        .fill(Color.ds(.controlFill))
                        .frame(width: size.dimension, height: size.dimension)
                        .overlay(
                            Circle()
                                .stroke(Color.ds(.bgDefault), lineWidth: 2)
                        )
                    
                    Text("+\(avatars.count - maxVisible)")
                        .font(.system(size: size.dimension * 0.3, weight: .semibold))
                        .foregroundColor(.ds(.textPrimary))
                }
                .zIndex(0)
            }
        }
    }
}

