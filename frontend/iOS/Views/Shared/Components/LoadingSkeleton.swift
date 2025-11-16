import SwiftUI

/// Loading Skeleton Component - Shimmer effect for loading states
struct LoadingSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.gray.opacity(0.2)
                
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 0.6)
                .offset(x: isAnimating ? geometry.size.width : -geometry.size.width * 0.6)
                .animation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            }
        }
        .onAppear {
            isAnimating = true
        }
        .accessibilityLabel("Loading")
    }
}

/// Skeleton Text - Placeholder for text content
struct SkeletonText: View {
    let width: CGFloat?
    let height: CGFloat
    
    init(width: CGFloat? = nil, height: CGFloat = 16) {
        self.width = width
        self.height = height
    }
    
    var body: some View {
        LoadingSkeleton()
            .frame(width: width, height: height)
            .cornerRadius(4)
    }
}

/// Skeleton Card - Placeholder for card content
struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonText(width: 200, height: 20)
            SkeletonText(width: 150, height: 16)
            SkeletonText(width: nil, height: 16)
            SkeletonText(width: 100, height: 16)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 16) {
        SkeletonCard()
        SkeletonCard()
        SkeletonCard()
    }
    .padding()
}

