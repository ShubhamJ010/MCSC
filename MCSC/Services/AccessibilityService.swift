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
}

class AccessibilityService: AccessibilityServiceProtocol {
    private let systemWide = AXUIElementCreateSystemWide()

    /// When `true`, `getAppFromDockItem` logs the Dock item's AX attributes and
    /// which resolution strategy matched. Flip on to verify Catalyst/Electron
    /// Dock icons (e.g. WhatsApp, Beeper) without spamming normal operation.
    /// Enabled by launching with `MCSC_DOCK_DIAG=1` in the environment.
    var dockDiagnosticsEnabled = false

    init() {
        if ProcessInfo.processInfo.environment["MCSC_DOCK_DIAG"] == "1" {
            dockDiagnosticsEnabled = true
        }
    }
    
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
        // Walk up the AX hierarchy: the hit element over a Dock icon is often a
        // child (badge / AXImage) rather than the AXDockItem itself, especially
        // for non-native apps (Mac Catalyst, Electron). Resolve against the
        // nearest Dock item ancestor instead of demanding the hit be one.
        return dockItemAncestor(for: element) != nil
    }

    /// Returns the nearest `AXDockItem` at or above `element`, climbing the
    /// parent chain up to a bounded depth. Returns `nil` if no Dock item is
    /// found — it can never escape into a window or app element.
    func dockItemAncestor(for element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element
        var depth = 0
        while let el = current, depth < 8 {
            var role: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &role) == .success,
               (role as? String) == "AXDockItem" {
                return el
            }
            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &parent) == .success,
                  let parentEl = parent as! AXUIElement? else {
                return nil
            }
            current = parentEl
            depth += 1
        }
        return nil
    }

    func getAppFromDockItem(_ element: AXUIElement) -> NSRunningApplication? {
        // Resolve against the actual Dock item (the hit element may be a child
        // such as a notification badge), then map it to a running app.
        guard let dockItem = dockItemAncestor(for: element) else {
            if dockDiagnosticsEnabled {
                print("[MCSC][DockDiag] no AXDockItem ancestor found for hit element")
            }
            return nil
        }

        let runningApps = NSWorkspace.shared.runningApplications

        // Primary: the Dock item often exposes its app URL. Matching by bundle
        // identifier is framework-agnostic and works for Mac Catalyst / Electron
        // apps whose AXTitle does not equal the running app's localizedName.
        if let url: NSURL = getAttributeValue(kAXURLAttribute, for: dockItem),
           let bundle = Bundle(url: url as URL),
           let app = runningApps.first(where: { $0.bundleIdentifier == bundle.bundleIdentifier }) {
            if dockDiagnosticsEnabled {
                print("[MCSC][DockDiag] resolved via AXURL → bundleID '\(bundle.bundleIdentifier)' → '\(app.localizedName ?? "?")'")
            }
            return app
        }

        // Fallback: tolerant (case / diacritic / whitespace-insensitive) title
        // match. The exact-equality check used previously failed for any app
        // whose Dock AXTitle differed from localizedName.
        guard let title: String = getAttributeValue(kAXTitleAttribute, for: dockItem) else {
            if dockDiagnosticsEnabled {
                let role: String? = getAttributeValue(kAXRoleAttribute, for: dockItem)
                let subrole: String? = getAttributeValue(kAXSubroleAttribute, for: dockItem)
                let url: NSURL? = getAttributeValue(kAXURLAttribute, for: dockItem)
                print("[MCSC][DockDiag] AXURL match failed; AXTitle missing — role='\(role ?? "?"))' subrole='\(subrole ?? "?")' AXURL=\(url?.absoluteString ?? "nil")")
            }
            return nil
        }
        let normalizedTitle = title.trimmingCharacters(in: .whitespaces)
        let opts: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        if let app = runningApps.first(where: {
            normalizedTitle.compare(($0.localizedName ?? "").trimmingCharacters(in: .whitespaces),
                                     options: opts) == .orderedSame
        }) {
            if dockDiagnosticsEnabled {
                print("[MCSC][DockDiag] resolved via tolerant AXTitle '\(normalizedTitle)' → '\(app.localizedName ?? "?")'")
            }
            return app
        }
        if dockDiagnosticsEnabled {
            let role: String? = getAttributeValue(kAXRoleAttribute, for: dockItem)
            let subrole: String? = getAttributeValue(kAXSubroleAttribute, for: dockItem)
            let url: NSURL? = getAttributeValue(kAXURLAttribute, for: dockItem)
            print("[MCSC][DockDiag] NO match — AXTitle='\(title)' role='\(role ?? "?")' subrole='\(subrole ?? "?")' AXURL=\(url?.absoluteString ?? "nil")' running=\(runningApps.compactMap { $0.localizedName })")
        }
        return nil
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