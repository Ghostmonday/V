import SwiftUI

struct VibezTypography {
    static let headerLarge = Font.system(size: 34, weight: .bold, design: .rounded)
    static let headerMedium = Font.system(size: 28, weight: .bold, design: .rounded)
    static let headerSmall = Font.system(size: 22, weight: .semibold, design: .rounded)
    
    static let bodyLarge = Font.system(size: 17, weight: .medium, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)
    
    static let button = Font.system(size: 17, weight: .bold, design: .rounded)
    static let caption = Font.system(size: 11, weight: .medium, design: .default)
}

extension View {
    func vibezHeaderLarge() -> some View {
        self.font(VibezTypography.headerLarge).foregroundColor(Color.Vibez.textPrimary)
    }
    
    func vibezHeaderMedium() -> some View {
        self.font(VibezTypography.headerMedium).foregroundColor(Color.Vibez.textPrimary)
    }
    
    func vibezHeaderSmall() -> some View {
        self.font(VibezTypography.headerSmall).foregroundColor(Color.Vibez.textPrimary)
    }
    
    func vibezBody() -> some View {
        self.font(VibezTypography.bodyMedium).foregroundColor(Color.Vibez.textSecondary)
    }
}

