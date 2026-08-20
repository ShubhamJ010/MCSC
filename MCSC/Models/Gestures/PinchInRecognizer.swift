import Foundation

/// Detects a "pinch-in" gesture: two fingers move closer together.
///
/// Thin subclass of `BasePinchRecognizer` (direction: inward).
/// State machine: idle → tracking (2 fingers) → cooldown → idle
final class PinchInRecognizer: BasePinchRecognizer {
    init() {
        super.init(direction: .inward)
    }
}
