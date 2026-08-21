import Cocoa

extension NSTabViewItem {
    var settingsPaneViewController: SettingsPaneViewController? {
        viewController as? SettingsPaneViewController
    }
}

/// Tab view controller that manages the settings panes.
///
/// Uses the preferences-style toolbar, animates the window to each pane's
/// preferred size during transitions (through a blank loading view so the
/// toolbar and frame animate together), and updates the window title to the
/// active pane. Reimplemented from usagimaru/MacAppSettingsUI.
final class SettingsTabViewController: NSTabViewController {
    weak var settingsWindowController: SettingsWindowController?

    private var settingsWindow: SettingsWindow? {
        view.window as? SettingsWindow
    }

    /// The safe version of `selectedTabViewItemIndex` (-1 when empty).
    var selectedTabIndex: Int? {
        get {
            if !tabViewItems.isEmpty, 0 ..< tabViewItems.count ~= selectedTabViewItemIndex {
                return selectedTabViewItemIndex
            }
            return nil
        }
        set {
            super.selectedTabViewItemIndex = newValue ?? 0
            if let selectedTabViewItem {
                selectTab(with: selectedTabViewItem, animateIfPossible: false)
            }
        }
    }

    var selectedTabViewItem: NSTabViewItem? {
        guard let selectedTabIndex else { return nil }
        return tabViewItems[selectedTabIndex]
    }

    /// Blank view swapped in during pane transitions so the window frame and
    /// toolbar animate correctly. Tracks its container so the incoming pane
    /// is placed at the post-resize frame, not the pre-resize one.
    private let loadingView: NSView = {
        let view = NSView()
        view.autoresizingMask = [.width, .height]
        return view
    }()

    /// Minimum content width observed from the window after toolbar layout,
    /// used to clamp pane widths and prevent flicker on narrow panes.
    private var minimumContentWidth: CGFloat = 0

