import Cocoa

/// A window-management operation triggered by a shortcut or gesture.
///
/// Implementations are lightweight `struct`s (no heap allocation) that
/// translate a screen point into one or more Accessibility actions. They are
/// pure operations with no long-lived state, so a single shared instance per
/// action can be reused across the app's lifetime.
protocol ShortcutAction {
    func perform(at point: CGPoint, service: AccessibilityServiceProtocol)
}
