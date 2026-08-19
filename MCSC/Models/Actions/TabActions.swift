import Cocoa

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
        guard let element = service.getElement(at: point) else { return }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return }
        KeyboardEventPoster.postShortcut(virtualKey: 0x2D, flags: .maskCommand, to: pid)
    }
}
