#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Building and running MCSC Unit Test Suite..."

swiftc \
  -F /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks \
  -I /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib \
  -L /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib \
  -framework XCTest \
  -framework Cocoa \
  -framework ApplicationServices \
  -Xlinker -rpath -Xlinker /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks \
  -Xlinker -rpath -Xlinker /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib \
  -o "${SCRIPT_DIR}/bin_test_runner" \
  "${ROOT_DIR}/MCSC/Services/MultitouchService.swift" \
  "${ROOT_DIR}/MCSC/Services/MultitouchBridge.swift" \
  "${ROOT_DIR}/MCSC/Services/AccessibilityService.swift" \
  "${ROOT_DIR}/MCSC/Services/HapticService.swift" \
  "${ROOT_DIR}/MCSC/Services/MissionControlHoverService.swift" \
  "${ROOT_DIR}/MCSC/Views/PreviewCloseButtonOverlay.swift" \
  "${ROOT_DIR}/MCSC/Models/GestureRecognizer.swift" \
  "${ROOT_DIR}/MCSC/Models/PinchInRecognizer.swift" \
  "${ROOT_DIR}/MCSC/Models/TwoFingerSwipeLeftRecognizer.swift" \
  "${ROOT_DIR}/MCSC/Models/TwoFingerSwipeRightRecognizer.swift" \
  "${ROOT_DIR}/MCSC/Models/SwipeRecognizer.swift" \
  "${ROOT_DIR}/MCSC/Models/TwoFingerDoubleTapRecognizer.swift" \
  "${ROOT_DIR}/MCSC/Models/ShortcutActions.swift" \
  "${SCRIPT_DIR}/Mocks/MockAccessibilityService.swift" \
  "${SCRIPT_DIR}/PinchInRecognizerTests.swift" \
  "${SCRIPT_DIR}/CmdSwipeActionsTests.swift" \
  "${SCRIPT_DIR}/GestureEngineRoutingTests.swift" \
  "${SCRIPT_DIR}/MissionControlHoverServiceTests.swift" \
  "${SCRIPT_DIR}/TestRunner.swift"

trap 'rm -f "${SCRIPT_DIR}/bin_test_runner"' EXIT

"${SCRIPT_DIR}/bin_test_runner"
