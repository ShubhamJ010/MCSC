import Cocoa

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
        KeyboardEventPoster.postShortcut(virtualKey: 0x0D, flags: .maskCommand, to: pid)
    }
}

struct ReopenTabAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              service.getWindow(for: element) != nil else { return }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return }
        KeyboardEventPoster.postShortcut(virtualKey: 0x11, flags: [.maskCommand, .maskShift], to: pid)
    }
}

/// Posts Cmd+Shift+W to the application under the point to close all of its
/// windows. In tabbed applications this closes every tab.
struct CloseAllTabsAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point) else { return }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return }
        KeyboardEventPoster.postShortcut(virtualKey: 0x0D, flags: [.maskCommand, .maskShift], to: pid)
    }
}

/// Posts Cmd+N to the application under the point to open a new window.
struct NewWindowAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        // Wake Exposé so the keystroke reaches the app while Mission Control is
        // still intercepting input — same pattern as ToggleFullscreenAction.
        _ = coreDockSendNotification("com.apple.expose.awake" as CFString, 0)
        guard let element = service.getElement(at: point) else { return }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return }
        KeyboardEventPoster.postShortcut(virtualKey: 0x2D, flags: .maskCommand, to: pid)
    }
}

/// Posts Cmd+T to the application under the point to open a new tab.
struct NewTabAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        // Wake Exposé so the keystroke reaches the app while Mission Control is
        // still intercepting input — same pattern as ToggleFullscreenAction.
        _ = coreDockSendNotification("com.apple.expose.awake" as CFString, 0)
        guard let element = service.getElement(at: point) else { return }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return }
        KeyboardEventPoster.postShortcut(virtualKey: 0x11, flags: .maskCommand, to: pid)
    }
}
