import Foundation

/// Result emitted when a gesture completes.
enum GestureResult {
    case pinchIn(atNormalized: (Float, Float))
    // Future: .swipeUp, .threeFingerTap, etc.
}

/// Protocol that all gesture recognizers must conform to.
protocol GestureRecognizer: AnyObject {
    /// Process a frame of active touch points. Return a result if gesture completed.
    func processFrame(_ touches: [TouchPoint], timestamp: Double) -> GestureResult?

    /// Reset the recognizer to idle state.
    func reset()
}

/// Dispatches touch frames to all registered recognizers.
/// First recognizer to return a result wins (prevents double-firing).
class GestureEngine {
    private var recognizers: [GestureRecognizer] = []
    var onGestureRecognized: ((GestureResult) -> Void)?

    func register(_ recognizer: GestureRecognizer) {
        recognizers.append(recognizer)
    }

    func processFrame(_ touches: [TouchPoint], timestamp: Double) {
        for recognizer in recognizers {
            if let result = recognizer.processFrame(touches, timestamp: timestamp) {
                onGestureRecognized?(result)
                // Reset all recognizers after a gesture fires
                recognizers.forEach { $0.reset() }
                break
            }
        }
    }

    func reset() {
        recognizers.forEach { $0.reset() }
    }

    func removeAll() {
        recognizers.removeAll()
        onGestureRecognized = nil
    }
}
