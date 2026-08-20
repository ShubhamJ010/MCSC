import Foundation

/// Detects a "pinch-out" gesture: two fingers move apart.
///
/// Thin subclass of `BasePinchRecognizer` (direction: outward).
/// State machine: idle → tracking (2 fingers) → cooldown → idle
final class PinchOutRecognizer: BasePinchRecognizer {
    init() {
        super.init(direction: .outward)
    }
}
