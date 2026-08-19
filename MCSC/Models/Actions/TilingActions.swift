import Cocoa

// MARK: - Tiling Actions

/// Expands the window at `point` to fill its screen's full bounds.
struct FillScreenAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              let window = service.getWindow(for: element) else { return }

        guard let screen = ScreenGeometry.screenContaining(axPoint: point) else { return }
        let axScreenBounds = ScreenGeometry.axBounds(for: screen)
        _ = service.setFrame(axScreenBounds, for: window)
    }
}

/// Increases the size of the target window by 33% (anchored at center, clamped to screen bounds).
struct MakeLargerAction: ShortcutAction {
    /// Multiplier used to scale window dimensions (+33%).
    private let scaleFactor: CGFloat = 1.33

    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              let window = service.getWindow(for: element),
              let currentFrame = service.getFrame(for: window) else { return }

        guard let screen = ScreenGeometry.screenContaining(axPoint: point) else { return }
        let axScreenBounds = ScreenGeometry.axBounds(for: screen)

        let targetWidth = (currentFrame.width * scaleFactor).rounded()
        let targetHeight = (currentFrame.height * scaleFactor).rounded()

        // Clamp dimensions to screen bounds
        let newWidth = min(targetWidth, axScreenBounds.width)
        let newHeight = min(targetHeight, axScreenBounds.height)

        // Expand symmetrically from center
        var newX = (currentFrame.origin.x - (newWidth - currentFrame.width) / 2.0).rounded()
        var newY = (currentFrame.origin.y - (newHeight - currentFrame.height) / 2.0).rounded()

        // Clamp position within screen boundaries
        if newX < axScreenBounds.minX {
            newX = axScreenBounds.minX
        } else if newX + newWidth > axScreenBounds.maxX {
            newX = axScreenBounds.maxX - newWidth
        }

        if newY < axScreenBounds.minY {
            newY = axScreenBounds.minY
        } else if newY + newHeight > axScreenBounds.maxY {
            newY = axScreenBounds.maxY - newHeight
        }

        _ = service.setFrame(CGRect(x: newX, y: newY, width: newWidth, height: newHeight), for: window)
    }
}

struct ReasonableSizeAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              let window = service.getWindow(for: element) else { return }
        guard let screen = ScreenGeometry.screenContaining(axPoint: point) else { return }
        let axBounds = ScreenGeometry.axBounds(for: screen)
        let w = (axBounds.width * 0.604).rounded()
        let h = (axBounds.height * 0.58).rounded()
        let x = (axBounds.origin.x + (axBounds.width - w) / 2).rounded()
        let y = (axBounds.origin.y + (axBounds.height - h) / 2).rounded()
        _ = service.setFrame(CGRect(x: x, y: y, width: w, height: h), for: window)
    }
}

struct AlmostMaximizeAction: ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol) {
        guard let element = service.getElement(at: point),
              let window = service.getWindow(for: element) else { return }
        guard let screen = ScreenGeometry.screenContaining(axPoint: point) else { return }
        let axBounds = ScreenGeometry.axBounds(for: screen)
        let w = (axBounds.width * 0.904).rounded()
        let h = (axBounds.height * 0.872).rounded()
        let x = (axBounds.origin.x + (axBounds.width - w) / 2).rounded()
        let y = (axBounds.origin.y + (axBounds.height - h) / 2).rounded()
        _ = service.setFrame(CGRect(x: x, y: y, width: w, height: h), for: window)
    }
}
