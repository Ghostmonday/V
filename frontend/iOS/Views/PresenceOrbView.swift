import SwiftUI
import Combine

/// Presence Orb View
/// Migrated from src/components/PresenceOrb.vue
/// Displays real-time presence status for a user in a room
struct PresenceOrbView: View {
    let userId: String
    let roomId: String
    
    @State private var status: PresenceStatus = .offline
    @StateObject private var webSocket = WebSocketManager.shared
    @State private var cancellables: Set<AnyCancellable> = []
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .shadow(radius: 2)
            .pulse(isActive: status == .online)
            .task {
                await loadPresence()
                await subscribeToPresence()
            }
    }
    
    private var statusColor: Color {
        switch status {
        case .online:
            return .green
        case .offline:
            return .gray
        case .away:
            return .yellow
        case .busy:
            return .red
        }
    }
    
    // MARK: - Data Loading
    
    private func loadPresence() async {
        // Fetch initial presence status
        do {
            guard let url = URL(string: "\(APIClient.baseURL)/api/presence/status/\(userId)") else { return }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(PresenceStatusResponse.self, from: data)
            
            await MainActor.run {
                self.status = PresenceStatus(rawValue: response.status) ?? .offline
            }
        } catch {
            print("[PresenceOrb] Error loading presence: \(error)")
        }
    }
    
    @MainActor
    private func subscribeToPresence() async {
        // Subscribe to WebSocket presence updates
        webSocket.presencePublisher
            .filter { $0.userId == self.userId }
            .sink { update in
                Task { @MainActor in
                    self.status = PresenceStatus(rawValue: update.status) ?? .offline
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Types

private struct PresenceStatusResponse: Codable {
    let status: String
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            Text("Online")
            PresenceOrbView(userId: "user1", roomId: "room1")
        }
        HStack {
            Text("Offline")
            PresenceOrbView(userId: "user2", roomId: "room1")
        }
    }
    .padding()
}

