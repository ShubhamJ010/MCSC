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
    static let dimension: CGFloat = 34.0

    /// Nominal window the symbol stays on screen before retracting. The retract
    /// actually leads this by `retractLead`, so the disappear effect bleeds into
    /// the tail of the flash rather than starting at a hard boundary. Slightly
    /// longer than the trigger itself so the flash outlives the close / minimize
    /// animation.
    private let displayDuration: TimeInterval = 0.6

    /// How much the retract leads the end of the display window: the disappear
    /// effect starts `retractLead` seconds before `displayDuration` elapses, so
    /// the symbol begins to thin out while the flash is still winding down.
    private let retractLead: TimeInterval = 0.12

    /// Duration of the retract: the symbol's `.disappear.byLayer` effect
    /// (macOS 14+) plus the concurrent panel fade-out.
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
        SymbolImageFactory.make(
            symbolName: symbolName,
            description: mode.accessibilityDescription,
            paletteColors: mode.paletteColors
        )
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

        // Clear any in-flight symbol effect (e.g. a previous disappear retract)
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

        // Play the mode's entry animation (bounce for hide, wiggle for the tab
        // modes) now that the panel is composited. Effects were cleared above so
        // repeated triggers start clean from the base layer. Close and quit use a
        // hover-style scale + alpha animation applied below instead of a symbol
        // effect.
        if #available(macOS 14.0, *), let animation = mode.entryAnimation {
            switch animation {
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

        // Hover-style scale + alpha animation for close, quit, and eject, matching
        // `CloseButtonView.setHovered` exactly (1.08× over 0.15s ease-out).
        // Reset first so repeated triggers start from a clean layer, then start
        // from 0.97 alpha and animate up to full scale + opacity.
        if mode == .close || mode == .quit || mode == .eject, let imageView = imageView {
            imageView.layer?.transform = CATransform3DIdentity
            imageView.alphaValue = 0.97
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true
                imageView.animator().alphaValue = 1.0
                imageView.layer?.transform = CATransform3DMakeScale(1.08, 1.08, 1.0)
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

    /// Animates the symbol away: plays the `disappear` symbol effect so each
    /// symbol layer vanishes sequentially, while the whole panel fades out
    /// concurrently so no empty "disappear ghost" frame lingers.
    /// `addSymbolEffect` exposes no completion callback, so the panel is
    /// dismissed by the fade's completion handler.
    private func retract(panel: NSPanel, imageView: NSImageView) {
        if #available(macOS 14.0, *) {
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
        ScreenGeometry.cocoaAnchorPoint(for: point, panelSize: panelSize)
    }
}
