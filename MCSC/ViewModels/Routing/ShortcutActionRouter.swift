import Cocoa

enum TargetResolution {
    case dock(NSRunningApplication)
    case window(AXUIElement)
    case none
}

enum ResolvedShortcutAction {
    case consumeAndExecute(feedbackMode: CursorFeedbackOverlay.Mode, action: () -> Void)
    case ignore
}

/// Routes keyboard shortcut events (e.g. Cmd+W, Cmd+Q, Cmd+M, Cmd+H) to their
/// corresponding actions based on current configuration and target resolution.
final class ShortcutActionRouter {
    static let kKeyW: Int64 = 13
    static let kKeyQ: Int64 = 12
    static let kKeyM: Int64 = 46
    static let kKeyH: Int64 = 4
    static let kKeyF: Int64 = 3
    static let kKeySpace: Int64 = 49

    private let actions: ActionRegistry

    init(actions: ActionRegistry = ActionRegistry()) {
        self.actions = actions
    }

    func routeShortcut(
        keyCode: Int64,
        flags: CGEventFlags,
        location: CGPoint,
        config: ShortcutConfiguration,
        isMissionControlActive: Bool,
        target: TargetResolution,
        service: AccessibilityServiceProtocol,
        volumeService: MountedVolumeServiceProtocol? = nil,
        activateApp: @escaping (CGPoint) -> Void
    ) -> ResolvedShortcutAction {
        let isCmdPressed = flags.contains(.maskCommand)
        let isShiftPressed = flags.contains(.maskShift)
        let isControlPressed = flags.contains(.maskControl)
        let isOptionPressed = flags.contains(.maskAlternate)

        guard isCmdPressed && !isShiftPressed && !isControlPressed && !isOptionPressed else {
            return .ignore
        }

        guard isMissionControlActive else {
            return .ignore
        }

        let app: NSRunningApplication?
        switch target {
        case .dock(let resolvedApp):
            app = resolvedApp
        case .window, .none:
            app = nil
        }

        // Mounted volume auto-eject enhancement:
        // If Cmd+W or Cmd+Q is triggered on a Finder window showing an ejectable/mounted volume,
        // close the window and eject the volume with eject.circle.fill feedback.
        if config.isAutoEjectEnabled,
           case .window(let window) = target,
           let volumeService = volumeService,
           (keyCode == Self.kKeyW && config.isCmdWEnabled) || (keyCode == Self.kKeyQ && config.isCmdQEnabled),
           let targetApp = service.getAppFromElement(window),
           targetApp.bundleIdentifier == "com.apple.finder",
           let mountPath = volumeService.ejectableVolumePath(
               forDocumentPath: service.getDocumentPath(for: window),
               windowTitle: service.getWindowTitle(for: window)
           ) {
            return .consumeAndExecute(feedbackMode: .eject) { [weak self] in
                guard let self = self else { return }
                self.actions.ejectVolumeAction.perform(
                    window: window,
                    mountPath: mountPath,
                    service: service,
                    volumeService: volumeService
                )
            }
        }

        if keyCode == Self.kKeyW && config.isCmdWEnabled {
            return .consumeAndExecute(feedbackMode: .close) { [weak self] in
                guard let self = self else { return }
                activateApp(location)
                if let app = app {
                    self.actions.closeTabAppAction.perform(app: app, service: service)
                } else {
                    self.actions.closeTabAction.perform(at: location, service: service)
                }
            }
        } else if keyCode == Self.kKeyQ && config.isCmdQEnabled {
            return .consumeAndExecute(feedbackMode: .quit) { [weak self] in
                guard let self = self else { return }
                if let app = app {
                    self.actions.forceQuitAppAction.perform(app: app)
                } else {
                    self.actions.forceQuitAction.perform(at: location, service: service)
                }
            }
        } else if keyCode == Self.kKeyM && config.isCmdMEnabled {
            return .consumeAndExecute(feedbackMode: .minimize) { [weak self] in
                guard let self = self else { return }
                if let app = app {
                    self.actions.minimizeAppAction.perform(app: app, service: service)
                } else {
                    self.actions.minimizeAction.perform(at: location, service: service)
                }
            }
        } else if keyCode == Self.kKeyH && config.isCmdHEnabled {
            return .consumeAndExecute(feedbackMode: .hide) { [weak self] in
                guard let self = self else { return }
                if let app = app {
                    app.hide()
                } else {
                    self.actions.hideAction.perform(at: location, service: service)
                }
            }
        }

        return .ignore
    }
}
