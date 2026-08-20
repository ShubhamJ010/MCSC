import Foundation
import Cocoa
import XCTest

@MainActor
final class SearchBarOverlayTests: XCTestCase {
    func testFrameIsCenteredAndSitsAboveDock() {
        guard let screen = NSScreen.screens.first, screen.frame.width > 100 else {
            XCTFail("No usable screen for search bar frame test")
            return
        }

        let frame = SearchBarOverlay.panelFrame(query: "C", screen: screen)

        XCTAssertEqual(frame.height, SearchBarOverlay.barHeight)
        XCTAssertEqual(frame.midX, screen.frame.midX, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(frame.minY, screen.frame.minY + SearchBarOverlay.defaultDockTopOffset - 0.5)
        XCTAssertGreaterThanOrEqual(frame.width, SearchBarOverlay.minWidth)
    }

    func testShortQueryUsesMinimumWidth() {
        guard let screen = NSScreen.screens.first else {
            XCTFail("No primary screen for width test")
            return
        }

        let frame = SearchBarOverlay.panelFrame(query: "A", screen: screen)
        XCTAssertEqual(frame.width, SearchBarOverlay.minWidth, accuracy: 0.5)
    }

    func testWidthIsCappedToScreen() {
        guard let screen = NSScreen.screens.first, screen.frame.width > SearchBarOverlay.horizontalMargin else {
            XCTFail("No usable screen for clamp test")
            return
        }

        let longQuery = String(repeating: "W", count: 400)
        let frame = SearchBarOverlay.panelFrame(query: longQuery, screen: screen)
        let maxWidth = screen.frame.width - SearchBarOverlay.horizontalMargin
        XCTAssertLessThanOrEqual(frame.width, maxWidth + 0.5)
        XCTAssertGreaterThanOrEqual(frame.minX, screen.frame.minX)
        XCTAssertLessThanOrEqual(frame.maxX, screen.frame.maxX + 0.5)
    }
}
