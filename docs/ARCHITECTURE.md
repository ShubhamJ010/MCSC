# MCSC Architecture & Engineering Deep Dive

This document serves as an educational resource and architectural blueprint for **MCSC (Mac Shortcut Control)**. It explains the design decisions, structural patterns, and performance optimizations behind the codebase.

---

## 🏛 The Core Dilemma: AppKit vs. SwiftUI

One of the most foundational architectural choices in MCSC was committing to a pure AppKit / Core Foundation foundation rather than SwiftUI.

| Feature | SwiftUI | AppKit (Current) |
| :--- | :--- | :--- |
| **Baseline Memory** | ~16-25 MB | **~12.4 MB** |
| **Framework Overhead** | High (SwiftUI Runtime, Combine) | Minimal |
| **Control** | Declarative (Abstracted) | Imperative (Granular) |
| **Lifecycle** | Managed by `@main` | Managed via `main.swift` & `AppDelegate` |

**Memory Footprint:** For a background utility that lives in the menu bar and processes trackpad/keyboard events, SwiftUI's runtime introduces unnecessary allocations. By using `main.swift`, `NSApplication`, and lightweight Cocoa panels, MCSC maintains a baseline memory footprint under 13 MB.

---

## 🏗 Modular MVVM Architecture

MCSC strictly follows the **Model-View-ViewModel (MVVM)** pattern with protocol-driven dependency inversion and clear single-responsibility components:

```
[System Events: Quartz CGEventTap / Multitouch / AX Notifications]
                           │
                           ▼
                    [Services Layer]
  (AccessibilityService, EventTapService, MultitouchService, MissionControlService)
                           │
                           ▼
                   [ViewModel Layer]
  (ShortcutViewModel ──► ShortcutActionRouter & GestureActionRouter)
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
      [Actions (Models)]          [Views (Overlays)]
 (WindowActions, AppActions,     (CursorFeedbackOverlay,
  TabActions, TilingActions)      PreviewCloseButtonOverlay)
```

### 1. Models (`MCSC/Models`)
- **Single-Responsibility Structs:** `CloseWindowAction`, `MinimizeWindowAction`, `HideApplicationAction`, `ForceQuitAction`, `CloseAppAction`, `MinimizeAppAction`, `ForceQuitAppAction`, `CloseTabAction`, `ReopenTabAction`, `CloseAllTabsAction`, `NewWindowAction`, `FillScreenAction`, `MakeLargerAction`, `ReasonableSizeAction`, `AlmostMaximizeAction`.
- **Mission Control Window Actions:** `MissionControlWindowActions` encapsulates window button pressing (`kAXCloseButtonAttribute`, `kAXMinimizeButtonAttribute`) and fallback activation.
- **Pure Helpers:** `KeyboardEventPoster` (C-level Quartz event injection), `ScreenGeometry` (coordinate conversions between Quartz AX space and Cocoa screen space).
- **Recognizers:** Gesture engines (`PinchInRecognizer`, `SwipeRecognizer`, `TwoFingerSwipeLeftRecognizer`, `TwoFingerSwipeRightRecognizer`, `TwoFingerDoubleTapRecognizer`) evaluating multitouch frames against geometric thresholds.

### 2. ViewModels (`MCSC/ViewModels`)
- **`ShortcutViewModel`:** Lifecycle orchestrator that instantiates and connects services, manages user configuration, and coordinates overlay feedback before action execution.
- **`ShortcutActionRouter`:** Pure router mapping keyboard events (`Cmd+W`, `Cmd+Q`, `Cmd+M`, `Cmd+H`) to concrete actions.
- **`GestureActionRouter`:** Pure router mapping recognized multitouch gestures to actions based on target resolution (dock vs. window).
- **`ActionRegistry`:** Container holding shared instances of all actions to eliminate runtime heap allocations.
- **`ShortcutConfiguration`:** Pure data struct holding toggle states for all shortcuts and gestures.

### 3. Services (`MCSC/Services`)
- **`AccessibilityServiceProtocol` / `AccessibilityService`:** Low-level wrapper for `AXUIElement` APIs with cached system-wide elements and safe CoreFoundation type checking.
- **`EventTapServiceProtocol` / `EventTapService`:** C-level Quartz event tap (`CGEvent.tapCreate`) for intercepting keyboard shortcuts.
- **`MissionControlServiceProtocol` / `MissionControlService`:** Dual-mode detection (Dock notifications + cached window list scans) for Mission Control activation state.
- **`MultitouchService` & `MultitouchBridge`:** Private MultitouchSupport.framework dynamic loader and frame listener with wake/sleep lifecycle management.
- **`MissionControlHoverServiceProtocol` / `MissionControlHoverService`:** Tracks mouse movement in Mission Control and positions hover action buttons on active window previews.
- **`AppLogger`:** Zero-allocation logging using Apple's unified `os.Logger` framework.

### 4. Views (`MCSC/Views`)
- **`CursorFeedbackOverlay`:** Floating non-activating Cocoa panel that renders animated SF Symbols under the cursor.
- **`CursorFeedbackMode`:** Data-driven enumeration of visual feedback descriptors, accessibility labels, and tint palettes.
- **`PreviewCloseButtonOverlay`:** Floating close/action button rendered directly on hovered Mission Control previews.
- **`SymbolImageFactory`:** Cached SF Symbol generator configuring point sizes, variable color palettes, and weights.

---

## 🛠 System-Level Integration & Memory Best Practices

1. **Unmanaged Core Foundation Memory:** When dealing with C-level objects (`CGEvent`, `AXUIElement`, `CFMachPort`), we use `Unmanaged.passUnretained` unless explicit ownership transfer is required.
2. **Safe Core Foundation Downcasting:** All `CFTypeRef` downcasts verify `CFGetTypeID(ref) == AXUIElementGetTypeID()` (or corresponding type ID) before force-casting to eliminate runtime invalid pointer dereferences.
3. **No Retain Cycles:** All closures capture `[weak self]` or weak references to dependencies.
4. **Explicit Teardown:** Every service implements `start()` and `stop()` to invalidate run loop sources, remove notification observers, and tear down Mach ports.
5. **No Polling:** System event-driven architecture using event taps, observers, and multitouch frame callbacks without high-frequency polling timers.
