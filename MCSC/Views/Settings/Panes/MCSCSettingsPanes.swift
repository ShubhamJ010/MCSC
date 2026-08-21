import Cocoa

/// Base class for MCSC settings panes: holds the view model and refreshes
/// checkbox states every time the settings window is shown.
class MCSCSettingsPane: SettingsPaneViewController {
    let viewModel: ShortcutViewModel

    init(viewModel: ShortcutViewModel,
         tabName: String,
         tabImage: NSImage?,
         tabIdentifier: String) {
        self.viewModel = viewModel
        super.init(tabName: tabName,
                   tabImage: tabImage,
                   tabIdentifier: tabIdentifier)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Re-read state from the view model into the controls.
    func refresh() {}

    /// The narrowest width every pane is laid out for. Matches the clone demo's 500pt (ref: DemoViewControllers.swift:56).
    static let minimumPaneWidth: CGFloat = 500
}

// MARK: - General

final class GeneralSettingsPane: MCSCSettingsPane {
    private var launchAtLoginCheckbox: NSButton!
    private var autoEjectCheckbox: NSButton!
    private var dockActionsCheckbox: NSButton!
    private var hoverCloseCheckbox: NSButton!

    override func loadView() {
        view = NSView()

        let layoutView = SettingsLayoutView()
        layoutView.install(in: view)

        let startup = layoutView.addColumnSection(label: "Startup")
        launchAtLoginCheckbox = startup.addCheckbox(title: "Launch at Login",
                                                    target: self,
                                                    action: #selector(toggleLaunchAtLogin(_:)))

        let behavior = layoutView.addColumnSection(label: "Behavior", itemColumnMaximumWidth: 340)
        autoEjectCheckbox = behavior.addCheckbox(title: "Auto-Eject Mounted Volumes",
                                                 target: self,
                                                 action: #selector(toggleAutoEject(_:)))
        dockActionsCheckbox = behavior.addCheckbox(title: "Dock Gestures & Shortcuts (outside Mission Control)",
                                                   target: self,
                                                   action: #selector(toggleDockActions(_:)))
        behavior.addDescriptionLabel("Applies gestures and Cmd-shortcuts while hovering Dock icons outside Mission Control.")
        hoverCloseCheckbox = behavior.addCheckbox(title: "Hover Close Button",
                                                  target: self,
                                                  action: #selector(toggleHoverClose(_:)))
        behavior.addDescriptionLabel("Shows a close button when hovering window thumbnails in Mission Control. Click to close; Cmd = quit, Option = minimize.")

        layoutView.addSeparatorSection()

        layoutView.addButtonSection(title: "Restore Defaults",
                                    alignment: .trailing,
                                    widthMode: .contentBlock,
                                    target: self,
                                    action: #selector(restoreDefaults(_:)))

        sizePaneToFitContent(minimumWidth: Self.minimumPaneWidth)
        refresh()
    }

    override func refresh() {
        launchAtLoginCheckbox?.state = viewModel.isLaunchAtLoginEnabled ? .on : .off
        autoEjectCheckbox?.state = viewModel.isAutoEjectEnabled ? .on : .off
        dockActionsCheckbox?.state = viewModel.isDockActionsOutsideMCEnabled ? .on : .off
        hoverCloseCheckbox?.state = viewModel.isHoverCloseButtonEnabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        viewModel.toggleLaunchAtLogin()
        sender.state = viewModel.isLaunchAtLoginEnabled ? .on : .off
    }

    @objc private func toggleAutoEject(_ sender: NSButton) {
        viewModel.isAutoEjectEnabled.toggle()
        sender.state = viewModel.isAutoEjectEnabled ? .on : .off
    }

    @objc private func toggleDockActions(_ sender: NSButton) {
        viewModel.isDockActionsOutsideMCEnabled.toggle()
        sender.state = viewModel.isDockActionsOutsideMCEnabled ? .on : .off
    }

    @objc private func toggleHoverClose(_ sender: NSButton) {
        viewModel.isHoverCloseButtonEnabled.toggle()
        sender.state = viewModel.isHoverCloseButtonEnabled ? .on : .off
    }

    @objc private func restoreDefaults(_ sender: NSButton) {
        viewModel.isAutoEjectEnabled = true
        viewModel.isDockActionsOutsideMCEnabled = true
        viewModel.isHoverCloseButtonEnabled = true
        refreshAllPanes()
    }
}

// MARK: - Shortcuts

final class ShortcutSettingsPane: MCSCSettingsPane {
    private var keyboardNavCheckbox: NSButton!
    private var cmdWCheckbox: NSButton!
    private var cmdQCheckbox: NSButton!
    private var cmdMCheckbox: NSButton!
    private var cmdHCheckbox: NSButton!
    private var cmdSpaceCheckbox: NSButton!

    override func loadView() {
        view = NSView()

        let layoutView = SettingsLayoutView()
        layoutView.install(in: view)

        let keyboardNav = layoutView.addColumnSection(label: "Mission Control", itemColumnMaximumWidth: 340)
        keyboardNavCheckbox = keyboardNav.addCheckbox(title: "Enable Keyboard Navigation (Tab / Return)",
                                                      target: self,
                                                      action: #selector(toggleKeyboardNav(_:)))
        keyboardNav.addDescriptionLabel("Tab / Shift+Tab cycle the selection between visible thumbnails row-major (wrap-around). Return activates the selected window. Typing filters windows fuzzy (e.g. “code” matches Xcode + Code) and Tab cycles only the filtered matches.")

        layoutView.addSeparatorSection()

        let appShortcuts = layoutView.addColumnSection(label: "App Shortcuts", itemColumnMaximumWidth: 320)
        cmdWCheckbox = appShortcuts.addCheckbox(title: "Cmd + W — Close Front Window",
                                                target: self,
                                                action: #selector(toggleCmdW(_:)))
        cmdQCheckbox = appShortcuts.addCheckbox(title: "Cmd + Q — Quit App",
                                                target: self,
                                                action: #selector(toggleCmdQ(_:)))
        cmdMCheckbox = appShortcuts.addCheckbox(title: "Cmd + M — Minimize Window",
                                                target: self,
                                                action: #selector(toggleCmdM(_:)))
        cmdHCheckbox = appShortcuts.addCheckbox(title: "Cmd + H — Hide App",
                                                target: self,
                                                action: #selector(toggleCmdH(_:)))
        cmdSpaceCheckbox = appShortcuts.addCheckbox(title: "Cmd + Space Fix (Mission Control)",
                                                    target: self,
                                                    action: #selector(toggleCmdSpace(_:)))

        sizePaneToFitContent(minimumWidth: Self.minimumPaneWidth)
        refresh()
    }

    override func refresh() {
        keyboardNavCheckbox?.state = viewModel.isKeyboardNavigationEnabled ? .on : .off
        cmdWCheckbox?.state = viewModel.isCmdWEnabled ? .on : .off
        cmdQCheckbox?.state = viewModel.isCmdQEnabled ? .on : .off
        cmdMCheckbox?.state = viewModel.isCmdMEnabled ? .on : .off
        cmdHCheckbox?.state = viewModel.isCmdHEnabled ? .on : .off
        cmdSpaceCheckbox?.state = viewModel.isCmdSpaceEnabled ? .on : .off
    }

    @objc private func toggleKeyboardNav(_ sender: NSButton) {
        viewModel.isKeyboardNavigationEnabled.toggle()
        sender.state = viewModel.isKeyboardNavigationEnabled ? .on : .off
    }

    @objc private func toggleCmdW(_ sender: NSButton) {
        viewModel.isCmdWEnabled.toggle()
        sender.state = viewModel.isCmdWEnabled ? .on : .off
    }

    @objc private func toggleCmdQ(_ sender: NSButton) {
        viewModel.isCmdQEnabled.toggle()
        sender.state = viewModel.isCmdQEnabled ? .on : .off
    }

    @objc private func toggleCmdM(_ sender: NSButton) {
        viewModel.isCmdMEnabled.toggle()
        sender.state = viewModel.isCmdMEnabled ? .on : .off
    }

    @objc private func toggleCmdH(_ sender: NSButton) {
        viewModel.isCmdHEnabled.toggle()
        sender.state = viewModel.isCmdHEnabled ? .on : .off
    }

    @objc private func toggleCmdSpace(_ sender: NSButton) {
        viewModel.isCmdSpaceEnabled.toggle()
        sender.state = viewModel.isCmdSpaceEnabled ? .on : .off
    }

    @objc private func restoreDefaults(_ sender: NSButton) {
        viewModel.isKeyboardNavigationEnabled = true
        viewModel.isCmdWEnabled = true
        viewModel.isCmdQEnabled = true
        viewModel.isCmdMEnabled = true
        viewModel.isCmdHEnabled = true
        viewModel.isCmdSpaceEnabled = true
        refreshAllPanes()
    }
}

// MARK: - Gestures

final class GestureSettingsPane: MCSCSettingsPane {
    private var gesturesMasterCheckbox: NSButton!
    private var pinchInCheckbox: NSButton!
    private var pinchOutCheckbox: NSButton!
    private var swipeLeftCheckbox: NSButton!
    private var swipeRightCheckbox: NSButton!
    private var swipeDownCheckbox: NSButton!
    private var swipeUpCheckbox: NSButton!
    private var twoFingerTapCheckbox: NSButton!

    override func loadView() {
        view = NSView()

        let layoutView = SettingsLayoutView()
        layoutView.install(in: view)

        let master = layoutView.addCheckboxSection(title: "Enable Gestures",
                                                   description: "Master switch for all trackpad gesture recognition. Individual gestures can be toggled below.",
                                                   target: self,
                                                   action: #selector(toggleGestures(_:)))
        gesturesMasterCheckbox = master.checkbox

        layoutView.addSeparatorSection()

        let trackpad = layoutView.addColumnSection(label: "Trackpad", itemColumnMaximumWidth: 380)
        pinchInCheckbox = trackpad.addCheckbox(title: "Pinch In → Close / Quit",
                                               target: self,
                                               action: #selector(togglePinchIn(_:)))
        pinchOutCheckbox = trackpad.addCheckbox(title: "Pinch Out → Fullscreen / New Window",
                                                target: self,
                                                action: #selector(togglePinchOut(_:)))
        swipeLeftCheckbox = trackpad.addCheckbox(title: "Swipe Left → Close Tab (Cmd: Close All Cmd⌥W)",
                                                 target: self,
                                                 action: #selector(toggleSwipeLeft(_:)))
        swipeRightCheckbox = trackpad.addCheckbox(title: "Swipe Right → Reopen Tab (Cmd: New Window Cmd⌥N)",
                                                  target: self,
                                                  action: #selector(toggleSwipeRight(_:)))
        swipeDownCheckbox = trackpad.addCheckbox(title: "Swipe Down → Make Larger (+33%)",
                                                 target: self,
                                                 action: #selector(toggleSwipeDown(_:)))
        swipeUpCheckbox = trackpad.addCheckbox(title: "Swipe Up → Minimize",
                                               target: self,
                                               action: #selector(toggleSwipeUp(_:)))
        twoFingerTapCheckbox = trackpad.addCheckbox(title: "2-Finger Double Tap → Resize",
                                                    target: self,
                                                    action: #selector(toggleTwoFingerDoubleTap(_:)))

        sizePaneToFitContent(minimumWidth: Self.minimumPaneWidth)
        refresh()
    }

    override func refresh() {
        gesturesMasterCheckbox?.state = viewModel.isGesturesEnabled ? .on : .off
        pinchInCheckbox?.state = viewModel.isPinchInEnabled ? .on : .off
        pinchOutCheckbox?.state = viewModel.isPinchOutEnabled ? .on : .off
        swipeLeftCheckbox?.state = viewModel.isSwipeLeftEnabled ? .on : .off
        swipeRightCheckbox?.state = viewModel.isSwipeRightEnabled ? .on : .off
        swipeDownCheckbox?.state = viewModel.isSwipeDownEnabled ? .on : .off
        swipeUpCheckbox?.state = viewModel.isSwipeUpEnabled ? .on : .off
        twoFingerTapCheckbox?.state = viewModel.isTwoFingerDoubleTapEnabled ? .on : .off
    }

    @objc private func toggleGestures(_ sender: NSButton) {
        viewModel.isGesturesEnabled.toggle()
        sender.state = viewModel.isGesturesEnabled ? .on : .off
    }

    @objc private func togglePinchIn(_ sender: NSButton) {
        viewModel.isPinchInEnabled.toggle()
        sender.state = viewModel.isPinchInEnabled ? .on : .off
    }

    @objc private func togglePinchOut(_ sender: NSButton) {
        viewModel.isPinchOutEnabled.toggle()
        sender.state = viewModel.isPinchOutEnabled ? .on : .off
    }

    @objc private func toggleSwipeLeft(_ sender: NSButton) {
        viewModel.isSwipeLeftEnabled.toggle()
        sender.state = viewModel.isSwipeLeftEnabled ? .on : .off
    }

    @objc private func toggleSwipeRight(_ sender: NSButton) {
        viewModel.isSwipeRightEnabled.toggle()
        sender.state = viewModel.isSwipeRightEnabled ? .on : .off
    }

    @objc private func toggleSwipeDown(_ sender: NSButton) {
        viewModel.isSwipeDownEnabled.toggle()
        sender.state = viewModel.isSwipeDownEnabled ? .on : .off
    }

    @objc private func toggleSwipeUp(_ sender: NSButton) {
        viewModel.isSwipeUpEnabled.toggle()
        sender.state = viewModel.isSwipeUpEnabled ? .on : .off
    }

    @objc private func toggleTwoFingerDoubleTap(_ sender: NSButton) {
        viewModel.isTwoFingerDoubleTapEnabled.toggle()
        sender.state = viewModel.isTwoFingerDoubleTapEnabled ? .on : .off
    }

    @objc private func restoreDefaults(_ sender: NSButton) {
        viewModel.isGesturesEnabled = true
        viewModel.isPinchInEnabled = true
        viewModel.isPinchOutEnabled = true
        viewModel.isSwipeLeftEnabled = true
        viewModel.isSwipeRightEnabled = true
        viewModel.isSwipeDownEnabled = true
        viewModel.isSwipeUpEnabled = true
        viewModel.isTwoFingerDoubleTapEnabled = true
        refreshAllPanes()
    }
}

// MARK: - Shared helpers

extension MCSCSettingsPane {
    /// Re-syncs every visible pane after a Restore Defaults action.
    func refreshAllPanes() {
        tabViewController?.panes.forEach { ($0 as? MCSCSettingsPane)?.refresh() }
    }
}
