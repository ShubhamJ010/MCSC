import Cocoa

protocol ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol)
}

struct CloseWindowAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              let window = service.getWindow(for: element) else { return }
        
        // Attempt to find the close button
        if let closeButton: AXUIElement = service.getAttributeValue(kAXCloseButtonAttribute, for: window) {
            _ = service.performAction(kAXPressAction, on: closeButton)
        }
    }
}

struct MinimizeWindowAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              let window = service.getWindow(for: element) else { return }
        
        if let minimizeButton: AXUIElement = service.getAttributeValue(kAXMinimizeButtonAttribute, for: window) {
            _ = service.performAction(kAXPressAction, on: minimizeButton)
        }
    }
}

struct MaximizeWindowAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              let window = service.getWindow(for: element) else { return }
        
        if let zoomButton: AXUIElement = service.getAttributeValue(kAXZoomButtonAttribute, for: window) {
            _ = service.performAction(kAXPressAction, on: zoomButton)
        }
    }
}

struct HideApplicationAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point) else { return }
        
        var pid: pid_t = 0
        let result = AXUIElementGetPid(element, &pid)
        
        if result == .success, let app = NSRunningApplication(processIdentifier: pid) {
            app.hide()
        }
    }
}

struct ForceQuitAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point) else { return }
        
        var pid: pid_t = 0
        let result = AXUIElementGetPid(element, &pid)
        
        if result == .success, let app = NSRunningApplication(processIdentifier: pid) {
            // Prevent the app from killing itself
            if pid != NSRunningApplication.current.processIdentifier {
                app.forceTerminate()
            }
        }
    }
}

struct CloseAppAction {
    func perform(app: NSRunningApplication, service: AccessibilityServiceProtocol) {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var windows: CFTypeRef?
        AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows)

        if let windowList = windows as? [AXUIElement], !windowList.isEmpty {
            for window in windowList {
                if let closeButton: AXUIElement = service.getAttributeValue(kAXCloseButtonAttribute, for: window) {
                    _ = service.performAction(kAXPressAction, on: closeButton)
                }
            }
        } else {
            app.terminate()
        }
    }
}

struct CloseTabAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              let window = service.getWindow(for: element) else { return }

        if let closeBtn = service.findActiveTabCloseButton(in: window) {
            _ = service.performAction(kAXPressAction, on: closeBtn)
            return
        }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return }
        postCmdW(to: pid)
    }

    private func postCmdW(to pid: pid_t) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x0D, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x0D, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.postToPid(pid)
        keyUp?.postToPid(pid)
    }
}

struct CloseTabAppAction {
    func perform(app: NSRunningApplication, service: AccessibilityServiceProtocol) {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var windows: CFTypeRef?
        AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows)

        if let windowList = windows as? [AXUIElement], !windowList.isEmpty {
            for window in windowList {
                if let closeBtn = service.findActiveTabCloseButton(in: window) {
                    _ = service.performAction(kAXPressAction, on: closeBtn)
                    return
                }
            }
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x0D, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x0D, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.postToPid(app.processIdentifier)
        keyUp?.postToPid(app.processIdentifier)
    }
}

struct MinimizeAppAction {
    func perform(app: NSRunningApplication, service: AccessibilityServiceProtocol) {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var windows: CFTypeRef?
        AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows)

        if let windowList = windows as? [AXUIElement] {
            for window in windowList {
                if let minimizeButton: AXUIElement = service.getAttributeValue(kAXMinimizeButtonAttribute, for: window) {
                    _ = service.performAction(kAXPressAction, on: minimizeButton)
                }
            }
        }
    }
}

struct ForceQuitAppAction {
    func perform(app: NSRunningApplication) {
        if app.processIdentifier != NSRunningApplication.current.processIdentifier {
            app.forceTerminate()
        }
    }
}

struct ReopenTabAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point) else { return }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return }
        postCmdShiftT(to: pid)
    }

    private func postCmdShiftT(to pid: pid_t) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x11, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x11, keyDown: false)
        keyDown?.flags = [.maskCommand, .maskShift]
        keyUp?.flags = [.maskCommand, .maskShift]
        keyDown?.postToPid(pid)
        keyUp?.postToPid(pid)
    }
}

struct ReopenTabAppAction {
    func perform(app: NSRunningApplication) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x11, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x11, keyDown: false)
        keyDown?.flags = [.maskCommand, .maskShift]
        keyUp?.flags = [.maskCommand, .maskShift]
        keyDown?.postToPid(app.processIdentifier)
        keyUp?.postToPid(app.processIdentifier)
    }
}

// MARK: - Fallback Actions

/// Unminimizes a window if it's minimized, or unhides an app if it's hidden.
/// Used as a fallback when the primary action (e.g. fullscreen) cannot be performed
/// because the app is minimized or hidden.
struct UnminimizeUnhideWindowAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point) else { return }
        let app = service.getAppFromElement(element)

        // 1. Try to unminimize: get the window and check if minimized
        if let window = service.getWindow(for: element) {
            if service.isWindowMinimized(window) {
                _ = service.unminimizeWindow(window)
                // Bring the app to front
                app?.activate(options: .activateIgnoringOtherApps)
                return
            }
        }

        // 2. If the app is hidden, unhide it
        if let app = app, app.isHidden {
            app.unhide()
            app.activate(options: .activateIgnoringOtherApps)
            return
        }
    }
}

// MARK: - Tiling Actions

struct FullscreenWindowAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              let window = service.getWindow(for: element) else { return }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let f = screen.frame
        let frame = CGRect(x: f.origin.x, y: 0, width: f.width, height: f.height)
        _ = service.setFrame(frame, for: window)
    }
}

struct ReasonableSizeAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              let window = service.getWindow(for: element) else { return }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let f = screen.frame
        let w = f.width * 0.7
        let h = f.height * 0.75
        let x = (f.width - w) / 2
        let y = (f.height - h) / 2
        _ = service.setFrame(CGRect(x: x, y: y, width: w, height: h), for: window)
    }
}

struct AlmostMaximizeAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              let window = service.getWindow(for: element) else { return }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let f = screen.frame
        let w = f.width * 0.8
        let h = f.height * 0.7
        let x = (f.width - w) / 2
        let y = (f.height - h) / 2
        _ = service.setFrame(CGRect(x: x, y: y, width: w, height: h), for: window)
    }
}