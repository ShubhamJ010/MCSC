import Cocoa
import Foundation
import XCTest

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

    func testDockHoveredProviderIntegration() throws {
        var queriedPoint: CGPoint?
        suppressor.isDockHoveredProvider = { point in
            queriedPoint = point
            return point.y > 900
        }

        XCTAssertTrue(try XCTUnwrap(suppressor.isDockHoveredProvider?(CGPoint(x: 500, y: 950))))
        XCTAssertEqual(queriedPoint, CGPoint(x: 500, y: 950))

        XCTAssertFalse(try XCTUnwrap(suppressor.isDockHoveredProvider?(CGPoint(x: 500, y: 100))))
        XCTAssertEqual(queriedPoint, CGPoint(x: 500, y: 100))
    }

    func testIsEnabledProviderIntegration() throws {
        var isEnabled = true
        suppressor.isEnabledProvider = { isEnabled }

        XCTAssertTrue(try XCTUnwrap(suppressor.isEnabledProvider?()))

        isEnabled = false
        XCTAssertFalse(try XCTUnwrap(suppressor.isEnabledProvider?()))
    }

    func testMultipleStartsAndStopsAreSafe() {
        // Calling start/stop repeatedly should never crash or throw
        suppressor.start()
        suppressor.start()
        suppressor.stop()
        suppressor.stop()
    }
}
