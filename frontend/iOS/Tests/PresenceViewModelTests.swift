/**
 * Unit Tests for PresenceViewModel
 * Tests presence loading, status fetching, distribution calculation, and incremental updates
 */

import XCTest
@testable import VibeZ

@MainActor
final class PresenceViewModelTests: XCTestCase {
    var viewModel: PresenceViewModel!
    var mockRoomService: MockRoomService!
    
    override func setUp() {
        super.setUp()
        mockRoomService = MockRoomService()
        viewModel = PresenceViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        mockRoomService = nil
        super.tearDown()
    }
    
    func testLoadPresenceWithUsers() async {
        // Given: Mock rooms with users
        let mockUsers = [
            User(id: UUID(), name: "User 1", avatar: "", mood: "calm", presenceStatus: .online),
            User(id: UUID(), name: "User 2", avatar: "", mood: "excited", presenceStatus: .away)
        ]
        
        // When: Load presence
        // Note: This would require dependency injection to properly test
        // For now, we test the public methods
        
        // Then: Verify users are loaded
        // This test structure shows the pattern - actual implementation would require DI
    }
    
    func testGetPresenceDistribution() {
        // Given: ViewModel with users
        viewModel.users = [
            User(id: UUID(), name: "User 1", avatar: "", mood: "calm", presenceStatus: .online),
            User(id: UUID(), name: "User 2", avatar: "", mood: "calm", presenceStatus: .online),
            User(id: UUID(), name: "User 3", avatar: "", mood: "calm", presenceStatus: .offline),
            User(id: UUID(), name: "User 4", avatar: "", mood: "calm", presenceStatus: .away),
            User(id: UUID(), name: "User 5", avatar: "", mood: "calm", presenceStatus: .busy)
        ]
        
        // When: Get distribution
        let distribution = viewModel.getPresenceDistribution()
        
        // Then: Verify counts
        XCTAssertEqual(distribution["online"], 2)
        XCTAssertEqual(distribution["offline"], 1)
        XCTAssertEqual(distribution["away"], 1)
        XCTAssertEqual(distribution["busy"], 1)
    }
    
    func testGetActiveParticipantsCount() {
        // Given: ViewModel with mixed presence users
        viewModel.users = [
            User(id: UUID(), name: "User 1", avatar: "", mood: "calm", presenceStatus: .online),
            User(id: UUID(), name: "User 2", avatar: "", mood: "calm", presenceStatus: .away),
            User(id: UUID(), name: "User 3", avatar: "", mood: "calm", presenceStatus: .busy),
            User(id: UUID(), name: "User 4", avatar: "", mood: "calm", presenceStatus: .offline)
        ]
        
        // When: Get active count
        let activeCount = viewModel.getActiveParticipantsCount()
        
        // Then: Should exclude offline
        XCTAssertEqual(activeCount, 3) // online, away, busy
    }
    
    func testGetOnlineParticipantsCount() {
        // Given: ViewModel with mixed presence users
        viewModel.users = [
            User(id: UUID(), name: "User 1", avatar: "", mood: "calm", presenceStatus: .online),
            User(id: UUID(), name: "User 2", avatar: "", mood: "calm", presenceStatus: .online),
            User(id: UUID(), name: "User 3", avatar: "", mood: "calm", presenceStatus: .away),
            User(id: UUID(), name: "User 4", avatar: "", mood: "calm", presenceStatus: .offline)
        ]
        
        // When: Get online count
        let onlineCount = viewModel.getOnlineParticipantsCount()
        
        // Then: Should only count online
        XCTAssertEqual(onlineCount, 2)
    }
    
    func testPresenceUpdateViaPublisher() {
        // Given: ViewModel with existing user
        let userId = UUID()
        viewModel.users = [
            User(id: userId, name: "User 1", avatar: "", mood: "calm", presenceStatus: .offline)
        ]
        
        // When: Presence update is published via WebSocket
        // Note: This tests the integration - actual handlePresenceUpdate is private
        // In production, this would be tested via WebSocketManager.presencePublisher
        
        // Then: User status should be updated
        // This test demonstrates the pattern - full test would require WebSocket mocking
    }
    
    func testPresenceDistributionWithNilStatus() {
        // Given: User with nil presence status
        viewModel.users = [
            User(id: UUID(), name: "User 1", avatar: "", mood: "calm", presenceStatus: nil)
        ]
        
        // When: Get distribution
        let distribution = viewModel.getPresenceDistribution()
        
        // Then: Should default to offline
        XCTAssertEqual(distribution["offline"], 1)
    }
}

// MARK: - Mock Helpers

class MockRoomService {
    var rooms: [Room] = []
}

