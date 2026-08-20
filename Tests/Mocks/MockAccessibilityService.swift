import Cocoa
import ApplicationServices

class MockAccessibilityService: AccessibilityServiceProtocol {
    var getElementCalledWith: CGPoint?
    var mockElement: AXUIElement?
    var mockWindow: AXUIElement?
    var mockApp: NSRunningApplication?
    var performActionCalledWith: (action: String, element: AXUIElement)?
    var setFrameCalledWith: (frame: CGRect, element: AXUIElement)?
    var isDockItemValue: Bool = false
    var focusWindowCalledWith: AXUIElement?
    var focusWindowReturnValue: Bool = true
    var mockFocusedWindow: AXUIElement?
    var mockTabCloseButton: AXUIElement?
    var mockDocumentPath: String?
    var mockWindowTitle: String?

    func getElement(at point: CGPoint) -> AXUIElement? {
        getElementCalledWith = point
        return mockElement
    }

    func getWindow(for element: AXUIElement) -> AXUIElement? {
        return mockWindow
    }

    func performAction(_ action: String, on element: AXUIElement) -> Bool {
        performActionCalledWith = (action, element)
        return true
    }

    func getAttributeValue<T>(_ attribute: String, for element: AXUIElement) -> T? {
        if attribute == kAXFocusedWindowAttribute, let window = mockFocusedWindow {
            return window as? T
        }
        return nil
    }

    func getFrame(for element: AXUIElement) -> CGRect? {
        return CGRect(x: 100, y: 100, width: 800, height: 600)
    }

    func setFrame(_ frame: CGRect, for element: AXUIElement) -> Bool {
        setFrameCalledWith = (frame, element)
        return true
    }

    func isDockItem(_ element: AXUIElement) -> Bool {
        return isDockItemValue
    }

    func getAppFromDockItem(_ element: AXUIElement) -> NSRunningApplication? {
        return mockApp
    }

    func findActiveTabCloseButton(in window: AXUIElement) -> AXUIElement? {
        return mockTabCloseButton
    }

    func getAppFromElement(_ element: AXUIElement) -> NSRunningApplication? {
        return mockApp
    }

    func focusWindow(_ window: AXUIElement) -> Bool {
        focusWindowCalledWith = window
        return focusWindowReturnValue
    }

    func getDocumentPath(for window: AXUIElement) -> String? {
        return mockDocumentPath
    }

    func getWindowTitle(for window: AXUIElement) -> String? {
        return mockWindowTitle
    }
}
