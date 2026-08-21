import Cocoa

/// Base class for a single settings pane.
///
/// Each pane records its `preferredPaneSize` (measured in `loadView()` via
/// `sizePaneToFitContent(minimumWidth:)`), which `SettingsTabViewController`
/// uses to resize the window per tab. Ported from usagimaru/MacAppSettingsUI.
class SettingsPaneViewController: NSViewController {
    weak var tabViewController: SettingsTabViewController?

    /// Tab label. Alias of `title`.
    var tabName: String? {
        get { title }
        set { title = newValue }
    }

    /// Tab toolbar icon.
    var tabImage: NSImage?
    /// Unique tab identifier.
    var tabIdentifier: String?
    /// Make the window resizable while this pane is active.
    var isResizableView = false

    /// Whether `loadPaneContent(completion:)` has run. Managed by the tab controller.
    var isPaneContentLoaded = false

    /// The size the window takes while this pane is displayed.
    private(set) var preferredPaneSize: NSSize?

    /// The smallest size this pane can be laid out at.
    var minimumPaneSize: NSSize?

    /// The largest size this pane allows. nil leaves the pane unbounded.
    var maximumPaneSize: NSSize?

    /// Lower bound kept so the pane can be measured again.
    private(set) var minimumPaneWidth: CGFloat = 0

    /// Guard against a layout that never converges.
    private static let paneSizeMeasurementPassLimit = 4

    private var minimumPaneWidthConstraint: NSLayoutConstraint?

    init(tabName: String? = nil,
         tabImage: NSImage? = nil,
         tabIdentifier: String? = nil,
         isResizableView: Bool = false) {
        super.init(nibName: nil, bundle: nil)
        self.tabName = tabName
        self.tabImage = tabImage
        self.tabIdentifier = tabIdentifier
        self.isResizableView = isResizableView
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if preferredPaneSize == nil {
            capturePreferredPaneSize()
        }
    }

    /// Record the laid-out frame size as the preferred pane size.
    func capturePreferredPaneSize() {
        view.layoutSubtreeIfNeeded()
        preferredPaneSize = view.frame.size
    }

    /// Override to load content asynchronously before the pane is displayed.
    func loadPaneContent(completion: @escaping () -> Void) {
        completion()
    }

    /// Give the pane a width lower bound and shrink-wrap it to its content.
    /// Call at the end of `loadView()`.
    func sizePaneToFitContent(minimumWidth: CGFloat) {
        minimumPaneWidth = minimumWidth

        // Reusing one constraint keeps repeated calls from stacking lower bounds.
        if let minimumPaneWidthConstraint {
            minimumPaneWidthConstraint.constant = minimumWidth
        } else {
            let constraint = view.widthAnchor.constraint(greaterThanOrEqualToConstant: minimumWidth)
            constraint.isActive = true
            minimumPaneWidthConstraint = constraint
        }

        // The width has to settle before the height, since it decides how many lines descriptions take.
        view.setFrameSize(NSSize(width: minimumWidth, height: 0))
        view.layoutSubtreeIfNeeded()

        // Wrapping widths only settle during layout, so measure until the size stops moving.
        var previousFittingSize = NSSize.zero
        for _ in 0 ..< Self.paneSizeMeasurementPassLimit {
            let fittingSize = view.fittingSize
            view.setFrameSize(fittingSize)
            view.layoutSubtreeIfNeeded()
            if fittingSize == previousFittingSize {
                break
            }
            previousFittingSize = fittingSize
        }

        capturePreferredPaneSize()
        // Measured at the width that settled, or a narrower one would wrap the labels and report a taller pane.
        minimumPaneSize = measureMinimumPaneSize(width: preferredPaneSize?.width ?? minimumWidth)
    }

    /// Measure the pane with its stretching sections pulled down to their lower bounds.
    private func measureMinimumPaneSize(width: CGFloat) -> NSSize {
        guard let layoutView = sectionLayoutView else {
            return NSSize(width: width, height: view.fittingSize.height)
        }

        let sizeToRestore = view.frame.size
        layoutView.setPreferredSectionHeightsActive(false)
        view.setFrameSize(NSSize(width: width, height: 0))
        view.layoutSubtreeIfNeeded()
        let minimumSize = NSSize(width: width, height: view.fittingSize.height)

        layoutView.setPreferredSectionHeightsActive(true)
        view.setFrameSize(sizeToRestore)
        view.layoutSubtreeIfNeeded()

        return minimumSize
    }

    /// The section layout view laid into this pane.
    private var sectionLayoutView: SettingsLayoutView? {
        view.subviews.compactMap { $0 as? SettingsLayoutView }.first
    }

    /// Measure the pane again and refresh the cached window size. Call after
    /// the content, font size or locale changed.
    func invalidatePaneSize() {
        guard isViewLoaded else { return }
        if minimumPaneWidthConstraint != nil {
            sizePaneToFitContent(minimumWidth: minimumPaneWidth)
        } else {
            capturePreferredPaneSize()
        }
        tabViewController?.invalidateCachedSize(for: self)
    }
}
