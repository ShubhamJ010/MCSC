import Cocoa

/// Central coordinator of the MVVM layer.
///
/// `ShortcutViewModel` wires together the low-level services (`EventTapServiceProtocol`,
/// `MultitouchService`, `AccessibilityServiceProtocol`, `MissionControlServiceProtocol`) and
/// delegates shortcut and gesture routing to `ShortcutActionRouter` and `GestureActionRouter`.
///
/// - Threading: callbacks from the event taps are delivered on the main thread;
///   gesture frames arrive via `main.async`, so all state access here is main-thread-confined.
/// - Retain-cycle safety: every closure handed to a service captures `self`
///   weakly (`[weak self]`), and heavy blocking AX actions are deferred one
///   run-loop turn so the UI (feedback overlay, haptics) can commit first.
final class ShortcutViewModel {
    private let eventTapService: EventTapServiceProtocol
    private let accessibilityService: AccessibilityServiceProtocol
    private let missionControlService: MissionControlServiceProtocol
    private let launchAtLoginService: LaunchAtLoginService

    private lazy var multitouchService = MultitouchService()
    private lazy var gestureEngine = GestureEngine()
    private lazy var hoverService: MissionControlHoverServiceProtocol = {
        MissionControlHoverService(
            accessibilityService: accessibilityService,
            isMissionControlActiveProvider: { [weak self] in
                self?.missionControlService.isMissionControlActive ?? false
            },
            isKeyboardNavigationEnabledProvider: { [weak self] in
                self?.config.isKeyboardNavigationEnabled ?? true
            }
        )
    }()

    private lazy var cursorFeedback = CursorFeedbackOverlay()
    private lazy var volumeService: MountedVolumeServiceProtocol = MountedVolumeService()
    /// Lazily-created event tap that swallows App Exposé / context-menu
    /// triggers (smartMagnify, synthesized clicks) while gestures or
    /// double-taps are aimed at Dock icons outside Mission Control.
    /// Providers use `[weak self]` so the suppressor never keeps the VM alive.
    private lazy var dockSuppressor: DockInteractionSuppressorProtocol = {
        let suppressor = DockInteractionSuppressor()
        suppressor.isDockHoveredProvider = { [weak self] point in
            guard let self = self else { return false }
            return self.accessibilityService.isDockRegion(at: point)
        }
        suppressor.isEnabledProvider = { [weak self] in
            guard let self = self else { return false }
            return !self.missionControlService.isMissionControlActive && self.config.isDockActionsOutsideMCEnabled
        }
        return suppressor
    }()

    /// Desktop-navigation actions need to know whether Mission Control is open
    /// so they can dismiss it before dragging a window across Spaces. Provider
    /// uses `[weak self]` so the registry never keeps the VM alive.
    private lazy var actionRegistry = ActionRegistry(isMissionControlActiveProvider: { [weak self] in
        guard let self = self else { return false }
        return self.missionControlService.isMissionControlActive
    })
    private lazy var shortcutRouter = ShortcutActionRouter(actions: actionRegistry)
    private lazy var gestureRouter = GestureActionRouter(actions: actionRegistry)

    var config = ShortcutConfiguration()

