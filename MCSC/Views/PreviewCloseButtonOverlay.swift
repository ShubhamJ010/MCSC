import Cocoa
import Symbols

/// A lightweight, floating overlay panel that anchors an action button
/// (`xmark.circle.fill` for Close, `minus.circle.fill` for Minimize, and a
/// purple `xmark.circle.fill` with a white cross for Force Quit) to the
/// top-left corner vertex of a Mission Control window preview.
@MainActor
final class PreviewCloseButtonOverlay {
    /// The action the hover button represents, plus its visual treatment.
    ///
    /// Data-driven like `CursorFeedbackOverlay.Mode`: adding a new action is a
    /// `case` plus its descriptors (symbol name, accessibility label, palette).
    /// `CaseIterable` lets tests enumerate every mode to prove each renders.
    enum Mode: CaseIterable {
        case close
        case minimize
        case quit

        /// SF Symbol name rendered by `NSImage(systemSymbolName:)`.
        var symbolName: String {
            switch self {
            case .close: return "xmark.circle.fill"
            case .minimize: return "minus.circle.fill"
            case .quit: return "xmark.circle.fill"
            }
        }

        /// Accessibility description of the action the symbol represents.
        var accessibilityDescription: String {
            switch self {
            case .close: return "Close Window"
            case .minimize: return "Minimize Window"
            case .quit: return "Force Quit"
            }
        }

        /// Tint palette painted through the symbol. `nil` keeps the system
        /// multicolor default.
        var paletteColors: [NSColor]? {
            switch self {
            case .close: return nil
            case .minimize: return [.black, .systemYellow]
            case .quit: return [.white, NSColor(red: 0.749, green: 0.353, blue: 0.949, alpha: 1.0)]
            }
        }
    }

    static let buttonDimension: CGFloat = 32.0
    
    private var panel: NSPanel?
    private var buttonView: CloseButtonView?
    
    var onCloseClicked: (() -> Void)? {
        didSet {
            buttonView?.onCloseClicked = onCloseClicked
        }
    }
    
    private(set) var isVisible = false
    private var currentAnchorOrigin: CGPoint = .zero

    init() {
        setupPanel()
    }

    private func setupPanel() {
        let contentRect = NSRect(x: 0, y: 0, width: Self.buttonDimension, height: Self.buttonDimension)
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)))
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        
        let button = CloseButtonView(frame: contentRect)
        button.onCloseClicked = { [weak self] in
            self?.onCloseClicked?()
        }
        
        panel.contentView = button
        self.buttonView = button
        self.panel = panel
    }

    /// Positions and displays the close button overlay centered directly over the top-left corner (x, y) of the window.
    func show(at windowBounds: CGRect, mode: Mode = .close) {
        guard let panel = panel else { return }
        
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let x = windowBounds.origin.x
        let y = windowBounds.origin.y
        let halfDim = Self.buttonDimension / 2.0
        
        let cocoaX = x - halfDim
        let cocoaY = (primaryHeight - y) - halfDim
        
        let targetRect = NSRect(
            x: cocoaX,
            y: cocoaY,
            width: Self.buttonDimension,
            height: Self.buttonDimension
        )
        
        let isNewOrigin = !windowBounds.origin.equalTo(currentAnchorOrigin)
        currentAnchorOrigin = windowBounds.origin
        
        panel.setFrame(targetRect, display: true)
        buttonView?.setMode(mode, animated: false)
        
        if !isVisible {
            panel.orderFrontRegardless()
            isVisible = true
            buttonView?.triggerDrawOnEffect()
        } else if isNewOrigin {
            buttonView?.triggerDrawOnEffect()
        }
    }

    func setMode(_ mode: Mode) {
        buttonView?.setMode(mode, animated: true)
    }

    func triggerRotateEffect() {
        buttonView?.triggerRotateEffect()
    }

    /// Hides the overlay panel.
    func hide() {
        guard isVisible else { return }
        panel?.orderOut(nil)
        isVisible = false
        currentAnchorOrigin = .zero
    }
}

