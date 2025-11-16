import SwiftUI

/// Create Room Sheet
/// Allows users to create a new room
struct CreateRoomSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var roomName: String = ""
    @State private var isPublic: Bool = false
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?
    let onRoomCreated: (Room) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Room Details") {
                    TextField("Room Name", text: $roomName)
                        .textInputAutocapitalization(.words)
                    
                    Toggle("Public Room", isOn: $isPublic)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Create Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createRoom()
                    }
                    .disabled(roomName.isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createRoom() {
        guard !roomName.isEmpty else { return }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                // Get current user ID (should be extracted from JWT in production)
                let ownerId = UUID() // TODO: Get from AuthService
                
                let newRoom = try await RoomService.createRoom(
                    name: roomName,
                    ownerId: ownerId,
                    isPublic: isPublic
                )
                
                await MainActor.run {
                    onRoomCreated(newRoom)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create room: \(error.localizedDescription)"
                    isCreating = false
                }
            }
        }
    }
}

#Preview {
    CreateRoomSheet(onRoomCreated: { _ in })
}

