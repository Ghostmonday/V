import Foundation

class RoomService {
    /// Fetch rooms from backend
    static func fetchRooms(userId: UUID? = nil) async throws -> [Room] {
        var queryParams: [String: String]?
        if let userId = userId {
            queryParams = ["userId": userId.uuidString]
        }
        
        let response: RoomsResponse = try await APIClient.shared.request(
            endpoint: APIClient.Endpoint.roomsList,
            method: "GET",
            queryParams: queryParams
        )
        
        return response.rooms
    }
    
    /// Fetch a single room by ID (optimized - doesn't fetch all rooms)
    static func fetchRoom(id: UUID) async throws -> Room {
        struct RoomResponse: Codable {
            let room: Room
        }
        
        let response: RoomResponse = try await APIClient.shared.request(
            endpoint: APIClient.Endpoint.roomDetail(id.uuidString),
            method: "GET"
        )
        
        return response.room
    }
    
    /// Create a new room
    static func createRoom(name: String, ownerId: UUID, isPublic: Bool = false) async throws -> Room {
        struct CreateRoomRequest: Codable {
            let name: String
            let owner_id: String
            let is_public: Bool
        }
        
        let request = CreateRoomRequest(
            name: name,
            owner_id: ownerId.uuidString,
            is_public: isPublic
        )
        
        let response: RoomResponse = try await APIClient.shared.request(
            endpoint: APIClient.Endpoint.roomsCreate,
            method: "POST",
            body: request
        )
        
        return response.room
    }
    
    /// Preload rooms for optimization
    static func preload() async {
        do {
            _ = try await fetchRooms()
        } catch {
            print("RoomService preload error: \(error)")
        }
    }
}