    // Forwarding properties for configuration (keeps AppDelegate API unchanged)
    var isCmdWEnabled: Bool { get { config.isCmdWEnabled } set { config.isCmdWEnabled = newValue } }
    var isCmdQEnabled: Bool { get { config.isCmdQEnabled } set { config.isCmdQEnabled = newValue } }
    var isCmdMEnabled: Bool { get { config.isCmdMEnabled } set { config.isCmdMEnabled = newValue } }
    var isCmdHEnabled: Bool { get { config.isCmdHEnabled } set { config.isCmdHEnabled = newValue } }
    var isCmdFEnabled: Bool { get { config.isCmdFEnabled } set { config.isCmdFEnabled = newValue } }
    var isCmdSpaceEnabled: Bool { get { config.isCmdSpaceEnabled } set { config.isCmdSpaceEnabled = newValue } }
    var isCmdTEnabled: Bool { get { config.isCmdTEnabled } set { config.isCmdTEnabled = newValue } }
    var isCmdNEnabled: Bool { get { config.isCmdNEnabled } set { config.isCmdNEnabled = newValue } }
    var isCmdShiftWEnabled: Bool { get { config.isCmdShiftWEnabled } set { config.isCmdShiftWEnabled = newValue } }
    var isCmdShiftTEnabled: Bool { get { config.isCmdShiftTEnabled } set { config.isCmdShiftTEnabled = newValue } }
    var isAutoEjectEnabled: Bool { get { config.isAutoEjectEnabled } set { config.isAutoEjectEnabled = newValue } }
    var isDockActionsOutsideMCEnabled: Bool { get { config.isDockActionsOutsideMCEnabled } set { config.isDockActionsOutsideMCEnabled = newValue } }
    var isGesturesEnabled: Bool { get { config.isGesturesEnabled } set { config.isGesturesEnabled = newValue } }
    var isPinchInEnabled: Bool { get { config.isPinchInEnabled } set { config.isPinchInEnabled = newValue } }
    var isPinchOutEnabled: Bool { get { config.isPinchOutEnabled } set { config.isPinchOutEnabled = newValue } }
    var isSwipeLeftEnabled: Bool { get { config.isSwipeLeftEnabled } set { config.isSwipeLeftEnabled = newValue } }
    var isSwipeRightEnabled: Bool { get { config.isSwipeRightEnabled } set { config.isSwipeRightEnabled = newValue } }
    var isSwipeDownEnabled: Bool { get { config.isSwipeDownEnabled } set { config.isSwipeDownEnabled = newValue } }
    var isSwipeUpEnabled: Bool { get { config.isSwipeUpEnabled } set { config.isSwipeUpEnabled = newValue } }
    var isTwoFingerDoubleTapEnabled: Bool { get { config.isTwoFingerDoubleTapEnabled } set { config.isTwoFingerDoubleTapEnabled = newValue } }
    var isKeyboardNavigationEnabled: Bool { get { config.isKeyboardNavigationEnabled } set { config.isKeyboardNavigationEnabled = newValue } }

    // Gesture action mappings
    func gestureAction(for kind: GestureKind, isCmd: Bool) -> GestureAction { config.action(for: kind, isCmd: isCmd) }
    func setGestureAction(_ action: GestureAction, for kind: GestureKind, isCmd: Bool) { config.setAction(action, for: kind, isCmd: isCmd) }
    func resetGestureMappings() { config.resetGestureMappings() }

    var isHoverCloseButtonEnabled: Bool {
        get { hoverService.isEnabled }
        set { hoverService.isEnabled = newValue }
    }

    /// Prevents gestures from firing right after Mission Control opens via 3-finger swipe.
    private var isCoolingDown = false

    var isLaunchAtLoginEnabled: Bool {
        return launchAtLoginService.isEnabled
    }

