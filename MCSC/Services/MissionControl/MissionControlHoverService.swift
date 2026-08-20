import Cocoa
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
@discardableResult
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

@MainActor
protocol MissionControlHoverServiceProtocol: AnyObject {
    var isEnabled: Bool { get set }
    var isTracking: Bool { get }
    
    func start()
    func stop()
}

@MainActor
final class MissionControlHoverService: MissionControlHoverServiceProtocol {
    private let accessibilityService: AccessibilityServiceProtocol
    private let isMissionControlActiveProvider: () -> Bool
    private let overlay: PreviewCloseButtonOverlay
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var axObserver: AXObserver?
    private var dockAXElement: AXUIElement?
    private var windowFetchTimer: Timer?
    /// Internal so tests can verify lifecycle without exposing to production
    /// callers outside the module.
    internal var spaceChangeObserver: NSObjectProtocol?
    
    private var windows: [[String: Any]] = []
    /// Test-only window count for verifying dedup behavior without depending
    /// on the real CGWindowList scan. Returns the number of tracked windows.
    internal var _testWindowCount: Int { windows.count }
    private(set) var isTracking = false
    private var isMissionControlActive = false
    private var isCmdHeld = false
    private var isOptionHeld = false
    private var isControlHeld = false
    private var hoveredWindow: [String: Any]?
    private var overlayRect: CGRect?
    private var isOverlayHovered = false

    /// The action the hover button currently represents, derived from held
    /// modifiers: Cmd → force quit, Option → minimize, Control → fullscreen,
    /// neither → close. Cmd takes precedence when several are held.
    internal var currentOverlayMode: PreviewCloseButtonOverlay.Mode {
        if isCmdHeld { return .quit }
        if isControlHeld { return .fullscreen }
        if isOptionHeld { return .minimize }
        return .close
    }
    
    var isEnabled = true {
        didSet {
            if !isEnabled {
                hideOverlay()
            }
        }
    }

    init(accessibilityService: AccessibilityServiceProtocol,
         isMissionControlActiveProvider: @escaping () -> Bool,
         overlay: PreviewCloseButtonOverlay? = nil) {
        self.accessibilityService = accessibilityService
        self.isMissionControlActiveProvider = isMissionControlActiveProvider
        self.overlay = overlay ?? PreviewCloseButtonOverlay()
    }
    
    func start() {
        guard !isTracking else { return }
        isTracking = true
        
        setupDockObserver()
        startInputTap()
        setupSpaceChangeObserver()
    }
    
    func stop() {
        guard isTracking else { return }
        stopDockObserver()
        stopInputTap()
        stopWindowFetchTimer()
        removeSpaceChangeObserver()
        hideOverlay()
        isTracking = false
    }
    
    // MARK: - Dock AXObserver
    
    private static let dockNotifications = [
        "AXExposeShowAllWindows",
        "AXExposeShowFrontWindows",
        "AXExposeShowDesktop",
        "AXExposeExit"
    ]

    private func setupDockObserver() {
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return
        }
        
        let pid = dockApp.processIdentifier
        let dockElement = AXUIElementCreateApplication(pid)
        self.dockAXElement = dockElement
        
        var observer: AXObserver?
        let callback: AXObserverCallback = { (observer, element, notification, refcon) in
            guard let refcon = refcon else { return }
            let service = Unmanaged<MissionControlHoverService>.fromOpaque(refcon).takeUnretainedValue()
            let notifName = notification as String
            
            DispatchQueue.main.async {
                service.handleDockNotification(notifName)
            }
        }
        
        guard AXObserverCreate(pid, callback, &observer) == .success, let obs = observer else {
            return
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        for notif in Self.dockNotifications {
            AXObserverAddNotification(obs, dockElement, notif as CFString, selfPtr)
        }
        
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
        self.axObserver = obs
    }
    
    private func stopDockObserver() {
        if let obs = axObserver, let dockElement = dockAXElement {
            for notif in Self.dockNotifications {
                AXObserverRemoveNotification(obs, dockElement, notif as CFString)
            }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
            self.axObserver = nil
            self.dockAXElement = nil
        }
    }
    
    private func handleDockNotification(_ notification: String) {
        if notification == "AXExposeExit" {
            isMissionControlActive = false
            stopWindowFetchTimer()
            hideOverlay()
        } else {
            isMissionControlActive = true
            fetchWindows()
            startWindowFetchTimer()
            
            if let mouseLocation = CGEvent(source: nil)?.location {
                updateOverlay(at: mouseLocation)
            }
        }
    }
    
    // MARK: - Window Polling
    
