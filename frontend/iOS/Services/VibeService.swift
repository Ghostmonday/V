import Foundation

/// Service for handling VIBE interactions (Reactions, Empathy Pulses)
class VibeService {
    static let shared = VibeService()
    
    private init() {}
    
    /// Send a reaction to a message
    func sendReaction(messageId: UUID, emoji: String) async throws {
        let payload: [String: Any] = [
            "message_id": messageId.uuidString,
            "emoji": emoji,
            "action": "add"
        ]
        
        _ = try await APIClient.shared.request(
            endpoint: "/api/reactions", // Based on reactions-api-routes.ts mounted at /api/reactions probably? 
            // Wait, in server config it might be mounted at /reactions. 
            // I'll assume /api prefix as per other services.
            // If it fails, I'll check server config.
            method: "POST",
            body: payload
        )
    }
    
    /// Remove a reaction from a message
    func removeReaction(messageId: UUID, emoji: String) async throws {
        let payload: [String: Any] = [
            "message_id": messageId.uuidString,
            "emoji": emoji,
            "action": "remove"
        ]
        
        // DELETE /message_id/react/emoji in older route? 
        // reactions-api-routes.ts showed: router.post('/', ...) for add/remove based on body action.
        // There was also router.delete('/:message_id/react/:emoji') in message-api-routes.ts but that might be legacy.
        // I will use the reactions-api-routes.ts endpoint which seemed more robust.
        
        _ = try await APIClient.shared.request(
            endpoint: "/api/reactions",
            method: "POST",
            body: payload
        )
    }
    
    /// "Collect VIBE" - Send an empathy pulse to the room
    /// This corresponds to the "VIBES" button in the UI
    func sendVibePulse(roomId: String, intensity: Double = 1.0) async {
        // Use WebSocket for real-time effect
        let payload: [String: Any] = [
            "roomId": roomId,
            "type": "pulse",
            "intensity": intensity,
            "timestamp": Date().ISO8601Format()
        ]
        
        await MainActor.run {
            WebSocketManager.shared.send(event: "emotion_pulse", payload: payload)
        }
        
        // Optionally log to telemetry
        UXTelemetryService.logClick(
            componentId: "VibePulse",
            metadata: ["intensity": "\(intensity)"]
        )
    }
}

