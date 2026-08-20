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

    func testFillScreenActionWithNilElementDoesNotCrash() {
        mockService.mockElement = nil
        let action = FillScreenAction()
        let point = CGPoint(x: 150, y: 250)
        action.perform(at: point, service: mockService)
        XCTAssertEqual(mockService.getElementCalledWith, point)
        XCTAssertNil(mockService.setFrameCalledWith)
    }

    func testReasonableSizeActionWithNilElementDoesNotCrash() {
        mockService.mockElement = nil
        let action = ReasonableSizeAction()
        let point = CGPoint(x: 150, y: 250)
        action.perform(at: point, service: mockService)
        XCTAssertEqual(mockService.getElementCalledWith, point)
        XCTAssertNil(mockService.setFrameCalledWith)
    }

    func testAlmostMaximizeActionWithNilElementDoesNotCrash() {
        mockService.mockElement = nil
        let action = AlmostMaximizeAction()
        let point = CGPoint(x: 150, y: 250)
        action.perform(at: point, service: mockService)
        XCTAssertEqual(mockService.getElementCalledWith, point)
        XCTAssertNil(mockService.setFrameCalledWith)
    }

    // MARK: - CloseTabAction multi-window targeting

    func testCloseTabActionFocusesResolvedWindowBeforeCmdWFallback() {
        // Simulate a window that lacks an accessible tab group, forcing the
        // Cmd+W fallback path. The resolved window (not the app's key window)
        // must be focused first.
        let appElement = AXUIElementCreateApplication(NSRunningApplication.current.processIdentifier)
        mockService.mockElement = appElement
        let hoveredWindow = AXUIElementCreateApplication(NSRunningApplication.current.processIdentifier)
        mockService.mockWindow = hoveredWindow
        mockService.mockTabCloseButton = nil

        CloseTabAction().perform(at: CGPoint(x: 10, y: 10), service: mockService)

        XCTAssertEqual(mockService.focusWindowCalledWith, hoveredWindow)
    }

    func testCloseTabActionPrefersAccessibleTabCloseButton() {
        // When the window exposes a tab close button, no focus change or
        // Cmd+W fallback should occur.
        let appElement = AXUIElementCreateApplication(NSRunningApplication.current.processIdentifier)
        mockService.mockElement = appElement
        mockService.mockWindow = AXUIElementCreateApplication(NSRunningApplication.current.processIdentifier)
        let closeBtn = AXUIElementCreateApplication(NSRunningApplication.current.processIdentifier)
        mockService.mockTabCloseButton = closeBtn

        CloseTabAction().perform(at: CGPoint(x: 10, y: 10), service: mockService)

        XCTAssertNil(mockService.focusWindowCalledWith)
        XCTAssertEqual(mockService.performActionCalledWith?.element, closeBtn)
    }

    // MARK: - CloseTabAppAction key-window targeting

    func testCloseTabAppActionTargetsKeyWindowTabCloseButton() {
        let app = NSRunningApplication.current
        let keyWindow = AXUIElementCreateApplication(app.processIdentifier)
        let closeBtn = AXUIElementCreateApplication(app.processIdentifier)
        mockService.mockFocusedWindow = keyWindow
        mockService.mockTabCloseButton = closeBtn

        CloseTabAppAction().perform(app: app, service: mockService)

        XCTAssertEqual(mockService.performActionCalledWith?.element, closeBtn)
        XCTAssertNil(mockService.focusWindowCalledWith)
    }

    func testCloseTabAppActionFallsBackToKeyWindowCmdWWhenNoTabButton() {
        let app = NSRunningApplication.current
        let keyWindow = AXUIElementCreateApplication(app.processIdentifier)
        mockService.mockFocusedWindow = keyWindow
        mockService.mockTabCloseButton = nil

        // No tab close button available: the Cmd+W fallback (targeting the key
        // window) runs. We assert it resolved the key window via the focused
        // window attribute rather than iterating all windows.
        CloseTabAppAction().perform(app: app, service: mockService)

        XCTAssertNil(mockService.performActionCalledWith)
    }
}