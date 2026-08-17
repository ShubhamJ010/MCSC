import Foundation
import Cocoa
import XCTest

final class CursorFeedbackOverlayTests: XCTestCase {
    private let panelSize = CGSize(width: 34, height: 34)

    func testCentersPanelOnAXPoint() {
        let primary = NSScreen.screens.first?.frame ?? .zero
        guard primary != .zero, primary.width > 100, primary.height > 100 else {
            XCTFail("No usable primary screen for centering test")
            return
        }

        // A point at the middle of the primary screen, expressed in
        // Quartz/AX coordinates (origin top-left).
        let axPoint = CGPoint(x: primary.midX, y: primary.height - primary.midY)

        let anchor = CursorFeedbackOverlay.cocoaAnchorPoint(for: axPoint, panelSize: panelSize)

        // The panel center (Cocoa coords) must land exactly on the AX point.
        XCTAssertEqual(anchor.x + panelSize.width / 2, axPoint.x, accuracy: 0.5,
                       "Panel should be horizontally centered on the AX point")
        XCTAssertEqual(anchor.y + panelSize.height / 2, primary.height - axPoint.y, accuracy: 0.5,
                       "Panel should be vertically centered on the AX point")
    }

    func testClampsToScreenBounds() {
        let primary = NSScreen.screens.first?.frame ?? .zero
        guard primary != .zero else {
            XCTFail("No primary screen for clamp test")
            return
        }

        // AX point far above/left of the primary screen's top-left corner.
        let topLeft = CursorFeedbackOverlay.cocoaAnchorPoint(
            for: CGPoint(x: -200, y: -200), panelSize: panelSize
        )
        XCTAssertGreaterThanOrEqual(topLeft.x, primary.minX, "Panel x must stay inside screen")
        XCTAssertGreaterThanOrEqual(topLeft.y, primary.minY, "Panel y must stay inside screen")

        // AX point far below/right of the primary screen's bottom-right corner.
        let bottomRight = CursorFeedbackOverlay.cocoaAnchorPoint(
            for: CGPoint(x: primary.width + 200, y: primary.height + 200), panelSize: panelSize
        )
        XCTAssertLessThanOrEqual(bottomRight.x + panelSize.width, primary.maxX + 0.5,
                                 "Panel must not overflow right edge")
        XCTAssertLessThanOrEqual(bottomRight.y + panelSize.height, primary.maxY + 0.5,
                                 "Panel must not overflow bottom edge")
    }
}
