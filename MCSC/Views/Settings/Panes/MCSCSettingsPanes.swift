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
    /// Demo General pane caps the item column — keeps pop-ups from stretching edge-to-edge.
    private static let itemColumnMaximumWidth: CGFloat = 220

    private var layoutView: SettingsLayoutView?
    private var gesturesMasterCheckbox: NSButton!

    private struct GestureRow {
        let kind: GestureKind
        let section: SettingsColumnSectionView
        let actionPopup: NSPopUpButton
        let cmdActionPopup: NSPopUpButton
        let enableSwitch: NSSwitch
    }
    private var gestureRows: [GestureRow] = []

    override func loadView() {
        view = NSView()
        buildSections()
        sizePaneToFitContent(minimumWidth: Self.minimumPaneWidth)
        refresh()
    }

    private func buildSections() {
        let layoutView = SettingsLayoutView()
        layoutView.install(in: view)
        self.layoutView = layoutView

        // Master switch — full-width checkbox with description, like DemoViewControllers General "Startup"
        let master = layoutView.addCheckboxSection(title: "Enable Gestures",
                                                   description: "Master switch for all trackpad gesture recognition. Individual gestures can be toggled below.",
                                                   identifier: .init("Master"),
                                                   target: self,
                                                   action: #selector(toggleGestures(_:)))
        gesturesMasterCheckbox = master.checkbox

        layoutView.addSeparatorSection(identifier: .init("Sep.Master"))

        // One column section per gesture — label in the label column, popup + checkbox accessory in the item column,
        // ⌘ variant as a second stacked item. Splitting into Pinch / Swipe / Tap groups with
        // separators mirrors the demo's section grouping and breaks up the 7-row wall (Guide/#sections).
        var gestureIndex = 0
        func addGestureRow(kind: GestureKind) {
            let isFirst = (gestureIndex == 0)
            let section = layoutView.addColumnSection(label: kind.displayName,
                                                      itemColumnMaximumWidth: isFirst ? Self.itemColumnMaximumWidth : nil,
                                                      identifier: .init(kind.rawValue))

            // Primary action — .small matches the ⌘ row so the two pop-ups share a baseline grid
            let popup = section.addPopUpButton(controlSize: .small, target: self, action: #selector(actionChanged(_:)))
            for action in GestureAction.allCases {
                popup.addItem(withTitle: action.menuTitle)
                popup.lastItem?.representedObject = action.rawValue
            }
            popup.tag = gestureIndex

            // Toggle — wire-frame demo uses DemoSwitch (Toggle .switch); NSSwitch is the AppKit
            // equivalent without SwiftUI overhead (fits memory ceiling). Mirrors
            // DemoViewControllers Wireframes section: trailing accessory, centerY aligned.
            let toggle = NSSwitch()
            toggle.target = self
            toggle.action = #selector(toggleGestureEnabled(_:))
            toggle.controlSize = NSControl.ControlSize.small
            toggle.tag = gestureIndex
            section.addAccessoryView(toggle, to: popup, spacing: 12)

            // Small breathing gap between the plain and ⌘ rows — ~2mm less than before:
            // keep visual separation but reduce by ~2pt. Gap view (2pt) + itemSpacing (6pt) ≈ 8pt.
            let gapView = NSView(frame: .zero)
            gapView.translatesAutoresizingMaskIntoConstraints = false
            gapView.heightAnchor.constraint(equalToConstant: 2).isActive = true
            section.addCustomView(gapView, verticalAlignment: .centerY)
            // gap takes no column-width vote (clear color, non-contributing) — we lower its hugging
            // so it doesn't widen the item column
            gapView.setContentHuggingPriority(.defaultLow, for: .horizontal)
            gapView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            // ⌘ variant — second stacked item, same .small size, dimmed secondary label
            let cmdRow = NSStackView()
            cmdRow.orientation = .horizontal
            cmdRow.spacing = 4
            cmdRow.alignment = .centerY

            let cmdLabel = NSTextField(labelWithString: "⌘")
            cmdLabel.font = .boldSystemFont(ofSize: 14)
            cmdLabel.textColor = .secondaryLabelColor
            cmdLabel.setContentHuggingPriority(.required, for: .horizontal)

            let cmdPopup = NSPopUpButton(frame: .zero, pullsDown: false)
            cmdPopup.controlSize = .small
            SettingsSectionView.applyControlSize(.small, to: cmdPopup)
            cmdPopup.target = self
            cmdPopup.action = #selector(cmdActionChanged(_:))
            cmdPopup.tag = gestureIndex
            for action in GestureAction.allCases {
                cmdPopup.addItem(withTitle: action.menuTitle)
                cmdPopup.lastItem?.representedObject = action.rawValue
            }

            cmdRow.addArrangedSubview(cmdLabel)
            cmdRow.addArrangedSubview(cmdPopup)
            cmdPopup.setContentHuggingPriority(.defaultHigh, for: .horizontal)

            section.addCustomView(cmdRow, verticalAlignment: .centerY)

            gestureRows.append(GestureRow(kind: kind, section: section, actionPopup: popup, cmdActionPopup: cmdPopup, enableSwitch: toggle))
            gestureIndex += 1
        }

        // Group: Pinch (2)
        addGestureRow(kind: .pinchIn)
        addGestureRow(kind: .pinchOut)
        layoutView.addSeparatorSection(identifier: .init("Sep.Pinch"))
        // Group: Swipe (4) — the bulk of the pane
        addGestureRow(kind: .swipeLeft)
        addGestureRow(kind: .swipeRight)
        addGestureRow(kind: .swipeDown)
        addGestureRow(kind: .swipeUp)
        layoutView.addSeparatorSection(identifier: .init("Sep.Swipe"))
        // Group: Tap (1)
        addGestureRow(kind: .twoFingerDoubleTap)

        layoutView.addSeparatorSection(identifier: .init("Sep.Restore"))

        layoutView.addButtonSection(title: "Restore Defaults",
                                    controlSize: .regular,
                                    alignment: .trailing,
                                    widthMode: .contentBlock,
                                    identifier: .init("RestoreDefaults"),
                                    target: self,
                                    action: #selector(restoreDefaults(_:)))
    }

    override func refresh() {
        gesturesMasterCheckbox?.state = viewModel.isGesturesEnabled ? .on : .off

        let masterOn = viewModel.isGesturesEnabled
        for row in gestureRows {
            let kindEnabled: Bool = {
                switch row.kind {
                case .pinchIn: return viewModel.isPinchInEnabled
                case .pinchOut: return viewModel.isPinchOutEnabled
                case .swipeLeft: return viewModel.isSwipeLeftEnabled
                case .swipeRight: return viewModel.isSwipeRightEnabled
                case .swipeDown: return viewModel.isSwipeDownEnabled
                case .swipeUp: return viewModel.isSwipeUpEnabled
                case .twoFingerDoubleTap: return viewModel.isTwoFingerDoubleTapEnabled
                }
            }()
            let rowEnabled = masterOn && kindEnabled
            row.enableSwitch.state = kindEnabled ? .on : .off
            row.enableSwitch.isEnabled = masterOn
            row.actionPopup.isEnabled = rowEnabled
            row.cmdActionPopup.isEnabled = rowEnabled

            let plainAction = viewModel.gestureAction(for: row.kind, isCmd: false)
            let cmdAction = viewModel.gestureAction(for: row.kind, isCmd: true)
            if let idx = row.actionPopup.itemArray.firstIndex(where: { ($0.representedObject as? String) == plainAction.rawValue }) {
                row.actionPopup.selectItem(at: idx)
            }
            if let idx = row.cmdActionPopup.itemArray.firstIndex(where: { ($0.representedObject as? String) == cmdAction.rawValue }) {
                row.cmdActionPopup.selectItem(at: idx)
            }
        }
    }

    private func setGestureEnabled(_ kind: GestureKind, enabled: Bool) {
        switch kind {
        case .pinchIn: viewModel.isPinchInEnabled = enabled
        case .pinchOut: viewModel.isPinchOutEnabled = enabled
        case .swipeLeft: viewModel.isSwipeLeftEnabled = enabled
        case .swipeRight: viewModel.isSwipeRightEnabled = enabled
        case .swipeDown: viewModel.isSwipeDownEnabled = enabled
        case .swipeUp: viewModel.isSwipeUpEnabled = enabled
        case .twoFingerDoubleTap: viewModel.isTwoFingerDoubleTapEnabled = enabled
        }
    }

    @objc private func toggleGestures(_ sender: NSButton) {
        viewModel.isGesturesEnabled.toggle()
        sender.state = viewModel.isGesturesEnabled ? .on : .off
        refresh()
    }

    @objc private func toggleGestureEnabled(_ sender: NSSwitch) {
        guard let kind = GestureKind.allCases[safe: sender.tag] else { return }
        let enabled = (sender.state == .on)
        setGestureEnabled(kind, enabled: enabled)
        refresh()
    }

    @objc private func actionChanged(_ sender: NSPopUpButton) {
        guard let kind = GestureKind.allCases[safe: sender.tag],
              let raw = sender.selectedItem?.representedObject as? String,
              let action = GestureAction(rawValue: raw) else { return }
        viewModel.setGestureAction(action, for: kind, isCmd: false)
    }

    @objc private func cmdActionChanged(_ sender: NSPopUpButton) {
        guard let kind = GestureKind.allCases[safe: sender.tag],
              let raw = sender.selectedItem?.representedObject as? String,
              let action = GestureAction(rawValue: raw) else { return }
        viewModel.setGestureAction(action, for: kind, isCmd: true)
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
        viewModel.resetGestureMappings()
        refreshAllPanes()
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Shared helpers

extension MCSCSettingsPane {
    /// Re-syncs every visible pane after a Restore Defaults action.
    func refreshAllPanes() {
        tabViewController?.panes.forEach { ($0 as? MCSCSettingsPane)?.refresh() }
    }
}
