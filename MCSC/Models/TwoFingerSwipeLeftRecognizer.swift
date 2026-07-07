import Foundation
import Cocoa

/// Detects a two-finger horizontal swipe left on the trackpad.
///
/// State machine:
///   idle → tracking (2 fingers detected, recording start X)
///        → cooldown (threshold crossed → action fired) → idle
class TwoFingerSwipeLeftRecognizer: GestureRecognizer {

    struct Config {
        /// Minimum horizontal displacement (normalized 0–1) to trigger a swipe left.
        var swipeThreshold: Float = 0.08

        /// Maximum time (seconds) the gesture can take.
        var maxGestureDuration: Double = 0.8

        /// Cooldown after a successful gesture.
        var cooldownDuration: Double = 0.8

        /// Dead zone for tap/slide discrimination. Movement within this zone
        /// does not commit to swipe, leaving the result to tap recognizers.
        var tapSlideZone: Float = 0.04
    }

    var config = Config()

    /// Return true if this recognizer should be active.
    var isEnabled: (() -> Bool)?

    /// Called when a swipe gesture completes. Return true if the Cmd key is held.
    var isCmdHeld: (() -> Bool)?

    // MARK: - State

    private enum State {
        case idle

        case tracking(
            finger1ID: Int32,
            finger2ID: Int32,
            startMidX: Float,
            startMidY: Float,
            startedMoving: Bool,
            startTime: Double
        )

        case cooldown(until: Double)
    }

    private var state: State = .idle

    // MARK: - GestureRecognizer

    func processFrame(_ touches: [TouchPoint], timestamp: Double) -> GestureResult? {
        guard isEnabled?() ?? true else { return nil }

        switch state {

        case .idle:
            if touches.count == 2 {
                let midX = (touches[0].normalizedX + touches[1].normalizedX) / 2.0
                let midY = (touches[0].normalizedY + touches[1].normalizedY) / 2.0
                state = .tracking(
                    finger1ID: touches[0].identifier,
                    finger2ID: touches[1].identifier,
                    startMidX: midX,
                    startMidY: midY,
                    startedMoving: false,
                    startTime: timestamp
                )
            }
            return nil

        case .tracking(let f1ID, let f2ID, let startMidX, let startMidY, let startedMoving, let startTime):
            if timestamp - startTime > config.maxGestureDuration {
                state = .idle
                return nil
            }

            let f1 = touches.first(where: { $0.identifier == f1ID })
            let f2 = touches.first(where: { $0.identifier == f2ID })

            guard let f1 = f1, let f2 = f2 else {
                state = .idle
                return nil
            }

            let currentMidX = (f1.normalizedX + f2.normalizedX) / 2.0
            let currentMidY = (f1.normalizedY + f2.normalizedY) / 2.0
            let deltaX = currentMidX - startMidX

            // Tap/slide discrimination: once movement exceeds tap-zone, commit
            var committed = startedMoving
            if !committed {
                committed = abs(deltaX) > config.tapSlideZone
            }

            guard committed else { return nil }

            // Swipe left = deltaX is negative (moving toward lower X values)
            if deltaX <= -config.swipeThreshold {
                let center: (Float, Float) = (currentMidX, currentMidY)
                let cmdHeld = isCmdHeld?() ?? false

                fireHaptic()
                state = .cooldown(until: timestamp + config.cooldownDuration)

                return cmdHeld ? .cmdSwipeLeft(atNormalized: center) : .swipeLeft(atNormalized: center)
            }

            // Still tracking, but haven't crossed threshold yet
            state = .tracking(
                finger1ID: f1ID, finger2ID: f2ID,
                startMidX: startMidX, startMidY: startMidY,
                startedMoving: committed,
                startTime: startTime
            )
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

    private func fireHaptic() {
        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.alignment, performanceTime: .now)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.05) {
            performer.perform(.levelChange, performanceTime: .now)
        }
    }
}