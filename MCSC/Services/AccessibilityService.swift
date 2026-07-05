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
