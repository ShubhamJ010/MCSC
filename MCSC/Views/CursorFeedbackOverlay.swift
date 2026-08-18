import Cocoa

/// A lightweight, non-interactive, transient overlay that flashes an action
/// symbol — red `xmark.circle.fill` for Close, `minus.circle.fill` for
/// Minimize, a purple `xmark.circle.fill` with a white cross for Force
/// Quit, a
/// black/yellow `eye.slash.circle.fill` for Hide, a pastel
/// `inset.filled.rectangle` for Almost Maximize, an accent
/// `inset.filled.center.rectangle` for Reasonable Size, an accent
/// `rectangle.fill` for Maximize, a `xmark.rectangle.fill` for Close Tab, a
/// `plus.rectangle.fill` for Reopen Tab, a `rectangle.badge.xmark` for Close
/// All Tabs, and a `rectangle.badge.plus` for New Window — centered at the
/// mouse cursor as visual feedback whenever a close, minimize, quit, hide, or
/// resize action executes (Cmd+W / Cmd+M / Cmd+Q / Cmd+H shortcuts and the
/// matching trackpad gestures). The three resize symbols (Almost Maximize,
/// Reasonable Size, Maximize) first paint an empty `rectangle` and then morph
/// into their filled glyph via a replace transition.
///
/// Unlike `PreviewCloseButtonOverlay` (which is anchored to the top-left of a
/// Mission Control window preview and is clickable), this overlay ignores all
/// mouse events so it never intercepts clicks or changes the cursor while
/// sitting directly under it.
@MainActor
final class CursorFeedbackOverlay {
    /// The set of actions the overlay can flash, plus their visual treatment.
    ///
    /// Adding a new feedback type is *data-only*: add a `case` and fill in the
    /// descriptors below (symbol name, accessibility label, tint palette, and
    /// optional entry animation). The overlay derives the rendered image and
    /// behaviour from these and needs no further changes.
    /// `CaseIterable` lets tests walk the full descriptor set to prove every
    /// mode renders a real SF Symbol and carries a non-empty a11y label.
    enum Mode: CaseIterable {
        case close
        case minimize
        case quit
        case hide
        case almost
        case reasonable
        case maximize
        case closeTab
        case reopenTab
        case closeAllTabs
        case newWindow

        /// SF Symbol name rendered by `NSImage(systemSymbolName:)`.
        var symbolName: String {
            switch self {
            case .close: return "xmark.circle.fill"
            case .minimize: return "minus.circle.fill"
            case .quit: return "xmark.circle.fill"
            case .hide: return "eye.slash.circle.fill"
            case .almost: return "inset.filled.rectangle"
            case .reasonable: return "inset.filled.center.rectangle"
            case .maximize: return "rectangle.fill"
            case .closeTab: return "xmark.rectangle.fill"
            case .reopenTab: return "plus.rectangle.fill"
            case .closeAllTabs: return "rectangle.badge.xmark"
            case .newWindow: return "rectangle.badge.plus"
            }
        }

        /// Accessibility description of the action the symbol represents.
        var accessibilityDescription: String {
            switch self {
            case .close: return "Close Window"
            case .minimize: return "Minimize Window"
            case .quit: return "Force Quit"
            case .hide: return "Hide Application"
            case .almost: return "Almost Maximize Window"
            case .reasonable: return "Reasonable Size"
            case .maximize: return "Maximize Window"
            case .closeTab: return "Close Tab"
            case .reopenTab: return "Reopen Tab"
            case .closeAllTabs: return "Close All Tabs"
            case .newWindow: return "New Window"
            }
        }

        /// Tint palette painted through the symbol (SF Symbols "palette" /
        /// variable-colour rendering). `nil` keeps the system multicolor
        /// default. Colors map to layers in order: primary → accent → none.
        var paletteColors: [NSColor]? {
            switch self {
            case .close: return nil
            case .minimize: return [.black, .systemYellow]
            case .quit: return [.white, NSColor(red: 0.749, green: 0.353, blue: 0.949, alpha: 1.0)]
            case .hide: return [.black, .systemYellow]
            case .almost, .reasonable:
                // Single Accent layer (the user's system accent colour), same as Maximize.
                return [.controlAccentColor]
            case .maximize:
                // Single Accent layer (the user's system accent colour).
                return [.controlAccentColor]
            case .closeTab:
                // System multicolor (red X, matching Close).
                return nil
            case .reopenTab:
                // Positive/additive green plus.
                return [.systemGreen]
            case .closeAllTabs:
                // System multicolor (red X badge, matching Close).
                return nil
            case .newWindow:
                // Positive/additive green badge, matching the reopen plus.
                return [.systemGreen]
            }
        }

