import Cocoa
import Foundation
import CoreGraphics

class MissionControlService {
    private var _isMissionControlActive = false
    var isMissionControlActive: Bool {
        return checkMissionControlActive()
    }
    var isSimulating = false

    /// Fires when Mission Control (or Expose) activates. Used for gesture cooldown.
    var onActivated: (() -> Void)?

    // Maintain notification observers for cleanup
    private var observers: [NSObjectProtocol] = []

    // MARK: - Detection tuning (verified on macOS 15.7.3)
    /// Layer of Mission Control's full-screen Dock overlay window.
    private let missionControlOverlayLayer = 20
    /// Mission Control also shows the Dock bar at/below this layer; a Finder
    /// folder stack shows only the overlay and lacks this, so it is excluded.
    private let dockBarLayerThreshold = 18

    // MARK: - Cached detection (polled at most every 200ms)
    private let detectionCacheInterval: Double = 0.2
    private var cachedIsActive: Bool?
    private var lastDetectionTime: Double = 0

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
            let observer = center.addObserver(forName: NSNotification.Name(event), object: nil, queue: .main) { @MainActor [weak self] _ in
                if event.contains("start") {
                    self?._isMissionControlActive = true
                    self?.onActivated?()
                }
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
    
    /// Returns `true` only while Mission Control is open.
    ///
    /// Mission Control exposes an empty-named, full-screen Dock window at
    /// `missionControlOverlayLayer` *and* the Dock bar itself (empty-named
    /// windows at `dockBarLayerThreshold` or below). Launchpad uses higher
    /// layers (27–29) and a Finder folder stack shows only the overlay without
    /// the Dock bar, so both are excluded. The result is cached for
    /// `detectionCacheInterval` to avoid polling the window list on every
    /// trackpad frame.
    func checkMissionControlActive() -> Bool {
        // Notification fast-path (rarely fires — MC notifications do not reach a
        // standalone process on this macOS version).
        if _isMissionControlActive { return true }

        let now = CACurrentMediaTime()
        if now - lastDetectionTime < detectionCacheInterval, let cached = cachedIsActive {
            return cached
        }

        // Collect the layers of all empty-named Dock windows.
        var emptyNamedDockLayers: [Int] = []
        if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] {
            for window in windowList {
                guard (window[kCGWindowOwnerName as String] as? String) == "Dock" else { continue }
                let name = window[kCGWindowName as String] as? String ?? ""
                let layer = window[kCGWindowLayer as String] as? Int ?? 0
                if name.isEmpty {
                    emptyNamedDockLayers.append(layer)
                }
            }
        }

        let isActive = emptyNamedDockLayers.contains(missionControlOverlayLayer)
            && emptyNamedDockLayers.contains { $0 <= dockBarLayerThreshold }

        cachedIsActive = isActive
        lastDetectionTime = now
        return isActive
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
