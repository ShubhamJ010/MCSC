import Foundation
import Cocoa

/// Detects a three-finger double tap on the trackpad.
///
/// State machine:
///   idle → tap1Down (3 fingers detected)
///        → tap1Up (all 3 lifted, waiting for second tap)
///        → cooldown (second tap detected → action fired) → idle
class ThreeFingerDoubleTapRecognizer: GestureRecognizer {

    struct Config {
        /// Maximum time between first lift and second touch (seconds).
        var doubleTapWindow: Double = 0.4

        /// Maximum duration of a single tap (finger-down to finger-up).
        var maxTapDuration: Double = 0.3

        /// Cooldown after a successful gesture.
        var cooldownDuration: Double = 0.8
    }

    var config = Config()

    /// Return true if this recognizer should be active.
    var isEnabled: (() -> Bool)?

    /// Called when gesture completes. Return true if Cmd is held.
    var isCmdHeld: (() -> Bool)?

    // MARK: - State

    private enum State {
        case idle
        case tap1Down(startTime: Double)
        case tap1Up(liftTime: Double)
        case cooldown(until: Double)
    }

    private var state: State = .idle

    // MARK: - GestureRecognizer

    func processFrame(_ touches: [TouchPoint], timestamp: Double) -> GestureResult? {
        guard isEnabled?() ?? true else { return nil }

        switch state {

        case .idle:
            if touches.count >= 3 {
                state = .tap1Down(startTime: timestamp)
            }
            return nil

        case .tap1Down(let startTime):
            // Timeout: fingers held too long — not a tap
            if timestamp - startTime > config.maxTapDuration {
                state = .idle
                return nil
            }
            // All 3 fingers lifted → first tap complete
            if touches.count == 0 {
                state = .tap1Up(liftTime: timestamp)
            }
            return nil

        case .tap1Up(let liftTime):
            // Timeout: second tap didn't come in time
            if timestamp - liftTime > config.doubleTapWindow {
                state = .idle
                return nil
            }
            // Second tap: 3 fingers touch down again
            if touches.count >= 3 {
                fireHaptic()
                state = .cooldown(until: timestamp + config.cooldownDuration)
                let cmdHeld = isCmdHeld?() ?? false
                return cmdHeld ? .cmdThreeFingerDoubleTap : .threeFingerDoubleTap
            }
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

    private func fireHaptic() {
        DispatchQueue.main.async {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .generic,
                performanceTime: .now
            )
        }
    }
}