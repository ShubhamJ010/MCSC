import XCTest
import Foundation
import Cocoa

final class DockInteractionSuppressorTests: XCTestCase {
    private var suppressor: DockInteractionSuppressor!

    override func setUp() {
        super.setUp()
        suppressor = DockInteractionSuppressor()
    }

    override func tearDown() {
        suppressor.stop()
        suppressor = nil
        super.tearDown()
    }

    func testInitialStateIsDisabled() {
        XCTAssertFalse(suppressor.isSuppressing)
        XCTAssertNil(suppressor.isDockHoveredProvider)
        XCTAssertNil(suppressor.isEnabledProvider)
    }

    func testSuppressionStateCanBeMutated() {
        suppressor.isSuppressing = true
        XCTAssertTrue(suppressor.isSuppressing)
        suppressor.isSuppressing = false
        XCTAssertFalse(suppressor.isSuppressing)
    }

    func testStopResetsSuppressionState() {
        suppressor.isSuppressing = true
        suppressor.stop()
        XCTAssertFalse(suppressor.isSuppressing)
    }

    func testDockHoveredProviderIntegration() {
        var queriedPoint: CGPoint?
        suppressor.isDockHoveredProvider = { point in
            queriedPoint = point
            return point.y > 900
        }

        XCTAssertTrue(suppressor.isDockHoveredProvider!(CGPoint(x: 500, y: 950)))
        XCTAssertEqual(queriedPoint, CGPoint(x: 500, y: 950))

        XCTAssertFalse(suppressor.isDockHoveredProvider!(CGPoint(x: 500, y: 100)))
        XCTAssertEqual(queriedPoint, CGPoint(x: 500, y: 100))
    }

    func testIsEnabledProviderIntegration() {
        var isEnabled = true
        suppressor.isEnabledProvider = { isEnabled }

        XCTAssertTrue(suppressor.isEnabledProvider!())

        isEnabled = false
        XCTAssertFalse(suppressor.isEnabledProvider!())
    }

    func testMultipleStartsAndStopsAreSafe() {
        // Calling start/stop repeatedly should never crash or throw
        suppressor.start()
        suppressor.start()
        suppressor.stop()
        suppressor.stop()
    }
}