        /// Optional entry symbol effect played as the feedback lands.
        ///
        /// Deliberately a small closed enum instead of a stored `SymbolEffect`
        /// existential: `addSymbolEffect` takes `some SymbolEffect` (opaque),
        /// which can't be fed from an `any SymbolEffect` box. The overlay's
        /// single `switch` here is the only place new animations need wiring.
        enum EntryAnimation {
            case scaleUpByLayer
            case bounce
            case wiggleByLayer
        }

        var entryAnimation: EntryAnimation? {
            switch self {
            case .quit: return .scaleUpByLayer
            case .hide: return .bounce
            case .closeTab, .reopenTab, .closeAllTabs, .newWindow: return .wiggleByLayer
            case .close, .minimize, .almost, .reasonable, .maximize: return nil
            }
        }

        /// Optional symbol *replacement* transition played as the feedback
        /// symbol swaps in. Distinct from `entryAnimation` (an in-place
        /// `addSymbolEffect`): this is a `setSymbolImage` content transition
        /// that visually morphs from the previous symbol, so it pairs with
        /// plain appear for close/minimize or the entry effects for quit/hide.
        enum ReplaceTransition {
            /// `.replace.magic(fallback: .upUp.byLayer)` on macOS 26+; falls
            /// back to `.replace.upUp.byLayer` on macOS 14/15.
            case magicReveal
            /// `.replace.downUp.byLayer` (macOS 14+; no OS-version fallback).
            case downUpReveal
        }

        var replaceTransition: ReplaceTransition? {
            switch self {
            case .almost, .reasonable, .maximize: return .downUpReveal
            case .close, .minimize, .quit, .hide, .closeTab, .reopenTab, .closeAllTabs, .newWindow: return nil
            }
        }

        /// Plain symbol painted *before* the replacement transition fires, so
        /// the swap-in always morphs from a stable base instead of whatever
        /// symbol previously occupied the overlay. The resize modes
        /// (maximize / reasonable / almost) all start from an empty rectangle.
        var baseSymbol: String? {
            switch self {
            case .almost, .reasonable, .maximize: return "rectangle"
            default: return nil
            }
        }
    }

    static let dimension: CGFloat = 34.0

    /// Nominal window the symbol stays on screen before retracting. The retract
    /// actually leads this by `retractLead`, so the draw-off bleeds into the tail
    /// of the flash rather than starting at a hard boundary. Slightly longer than
    /// the trigger itself so the flash outlives the close / minimize animation.
    private let displayDuration: TimeInterval = 0.6

    /// How much the retract leads the end of the display window: the draw-off /
    /// disappear effect starts `retractLead` seconds before `displayDuration`
    /// elapses, so the symbol begins to thin out while the flash is still
    /// winding down.
    private let retractLead: TimeInterval = 0.12

    /// Duration of the retract: the symbol's draw-off / disappear effect
    /// (macOS 26 / 14+) plus the concurrent panel fade-out.
    private let retractDuration: TimeInterval = 0.45

    private var panel: NSPanel?
    private var imageView: NSImageView?
    private var dismissWork: DispatchWorkItem?

    /// Cache of rendered feedback symbols, keyed by mode. Populated lazily so
    /// each symbol is rasterized at most once per process and reused across
    /// triggers.
    private var imageCache: [Mode: NSImage] = [:]

    /// Returns the cached — or freshly rendered — symbol image for `mode`.
    private func image(for mode: Mode) -> NSImage? {
        if let cached = imageCache[mode] { return cached }
        guard let image = makeSymbolImage(for: mode) else { return nil }
        imageCache[mode] = image
        return image
    }