    private var tabViewSizes: [NSTabViewItem: NSSize] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        // The window title is managed manually to delay refresh until the transition ends.
        canPropagateSelectedChildViewControllerTitle = false
        tabStyle = .toolbar
    }

    /// Eagerly load all tab views.
    func loadAllTabs() {
        tabViewItems.forEach { _ = $0.viewController?.view }
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        if let selectedTabViewItem {
            selectTab(with: selectedTabViewItem, animateIfPossible: false)
        }

        // If a tab item exists but none is selected, select #0 (just in case).
        if !tabViewItems.isEmpty, selectedTabViewItem == nil {
            selectedTabViewItemIndex = 0
        }

        // Capture the minimum content width imposed by the toolbar layout.
        // After the first selectTab the window frame has been corrected by the
        // system; use it as a floor for all pane widths to prevent flicker.
        // Only re-cache tabs whose preferred size is already known, to avoid
        // triggering view loading for unvisited tabs.
        if minimumContentWidth == 0,
           let contentWidth = settingsWindow?.contentView?.frame.size.width,
           contentWidth > 0 {
            minimumContentWidth = contentWidth
            for item in tabViewItems
                where item.settingsPaneViewController?.preferredPaneSize != nil || item.viewController?
                .isViewLoaded == true {
                cacheTabViewSize(for: item)
            }
        }
    }

    // MARK: - Panes

    /// All panes in order.
    var panes: [SettingsPaneViewController] {
        tabViewItems.compactMap(\.settingsPaneViewController)
    }

    func set(panes: [SettingsPaneViewController]) {
        add(panes: panes)
        selectedTabIndex = 0
    }

    func add(panes: [SettingsPaneViewController]) {
        for pane in panes {
            pane.tabViewController = self
            let item = makeTabViewItem(from: pane)
            addTabViewItem(item)
        }
    }

    private func makeTabViewItem(from pane: SettingsPaneViewController) -> NSTabViewItem {
        let item = NSTabViewItem(viewController: pane)
        item.label = pane.tabName ?? ""
        item.image = pane.tabImage
        item.identifier = pane.tabIdentifier
        return item
    }

    // MARK: - Transition

    override func tabView(_ tabView: NSTabView, shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
        // Block toolbar interactions during transitions.
        if settingsWindow?.isWindowResizing == true {
            return false
        }
        return super.tabView(tabView, shouldSelect: tabViewItem)
    }

    override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, willSelect: tabViewItem)
        settingsWindow?.styleMask.remove(.resizable)
    }

    override func transition(from fromViewController: NSViewController,
                             to toViewController: NSViewController,
                             options _: NSViewController.TransitionOptions = [],
                             completionHandler completion: (() -> Void)? = nil) {
        guard let superview = fromViewController.view.superview, let selectedTabViewItem else {
            completion?()
            return
        }

        // A blank view is swapped in during the transition so the implicit
        // animations of the window frame and toolbar display correctly.
        loadingView.frame = fromViewController.view.frame
        superview.replaceSubview(fromViewController.view, with: loadingView)

        let pane = toViewController as? SettingsPaneViewController

        let performTransition = { [weak self] in
            guard let self else {
                completion?()
                return
            }

            let animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

            self.cacheTabViewSize(for: selectedTabViewItem)
            self.fitWindowSize(to: selectedTabViewItem, animateIfPossible: animates) {
                toViewController.view.frame = self.loadingView.frame
                superview.replaceSubview(self.loadingView, with: toViewController.view)
                toViewController.view.layoutSubtreeIfNeeded()

                if animates {
                    self.addDropInTransition(to: superview)
                }

                self.settingsWindow?.setWindowTitle(with: selectedTabViewItem)
                self.setWindowBehavior(with: selectedTabViewItem)

                completion?()
            }
        }

        // Load pane content lazily if not yet loaded.
        if let pane, !pane.isPaneContentLoaded {
            pane.loadPaneContent { [weak pane] in
                pane?.isPaneContentLoaded = true
                performTransition()
            }
        } else {
            performTransition()
        }
    }

    /// Drops the incoming pane in from above with a slight overshoot settle,
    /// in the style of native settings windows. Runs as a layer transition so
    /// NSTabView's own layout passes cannot snap the pane back mid-animation;
    /// Reduce Motion falls through to an instant swap.
    private func addDropInTransition(to containerView: NSView) {
        containerView.wantsLayer = true
        let transition = CATransition()
        transition.type = .moveIn
        // The incoming pane enters from the top edge, sliding down into place.
        transition.subtype = .fromTop
        transition.duration = 0.4
        // Control points past 1.0 push the progress past its target and back,
        // which turns the slide into a drop-and-settle bounce.
        transition.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1.3, 0.4, 1)
        containerView.layer?.add(transition, forKey: "paneDropIn")
    }

    // MARK: - Pane sizing

    private func cacheTabViewSize(for tabViewItem: NSTabViewItem) {
        var size: NSSize?

        if let pane = tabViewItem.settingsPaneViewController,
           let preferredSize = pane.preferredPaneSize,
           preferredSize.width > 0, preferredSize.height > 0 {
            size = preferredSize
        } else if tabViewItem.viewController?.isViewLoaded == true,
                  let view = tabViewItem.view {
            let fittingSize = view.fittingSize
            if fittingSize.width > 0, fittingSize.height > 0 {
                size = fittingSize
            }
        }

        guard var s = size else { return }

        if minimumContentWidth > 0 {
            s.width = max(s.width, minimumContentWidth)
        }
        if let pane = tabViewItem.settingsPaneViewController {
            if let minimumSize = pane.minimumPaneSize {
                s.width = max(s.width, minimumSize.width)
                s.height = max(s.height, minimumSize.height)
            }
            if let maximumSize = pane.maximumPaneSize {
                s.width = min(s.width, maximumSize.width)
                s.height = min(s.height, maximumSize.height)
            }
        }

        tabViewSizes[tabViewItem] = s
    }

    func invalidateCachedSize(for pane: SettingsPaneViewController) {
        guard let tabViewItem = tabViewItems.first(where: { $0.viewController === pane }) else { return }
        tabViewSizes[tabViewItem] = nil
        cacheTabViewSize(for: tabViewItem)

        if tabViewItem == selectedTabViewItem {
            fitWindowSize(to: tabViewItem, animateIfPossible: false)
        }
    }

    private func fitWindowSize(to tabViewItem: NSTabViewItem, animateIfPossible: Bool,
                               completion: (() -> Void)? = nil) {
        guard let size = tabViewSizes[tabViewItem], let settingsWindow else {
            completion?()
            return
        }
        applyContentSizeLimits(of: tabViewItem.settingsPaneViewController)
        settingsWindow.setWindowSize(size, animateIfPossible: animateIfPossible, completion: completion)
    }

    private func applyContentSizeLimits(of pane: SettingsPaneViewController?) {
        guard let settingsWindow else { return }

        let unbounded = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        guard let pane, pane.isResizableView else {
            settingsWindow.contentMinSize = .zero
            settingsWindow.contentMaxSize = unbounded
            return
        }

        var minimumSize = pane.minimumPaneSize ?? .zero
        if minimumContentWidth > 0 {
            minimumSize.width = max(minimumSize.width, minimumContentWidth)
        }
        settingsWindow.contentMinSize = minimumSize
        settingsWindow.contentMaxSize = pane.maximumPaneSize ?? unbounded
    }

    // MARK: - Title & behavior

    func selectTab(with tabViewItem: NSTabViewItem, animateIfPossible: Bool) {
        let pane = tabViewItem.settingsPaneViewController

        let doSelect = { [weak self] in
            guard let self else { return }
            self.cacheTabViewSize(for: tabViewItem)
            self.fitWindowSize(to: tabViewItem, animateIfPossible: animateIfPossible)
            self.updateWindowTitleWithSelectedTab()
        }

        if let pane, !pane.isPaneContentLoaded {
            pane.loadPaneContent { [weak pane] in
                pane?.isPaneContentLoaded = true
                doSelect()
            }
        } else {
            doSelect()
        }
    }

    func updateWindowTitleWithSelectedTab() {
        settingsWindow?.setWindowTitle(with: selectedTabViewItem)
    }

    private func setWindowBehavior(with tabViewItem: NSTabViewItem) {
        if tabViewItem.settingsPaneViewController?.isResizableView == true {
            settingsWindow?.styleMask.insert(.resizable)
        } else {
            settingsWindow?.styleMask.remove(.resizable)
        }
    }
}
