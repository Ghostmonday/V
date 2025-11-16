import SwiftUI

/// Room settings with AI moderation toggle
struct RoomSettingsView: View {
    let room: Room
    @Environment(\.dismiss) var dismiss
    @State private var aiModerationEnabled: Bool
    @State private var canToggleModeration: Bool
    @State private var haptic = UIImpactFeedbackGenerator(style: .light)
    
    init(room: Room) {
        self.room = room
        _aiModerationEnabled = State(initialValue: room.ai_moderation ?? false)
        // Check if user has enterprise tier
        _canToggleModeration = State(initialValue: true) // TODO: Check subscription tier
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Moderation") {
                    Toggle("AI Moderation", isOn: $aiModerationEnabled)
                        .disabled(!canToggleModeration)
                        .onChange(of: aiModerationEnabled) { newValue in
                            haptic.impactOccurred()
                            updateModeration(enabled: newValue)
                        }
                    
                    if !canToggleModeration {
                        Text("Enterprise subscription required")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if room.isTemp, let countdown = room.expiryCountdown {
                    Section("Room Info") {
                        HStack {
                            Text("Expires in")
                            Spacer()
                            Text(countdown)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                if room.is_self_hosted == true {
                    Section("Hosting") {
                        HStack {
                            Image(systemName: "server.rack")
                            Text("Self-hosted")
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("Room Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func updateModeration(enabled: Bool) {
        // TODO: Call API to update room config
        Task {
            // await RoomService.updateModeration(roomId: room.id, enabled: enabled)
            print("Updating moderation: \(enabled)")
        }
    }
}

#Preview {
    RoomSettingsView(room: Room(
        id: UUID(),
        name: "Test Room",
        owner_id: UUID(),
        is_public: true,
        users: nil,
        maxOrbs: nil,
        activityLevel: nil,
        room_tier: "enterprise",
        ai_moderation: false,
        expires_at: nil,
        is_self_hosted: false
    ))
}

