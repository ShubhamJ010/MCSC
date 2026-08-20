# Changelog

## 0.5.0-beta (21 Aug 2026)

- **Pinch-Out Gesture for Fullscreen & Windowing**: New `PinchOutRecognizer` (extracted shared `BasePinchRecognizer`) — `pinch-out` toggles fullscreen (`kAXZoomButtonAttribute` + `CoreDockSendNotification("com.apple.expose.awake")`), `Cmd+pinch-out` creates a new window (`Cmd+N`). Includes distinct haptic (`alignment → levelChange` vs `levelChange → levelChange` for pinch-in) and `.fullscreen` cursor feedback (`arrow.down.left.and.arrow.up.right.circle.fill`, black/green palette). Toggle via `isPinchOutEnabled` / menu bar. See `PinchOutRecognizer.swift`, `WindowActions.swift:ToggleFullscreenAction`, `HapticService.swift:pinchOut`.
- **Dock Parity for Tiling / Fullscreen**: `SwipeDown` (Fill / Make Larger), `DoubleTap` (Reasonable 60% / Almost 90%), and `Pinch-Out` (Fullscreen) now resolve Dock targets via `AppActions.swift:111` — swiping/resizing on a Dock icon in Mission Control acts on the app's windows. `GestureActionRouter` previously returned `.none` for Dock on those paths.
- **Fullscreen Hover + Event-Tap Resilience**: `PreviewCloseButtonOverlay.Mode.fullscreen` (4th mode, green `arrow.down…circle.fill`) added to hover button; `MissionControlWindowActions.swift:performFullscreen` provides Mission Control dictionary path (`CoreDockSendNotification`) fallback. `EventTapService` auto-recreates tap on `.tapDisabledByTimeout` / `.tapDisabledByUserInput`.
- **Tab-Close Reliability Fix**: `AccessibilityService.findActiveTabCloseButton(in:)` now recursively descends bounded depth 8, skipping `AXWebArea`, to find `AXTabGroup` under `AXGroup` wrappers (Chrome). Fixes `Cmd+W` / swipe-left previously falling back to unreliable `Cmd+W`. Fallback now focuses hovered window via `kAXFocusedAttribute` first.
- **macOS 14+ Symbol-Effect Fallbacks**: Dropped macOS 26-only `.wiggle` / `.magic` requirements — `.wiggle.byLayer` falls back to `.bounce` on <26, `.magic(fallback: .upUp)` falls back to `.upUp.byLayer`. Prevents missing animations on 14/15.
- **MVVM Reorganization**: Moved to strict MVVM layout — `Models/Actions/`, `Models/Gestures/`, `Services/{Accessibility,EventTap,Haptics,LaunchAtLogin,MissionControl,Multitouch}`, `ViewModels/Routing/`, `Utilities/`. Extracted `ShortcutActionRouter` / `GestureActionRouter` / `ActionRegistry` / `ShortcutConfiguration` and `ScreenGeometry` / `SymbolImageFactory` / `KeyboardEventPoster`.
- **README Feature Advertising**: Expanded `README.md:34` from 7 to 11 bullets — new standalone entries for Hover Buttons, Cursor Feedback + Haptics (14 modes), Window Tiling & Tab Control, Auto-Eject, Dock-Aware Targeting, and Fully Configurable toggles.
- **Includes 0.4.1 & 0.4.2**: This beta rolls up **Mounted Volume Auto-Eject (0.4.1)** and **Type-to-Select Fuzzy Finder (0.4.2)** — see entries below — which were committed after `v0.4.0-beta` but not yet released.

## 0.4.2 (20 Aug 2026)

