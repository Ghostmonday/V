import SwiftUI

/// Quick Jump Bar - Quick access to pinned rooms
struct QuickJumpBar: View {
    @StateObject private var viewModel = QuickJumpViewModel()
    @State private var selectedRoomId: UUID?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.pinnedRooms) { room in
                    QuickJumpButton(room: room, isSelected: selectedRoomId == room.id) {
                        selectedRoomId = room.id
                        // Navigate to room
                        // TODO: Implement navigation
                    }
                }
            }
            .padding(.horizontal)
        }
        .accessibilityLabel("Pinned rooms quick access")
        .task {
            await viewModel.loadPinnedRooms()
        }
    }
}

/// Quick Jump Button
struct QuickJumpButton: View {
    let room: Room
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundColor(isSelected ? Color("VibeZGold") : .secondary)
                
                Text(room.name ?? "Room")
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color("VibeZGold").opacity(0.2) : Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(room.name ?? "Room") pinned room")
        .accessibilityHint("Double tap to open")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Quick Jump ViewModel
@MainActor
final class QuickJumpViewModel: ObservableObject {
    @Published var pinnedRooms: [Room] = []
    
    func loadPinnedRooms() async {
        do {
            let response: PinnedRoomsResponse = try await APIClient.shared.request(
                endpoint: "/api/pinned",
                method: "GET"
            )
            pinnedRooms = response.rooms
        } catch {
            print("[QuickJump] Failed to load pinned rooms: \(error)")
            pinnedRooms = []
        }
    }
}

struct PinnedRoomsResponse: Codable {
    let rooms: [Room]
}

#Preview {
    QuickJumpBar()
        .padding()
}

