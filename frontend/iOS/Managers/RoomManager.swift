import Foundation

@MainActor
class RoomManager {
    static let shared = RoomManager()
    
    func createRoom() async throws -> Room {
        // Get current user ID (should be from auth)
        let ownerId = UUID() // TODO: Get from authenticated user
        return try await RoomService.createRoom(name: "New Room", ownerId: ownerId)
    }
    
    func updatePresence(in room: Room) {
        Task {
            let viewModel = PresenceViewModel()
            await viewModel.joinRoom(room)
        }
    }
}