    init(eventTapService: EventTapServiceProtocol,
         accessibilityService: AccessibilityServiceProtocol,
         missionControlService: MissionControlServiceProtocol,
         launchAtLoginService: LaunchAtLoginService) {
        self.eventTapService = eventTapService
        self.accessibilityService = accessibilityService
        self.missionControlService = missionControlService
        self.launchAtLoginService = launchAtLoginService

        setupCallbacks()

        // Cooldown after Mission Control activates to avoid false gesture detection
        missionControlService.onActivated = { [weak self] in
            self?.isCoolingDown = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isCoolingDown = false
            }
        }
    }

    func toggleLaunchAtLogin() {
        launchAtLoginService.toggle()
    }

    private func setupCallbacks() {
        let cmdHeldProvider: () -> Bool = {
            NSEvent.modifierFlags.contains(.command)
        }

        eventTapService.onShortcutDetected = { [weak self] keyCode, flags, location in
            guard let self = self else { return false }

            let isCmdPressed = flags.contains(.maskCommand)
            let isShiftPressed = flags.contains(.maskShift)
            let isControlPressed = flags.contains(.maskControl)
            let isOptionPressed = flags.contains(.maskAlternate)

            if isCmdPressed && !isShiftPressed && !isControlPressed && !isOptionPressed {
                if keyCode == ShortcutActionRouter.kKeySpace && self.config.isCmdSpaceEnabled && !self.missionControlService.isSimulating {
                    if self.missionControlService.checkMissionControlActive() {
                        self.missionControlService.executeFixSequence()
                        return true
                    }
                }
            }

            let effectiveLocation = (location == .zero) ? self.currentAXMouseLocation() : location
            let target = self.resolveTarget(at: effectiveLocation)
            let resolution = self.shortcutRouter.routeShortcut(
                keyCode: keyCode,
                flags: flags,
                location: effectiveLocation,
                config: self.config,
                isMissionControlActive: self.missionControlService.isMissionControlActive,
                target: target,
                service: self.accessibilityService,
                volumeService: self.volumeService,
                activateApp: { [weak self] loc in self?.activateAppIfNeeded(at: loc) }
            )

            switch resolution {
            case .consumeAndExecute(let feedbackMode, let action):
                self.executeFeedbackThenAction(at: effectiveLocation, feedbackMode: feedbackMode, haptic: nil, action: action)
                return true
            case .ignore:
                return false
            }
        }

        // Register gesture recognizers
        let twoFingerTapRecognizer = TwoFingerDoubleTapRecognizer()
        twoFingerTapRecognizer.isCmdHeld = cmdHeldProvider
        twoFingerTapRecognizer.isEnabled = { [weak self] in self?.config.isTwoFingerDoubleTapEnabled ?? false }
        gestureEngine.register(twoFingerTapRecognizer)

        let pinchInRecognizer = PinchInRecognizer()
        pinchInRecognizer.isCmdHeld = cmdHeldProvider
        pinchInRecognizer.isEnabled = { [weak self] in self?.config.isPinchInEnabled ?? false }
        gestureEngine.register(pinchInRecognizer)

        let pinchOutRecognizer = PinchOutRecognizer()
        pinchOutRecognizer.isCmdHeld = cmdHeldProvider
        pinchOutRecognizer.isEnabled = { [weak self] in self?.config.isPinchOutEnabled ?? false }
        gestureEngine.register(pinchOutRecognizer)

        let swipeLeftRecognizer = TwoFingerSwipeLeftRecognizer()
        swipeLeftRecognizer.isCmdHeld = cmdHeldProvider
        swipeLeftRecognizer.isEnabled = { [weak self] in self?.config.isSwipeLeftEnabled ?? false }
        gestureEngine.register(swipeLeftRecognizer)

        let swipeRightRecognizer = TwoFingerSwipeRightRecognizer()
        swipeRightRecognizer.isCmdHeld = cmdHeldProvider
        swipeRightRecognizer.isEnabled = { [weak self] in self?.config.isSwipeRightEnabled ?? false }
        gestureEngine.register(swipeRightRecognizer)

        let swipeRecognizer = SwipeRecognizer()
        swipeRecognizer.isCmdHeld = cmdHeldProvider
        swipeRecognizer.isEnabled = { [weak self] in
            guard let self = self else { return false }
            return self.config.isSwipeDownEnabled || self.config.isSwipeUpEnabled
        }
        swipeRecognizer.isSwipeDownEnabled = { [weak self] in self?.config.isSwipeDownEnabled ?? false }
        swipeRecognizer.isSwipeUpEnabled = { [weak self] in self?.config.isSwipeUpEnabled ?? false }
        gestureEngine.register(swipeRecognizer)

        // MultitouchService -> GestureEngine
        multitouchService.onFrame = { [weak self] touches, timestamp in
            guard let self = self,
                  self.config.isGesturesEnabled,
                  !self.isCoolingDown else { return }

            let mcActive = self.missionControlService.isMissionControlActive
            let dockHovered = !mcActive
                && self.config.isDockActionsOutsideMCEnabled
                && self.isDockHovered()

            if dockHovered {
                self.dockSuppressor.isSuppressing = (touches.count >= 2)
            } else if !mcActive {
                self.dockSuppressor.isSuppressing = false
            }

            guard mcActive || dockHovered else { return }
            self.gestureEngine.processFrame(touches, timestamp: timestamp)
        }

        // GestureEngine -> Actions
        gestureEngine.onGestureRecognized = { [weak self] result in
            guard let self = self else { return }
            let axPoint = self.currentAXMouseLocation()

            let target = self.resolveTarget(at: axPoint)
            let resolution = self.gestureRouter.routeGesture(
                result,
                at: axPoint,
                target: target,
                service: self.accessibilityService,
                volumeService: self.volumeService,
                isAutoEjectEnabled: self.config.isAutoEjectEnabled,
                config: self.config,
                activateApp: { [weak self] loc in self?.activateAppIfNeeded(at: loc) }
            )

            switch resolution {
            case .execute(let feedbackMode, let haptic, let action):
                if !self.missionControlService.isMissionControlActive && self.config.isDockActionsOutsideMCEnabled {
                    self.dockSuppressor.isSuppressing = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                        self?.dockSuppressor.isSuppressing = false
                    }
                }
                self.executeFeedbackThenAction(at: axPoint, feedbackMode: feedbackMode, haptic: haptic, action: action)
            case .none:
                break
            }
        }
    }

    /// Shows feedback + fires haptic, then defers the action one run-loop turn
    /// so the feedback panel composites before the blocking AX call starves
    /// the run loop.
    private func executeFeedbackThenAction(
        at point: CGPoint,
        feedbackMode: CursorFeedbackOverlay.Mode,
        haptic: HapticType?,
        action: @escaping () -> Void
    ) {
        cursorFeedback.show(at: point, mode: feedbackMode)
        if let haptic = haptic {
            HapticService.perform(haptic)
        }
        DispatchQueue.main.async { [weak self] in
            // Teardown-safety gate: cancels deferred execution if VM is deallocated before the turn fires
            guard self != nil else { return }
            action()
        }
    }

    // MARK: - Target Resolution

    /// Current cursor position in top-left-origin AX coordinates (what
    /// `AXUIElementCopyElementAtPosition` expects). Prefers the Quartz event
    /// location; falls back to converting Cocoa's bottom-left `NSEvent`
    /// coordinates when no event source is available.
    private func currentAXMouseLocation() -> CGPoint {
        if let loc = CGEvent(source: nil)?.location {
            return loc
        }
        let mouseLocation = NSEvent.mouseLocation
        let primaryHeight = ScreenGeometry.primaryScreenHeight
        return CGPoint(x: mouseLocation.x, y: primaryHeight - mouseLocation.y)
    }

    /// `true` when the cursor currently sits over a Dock icon region.
    /// Used to gate outside-Mission-Control dock gestures/shortcuts.
    private func isDockHovered() -> Bool {
        return accessibilityService.isDockRegion(at: currentAXMouseLocation())
    }

    private func resolveTarget(at point: CGPoint) -> TargetResolution {
        guard let element = accessibilityService.getElement(at: point) else { return .none }
        if accessibilityService.isDockItem(element) {
            if let app = accessibilityService.getAppFromDockItem(element) {
                return .dock(app)
            }
            return .none
        }
        if let window = accessibilityService.getWindow(for: element) {
            return .window(window)
        }
        return .none
    }

    // MARK: - App Activation

    @discardableResult
    private func activateAppIfNeeded(at point: CGPoint) -> NSRunningApplication? {
        let element = accessibilityService.getElement(at: point)
        let isDock = element.map { accessibilityService.isDockItem($0) } ?? false
        let app = isDock
            ? element.flatMap { accessibilityService.getAppFromDockItem($0) }
            : element.flatMap { accessibilityService.getAppFromElement($0) }
        app?.activate(options: .activateIgnoringOtherApps)
        return app
    }

    func start() {
        eventTapService.start()
        missionControlService.start()
        multitouchService.start()
        hoverService.start()
        dockSuppressor.start()
    }

    func stop() {
        eventTapService.stop()
        missionControlService.stop()
        multitouchService.stop()
        hoverService.stop()
        dockSuppressor.stop()
        gestureEngine.reset()
        cursorFeedback.hide()
    }
}
