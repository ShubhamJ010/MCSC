import Foundation
import XCTest

final class PinchInRecognizerTests: XCTestCase {
    private var recognizer: PinchInRecognizer!

    override func setUp() {
        super.setUp()
        recognizer = PinchInRecognizer()
    }

    override func tearDown() {
        recognizer = nil
        super.tearDown()
    }

    func testPinchInTriggerWhenThresholdCrossed() {
        recognizer.isCmdHeld = { false }

        // Initial frame: 2 fingers distance = 0.5
        let touch1 = TouchPoint(identifier: 1, state: 4, normalizedX: 0.2, normalizedY: 0.5, size: 1.0)
        let touch2 = TouchPoint(identifier: 2, state: 4, normalizedX: 0.7, normalizedY: 0.5, size: 1.0)
        let result1 = recognizer.processFrame([touch1, touch2], timestamp: 1.0)
        XCTAssertNil(result1, "Initial touch frame should start tracking and return nil")

        // Second frame: fingers move closer (distance = 0.2, a 60% decrease >= 40% threshold)
        let touch1Moved = TouchPoint(identifier: 1, state: 4, normalizedX: 0.4, normalizedY: 0.5, size: 1.0)
        let touch2Moved = TouchPoint(identifier: 2, state: 4, normalizedX: 0.6, normalizedY: 0.5, size: 1.0)
        let result2 = recognizer.processFrame([touch1Moved, touch2Moved], timestamp: 1.1)

        guard let result = result2 else {
            XCTFail("Expected pinchIn gesture result, got nil")
            return
        }

        switch result {
        case .pinchIn(let center):
            XCTAssertEqual(center.0, 0.5, accuracy: 0.01)
            XCTAssertEqual(center.1, 0.5, accuracy: 0.01)
        default:
            XCTFail("Expected .pinchIn, got \(result)")
        }
    }

    func testCmdPinchInTriggerWhenCmdHeld() {
        recognizer.isCmdHeld = { true }

        let touch1 = TouchPoint(identifier: 1, state: 4, normalizedX: 0.2, normalizedY: 0.5, size: 1.0)
        let touch2 = TouchPoint(identifier: 2, state: 4, normalizedX: 0.7, normalizedY: 0.5, size: 1.0)
        _ = recognizer.processFrame([touch1, touch2], timestamp: 1.0)

        // 60% distance reduction
        let touch1Moved = TouchPoint(identifier: 1, state: 4, normalizedX: 0.4, normalizedY: 0.5, size: 1.0)
        let touch2Moved = TouchPoint(identifier: 2, state: 4, normalizedX: 0.6, normalizedY: 0.5, size: 1.0)
        let result = recognizer.processFrame([touch1Moved, touch2Moved], timestamp: 1.1)

        guard let res = result else {
            XCTFail("Expected cmdPinchIn gesture result, got nil")
            return
        }

        switch res {
        case .cmdPinchIn(let center):
            XCTAssertEqual(center.0, 0.5, accuracy: 0.01)
            XCTAssertEqual(center.1, 0.5, accuracy: 0.01)
        default:
            XCTFail("Expected .cmdPinchIn, got \(res)")
        }
    }

    func testPinchInBelowThresholdDoesNotTrigger() {
        // Initial distance = 0.5
        let touch1 = TouchPoint(identifier: 1, state: 4, normalizedX: 0.2, normalizedY: 0.5, size: 1.0)
        let touch2 = TouchPoint(identifier: 2, state: 4, normalizedX: 0.7, normalizedY: 0.5, size: 1.0)
        _ = recognizer.processFrame([touch1, touch2], timestamp: 1.0)

        // Distance = 0.46 (8% reduction, threshold is 40%)
        let touch1Moved = TouchPoint(identifier: 1, state: 4, normalizedX: 0.22, normalizedY: 0.5, size: 1.0)
        let touch2Moved = TouchPoint(identifier: 2, state: 4, normalizedX: 0.68, normalizedY: 0.5, size: 1.0)
        let result = recognizer.processFrame([touch1Moved, touch2Moved], timestamp: 1.1)

        XCTAssertNil(result, "Small movement below threshold should not trigger gesture")
    }

