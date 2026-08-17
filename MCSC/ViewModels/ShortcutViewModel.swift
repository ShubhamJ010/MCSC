import Cocoa

class ShortcutViewModel {
    private let eventTapService: EventTapService
    private let accessibilityService: AccessibilityServiceProtocol
    private let missionControlService: MissionControlService
    private let launchAtLoginService: LaunchAtLoginService
    private lazy var multitouchService = MultitouchService()
    private lazy var gestureEngine = GestureEngine()
    private lazy var hoverService: MissionControlHoverServiceProtocol = {
        MissionControlHoverService(
            accessibilityService: accessibilityService,
            isMissionControlActiveProvider: { [weak self] in
                self?.missionControlService.isMissionControlActive ?? false
            }
        )
    }()
    
    private lazy var cursorFeedback = CursorFeedbackOverlay()
    
    private let closeAction = CloseWindowAction()
    private let closeTabAction = CloseTabAction()
    private let closeTabAppAction = CloseTabAppAction()
    private let reopenTabAction = ReopenTabAction()
    private let reopenTabAppAction = ReopenTabAppAction()
    private let closeAppAction = CloseAppAction()
    private let minimizeAction = MinimizeWindowAction()
    private let maximizeAction = MaximizeWindowAction()
    private let hideAction = HideApplicationAction()
    private let forceQuitAction = ForceQuitAction()
    private let minimizeAppAction = MinimizeAppAction()
    private let forceQuitAppAction = ForceQuitAppAction()
    private let makeLargerAction = MakeLargerAction()
    private let reasonableSizeAction = ReasonableSizeAction()
    private let almostMaximizeAction = AlmostMaximizeAction()
    private let closeAllTabsAction = CloseAllTabsAction()
    private let newWindowAction = NewWindowAction()
    
    // Key codes
    private let kKeyW: Int64 = 13
    private let kKeyQ: Int64 = 12
    private let kKeyM: Int64 = 46
    private let kKeyH: Int64 = 4
    private let kKeyF: Int64 = 3
    private let kKeySpace: Int64 = 49
    
    var isCmdWEnabled = true
    var isCmdQEnabled = true
    var isCmdMEnabled = true
    var isCmdHEnabled = true
    var isCmdFEnabled = false
    var isCmdSpaceEnabled = true
    var isGesturesEnabled = true
    var isPinchInEnabled = true
    var isSwipeLeftEnabled = true
    var isSwipeRightEnabled = true
    var isSwipeDownEnabled = true
    var isSwipeUpEnabled = true
    var isTwoFingerDoubleTapEnabled = true
    
    var isHoverCloseButtonEnabled: Bool {
        get { hoverService.isEnabled }
        set { hoverService.isEnabled = newValue }
    }

    /// Prevents gestures from firing right after Mission Control opens via 3-finger swipe.
    private var isCoolingDown = false

    var isLaunchAtLoginEnabled: Bool {
        return launchAtLoginService.isEnabled
    }
    
