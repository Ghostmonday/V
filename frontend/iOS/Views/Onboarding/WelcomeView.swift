import SwiftUI

/// Welcome screen - first launch
struct WelcomeView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showRoomOptions = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Text("Welcome to VibeZ")
                .font(.system(.largeTitle, weight: .bold))
                .foregroundColor(Color("VibeZGold"))
                .shadow(color: Color("VibeZGlow").opacity(0.6), radius: 8)
            
            Spacer()
            
            Button("Get Started") {
                showRoomOptions = true
            }
            .font(.title3.bold())
            .foregroundColor(.black)
            .padding(.horizontal, 44)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(Color("VibeZGold"))
            )
            .shadow(color: Color("VibeZGoldDark").opacity(0.6), radius: 6, y: 3)
            .padding(.bottom, 60)
        }
        .sheet(isPresented: $showRoomOptions) {
            RoomTierView(onComplete: {
                hasCompletedOnboarding = true
            })
        }
    }
}

#Preview {
    WelcomeView()
}

