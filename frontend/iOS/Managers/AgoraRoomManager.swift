import Foundation
import Combine

/// Agora Room Manager - Handles room joining, token management, and member state
@MainActor
class AgoraRoomManager: ObservableObject {
    static let shared = AgoraRoomManager()
    
    @Published var isVoiceOnly = false
    @Published var currentUserId: String = ""
    @Published var currentUid: Int = 0
    @Published var currentToken: String = ""
    
    private let apiBaseURL: String
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Get API base URL from config or environment
        self.apiBaseURL = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:3000"
    }
    
    struct JoinResult {
        let success: Bool
        let token: String?
        let channelName: String?
        let uid: Int?
        let members: [RoomMember]
        let isVideoEnabled: Bool
        let isMuted: Bool
        let error: String?
    }
    
    /// Join a room and get Agora token
    func joinRoom(roomId: String) async throws -> JoinResult {
        guard let userId = getCurrentUserId() else {
            return JoinResult(
                success: false,
                token: nil,
                channelName: nil,
                uid: nil,
                members: [],
                isVideoEnabled: false,
                isMuted: false,
                error: "User not authenticated"
            )
        }
        
        guard let url = URL(string: "\(apiBaseURL)/chat-rooms/\(roomId)/join") else {
            return JoinResult(
                success: false,
                token: nil,
                channelName: nil,
                uid: nil,
                members: [],
                isVideoEnabled: false,
                isMuted: false,
                error: "Invalid URL"
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if available
        if let authToken = getAuthToken() {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return JoinResult(
                    success: false,
                    token: nil,
                    channelName: nil,
                    uid: nil,
                    members: [],
                    isVideoEnabled: false,
                    isMuted: false,
                    error: "Invalid response"
                )
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let result = try decoder.decode(JoinResponse.self, from: data)
                
                // Store current session info
                self.currentUserId = userId
                self.currentUid = result.uid
                self.currentToken = result.token
                self.isVoiceOnly = result.roomState?.voiceOnly ?? false
                
                // Convert API members to RoomMember
                let members = result.members.map { apiMember in
                    RoomMember(
                        id: apiMember.userId,
                        userId: apiMember.userId,
                        uid: apiMember.uid,
                        isMuted: apiMember.isMuted,
                        isVideoEnabled: apiMember.isVideoEnabled,
                        joinedAt: Int(Date().timeIntervalSince1970)
                    )
                }
                
                // Find current user's state
                let currentMember = members.first { $0.userId == userId }
                
                return JoinResult(
                    success: true,
                    token: result.token,
                    channelName: result.channelName,
                    uid: result.uid,
                    members: members,
                    isVideoEnabled: currentMember?.isVideoEnabled ?? true,
                    isMuted: currentMember?.isMuted ?? false,
                    error: nil
                )
            } else {
                let errorMessage = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                return JoinResult(
                    success: false,
                    token: nil,
                    channelName: nil,
                    uid: nil,
                    members: [],
                    isVideoEnabled: false,
                    isMuted: false,
                    error: errorMessage?.error ?? "Failed to join room"
                )
            }
        } catch {
            return JoinResult(
                success: false,
                token: nil,
                channelName: nil,
                uid: nil,
                members: [],
                isVideoEnabled: false,
                isMuted: false,
                error: error.localizedDescription
            )
        }
    }
    
    /// Toggle mute status
    func toggleMute(roomId: String, isMuted: Bool) async -> Bool {
        return await updateRoomState(roomId: roomId, endpoint: "mute", body: ["isMuted": isMuted])
    }
    
    /// Toggle video status
    func toggleVideo(roomId: String, isVideoEnabled: Bool) async -> Bool {
        return await updateRoomState(roomId: roomId, endpoint: "video", body: ["isVideoEnabled": isVideoEnabled])
    }
    
    /// Leave room
    func leaveRoom(roomId: String) async {
        guard let url = URL(string: "\(apiBaseURL)/rooms/\(roomId)/leave") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = getAuthToken() {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        _ = try? await URLSession.shared.data(for: request)
        
        // Reset state
        self.currentUserId = ""
        self.currentUid = 0
        self.currentToken = ""
    }
    
    /// Get room members
    func getRoomMembers(roomId: String) async -> [RoomMember] {
        guard let url = URL(string: "\(apiBaseURL)/rooms/\(roomId)/members") else { return [] }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = getAuthToken() {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }
            
            let decoder = JSONDecoder()
            let result = try decoder.decode(MembersResponse.self, from: data)
            
            return result.members.map { apiMember in
                RoomMember(
                    id: apiMember.userId,
                    userId: apiMember.userId,
                    uid: apiMember.uid,
                    isMuted: apiMember.isMuted,
                    isVideoEnabled: apiMember.isVideoEnabled,
                    joinedAt: apiMember.joinedAt
                )
            }
        } catch {
            return []
        }
    }
    
    // MARK: - Private Helpers
    
    private func updateRoomState(roomId: String, endpoint: String, body: [String: Any]) async -> Bool {
        guard let url = URL(string: "\(apiBaseURL)/rooms/\(roomId)/\(endpoint)") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = getAuthToken() {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
    
    private func getCurrentUserId() -> String? {
        // TODO: Get from auth service
        return UserDefaults.standard.string(forKey: "userId")
    }
    
    private func getAuthToken() -> String? {
        // TODO: Get from auth service
        return UserDefaults.standard.string(forKey: "authToken")
    }
}

// MARK: - API Response Models

struct JoinResponse: Codable {
    let success: Bool
    let token: String
    let channelName: String
    let uid: Int
    let members: [APIMember]
    let roomState: RoomState?
}

struct APIMember: Codable {
    let userId: String
    let uid: Int
    let isMuted: Bool
    let isVideoEnabled: Bool
}

struct RoomState: Codable {
    let capacity: Int
    let voiceOnly: Bool
    let memberCount: Int
}

struct MembersResponse: Codable {
    let success: Bool
    let members: [APIMemberWithTimestamp]
}

struct APIMemberWithTimestamp: Codable {
    let userId: String
    let uid: Int
    let isMuted: Bool
    let isVideoEnabled: Bool
    let joinedAt: Int
}

struct ErrorResponse: Codable {
    let error: String
}