// MARK: - CloseButtonView

@MainActor
final class CloseButtonView: NSView {
    var onCloseClicked: (() -> Void)?
    
    private let imageView = NSImageView()
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private(set) var currentMode: PreviewCloseButtonOverlay.Mode = .close
    
    /// Cache of rendered action symbols, keyed by mode. Populated lazily so
    /// each symbol is rasterized at most once and reused across hovers.
    private var imageCache: [PreviewCloseButtonOverlay.Mode: NSImage] = [:]

    /// Returns the cached — or freshly rendered — symbol image for `mode`.
    private func image(for mode: PreviewCloseButtonOverlay.Mode) -> NSImage? {
        if let cached = imageCache[mode] { return cached }
        guard let image = makeSymbolImage(for: mode) else { return nil }
        imageCache[mode] = image
        return image
    }

    /// Builds the SF Symbol image for `mode`: semibold 24 pt, tinted with the
    /// mode's palette (or the system multicolor default).
    private func makeSymbolImage(for mode: PreviewCloseButtonOverlay.Mode) -> NSImage? {
        var config = NSImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        if let colors = mode.paletteColors {
            config = config.applying(NSImage.SymbolConfiguration(paletteColors: colors))
        } else {
            config = config.applying(NSImage.SymbolConfiguration.preferringMulticolor())
        }
        return NSImage(systemSymbolName: mode.symbolName,
                       accessibilityDescription: mode.accessibilityDescription)?
            .withSymbolConfiguration(config)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupLayer()
        setupImageView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupLayer()
        setupImageView()
    }

    private func setupLayer() {
        guard let layer = self.layer else { return }
        layer.masksToBounds = false
        layer.shadowColor = NSColor.black.withAlphaComponent(0.45).cgColor
        layer.shadowOpacity = 1.0
        layer.shadowOffset = CGSize(width: 0, height: -1.5)
        layer.shadowRadius = 4.5
    }

    private func setupImageView() {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.image = image(for: .close)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 28),
            imageView.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    func setMode(_ mode: PreviewCloseButtonOverlay.Mode, animated: Bool) {
        guard mode != currentMode else { return }
        currentMode = mode
        
        guard let image = image(for: mode) else { return }
        
        if animated, #available(macOS 14.0, *) {
            imageView.setSymbolImage(
                image,
                contentTransition: .replace.magic(fallback: .downUp.wholeSymbol),
                options: .nonRepeating
            )
        } else {
            imageView.image = image
        }
    }

    /// Plays the `.drawOn.byLayer` symbol effect on the image.
    func triggerDrawOnEffect() {
        if #available(macOS 26.0, *) {
            imageView.addSymbolEffect(.drawOn.byLayer, options: .nonRepeating)
        } else if #available(macOS 14.0, *) {
            imageView.addSymbolEffect(.appear.byLayer, options: .nonRepeating)
        }
    }

    /// Plays the non-repeating rotate symbol effect when clicked.
    func triggerRotateEffect() {
        if #available(macOS 14.0, *) {
            imageView.addSymbolEffect(.rotate.byLayer, options: .nonRepeating)
        }
    }

    // MARK: - Hover and Cursor Tracking

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        NSCursor.pointingHand.push()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            self.animator().alphaValue = 1.0
            self.layer?.transform = CATransform3DMakeScale(1.12, 1.12, 1.0)
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        NSCursor.pop()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            self.animator().alphaValue = 0.95
            self.layer?.transform = CATransform3DIdentity
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    // MARK: - Mouse Click Handling

    override func mouseDown(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            self.layer?.transform = CATransform3DMakeScale(0.92, 0.92, 1.0)
        }
    }

    override func mouseUp(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            self.layer?.transform = isHovered ? CATransform3DMakeScale(1.12, 1.12, 1.0) : CATransform3DIdentity
        }
        
        let pointInView = convert(event.locationInWindow, from: nil)
        if bounds.contains(pointInView) {
            triggerRotateEffect()
            onCloseClicked?()
        }
    }
}
