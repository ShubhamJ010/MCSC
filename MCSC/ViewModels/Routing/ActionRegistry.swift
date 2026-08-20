import Cocoa

/// Container holding shared instances of all window, app, tab, and tiling actions.
final class ActionRegistry {
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
    let ejectVolumeAction = EjectVolumeAction()
}
