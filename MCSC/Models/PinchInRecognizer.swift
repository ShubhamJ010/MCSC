import Foundation
import Cocoa

/// Detects a "pinch-in" gesture: two fingers move closer together.
///
/// State machine:
///   idle → tracking (2 fingers detected, recording initial distance)
///        → cooldown (threshold crossed → action fired) → idle
class PinchInRecognizer: GestureRecognizer {

    // MARK: - Configuration

    struct Config {
        /// Minimum ratio of distance decrease to trigger (0.0–1.0).
        /// e.g. 0.4 means the distance between fingers must decrease by 40%.
        var pinchRatioThreshold: Float = 0.4

        /// Maximum time (seconds) the gesture can take from first detection.
        var maxGestureDuration: Double = 1.5

        /// Cooldown period after a successful gesture (seconds).
        var cooldownDuration: Double = 0.8
    }

    var config = Config()

    /// Return true if this recognizer should be active.
    var isEnabled: (() -> Bool)?

    /// Called when a pinch gesture completes. Return true if the Cmd key is held.
    var isCmdHeld: (() -> Bool)?

    // MARK: - State

    private enum State {
        case idle

        /// Two fingers detected, tracking distance change.
        case tracking(
            finger1ID: Int32,
            finger2ID: Int32,
            initialDistance: Float,
            startTime: Double,
            lastDistance: Float,
            lastCenterNormalized: (Float, Float)
        )

        case cooldown(until: Double)
    }

    private var state: State = .idle

    // MARK: - GestureRecognizer

    func processFrame(_ touches: [TouchPoint], timestamp: Double) -> GestureResult? {
        guard isEnabled?() ?? true else { return nil }
        switch state {

        case .idle:
            // Need exactly 2 touching fingers to start tracking
            if touches.count == 2 {
                let d = distance(touches[0], touches[1])
                let center = midpoint(touches[0], touches[1])
                state = .tracking(
                    finger1ID: touches[0].identifier,
                    finger2ID: touches[1].identifier,
                    initialDistance: d,
                    startTime: timestamp,
                    lastDistance: d,
                    lastCenterNormalized: center
                )
            }
            return nil

        case .tracking(let f1ID, let f2ID, let initialDist, let startTime, _, _):
            // Timeout: gesture took too long
            if timestamp - startTime > config.maxGestureDuration {
                state = .idle
                return nil
            }

            // Find our tracked fingers in the current frame
            let f1 = touches.first(where: { $0.identifier == f1ID })
            let f2 = touches.first(where: { $0.identifier == f2ID })

            if let f1 = f1, let f2 = f2 {
                // Both fingers still touching — update distance
                let currentDist = distance(f1, f2)
                let center = midpoint(f1, f2)

                // Check if pinch ratio just crossed the threshold
                let ratio = initialDist > 0.05 ? (initialDist - currentDist) / initialDist : 0
                if ratio >= config.pinchRatioThreshold {
                    // Threshold crossed → fire immediately
                    fireHaptic()
                    state = .cooldown(until: timestamp + config.cooldownDuration)
                    let cmdHeld = isCmdHeld?() ?? false
                    if cmdHeld {
                        return .cmdSwipeLeft(atNormalized: center)
                    }
                    return .swipeLeft(atNormalized: center)
                } else {
                    state = .tracking(
                        finger1ID: f1ID, finger2ID: f2ID,
                        initialDistance: initialDist,
                        startTime: startTime,
                        lastDistance: currentDist,
                        lastCenterNormalized: center
                    )
                }
                return nil
            }

            // Finger(s) lifted before threshold was reached — cancel
            state = .idle
            return nil

        case .cooldown(let until):
            if timestamp > until {
                state = .idle
            }
            return nil
        }
    }

    func reset() {
        state = .idle
    }

    // MARK: - Haptic Feedback

    /// Fires a subtle haptic "tick" to confirm the pinch threshold was reached.
    private func fireHaptic() {
        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.levelChange, performanceTime: .now)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.08) {
            performer.perform(.levelChange, performanceTime: .now)
        }
    }

    // MARK: - Geometry Helpers

    private func distance(_ a: TouchPoint, _ b: TouchPoint) -> Float {
        let dx = a.normalizedX - b.normalizedX
        let dy = a.normalizedY - b.normalizedY
        return sqrt(dx * dx + dy * dy)
    }

    private func midpoint(_ a: TouchPoint, _ b: TouchPoint) -> (Float, Float) {
        return ((a.normalizedX + b.normalizedX) / 2.0,
                (a.normalizedY + b.normalizedY) / 2.0)
    }
}
