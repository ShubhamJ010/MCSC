import Cocoa

/// Settings window for Mission Control keyboard navigation.
///
/// The single "Keyboard Navigation (Tab / Return)" toggle in
/// `ShortcutConfiguration` (persisted via `UserDefaults`) gates all of
/// Tab / Shift+Tab / Return / arrow-key / typing navigation in
/// `MissionControlHoverService` and `WindowSearchSession`. When enabled
/// (default on):
///  - Typing filters windows fuzzy (`code` → `Code` + `Xcode`) via
///    `WindowSelectionEngine.fuzzyMatch` (prefix rank 0 beats substring rank 1);
///    Tab cycles only the filtered matches with wrap-around.
///  - With an empty query Tab cycles all visible thumbnails row-major
///    (top-to-bottom, left-to-right, 40 pt row tolerance) via
///    `rowMajorSorted`; arrow keys require an active query.
///  - Return / Enter activates the selected thumbnail and dismisses Mission
///    Control via `WindowActivationAction` synthetic click (50 ms dwell).
///  - The search pill / session persists until activation or Escape; the
///    2 s idle auto-clear is suppressed (see `resetIdleTimer()`).
/// When disabled, alphanumeric keys pass through and no HID tap is installed.
@MainActor
final class SettingsWindowController: NSWindowController {
    private let viewModel: ShortcutViewModel
    private var keyboardNavCheckbox: NSButton!

    init(viewModel: ShortcutViewModel) {
        self.viewModel = viewModel
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "MCSC Settings"
        win.center()
        win.isReleasedWhenClosed = false
        super.init(window: win)
        setupContent()
        sync()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupContent() {
        guard let win = window, let content = win.contentView else { return }

        let title = NSTextField(labelWithString: "Mission Control — Keyboard Navigation")
        title.font = .systemFont(ofSize: 13, weight: .semibold)

        let desc = NSTextField(wrappingLabelWithString:
            "Tab / Shift+Tab cycle the selection between visible thumbnails row-major (wrap-around). Return / Enter activates the selected window. When you type (e.g. “code” matches Xcode + Code) Tab cycles only the filtered matches and the search pill stays until activation.")
        desc.font = .systemFont(ofSize: 11)
        desc.textColor = .secondaryLabelColor

        keyboardNavCheckbox = NSButton(checkboxWithTitle: "Enable Keyboard Navigation (Tab / Return)", target: self, action: #selector(toggled(_:)))
        keyboardNavCheckbox.font = .systemFont(ofSize: 12)

        let stack = NSStackView(views: [title, desc, keyboardNavCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20)
        ])
    }

    private func sync() {
        keyboardNavCheckbox.state = viewModel.isKeyboardNavigationEnabled ? .on : .off
    }

    @objc private func toggled(_ sender: NSButton) {
        viewModel.isKeyboardNavigationEnabled = (sender.state == .on)
    }

    func show() {
        sync()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
