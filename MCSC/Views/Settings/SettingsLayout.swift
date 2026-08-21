import Cocoa

// Faithful port of usagimaru/MacAppSettingsUI (Sources/Layout/Section-based),
// trimmed of debug wireframes, localization and storyboard helpers.

/// Layout metrics of a settings pane.
enum SettingsLayoutMetrics {
    /// Spacing between sections.
    static let sectionSpacing: CGFloat = 20
    /// Spacing between the label column and the item column.
    static let columnSpacing: CGFloat = 8
    /// Spacing between items within a section.
    static let itemSpacing: CGFloat = 6
}

/// Ladder of layout priorities of a settings pane.
enum SettingsLayoutPriority {
    /// Width a section declares for the item column. Not required, so that wider items can still push the column open.
    static let itemColumnDeclaredWidth = NSLayoutConstraint.Priority(rawValue: 999)
    /// Width a description label asks of the item column. Loses to a declared width, beats the shrink.
    static let descriptionWidthDemand = NSLayoutConstraint.Priority(rawValue: 500)
    /// Force that hugs the item column to what its items need.
    static let itemColumnWidthShrink = NSLayoutConstraint.Priority(rawValue: 300)
    /// Force that hugs the label column to its longest label.
    static let labelColumnWidthShrink = NSLayoutConstraint.Priority(rawValue: 250)
    /// Force that fills the container. Weakest of the three, so it only takes effect while no column shrinks it.
    static let contentWidthGrow = NSLayoutConstraint.Priority(rawValue: 200)
    /// Horizontal priority of controls that take no part in deciding a column width.
    static let nonContributing = NSLayoutConstraint.Priority(rawValue: 50)
    /// Force that fills the pane vertically. Not required, so a pane dragged shorter bends instead of breaking.
    static let contentHeightGrow = NSLayoutConstraint.Priority(rawValue: 999)
    /// Height a stretching section asks for. Beats the shrink, gives way to a shorter pane.
    static let sectionPreferredHeight = NSLayoutConstraint.Priority(rawValue: 251)
    /// Force that hugs a stretching section to its lower bound. Weakest of all, so the surplus lands there.
    static let sectionHeightShrink = NSLayoutConstraint.Priority(rawValue: 1)
}

/// A description label that shrinks to its text and wraps at a width handed
/// down from the outside (its own bounds would make the width chase itself).
final class SettingsWrappingLabel: NSTextField {

    var availableWidth: CGFloat = 0 {
        didSet {
            guard availableWidth != oldValue else { return }
            preferredMaxLayoutWidth = availableWidth
            invalidateIntrinsicContentSize()
        }
    }