- **Type-to-Select Window Fuzzy Finder**: Simply start typing any app or window name while in Mission Control to immediately search, rank, and highlight visible windows:
  - **Stateless Selection Engine (`WindowSelectionEngine`)**: Ranks matches with prefix hits taking priority over substring hits, sorted alphabetically and by window ID.
  - **Top-Left Shoulder Targeting**: Targets the thumbnail's top-left shoulder (inset 20 pt right & down) rather than the center, ensuring windows grouped/stacked by application remain reachable without being blocked by the close/minimize button bar.
  - **Native Highlight Synchronization**: Injects synthetic `.mouseMoved` events so macOS Mission Control paints its native blue highlight on the matched window while keeping `hoveredWindow` in sync for subsequent `Cmd` shortcuts (`Cmd+W`, `Cmd+Q`, `Cmd+M`).
  - **Activation with 50 ms Dwell Click (`WindowActivationAction`)**: Pressing `Enter` / `Return` injects a timed `mouseMoved` → `leftMouseDown` → 50 ms dwell → `leftMouseUp` sequence at `.cghidEventTap` to reliably activate and raise the window while dismissing Mission Control.
  - **Dedicated HID Key Tap (`MCKeyboardTapService`)**: Installs a `.cghidEventTap` `keyDown` tap active strictly during Mission Control to capture keystrokes before the WindowServer swallows them.
  - **Dock-Style Query Pill (`SearchBarOverlay`)**: Renders an uppercase, bold (22 pt heavy) query bar using continuous squircle corners (`layer.cornerCurve = .continuous`) and macOS HUD material, floating cleanly above the Dock.
  - **Navigation Controls**: `Tab` and `Down Arrow` cycle forward; `Up Arrow` cycles backward; `Backspace` deletes characters; `Escape` (or 2-second idle timeout) resets the query.
