import SwiftUI

struct MainView: View {
    @State private var selectedTab: Tab = .home
    
    enum Tab {
        case home, explore, profile
    }
    
    var body: some View {
        ZStack {
            VibezBackground()
            
            // Content
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .explore:
                    ExploreView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Floating Tab Bar
            VStack {
                Spacer()
                HStack(spacing: 40) {
                    TabButton(icon: "house.fill", isSelected: selectedTab == .home) {
                        selectedTab = .home
                    }
                    
                    TabButton(icon: "waveform", isSelected: selectedTab == .explore) {
                        selectedTab = .explore
                    }
                    
                    TabButton(icon: "person.fill", isSelected: selectedTab == .profile) {
                        selectedTab = .profile
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.Vibez.deepVoid.opacity(0.8))
                        .background(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                )
                .padding(.bottom, 20)
            }
        }
    }
}

struct TabButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(isSelected ? Color.Vibez.electricBlue : Color.Vibez.textSecondary)
                .shadow(color: isSelected ? Color.Vibez.electricBlue.opacity(0.5) : .clear, radius: 10)
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
    }
}

