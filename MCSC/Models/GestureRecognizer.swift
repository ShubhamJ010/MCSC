import Foundation

/// Result emitted when a gesture completes.
enum GestureResult {
    case pinchIn(atNormalized: (Float, Float))
    case cmdPinchIn(atNormalized: (Float, Float))
    case swipeLeft(atNormalized: (Float, Float))
    case cmdSwipeLeft(atNormalized: (Float, Float))
    case swipeRight(atNormalized: (Float, Float))
    case cmdSwipeRight(atNormalized: (Float, Float))
    case swipeDown(atNormalized: (Float, Float))
    case cmdSwipeDown(atNormalized: (Float, Float))
    case swipeUp(atNormalized: (Float, Float))
    case cmdSwipeUp(atNormalized: (Float, Float))
    case twoFingerDoubleTap
    case cmdTwoFingerDoubleTap
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
    private var poisoned = false
    /// Set after a gesture fires; frames are ignored until all fingers lift,
    /// so each gesture triggers once per finger-lift rather than on continuous
    /// motion (e.g. repeatedly swiping up without lifting).
    private var awaitingLift = false

    func register(_ recognizer: GestureRecognizer) {
        recognizers.append(recognizer)
    }

    func processFrame(_ touches: [TouchPoint], timestamp: Double) {
        // After a gesture fires, ignore frames until every finger is lifted,
        // so a gesture triggers only once per finger-lift instead of on
        // continuous motion (e.g. repeatedly swiping up without lifting).
        if awaitingLift {
            if touches.count == 0 {
                awaitingLift = false
            } else {
                return
            }
        }

        // If 3+ fingers appear at ANY point, poison the cycle.
        // All recognizers are reset immediately, and no further
        // frames are forwarded until every finger is lifted.
        if touches.count >= 3 {
            if !poisoned {
                poisoned = true
                recognizers.forEach { $0.reset() }
            }
            return
        }

        // Un-poison only when ALL fingers are lifted
        if poisoned {
            if touches.count == 0 {
                poisoned = false
            }
            return
        }

        for recognizer in recognizers {
            if let result = recognizer.processFrame(touches, timestamp: timestamp) {
                onGestureRecognized?(result)
                // Reset all recognizers after a gesture fires
                recognizers.forEach { $0.reset() }
                // Require a full finger lift before the next gesture can fire.
                awaitingLift = true
                break
            }
        }
    }

    func reset() {
        poisoned = false
        awaitingLift = false
        recognizers.forEach { $0.reset() }
    }

    func removeAll() {
        recognizers.removeAll()
        onGestureRecognized = nil
        poisoned = false
    }
}