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
    var isSwipeLeftEnabled = true
    var isSwipeRightEnabled = true
    var isSwipeDownEnabled = true
    var isSwipeUpEnabled = true
    var isTwoFingerDoubleTapEnabled = true
    var isAutoEjectEnabled = true
    var isKeyboardNavigationEnabled = true {
        didSet { UserDefaults.standard.set(isKeyboardNavigationEnabled, forKey: Self.Keys.keyboardNavigation) }
    }

    init() {
        if UserDefaults.standard.object(forKey: Self.Keys.keyboardNavigation) != nil {
            isKeyboardNavigationEnabled = UserDefaults.standard.bool(forKey: Self.Keys.keyboardNavigation)
        }
    }

    private enum Keys {
        static let keyboardNavigation = "mcsc.keyboardNavigation.enabled"
    }
}