- **Community Acknowledgement**: Special thanks to [OpenMissionControl](https://github.com/nohackjustnoobb/OpenMissionControl) and [PR #3 (changes)](https://github.com/nohackjustnoobb/OpenMissionControl/pull/3/changes) for inspiring and unlocking key techniques in macOS Exposé window handling and low-level SPI usage.

## 0.4.1 (20 Aug 2026)

- **Mounted Volume Auto-Eject Enhancement**: When pressing `Cmd+W` or `Cmd+Q` (or using pinch-in/swipe-left gestures) on a Finder window showing an ejectable volume (e.g. DMG installers) in Mission Control, MCSC automatically closes the window and unmounts/ejects the volume.
- **Eject Feedback Overlay**: Flashes `eject.circle.fill` with Red 100% primary tint (`[.white, .systemRed]` palette) and the same hover-style scale + alpha animation (1.08× scale over 0.15s ease-out) at the cursor position.
- **Menu Bar Toggle**: Added "Auto-Eject Mounted Volumes" toggle to status bar menu.

## 0.4.0-beta (18 Aug 2026)

- **Cmd+W Multi-Window Targeting Fix**: `CloseTabAction`/`CloseTabAppAction` now close the hovered window's active tab reliably in Mission Control. `findActiveTabCloseButton` recursively descends the AX tree (bounded depth, skipping `AXWebArea`) to locate the `AXTabGroup`/`AXRadioButton` close button — fixing browsers whose tab strip is nested under an `AXGroup` (e.g. Chrome) rather than a direct window child, which previously forced the unreliable ⌘W fallback. When no accessible tab button exists, the ⌘W fallback now focuses the hovered window first via `kAXFocusedAttribute` (best-effort). Browsers with non-standard tab UIs (Zen, Dia) or limited AX exposure (Safari) still fall back to the ⌘W path.
- **Tab Swipe Feedback**: two-finger swipe-left (Close Tab) flashes `xmark.rectangle.fill`, swipe-right (Reopen Tab) `plus.rectangle.fill`, Cmd+swipe-left (Close All Tabs) `rectangle.badge.xmark`, and Cmd+swipe-right (New Window) `rectangle.badge.plus` at the cursor — all animated with `.wiggle.byLayer` on macOS 26+ (`.bounce` fallback before). This closes the last cursor-feedback gaps: every shortcut and gesture now flashes.
- **Maximize Feedback**: swipe-down (Make Larger) now flashes an accent-coloured `rectangle.fill` at the cursor, animated with a `.replace.downUp.byLayer` content transition.
- **Hover Button Modifier Actions**: the Mission Control hover button now supports three actions. No modifier shows the Close button; holding **Option** switches it to Minimize (`minus.circle.fill`); holding **Cmd** switches it to Force Quit (the black→purple `xmark.circle.fill`). Clicking performs the shown action. Cmd takes precedence when both modifiers are held.
- **Resize Feedback**: two-finger double-tap (Reasonable Size), Cmd+two-finger double-tap (Almost Maximize), and swipe-down (Maximize) now flash accent-tinted symbols at the cursor — `inset.filled.center.rectangle` for Reasonable, `inset.filled.rectangle` for Almost, and `rectangle.fill` for Maximize — all sharing the same accent colour and `.replace.downUp.byLayer` content transition.
- **Extensible Replace Transitions**: `CursorFeedbackOverlay.Mode` gained a second animation descriptor — `replaceTransition` — so a feedback type can choose a `setSymbolImage` content transition (symbol morphs from the previous symbol) instead of an in-place `addSymbolEffect`. New replacement styles are one `case` plus one line in `show()`.
- **Hide Feedback**: `Cmd+H` and Cmd+swipe-up (hide) now flash a distinct `smallcircle.filled.circle.fill` at the cursor, tinted with a Primary / Accent / None palette (black / system blue / clear) and a `.bounce` entry animation.
- **Extensible Feedback Modes**: `CursorFeedbackOverlay.Mode` is now data-driven — each mode declares its SF Symbol name, accessibility label, tint palette, and optional entry symbol effect. Adding a new feedback type is a single `case` plus four descriptor lines; the image factory, caching, and animation plumbing are shared.
- **Force-Quit Feedback**: `Cmd+Q` and Cmd+pinch-in (force quit) now flash a distinct `xmark.circle.fill` at the cursor, rendered with a Black → Purple gradient variable palette and a hover-style scale-up + fade-in (1.08×, 0.15 s ease-out) entry animation matching the close button's hover, so quit actions read differently from close (red X) and minimize (black/yellow minus) through their palette.

## 0.3.2 (17 Aug 2026)

- **Cursor-Anchored Action Feedback**: Reused the same `xmark.circle.fill` (Close) and `minus.circle.fill` (Minimize) symbols from the Mission Control hover overlay as a transient, non-interactive visual feedback flash anchored at the mouse cursor whenever a close or minimize action executes:
  - `Cmd+W` (close) → red X flash at the cursor.
  - `Cmd+M` (minimize) → yellow minus flash at the cursor.
  - Pinch-in (close) and swipe-up (minimize) gestures → matching feedback at the cursor.
  - Auto-fades after ~0.6 s; repeated triggers reset the timer. Click-through (`ignoresMouseEvents`), lazily allocated, and cleaned up on `stop()`.
  - Close and force-quit feedback share a hover-style scale-up + fade-in (1.08×, 0.15 s ease-out) entry animation matching `CloseButtonView.setHovered`.
- **Feedback Timing Fix**: Feedback now emits *before* the (blocking, synchronous) Accessibility action instead of after it, so the symbol and haptic land at the same moment the close/minimize shortcut or gesture fires — rather than once the window has already closed or minimized (which read as janky, out-of-sync feedback).
  - The overlay sets its opacity synchronously (plus a `CATransaction.flush()`) and actions are deferred one run-loop turn, ensuring the symbol is composited on screen *before* the blocking AX action starves the main run loop — otherwise it would only render as the action completes and immediately fade (a flicker).
- **Animated Retract**: the symbol exits with a `.disappear.byLayer` symbol effect (each symbol layer vanishes sequentially) and a concurrent panel fade instead of a plain fade. Available on macOS 14+. The retract leads the display window by ~0.12 s so the exit overlaps, rather than waiting for, the end of the flash.

## 0.3.1 (17 Aug 2026)

- **Mission Control Hover Buttons**: Added preview close (`xmark.circle.fill`) and minimize (`minus.circle.fill`) action overlay button anchored directly to the top-left vertex of window thumbnails in Mission Control.
  - Supports Cmd-hold toggle to switch between Close and Minimize modes with smooth symbol content replacement animations.
  - Integrated an `.appear.byLayer` entry symbol animation.
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
