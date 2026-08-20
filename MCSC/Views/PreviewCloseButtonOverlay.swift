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
        case fullscreen

        /// SF Symbol name rendered by `NSImage(systemSymbolName:)`.
        var symbolName: String {
            switch self {
            case .close: return "xmark.circle.fill"
            case .minimize: return "minus.circle.fill"
            case .quit: return "xmark.circle.fill"
            case .fullscreen: return "arrow.down.left.and.arrow.up.right.circle.fill"
            }
        }

        /// Accessibility description of the action the symbol represents.
        var accessibilityDescription: String {
            switch self {
            case .close: return "Close Window"
            case .minimize: return "Minimize Window"
            case .quit: return "Force Quit"
            case .fullscreen: return "Toggle Fullscreen"
            }
        }

        /// Tint palette painted through the symbol. `nil` keeps the system
        /// multicolor default.
        var paletteColors: [NSColor]? {
            switch self {
            case .close: return nil
            case .minimize: return [.black, .systemYellow]
            case .quit: return [.white, NSColor(red: 0.749, green: 0.353, blue: 0.949, alpha: 1.0)]
            case .fullscreen: return [.black, .systemGreen]
            }
        }
    }

    static let buttonDimension: CGFloat = 32.0
    
    private var panel: NSPanel?
    private var buttonView: CloseButtonView?
    
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
        
        panel.contentView = button
        self.buttonView = button
        self.panel = panel
    }

    /// Positions and displays the close button overlay centered directly over the top-left corner (x, y) of the window.
    func show(at windowBounds: CGRect, mode: Mode = .close) {
        guard let panel = panel else { return }
        
        let cocoaAnchor = ScreenGeometry.cocoaPoint(for: windowBounds.origin)
        let halfDim = Self.buttonDimension / 2.0
        
        let targetRect = NSRect(
            x: cocoaAnchor.x - halfDim,
            y: cocoaAnchor.y - halfDim,
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
            buttonView?.triggerAppearEffect()
        } else if isNewOrigin {
            buttonView?.triggerAppearEffect()
        }
    }

    func setMode(_ mode: Mode) {
        buttonView?.setMode(mode, animated: true)
    }

    /// Reflects mouse-over state on the anchor button with a scale animation.
    /// Driven by the service's input event tap (AppKit tracking areas don't
    /// fire while this app is inactive behind Mission Control).
    func setHovered(_ isHovered: Bool) {
        buttonView?.setHovered(isHovered)
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
    private let imageView = NSImageView()
    private(set) var isHovered = false
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
        SymbolImageFactory.make(
            symbolName: mode.symbolName,
            description: mode.accessibilityDescription,
            paletteColors: mode.paletteColors
        )
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

    /// Plays the `.appear.byLayer` symbol effect on the image.
    func triggerAppearEffect() {
        if #available(macOS 14.0, *) {
            imageView.addSymbolEffect(.appear.byLayer, options: .nonRepeating)
        }
    }

// MARK: - Hover State (driven by MissionControlHoverService event tap)

    /// Scales the button up while the cursor is over it and back to resting
    /// size when it leaves. Called from the service's global mouse-move tap —
    /// AppKit tracking areas don't deliver enter/exit while this app is
    /// inactive behind Mission Control.
    func setHovered(_ hovered: Bool) {
        guard hovered != isHovered else { return }
        isHovered = hovered
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            self.animator().alphaValue = hovered ? 1.0 : 0.97
            self.layer?.transform = hovered ? CATransform3DMakeScale(1.08, 1.08, 1.0) : CATransform3DIdentity
        }
    }
}
