import Foundation

/// Value type representing user-configurable shortcut and gesture toggles.
struct ShortcutConfiguration {
    var isCmdWEnabled = true {
        didSet { UserDefaults.standard.set(isCmdWEnabled, forKey: Self.Keys.cmdWEnabled) }
    }
    var isCmdQEnabled = true {
        didSet { UserDefaults.standard.set(isCmdQEnabled, forKey: Self.Keys.cmdQEnabled) }
    }
    var isCmdMEnabled = true {
        didSet { UserDefaults.standard.set(isCmdMEnabled, forKey: Self.Keys.cmdMEnabled) }
    }
    var isCmdHEnabled = true {
        didSet { UserDefaults.standard.set(isCmdHEnabled, forKey: Self.Keys.cmdHEnabled) }
    }
    var isCmdFEnabled = false {
        didSet { UserDefaults.standard.set(isCmdFEnabled, forKey: Self.Keys.cmdFEnabled) }
    }
    var isCmdSpaceEnabled = true {
        didSet { UserDefaults.standard.set(isCmdSpaceEnabled, forKey: Self.Keys.cmdSpaceEnabled) }
    }
    var isCmdTEnabled = false {
        didSet { UserDefaults.standard.set(isCmdTEnabled, forKey: Self.Keys.cmdTEnabled) }
    }
    var isCmdNEnabled = false {
        didSet { UserDefaults.standard.set(isCmdNEnabled, forKey: Self.Keys.cmdNEnabled) }
    }
    var isCmdShiftWEnabled = false {
        didSet { UserDefaults.standard.set(isCmdShiftWEnabled, forKey: Self.Keys.cmdShiftWEnabled) }
    }
    var isCmdShiftTEnabled = false {
        didSet { UserDefaults.standard.set(isCmdShiftTEnabled, forKey: Self.Keys.cmdShiftTEnabled) }
    }
    // Window & Tab — additional window/size/desktop shortcuts (off by default, gesture-only previously)
    var isCloseWindowEnabled = false {
        didSet { UserDefaults.standard.set(isCloseWindowEnabled, forKey: Self.Keys.closeWindowEnabled) }
    }
    var isFillScreenEnabled = false {
        didSet { UserDefaults.standard.set(isFillScreenEnabled, forKey: Self.Keys.fillScreenEnabled) }
    }
    var isAlmostMaximizeEnabled = false {
        didSet { UserDefaults.standard.set(isAlmostMaximizeEnabled, forKey: Self.Keys.almostMaximizeEnabled) }
    }
    var isReasonableSizeEnabled = false {
        didSet { UserDefaults.standard.set(isReasonableSizeEnabled, forKey: Self.Keys.reasonableSizeEnabled) }
    }
    var isMakeLargerEnabled = false {
        didSet { UserDefaults.standard.set(isMakeLargerEnabled, forKey: Self.Keys.makeLargerEnabled) }
    }
    var isMakeSmallerEnabled = false {
        didSet { UserDefaults.standard.set(isMakeSmallerEnabled, forKey: Self.Keys.makeSmallerEnabled) }
    }
    var isMoveNextDesktopEnabled = false {
        didSet { UserDefaults.standard.set(isMoveNextDesktopEnabled, forKey: Self.Keys.moveNextDesktopEnabled) }
    }
    var isMovePreviousDesktopEnabled = false {
        didSet { UserDefaults.standard.set(isMovePreviousDesktopEnabled, forKey: Self.Keys.movePreviousDesktopEnabled) }
    }
    var isGesturesEnabled = true {
        didSet { UserDefaults.standard.set(isGesturesEnabled, forKey: Self.Keys.gesturesEnabled) }
    }
    var isPinchInEnabled = true {
        didSet { UserDefaults.standard.set(isPinchInEnabled, forKey: Self.Keys.pinchInEnabled) }
    }
    var isPinchOutEnabled = true {
        didSet { UserDefaults.standard.set(isPinchOutEnabled, forKey: Self.Keys.pinchOutEnabled) }
    }
    var isSwipeLeftEnabled = true {
        didSet { UserDefaults.standard.set(isSwipeLeftEnabled, forKey: Self.Keys.swipeLeftEnabled) }
    }
    var isSwipeRightEnabled = true {
        didSet { UserDefaults.standard.set(isSwipeRightEnabled, forKey: Self.Keys.swipeRightEnabled) }
    }
    var isSwipeDownEnabled = true {
        didSet { UserDefaults.standard.set(isSwipeDownEnabled, forKey: Self.Keys.swipeDownEnabled) }
    }
    var isSwipeUpEnabled = true {
        didSet { UserDefaults.standard.set(isSwipeUpEnabled, forKey: Self.Keys.swipeUpEnabled) }
    }
    var isTwoFingerDoubleTapEnabled = true {
        didSet { UserDefaults.standard.set(isTwoFingerDoubleTapEnabled, forKey: Self.Keys.twoFingerDoubleTapEnabled) }
    }
    var isAutoEjectEnabled = true {
        didSet { UserDefaults.standard.set(isAutoEjectEnabled, forKey: Self.Keys.autoEjectEnabled) }
    }
    /// When `true`, dock-targeted shortcuts and gestures also work while
    /// hovering Dock icons in normal desktop mode (Mission Control closed).
    /// Persisted to `UserDefaults` on every mutation.
    var isDockActionsOutsideMCEnabled = true {
        didSet { UserDefaults.standard.set(isDockActionsOutsideMCEnabled, forKey: Self.Keys.dockActionsOutsideMC) }
    }
    var isKeyboardNavigationEnabled = true {
        didSet { UserDefaults.standard.set(isKeyboardNavigationEnabled, forKey: Self.Keys.keyboardNavigation) }
    }
    // MARK: - General / Feedback — on by default (restores previous always-on behavior, now configurable).