    init(string: String) {
        super.init(frame: .zero)
        stringValue = string
        isEditable = false
        isBezeled = false
        isBordered = false
        backgroundColor = .clear
        isSelectable = false
        usesSingleLineMode = false
        lineBreakMode = .byWordWrapping
        maximumNumberOfLines = 0
        cell?.wraps = true
        cell?.isScrollable = false
        font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        textColor = .secondaryLabelColor
        alignment = .natural

        // Take no part in deciding the column width, but do shrink the box down to the text.
        setContentCompressionResistancePriority(SettingsLayoutPriority.nonContributing, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Width the text takes on a single line; the column asks for this much
    /// before settling on a narrower, wrapping box.
    var naturalTextWidth: CGFloat {
        let unbounded = NSRect(x: 0, y: 0, width: 10000, height: 10000)
        return cell?.cellSize(forBounds: unbounded).width ?? 0
    }
}

/// Width a section's content spans.
enum SettingsSectionWidthMode {
    /// Line up with the two-column block, so the edges match the column sections.
    case contentBlock
    /// Span the whole container width.
    case fullWidth
}

/// Height a section takes.
enum SettingsSectionHeightMode {
    /// Follow the height of the content.
    case fitsContent
    /// Take in the surplus height of the pane, never falling below the minimum height.
    case flexible(minimumHeight: CGFloat, preferredHeight: CGFloat)
}

/// Vertical alignment of an item in a section against its label.
enum SettingsItemVerticalAlignment {
    case firstBaseline
    case top
    case centerY
}

/// A unit of view stacked in a `SettingsLayoutView`.
class SettingsSectionView: NSView {

    /// Box holding the section content. Its width follows the width mode and it stays centered.
    let contentGuide = NSLayoutGuide()

    /// Which width the content box follows. Switching it swaps the active width constraint.
    var widthMode: SettingsSectionWidthMode = .contentBlock {
        didSet { updateContentWidthConstraint() }
    }

    /// Whether the section takes in surplus height. Switching it swaps the active height constraints.
    var heightMode: SettingsSectionHeightMode = .fitsContent {
        didSet {
            updateHeightConstraints()
            layoutView?.invalidateFlexibleSections()
        }
    }

    /// The container this section was added to.
    weak var layoutView: SettingsLayoutView?

    /// Width of the section itself, which the container has already stretched to its full width.
    private var fullWidthConstraint: NSLayoutConstraint?
    /// Width shared with the two-column block. Absent while the section stands outside a container.
    private var contentBlockWidthConstraint: NSLayoutConstraint?
    /// Lower bound the section keeps while it takes in surplus height.
    private var minimumHeightConstraint: NSLayoutConstraint?
    /// Height the section asks for. It gives way once the pane is dragged shorter.
    private var preferredHeightConstraint: NSLayoutConstraint?

    init(identifier: NSUserInterfaceItemIdentifier? = nil) {
        super.init(frame: .zero)
        self.identifier = identifier
        setUpContentGuide()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setUpContentGuide() {
        addLayoutGuide(contentGuide)

        NSLayoutConstraint.activate([
            contentGuide.topAnchor.constraint(equalTo: topAnchor),
            contentGuide.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentGuide.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentGuide.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            contentGuide.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])

        fullWidthConstraint = contentGuide.widthAnchor.constraint(equalTo: widthAnchor)
        updateContentWidthConstraint()
    }

    /// Take over the container's shared block width. Whether the section actually follows it is up to the width mode.
    func adoptContentWidth(from widthGuide: NSLayoutGuide) {
        contentBlockWidthConstraint = contentGuide.widthAnchor.constraint(equalTo: widthGuide.widthAnchor)
        updateContentWidthConstraint()
    }

    private func updateContentWidthConstraint() {
        // Outside a container there is no block to follow, so the section width stays the only width available.
        let followsContentBlock = (widthMode == .contentBlock && contentBlockWidthConstraint != nil)

        // Drop the old width before putting up the new one, so the two never coexist.
        if followsContentBlock {
            fullWidthConstraint?.isActive = false
            contentBlockWidthConstraint?.isActive = true
        } else {
            contentBlockWidthConstraint?.isActive = false
            fullWidthConstraint?.isActive = true
        }
    }

    // MARK: - Height

    /// Whether this section takes in the surplus height of the pane.
    var isVerticallyFlexible: Bool {
        if case .flexible = heightMode { return true }
        return false
    }

    /// Lower bound this section keeps while stretching. nil while it follows its content.
    var flexibleMinimumHeight: CGFloat? {
        guard case .flexible(let minimumHeight, _) = heightMode else { return nil }
        return minimumHeight
    }

    private func updateHeightConstraints() {
        minimumHeightConstraint?.isActive = false
        preferredHeightConstraint?.isActive = false
        minimumHeightConstraint = nil
        preferredHeightConstraint = nil

        guard case .flexible(let minimumHeight, let preferredHeight) = heightMode else {
            setContentHuggingPriority(.defaultLow, for: .vertical)
            return
        }

        // The stack hands its surplus to the least hugging section.
        setContentHuggingPriority(SettingsLayoutPriority.sectionHeightShrink, for: .vertical)

        let minimum = heightAnchor.constraint(greaterThanOrEqualToConstant: minimumHeight)
        minimum.isActive = true
        minimumHeightConstraint = minimum

        // A lower bound, so the tallest request decides the height the pane opens at.
        let preferred = heightAnchor.constraint(greaterThanOrEqualToConstant: preferredHeight)
        preferred.priority = SettingsLayoutPriority.sectionPreferredHeight
        preferred.isActive = true
        preferredHeightConstraint = preferred
    }

    /// Drop the height request while the pane measures its lower bound.
    func setPreferredHeightActive(_ flag: Bool) {
        preferredHeightConstraint?.isActive = flag
    }

    /// Apply a control size together with the font size that matches it.
    static func applyControlSize(_ controlSize: NSControl.ControlSize, to control: NSControl) {
        control.controlSize = controlSize
        if controlSize == .small {
            control.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        }
    }
}

/// A two-column section made of one trailing-aligned label and any number of
/// leading-aligned items. The label column follows its longest label across
/// every section, and the item column follows whatever its items need.
final class SettingsColumnSectionView: SettingsSectionView {

    private(set) var titleLabel: NSTextField!

    /// Width this section asks of the item column. Caps and floors it alike,
    /// so the column settles there. nil follows the items instead.
    var itemColumnMaximumWidth: CGFloat? {
        didSet {
            updateItemColumnMaximumWidthConstraint()
            layoutView?.invalidateItemColumnDeclaredWidth()
        }
    }

    /// Box of the label column. Its width comes from the container guide.
    private let labelBoxGuide = NSLayoutGuide()
    /// Box of the item column. It sits on the trailing side of the label column.
    private let itemBoxGuide = NSLayoutGuide()

    private unowned let labelColumnWidthGuide: NSLayoutGuide
    private unowned let itemColumnWidthGuide: NSLayoutGuide

    private var items = [NSView]()
    private var bottomConstraint: NSLayoutConstraint?
    private var itemColumnMaximumWidthConstraint: NSLayoutConstraint?
    /// Constraints that let the label decide the height while no item has been added yet.
    private var labelOnlyVerticalConstraints = [NSLayoutConstraint]()

    init(labelTitle: String,
         labelColumnWidthGuide: NSLayoutGuide,
         itemColumnWidthGuide: NSLayoutGuide,
         itemColumnMaximumWidth: CGFloat? = nil,
         identifier: NSUserInterfaceItemIdentifier? = nil) {
        self.labelColumnWidthGuide = labelColumnWidthGuide
        self.itemColumnWidthGuide = itemColumnWidthGuide
        self.itemColumnMaximumWidth = itemColumnMaximumWidth
        super.init(identifier: identifier)

        setUpGuides()
        setUpTitleLabel(labelTitle)
        updateItemColumnMaximumWidthConstraint()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setUpGuides() {
        [labelBoxGuide, itemBoxGuide].forEach { addLayoutGuide($0) }

        // The two columns fill the content box exactly, so centering and width are left to the base class.
        NSLayoutConstraint.activate([
            labelBoxGuide.topAnchor.constraint(equalTo: topAnchor),
            labelBoxGuide.bottomAnchor.constraint(equalTo: bottomAnchor),
            labelBoxGuide.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            itemBoxGuide.topAnchor.constraint(equalTo: topAnchor),
            itemBoxGuide.bottomAnchor.constraint(equalTo: bottomAnchor),
            itemBoxGuide.leadingAnchor.constraint(equalTo: labelBoxGuide.trailingAnchor,
                                                  constant: SettingsLayoutMetrics.columnSpacing),
            itemBoxGuide.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor),
        ])
    }

    /// The container shares the item column width guide across every section,
    /// so the narrowest declaration wins for the whole layout.
    private func updateItemColumnMaximumWidthConstraint() {
        itemColumnMaximumWidthConstraint?.isActive = false
        itemColumnMaximumWidthConstraint = nil

        guard let itemColumnMaximumWidth else { return }

        let constraint = itemColumnWidthGuide.widthAnchor.constraint(lessThanOrEqualToConstant: itemColumnMaximumWidth)
        constraint.priority = SettingsLayoutPriority.itemColumnDeclaredWidth
        constraint.isActive = true
        itemColumnMaximumWidthConstraint = constraint
    }

    private func setUpTitleLabel(_ title: String) {
        titleLabel = NSTextField(labelWithString: "\(title):")
        titleLabel.alignment = .right
        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize)

        // Left in wrapping mode the label gains no intrinsic width and the column collapses to zero.
        titleLabel.usesSingleLineMode = true
        // Truncating in the middle keeps the trailing colon, so a shortened label still reads as a label.
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.cell?.isScrollable = false
        // Recovers a truncated label on hover, so a narrow pane never hides the wording outright.
        titleLabel.allowsExpansionToolTips = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.trailingAnchor.constraint(equalTo: labelBoxGuide.trailingAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: labelBoxGuide.leadingAnchor),
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])

        labelOnlyVerticalConstraints = [
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ]
        NSLayoutConstraint.activate(labelOnlyVerticalConstraints)
    }

