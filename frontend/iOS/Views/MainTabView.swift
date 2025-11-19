import SwiftUI
import UIKit

@available(iOS 17.0, *)
struct MainTabView: View {
    @State private var selectedTab: Int = 0
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.clear
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RoomListView()
                .tabItem { 
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
                .accessibilityLabel("Home tab")
                .accessibilityHint("View your rooms")
            
            SearchView()
                .tabItem { 
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)
                .accessibilityLabel("Search tab")
                .accessibilityHint("Search messages, rooms, and users")
            
            ProfileView()
                .tabItem { 
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
                .accessibilityLabel("Settings tab")
                .accessibilityHint("View profile and settings")
        }
        .tint(Color("VibeZGold"))
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        MainTabView()
    } else {
        Text("iOS 17.0+ required")
    }
}
