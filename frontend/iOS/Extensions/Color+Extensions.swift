import SwiftUI

extension Color {
    // Golden VibeZ Theme Colors
    static let vibezGold = Color("VibeZGold")
    static let vibezGoldDark = Color("VibeZGoldDark")
    static let vibezDeep = Color("VibeZDeep")
    static let vibezGlow = Color("VibeZGlow")
    
    // Legacy colors (for backward compatibility)
    static let primaryVibeZ = Color(hex: "#7C4DFF")
    static let voidBlack = Color(hex: "#0A0A0A")
    
    // Communication dashboard colors
    static let commsActive = Color(hex: "#00C853") // Green for active/online
    static let commsWarning = Color(hex: "#FFB300") // Amber for warnings
    static let commsError = Color(hex: "#D32F2F") // Red for errors
    static let glassBackground = Color.white.opacity(0.1)
    static let glassBorder = Color.white.opacity(0.2)
    
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

