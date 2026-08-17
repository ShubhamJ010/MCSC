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

    /// How long the symbol stays on screen before fading out.
    private let displayDuration: TimeInterval = 0.45
    private let fadeOutDuration: TimeInterval = 0.18

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
        imageView?.image = (mode == .close) ? closeImage : minimizeImage

        if panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.08
                panel.animator().alphaValue = 1.0
            }
        } else {
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1.0
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
            guard let self = self, let panel = self.panel else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = self.fadeOutDuration
                panel.animator().alphaValue = 0.0
            } completionHandler: {
                // Only fully dismiss if no newer trigger bumped alpha back up.
                if panel.alphaValue == 0.0 {
                    panel.orderOut(nil)
                }
            }
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration, execute: work)
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
