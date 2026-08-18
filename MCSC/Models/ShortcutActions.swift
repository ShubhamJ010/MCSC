import Cocoa

/// A window-management operation triggered by a shortcut or gesture.
///
/// Implementations are lightweight `struct`s (no heap allocation) that
/// translate a screen point into one or more Accessibility actions. They are
/// pure operations with no long-lived state, so a single shared instance per
/// action can be reused across the app's lifetime.
protocol ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol)
}

/// Closes the window at `point` by pressing its AX close button.
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

/// Closes the tab in the window currently under the cursor.
///
/// Resolution order:
/// 1. Hit-test the cursor position to the AX element, then to its owning window.
/// 2. If the window exposes an accessible tab strip, press the selected tab's
///    close button directly — this closes the hovered window's active tab
///    regardless of which window is key, so it is robust in Mission Control.
/// 3. Otherwise fall back to posting ⌘W to the app, first attempting to focus
///    the hovered window so the key window matches the cursor (best-effort;
///    some apps ignore programmatic focus while Mission Control is active).
struct CloseTabAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              let window = service.getWindow(for: element) else { return }

        if let closeBtn = service.findActiveTabCloseButton(in: window) {
            _ = service.performAction(kAXPressAction, on: closeBtn)
            return
        }

        // Steer Cmd+W toward the hovered window (the resolved `window`), not the
        // app's previously focused key window. Best-effort: if the app ignores
        // programmatic focus, the key window path is unchanged.
        _ = service.focusWindow(window)

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
        postCmdW(to: app.processIdentifier)
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
        guard let element = service.getElement(at: point),
              let _ = service.getWindow(for: element) else { return }

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

// MARK: - Tiling Actions

/// Expands the window at `point` to fill its screen's full bounds.
struct FillScreenAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              let window = service.getWindow(for: element) else { return }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let screen = NSScreen.screens.first(where: {
            let axBounds = CGRect(
                x: $0.frame.origin.x,
                y: primaryHeight - $0.frame.origin.y - $0.frame.height,
                width: $0.frame.width,
                height: $0.frame.height
            )
            return axBounds.contains(point)
        }) ?? NSScreen.main ?? NSScreen.screens.first

        guard let screenFrame = screen?.frame else { return }

        // Convert to AX coordinates (origin at the top-left of the primary display).
        let axScreenBounds = CGRect(
            x: screenFrame.origin.x,
            y: primaryHeight - screenFrame.origin.y - screenFrame.height,
            width: screenFrame.width,
            height: screenFrame.height
        )

        _ = service.setFrame(axScreenBounds, for: window)
    }
}

/// Increases the size of the target window by 33% (anchored at center, clamped to screen bounds).
struct MakeLargerAction: ShortcutAction {
    /// Multiplier used to scale window dimensions (+33%).
    private let scaleFactor: CGFloat = 1.33

    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              let window = service.getWindow(for: element),
              let currentFrame = service.getFrame(for: window) else { return }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let screen = NSScreen.screens.first(where: {
            let axBounds = CGRect(
                x: $0.frame.origin.x,
                y: primaryHeight - $0.frame.origin.y - $0.frame.height,
                width: $0.frame.width,
                height: $0.frame.height
            )
            return axBounds.contains(point)
        }) ?? NSScreen.main ?? NSScreen.screens[0]

        let screenFrame = screen.frame
        let axScreenBounds = CGRect(
            x: screenFrame.origin.x,
            y: primaryHeight - screenFrame.origin.y - screenFrame.height,
            width: screenFrame.width,
            height: screenFrame.height
        )

        let targetWidth = (currentFrame.width * scaleFactor).rounded()
        let targetHeight = (currentFrame.height * scaleFactor).rounded()

        // Clamp dimensions to screen bounds
        let newWidth = min(targetWidth, axScreenBounds.width)
        let newHeight = min(targetHeight, axScreenBounds.height)

        // Expand symmetrically from center
        var newX = (currentFrame.origin.x - (newWidth - currentFrame.width) / 2.0).rounded()
        var newY = (currentFrame.origin.y - (newHeight - currentFrame.height) / 2.0).rounded()

        // Clamp position within screen boundaries
        if newX < axScreenBounds.minX {
            newX = axScreenBounds.minX
        } else if newX + newWidth > axScreenBounds.maxX {
            newX = axScreenBounds.maxX - newWidth
        }

        if newY < axScreenBounds.minY {
            newY = axScreenBounds.minY
        } else if newY + newHeight > axScreenBounds.maxY {
            newY = axScreenBounds.maxY - newHeight
        }

        _ = service.setFrame(CGRect(x: newX, y: newY, width: newWidth, height: newHeight), for: window)
    }
}

struct ReasonableSizeAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              let window = service.getWindow(for: element) else { return }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let f = screen.frame
        let w = (f.width * 0.604).rounded()
        let h = (f.height * 0.58).rounded()
        let x = f.origin.x + (f.width - w) / 2
        let y = f.origin.y + (f.height - h) / 2
        _ = service.setFrame(CGRect(x: x, y: y, width: w, height: h), for: window)
    }
}

struct AlmostMaximizeAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              let window = service.getWindow(for: element) else { return }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let f = screen.frame
        let w = (f.width * 0.904).rounded()
        let h = (f.height * 0.872).rounded()
        let x = f.origin.x + (f.width - w) / 2
        let y = f.origin.y + (f.height - h) / 2
        _ = service.setFrame(CGRect(x: x, y: y, width: w, height: h), for: window)
    }
}

// MARK: - Cmd Swipe Actions

/// Posts Cmd+Shift+W to the application under the point to close all of its
/// windows. In tabbed applications this closes every tab.
struct CloseAllTabsAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point) else { return }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return }
        postCmdShiftW(to: pid)
    }

    private func postCmdShiftW(to pid: pid_t) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x0D, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x0D, keyDown: false)
        keyDown?.flags = [.maskCommand, .maskShift]
        keyUp?.flags = [.maskCommand, .maskShift]
        keyDown?.postToPid(pid)
        keyUp?.postToPid(pid)
    }
}

/// Posts Cmd+N to the application under the point to open a new window.
struct NewWindowAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point) else { return }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return }
        postCmdN(to: pid)
    }

    private func postCmdN(to pid: pid_t) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x2D, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x2D, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.postToPid(pid)
        keyUp?.postToPid(pid)
    }
}