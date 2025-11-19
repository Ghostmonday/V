import SwiftUI

extension Color {
    struct Vibez {
        // Primary Colors
        static let background = Color(hex: "05050A")
        static let deepVoid = Color(hex: "0A0A12")
        static let electricBlue = Color(hex: "2E5CFF")
        static let neonCyan = Color(hex: "00F0FF")
        static let plasmaPurple = Color(hex: "7B2EFF")
        
        // Functional Colors
        static let success = Color(hex: "00FF94")
        static let warning = Color(hex: "FFD600")
        static let error = Color(hex: "FF2E2E")
        static let textPrimary = Color(hex: "FFFFFF")
        static let textSecondary = Color(hex: "8F9BB3")
        
        // Gradients
        static let primaryGradient = LinearGradient(
            gradient: Gradient(colors: [electricBlue, plasmaPurple]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let darkVoidGradient = LinearGradient(
            gradient: Gradient(colors: [background, deepVoid]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}


