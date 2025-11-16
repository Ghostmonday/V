/**
 * Design System - SwiftUI-Generated Backgrounds
 * 
 * Background components generated in code (no image assets needed).
 * These use SwiftUI gradients, materials, and shapes for perfect scaling.
 */

import SwiftUI

// MARK: - Onboarding Background

struct DSOnboardingBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.ds(.bgDefault),
                Color.ds(.brandPrimary).opacity(0.3),
                Color.ds(.brandAccent).opacity(0.2),
                Color.ds(.bgDefault)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Voice Room Background

struct DSVoiceRoomBackground: View {
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color.ds(.bgDefault),
                    Color.ds(.brandPrimary).opacity(0.1),
                    Color.ds(.bgDefault)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Subtle waveform pattern overlay
            WaveformPattern()
                .opacity(0.1)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Waveform Pattern

struct WaveformPattern: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let centerY = height / 2
                
                // Create subtle waveform pattern
                path.move(to: CGPoint(x: 0, y: centerY))
                
                for x in stride(from: 0, to: width, by: 20) {
                    let amplitude = sin(x / 50) * 30
                    path.addLine(to: CGPoint(x: x, y: centerY + amplitude))
                }
            }
            .stroke(Color.ds(.brandPrimary), lineWidth: 1)
        }
    }
}

// MARK: - Dashboard Card Background

struct DSDashboardCardBackground: View {
    let style: CardStyle
    
    enum CardStyle {
        case default_
        case elevated
        case overlay
        
        var material: Material {
            switch self {
            case .default_: return .ultraThinMaterial
            case .elevated: return .thinMaterial
            case .overlay: return .regularMaterial
            }
        }
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
            .fill(style.material)
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .stroke(Color.ds(.controlStroke).opacity(0.2), lineWidth: 1)
            )
            .shadow(
                color: DSShadow.card.color,
                radius: DSShadow.card.radius,
                x: DSShadow.card.x,
                y: DSShadow.card.y
            )
    }
}

// MARK: - Chat Bubble Tail

struct DSChatBubbleTail: Shape {
    var isMine: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        if isMine {
            // Right-side tail (for sent messages)
            path.move(to: CGPoint(x: rect.maxX, y: rect.midY - 6))
            path.addLine(to: CGPoint(x: rect.maxX + 8, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + 6))
            path.closeSubpath()
        } else {
            // Left-side tail (for received messages)
            path.move(to: CGPoint(x: rect.minX, y: rect.midY - 6))
            path.addLine(to: CGPoint(x: rect.minX - 8, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + 6))
            path.closeSubpath()
        }
        
        return path
    }
}

// MARK: - Loading Shimmer

struct DSLoadingShimmer: View {
    @State private var shimmerOffset: CGFloat = -1
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.ds(.bgDefault),
                Color.ds(.shimmer),
                Color.ds(.bgDefault)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .offset(x: shimmerOffset * 400)
        .animation(
            .linear(duration: 1.5)
                .repeatForever(autoreverses: false),
            value: shimmerOffset
        )
        .onAppear {
            shimmerOffset = 1
        }
    }
}

// MARK: - Shimmer Overlay Modifier

struct ShimmerModifier: ViewModifier {
    @State private var shimmerOffset: CGFloat = -1
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        Color.ds(.shimmer).opacity(0.3),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: shimmerOffset * 400)
                .animation(
                    .linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                    value: shimmerOffset
                )
            )
            .onAppear {
                shimmerOffset = 1
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Dashboard Sparkline

struct DSDashboardSparkline: View {
    let data: [Double]
    let color: Color
    let lineWidth: CGFloat
    
    init(
        data: [Double],
        color: Color = .ds(.brandPrimary),
        lineWidth: CGFloat = 2
    ) {
        self.data = data
        self.color = color
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !data.isEmpty else { return }
                
                let width = geometry.size.width
                let height = geometry.size.height
                let maxValue = data.max() ?? 1
                let minValue = data.min() ?? 0
                let range = maxValue - minValue
                
                let stepX = width / CGFloat(max(data.count - 1, 1))
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalizedValue = range > 0 ? (value - minValue) / range : 0.5
                    let y = height - (normalizedValue * height)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}


