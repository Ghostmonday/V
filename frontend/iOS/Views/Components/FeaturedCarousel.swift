import SwiftUI

struct FeaturedCarousel: View {
    // Mock data for now
    let featuredRooms: [Room] = [
        Room(id: UUID(), name: "Midnight Jazz Club", owner_id: UUID(), is_public: true, users: [], maxOrbs: 50, activityLevel: "high", room_tier: "enterprise", ai_moderation: false, expires_at: nil, is_self_hosted: false),
        Room(id: UUID(), name: "Tech Talk Daily", owner_id: UUID(), is_public: true, users: [], maxOrbs: 20, activityLevel: "medium", room_tier: "pro", ai_moderation: true, expires_at: nil, is_self_hosted: false)
    ]
    
    var body: some View {
        TabView {
            ForEach(featuredRooms) { room in
                FeaturedRoomCard(room: room)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 250)
    }
}

struct FeaturedRoomCard: View {
    let room: Room
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image/Gradient
            LinearGradient(
                colors: [Color.Vibez.electricBlue.opacity(0.3), Color.Vibez.deepVoid],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(Color.black)
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("FEATURED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.Vibez.warning) // Gold color
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                
                Spacer()
                
                Text(room.name ?? "Untitled Room")
                    .font(VibezTypography.headerMedium)
                    .foregroundColor(.white)
                    .shadow(radius: 5)
                
                Text("Hosted by @creator") // Placeholder
                    .font(VibezTypography.bodyMedium)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(20)
        }
        .cornerRadius(24)
        .padding(.horizontal)
        .shadow(color: Color.Vibez.electricBlue.opacity(0.2), radius: 15, x: 0, y: 10)
    }
}

