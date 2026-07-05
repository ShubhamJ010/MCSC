import Cocoa

class ShortcutViewModel {
    private let eventTapService: EventTapService
    private let accessibilityService: AccessibilityServiceProtocol
    private let missionControlService: MissionControlService
    private let launchAtLoginService: LaunchAtLoginService
    private lazy var multitouchService = MultitouchService()
    private lazy var gestureEngine = GestureEngine()
    
    private let closeAction = CloseWindowAction()
    private let minimizeAction = MinimizeWindowAction()
    private let maximizeAction = MaximizeWindowAction()
    private let hideAction = HideApplicationAction()
    private let forceQuitAction = ForceQuitAction()
    private let closeAppAction = CloseAppAction()
    private let minimizeAppAction = MinimizeAppAction()
    private let forceQuitAppAction = ForceQuitAppAction()
    
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
    var isPinchToCloseEnabled = true
    
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
                        if let app = app {
                            self.closeAppAction.perform(app: app, service: self.accessibilityService)
                        } else {
                            self.closeAction.perform(at: location, service: self.accessibilityService)
                        }
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
        gestureEngine.register(PinchInRecognizer())
        
        // MultitouchService -> GestureEngine
        multitouchService.onFrame = { [weak self] touches, timestamp in
            guard let self = self,
                  self.isPinchToCloseEnabled,
                  self.missionControlService.isMissionControlActive else { return }
            self.gestureEngine.processFrame(touches, timestamp: timestamp)
        }
        
        // GestureEngine -> Actions
        gestureEngine.onGestureRecognized = { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .pinchIn:
                // Use mouse cursor position in Core Graphics coordinates (0,0 is top-left)
                guard let mouseLocation = CGEvent(source: nil)?.location else { return }
                
                let element = self.accessibilityService.getElement(at: mouseLocation)
                let isDock = element.map { self.accessibilityService.isDockItem($0) } ?? false
                let app = isDock ? element.flatMap { self.accessibilityService.getAppFromDockItem($0) } : nil
                
                if let app = app {
                    self.closeAppAction.perform(app: app, service: self.accessibilityService)
                } else {
                    self.closeAction.perform(at: mouseLocation, service: self.accessibilityService)
                }
            }
        }
    }
    
    func start() {
        eventTapService.start()
        missionControlService.start()
        multitouchService.start()
    }
    
    func stop() {
        eventTapService.stop()
        missionControlService.stop()
        multitouchService.stop()
        gestureEngine.reset()
    }
}
