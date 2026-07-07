import Cocoa
import ApplicationServices

protocol AccessibilityServiceProtocol {
    func getElement(at point: CGPoint) -> AXUIElement?
    func getWindow(for element: AXUIElement) -> AXUIElement?
    func performAction(_ action: String, on element: AXUIElement) -> Bool
    func getAttributeValue<T>(_ attribute: String, for element: AXUIElement) -> T?
    func setFrame(_ frame: CGRect, for element: AXUIElement) -> Bool
    func isDockItem(_ element: AXUIElement) -> Bool
    func getAppFromDockItem(_ element: AXUIElement) -> NSRunningApplication?
    func findActiveTabCloseButton(in window: AXUIElement) -> AXUIElement?
    func getAppFromElement(_ element: AXUIElement) -> NSRunningApplication?
    func isWindowMinimized(_ window: AXUIElement) -> Bool
    func unminimizeWindow(_ window: AXUIElement) -> Bool
}

class AccessibilityService: AccessibilityServiceProtocol {
    private let systemWide = AXUIElementCreateSystemWide()
    
    func getElement(at point: CGPoint) -> AXUIElement? {
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element)
        
        guard result == .success else { return nil }
        return element
    }
    
    func getWindow(for element: AXUIElement) -> AXUIElement? {
        var window: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &window)
        
        if result == .success {
            return (window as! AXUIElement)
        }
        
        // If the element itself is a window
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
           (role as? String) == kAXWindowRole {
            return element
        }
        
        return nil
    }
    
    func performAction(_ action: String, on element: AXUIElement) -> Bool {
        let result = AXUIElementPerformAction(element, action as CFString)
        return result == .success
    }
    
    func getAttributeValue<T>(_ attribute: String, for element: AXUIElement) -> T? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? T
    }

    func isDockItem(_ element: AXUIElement) -> Bool {
        var role: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        guard result == .success else { return false }
        return (role as? String) == "AXDockItem"
    }

    func getAppFromDockItem(_ element: AXUIElement) -> NSRunningApplication? {
        guard let title: String = getAttributeValue(kAXTitleAttribute, for: element) else {
            return nil
        }

        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.first { $0.localizedName == title }
    }

    func findActiveTabCloseButton(in window: AXUIElement) -> AXUIElement? {
        guard let children: [AXUIElement] = getAttributeValue(kAXChildrenAttribute, for: window) else {
            print("[MCSC] findActiveTabCloseButton: no children on window")
            return nil
        }
        for child in children {
            guard let role: String = getAttributeValue(kAXRoleAttribute, for: child),
                  role == "AXTabGroup" else { continue }
            guard let tabs: [AXUIElement] = getAttributeValue(kAXChildrenAttribute, for: child) else {
                continue
            }
            for tab in tabs {
                guard let tabRole: String = getAttributeValue(kAXRoleAttribute, for: tab),
                      tabRole == "AXRadioButton" else { continue }
                let isSelected: Bool? = getAttributeValue(kAXValueAttribute, for: tab)
                if isSelected == true {
                    if let tabChildren: [AXUIElement] = getAttributeValue(kAXChildrenAttribute, for: tab) {
                        for tabChild in tabChildren {
                            if let childRole: String = getAttributeValue(kAXRoleAttribute, for: tabChild),
                               childRole == "AXButton" {
                                return tabChild
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    func getAppFromElement(_ element: AXUIElement) -> NSRunningApplication? {
        var pid: pid_t = 0
        let result = AXUIElementGetPid(element, &pid)
        guard result == .success else { return nil }
        return NSRunningApplication(processIdentifier: pid)
    }

    func isWindowMinimized(_ window: AXUIElement) -> Bool {
        guard let minimized: Bool = getAttributeValue(kAXMinimizedAttribute, for: window) else {
            return false
        }
        return minimized
    }

    /// Reliably raises (unminimizes + brings to front) a window using the
    /// `kAXRaiseAction` AX action, which is the supported way to unminimize a window.
    func unminimizeWindow(_ window: AXUIElement) -> Bool {
        let result = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        return result == .success
    }

    func setFrame(_ frame: CGRect, for element: AXUIElement) -> Bool {
        // Set position first, then size — some apps fail if done in one shot
        var position = CGPoint(x: frame.origin.x, y: frame.origin.y)
        let posValue = AXValueCreate(.cgPoint, &position)!
        let posResult = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, posValue)

        var size = CGSize(width: frame.width, height: frame.height)
        let sizeValue = AXValueCreate(.cgSize, &size)!
        let sizeResult = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)

        return posResult == .success && sizeResult == .success
    }
}