import SwiftUI

/// Presence Indicator View
/// Migrated from src/components/PresenceIndicator.vue
/// Displays textual presence status
struct PresenceIndicatorView: View {
    let userId: String
    
    @State private var status: String = "offline"
    
    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusBackground)
            .cornerRadius(4)
            .task {
                await loadStatus()
            }
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "online":
            return .green
        case "offline":
            return .gray
        case "away":
            return .yellow
        case "busy":
            return .red
        default:
            return .gray
        }
    }
    
    private var statusBackground: Color {
        statusColor.opacity(0.2)
    }
    
    // MARK: - Data Loading
    
    private func loadStatus() async {
        do {
            guard let url = URL(string: "\(APIClient.baseURL)/api/presence/status/\(userId)") else { return }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(StatusResponse.self, from: data)
            
            await MainActor.run {
                self.status = response.status
            }
        } catch {
            print("[PresenceIndicator] Error loading status: \(error)")
        }
    }
}

private struct StatusResponse: Codable {
    let status: String
}

#Preview {
    VStack(spacing: 12) {
        PresenceIndicatorView(userId: "user1")
        PresenceIndicatorView(userId: "user2")
        PresenceIndicatorView(userId: "user3")
    }
    .padding()
}

