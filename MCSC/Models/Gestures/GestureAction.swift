import Foundation

// MARK: - Kind

/// The seven physical trackpad gestures recognised by the engine.
/// Each kind has both a plain and a ⌘-modified variant; the mapping is
/// `kind + isCmd → action`.
enum GestureKind: String, CaseIterable {
    case pinchIn
    case pinchOut
    case swipeLeft
    case swipeRight
    case swipeDown
    case swipeUp
    case twoFingerDoubleTap

    /// Short human name shown in the settings pane.
    var displayName: String {
        switch self {
        case .pinchIn: return "Pinch In"
        case .pinchOut: return "Pinch Out"
        case .swipeLeft: return "Swipe Left"
        case .swipeRight: return "Swipe Right"
        case .swipeDown: return "Swipe Down"
        case .swipeUp: return "Swipe Up"
        case .twoFingerDoubleTap: return "2-Finger Double Tap"
        }
    }

    /// SF Symbol used next to the name in the gesture rows.
    var symbolName: String {
        switch self {
        case .pinchIn: return "arrow.inward"
        case .pinchOut: return "arrow.outward"
        case .swipeLeft: return "arrow.left"
        case .swipeRight: return "arrow.right"
        case .swipeDown: return "arrow.down"
        case .swipeUp: return "arrow.up"
        case .twoFingerDoubleTap: return "hand.tap"
        }
    }

    /// Whether this kind triggers `activateApp` when fired on a window/dock target.
    /// Mirrors legacy behaviour: only swipe-left auto-activates the target app.
    var activatesApp: Bool { self == .swipeLeft }

    /// Haptic type for this kind; two-finger tap varies by modifier.
    func haptic(isCmd: Bool) -> HapticType {
        switch self {
        case .pinchIn: return .pinchIn
        case .pinchOut: return .pinchOut
        case .swipeLeft: return .swipeLeft
        case .swipeRight: return .swipeRight
        case .swipeDown: return .swipeDown
        case .swipeUp: return .swipeUp
        case .twoFingerDoubleTap: return isCmd ? .cmdTwoFingerDoubleTap : .twoFingerDoubleTap
        }
    }
}

// MARK: - Action

/// The window/app action a gesture can be bound to.
/// Raw values are persisted to UserDefaults, so never rename or delete — only append.
enum GestureAction: String, CaseIterable {
    case closeWindow = "closeWindow"
    case quitApp = "quitApp"
    case closeTab = "closeTab"
    case closeAllTabs = "closeAllTabs"
    case reopenTab = "reopenTab"
    case newTab = "newTab"
    case newWindow = "newWindow"
    case toggleFullscreen = "toggleFullscreen"
    case fillScreen = "fillScreen"
    case almostMaximize = "almostMaximize"
    case makeLarger = "makeLarger"
    case reasonableSize = "reasonableSize"
    case minimize = "minimize"
    case hideApp = "hideApp"
    case moveNextDesktop = "moveNextDesktop"
    case movePreviousDesktop = "movePreviousDesktop"

    /// Label shown in the popup menu.
    var menuTitle: String {
        switch self {
        case .closeWindow: return "Close Window"
        case .quitApp: return "Quit App"
        case .closeTab: return "Close Tab"
        case .closeAllTabs: return "Close All Tabs"
        case .reopenTab: return "Reopen Tab"
        case .newTab: return "New Tab"
        case .newWindow: return "New Window"
        case .toggleFullscreen: return "Toggle Fullscreen"
        case .fillScreen: return "Fill Screen"
        case .almostMaximize: return "Almost Maximize"
        case .makeLarger: return "Make Larger (+33%)"
        case .reasonableSize: return "Reasonable Size"
        case .minimize: return "Minimize"
        case .hideApp: return "Hide App"
        case .moveNextDesktop: return "Move to Next Desktop"
        case .movePreviousDesktop: return "Move to Previous Desktop"
        }
    }

    /// Short subtitle hint used only in docs/tests if needed.
    var shortDescription: String { menuTitle }
}

// MARK: - Defaults

/// Factory defaults matching the legacy hardcoded GestureActionRouter mappings.
enum GestureDefaults {
    static func action(for kind: GestureKind, isCmd: Bool) -> GestureAction {
        switch (kind, isCmd) {
        case (.pinchIn, false): return .closeWindow
        case (.pinchIn, true): return .quitApp
        case (.pinchOut, false): return .toggleFullscreen
        case (.pinchOut, true): return .newWindow
        case (.swipeLeft, false): return .closeTab
        case (.swipeLeft, true): return .closeAllTabs
        case (.swipeRight, false): return .reopenTab
        case (.swipeRight, true): return .newTab
        case (.swipeDown, false): return .fillScreen
        case (.swipeDown, true): return .makeLarger
        case (.swipeUp, false): return .minimize
        case (.swipeUp, true): return .hideApp
        case (.twoFingerDoubleTap, false): return .reasonableSize
        case (.twoFingerDoubleTap, true): return .almostMaximize
        }
    }

    static var plainDefaults: [GestureKind: GestureAction] {
        Dictionary(uniqueKeysWithValues: GestureKind.allCases.map { ($0, action(for: $0, isCmd: false)) })
    }

    static var cmdDefaults: [GestureKind: GestureAction] {
        Dictionary(uniqueKeysWithValues: GestureKind.allCases.map { ($0, action(for: $0, isCmd: true)) })
    }
}

// MARK: - GestureResult → kind projection

extension GestureResult {
    /// Decomposes a result into its kind + whether ⌘ was held.
    var kindAndModifier: (kind: GestureKind, isCmd: Bool) {
        switch self {
        case .pinchIn: return (.pinchIn, false)
        case .cmdPinchIn: return (.pinchIn, true)
        case .pinchOut: return (.pinchOut, false)
        case .cmdPinchOut: return (.pinchOut, true)
        case .swipeLeft: return (.swipeLeft, false)
        case .cmdSwipeLeft: return (.swipeLeft, true)
        case .swipeRight: return (.swipeRight, false)
        case .cmdSwipeRight: return (.swipeRight, true)
        case .swipeDown: return (.swipeDown, false)
        case .cmdSwipeDown: return (.swipeDown, true)
        case .swipeUp: return (.swipeUp, false)
        case .cmdSwipeUp: return (.swipeUp, true)
        case .twoFingerDoubleTap: return (.twoFingerDoubleTap, false)
        case .cmdTwoFingerDoubleTap: return (.twoFingerDoubleTap, true)
        }
    }
}
