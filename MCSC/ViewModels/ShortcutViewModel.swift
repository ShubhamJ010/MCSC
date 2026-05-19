import Cocoa

class ShortcutViewModel {
    private let eventTapService: EventTapService
    private let accessibilityService: AccessibilityServiceProtocol
    
    private let closeAction = CloseWindowAction()
    private let forceQuitAction = ForceQuitAction()
    
    // Key codes
    private let kKeyW: Int64 = 13
    private let kKeyQ: Int64 = 12
    
    var isCmdWEnabled = true
    var isCmdQEnabled = true
    
    init(eventTapService: EventTapService, accessibilityService: AccessibilityServiceProtocol) {
        self.eventTapService = eventTapService
        self.accessibilityService = accessibilityService
        
        setupCallbacks()
    }
    
    private func setupCallbacks() {
        eventTapService.onShortcutDetected = { [weak self] keyCode, flags, location in
            guard let self = self else { return false }
            
            // We only care about Cmd + W and Cmd + Q
            let isCmdPressed = flags.contains(.maskCommand)
            
            if isCmdPressed {
                if keyCode == self.kKeyW && self.isCmdWEnabled {
                    self.closeAction.perform(at: location, service: self.accessibilityService)
                    return true // Consume event
                } else if keyCode == self.kKeyQ && self.isCmdQEnabled {
                    self.forceQuitAction.perform(at: location, service: self.accessibilityService)
                    return true // Consume event
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
    }
}
