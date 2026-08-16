import Foundation
import Cocoa
import XCTest

final class MoveWindowToSpaceActionTests: XCTestCase {
    private var mockService: MockAccessibilityService!

    override func setUp() {
        super.setUp()
        mockService = MockAccessibilityService()
    }

    override func tearDown() {
        mockService = nil
        super.tearDown()
    }

    func testSpaceDirectionEnum() {
        let prev = SpaceDirection.previous
        let next = SpaceDirection.next
        XCTAssertNotEqual(String(describing: prev), String(describing: next))
    }

    func testMoveWindowToPreviousSpaceActionInstantiation() {
        let action = MoveWindowToSpaceAction(direction: .previous)
        XCTAssertEqual(action.direction, .previous)
    }

    func testMoveWindowToNextSpaceActionInstantiation() {
        let action = MoveWindowToSpaceAction(direction: .next)
        XCTAssertEqual(action.direction, .next)
    }

    func testPerformWithNilElementDoesNotCrash() {
        mockService.mockElement = nil
        let action = MoveWindowToSpaceAction(direction: .next)
        let testPoint = CGPoint(x: 250, y: 350)
        action.perform(at: testPoint, service: mockService)
        XCTAssertEqual(mockService.getElementCalledWith, testPoint)
    }

    func testPerformWithNilWindowDoesNotCrash() {
        // Create an AXUIElement for testing
        let element = AXUIElementCreateSystemWide()
        mockService.mockElement = element
        mockService.mockWindow = nil

        let action = MoveWindowToSpaceAction(direction: .previous)
        let testPoint = CGPoint(x: 100, y: 100)
        action.perform(at: testPoint, service: mockService)
        XCTAssertEqual(mockService.getElementCalledWith, testPoint)
    }

    func testPerformResolvesWindowAndElement() {
        let element = AXUIElementCreateSystemWide()
        mockService.mockElement = element
        mockService.mockWindow = element

        let action = MoveWindowToSpaceAction(direction: .next)
        let testPoint = CGPoint(x: 500, y: 400)
        action.perform(at: testPoint, service: mockService)

        XCTAssertEqual(mockService.getElementCalledWith, testPoint)
    }
}
