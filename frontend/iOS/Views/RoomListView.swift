import SwiftUI

struct RoomListView: View {
    @State private var rooms: [Room] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @ObservedObject private var globalAccessManager = GlobalAccessManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.Vibez.deepVoid.opacity(0.8),
                        Color.Vibez.electricBlue.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if isLoading {
                    // Enhanced loading state
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.blue)
                        
                        Text("Finding your rooms...")
                            .font(.headline) // Dynamic Type support
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Finding your rooms")
                        
                        Text("Linking up...")
                            .font(.caption) // Dynamic Type support
                            .foregroundColor(.secondary.opacity(0.7))
                            .accessibilityLabel("Linking up")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale))
                } else if rooms.isEmpty {
                    // Enhanced empty state
                    VStack(spacing: 24) {
                        Image(systemName: "door.left.hand.open")
                            .font(.system(size: 64))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 10)
                        
                        VStack(spacing: 8) {
                            Text("Nothing here yet")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Make your first room")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: {
                            showCreateSheet = true
                        }) {
                            GlassView(
                                material: .regular,
                                tint: .brand,
                                border: .glow(Color("VibeZGold")),
                                cornerRadius: 12,
                                shadow: true,
                                padding: 12
                            ) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("New room")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                            }
                        }
                        .accessibilityLabel("New room")
                        .accessibilityHint("Double tap to make a room")
                        .accessibilityAddTraits(.isButton)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .transition(.opacity.combined(with: .scale))
                } else {
                    // Enhanced room list
                    List {
                        ForEach(rooms) { room in
                            RoomRow(room: room)
                                .listRowBackground(
                                    GlassView(
                                        material: .ultraThin,
                                        tint: .none,
                                        border: .subtle,
                                        cornerRadius: 12,
                                        shadow: false,
                                        padding: 4
                                    ) { Color.clear }
                                    .padding(.vertical, 4)
                                )
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Rooms")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showCreateSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color("VibeZGold"))
                    }
                }
            }
            // TODO: Add CreateRoomSheet.swift to Xcode project target
            // .sheet(isPresented: $showCreateSheet) {
            //     CreateRoomSheet(onRoomCreated: { newRoom in
            //         rooms.append(newRoom)
            //         showCreateSheet = false
            //     })
            // }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLoading)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rooms.isEmpty)
            .alert("Network Unstable", isPresented: $globalAccessManager.isRestrictionDetected) {
                Button("Enable Global Access Mode") {
                    globalAccessManager.toggleGAM(true)
                }
                Button("Cancel", role: .cancel) {
                    globalAccessManager.dismissRecommendation()
                }
            } message: {
                Text("Your network seems restricted or unstable. Global Access Mode may improve voice room stability on congested networks.")
            }
        }
        .task {
            await loadRooms()
        }
        /// UX: Doorway list
    }
    
    private func loadRooms() async {
        isLoading = true
        
        // Load rooms
        do {
            rooms = try await RoomService.fetchRooms()
        } catch {
            print("Failed to load rooms: \(error)")
            // Fallback: Add dummy room for visibility
            rooms = [createDummyRoom(name: "General")]
        }
        
        isLoading = false
    }
    
    private func createDummyRoom(name: String) -> Room {
        return Room(
            id: UUID(),
            name: name,
            owner_id: UUID(),
            is_public: true,
            users: [],
            maxOrbs: 10,
            activityLevel: "calm",
            room_tier: "free",
            ai_moderation: false,
            expires_at: nil,
            is_self_hosted: false
        )
    }
}

/// Room Row Component with tier icons
struct RoomRow: View {
    let room: Room
    @State private var showSettings = false
    
    var body: some View {
        NavigationLink(destination: ChatView(room: room).navigationBarTitleDisplayMode(.inline)) {
            HStack(spacing: 16) {
                // Room icon with tier badges
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.6), .cyan.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "door.left.hand.open")
                        .foregroundColor(.white)
                        .font(.title3)
                    
                    // Tier badges
                    if room.isTemp {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(4)
                            .background(Circle().fill(.white))
                            .offset(x: 4, y: 4)
                    } else if room.isModerated {
                        Image(systemName: "shield.checkered")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .padding(4)
                            .background(Circle().fill(.white))
                            .offset(x: 4, y: 4)
                    } else if room.is_self_hosted == true {
                        Image(systemName: "server.rack")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(4)
                            .background(Circle().fill(.white))
                            .offset(x: 4, y: 4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(room.name ?? "Unnamed Room")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if room.isTemp, let countdown = room.expiryCountdown {
                            Text("• \(countdown)")
                            .font(.caption)
                            .foregroundColor(.orange)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        if let activityLevel = room.activityLevel {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(activityColor(activityLevel))
                                    .frame(width: 6, height: 6)
                                
                                Text(activityLevel.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if room.isModerated {
                            Label("Moderated", systemImage: "shield.checkered")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .sheet(isPresented: $showSettings) {
            // RoomSettingsView(room: room) // TODO: Implement RoomSettingsView
            Text("Room Settings")
                .foregroundColor(.white)
                .padding()
        }
    }
    
    private func activityColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "calm": return .green
        case "active": return .blue
        case "busy": return .orange
        case "intense": return .red
        default: return .gray
        }
    }
}

#Preview {
    RoomListView()
}
