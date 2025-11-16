import SwiftUI

/// Nickname Management View - Set custom nicknames per room
struct NicknameManagementView: View {
    @StateObject private var viewModel = NicknameViewModel()
    @State private var selectedRoom: Room?
    
    var body: some View {
        List {
            ForEach(viewModel.roomsWithNicknames) { item in
                NicknameRow(item: item) { room, nickname in
                    Task {
                        await viewModel.updateNickname(roomId: room.id.uuidString, nickname: nickname)
                    }
                }
            }
        }
        .navigationTitle("Nicknames")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadNicknames()
        }
    }
}

/// Nickname Row
struct NicknameRow: View {
    let item: RoomNicknameItem
    let onUpdate: (Room, String) -> Void
    @State private var nickname: String
    
    init(item: RoomNicknameItem, onUpdate: @escaping (Room, String) -> Void) {
        self.item = item
        self.onUpdate = onUpdate
        _nickname = State(initialValue: item.nickname ?? "")
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.room.name ?? "Room")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                TextField("Nickname", text: $nickname)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .onSubmit {
                        onUpdate(item.room, nickname)
                    }
                    .accessibilityLabel("Nickname for \(item.room.name ?? "room")")
            }
            
            Spacer()
            
            if nickname != item.nickname {
                Button("Save") {
                    onUpdate(item.room, nickname)
                }
                .font(.subheadline)
                .foregroundColor(Color("VibeZGold"))
                .accessibleButton("Save nickname", hint: "Double tap to save changes")
            }
        }
        .padding(.vertical, 4)
    }
}

struct RoomNicknameItem: Identifiable {
    let id: UUID
    let room: Room
    let nickname: String?
}

/// Nickname ViewModel
@MainActor
final class NicknameViewModel: ObservableObject {
    @Published var roomsWithNicknames: [RoomNicknameItem] = []
    
    func loadNicknames() async {
        do {
            let response: NicknamesResponse = try await APIClient.shared.request(
                endpoint: "/api/nicknames",
                method: "GET"
            )
            roomsWithNicknames = response.nicknames.map { item in
                RoomNicknameItem(
                    id: UUID(uuidString: item.roomId) ?? UUID(),
                    room: Room(
                        id: UUID(uuidString: item.roomId) ?? UUID(),
                        name: item.roomName,
                        owner_id: UUID(),
                        is_public: true,
                        users: [],
                        maxOrbs: 10,
                        activityLevel: "calm",
                        room_tier: "free",
                        ai_moderation: false,
                        expires_at: nil,
                        is_self_hosted: false
                    ),
                    nickname: item.nickname
                )
            }
        } catch {
            print("[NicknameManagement] Failed to load nicknames: \(error)")
            roomsWithNicknames = []
        }
    }
    
    func updateNickname(roomId: String, nickname: String) async {
        do {
            try await APIClient.shared.request(
                endpoint: "/api/nicknames",
                method: "POST",
                body: [
                    "room_id": roomId,
                    "nickname": nickname
                ]
            )
            await loadNicknames()
        } catch {
            print("[NicknameManagement] Failed to update nickname: \(error)")
        }
    }
}

struct NicknamesResponse: Codable {
    let nicknames: [NicknameItem]
}

struct NicknameItem: Codable {
    let roomId: String
    let roomName: String?
    let nickname: String?
}

/// User Settings Manager
class UserSettings: ObservableObject {
    static let shared = UserSettings()
    @Published var lowBandwidth: Bool {
        didSet {
            UserDefaults.standard.set(lowBandwidth, forKey: "lowBandwidth")
        }
    }
    
    private init() {
        self.lowBandwidth = UserDefaults.standard.bool(forKey: "lowBandwidth")
    }
}

private func updateBandwidthPreference(_ enabled: Bool) async {
    do {
        try await APIClient.shared.request(
            endpoint: "/api/bandwidth/preference",
            method: "POST",
            body: ["low_bandwidth": enabled]
        )
    } catch {
        print("[Settings] Failed to update bandwidth preference: \(error)")
    }
}

#Preview {
    NavigationStack {
        NicknameManagementView()
    }
}

