import Foundation
import Combine
import SwiftUI

@MainActor
class PresenceViewModel: ObservableObject {
    @Published var activeParticipants: Int = 0
    @Published var presenceDistribution: [String: Int] = [:]
    @Published var currentRooms: Set<String> = []
    
    private let webSocketManager = WebSocketManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Subscribe to presence updates
        webSocketManager.presencePublisher
            .sink { [weak self] update in
                self?.handlePresenceUpdate(update)
            }
            .store(in: &cancellables)
    }
    
    func joinRoom(_ room: Room) async {
        currentRooms.insert(room.id.uuidString)
        webSocketManager.sendPresenceUpdate(status: "online")
    }
    
    func leaveRoom(_ roomId: String) {
        currentRooms.remove(roomId)
    }
    
    func getActiveParticipantsCount() -> Int {
        return activeParticipants
    }
    
    func getPresenceDistribution() -> [String: Int] {
        return presenceDistribution
    }
    
    private func handlePresenceUpdate(_ update: PresenceUpdate) {
        // Update presence distribution
        presenceDistribution[update.status, default: 0] += 1
        
        // Update active participants count
        if update.status == "online" {
            activeParticipants = max(activeParticipants, presenceDistribution["online"] ?? 0)
        }
    }
}