    /// Builds the SF Symbol image for `mode`: semibold 24 pt, tinted with the
    /// mode's palette (or the system multicolor default). Pure factory — no
    /// state — so new modes only need their `Mode` descriptors.
    private func makeSymbolImage(for mode: Mode) -> NSImage? {
        makeSymbolImage(symbolName: mode.symbolName, mode: mode)
    }

    /// Renders an arbitrary SF Symbol with the given mode's tint palette. Used
    /// for the base symbols (e.g. empty rectangle) painted just before a
    /// replacement transition fires.
    private func makeSymbolImage(symbolName: String, mode: Mode) -> NSImage? {
        var config = NSImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        if let colors = mode.paletteColors {
            config = config.applying(NSImage.SymbolConfiguration(paletteColors: colors))
        } else {
            config = config.applying(NSImage.SymbolConfiguration.preferringMulticolor())
        }
        return NSImage(systemSymbolName: symbolName,
                       accessibilityDescription: mode.accessibilityDescription)?
            .withSymbolConfiguration(config)
    }

    init() {
        setupPanel()
    }

    private func setupPanel() {
        let contentRect = NSRect(x: 0, y: 0, width: Self.dimension, height: Self.dimension)
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
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.alphaValue = 0.0

        let imageView = NSImageView(frame: contentRect)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.45).cgColor
        imageView.layer?.shadowOpacity = 1.0
        imageView.layer?.shadowOffset = CGSize(width: 0, height: -1.5)
        imageView.layer?.shadowRadius = 4.5
        imageView.image = image(for: .close)