    init(eventTapService: EventTapService, 
         accessibilityService: AccessibilityServiceProtocol, 
         missionControlService: MissionControlService,
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
        eventTapService.onShortcutDetected = { [weak self] keyCode, flags, location in
            guard let self = self else { return false }
            
            // We only care about Cmd combinations and no other modifiers
            let isCmdPressed = flags.contains(.maskCommand)
            let isShiftPressed = flags.contains(.maskShift)
            let isControlPressed = flags.contains(.maskControl)
            let isOptionPressed = flags.contains(.maskAlternate)
            
            if isCmdPressed && !isShiftPressed && !isControlPressed && !isOptionPressed {
                if keyCode == self.kKeySpace && self.isCmdSpaceEnabled && !self.missionControlService.isSimulating {
                    if self.missionControlService.checkMissionControlActive() {
                        self.missionControlService.executeFixSequence()
                        return true
                    }
                }
                
                if self.missionControlService.isMissionControlActive {
                    let element = self.accessibilityService.getElement(at: location)
                    let isDock = element.map { self.accessibilityService.isDockItem($0) } ?? false
                    let app = isDock ? element.flatMap { self.accessibilityService.getAppFromDockItem($0) } : nil

                    if keyCode == self.kKeyW && self.isCmdWEnabled {
                        self.activateAppIfNeeded(at: location)
                        if let app = app {
                            self.closeTabAppAction.perform(app: app, service: self.accessibilityService)
                        } else {
                            self.closeTabAction.perform(at: location, service: self.accessibilityService)
                        }
                        self.cursorFeedback.show(at: location, mode: .close)
                        return true
                    } else if keyCode == self.kKeyQ && self.isCmdQEnabled {
                        if let app = app {
                            self.forceQuitAppAction.perform(app: app)
                        } else {
                            self.forceQuitAction.perform(at: location, service: self.accessibilityService)
                        }
                        return true
                    } else if keyCode == self.kKeyM && self.isCmdMEnabled {
                        if let app = app {
                            self.minimizeAppAction.perform(app: app, service: self.accessibilityService)
                        } else {
                            self.minimizeAction.perform(at: location, service: self.accessibilityService)
                        }
                        self.cursorFeedback.show(at: location, mode: .minimize)
                        return true
                    } else if keyCode == self.kKeyH && self.isCmdHEnabled {
                        if let app = app {
                            app.hide()
                        } else {
                            self.hideAction.perform(at: location, service: self.accessibilityService)
                        }
                        return true
                    }
                }
            }
            
            return false // Don't consume
        }
        
        // Register gesture recognizers
        // IMPORTANT: Tap recognizers must be registered BEFORE swipe recognizers.
        // The GestureEngine processes recognizers in registration order, and the
        // first recognizer to return a result wins. Taps need priority to prevent
        // swipe recognizers from accidentally firing during double-tap gestures.

        let twoFingerTapRecognizer = TwoFingerDoubleTapRecognizer()
        twoFingerTapRecognizer.isCmdHeld = {
            NSEvent.modifierFlags.contains(.command)
        }
        twoFingerTapRecognizer.isEnabled = { [weak self] in self?.isTwoFingerDoubleTapEnabled ?? false }
        gestureEngine.register(twoFingerTapRecognizer)

        let pinchInRecognizer = PinchInRecognizer()
        pinchInRecognizer.isCmdHeld = {
            NSEvent.modifierFlags.contains(.command)
        }
        pinchInRecognizer.isEnabled = { [weak self] in self?.isPinchInEnabled ?? false }
        gestureEngine.register(pinchInRecognizer)

        let swipeLeftRecognizer = TwoFingerSwipeLeftRecognizer()
        swipeLeftRecognizer.isCmdHeld = {
            NSEvent.modifierFlags.contains(.command)
        }
        swipeLeftRecognizer.isEnabled = { [weak self] in self?.isSwipeLeftEnabled ?? false }
        gestureEngine.register(swipeLeftRecognizer)

        let swipeRightRecognizer = TwoFingerSwipeRightRecognizer()
        swipeRightRecognizer.isCmdHeld = {
            NSEvent.modifierFlags.contains(.command)
        }
        swipeRightRecognizer.isEnabled = { [weak self] in self?.isSwipeRightEnabled ?? false }
        gestureEngine.register(swipeRightRecognizer)

        let swipeRecognizer = SwipeRecognizer()
        swipeRecognizer.isCmdHeld = {
            NSEvent.modifierFlags.contains(.command)
        }
        swipeRecognizer.isEnabled = { [weak self] in
            guard let self = self else { return false }
            return self.isSwipeDownEnabled || self.isSwipeUpEnabled
        }
        swipeRecognizer.isSwipeDownEnabled = { [weak self] in self?.isSwipeDownEnabled ?? false }
        swipeRecognizer.isSwipeUpEnabled = { [weak self] in self?.isSwipeUpEnabled ?? false }
        gestureEngine.register(swipeRecognizer)
        
        // MultitouchService -> GestureEngine
        multitouchService.onFrame = { [weak self] touches, timestamp in
            guard let self = self,
                  self.isGesturesEnabled,
                  !self.isCoolingDown,
                  self.missionControlService.isMissionControlActive else { return }
            self.gestureEngine.processFrame(touches, timestamp: timestamp)
        }
        
        // GestureEngine -> Actions
        gestureEngine.onGestureRecognized = { [weak self] result in
            guard let self = self,
                  let mouseLocation = CGEvent(source: nil)?.location else { return }

            let target = self.resolveTarget(at: mouseLocation)

            switch result {
            case .pinchIn:
                switch target {
                case .dock(let app):
                    self.closeAppAction.perform(app: app, service: self.accessibilityService)
                    self.cursorFeedback.show(at: mouseLocation, mode: .close)
                    HapticService.perform(.pinchIn)
                case .window:
                    self.closeAction.perform(at: mouseLocation, service: self.accessibilityService)
                    self.cursorFeedback.show(at: mouseLocation, mode: .close)
                    HapticService.perform(.pinchIn)
                case .none:
                    break
                }

            case .cmdPinchIn:
                switch target {
                case .dock(let app):
                    self.forceQuitAppAction.perform(app: app)
                    HapticService.perform(.pinchIn)
                case .window:
                    self.forceQuitAction.perform(at: mouseLocation, service: self.accessibilityService)
                    HapticService.perform(.pinchIn)
                case .none:
                    break
                }

            case .swipeLeft:
                switch target {
                case .dock(let app):
                    app.activate(options: .activateIgnoringOtherApps)
                    self.closeTabAppAction.perform(app: app, service: self.accessibilityService)
                    HapticService.perform(.swipeLeft)
                case .window:
                    self.activateAppIfNeeded(at: mouseLocation)
                    self.closeTabAction.perform(at: mouseLocation, service: self.accessibilityService)
                    HapticService.perform(.swipeLeft)
                case .none:
                    break
                }

            case .cmdSwipeLeft:
                switch target {
                case .window, .dock:
                    self.closeAllTabsAction.perform(at: mouseLocation, service: self.accessibilityService)
                    HapticService.perform(.swipeLeft)
                case .none:
                    break
                }

            case .swipeRight:
                switch target {
                case .dock(let app):
                    self.reopenTabAppAction.perform(app: app)
                    HapticService.perform(.swipeRight)
                case .window:
                    self.reopenTabAction.perform(at: mouseLocation, service: self.accessibilityService)
                    HapticService.perform(.swipeRight)
                case .none:
                    break
                }

            case .cmdSwipeRight:
                switch target {
                case .window, .dock:
                    self.newWindowAction.perform(at: mouseLocation, service: self.accessibilityService)
                    HapticService.perform(.swipeRight)
                case .none:
                    break
                }

            case .swipeDown:
                switch target {
                case .window:
                    self.makeLargerAction.perform(at: mouseLocation, service: self.accessibilityService)
                    HapticService.perform(.swipeDown)
                case .dock, .none:
                    break
                }

            case .cmdSwipeDown:
                switch target {
                case .window:
                    self.makeLargerAction.perform(at: mouseLocation, service: self.accessibilityService)
                    HapticService.perform(.swipeDown)
                case .dock, .none:
                    break
                }

            case .swipeUp:
                switch target {
                case .dock(let app):
                    self.minimizeAppAction.perform(app: app, service: self.accessibilityService)
                    self.cursorFeedback.show(at: mouseLocation, mode: .minimize)
                    HapticService.perform(.swipeUp)
                case .window:
                    self.minimizeAction.perform(at: mouseLocation, service: self.accessibilityService)
                    self.cursorFeedback.show(at: mouseLocation, mode: .minimize)
                    HapticService.perform(.swipeUp)
                case .none:
                    break
                }

            case .cmdSwipeUp:
                switch target {
                case .dock(let app):
                    app.hide()
                    HapticService.perform(.swipeUp)
                case .window:
                    self.hideAction.perform(at: mouseLocation, service: self.accessibilityService)
                    HapticService.perform(.swipeUp)
                case .none:
                    break
                }

            case .twoFingerDoubleTap:
                switch target {
                case .window:
                    self.reasonableSizeAction.perform(at: mouseLocation, service: self.accessibilityService)
                    HapticService.perform(.twoFingerDoubleTap)
                case .dock, .none:
                    break
                }

            case .cmdTwoFingerDoubleTap:
                switch target {
                case .window:
                    self.almostMaximizeAction.perform(at: mouseLocation, service: self.accessibilityService)
                    HapticService.perform(.cmdTwoFingerDoubleTap)
                case .dock, .none:
                    break
                }
            }
        }
    }

    // MARK: - Target Resolution

    private enum TargetResolution {
        case dock(NSRunningApplication)
        case window(AXUIElement)
        case none
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

    /// Resolves the `NSRunningApplication` under the given point and activates it
    /// (brings it frontmost). This ensures that close-tab, close-window, and force-quit
    /// operations work reliably — many apps ignore keyboard or accessibility events
    /// when they are not the active application.
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
    }
    
    func stop() {
        eventTapService.stop()
        missionControlService.stop()
        multitouchService.stop()
        hoverService.stop()
        gestureEngine.reset()
        cursorFeedback.hide()
    }
}