    func testPinchInTimesOutAfterMaxDuration() {
        let touch1 = TouchPoint(identifier: 1, state: 4, normalizedX: 0.2, normalizedY: 0.5, size: 1.0)
        let touch2 = TouchPoint(identifier: 2, state: 4, normalizedX: 0.7, normalizedY: 0.5, size: 1.0)
        _ = recognizer.processFrame([touch1, touch2], timestamp: 1.0)

        // Frame after 2.0s (> 1.5s maxGestureDuration)
        let touch1Moved = TouchPoint(identifier: 1, state: 4, normalizedX: 0.4, normalizedY: 0.5, size: 1.0)
        let touch2Moved = TouchPoint(identifier: 2, state: 4, normalizedX: 0.6, normalizedY: 0.5, size: 1.0)
        let result = recognizer.processFrame([touch1Moved, touch2Moved], timestamp: 3.1)

        XCTAssertNil(result, "Gesture exceeding max duration should time out")
    }

    func testPinchInFingerLiftCancelsTracking() {
        let touch1 = TouchPoint(identifier: 1, state: 4, normalizedX: 0.2, normalizedY: 0.5, size: 1.0)
        let touch2 = TouchPoint(identifier: 2, state: 4, normalizedX: 0.7, normalizedY: 0.5, size: 1.0)
        _ = recognizer.processFrame([touch1, touch2], timestamp: 1.0)

        // Finger 2 lifted before threshold reached
        let result = recognizer.processFrame([touch1], timestamp: 1.1)
        XCTAssertNil(result, "Lifting a finger should cancel tracking")

        // Next frame with 1 finger returns nil
        let resultAfter = recognizer.processFrame([touch1], timestamp: 1.2)
        XCTAssertNil(resultAfter)
    }

    func testPinchInDisabledReturnsNil() {
        recognizer.isEnabled = { false }

        let touch1 = TouchPoint(identifier: 1, state: 4, normalizedX: 0.2, normalizedY: 0.5, size: 1.0)
        let touch2 = TouchPoint(identifier: 2, state: 4, normalizedX: 0.7, normalizedY: 0.5, size: 1.0)
        _ = recognizer.processFrame([touch1, touch2], timestamp: 1.0)

        let touch1Moved = TouchPoint(identifier: 1, state: 4, normalizedX: 0.4, normalizedY: 0.5, size: 1.0)
        let touch2Moved = TouchPoint(identifier: 2, state: 4, normalizedX: 0.6, normalizedY: 0.5, size: 1.0)
        let result = recognizer.processFrame([touch1Moved, touch2Moved], timestamp: 1.1)

        XCTAssertNil(result, "Disabled recognizer must return nil")
    }

    func testPinchInCooldownSuppressesImmediateRefire() {
        let touch1 = TouchPoint(identifier: 1, state: 4, normalizedX: 0.2, normalizedY: 0.5, size: 1.0)
        let touch2 = TouchPoint(identifier: 2, state: 4, normalizedX: 0.7, normalizedY: 0.5, size: 1.0)
        _ = recognizer.processFrame([touch1, touch2], timestamp: 1.0)

        let touch1Moved = TouchPoint(identifier: 1, state: 4, normalizedX: 0.4, normalizedY: 0.5, size: 1.0)
        let touch2Moved = TouchPoint(identifier: 2, state: 4, normalizedX: 0.6, normalizedY: 0.5, size: 1.0)
        let result = recognizer.processFrame([touch1Moved, touch2Moved], timestamp: 1.1)
        XCTAssertNotNil(result)

        // Next frame during cooldown (timestamp < 1.1 + 0.8)
        let resultDuringCooldown = recognizer.processFrame([touch1Moved, touch2Moved], timestamp: 1.3)
        XCTAssertNil(resultDuringCooldown, "Frames during cooldown should return nil")
    }

    func testPinchInResetClearsState() {
        let touch1 = TouchPoint(identifier: 1, state: 4, normalizedX: 0.2, normalizedY: 0.5, size: 1.0)
        let touch2 = TouchPoint(identifier: 2, state: 4, normalizedX: 0.7, normalizedY: 0.5, size: 1.0)
        _ = recognizer.processFrame([touch1, touch2], timestamp: 1.0)

        recognizer.reset()

        // After reset, moving fingers should not trigger because initial distance was reset
        let touch1Moved = TouchPoint(identifier: 1, state: 4, normalizedX: 0.4, normalizedY: 0.5, size: 1.0)
        let touch2Moved = TouchPoint(identifier: 2, state: 4, normalizedX: 0.6, normalizedY: 0.5, size: 1.0)
        let result = recognizer.processFrame([touch1Moved, touch2Moved], timestamp: 1.1)
        XCTAssertNil(result, "Reset should clear initial tracking distance and state")
    }
}
