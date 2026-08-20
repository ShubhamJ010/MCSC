import Foundation

/// Value type representing user-configurable shortcut and gesture toggles.
struct ShortcutConfiguration {
    var isCmdWEnabled = true
    var isCmdQEnabled = true
    var isCmdMEnabled = true
    var isCmdHEnabled = true
    var isCmdFEnabled = false
    var isCmdSpaceEnabled = true
    var isGesturesEnabled = true
    var isPinchInEnabled = true
    var isPinchOutEnabled = true
    var isSwipeLeftEnabled = true
    var isSwipeRightEnabled = true
    var isSwipeDownEnabled = true
    var isSwipeUpEnabled = true
    var isTwoFingerDoubleTapEnabled = true
    var isAutoEjectEnabled = true
    /// When `true`, dock-targeted shortcuts and gestures also work while
    /// hovering Dock icons in normal desktop mode (Mission Control closed).
    /// Persisted to `UserDefaults` on every mutation.
    var isDockActionsOutsideMCEnabled = true {
        didSet { UserDefaults.standard.set(isDockActionsOutsideMCEnabled, forKey: Self.Keys.dockActionsOutsideMC) }
    }
    var isKeyboardNavigationEnabled = true {
        didSet { UserDefaults.standard.set(isKeyboardNavigationEnabled, forKey: Self.Keys.keyboardNavigation) }
    }

    init() {
        if UserDefaults.standard.object(forKey: Self.Keys.keyboardNavigation) != nil {
            isKeyboardNavigationEnabled = UserDefaults.standard.bool(forKey: Self.Keys.keyboardNavigation)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.dockActionsOutsideMC) != nil {
            isDockActionsOutsideMCEnabled = UserDefaults.standard.bool(forKey: Self.Keys.dockActionsOutsideMC)
        }
    }

    private enum Keys {
        static let keyboardNavigation = "mcsc.keyboardNavigation.enabled"
        static let dockActionsOutsideMC = "mcsc.dockActionsOutsideMC.enabled"
    }
}
