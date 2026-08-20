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

    func testShortcutRouterCmdWRoutesToEjectWhenFinderMountedVolume() {
        let mockVolumeService = MockMountedVolumeService()
        mockVolumeService.mockEjectablePath = "/Volumes/AppInstaller"

        let finderApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
        mockService.mockApp = finderApp
        mockService.mockDocumentPath = "/Volumes/AppInstaller"

        let config = ShortcutConfiguration()
        let result = shortcutRouter.routeShortcut(
            keyCode: ShortcutActionRouter.kKeyW,
            flags: .maskCommand,
            location: CGPoint(x: 100, y: 100),
            config: config,
            isMissionControlActive: true,
            target: .window(mockService.mockElement!),
            service: mockService,
            volumeService: mockVolumeService,
            activateApp: { _ in }
        )

        switch result {
        case .consumeAndExecute(let feedbackMode, let action):
            XCTAssertEqual(feedbackMode, .eject)
            action()
            XCTAssertEqual(mockVolumeService.ejectVolumeCalledWith, "/Volumes/AppInstaller")
        case .ignore:
            XCTFail("Expected shortcut to route to eject action")
        }
    }

    func testShortcutRouterCmdQRoutesToEjectWhenFinderMountedVolume() {
        let mockVolumeService = MockMountedVolumeService()
        mockVolumeService.mockEjectablePath = "/Volumes/AppInstaller"

        let finderApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
        mockService.mockApp = finderApp
        mockService.mockDocumentPath = "/Volumes/AppInstaller"

        let config = ShortcutConfiguration()
        let result = shortcutRouter.routeShortcut(
            keyCode: ShortcutActionRouter.kKeyQ,
            flags: .maskCommand,
            location: CGPoint(x: 100, y: 100),
            config: config,
            isMissionControlActive: true,
            target: .window(mockService.mockElement!),
            service: mockService,
            volumeService: mockVolumeService,
            activateApp: { _ in }
        )

        switch result {
        case .consumeAndExecute(let feedbackMode, let action):
            XCTAssertEqual(feedbackMode, .eject)
            action()
            XCTAssertEqual(mockVolumeService.ejectVolumeCalledWith, "/Volumes/AppInstaller")
        case .ignore:
            XCTFail("Expected Cmd+Q on mounted volume to route to eject action")
        }
    }

    func testShortcutRouterDoesNotEjectWhenAutoEjectDisabled() {
        let mockVolumeService = MockMountedVolumeService()
        mockVolumeService.mockEjectablePath = "/Volumes/AppInstaller"

        let finderApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
        mockService.mockApp = finderApp
        mockService.mockDocumentPath = "/Volumes/AppInstaller"

        var config = ShortcutConfiguration()
        config.isAutoEjectEnabled = false

        let result = shortcutRouter.routeShortcut(
            keyCode: ShortcutActionRouter.kKeyW,
            flags: .maskCommand,
            location: CGPoint(x: 100, y: 100),
            config: config,
            isMissionControlActive: true,
            target: .window(mockService.mockElement!),
            service: mockService,
            volumeService: mockVolumeService,
            activateApp: { _ in }
        )

        switch result {
        case .consumeAndExecute(let feedbackMode, _):
            XCTAssertEqual(feedbackMode, .close)
        case .ignore:
            XCTFail("Expected standard close action when auto-eject disabled")
        }
    }

    func testGestureRouterPinchInRoutesToEjectWhenFinderMountedVolume() {
        let mockVolumeService = MockMountedVolumeService()
        mockVolumeService.mockEjectablePath = "/Volumes/AppInstaller"

        let finderApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
        mockService.mockApp = finderApp
        mockService.mockDocumentPath = "/Volumes/AppInstaller"

        let result = gestureRouter.routeGesture(
            .pinchIn(atNormalized: (0.5, 0.5)),
            at: CGPoint(x: 200, y: 200),
            target: .window(mockService.mockElement!),
            service: mockService,
            volumeService: mockVolumeService,
            activateApp: { _ in }
        )

        switch result {
        case .execute(let feedbackMode, let haptic, let action):
            XCTAssertEqual(feedbackMode, .eject)
            XCTAssertEqual(haptic, .pinchIn)
            action()
            XCTAssertEqual(mockVolumeService.ejectVolumeCalledWith, "/Volumes/AppInstaller")
        case .none:
            XCTFail("Expected gesture to route to eject action")
        }
    }

    func testGestureRouterDoesNotEjectWhenAutoEjectDisabled() {
        let mockVolumeService = MockMountedVolumeService()
        mockVolumeService.mockEjectablePath = "/Volumes/AppInstaller"

        let finderApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
        mockService.mockApp = finderApp
        mockService.mockDocumentPath = "/Volumes/AppInstaller"

        let result = gestureRouter.routeGesture(
            .pinchIn(atNormalized: (0.5, 0.5)),
            at: CGPoint(x: 200, y: 200),
            target: .window(mockService.mockElement!),
            service: mockService,
            volumeService: mockVolumeService,
            isAutoEjectEnabled: false,
            activateApp: { _ in }
        )

        switch result {
        case .execute(let feedbackMode, let haptic, _):
            XCTAssertEqual(feedbackMode, .close)
            XCTAssertEqual(haptic, .pinchIn)
            XCTAssertNil(mockVolumeService.ejectVolumeCalledWith)
        case .none:
            XCTFail("Expected gesture to route to standard close action")
        }
    }
}

final class MockMountedVolumeService: MountedVolumeServiceProtocol {
    var mockEjectablePath: String?
    var ejectVolumeCalledWith: String?
    var ejectVolumeSuccess: Bool = true

    func ejectableVolumePath(forDocumentPath path: String?, windowTitle: String?) -> String? {
        return mockEjectablePath
    }

    func ejectVolume(at mountPath: String, completion: @escaping (Bool) -> Void) {
        ejectVolumeCalledWith = mountPath
        completion(ejectVolumeSuccess)
    }
}
