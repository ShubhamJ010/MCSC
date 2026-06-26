import Cocoa
import Foundation
import CoreGraphics

class MissionControlService {
    private var _isMissionControlActive = false
    var isMissionControlActive: Bool {
        return checkMissionControlActive()
    }
    var isSimulating = false
    
    // Maintain notification observers for cleanup
    private var observers: [NSObjectProtocol] = []
    
    init() {
        start()
    }
    
    func start() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        let center = DistributedNotificationCenter.default()
        
        let events = [
            "com.apple.expose.start", "com.apple.expose.stop",
            "com.apple.showdesktop.start", "com.apple.showdesktop.stop",
            "com.apple.expose.front.start", "com.apple.expose.front.stop",
            "com.apple.MissionControl.start", "com.apple.MissionControl.stop",
            "com.apple.dashboard.start", "com.apple.dashboard.stop"
        ]
        
        for event in events {
            let observer = center.addObserver(forName: NSNotification.Name(event), object: nil, queue: .main) { [weak self] _ in
                if event.contains("start") { self?._isMissionControlActive = true }
                if event.contains("stop") { self?._isMissionControlActive = false }
            }
            observers.append(observer)
        }
    }
    
    func stop() {
        let center = DistributedNotificationCenter.default()
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
    }
    
    func checkMissionControlActive() -> Bool {
        if _isMissionControlActive { return true }
        
        // Fallback check via window list
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        for window in windowList {
            let ownerName = window[kCGWindowOwnerName as String] as? String ?? ""
            let name = window[kCGWindowName as String] as? String ?? ""
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            
            if ownerName == "Dock" {
                if let bounds = window[kCGWindowBounds as String] as? [String: Any],
                   let y = bounds["Y"] as? CGFloat {
                    if y == -1 || layer > 0 {
                        return true
                    }
                }
                if name == "Mission Control" || name == "Expose" {
                    return true
                }
            }
        }
        return false
    }
    
    func executeFixSequence() {
        isSimulating = true
        
        // Step 1: Simulating Escape (Key code 53)
        postKeyEvent(keyCode: 53, flags: [])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            // Step 2: Simulating Cmd+Space (Key code 49)
            self?.postKeyEvent(keyCode: 49, flags: .maskCommand)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.isSimulating = false
            }
        }
    }
    
    private func postKeyEvent(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) else { return }
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        
        keyDown.flags = flags
        keyUp.flags = flags
        
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
