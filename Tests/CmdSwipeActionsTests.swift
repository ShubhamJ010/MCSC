import Foundation
import Cocoa
import XCTest

final class CmdSwipeActionsTests: XCTestCase {
    private var mockService: MockAccessibilityService!

    override func setUp() {
        super.setUp()
        mockService = MockAccessibilityService()
    }

    override func tearDown() {
        mockService = nil
        super.tearDown()
    }

    func testCloseAllTabsActionWithNilElementDoesNotCrash() {
        mockService.mockElement = nil
        let action = CloseAllTabsAction()
        let point = CGPoint(x: 120, y: 200)
        action.perform(at: point, service: mockService)
        XCTAssertEqual(mockService.getElementCalledWith, point)
    }

    func testNewWindowActionWithNilElementDoesNotCrash() {
        mockService.mockElement = nil
        let action = NewWindowAction()
        let point = CGPoint(x: 80, y: 90)
        action.perform(at: point, service: mockService)
        XCTAssertEqual(mockService.getElementCalledWith, point)
    }
}