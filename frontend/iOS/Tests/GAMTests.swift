import XCTest
@testable import VibeZ

@MainActor
final class GAMTests: XCTestCase {
    
    var manager: GlobalAccessManager!
    
    override func setUp() {
        super.setUp()
        manager = GlobalAccessManager.shared
        // Reset state before each test
        manager.toggleGAM(false)
        manager.dismissRecommendation()
    }
    
    func testToggleGAM() {
        XCTAssertFalse(manager.isGAMEnabled)
        XCTAssertEqual(manager.recommendedIceTransportPolicy, "all")
        
        manager.toggleGAM(true)
        
        XCTAssertTrue(manager.isGAMEnabled)
        XCTAssertEqual(manager.recommendedIceTransportPolicy, "relay")
    }
    
    func testFailureDetection() {
        // Initial state
        XCTAssertFalse(manager.isRestrictionDetected)
        XCTAssertEqual(manager.connectionFailureCount, 0)
        
        // Report 1st failure
        manager.reportConnectionFailure()
        XCTAssertEqual(manager.connectionFailureCount, 1)
        XCTAssertFalse(manager.isRestrictionDetected)
        
        // Report 2nd failure
        manager.reportConnectionFailure()
        XCTAssertEqual(manager.connectionFailureCount, 2)
        XCTAssertFalse(manager.isRestrictionDetected)
        
        // Report 3rd failure (Threshold)
        manager.reportConnectionFailure()
        XCTAssertEqual(manager.connectionFailureCount, 3)
        XCTAssertTrue(manager.isRestrictionDetected)
    }
    
    func testSuccessResetsCounter() {
        manager.reportConnectionFailure()
        manager.reportConnectionFailure()
        XCTAssertEqual(manager.connectionFailureCount, 2)
        
        manager.reportConnectionSuccess()
        XCTAssertEqual(manager.connectionFailureCount, 0)
    }
    
    func testManualEnableResetsDetection() {
        // Trigger detection
        manager.reportConnectionFailure()
        manager.reportConnectionFailure()
        manager.reportConnectionFailure()
        XCTAssertTrue(manager.isRestrictionDetected)
        
        // User enables GAM manually
        manager.toggleGAM(true)
        
        XCTAssertFalse(manager.isRestrictionDetected)
        XCTAssertEqual(manager.connectionFailureCount, 0)
    }
    
    func testDismissRecommendation() {
        // Trigger detection
        manager.reportConnectionFailure()
        manager.reportConnectionFailure()
        manager.reportConnectionFailure()
        XCTAssertTrue(manager.isRestrictionDetected)
        
        // User dismisses
        manager.dismissRecommendation()
        
        XCTAssertFalse(manager.isRestrictionDetected)
        XCTAssertEqual(manager.connectionFailureCount, 0)
    }
}
