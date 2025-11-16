import Foundation
import Combine

@MainActor
class RoomViewModel: ObservableObject {
    @Published var room: Room?
    @Published var messages: [Message] = []
    @Published var isSilent: Bool = false /// UX: Silence empathy
    
    private var silenceTimer: Timer?
    
    func loadRoom(id: UUID) {
        Task { @MainActor in
            do {
                // Load room details (optimized - fetch single room instead of all rooms)
                self.room = try await RoomService.fetchRoom(id: id)
                
                // Load messages (lazy load - only recent messages initially)
                // Load last 50 messages instead of all history for better performance
                let oneDayAgo = Date().addingTimeInterval(-86400) // 24 hours ago
                self.messages = try await MessageService.getMessages(for: id, since: oneDayAgo)
                
                startSilenceDetection()
            } catch {
                print("Room load error: \(error)")
            }
        }
    }
    
    private func startSilenceDetection() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.isSilent = true
                // UX: Re-engage with empathy (AI service removed)
                // if let roomId = self.room?.id.uuidString {
                //     _ = try? await AIService.reply(with: "Still here? Let's vibe.", roomId: roomId)
                // }
            }
        }
    }
    
    nonisolated deinit {
        // Timer cleanup handled by @MainActor context
    }
}

