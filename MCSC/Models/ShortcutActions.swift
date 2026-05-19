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