    /// Activate the constraints crossing into the container column width
    /// guides. Call after joining the view hierarchy.
    func activateColumnWidthConstraints() {
        NSLayoutConstraint.activate([
            labelBoxGuide.widthAnchor.constraint(equalTo: labelColumnWidthGuide.widthAnchor),
            itemBoxGuide.widthAnchor.constraint(equalTo: itemColumnWidthGuide.widthAnchor),
            labelColumnWidthGuide.widthAnchor.constraint(greaterThanOrEqualTo: titleLabel.widthAnchor),
        ])
    }

    // MARK: - Adding items

    @discardableResult
    func addCheckbox(title: String, isOn: Bool = false, target: AnyObject?, action: Selector?) -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: title, target: target, action: action)
        checkbox.state = isOn ? .on : .off
        appendItem(checkbox, verticalAlignment: .firstBaseline, contributesToColumnWidth: true)
        return checkbox
    }

    /// Supplementary description label; takes no part in deciding the column width.
    @discardableResult
    func addDescriptionLabel(_ string: String) -> SettingsWrappingLabel {
        let label = SettingsWrappingLabel(string: string)
        appendItem(label, verticalAlignment: .firstBaseline, contributesToColumnWidth: false)
        return label
    }

    @discardableResult
    func addButton(title: String,
                   controlSize: NSControl.ControlSize = .regular,
                   target: AnyObject?,
                   action: Selector?) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.bezelStyle = .push
        Self.applyControlSize(controlSize, to: button)
        appendItem(button, verticalAlignment: .firstBaseline, contributesToColumnWidth: true)
        return button
    }

    /// Arbitrary view.
    func addCustomView(_ view: NSView, verticalAlignment: SettingsItemVerticalAlignment = .firstBaseline) {
        appendItem(view, verticalAlignment: verticalAlignment, contributesToColumnWidth: true)
    }

    private func appendItem(_ item: NSView,
                            verticalAlignment: SettingsItemVerticalAlignment,
                            contributesToColumnWidth: Bool) {
        let previousItem = items.last

        item.translatesAutoresizingMaskIntoConstraints = false
        addSubview(item)

        var constraints = [item.leadingAnchor.constraint(equalTo: itemBoxGuide.leadingAnchor)]

        if contributesToColumnWidth {
            constraints.append(item.trailingAnchor.constraint(lessThanOrEqualTo: itemBoxGuide.trailingAnchor))
            constraints.append(itemColumnWidthGuide.widthAnchor.constraint(greaterThanOrEqualTo: item.widthAnchor))
        } else {
            // The wrapping width arrives through `availableWidth`, so the box only needs to stay inside the column.
            constraints.append(item.trailingAnchor.constraint(lessThanOrEqualTo: itemBoxGuide.trailingAnchor))

            // Asking with the box width would be circular, because that width is what this demand decides.
            // Round up, or integralizing the box can land a point short of the text and wrap it needlessly.
            if let label = item as? SettingsWrappingLabel {
                let demand = itemColumnWidthGuide.widthAnchor
                    .constraint(greaterThanOrEqualToConstant: label.naturalTextWidth.rounded(.up))
                demand.priority = SettingsLayoutPriority.descriptionWidthDemand
                constraints.append(demand)
            }
        }

        if let previousItem {
            constraints.append(item.topAnchor.constraint(equalTo: previousItem.bottomAnchor,
                                                         constant: SettingsLayoutMetrics.itemSpacing))
        } else {
            constraints.append(item.topAnchor.constraint(equalTo: topAnchor))
        }

        NSLayoutConstraint.activate(constraints)

        if previousItem == nil {
            NSLayoutConstraint.deactivate(labelOnlyVerticalConstraints)
            switch verticalAlignment {
            case .firstBaseline:
                titleLabel.firstBaselineAnchor.constraint(equalTo: item.firstBaselineAnchor).isActive = true
            case .top:
                titleLabel.topAnchor.constraint(equalTo: item.topAnchor).isActive = true
            case .centerY:
                titleLabel.centerYAnchor.constraint(equalTo: item.centerYAnchor).isActive = true
            }
        }

        bottomConstraint?.isActive = false
        bottomConstraint = bottomAnchor.constraint(equalTo: item.bottomAnchor)
        bottomConstraint?.isActive = true

        items.append(item)
    }

    override func layout() {
        super.layout()
        let itemColumnWidth = itemBoxGuide.frame.width
        items.forEach { ($0 as? SettingsWrappingLabel)?.availableWidth = itemColumnWidth }
    }
}

