# Changelog

## 0.3.2 (17 Aug 2026)

- **Cursor-Anchored Action Feedback**: Reused the same `xmark.circle.fill` (Close) and `minus.circle.fill` (Minimize) symbols from the Mission Control hover overlay as a transient, non-interactive visual feedback flash anchored at the mouse cursor whenever a close or minimize action executes:
  - `Cmd+W` (close) → red X flash at the cursor.
  - `Cmd+M` (minimize) → yellow minus flash at the cursor.
  - Pinch-in (close) and swipe-up (minimize) gestures → matching feedback at the cursor.
  - Auto-fades after ~0.45 s; repeated triggers reset the timer. Click-through (`ignoresMouseEvents`), lazily allocated, and cleaned up on `stop()`.

## 0.3.1 (17 Aug 2026)

- **Mission Control Hover Buttons**: Added preview close (`xmark.circle.fill`) and minimize (`minus.circle.fill`) action overlay button anchored directly to the top-left vertex of window thumbnails in Mission Control.
  - Supports Cmd-hold toggle to switch between Close and Minimize modes with smooth symbol content replacement animations.
  - Integrated `.drawOn.byLayer` / `.appear.byLayer` entry symbol animations and `.rotate.byLayer` click animations.
- **Bug Fix**: Fixed application crash when clicking the close or minimize overlay button caused by recursive `dispatch_sync` execution on the main queue within the event tap callback.
- **Reliability & Fallbacks**: Added type-safe AX attribute resolution, fallback application activation + action triggering for non-standard windows, and window list caching cleanups.

## 16 Aug 2026

- **Haptics & Gesture Target Validation**: Fixed phantom haptic feedback when scrolling or performing two-finger gestures over empty areas (wallpaper / Spaces bar) in Mission Control. Removed premature haptic triggers from recognizers (`SwipeRecognizer`, `TwoFingerSwipeLeftRecognizer`, `TwoFingerSwipeRightRecognizer`, `TwoFingerDoubleTapRecognizer`, `PinchInRecognizer`) to keep models pure. Introduced `HapticService` and added target resolution in `ShortcutViewModel` so haptics and actions only execute when hovering over a valid window thumbnail or Dock item.

## 16 Aug 2026 (Breaking Gesture Refactor)

- **ShortcutActions.swift**: Removed `MoveWindowToSpaceAction` and `SpaceDirection`. Added `CloseAllTabsAction` (posts Cmd+Shift+W to close all tabs/windows) and `NewWindowAction` (posts Cmd+N to open a new window).
- **PinchInRecognizer.swift**: Fixed `processFrame` to emit `.pinchIn` / `.cmdPinchIn` instead of `.swipeLeft` / `.cmdSwipeLeft`.
- **ShortcutViewModel.swift**:
  - Registered `PinchInRecognizer` in `GestureEngine`.
  - Routed `pinchIn` to Close Window / Close Application and `cmdPinchIn` to Force Quit.
  - Routed `cmdSwipeLeft` to Close All Tabs (Cmd+Shift+W).
  - Routed `cmdSwipeRight` to New Window (Cmd+N).
  - Added `isPinchInEnabled` property.
- **AppDelegate.swift**:
  - Added "Pinch In → Close / Quit" toggle to status menu.
  - Updated "Swipe Left" label to "Swipe Left → Close Tab (Cmd: Close All Cmd⌥W)".
  - Updated "Swipe Right" label to "Swipe Right → Reopen Tab (Cmd: New Window Cmd⌥N)".
- **README.md**: Updated gestures table to document the full gesture mapping matrix.

## 16 Aug 2026

- **ShortcutActions.swift**: Replaced `FullscreenWindowAction` with `MakeLargerAction` to increase window dimensions by 33% (anchored at center and clamped to the active display bounds).
- **AccessibilityService.swift**: Added `getFrame(for:)` to `AccessibilityServiceProtocol` and `AccessibilityService` using `kAXPositionAttribute` and `kAXSizeAttribute`.
- **ShortcutViewModel.swift**: Replaced `fullscreenAction` with `makeLargerAction` for `swipeDown` and `cmdSwipeDown` gestures.
- **AppDelegate.swift**: Updated menu item label to "Swipe Down → Make Larger (+33%)".
- **README.md**: Updated gesture documentation table.

## 12 Jul 2026

- **AccessibilityService.swift**: Fixed Dock gesture/shortcut resolution for non-native apps (Mac Catalyst, Electron). `isDockItem` and `getAppFromDockItem` now walk up to the nearest `AXDockItem` ancestor (hit element is often a badge/AXImage child) and resolve the running app by **bundle identifier** via the Dock item's `AXURL` first, falling back to a case/diacritic/whitespace-insensitive `AXTitle` match. Previously an exact `localizedName == AXTitle` equality caused `getAppFromDockItem` to return `nil` for these apps, silently degrading into a window lookup that found no window on a Dock icon — so `Cmd+W`/swipe/pinch over their Dock icons did nothing. Window-targeted actions are unaffected.

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
