import Cocoa

class ShortcutViewModel {
    private let eventTapService: EventTapService
    private let accessibilityService: AccessibilityServiceProtocol
    private let missionControlService: MissionControlService
    private let launchAtLoginService: LaunchAtLoginService
    
    private let closeAction = CloseWindowAction()
    private let minimizeAction = MinimizeWindowAction()
    private let maximizeAction = MaximizeWindowAction()
    private let hideAction = HideApplicationAction()
    private let forceQuitAction = ForceQuitAction()
    
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
    var isCmdFEnabled = true
    var isCmdSpaceEnabled = true
    
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
            
            // We only care about Cmd combinations
            let isCmdPressed = flags.contains(.maskCommand)
            
            if isCmdPressed {
                if keyCode == self.kKeySpace && self.isCmdSpaceEnabled && !self.missionControlService.isSimulating {
                    if self.missionControlService.checkMissionControlActive() {
                        self.missionControlService.executeFixSequence()
                        return true
                    }
                }
                
                if keyCode == self.kKeyW && self.isCmdWEnabled {
                    self.closeAction.perform(at: location, service: self.accessibilityService)
                    return true
                } else if keyCode == self.kKeyQ && self.isCmdQEnabled {
                    self.forceQuitAction.perform(at: location, service: self.accessibilityService)
                    return true
                } else if keyCode == self.kKeyM && self.isCmdMEnabled {
                    self.minimizeAction.perform(at: location, service: self.accessibilityService)
                    return true
                } else if keyCode == self.kKeyH && self.isCmdHEnabled {
                    self.hideAction.perform(at: location, service: self.accessibilityService)
                    return true
                } else if keyCode == self.kKeyF && self.isCmdFEnabled {
                    self.maximizeAction.perform(at: location, service: self.accessibilityService)
                    return true
                }
            }
            
            return false // Don't consume
        }
    }
    
    func start() {
        eventTapService.start()
    }
    
    func stop() {
        eventTapService.stop()
        missionControlService.stop()
    }
}
