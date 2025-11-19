import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    // MARK: - Onboarding State
    // Deprecated: We now use lazy signup, so this is always true effectively
    @Published var hasCompletedOnboarding: Bool = true
    
    // MARK: - Guest State
    @Published var isGuest: Bool = true
    
    // MARK: - Privacy Flags (Opt-In by Default)
    @Published var allowCrashReporting: Bool {
        didSet { UserDefaults.standard.set(allowCrashReporting, forKey: "allowCrashReporting") }
    }
    
    @Published var allowDiscoverability: Bool {
        didSet { UserDefaults.standard.set(allowDiscoverability, forKey: "allowDiscoverability") }
    }
    
    @Published var allowUsageAnalytics: Bool {
        didSet { UserDefaults.standard.set(allowUsageAnalytics, forKey: "allowUsageAnalytics") }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.allowCrashReporting = UserDefaults.standard.bool(forKey: "allowCrashReporting")
        self.allowDiscoverability = UserDefaults.standard.bool(forKey: "allowDiscoverability")
        self.allowUsageAnalytics = UserDefaults.standard.bool(forKey: "allowUsageAnalytics")
        
        // Sync with GuestService
        GuestService.shared.$isGuest
            .assign(to: \.isGuest, on: self)
            .store(in: &cancellables)
    }
    
    func resetPrivacy() {
        allowCrashReporting = false
        allowDiscoverability = false
        allowUsageAnalytics = false
    }
}
