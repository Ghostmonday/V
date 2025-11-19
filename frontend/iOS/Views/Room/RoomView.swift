import SwiftUI

struct RoomView: View {
    let roomName: String
    @Environment(\.dismiss) var dismiss
    @State private var messageText = ""
    @State private var isMuted = true
    @State private var showChat = true
    
    // Mock Data
    let speakers = ["Alex", "Sarah", "Mike"]
    let listeners = ["User1", "User2", "User3", "User4", "User5"]
    
    var body: some View {
        ZStack {
            // Background
            VibezBackground()
            
            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text(roomName)
                        .font(VibezTypography.headerSmall)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { /* Room Settings */ }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding()
                .background(Color.Vibez.deepVoid.opacity(0.8))
                
                // MARK: - Stage (Voice Area)
                ScrollView {
                    VStack(spacing: 30) {
                        // Speakers (The Stage)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            ForEach(speakers, id: \.self) { speaker in
                                VStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.Vibez.deepVoid)
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.Vibez.electricBlue, lineWidth: 2)
                                            )
                                            .shadow(color: Color.Vibez.electricBlue.opacity(0.5), radius: 10)
                                        
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                            .font(.title)
                                    }
                                    
                                    Text(speaker)
                                        .font(VibezTypography.caption)
                                        .foregroundColor(.white)
                                    
                                    Text("Speaker")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color.Vibez.electricBlue)
                                }
                            }
                        }
                        .padding(.top, 20)
                        
                        // Divider
                        Rectangle()
                            .fill(LinearGradient(colors: [.clear, .white.opacity(0.1), .clear], startPoint: .leading, endPoint: .trailing))
                            .frame(height: 1)
                            .padding(.vertical)
                        
                        // Listeners (The Crowd)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 15) {
                            ForEach(listeners, id: \.self) { listener in
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.5))
                                    )
                            }
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: showChat ? UIScreen.main.bounds.height * 0.4 : .infinity)
                
                // MARK: - Persistent Chat (Text Area)
                if showChat {
                    VStack(spacing: 0) {
                        // Drag Handle
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 40, height: 4)
                            .padding(.vertical, 8)
                        
                        // Chat List
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(0..<5) { i in
                                    HStack(alignment: .top) {
                                        Text("User\(i):")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(Color.Vibez.neonCyan)
                                        Text("This is a persistent text message that stays even when voice is idle.")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }
                        
                        // Input
                        HStack {
                            TextField("Say something...", text: $messageText)
                                .padding(10)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(20)
                                .foregroundColor(.white)
                            
                            Button(action: {}) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Color.Vibez.electricBlue)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                    }
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(24, corners: [.topLeft, .topRight])
                }
            }
            
            // MARK: - Bottom Controls
            VStack {
                Spacer()
                HStack(spacing: 40) {
                    ControlIcon(icon: isMuted ? "mic.slash.fill" : "mic.fill", isActive: !isMuted) {
                        isMuted.toggle()
                    }
                    
                    ControlIcon(icon: "hand.raised.fill", isActive: false) {
                        // Raise hand
                    }
                    
                    ControlIcon(icon: "bubble.left.and.bubble.right.fill", isActive: showChat) {
                        withAnimation { showChat.toggle() }
                    }
                    
                    Button(action: { dismiss() }) {
                        Text("Leave")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.Vibez.error)
                            .cornerRadius(20)
                    }
                }
                .padding(.bottom, 30)
                .padding(.horizontal)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                )
            }
        }
    }
}

struct ControlIcon: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? .black : .white)
                .frame(width: 50, height: 50)
                .background(isActive ? Color.Vibez.electricBlue : Color.white.opacity(0.1))
                .clipShape(Circle())
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

