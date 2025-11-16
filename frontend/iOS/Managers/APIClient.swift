import Foundation

/// API Client for VibeZ backend
/// Handles all HTTP requests to Express/Node backend
@MainActor
class APIClient {
    static let shared = APIClient()
    
    // Base URL - configure based on environment
    static var baseURL: String {
        #if DEBUG
        return "http://localhost:3000"
        #else
        return ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "https://your-production-url.com"
        #endif
    }
    
    static var wsBaseURL: String {
        return baseURL.replacingOccurrences(of: "http://", with: "ws://").replacingOccurrences(of: "https://", with: "wss://")
    }
    
    // Endpoint constants aligned with backend routes
    enum Endpoint {
        // Authentication
        static let authApple = "/auth/apple"
        static let authGoogle = "/auth/google"
        static let authLogin = "/auth/login"
        static let authFirebase = "/auth/firebase"
        
        // Rooms
        static let roomsList = "/rooms/list"
        static let roomsCreate = "/rooms/create"
        static func roomDetail(_ roomId: String) -> String { "/chat-rooms/\(roomId)" }
        
        // Messaging
        static let messagingSend = "/messaging/send"
        static func messagingRoom(_ roomId: String) -> String { "/messaging/\(roomId)" }
        
        // Search
        static let search = "/api/search"
        static let searchMessages = "/api/search/messages"
        static let searchRooms = "/api/search/rooms"
        
        // Read Receipts
        static let readReceiptsRead = "/api/read-receipts/read"
        static let readReceiptsDelivered = "/api/read-receipts/delivered"
        static func readReceiptsMessage(_ messageId: String) -> String { "/api/read-receipts/\(messageId)" }
        
        // Polls
        static let pollsCreate = "/api/polls"
        static func pollsVote(_ pollId: String) -> String { "/api/polls/\(pollId)/vote" }
        static func pollsResults(_ pollId: String) -> String { "/api/polls/\(pollId)/results" }
        static func pollsRoom(_ roomId: String) -> String { "/api/polls/room/\(roomId)" }
        
        // Pinned Items
        static let pinnedItems = "/api/pinned"
        static func pinnedItem(_ itemId: String) -> String { "/api/pinned/\(itemId)" }
        
        // Bot Invites
        static let botInvitesCreate = "/api/bot-invites/create"
        static func botInvitesRedeem(_ token: String) -> String { "/api/bot-invites/redeem/\(token)" }
        
        // Nicknames
        static let nicknames = "/api/nicknames"
        static func nicknameRoom(_ roomId: String) -> String { "/api/nicknames/room/\(roomId)" }
        
        // Bandwidth
        static let bandwidthPreference = "/api/bandwidth/preference"
        
        // Presence
        static let presenceStatus = "/presence/status"
        static let presenceUpdate = "/presence/update"
        
        // AI
        static let aiChat = "/ai/chat"
        
        // Telemetry
        static let telemetryLog = "/telemetry/log"
        
        // Config
        static let config = "/config"
    }
    
    private var session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    /// Generic request method
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil,
        queryParams: [String: String]? = nil
    ) async throws -> T {
        var urlString = APIClient.baseURL + endpoint
        
        // Add query parameters
        if let queryParams = queryParams, !queryParams.isEmpty {
            let queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
            var components = URLComponents(string: urlString)
            components?.queryItems = queryItems
            urlString = components?.url?.absoluteString ?? urlString
        }
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication token if available
        if let token = AuthTokenManager.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body for POST/PUT requests
        if let body = body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
    
    /// Request without response body
    func request(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil,
        queryParams: [String: String]? = nil
    ) async throws {
        var urlString = APIClient.baseURL + endpoint
        
        if let queryParams = queryParams, !queryParams.isEmpty {
            let queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
            var components = URLComponents(string: urlString)
            components?.queryItems = queryItems
            urlString = components?.url?.absoluteString ?? urlString
        }
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthTokenManager.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
}

/// Simple token manager for authentication
@MainActor
class AuthTokenManager {
    static let shared = AuthTokenManager()
    private let keychainKey = "vibez_auth_token"
    
    var token: String? {
        get {
            return UserDefaults.standard.string(forKey: keychainKey)
        }
        set {
            if let token = newValue {
                UserDefaults.standard.set(token, forKey: keychainKey)
            } else {
                UserDefaults.standard.removeObject(forKey: keychainKey)
            }
        }
    }
    
    private init() {}
}

