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
        hoverService.handleFlagsChanged(cmdPressed: true, optionPressed: false, controlPressed: false)
        hoverService.handleFlagsChanged(cmdPressed: false, optionPressed: true, controlPressed: false)
        hoverService.handleFlagsChanged(cmdPressed: false, optionPressed: false, controlPressed: true)
        hoverService.handleFlagsChanged(cmdPressed: true, optionPressed: true, controlPressed: true)
        hoverService.handleFlagsChanged(cmdPressed: false, optionPressed: false, controlPressed: false)
    }

    func testControlKeySelectsFullscreenMode() {
        hoverService.start()
        // No modifiers → close (default)
        hoverService.handleFlagsChanged(cmdPressed: false, optionPressed: false, controlPressed: false)
        XCTAssertEqual(hoverService.currentOverlayMode, .close)
        // Control held → fullscreen
        hoverService.handleFlagsChanged(cmdPressed: false, optionPressed: false, controlPressed: true)
        XCTAssertEqual(hoverService.currentOverlayMode, .fullscreen)
        // Release → back to close
        hoverService.handleFlagsChanged(cmdPressed: false, optionPressed: false, controlPressed: false)
        XCTAssertEqual(hoverService.currentOverlayMode, .close)
    }

    // MARK: - Space-change observer lifecycle (#2)

    func testStartRegistersSpaceChangeObserver() {
        XCTAssertNil(hoverService.spaceChangeObserver)
        hoverService.start()
        XCTAssertNotNil(hoverService.spaceChangeObserver)
    }

    func testStopRemovesSpaceChangeObserver() {
        hoverService.start()
        XCTAssertNotNil(hoverService.spaceChangeObserver)
        hoverService.stop()
        XCTAssertNil(hoverService.spaceChangeObserver)
    }

    func testDoubleStartDoesNotDuplicateObserver() {
        hoverService.start()
        let first = hoverService.spaceChangeObserver
        hoverService.start() // no-op guard
        XCTAssertTrue(hoverService.spaceChangeObserver === first)
    }

    // MARK: - Window-list dedup (#3)

    func testInitialWindowCountIsZero() {
        XCTAssertEqual(hoverService._testWindowCount, 0)
    }
}
