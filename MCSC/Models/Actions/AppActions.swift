import Cocoa

struct CloseAppAction {
    func perform(app: NSRunningApplication, service: AccessibilityServiceProtocol) {
        guard app.processIdentifier != NSRunningApplication.current.processIdentifier else { return }
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

/// Closes a tab when the Cmd+W shortcut is fired from a Dock item.
///
/// Targets the app's key window (the one the user is acting on from the Dock)
/// and, when it exposes an accessible tab strip, presses that window's selected
/// tab close button. Falls back to posting ⌘W to the app's key window, which
/// matches the Dock-item targeting expectation.
struct CloseTabAppAction {
    func perform(app: NSRunningApplication, service: AccessibilityServiceProtocol) {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // Target the app's key window (the one the user is acting on from the
        // Dock), not an arbitrary window in the list.
        if let keyWindow: AXUIElement = service.getAttributeValue(kAXFocusedWindowAttribute, for: appElement),
           let closeBtn = service.findActiveTabCloseButton(in: keyWindow) {
            _ = service.performAction(kAXPressAction, on: closeBtn)
            return
        }

        // Fallback: Cmd+W delivered to the app's key window, which matches the
        // Dock-item targeting expectation.
        KeyboardEventPoster.postShortcut(virtualKey: 0x0D, flags: .maskCommand, to: app.processIdentifier)
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

struct ReopenTabAppAction {
    func perform(app: NSRunningApplication) {
        KeyboardEventPoster.postShortcut(virtualKey: 0x11, flags: [.maskCommand, .maskShift], to: app.processIdentifier)
    }
}