    /// Haptic pulses for shortcuts/gestures. Previously always-on; now configurable.
    var isHapticFeedbackEnabled = true {
        didSet { UserDefaults.standard.set(isHapticFeedbackEnabled, forKey: Self.Keys.hapticFeedbackEnabled) }
    }
    /// Visual cursor flash overlay on actions. Previously always-on; now configurable.
    var isCursorFeedbackEnabled = true {
        didSet { UserDefaults.standard.set(isCursorFeedbackEnabled, forKey: Self.Keys.cursorFeedbackEnabled) }
    }

    // MARK: - Gesture action mappings

    /// Plain gesture → action mapping.
    var gestureActions: [GestureKind: GestureAction] = GestureDefaults.plainDefaults {
        didSet { persistGestureActions() }
    }
    /// ⌘-modified gesture → action mapping.
    var cmdGestureActions: [GestureKind: GestureAction] = GestureDefaults.cmdDefaults {
        didSet { persistCmdGestureActions() }
    }

    init() {
        if let v = Self.loadBool(forKey: Self.Keys.cmdWEnabled) { isCmdWEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.cmdQEnabled) { isCmdQEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.cmdMEnabled) { isCmdMEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.cmdHEnabled) { isCmdHEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.cmdFEnabled) { isCmdFEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.cmdSpaceEnabled) { isCmdSpaceEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.cmdTEnabled) { isCmdTEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.cmdNEnabled) { isCmdNEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.cmdShiftWEnabled) { isCmdShiftWEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.cmdShiftTEnabled) { isCmdShiftTEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.closeWindowEnabled) { isCloseWindowEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.fillScreenEnabled) { isFillScreenEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.almostMaximizeEnabled) { isAlmostMaximizeEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.reasonableSizeEnabled) { isReasonableSizeEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.makeLargerEnabled) { isMakeLargerEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.makeSmallerEnabled) { isMakeSmallerEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.moveNextDesktopEnabled) { isMoveNextDesktopEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.movePreviousDesktopEnabled) { isMovePreviousDesktopEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.keyboardNavigation) { isKeyboardNavigationEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.dockActionsOutsideMC) { isDockActionsOutsideMCEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.gesturesEnabled) { isGesturesEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.pinchInEnabled) { isPinchInEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.pinchOutEnabled) { isPinchOutEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.swipeLeftEnabled) { isSwipeLeftEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.swipeRightEnabled) { isSwipeRightEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.swipeDownEnabled) { isSwipeDownEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.swipeUpEnabled) { isSwipeUpEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.twoFingerDoubleTapEnabled) { isTwoFingerDoubleTapEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.autoEjectEnabled) { isAutoEjectEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.hapticFeedbackEnabled) { isHapticFeedbackEnabled = v }
        if let v = Self.loadBool(forKey: Self.Keys.cursorFeedbackEnabled) { isCursorFeedbackEnabled = v }
        if let dict = UserDefaults.standard.dictionary(forKey: Self.Keys.gestureActions) as? [String: String] {
            for (k, v) in dict {
                if let kind = GestureKind(rawValue: k), let action = GestureAction(rawValue: v) {
                    gestureActions[kind] = action
                }
            }
        }
        if let dict = UserDefaults.standard.dictionary(forKey: Self.Keys.cmdGestureActions) as? [String: String] {
            for (k, v) in dict {
                if let kind = GestureKind(rawValue: k), let action = GestureAction(rawValue: v) {
                    cmdGestureActions[kind] = action
                }
            }
        }
    }

    /// Lookup respecting ⌘ modifier.
    func action(for kind: GestureKind, isCmd: Bool) -> GestureAction {
        if isCmd { return cmdGestureActions[kind] ?? GestureDefaults.action(for: kind, isCmd: true) }
        return gestureActions[kind] ?? GestureDefaults.action(for: kind, isCmd: false)
    }

    mutating func setAction(_ action: GestureAction, for kind: GestureKind, isCmd: Bool) {
        if isCmd { cmdGestureActions[kind] = action } else { gestureActions[kind] = action }
    }

    mutating func resetGestureMappings() {
        gestureActions = GestureDefaults.plainDefaults
        cmdGestureActions = GestureDefaults.cmdDefaults
    }

