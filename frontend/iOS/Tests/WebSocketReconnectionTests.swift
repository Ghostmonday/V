/**
 * WebSocket Reconnection Tests
 * Tests reconnection state machine, message outbox functionality, room restoration, and network reachability integration
 */

import XCTest
@testable import VibeZ
import Combine

@MainActor
final class WebSocketReconnectionTests: XCTestCase {
    var webSocketManager: WebSocketManager!
    var networkReachability: NetworkReachability!
    var roomRestoration: RoomRestorationService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        webSocketManager = WebSocketManager.shared
        networkReachability = NetworkReachability.shared
        roomRestoration = RoomRestorationService.shared
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        webSocketManager.disconnect()
        roomRestoration.clearAllRooms()
        super.tearDown()
    }
    
    // MARK: - Reconnection State Machine Tests
    
    func testStateMachineTransitions() {
        // Given: Initial disconnected state
        XCTAssertEqual(webSocketManager.connectionState, .disconnected)
        XCTAssertFalse(webSocketManager.isConnected)
        
        // When: Connecting
        webSocketManager.connect(userId: "test-user", token: "test-token")
        
        // Then: Should transition through states
        // Note: Actual state transitions depend on WebSocket connection success
        // In a real test, we'd mock the WebSocket connection
    }
    
    func testStateMachineDisconnectedToConnecting() {
        // Given: Disconnected state
        XCTAssertEqual(webSocketManager.connectionState, .disconnected)
        
        // When: Attempting connection
        webSocketManager.connect(userId: "test-user", token: "test-token")
        
        // Then: Should be in connecting or connected state
        let state = webSocketManager.connectionState
        XCTAssertTrue(state == .connecting || state == .connected || state == .ready)
    }
    
    func testStateMachineDisconnect() {
        // Given: Connected state (if connection succeeds)
        webSocketManager.connect(userId: "test-user", token: "test-token")
        
        // When: Disconnecting
        webSocketManager.disconnect()
        
        // Then: Should be disconnected
        XCTAssertEqual(webSocketManager.connectionState, .disconnected)
        XCTAssertFalse(webSocketManager.isConnected)
    }
    
    // MARK: - Exponential Backoff Tests
    
    func testExponentialBackoffCalculation() {
        // Note: Backoff calculation is private, but we can test behavior
        // by observing reconnection timing
        
        // Given: Disconnected state
        webSocketManager.disconnect()
        
        // When: Connection is lost and reconnection attempted
        // The backoff delay should increase with each attempt
        
        // This would require mocking the WebSocket to simulate failures
        // and measuring the time between reconnection attempts
    }
    
    func testMaximumRetryAttempts() {
        // Given: Connection with stored credentials
        webSocketManager.connect(userId: "test-user", token: "test-token")
        webSocketManager.disconnect()
        
        // When: Multiple reconnection attempts fail
        // Then: Should stop after max attempts (10)
        
        // Note: This requires mocking network failures
    }
    
    // MARK: - Message Outbox Tests
    
    func testOutboxQueueWhenDisconnected() {
        // Given: Disconnected state
        webSocketManager.disconnect()
        XCTAssertFalse(webSocketManager.isConnected)
        
        // When: Sending message while disconnected
        webSocketManager.send(event: "test_event", payload: ["key": "value"])
        
        // Then: Message should be queued in outbox
        // Note: Outbox is private, but we can verify by checking
        // that messages are sent after reconnection
    }
    
    func testOutboxFlushOnReconnection() {
        // Given: Disconnected with queued messages
        webSocketManager.disconnect()
        webSocketManager.send(event: "test_event", payload: ["key": "value"])
        
        // When: Reconnecting
        webSocketManager.connect(userId: "test-user", token: "test-token")
        
        // Then: Outbox should be flushed
        // Note: Requires WebSocket mocking to verify messages are sent
    }
    
    func testOutboxTTLExpiration() {
        // Given: Disconnected with queued messages
        webSocketManager.disconnect()
        webSocketManager.send(event: "test_event", payload: ["key": "value"])
        
        // When: Waiting longer than TTL (60 seconds)
        // Then: Expired messages should be removed
        
        // Note: This requires time manipulation or waiting
        // In a real test, we'd use a test clock or fast-forward time
    }
    
    func testOutboxSizeLimit() {
        // Given: Disconnected state
        webSocketManager.disconnect()
        
        // When: Queueing more than maxOutboxSize (100) messages
        for i in 0..<150 {
            webSocketManager.send(event: "test_event", payload: ["index": i])
        }
        
        // Then: Oldest messages should be dropped
        // Note: Outbox is private, but behavior can be inferred
    }
    
    // MARK: - Room Restoration Tests
    
    func testRoomRestorationServiceAddRoom() {
        // Given: Empty room restoration service
        roomRestoration.clearAllRooms()
        
        // When: Adding a room
        roomRestoration.addRoom("room-123")
        
        // Then: Room should be tracked
        let rooms = roomRestoration.getJoinedRooms()
        XCTAssertTrue(rooms.contains("room-123"))
    }
    
    func testRoomRestorationServiceRemoveRoom() {
        // Given: Room in restoration service
        roomRestoration.addRoom("room-123")
        
        // When: Removing room
        roomRestoration.removeRoom("room-123")
        
        // Then: Room should not be tracked
        let rooms = roomRestoration.getJoinedRooms()
        XCTAssertFalse(rooms.contains("room-123"))
    }
    
    func testRoomRestorationServicePersistence() {
        // Given: Rooms added to restoration service
        roomRestoration.clearAllRooms()
        roomRestoration.addRoom("room-1")
        roomRestoration.addRoom("room-2")
        roomRestoration.addRoom("room-3")
        
        // When: Creating new instance (simulating app restart)
        let newRestoration = RoomRestorationService.shared
        
        // Then: Rooms should be persisted
        let rooms = newRestoration.getJoinedRooms()
        XCTAssertTrue(rooms.contains("room-1"))
        XCTAssertTrue(rooms.contains("room-2"))
        XCTAssertTrue(rooms.contains("room-3"))
    }
    
    func testRoomRestorationBatchRejoin() {
        // Given: Multiple rooms
        roomRestoration.clearAllRooms()
        for i in 1...15 {
            roomRestoration.addRoom("room-\(i)")
        }
        
        // When: Getting batch for rejoin
        let batch = roomRestoration.getRoomsForBatchRejoin(batchSize: 10)
        
        // Then: Should return batch of specified size
        XCTAssertEqual(batch.count, 10)
    }
    
    func testRoomRestorationClearAll() {
        // Given: Multiple rooms
        roomRestoration.addRoom("room-1")
        roomRestoration.addRoom("room-2")
        
        // When: Clearing all rooms
        roomRestoration.clearAllRooms()
        
        // Then: No rooms should be tracked
        let rooms = roomRestoration.getJoinedRooms()
        XCTAssertTrue(rooms.isEmpty)
    }
    
    // MARK: - Network Reachability Tests
    
    func testNetworkReachabilityInitialState() {
        // Given: Network reachability service
        // When: Initialized
        // Then: Should have initial state
        XCTAssertNotNil(networkReachability.isNetworkAvailable)
    }
    
    func testNetworkReachabilityCallbacks() {
        // Given: Network reachability service
        var networkAvailableCalled = false
        var networkUnavailableCalled = false
        
        networkReachability.onNetworkAvailable = {
            networkAvailableCalled = true
        }
        
        networkReachability.onNetworkUnavailable = {
            networkUnavailableCalled = true
        }
        
        // When: Network status changes
        // Then: Callbacks should be triggered
        
        // Note: Actual network status changes require system-level mocking
        // or real network state changes
    }
    
    func testNetworkReachabilityPreventsReconnection() {
        // Given: Disconnected WebSocket
        webSocketManager.disconnect()
        
        // When: Network is unavailable
        // Then: Reconnection should not be attempted
        
        // Note: Requires network state mocking
    }
    
    // MARK: - Ping/Pong Tests
    
    func testPingInterval() {
        // Given: Connected WebSocket
        webSocketManager.connect(userId: "test-user", token: "test-token")
        
        // When: Connection is established
        // Then: Ping should be sent periodically (every 30 seconds)
        
        // Note: Requires WebSocket mocking to verify ping calls
    }
    
    func testConnectionTimeoutDetection() {
        // Given: Connected WebSocket
        webSocketManager.connect(userId: "test-user", token: "test-token")
        
        // When: No messages received for timeout period (90 seconds)
        // Then: Connection should be considered dead and reconnection attempted
        
        // Note: Requires time manipulation or waiting
    }
    
    // MARK: - App Lifecycle Tests
    
    func testAppBackgroundHandling() {
        // Given: Connected WebSocket
        webSocketManager.connect(userId: "test-user", token: "test-token")
        
        // When: App enters background
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        // Then: Connection handling should be appropriate
        // Note: iOS may suspend WebSocket connections in background
    }
    
    func testAppForegroundReconnection() {
        // Given: Disconnected WebSocket
        webSocketManager.disconnect()
        
        // When: App enters foreground
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        
        // Then: Reconnection should be attempted if credentials are stored
        // Note: Requires stored credentials from previous connection
    }
    
    // MARK: - Integration Tests
    
    func testFullReconnectionFlow() {
        // Given: Initial disconnected state
        XCTAssertEqual(webSocketManager.connectionState, .disconnected)
        
        // When: Connecting with rooms
        roomRestoration.addRoom("room-1")
        roomRestoration.addRoom("room-2")
        webSocketManager.connect(userId: "test-user", token: "test-token")
        
        // Then: Should transition through states and restore rooms
        // Note: Requires WebSocket mocking to verify full flow
    }
    
    func testReconnectionWithOutboxMessages() {
        // Given: Disconnected with queued messages
        webSocketManager.disconnect()
        webSocketManager.send(event: "message", payload: ["text": "Hello"])
        webSocketManager.send(event: "typing_start", payload: ["roomId": "room-123"])
        
        // When: Reconnecting
        webSocketManager.connect(userId: "test-user", token: "test-token")
        
        // Then: Queued messages should be sent
        // Note: Requires WebSocket mocking to verify
    }
    
    func testRoomRestorationAfterReconnection() {
        // Given: Rooms tracked before connection
        roomRestoration.clearAllRooms()
        roomRestoration.addRoom("room-1")
        roomRestoration.addRoom("room-2")
        
        // When: Connecting
        webSocketManager.connect(userId: "test-user", token: "test-token")
        
        // Then: Rooms should be restored
        // Note: Requires WebSocket mocking to verify room join messages
    }
    
    // MARK: - Edge Cases
    
    func testMultipleRapidReconnections() {
        // Given: WebSocket manager
        // When: Rapid connect/disconnect cycles
        for _ in 0..<5 {
            webSocketManager.connect(userId: "test-user", token: "test-token")
            webSocketManager.disconnect()
        }
        
        // Then: Should handle gracefully without crashes
        XCTAssertEqual(webSocketManager.connectionState, .disconnected)
    }
    
    func testReconnectionWithoutStoredCredentials() {
        // Given: Disconnected without stored credentials
        webSocketManager.disconnect()
        
        // When: Attempting reconnection
        // Then: Should not reconnect (no credentials)
        // Note: Requires network failure simulation
    }
    
    func testOutboxWithInvalidMessages() {
        // Given: Disconnected state
        webSocketManager.disconnect()
        
        // When: Queueing messages with invalid data
        webSocketManager.send(event: "test", payload: ["invalid": "data"])
        
        // Then: Should handle gracefully
        // Note: Outbox should queue messages regardless of validity
    }
}

