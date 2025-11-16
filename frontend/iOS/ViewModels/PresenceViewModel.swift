import Foundation
import Combine
import OSLog

@MainActor
class PresenceViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var currentMood: String = "calm" /// UX: Emotional attunement
    
    private var cancellables = Set<AnyCancellable>()
    private var presenceCache: [UUID: PresenceStatus] = [:]
    
    init() {
        // Load initial presence data
        Task { @MainActor in
            await loadPresence()
            subscribeToPresenceUpdates()
        }
    }
    
    /// Load user presence from backend
    private func loadPresence() async {
        do {
            // Try to fetch users with presence status from rooms
            let rooms = try await RoomService.fetchRooms()
            
            // Collect all unique users from rooms
            var allUsers: [User] = []
            var userSet = Set<UUID>()
            
            for room in rooms {
                if let roomUsers = room.users {
                    for user in roomUsers {
                        if !userSet.contains(user.id) {
                            userSet.insert(user.id)
                            
                            // Fetch presence status for this user
                            var userWithPresence = user
                            if let presenceStatus = await fetchUserPresenceStatus(userId: user.id) {
                                userWithPresence.presenceStatus = presenceStatus
                                presenceCache[user.id] = presenceStatus
                            } else {
                                // Default to offline if status unavailable
                                userWithPresence.presenceStatus = .offline
                                presenceCache[user.id] = .offline
                            }
                            
                            allUsers.append(userWithPresence)
                        }
                    }
                }
            }
            
            // If no users from rooms, try direct presence status endpoint
            if allUsers.isEmpty {
                // Fallback: Try to get current user's presence
                if let currentUserId = AuthTokenManager.shared.token {
                    if let status = await fetchUserPresenceStatus(userId: UUID(uuidString: currentUserId) ?? UUID()) {
                        // Create a mock user for testing if needed
                        // In production, this would come from user profile API
                    }
                }
            }
            
            users = allUsers
        } catch {
            Logger(subsystem: "com.vibez.app", category: "PresenceViewModel").error("[PresenceViewModel] Error loading presence: \(error.localizedDescription)")
            // On error, keep existing users or start with empty array
        }
    }
    
    /// Fetch presence status for a specific user
    private func fetchUserPresenceStatus(userId: UUID) async -> PresenceStatus? {
        // Check cache first
        if let cachedStatus = presenceCache[userId] {
            return cachedStatus
        }
        
        do {
            // Use presence status endpoint
            let response: PresenceStatusResponse = try await APIClient.shared.request(
                endpoint: "\(APIClient.Endpoint.presenceStatus)?userId=\(userId.uuidString)",
                method: "GET"
            )
            
            let status = PresenceStatus(rawValue: response.status) ?? .offline
            presenceCache[userId] = status
            return status
        } catch {
            Logger(subsystem: "com.vibez.app", category: "PresenceViewModel").error("[PresenceViewModel] Error fetching presence for user \(userId): \(error.localizedDescription)")
            // Default to offline on error
            let defaultStatus: PresenceStatus = .offline
            presenceCache[userId] = defaultStatus
            return defaultStatus
        }
    }
    
    /// Subscribe to WebSocket presence updates for incremental updates
    private func subscribeToPresenceUpdates() {
        WebSocketManager.shared.presencePublisher
            .sink { [weak self] update in
                Task { @MainActor in
                    self?.handlePresenceUpdate(update)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Handle incremental presence update from WebSocket
    private func handlePresenceUpdate(_ update: PresenceUpdate) {
        guard let userId = UUID(uuidString: update.userId),
              let status = PresenceStatus(rawValue: update.status) else {
            return
        }
        
        // Update cache
        presenceCache[userId] = status
        
        // Update user in array if exists
        if let index = users.firstIndex(where: { $0.id == userId }) {
            users[index].presenceStatus = status
        } else {
            // User not in list yet - could add if needed
            // For now, we'll reload on next full refresh if needed
        }
    }
    
    /// Get presence distribution counts
    func getPresenceDistribution() -> [String: Int] {
        var distribution: [String: Int] = [
            "online": 0,
            "offline": 0,
            "away": 0,
            "busy": 0
        ]
        
        for user in users {
            let status = user.presenceStatus ?? .offline
            distribution[status.rawValue] = (distribution[status.rawValue] ?? 0) + 1
        }
        
        return distribution
    }
    
    /// Get active participants count (online, away, or busy)
    func getActiveParticipantsCount() -> Int {
        return users.filter { user in
            guard let status = user.presenceStatus else { return false }
            return status == .online || status == .away || status == .busy
        }.count
    }
    
    /// Get online participants count only
    func getOnlineParticipantsCount() -> Int {
        return users.filter { $0.presenceStatus == .online }.count
    }
    
    func joinRoom(_ room: Room) async {
        // Update presence on backend
        do {
            struct PresenceUpdateRequest: Codable {
                let userId: String
                let status: String
            }
            
            // Get current user ID (should be stored after auth)
            let userId = AuthTokenManager.shared.token ?? UUID().uuidString
            
            let request = PresenceUpdateRequest(userId: userId, status: "online")
            try await APIClient.shared.request(
                endpoint: APIClient.Endpoint.presenceUpdate,
                method: "POST",
                body: request
            )
            
            SystemService.logTelemetry(event: "presence.event", data: ["roomId": room.id.uuidString])
        } catch {
            Logger(subsystem: "com.vibez.app", category: "PresenceViewModel").error("Presence update error: \(error.localizedDescription)")
        }
        
        // Deferred bootstrap of AIReasoner on first interaction, as per optimizer goals
        await AIReasoner.shared.bootstrap()
    }
}

// MARK: - Supporting Types

private struct PresenceStatusResponse: Codable {
    let status: String
}

