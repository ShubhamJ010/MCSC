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
        if UserDefaults.standard.object(forKey: Self.Keys.cmdWEnabled) != nil {
            isCmdWEnabled = UserDefaults.standard.bool(forKey: Self.Keys.cmdWEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.cmdQEnabled) != nil {
            isCmdQEnabled = UserDefaults.standard.bool(forKey: Self.Keys.cmdQEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.cmdMEnabled) != nil {
            isCmdMEnabled = UserDefaults.standard.bool(forKey: Self.Keys.cmdMEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.cmdHEnabled) != nil {
            isCmdHEnabled = UserDefaults.standard.bool(forKey: Self.Keys.cmdHEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.cmdFEnabled) != nil {
            isCmdFEnabled = UserDefaults.standard.bool(forKey: Self.Keys.cmdFEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.cmdSpaceEnabled) != nil {
            isCmdSpaceEnabled = UserDefaults.standard.bool(forKey: Self.Keys.cmdSpaceEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.cmdTEnabled) != nil {
            isCmdTEnabled = UserDefaults.standard.bool(forKey: Self.Keys.cmdTEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.cmdNEnabled) != nil {
            isCmdNEnabled = UserDefaults.standard.bool(forKey: Self.Keys.cmdNEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.cmdShiftWEnabled) != nil {
            isCmdShiftWEnabled = UserDefaults.standard.bool(forKey: Self.Keys.cmdShiftWEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.cmdShiftTEnabled) != nil {
            isCmdShiftTEnabled = UserDefaults.standard.bool(forKey: Self.Keys.cmdShiftTEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.keyboardNavigation) != nil {
            isKeyboardNavigationEnabled = UserDefaults.standard.bool(forKey: Self.Keys.keyboardNavigation)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.dockActionsOutsideMC) != nil {
            isDockActionsOutsideMCEnabled = UserDefaults.standard.bool(forKey: Self.Keys.dockActionsOutsideMC)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.gesturesEnabled) != nil {
            isGesturesEnabled = UserDefaults.standard.bool(forKey: Self.Keys.gesturesEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.pinchInEnabled) != nil {
            isPinchInEnabled = UserDefaults.standard.bool(forKey: Self.Keys.pinchInEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.pinchOutEnabled) != nil {
            isPinchOutEnabled = UserDefaults.standard.bool(forKey: Self.Keys.pinchOutEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.swipeLeftEnabled) != nil {
            isSwipeLeftEnabled = UserDefaults.standard.bool(forKey: Self.Keys.swipeLeftEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.swipeRightEnabled) != nil {
            isSwipeRightEnabled = UserDefaults.standard.bool(forKey: Self.Keys.swipeRightEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.swipeDownEnabled) != nil {
            isSwipeDownEnabled = UserDefaults.standard.bool(forKey: Self.Keys.swipeDownEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.swipeUpEnabled) != nil {
            isSwipeUpEnabled = UserDefaults.standard.bool(forKey: Self.Keys.swipeUpEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.twoFingerDoubleTapEnabled) != nil {
            isTwoFingerDoubleTapEnabled = UserDefaults.standard.bool(forKey: Self.Keys.twoFingerDoubleTapEnabled)
        }
        if UserDefaults.standard.object(forKey: Self.Keys.autoEjectEnabled) != nil {
            isAutoEjectEnabled = UserDefaults.standard.bool(forKey: Self.Keys.autoEjectEnabled)
        }
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
        static let gestureActions = "mcsc.gestures.actions"
        static let cmdGestureActions = "mcsc.gestures.cmdActions"
    }
}