/// Horizontal placement of a control inside the section content box.
enum SettingsSectionAlignment {
    case leading
    case center
    case trailing
}

/// A separator spanning the whole container.
final class SettingsSeparatorSectionView: SettingsSectionView {

    private(set) var separator: NSBox!

    override init(identifier: NSUserInterfaceItemIdentifier? = nil) {
        super.init(identifier: identifier)

        separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

/// A section placing a single push button in the content box.
final class SettingsButtonSectionView: SettingsSectionView {

    private(set) var button: NSButton!

    init(title: String,
         controlSize: NSControl.ControlSize = .regular,
         alignment: SettingsSectionAlignment = .center,
         identifier: NSUserInterfaceItemIdentifier? = nil,
         target: AnyObject?,
         action: Selector?) {
        super.init(identifier: identifier)

        button = NSButton(title: title, target: target, action: action)
        button.bezelStyle = .push
        Self.applyControlSize(controlSize, to: button)
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)

        var constraints = [
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.leadingAnchor.constraint(greaterThanOrEqualTo: contentGuide.leadingAnchor),
            button.trailingAnchor.constraint(lessThanOrEqualTo: contentGuide.trailingAnchor),
        ]

        switch alignment {
        case .leading:
            constraints.append(button.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor))
        case .center:
            constraints.append(button.centerXAnchor.constraint(equalTo: contentGuide.centerXAnchor))
        case .trailing:
            constraints.append(button.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor))
        }

