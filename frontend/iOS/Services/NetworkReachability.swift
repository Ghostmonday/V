import Foundation
import Network
import Combine
import OSLog

/// Network Reachability Service
/// Monitors network status changes and triggers reconnection when network becomes available
@MainActor
class NetworkReachability: ObservableObject {
    private static let logger = Logger(subsystem: "com.vibez.app", category: "NetworkReachability")
    static let shared = NetworkReachability()
    
    @Published var isNetworkAvailable: Bool = true
    @Published var connectionType: ConnectionType = .unknown
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
        case unavailable
    }
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkReachability")
    private var cancellables = Set<AnyCancellable>()
    
    // Callback for network availability changes
    var onNetworkAvailable: (() -> Void)?
    var onNetworkUnavailable: (() -> Void)?
    
    private init() {
        startMonitoring()
    }
    
    /// Start monitoring network status
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                
                let wasAvailable = self.isNetworkAvailable
                let wasType = self.connectionType
                
                // Update network availability
                self.isNetworkAvailable = path.status == .satisfied
                
                // Determine connection type
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        self.connectionType = .wifi
                    } else if path.usesInterfaceType(.cellular) {
                        self.connectionType = .cellular
                    } else if path.usesInterfaceType(.wiredEthernet) {
                        self.connectionType = .ethernet
                    } else {
                        self.connectionType = .unknown
                    }
                } else {
                    self.connectionType = .unavailable
                }
                
                // Log network status changes
                if wasAvailable != self.isNetworkAvailable {
                    Self.logger.info("Network status changed: \(self.isNetworkAvailable ? "available" : "unavailable"), type: \(String(describing: self.connectionType))")
                    
                    // Trigger callbacks
                    if self.isNetworkAvailable && !wasAvailable {
                        // Network became available
                        self.onNetworkAvailable?()
                    } else if !self.isNetworkAvailable && wasAvailable {
                        // Network became unavailable
                        self.onNetworkUnavailable?()
                    }
                }
                
                // Log connection type changes
                if wasType != self.connectionType {
                    Self.logger.info("Connection type changed: \(String(describing: self.connectionType))")
                }
            }
        }
        
        monitor.start(queue: queue)
        Self.logger.info("Network monitoring started")
    }
    
    /// Stop monitoring network status
    nonisolated func stopMonitoring() {
        monitor.cancel()
        // Note: Can't use main actor-isolated logger from nonisolated context
        // Logger will be cleaned up automatically
    }
    
    /// Check if network is currently available (synchronous)
    func checkNetworkAvailability() -> Bool {
        return isNetworkAvailable
    }
    
    deinit {
        stopMonitoring()
    }
}

