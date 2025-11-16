import Foundation

class MessageService {
    /// Send a message to a room
    static func sendMessage(_ message: Message, to room: Room) async throws {
        let request = SendMessageRequest(
            roomId: room.id.uuidString,
            senderId: message.senderId.uuidString,
            content: message.content,
            type: message.type
        )
        
        try await APIClient.shared.request(
            endpoint: APIClient.Endpoint.messagingSend,
            method: "POST",
            body: request
        )
        
        // Log telemetry
        SystemService.logTelemetry(event: "message.sent", data: ["roomId": room.id.uuidString])
    }
    
    /// Get messages for a room (lazy loading - fetches since timestamp)
    static func getMessages(for roomId: UUID, since timestamp: Date? = nil) async throws -> [Message] {
        var queryParams: [String: String] = [:]
        if let timestamp = timestamp {
            queryParams["since"] = ISO8601DateFormatter().string(from: timestamp)
        }
        
        let messages: [Message] = try await APIClient.shared.request(
            endpoint: APIClient.Endpoint.messagingRoom(roomId.uuidString),
            method: "GET",
            queryParams: queryParams.isEmpty ? nil : queryParams
        )
        
        return messages
    }
    
    /// Get all messages for a room (legacy - use getMessages with since parameter for better performance)
    static func getAllMessages(for roomId: UUID) async throws -> [Message] {
        return try await getMessages(for: roomId, since: nil)
    }
}

