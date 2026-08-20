import Cocoa

enum ResolvedGestureAction {
    case execute(feedbackMode: CursorFeedbackOverlay.Mode, haptic: HapticType?, action: () -> Void)
    case none
}

/// Routes gesture recognition results to their corresponding actions
/// based on the target element under cursor.
final class GestureActionRouter {
    private let actions: ActionRegistry

    init(actions: ActionRegistry = ActionRegistry()) {
        self.actions = actions
    }

    func routeGesture(
        _ result: GestureResult,
        at point: CGPoint,
        target: TargetResolution,
        service: AccessibilityServiceProtocol,
        volumeService: MountedVolumeServiceProtocol? = nil,
        isAutoEjectEnabled: Bool = true,
        activateApp: @escaping (CGPoint) -> Void
    ) -> ResolvedGestureAction {
        switch result {
        case .pinchIn:
            switch target {
            case .dock(let app):
                return .execute(feedbackMode: .close, haptic: .pinchIn) { [weak self] in
                    self?.actions.closeAppAction.perform(app: app, service: service)
                }
            case .window(let window):
                if isAutoEjectEnabled,
                   let volumeService = volumeService,
                   let targetApp = service.getAppFromElement(window),
                   targetApp.bundleIdentifier == "com.apple.finder",
                   let mountPath = volumeService.ejectableVolumePath(
                       forDocumentPath: service.getDocumentPath(for: window),
                       windowTitle: service.getWindowTitle(for: window)
                   ) {
                    return .execute(feedbackMode: .eject, haptic: .pinchIn) { [weak self] in
                        self?.actions.ejectVolumeAction.perform(
                            window: window,
                            mountPath: mountPath,
                            service: service,
                            volumeService: volumeService
                        )
                    }
                }
                return .execute(feedbackMode: .close, haptic: .pinchIn) { [weak self] in
                    self?.actions.closeAction.perform(at: point, service: service)
                }
            case .none:
                return .none
            }

        case .cmdPinchIn:
            switch target {
            case .dock(let app):
                return .execute(feedbackMode: .quit, haptic: .pinchIn) { [weak self] in
                    self?.actions.forceQuitAppAction.perform(app: app)
                }
            case .window(let window):
                if isAutoEjectEnabled,
                   let volumeService = volumeService,
                   let targetApp = service.getAppFromElement(window),
                   targetApp.bundleIdentifier == "com.apple.finder",
                   let mountPath = volumeService.ejectableVolumePath(
                       forDocumentPath: service.getDocumentPath(for: window),
                       windowTitle: service.getWindowTitle(for: window)
                   ) {
                    return .execute(feedbackMode: .eject, haptic: .pinchIn) { [weak self] in
                        self?.actions.ejectVolumeAction.perform(
                            window: window,
                            mountPath: mountPath,
                            service: service,
                            volumeService: volumeService
                        )
                    }
                }
                return .execute(feedbackMode: .quit, haptic: .pinchIn) { [weak self] in
                    self?.actions.forceQuitAction.perform(at: point, service: service)
                }
            case .none:
                return .none
            }

        case .swipeLeft:
            switch target {
            case .dock(let app):
                return .execute(feedbackMode: .closeTab, haptic: .swipeLeft) { [weak self] in
                    activateApp(point)
                    self?.actions.closeTabAppAction.perform(app: app, service: service)
                }
            case .window(let window):
                if isAutoEjectEnabled,
                   let volumeService = volumeService,
                   let targetApp = service.getAppFromElement(window),
                   targetApp.bundleIdentifier == "com.apple.finder",
                   let mountPath = volumeService.ejectableVolumePath(
                       forDocumentPath: service.getDocumentPath(for: window),
                       windowTitle: service.getWindowTitle(for: window)
                   ) {
                    return .execute(feedbackMode: .eject, haptic: .swipeLeft) { [weak self] in
                        self?.actions.ejectVolumeAction.perform(
                            window: window,
                            mountPath: mountPath,
                            service: service,
                            volumeService: volumeService
                        )
                    }
                }
                return .execute(feedbackMode: .closeTab, haptic: .swipeLeft) { [weak self] in
                    activateApp(point)
                    self?.actions.closeTabAction.perform(at: point, service: service)
                }
            case .none:
                return .none
            }

        case .cmdSwipeLeft:
            switch target {
            case .window, .dock:
                return .execute(feedbackMode: .closeAllTabs, haptic: .swipeLeft) { [weak self] in
                    self?.actions.closeAllTabsAction.perform(at: point, service: service)
                }
            case .none:
                return .none
            }

        case .swipeRight:
            switch target {
            case .dock(let app):
                return .execute(feedbackMode: .reopenTab, haptic: .swipeRight) { [weak self] in
                    self?.actions.reopenTabAppAction.perform(app: app)
                }
            case .window:
                return .execute(feedbackMode: .reopenTab, haptic: .swipeRight) { [weak self] in
                    self?.actions.reopenTabAction.perform(at: point, service: service)
                }
            case .none:
                return .none
            }

        case .cmdSwipeRight:
            switch target {
            case .window, .dock:
                return .execute(feedbackMode: .newWindow, haptic: .swipeRight) { [weak self] in
                    self?.actions.newWindowAction.perform(at: point, service: service)
                }
            case .none:
                return .none
            }

        case .swipeDown:
            switch target {
            case .window:
                return .execute(feedbackMode: .maximize, haptic: .swipeDown) { [weak self] in
                    self?.actions.fillScreenAction.perform(at: point, service: service)
                }
            case .dock, .none:
                return .none
            }

        case .cmdSwipeDown:
            switch target {
            case .window:
                return .execute(feedbackMode: .maximize, haptic: .swipeDown) { [weak self] in
                    self?.actions.makeLargerAction.perform(at: point, service: service)
                }
            case .dock, .none:
                return .none
            }

        case .swipeUp:
            switch target {
            case .dock(let app):
                return .execute(feedbackMode: .minimize, haptic: .swipeUp) { [weak self] in
                    self?.actions.minimizeAppAction.perform(app: app, service: service)
                }
            case .window:
                return .execute(feedbackMode: .minimize, haptic: .swipeUp) { [weak self] in
                    self?.actions.minimizeAction.perform(at: point, service: service)
                }
            case .none:
                return .none
            }

        case .cmdSwipeUp:
            switch target {
            case .dock(let app):
                return .execute(feedbackMode: .hide, haptic: .swipeUp) { [weak self] in
                    guard self != nil else { return }
                    app.hide()
                }
            case .window:
                return .execute(feedbackMode: .hide, haptic: .swipeUp) { [weak self] in
                    self?.actions.hideAction.perform(at: point, service: service)
                }
            case .none:
                return .none
            }

        case .twoFingerDoubleTap:
            switch target {
            case .window:
                return .execute(feedbackMode: .reasonable, haptic: .twoFingerDoubleTap) { [weak self] in
                    self?.actions.reasonableSizeAction.perform(at: point, service: service)
                }
            case .dock, .none:
                return .none
            }

        case .cmdTwoFingerDoubleTap:
            switch target {
            case .window:
                return .execute(feedbackMode: .almost, haptic: .cmdTwoFingerDoubleTap) { [weak self] in
                    self?.actions.almostMaximizeAction.perform(at: point, service: service)
                }
            case .dock, .none:
                return .none
            }
        }
    }
}
