/**
 * Design System - Presence Orb Component
 * 
 * Enhanced presence orb with breathing animation, status colors,
 * and improved visual feedback.
 */

import SwiftUI

struct DSPresenceOrb: View {
    let status: PresenceStatus
    let size: OrbSize
    let isPulsing: Bool
    
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
        
        var glowIntensity: Double {
            switch self {
            case .online: return 0.8
            case .away: return 0.5
            case .busy: return 0.6
            case .offline: return 0.2
            }
        }
    }
    
    enum OrbSize {
        case sm
        case md
        case lg
        
        var dimension: CGFloat {
            switch self {
            case .sm: return 8
            case .md: return 12
            case .lg: return 16
            }
        }
        
        var glowRadius: CGFloat {
            switch self {
            case .sm: return 4
            case .md: return 6
            case .lg: return 8
            }
        }
    }
    
    @State private var breathingScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.6
    
    init(
        status: PresenceStatus,
        size: OrbSize = .md,
        isPulsing: Bool = true
    ) {
        self.status = status
        self.size = size
        self.isPulsing = isPulsing
    }
    
    var body: some View {
        Circle()
            .fill(status.color.opacity(0.9))
            .frame(width: size.dimension, height: size.dimension)
            .shadow(
                color: status.color.opacity(glowOpacity),
                radius: size.glowRadius
            )
            .scaleEffect(breathingScale)
            .onAppear {
                if isPulsing && status != .offline {
                    startBreathingAnimation()
                }
            }
            .onChange(of: status) { _ in
                if isPulsing && status != .offline {
                    startBreathingAnimation()
                } else {
                    breathingScale = 1.0
                    glowOpacity = status.glowIntensity
                }
            }
            .accessibilityLabel("Presence: \(status.accessibilityLabel)")
    }
    
    private func startBreathingAnimation() {
        // Respect reduce motion preference
        if UIAccessibility.isReduceMotionEnabled {
            breathingScale = 1.0
            glowOpacity = status.glowIntensity
            return
        }
        
        // Breathing animation: 3 second loop
        withAnimation(
            Animation.easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
        ) {
            breathingScale = 0.96
        }
        
        // Glow pulse animation
        withAnimation(
            Animation.easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
        ) {
            glowOpacity = status.glowIntensity * 0.7
        }
    }
}

extension DSPresenceOrb.PresenceStatus {
    var accessibilityLabel: String {
        switch self {
        case .online: return "Online"
        case .away: return "Away"
        case .busy: return "Busy"
        case .offline: return "Offline"
        }
    }
}

// MARK: - Presence Indicator (with label)

struct DSPresenceIndicator: View {
    let status: DSPresenceOrb.PresenceStatus
    let label: String?
    
    init(status: DSPresenceOrb.PresenceStatus, label: String? = nil) {
        self.status = status
        self.label = label
    }
    
    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            DSPresenceOrb(status: status)
            
            if let label = label {
                Text(label)
                    .font(DSTypography.caption)
                    .foregroundColor(.ds(.textSecondary))
            }
        }
    }
}

