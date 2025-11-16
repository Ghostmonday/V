import SwiftUI

/// Accessibility Helper Extension
/// Provides convenient accessibility modifiers for all interactive elements
extension View {
    /// Add accessibility labels, hints, and values to any view
    /// - Parameters:
    ///   - label: The accessibility label (required)
    ///   - hint: Optional hint describing what happens when activated
    ///   - value: Optional current value or state
    func accessible(_ label: String, hint: String? = nil, value: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
    }
    
    /// Add accessibility support for buttons
    func accessibleButton(_ label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "Double tap to activate")
            .accessibilityAddTraits(.isButton)
    }
    
    /// Add accessibility support for toggles
    func accessibleToggle(_ label: String, isOn: Bool, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "Double tap to toggle")
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityAddTraits(.isButton)
    }
    
    /// Support reduced motion preferences
    @ViewBuilder
    func reducedMotion<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if UIAccessibility.isReduceMotionEnabled {
            content()
        } else {
            self
        }
    }
}

