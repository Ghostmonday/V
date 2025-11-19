import Foundation
import Combine

@MainActor
class GuestService: ObservableObject {
    static let shared = GuestService()
    
    @Published var isGuest: Bool = true
    @Published var guestHandle: String = ""
    @Published var guestID: UUID = UUID()
    @Published var showSavePrompt: Bool = false
    
    private let kIsGuest = "isGuest"
    private let kGuestHandle = "guestHandle"
    private let kGuestID = "guestID"
    private let kSessionStartTime = "sessionStartTime"
    
    private var timer: AnyCancellable?
    
    init() {
        loadGuestState()
        startSessionTimer()
    }
    
    private func loadGuestState() {
        if UserDefaults.standard.object(forKey: kIsGuest) == nil {
            // First launch ever
            createGuestIdentity()
        } else {
            self.isGuest = UserDefaults.standard.bool(forKey: kIsGuest)
            self.guestHandle = UserDefaults.standard.string(forKey: kGuestHandle) ?? "Guest"
            if let idString = UserDefaults.standard.string(forKey: kGuestID), let id = UUID(uuidString: idString) {
                self.guestID = id
            } else {
                // Fallback if ID is missing
                createGuestIdentity()
            }
        }
    }
    
    private func createGuestIdentity() {
        self.isGuest = true
        self.guestID = UUID()
        self.guestHandle = "VibeGuest_\(Int.random(in: 1000...9999))"
        UserDefaults.standard.set(Date(), forKey: kSessionStartTime)
        
        saveState()
    }
    
    private func saveState() {
        UserDefaults.standard.set(isGuest, forKey: kIsGuest)
        UserDefaults.standard.set(guestHandle, forKey: kGuestHandle)
        UserDefaults.standard.set(guestID.uuidString, forKey: kGuestID)
    }
    
    private func startSessionTimer() {
        guard isGuest else { return }
        
        // Check every minute
        timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.checkSessionDuration()
        }
    }
    
    private func checkSessionDuration() {
        guard isGuest, !showSavePrompt else { return }
        
        if let startTime = UserDefaults.standard.object(forKey: kSessionStartTime) as? Date {
            let elapsed = Date().timeIntervalSince(startTime)
            // 4 hours = 14400 seconds
            // For testing/demo purposes, we might want this shorter, but requirement says ~4 hours.
            if elapsed >= 14400 {
                showSavePrompt = true
            }
        }
    }
    
    func upgradeToUser(handle: String) {
        self.isGuest = false
        self.guestHandle = handle
        self.showSavePrompt = false
        timer?.cancel()
        // In a real app, we would sync this to the backend here
        saveState()
    }
    
    func dismissSavePrompt() {
        showSavePrompt = false
        // Reset timer or mark as dismissed to not show again immediately?
        // For now, just dismiss.
    }
    
    func reset() {
        createGuestIdentity()
        showSavePrompt = false
        startSessionTimer()
    }
}