        panel.contentView = imageView
        self.imageView = imageView
        self.panel = panel
    }

    /// Shows the feedback symbol centered on `point` (Quartz/AX screen
    /// coordinates, origin at the top-left). Repeated triggers within the
    /// display window reset the auto-dismiss timer so the symbol persists a
    /// full beat from the most recent action.
    func show(at point: CGPoint, mode: Mode) {
        guard let panel = panel else { return }

        // Cancel any pending dismissal so repeated triggers reset the timer.
        dismissWork?.cancel()
        dismissWork = nil

        panel.setFrameOrigin(Self.cocoaAnchorPoint(for: point, panelSize: panel.frame.size))

        // Clear any in-flight symbol effect (e.g. a previous draw-off retract)
        // before swapping to the new symbol.
        if #available(macOS 14.0, *) {
            imageView?.removeAllSymbolEffects(animated: false)
        }

        let feedbackImage = image(for: mode)

        // Modes with a replacement transition first paint a stable base symbol
        // (an empty rectangle for the resize modes), so the morph below always
        // starts from a clean silhouette instead of whatever symbol previously
        // occupied the overlay.
        let baseImage = mode.baseSymbol.flatMap { makeSymbolImage(symbolName: $0, mode: mode) }

        // Set opacity synchronously instead of via an `animator()` fade-in.
        // The close/minimize action invoked right after this blocks the main
        // thread with synchronous AX calls, starving any run-loop animation —
        // a fade-in would only play *after* the action completes, making the
        // symbol flicker in and immediately out. Instant alpha guarantees the
        // symbol is visible from the exact moment the shortcut/gesture fires.
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
        panel.alphaValue = 1.0
        imageView?.image = baseImage ?? feedbackImage
        // Commit the base symbol synchronously so the replacement transition
        // below morphs from it rather than from stale pixels. The close/minimize
        // action invoked right after this blocks the main thread with synchronous
        // AX calls; if the layer commit waits for the next run loop turn, the
        // symbol's backing store is only uploaded after the action completes —
        // right before the auto-dismiss fires — which reads as a flicker
        // ("appears and vanishes").
        CATransaction.flush()

        // Symbol swap: plain assignment, or a "replace" content transition for
        // modes that request one (almost / reasonable / maximize morph from the
        // painted base symbol). `setSymbolImage` needs a live SF Symbol image,
        // which the cache always provides.
        if let replace = mode.replaceTransition, let feedbackImage {
            switch replace {
            case .magicReveal:
                if #available(macOS 26.0, *) {
                    imageView?.setSymbolImage(feedbackImage, contentTransition: .replace.magic(fallback: .upUp.byLayer), options: .nonRepeating)
                } else {
                    // Pre-macOS-26 equivalent of `fallback: .upUp.byLayer`.
                    imageView?.setSymbolImage(feedbackImage, contentTransition: .replace.upUp.byLayer, options: .nonRepeating)
                }
            case .downUpReveal:
                imageView?.setSymbolImage(feedbackImage, contentTransition: .replace.downUp.byLayer, options: .nonRepeating)
            }
        }

        // Play the mode's entry animation (scale-up for quit, bounce for hide,
        // none for close/minimize) now that the panel is composited. Effects
        // were cleared above so repeated triggers start clean from the base layer.
        if #available(macOS 14.0, *), let animation = mode.entryAnimation {
            switch animation {
            case .scaleUpByLayer:
                imageView?.addSymbolEffect(.scale.up.byLayer, options: .nonRepeating)
            case .bounce:
                imageView?.addSymbolEffect(.bounce, options: .nonRepeating)
            case .wiggleByLayer:
                if #available(macOS 26.0, *) {
                    imageView?.addSymbolEffect(.wiggle.byLayer, options: .nonRepeating)
                } else {
                    imageView?.addSymbolEffect(.bounce, options: .nonRepeating)
                }
            }
        }

        scheduleDismiss()
    }

    /// Immediately hides the overlay. Used for cleanup when the app stops.
    func hide() {
        dismissWork?.cancel()
        dismissWork = nil
        panel?.orderOut(nil)
        panel?.alphaValue = 0.0
    }

    private func scheduleDismiss() {
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, let panel = self.panel, let imageView = self.imageView else { return }
            self.retract(panel: panel, imageView: imageView)
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + displayDuration - retractLead,
            execute: work
        )
    }

    /// Animates the symbol away: plays the `drawOff` symbol effect so the icon
    /// retracts stroke-by-stroke (the reverse of how it was drawn in), while the
    /// whole panel fades out concurrently so no empty "draw-off ghost" frame
    /// lingers. `addSymbolEffect` exposes no completion callback, so the panel
    /// is dismissed by the fade's completion handler.
    ///
    /// `.drawOn` / `.drawOff` are macOS 26+ only. On macOS 14/15 the closest
    /// analog is `.disappear` (each symbol layer vanishes sequentially), which
    /// the deployment target (15.7) always has.
    private func retract(panel: NSPanel, imageView: NSImageView) {
        if #available(macOS 26.0, *) {
            imageView.addSymbolEffect(.drawOff.reversed.individually, options: .nonRepeating)
        } else {
            imageView.addSymbolEffect(.disappear.byLayer, options: .nonRepeating)
        }
        fadeOut(panel: panel, imageView: imageView, duration: retractDuration)
    }

    /// Fades the panel to zero over `duration` and dismisses it. The symbol
    /// effect is safely cleaned up once the fade completes.
    private func fadeOut(panel: NSPanel, imageView: NSImageView, duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            panel.animator().alphaValue = 0.0
        } completionHandler: {
            // Only fully dismiss if no newer trigger bumped alpha back up.
            if panel.alphaValue == 0.0 {
                panel.orderOut(nil)
                imageView.removeAllSymbolEffects()
            }
        }
    }

    /// Converts a Quartz/AX screen point (origin top-left of the primary
    /// display) into a Cocoa screen origin (bottom-left) that centers a panel
    /// of `panelSize` on the point, clamped so the panel never leaves the
    /// display that contains it. Pure math — kept `nonisolated` so it is
    /// testable without a main actor.
    nonisolated static func cocoaAnchorPoint(for point: CGPoint, panelSize: CGSize) -> CGPoint {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let halfW = panelSize.width / 2.0
        let halfH = panelSize.height / 2.0

        var x = point.x - halfW
        var y = (primaryHeight - point.y) - halfH

        // Find the Cocoa screen containing the requested center so clamping
        // stays accurate on multi-display setups.
        let centerCocoa = CGPoint(x: point.x, y: primaryHeight - point.y)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(centerCocoa) })
            ?? NSScreen.screens.first
        if let frame = screen?.frame {
            x = min(max(x, frame.minX), frame.maxX - panelSize.width)
            y = min(max(y, frame.minY), frame.maxY - panelSize.height)
        }
        return CGPoint(x: x, y: y)
    }
}
