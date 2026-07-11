# Changelog

## 11 Jul 2026

- **MissionControlService.swift**: Fixed Mission Control detection so gestures and `Cmd` shortcuts fire **only** inside Mission Control. Detection now uses `CGWindowListCopyWindowInfo` Dock window-layer analysis — Mission Control exposes a full-screen Dock overlay at layer 20 together with the Dock bar at layer ≤ 18; Launchpad (layers 27–29) and expanded Finder folder stacks (overlay only, no Dock bar) are correctly excluded. Replaced the previous always-on `Dock layer > 0` heuristic that fired everywhere. The result is cached for 200ms to avoid polling on every trackpad frame.
- **GestureRecognizer.swift**: Added an "awaiting lift" guard to `GestureEngine` so a gesture fires only once per finger lift. Previously a gesture re-armed on the next frame and re-fired continuously while fingers were held down and moving; frames are now ignored until all fingers are lifted.

## 07 Jul 2026

- **GestureRecognizer.swift**: Added three-finger touch rejection so two-finger gestures are not triggered by three-finger input.
- **TwoFingerSwipeLeftRecognizer.swift / TwoFingerSwipeRightRecognizer.swift**: Expanded swipe recognition with a tap-slide dead zone and directional haptic feedback; reworked state machine for more reliable left/right detection.
- **SwipeRecognizer.swift**: Added tap-slide dead zone handling and per-direction haptic triggers.
- **TwoFingerDoubleTapRecognizer.swift**: Simplified haptic logic and aligned recognition with the new dead-zone behavior.
- **PinchInRecognizer.swift**: Tuned threshold handling to match the updated gesture model.
- **ShortcutViewModel.swift**: Integrated swipe left/right and refined gesture routing; removed three-finger double tap wiring and unused window fallback handling.
- **ShortcutActions.swift**: Removed unused window unminimize/unhide fallback actions.
- **AccessibilityService.swift**: Removed dead fallback paths no longer used by shortcut actions.
- **ThreeFingerDoubleTapRecognizer.swift**: Removed (gesture support dropped).
- **build-release skill**: Added user-invokable release skill (`.agents/skills/build-release`) with build and verification scripts.

## 05 Jul 2026

- **main.swift**: Fixed Swift 6 MainActor isolation error by wrapping delegate init in `MainActor.assumeIsolated`.
- **AppDelegate.swift**: Added `@MainActor` annotation. Replaced flat "Pinch to Close" menu item with "Enable Gestures" submenu containing per-gesture toggles (Pinch In, Swipe Down/Up, 3-Finger Double Tap).
- **GestureRecognizer.swift**: Added `cmdPinchIn`, `swipeDown`, `cmdSwipeDown`, `swipeUp`, `cmdSwipeUp`, `threeFingerDoubleTap`, and `cmdThreeFingerDoubleTap` result types.
- **PinchInRecognizer.swift**: Simplified state machine by removing the "armed" state — gesture fires immediately on threshold crossing. Added `isEnabled` and `isCmdHeld` closures.
- **ShortcutActions.swift**: Added `FullscreenWindowAction`, `ReasonableSizeAction`, and `AlmostMaximizeAction` for window tiling.
- **AccessibilityService.swift**: Added `setFrame(_:for:)` to set window position and size via AX API.
- **EventTapService.swift**: Added `CFEventTimestamp` typealias.
- **MissionControlService.swift**: Added `onActivated` callback fired when Mission Control opens, used for gesture cooldown.
- **MultitouchService.swift**: Made `multitouchCallback` `nonisolated` and dispatch frame data to main queue.
- **ShortcutViewModel.swift**: Integrated `SwipeRecognizer` and `ThreeFingerDoubleTapRecognizer`. Added Cmd-modifier variants for all gestures. Added Mission Control activation cooldown to prevent false gesture detection.

## 05 Jul 2026

- **AccessibilityService.swift**: Added `isDockItem()` and `getAppFromDockItem()` to detect dock icons and resolve them to running applications via AX title matching.
- **ShortcutActions.swift**: Added `CloseAppAction`, `MinimizeAppAction`, and `ForceQuitAppAction` for app-level operations on dock icons.
- **ShortcutViewModel.swift**: Shortcuts (`Cmd+W`, `Cmd+Q`, `Cmd+M`, `Cmd+H`) now work on dock icons in Mission Control, routing to app-level actions instead of window-level actions.

## 25 May 2026

- **AppDelegate.swift**: Refined status bar menu labels by removing "Toggle" prefix for cleaner UI. Added `setupStatusBar()` call during initialization to ensure accurate UI state.
- **ShortcutViewModel.swift**:
  - Disabled `Cmd + F` shortcut by default.
  - Refined `Cmd` detection logic to ensure only the `Command` modifier is active (ignoring Shift, Control, and Option) to prevent interference with other system shortcuts.
  - Removed logic related to `Cmd + F` / `maximizeAction`.
  - Restricted all shortcut actions (`Cmd+W`, `Cmd+Q`, `Cmd+M`, `Cmd+H`) to only execute when Mission Control is active.
