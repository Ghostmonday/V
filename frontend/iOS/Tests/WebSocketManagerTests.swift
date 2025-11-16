/**
 * Unit Tests for WebSocketManager
 * Tests connection management, message sending/receiving, and state tracking
 */

import XCTest
@testable import VibeZ
import Combine

@MainActor
final class WebSocketManagerTests: XCTestCase {
    var webSocketManager: WebSocketManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        webSocketManager = WebSocketManager.shared
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        webSocketManager = nil
        super.tearDown()
    }
    
    func testInitialConnectionState() {
        // Given: New WebSocketManager
        // When: Initialized
        // Then: Should be disconnected
        XCTAssertFalse(webSocketManager.isConnected)
        XCTAssertEqual(webSocketManager.connectionState, .disconnected)
    }
    
    func testConnectionStatePublisher() {
        // Given: Connection state publisher
        let expectation = XCTestExpectation(description: "Connection state updates")
        
        webSocketManager.$connectionState
            .sink { state in
                if state == .disconnected {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: State changes
        // Then: Publisher should emit
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testIsConnectedPublisher() {
        // Given: isConnected publisher
        let expectation = XCTestExpectation(description: "Connection status updates")
        
        webSocketManager.$isConnected
            .sink { isConnected in
                if !isConnected {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: Connection status changes
        // Then: Publisher should emit
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMessagePublisher() {
        // Given: Message publisher
        let expectation = XCTestExpectation(description: "Message received")
        
        webSocketManager.messagePublisher
            .sink { message in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When: Message is received (would need to simulate)
        // Then: Publisher should emit
        
        // Note: Full test would require WebSocket mocking
    }
    
    func testPresencePublisher() {
        // Given: Presence publisher
        let expectation = XCTestExpectation(description: "Presence update received")
        
        webSocketManager.presencePublisher
            .sink { update in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When: Presence update is received
        // Then: Publisher should emit
        
        // Note: Full test would require WebSocket mocking
    }
    
    func testSendMessageWhenDisconnected() {
        // Given: Disconnected WebSocket
        webSocketManager.isConnected = false
        
        // When: Send message
        webSocketManager.send(event: "test", payload: [:])
        
        // Then: Should not send (logged as warning)
        // Note: Actual verification would require checking logs
    }
}

