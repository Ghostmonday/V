import Foundation
import Combine
import SwiftUI

@MainActor
class RoomViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    
    func loadRoom(id: UUID) {
        isLoading = true
        error = nil
        
        Task {
            do {
                let fetchedMessages = try await MessageService.getMessages(for: id)
                await MainActor.run {
                    self.messages = fetchedMessages
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    func refreshMessages(for roomId: UUID) {
        loadRoom(id: roomId)
    }
}

