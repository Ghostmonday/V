import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
@available(iOS 17.0, *)
struct VibeZApp: App {
    @StateObject private var presenceViewModel = PresenceViewModel()
    @StateObject private var firebaseAuthViewModel = FirebaseAuthViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var darkMode = false
    
    init() {
        // Initialize Firebase first (must be done before Google Sign-In)
        FirebaseApp.configure()
        
        // Configure Google Sign-In after Firebase initialization
        // This ensures proper initialization order and prevents race conditions
        DispatchQueue.main.async {
            if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
               let plist = NSDictionary(contentsOfFile: path),
               let clientId = plist["CLIENT_ID"] as? String {
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
            }
        }
        // Global tint - golden vibez theme
        UIView.appearance().tintColor = UIColor(named: "VibeZGold") ?? UIColor(red: 0.96, green: 0.75, blue: 0.29, alpha: 1.0)
        
        // Navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(named: "VibeZDeep") ?? UIColor(red: 0.10, green: 0.06, blue: 0.00, alpha: 1.0)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(named: "VibeZGold") ?? UIColor(red: 0.96, green: 0.75, blue: 0.29, alpha: 1.0)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(named: "VibeZGold") ?? UIColor(red: 0.96, green: 0.75, blue: 0.29, alpha: 1.0)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        
        // Tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(named: "VibeZDeep") ?? UIColor(red: 0.10, green: 0.06, blue: 0.00, alpha: 1.0)
        tabAppearance.selectionIndicatorTintColor = UIColor(named: "VibeZGold") ?? UIColor(red: 0.96, green: 0.75, blue: 0.29, alpha: 1.0)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                // Check Firebase authentication state first
                if firebaseAuthViewModel.state == .signedIn {
                    // User is authenticated - check onboarding
                    if hasCompletedOnboarding {
                        MainTabView()
                            .environmentObject(presenceViewModel)
                            .environmentObject(firebaseAuthViewModel)
                            .task {
                                // Restore IAP on launch
                                await SubscriptionManager.shared.restorePurchases()
                                // Preload services (using @MainActor task instead of Task.detached)
                                Task { @MainActor in
                                    await RoomService.preload()
                                }
                                // Start telemetry monitoring
                                SystemMonitor.shared.monitorTelemetry()
                            }
                            .transition(.opacity)
                    } else {
                        OnboardingView()
                            .environmentObject(firebaseAuthViewModel)
                            .transition(.opacity)
                    }
                } else {
                    // User is not authenticated - show login
                    LoginView()
                        .environmentObject(firebaseAuthViewModel)
                        .overlay {
                            if firebaseAuthViewModel.isLoading {
                                LoadingView()
                            }
                        }
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: firebaseAuthViewModel.state)
            .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
            .onOpenURL { url in
                // Handle deep links, such as those from Google Sign-In
                GIDSignIn.sharedInstance.handle(url)
            }
            .onAppear {
                darkMode = UIScreen.main.traitCollection.userInterfaceStyle == .dark
            }
            .accentColor(darkMode ? .white : .black)
            .preferredColorScheme(darkMode ? .dark : .light)
        }
    }
}

