import XCTest
import Foundation

final class RouterTests: XCTestCase {
    private var mockService: MockAccessibilityService!
    private var actionRegistry: ActionRegistry!
    private var shortcutRouter: ShortcutActionRouter!
    private var gestureRouter: GestureActionRouter!

    override func setUp() {
        super.setUp()
        mockService = MockAccessibilityService()
        mockService.mockElement = AXUIElementCreateSystemWide()
        actionRegistry = ActionRegistry()
        shortcutRouter = ShortcutActionRouter(actions: actionRegistry)
        gestureRouter = GestureActionRouter(actions: actionRegistry)
    }

    func testShortcutRouterCmdWProducesCloseActionWhenEnabled() {
        let config = ShortcutConfiguration()
        let result = shortcutRouter.routeShortcut(
            keyCode: ShortcutActionRouter.kKeyW,
            flags: .maskCommand,
            location: CGPoint(x: 100, y: 100),
            config: config,
            isMissionControlActive: true,
            target: .none,
            service: mockService,
            activateApp: { _ in }
        )

        switch result {
        case .consumeAndExecute(let feedbackMode, _):
            XCTAssertEqual(feedbackMode, .close)
        case .ignore:
            XCTFail("Expected shortcut to be consumed and executed")
        }
    }

    func testShortcutRouterIgnoresWhenMissionControlInactive() {
        let config = ShortcutConfiguration()
        let result = shortcutRouter.routeShortcut(
            keyCode: ShortcutActionRouter.kKeyW,
            flags: .maskCommand,
            location: CGPoint(x: 100, y: 100),
            config: config,
            isMissionControlActive: false,
            target: .none,
            service: mockService,
            activateApp: { _ in }
        )

        switch result {
        case .consumeAndExecute:
            XCTFail("Should ignore when Mission Control is inactive")
        case .ignore:
            break
        }
    }

    func testShortcutRouterIgnoresWhenDisabled() {
        var config = ShortcutConfiguration()
        config.isCmdWEnabled = false

        let result = shortcutRouter.routeShortcut(
            keyCode: ShortcutActionRouter.kKeyW,
            flags: .maskCommand,
            location: CGPoint(x: 100, y: 100),
            config: config,
            isMissionControlActive: true,
            target: .none,
            service: mockService,
            activateApp: { _ in }
        )

        switch result {
        case .consumeAndExecute:
            XCTFail("Should ignore disabled shortcut")
        case .ignore:
            break
        }
    }

    func testGestureRouterPinchInRoutesToClose() {
        let result = gestureRouter.routeGesture(
            .pinchIn(atNormalized: (0.5, 0.5)),
            at: CGPoint(x: 200, y: 200),
            target: .window(mockService.mockElement!),
            service: mockService,
            activateApp: { _ in }
        )

        switch result {
        case .execute(let feedbackMode, let haptic, _):
            XCTAssertEqual(feedbackMode, .close)
            XCTAssertEqual(haptic, .pinchIn)
        case .none:
            XCTFail("Expected gesture to route to action")
        }
    }

    func testGestureRouterCmdPinchInRoutesToQuit() {
        let result = gestureRouter.routeGesture(
            .cmdPinchIn(atNormalized: (0.5, 0.5)),
            at: CGPoint(x: 200, y: 200),
            target: .window(mockService.mockElement!),
            service: mockService,
            activateApp: { _ in }
        )

        switch result {
        case .execute(let feedbackMode, let haptic, _):
            XCTAssertEqual(feedbackMode, .quit)
            XCTAssertEqual(haptic, .pinchIn)
        case .none:
            XCTFail("Expected gesture to route to action")
        }
    }

    func testGestureRouterDoubleTapRoutesToReasonableSize() {
        let result = gestureRouter.routeGesture(
            .twoFingerDoubleTap,
            at: CGPoint(x: 200, y: 200),
            target: .window(mockService.mockElement!),
            service: mockService,
            activateApp: { _ in }
        )

        switch result {
        case .execute(let feedbackMode, let haptic, _):
            XCTAssertEqual(feedbackMode, .reasonable)
            XCTAssertEqual(haptic, .twoFingerDoubleTap)
        case .none:
            XCTFail("Expected gesture to route to action")
        }
    }
}
