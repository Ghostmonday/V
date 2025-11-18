import Foundation
import Combine
import OSLog

/// Room Restoration Service
/// Tracks joined rooms and persists room state across reconnections
/// Provides automatic re-join with deduplication
@MainActor
class RoomRestorationService: ObservableObject {
    private static let logger = Logger(subsystem: "com.vibez.app", category: "RoomRestoration")
    static let shared = RoomRestorationService()
    
    // Track joined rooms per user
    private var joinedRooms: Set<String> = []
    
    // UserDefaults key for persistence
    private let roomsKey = "vibez_joined_rooms"
    
    private init() {
        loadPersistedRooms()
    }
    
    /// Add a room to the joined rooms set
    func addRoom(_ roomId: String) {
        guard !roomId.isEmpty else { return }
        
        let wasNew = joinedRooms.insert(roomId).inserted
        if wasNew {
            Self.logger.info("Room added to restoration service: \(roomId)")
            persistRooms()
        }
    }
    
    /// Remove a room from the joined rooms set
    func removeRoom(_ roomId: String) {
        let wasRemoved = joinedRooms.remove(roomId) != nil
        if wasRemoved {
            Self.logger.info("Room removed from restoration service: \(roomId)")
            persistRooms()
        }
    }
    
    /// Get all joined rooms
    func getJoinedRooms() -> [String] {
        return Array(joinedRooms)
    }
    
    /// Check if a room is in the joined set
    func isRoomJoined(_ roomId: String) -> Bool {
        return joinedRooms.contains(roomId)
    }
    
    /// Clear all joined rooms (on logout)
    func clearAllRooms() {
        joinedRooms.removeAll()
        persistRooms()
        Self.logger.info("All rooms cleared from restoration service")
    }
    
    /// Batch add rooms (for efficient restoration)
    func addRooms(_ roomIds: [String]) {
        var addedCount = 0
        for roomId in roomIds {
            if !roomId.isEmpty && joinedRooms.insert(roomId).inserted {
                addedCount += 1
            }
        }
        
        if addedCount > 0 {
            Self.logger.info("Batch added \(addedCount) rooms to restoration service")
            persistRooms()
        }
    }
    
    /// Get rooms for batch re-join (with size limit)
    func getRoomsForBatchRejoin(batchSize: Int = 10) -> [String] {
        let rooms = Array(joinedRooms)
        return Array(rooms.prefix(batchSize))
    }
    
    // MARK: - Persistence
    
    /// Persist joined rooms to UserDefaults
    private func persistRooms() {
        let roomsArray = Array(joinedRooms)
        UserDefaults.standard.set(roomsArray, forKey: roomsKey)
    }
    
    /// Load persisted rooms from UserDefaults
    private func loadPersistedRooms() {
        if let roomsArray = UserDefaults.standard.array(forKey: roomsKey) as? [String] {
            joinedRooms = Set(roomsArray)
            Self.logger.info("Loaded \(self.joinedRooms.count) persisted rooms")
        }
    }
}