    /// Resets all toggles to defaults (single source of truth for Restore Defaults).
    mutating func restoreDefaults() {
        isCmdWEnabled = true
        isCmdQEnabled = true
        isCmdMEnabled = true
        isCmdHEnabled = true
        isCmdFEnabled = false
        isCmdSpaceEnabled = true
        isCmdTEnabled = false
        isCmdNEnabled = false
        isCmdShiftWEnabled = false
        isCmdShiftTEnabled = false
        isCloseWindowEnabled = false
        isFillScreenEnabled = false
        isAlmostMaximizeEnabled = false
        isReasonableSizeEnabled = false
        isMakeLargerEnabled = false
        isMakeSmallerEnabled = false
        isMoveNextDesktopEnabled = false
        isMovePreviousDesktopEnabled = false
        isGesturesEnabled = true
        isPinchInEnabled = true
        isPinchOutEnabled = true
        isSwipeLeftEnabled = true
        isSwipeRightEnabled = true
        isSwipeDownEnabled = true
        isSwipeUpEnabled = true
        isTwoFingerDoubleTapEnabled = true
        isAutoEjectEnabled = true
        isDockActionsOutsideMCEnabled = true
        isKeyboardNavigationEnabled = true
        isHapticFeedbackEnabled = true
        isCursorFeedbackEnabled = true
        resetGestureMappings()
    }

    // MARK: - Helpers

    private static func loadBool(forKey key: String) -> Bool? {
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func persistGestureActions() {
        let dict = Dictionary(uniqueKeysWithValues: gestureActions.map { ($0.key.rawValue, $0.value.rawValue) })
        UserDefaults.standard.set(dict, forKey: Self.Keys.gestureActions)
    }

    private func persistCmdGestureActions() {
        let dict = Dictionary(uniqueKeysWithValues: cmdGestureActions.map { ($0.key.rawValue, $0.value.rawValue) })
        UserDefaults.standard.set(dict, forKey: Self.Keys.cmdGestureActions)
    }

    private enum Keys {
        static let cmdWEnabled = "mcsc.shortcuts.cmdW.enabled"
        static let cmdQEnabled = "mcsc.shortcuts.cmdQ.enabled"
        static let cmdMEnabled = "mcsc.shortcuts.cmdM.enabled"
        static let cmdHEnabled = "mcsc.shortcuts.cmdH.enabled"
        static let cmdFEnabled = "mcsc.shortcuts.cmdF.enabled"
        static let cmdSpaceEnabled = "mcsc.shortcuts.cmdSpace.enabled"
        static let cmdTEnabled = "mcsc.shortcuts.cmdT.enabled"
        static let cmdNEnabled = "mcsc.shortcuts.cmdN.enabled"
        static let cmdShiftWEnabled = "mcsc.shortcuts.cmdShiftW.enabled"
        static let cmdShiftTEnabled = "mcsc.shortcuts.cmdShiftT.enabled"
        static let closeWindowEnabled = "mcsc.shortcuts.closeWindow.enabled"
        static let fillScreenEnabled = "mcsc.shortcuts.fillScreen.enabled"
        static let almostMaximizeEnabled = "mcsc.shortcuts.almostMaximize.enabled"
        static let reasonableSizeEnabled = "mcsc.shortcuts.reasonableSize.enabled"
        static let makeLargerEnabled = "mcsc.shortcuts.makeLarger.enabled"
        static let makeSmallerEnabled = "mcsc.shortcuts.makeSmaller.enabled"
        static let moveNextDesktopEnabled = "mcsc.shortcuts.moveNextDesktop.enabled"
        static let movePreviousDesktopEnabled = "mcsc.shortcuts.movePreviousDesktop.enabled"
        static let keyboardNavigation = "mcsc.keyboardNavigation.enabled"
        static let dockActionsOutsideMC = "mcsc.dockActionsOutsideMC.enabled"
        static let gesturesEnabled = "mcsc.gestures.enabled"
        static let pinchInEnabled = "mcsc.gestures.pinchIn.enabled"
        static let pinchOutEnabled = "mcsc.gestures.pinchOut.enabled"
        static let swipeLeftEnabled = "mcsc.gestures.swipeLeft.enabled"
        static let swipeRightEnabled = "mcsc.gestures.swipeRight.enabled"
        static let swipeDownEnabled = "mcsc.gestures.swipeDown.enabled"
        static let swipeUpEnabled = "mcsc.gestures.swipeUp.enabled"
        static let twoFingerDoubleTapEnabled = "mcsc.gestures.twoFingerDoubleTap.enabled"
        static let autoEjectEnabled = "mcsc.autoEject.enabled"
        static let hapticFeedbackEnabled = "mcsc.feedback.haptics.enabled"
        static let cursorFeedbackEnabled = "mcsc.feedback.cursor.enabled"
        static let gestureActions = "mcsc.gestures.actions"
        static let cmdGestureActions = "mcsc.gestures.cmdActions"
    }
}
