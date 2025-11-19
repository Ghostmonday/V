import SwiftUI

struct VibezBackground: View {
    var body: some View {
        ZStack {
            Color.Vibez.background.ignoresSafeArea()
            
            // Subtle ambient glow
            GeometryReader { geometry in
                Circle()
                    .fill(Color.Vibez.electricBlue)
                    .frame(width: 300, height: 300)
                    .blur(radius: 100)
                    .opacity(0.1)
                    .position(x: geometry.size.width * 0.2, y: geometry.size.height * 0.2)
                
                Circle()
                    .fill(Color.Vibez.plasmaPurple)
                    .frame(width: 250, height: 250)
                    .blur(radius: 100)
                    .opacity(0.1)
                    .position(x: geometry.size.width * 0.8, y: geometry.size.height * 0.8)
            }
        }
    }
}

