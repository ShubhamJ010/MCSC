import Foundation
import Cocoa
import XCTest

@MainActor
final class MissionControlHoverServiceTests: XCTestCase {
    private var mockService: MockAccessibilityService!
    private var isMissionControlActive = false
    private var hoverService: MissionControlHoverService!

    override func setUp() {
        super.setUp()
        mockService = MockAccessibilityService()
        isMissionControlActive = false
        hoverService = MissionControlHoverService(
            accessibilityService: mockService,
            isMissionControlActiveProvider: { [weak self] in
                self?.isMissionControlActive ?? false
            }
        )
    }

    override func tearDown() {
        hoverService.stop()
        hoverService = nil
        mockService = nil
        super.tearDown()
    }

    func testInitialStateIsNotTracking() {
        XCTAssertFalse(hoverService.isTracking)
        XCTAssertTrue(hoverService.isEnabled)
    }

    func testStartAndStopTracking() {
        hoverService.start()
        XCTAssertTrue(hoverService.isTracking)
        
        hoverService.stop()
        XCTAssertFalse(hoverService.isTracking)
    }

    func testTogglingEnabledState() {
        hoverService.isEnabled = false
        XCTAssertFalse(hoverService.isEnabled)
        
        hoverService.isEnabled = true
        XCTAssertTrue(hoverService.isEnabled)
    }

    func testMouseDownWhenNotActiveReturnsFalse() {
        let result = hoverService.handleMouseDown(at: CGPoint(x: 100, y: 100))
        XCTAssertFalse(result)
    }

    func testFlagsChangedDoesNotCrash() {
        hoverService.start()
        hoverService.handleFlagsChanged(cmdPressed: true)
        hoverService.handleFlagsChanged(cmdPressed: false)
    }
}