    private func startWindowFetchTimer() {
        stopWindowFetchTimer()
        windowFetchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.fetchWindows()
            }
        }
    }
    
    private func stopWindowFetchTimer() {
        windowFetchTimer?.invalidate()
        windowFetchTimer = nil
    }

    // MARK: - Active Space Change

    /// Refreshes the window list and overlay when the active Space changes
    /// while Mission Control is open. Without this, `windows` can reference
    /// windows that no longer exist on the new Space.
    private func setupSpaceChangeObserver() {
        guard spaceChangeObserver == nil else { return }
        spaceChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.fetchWindows()
                if let mouseLocation = CGEvent(source: nil)?.location {
                    self.updateOverlay(at: mouseLocation)
                }
            }
        }
    }

    private func removeSpaceChangeObserver() {
        if let observer = spaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            spaceChangeObserver = nil
        }
    }
    
    private func fetchWindows() {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        let filtered = list.filter { window in
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  let owner = window[kCGWindowOwnerName as String] as? String,
                  owner != "Dock", owner != "MCSC", owner != "Window Server" else {
                return false
            }
            if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
               let w = bounds["Width"], let h = bounds["Height"], w >= 100, h >= 100 {
                return true
            }
            return false
        }

        // Skip the assignment and overlay recomputation when the window list is
        // unchanged. A deep compare avoids redundant work on every 500ms poll.
        if !NSArray(array: filtered).isEqual(to: windows) {
            windows = filtered
        }
    }
    
    // MARK: - Input Event Tap
    
    private func startInputTap() {
        guard eventTap == nil else { return }
        
        let mask = (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<MissionControlHoverService>.fromOpaque(refcon).takeUnretainedValue()

                // macOS disables event taps on timeout or user input; re-enable
                // so hover tracking survives without an app restart.
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = service.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                if type == .flagsChanged {
                    let cmdPressed = event.flags.contains(.maskCommand)
                    let optionPressed = event.flags.contains(.maskAlternate)
                    let controlPressed = event.flags.contains(.maskControl)
                    if Thread.isMainThread {
                        service.handleFlagsChanged(cmdPressed: cmdPressed, optionPressed: optionPressed, controlPressed: controlPressed)
                    } else {
                        DispatchQueue.main.async {
                            service.handleFlagsChanged(cmdPressed: cmdPressed, optionPressed: optionPressed, controlPressed: controlPressed)
                        }
                    }
                    return Unmanaged.passUnretained(event)
                }
                
                if type == .leftMouseDown {
                    let location = event.location
                    var intercepted = false
                    
                    // Safely check if click hit the overlay button without blocking main thread
                    if Thread.isMainThread {
                        intercepted = service.handleMouseDown(at: location)
                    } else {
                        DispatchQueue.main.sync {
                            intercepted = service.handleMouseDown(at: location)
                        }
                    }
                    
                    if intercepted {
                        return nil // Swallow the click so Mission Control does not dismiss prematurely
                    }
                    return Unmanaged.passUnretained(event)
                }
                
                let location = event.location
                if Thread.isMainThread {
                    service.handleMouseMoved(at: location)
                } else {
                    DispatchQueue.main.async {
                        service.handleMouseMoved(at: location)
                    }
                }
                
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    private func stopInputTap() {
        if let source = runLoopSource {
            CFRunLoopSourceInvalidate(source)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }
    
    func handleFlagsChanged(cmdPressed: Bool, optionPressed: Bool, controlPressed: Bool = false) {
        guard isTracking && isEnabled else { return }
        isCmdHeld = cmdPressed
        isOptionHeld = optionPressed
        isControlHeld = controlPressed
        overlay.setMode(currentOverlayMode)
    }
    
    func handleMouseDown(at location: CGPoint) -> Bool {
        guard isTracking && isEnabled, isMissionControlActive || isMissionControlActiveProvider() else {
            return false
        }
        
        guard let rect = overlayRect, rect.contains(location), let window = hoveredWindow else {
            return false
        }
        
        executeAction(on: window)
        return true
    }
    
    func handleMouseMoved(at mouseLocation: CGPoint) {
        guard isTracking && isEnabled else {
            hideOverlay()
            return
        }
        
        guard isMissionControlActive || isMissionControlActiveProvider() else {
            hideOverlay()
            return
        }
        
        if windows.isEmpty {
            fetchWindows()
        }
        
        updateOverlay(at: mouseLocation)
    }
    
    private func updateOverlay(at mouseLocation: CGPoint) {
        // If mouse is hovering over the action button itself, keep it visible
        if let rect = overlayRect, rect.contains(mouseLocation), hoveredWindow != nil {
            if !isOverlayHovered {
                isOverlayHovered = true
                overlay.setHovered(true)
            }
            return
        }
        
        // Mouse left the button: release hover state.
        if isOverlayHovered {
            isOverlayHovered = false
            overlay.setHovered(false)
        }
        
        // Find window containing cursor
        for windowInfo in windows {
            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"] else {
                continue
            }
            
            let windowFrame = CGRect(x: x, y: y, width: width, height: height)
            
            if windowFrame.contains(mouseLocation) {
                hoveredWindow = windowInfo
                let halfDim = PreviewCloseButtonOverlay.buttonDimension / 2.0
                overlayRect = CGRect(x: x - halfDim, y: y - halfDim, width: PreviewCloseButtonOverlay.buttonDimension, height: PreviewCloseButtonOverlay.buttonDimension)
                overlay.show(at: windowFrame, mode: currentOverlayMode)
                return
            }
        }
        
        hideOverlay()
    }
    
    private func hideOverlay() {
        if hoveredWindow != nil || overlay.isVisible {
            hoveredWindow = nil
            overlayRect = nil
            if isOverlayHovered {
                isOverlayHovered = false
                overlay.setHovered(false)
            }
            overlay.hide()
        }
    }
    
    // MARK: - Actions
    
    private func executeAction(on windowInfo: [String: Any]) {
        HapticService.perform(.pinchIn)
        
        switch currentOverlayMode {
        case .close:
            MissionControlWindowActions.performClose(on: windowInfo, accessibilityService: accessibilityService)
        case .minimize:
            MissionControlWindowActions.performMinimize(on: windowInfo, accessibilityService: accessibilityService)
        case .quit:
            MissionControlWindowActions.performForceQuit(on: windowInfo)
        case .fullscreen:
            MissionControlWindowActions.performFullscreen(on: windowInfo)
        }
        
        if let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID {
            windows.removeAll { ($0[kCGWindowNumber as String] as? CGWindowID) == windowID }
        }
        
        hideOverlay()
    }

    deinit {
        if let source = runLoopSource {
            CFRunLoopSourceInvalidate(source)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let obs = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
        }
        if let observer = spaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