        NSLayoutConstraint.activate(constraints)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

/// A section placing a leading-aligned checkbox in the content box, with an
/// optional wrapping description underneath.
final class SettingsCheckboxSectionView: SettingsSectionView {

    private(set) var checkbox: NSButton!
    private(set) var descriptionLabel: SettingsWrappingLabel?

    init(title: String,
         isOn: Bool = false,
         description: String? = nil,
         identifier: NSUserInterfaceItemIdentifier? = nil,
         target: AnyObject?,
         action: Selector?) {
        super.init(identifier: identifier)

        checkbox = NSButton(checkboxWithTitle: title, target: target, action: action)
        checkbox.state = isOn ? .on : .off
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkbox)

        var constraints = [
            checkbox.topAnchor.constraint(equalTo: topAnchor),
            checkbox.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            checkbox.trailingAnchor.constraint(lessThanOrEqualTo: contentGuide.trailingAnchor),
        ]

        if let description {
            let label = SettingsWrappingLabel(string: description)
            descriptionLabel = label
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)

            constraints += [
                label.topAnchor.constraint(equalTo: checkbox.bottomAnchor,
                                           constant: SettingsLayoutMetrics.itemSpacing),
                label.leadingAnchor.constraint(equalTo: checkbox.leadingAnchor),
                label.trailingAnchor.constraint(lessThanOrEqualTo: contentGuide.trailingAnchor),
                label.bottomAnchor.constraint(equalTo: bottomAnchor),
            ]
        } else {
            constraints.append(checkbox.bottomAnchor.constraint(equalTo: bottomAnchor))
        }

        NSLayoutConstraint.activate(constraints)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        descriptionLabel?.availableWidth = contentGuide.frame.width
    }
}
