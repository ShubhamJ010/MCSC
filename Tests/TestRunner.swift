import Foundation
import XCTest

@main
struct TestRunner {
    static func main() {
        let suites: [XCTestSuite] = [
            PinchInRecognizerTests.defaultTestSuite,
            MoveWindowToSpaceActionTests.defaultTestSuite,
            GestureEngineRoutingTests.defaultTestSuite
        ]

        var totalFailed = 0
        var totalPassed = 0

        print("========================================")
        print("Running MCSC Unit Test Suite")
        print("========================================")

        for suite in suites {
            suite.run()
            if let result = suite.testRun {
                totalFailed += Int(result.failureCount + result.unexpectedExceptionCount)
                totalPassed += Int(result.executionCount - result.failureCount - result.unexpectedExceptionCount)
            }
        }

        print("========================================")
        print("Test Summary: \(totalPassed) passed, \(totalFailed) failed")
        print("========================================")

        if totalFailed > 0 {
            exit(1)
        }
    }
}
