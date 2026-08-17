import Cocoa

/// A lightweight, non-interactive, transient overlay that flashes an action
/// symbol — red `xmark.circle.fill` for Close, `minus.circle.fill` for
/// Minimize — centered at the mouse cursor as visual feedback whenever a
/// close or minimize action executes (Cmd+W / Cmd+M shortcuts, pinch-in /
/// swipe-up gestures).
///
/// Unlike `PreviewCloseButtonOverlay` (which is anchored to the top-left of a
/// Mission Control window preview and is clickable), this overlay ignores all
/// mouse events so it never intercepts clicks or changes the cursor while
/// sitting directly under it.
@MainActor
final class CursorFeedbackOverlay {
    enum Mode {
        case close
        case minimize
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

    /// Same image configuration as `CloseButtonView` so the feedback symbol
    /// looks identical to the Mission Control hover overlay.
    private let closeImage: NSImage? = {
        let config = NSImage.SymbolConfiguration.preferringMulticolor()
            .applying(NSImage.SymbolConfiguration(pointSize: 24, weight: .semibold))
        return NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close Window")?.withSymbolConfiguration(config)
    }()

    private let minimizeImage: NSImage? = {
        let paletteConfig = NSImage.SymbolConfiguration(paletteColors: [.black, .systemYellow])
            .applying(NSImage.SymbolConfiguration(pointSize: 24, weight: .semibold))
        return NSImage(systemSymbolName: "minus.circle.fill", accessibilityDescription: "Minimize Window")?.withSymbolConfiguration(paletteConfig)
    }()

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
        imageView.image = closeImage

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
        imageView?.image = (mode == .close) ? closeImage : minimizeImage

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
        // Commit the layer tree synchronously. The close/minimize action invoked
        // right after this blocks the main thread with synchronous AX calls; if
        // the layer commit waits for the next run loop turn, the symbol's backing
        // store is only uploaded after the action completes — right before the
        // auto-dismiss fires — which reads as a flicker ("appears and vanishes").
        CATransaction.flush()

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
        } completionHandler: { [weak self] in
            guard let self = self else { return }
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
