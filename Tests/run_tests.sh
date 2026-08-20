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
  "${ROOT_DIR}/MCSC/Services/Multitouch/MultitouchService.swift" \
  "${ROOT_DIR}/MCSC/Services/Multitouch/MultitouchBridge.swift" \
  "${ROOT_DIR}/MCSC/Services/Accessibility/AccessibilityService.swift" \
  "${ROOT_DIR}/MCSC/Services/Volume/MountedVolumeService.swift" \
  "${ROOT_DIR}/MCSC/Services/Haptics/HapticService.swift" \
  "${ROOT_DIR}/MCSC/Services/MissionControl/MissionControlHoverService.swift" \
  "${ROOT_DIR}/MCSC/Services/MissionControl/MCKeyboardTapService.swift" \
  "${ROOT_DIR}/MCSC/Models/WindowSelectionEngine.swift" \
  "${ROOT_DIR}/MCSC/Models/WindowSearchSession.swift" \
  "${ROOT_DIR}/MCSC/Models/Actions/WindowActivationAction.swift" \
  "${ROOT_DIR}/MCSC/Views/PreviewCloseButtonOverlay.swift" \
  "${ROOT_DIR}/MCSC/Views/SearchBarOverlay.swift" \
  "${ROOT_DIR}/MCSC/Views/CursorFeedbackOverlay.swift" \
  "${ROOT_DIR}/MCSC/Views/CursorFeedbackMode.swift" \
  "${ROOT_DIR}/MCSC/Utilities/Logger.swift" \
  "${ROOT_DIR}/MCSC/Utilities/ScreenGeometry.swift" \
  "${ROOT_DIR}/MCSC/Utilities/KeyboardEventPoster.swift" \
  "${ROOT_DIR}/MCSC/Utilities/SymbolImageFactory.swift" \
  "${ROOT_DIR}/MCSC/Models/Gestures/GestureRecognizer.swift" \
  "${ROOT_DIR}/MCSC/Models/Gestures/PinchInRecognizer.swift" \
  "${ROOT_DIR}/MCSC/Models/Gestures/TwoFingerSwipeLeftRecognizer.swift" \
  "${ROOT_DIR}/MCSC/Models/Gestures/TwoFingerSwipeRightRecognizer.swift" \
  "${ROOT_DIR}/MCSC/Models/Gestures/SwipeRecognizer.swift" \
  "${ROOT_DIR}/MCSC/Models/Gestures/TwoFingerDoubleTapRecognizer.swift" \
  "${ROOT_DIR}/MCSC/Models/Actions/ShortcutAction.swift" \
  "${ROOT_DIR}/MCSC/Models/Actions/WindowActions.swift" \
  "${ROOT_DIR}/MCSC/Models/Actions/VolumeActions.swift" \
  "${ROOT_DIR}/MCSC/Models/Actions/AppActions.swift" \
  "${ROOT_DIR}/MCSC/Models/Actions/TabActions.swift" \
  "${ROOT_DIR}/MCSC/Models/Actions/TilingActions.swift" \
  "${ROOT_DIR}/MCSC/Models/Actions/MissionControlWindowActions.swift" \
  "${ROOT_DIR}/MCSC/ViewModels/ShortcutConfiguration.swift" \
  "${ROOT_DIR}/MCSC/ViewModels/Routing/ActionRegistry.swift" \
  "${ROOT_DIR}/MCSC/ViewModels/Routing/ShortcutActionRouter.swift" \
  "${ROOT_DIR}/MCSC/ViewModels/Routing/GestureActionRouter.swift" \
  "${SCRIPT_DIR}/Mocks/MockAccessibilityService.swift" \
  "${SCRIPT_DIR}/PinchInRecognizerTests.swift" \
  "${SCRIPT_DIR}/CmdSwipeActionsTests.swift" \
  "${SCRIPT_DIR}/GestureEngineRoutingTests.swift" \
  "${SCRIPT_DIR}/MissionControlHoverServiceTests.swift" \
  "${SCRIPT_DIR}/WindowSelectionEngineTests.swift" \
  "${SCRIPT_DIR}/WindowSearchSessionTests.swift" \
  "${SCRIPT_DIR}/SearchBarOverlayTests.swift" \
  "${SCRIPT_DIR}/CursorFeedbackOverlayTests.swift" \
  "${SCRIPT_DIR}/RouterTests.swift" \
  "${SCRIPT_DIR}/TestRunner.swift"

trap 'rm -f "${SCRIPT_DIR}/bin_test_runner"' EXIT

"${SCRIPT_DIR}/bin_test_runner"
