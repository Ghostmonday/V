import SwiftUI

/// Loading Spinner Component
/// Reusable spinner matching Vue loading states
struct LoadingSpinner: View {
    @State private var isAnimating = false
    let size: CGFloat
    let color: Color
    
    init(size: CGFloat = 20, color: Color = .white) {
        self.size = size
        self.color = color
    }
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(color, lineWidth: 2)
            .frame(width: size, height: size)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

#Preview {
    LoadingSpinner()
        .padding()
        .background(Color.blue)
}

