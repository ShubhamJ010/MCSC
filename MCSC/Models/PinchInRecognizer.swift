import Foundation
import Cocoa

/// Detects a "pinch-in" gesture: two fingers move closer together,
/// then lift off the trackpad.
///
/// State machine:
///   idle → tracking (2 fingers detected, recording initial distance)
///        → recognized (distance decreased by threshold + fingers lifted)
///        → cooldown (prevent rapid re-fires) → idle
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

    // MARK: - State

    private enum State {
        case idle
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

        case .tracking(let f1ID, let f2ID, let initialDist, let startTime, _, let lastCenter):
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
                state = .tracking(
                    finger1ID: f1ID, finger2ID: f2ID,
                    initialDistance: initialDist,
                    startTime: startTime,
                    lastDistance: currentDist,
                    lastCenterNormalized: center
                )
                return nil
            }

            // At least one finger lifted — check if pinch threshold was met
            // (we use lastDistance since the fingers are now gone)
            if let result = checkCompletion(initialDist: initialDist, lastCenter: lastCenter, timestamp: timestamp) {
                return result
            }
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

    // MARK: - Helpers

    private func checkCompletion(initialDist: Float, lastCenter: (Float, Float), timestamp: Double) -> GestureResult? {
        guard case .tracking(_, _, _, _, let lastDist, _) = state else { return nil }

        let ratio = (initialDist - lastDist) / initialDist
        if ratio >= config.pinchRatioThreshold && initialDist > 0.05 {
            // Haptic feedback
            DispatchQueue.main.async {
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            }
            state = .cooldown(until: timestamp + config.cooldownDuration)
            return .pinchIn(atNormalized: lastCenter)
        }
        return nil
    }

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
