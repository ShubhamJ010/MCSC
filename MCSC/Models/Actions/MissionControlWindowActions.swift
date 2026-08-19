import Cocoa

/// Executes window-level operations (close, minimize, force-quit) on windows
/// identified by Mission Control / Exposé window metadata dictionaries.
enum MissionControlWindowActions {
    /// Finds the AX window matching `windowID` and presses its button for
    /// `attribute` (kAXCloseButtonAttribute / kAXMinimizeButtonAttribute).
    /// Returns true if the button was successfully pressed.
    static func pressWindowButton(attribute: String, on windowInfo: [String: Any]) -> Bool {
        guard let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
              let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID else {
            return false
        }

        let app = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let windowsRef = windowsRef, CFGetTypeID(windowsRef) == CFArrayGetTypeID(),
           let axWindows = windowsRef as? [AXUIElement] {
            for axWindow in axWindows {
                var axId: CGWindowID = 0
                _AXUIElementGetWindow(axWindow, &axId)
                if axId == windowID {
                    var buttonRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(axWindow, attribute as CFString, &buttonRef) == .success,
                       let btn = buttonRef,
                       CFGetTypeID(btn) == AXUIElementGetTypeID() {
                        let actionResult = AXUIElementPerformAction((btn as! AXUIElement), kAXPressAction as CFString)
                        if actionResult == .success {
                            return true
                        }
                    }
                }
            }
        }
        return false
    }

    static func performClose(on windowInfo: [String: Any], accessibilityService: AccessibilityServiceProtocol) {
        if pressWindowButton(attribute: kAXCloseButtonAttribute, on: windowInfo) {
            return
        }

        guard let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t else { return }

        // Fallback: activate application and trigger close action
        if let app = NSRunningApplication(processIdentifier: pid) {
            if #available(macOS 14.0, *) {
                app.activate()
            } else {
                app.activate(options: .activateIgnoringOtherApps)
            }
        }
        
        if let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat] {
            let centerPoint = CGPoint(
                x: (boundsDict["X"] ?? 0) + (boundsDict["Width"] ?? 0) / 2,
                y: (boundsDict["Y"] ?? 0) + (boundsDict["Height"] ?? 0) / 2
            )
            CloseWindowAction().perform(at: centerPoint, service: accessibilityService)
        }
    }

    static func performMinimize(on windowInfo: [String: Any], accessibilityService: AccessibilityServiceProtocol) {
        if pressWindowButton(attribute: kAXMinimizeButtonAttribute, on: windowInfo) {
            return
        }

        guard let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t else { return }

        // Fallback: activate application and trigger minimize action
        if let app = NSRunningApplication(processIdentifier: pid) {
            if #available(macOS 14.0, *) {
                app.activate()
            } else {
                app.activate(options: .activateIgnoringOtherApps)
            }
        }
        
        if let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat] {
            let centerPoint = CGPoint(
                x: (boundsDict["X"] ?? 0) + (boundsDict["Width"] ?? 0) / 2,
                y: (boundsDict["Y"] ?? 0) + (boundsDict["Height"] ?? 0) / 2
            )
            MinimizeWindowAction().perform(at: centerPoint, service: accessibilityService)
        }
    }

    static func performForceQuit(on windowInfo: [String: Any]) {
        guard let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
              pid != NSRunningApplication.current.processIdentifier,
              let app = NSRunningApplication(processIdentifier: pid) else {
            return
        }
        app.forceTerminate()
    }
}
