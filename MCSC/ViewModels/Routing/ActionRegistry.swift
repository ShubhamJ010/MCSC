import Cocoa

/// Container holding shared instances of all window, app, tab, and tiling actions.
final class ActionRegistry {
    let moveNextDesktopAction: MoveWindowToDesktopAction
    let movePreviousDesktopAction: MoveWindowToDesktopAction
    let closeAction = CloseWindowAction()
    let closeTabAction = CloseTabAction()
    let closeTabAppAction = CloseTabAppAction()
    let reopenTabAction = ReopenTabAction()
    let reopenTabAppAction = ReopenTabAppAction()
    let closeAppAction = CloseAppAction()
    let minimizeAction = MinimizeWindowAction()
    let hideAction = HideApplicationAction()
    let forceQuitAction = ForceQuitAction()
    let minimizeAppAction = MinimizeAppAction()
    let forceQuitAppAction = ForceQuitAppAction()
    let makeLargerAction = MakeLargerAction()
    let fillScreenAction = FillScreenAction()
    let reasonableSizeAction = ReasonableSizeAction()
    let almostMaximizeAction = AlmostMaximizeAction()
    let closeAllTabsAction = CloseAllTabsAction()
    let newWindowAction = NewWindowAction()
    let newTabAction = NewTabAction()
    let toggleFullscreenAction = ToggleFullscreenAction()
    let toggleFullscreenAppAction = ToggleFullscreenAppAction()
    let fillScreenAppAction = FillScreenAppAction()
    let makeLargerAppAction = MakeLargerAppAction()
    let reasonableSizeAppAction = ReasonableSizeAppAction()
    let almostMaximizeAppAction = AlmostMaximizeAppAction()
    let ejectVolumeAction = EjectVolumeAction()

    /// - Parameter isMissionControlActiveProvider: lets desktop-navigation
    ///   actions know when Mission Control must be dismissed before dragging.
    ///   Defaults to `false` (tests, plain construction).
    init(isMissionControlActiveProvider: @escaping () -> Bool = { false }) {
        self.moveNextDesktopAction = MoveWindowToDesktopAction(
            direction: .next,
            isMissionControlActiveProvider: isMissionControlActiveProvider)
        self.movePreviousDesktopAction = MoveWindowToDesktopAction(
            direction: .previous,
            isMissionControlActiveProvider: isMissionControlActiveProvider)
    }
}
