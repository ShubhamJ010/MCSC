# MCSC Folder Structure Reorganization Plan

> Goal: reorganize the existing files into a best-practice MVVM folder
> structure by **moving only** — no new files, no deleted files, no code
> changes. Just moving `.swift` files into subdirectories so the physical
> layout matches the MVVM layering and groups files by responsibility.
>
> The Xcode project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+),
> so disk moves are auto-synced into the project navigator — **no `.pbxproj`
> edits needed**. Swift imports are module-based, not path-based, so **no
> import statements break**. The only file that needs a content update is
> `Tests/run_tests.sh` (its explicit source-file list must match new paths).

---

## Current State

```
MCSC/
├── AppDelegate.swift
├── main.swift
├── Models/                          ← 14 files, mixed concerns
│   ├── ShortcutAction.swift         (protocol)
│   ├── WindowActions.swift          (window-level AX actions)
│   ├── AppActions.swift             (app-level AX actions)
│   ├── TabActions.swift             (tab keyboard-post actions)
│   ├── TilingActions.swift          (resize/tilt actions)
│   ├── MissionControlWindowActions.swift  (MC window actions)
│   ├── KeyboardEventPoster.swift    (helper utility)
│   ├── ScreenGeometry.swift         (helper utility)
│   ├── GestureRecognizer.swift      (engine + protocol)
│   ├── PinchInRecognizer.swift
│   ├── SwipeRecognizer.swift
│   ├── TwoFingerSwipeLeftRecognizer.swift
│   ├── TwoFingerSwipeRightRecognizer.swift
│   └── TwoFingerDoubleTapRecognizer.swift
├── ViewModels/                      ← 5 files, mixed concerns
│   ├── ShortcutViewModel.swift
│   ├── ShortcutConfiguration.swift
│   ├── ShortcutActionRouter.swift
│   ├── GestureActionRouter.swift
│   └── ActionRegistry.swift
├── Services/                        ← 9 files, mixed concerns
│   ├── Logger.swift                 (utility)
│   ├── EventTapService.swift
│   ├── AccessibilityService.swift
│   ├── MissionControlService.swift
│   ├── MissionControlHoverService.swift
│   ├── MultitouchService.swift
│   ├── MultitouchBridge.swift
│   ├── HapticService.swift
│   └── LaunchAtLoginService.swift
└── Views/
    ├── CursorFeedbackOverlay.swift
    ├── CursorFeedbackMode.swift
    ├── PreviewCloseButtonOverlay.swift
    └── SymbolImageFactory.swift     (utility, not a view)
```

### Problems with the current layout

1. **`Models/` is a dumping ground.** It mixes the gesture-recognition
   subsystem (5 recognizers + engine), action implementations (5 action
   files), and helper utilities (KeyboardEventPoster, ScreenGeometry) that
   aren't "models" in any sense.
2. **`ViewModels/` mixes routing with configuration.** The two routers
   and the ActionRegistry are a distinct concern from the ViewModel itself.
3. **`Services/` mixes system wrappers with utilities.** Logger.swift is a
   logging utility, not a service wrapping a macOS API.
4. **`Views/` contains a utility.** `SymbolImageFactory.swift` is a shared
   rendering helper, not a view.
5. **App entry points** (`AppDelegate.swift`, `main.swift`) sit at the root
   with no grouping.

---

## Target Structure (move-only)

```
MCSC/
├── App/
│   ├── AppDelegate.swift
│   └── main.swift
├── Models/
│   ├── Actions/
│   │   ├── ShortcutAction.swift           (protocol)
│   │   ├── WindowActions.swift
│   │   ├── AppActions.swift
│   │   ├── TabActions.swift
│   │   ├── TilingActions.swift
│   │   └── MissionControlWindowActions.swift
│   └── Gestures/
│       ├── GestureRecognizer.swift        (engine + protocol)
│       ├── PinchInRecognizer.swift
│       ├── SwipeRecognizer.swift
│       ├── TwoFingerSwipeLeftRecognizer.swift
│       ├── TwoFingerSwipeRightRecognizer.swift
│       └── TwoFingerDoubleTapRecognizer.swift
├── ViewModels/
│   ├── ShortcutViewModel.swift
│   ├── ShortcutConfiguration.swift
│   └── Routing/
│       ├── ShortcutActionRouter.swift
│       ├── GestureActionRouter.swift
│       └── ActionRegistry.swift
├── Services/
│   ├── Accessibility/
│   │   └── AccessibilityService.swift
│   ├── EventTap/
│   │   └── EventTapService.swift
│   ├── MissionControl/
│   │   ├── MissionControlService.swift
│   │   └── MissionControlHoverService.swift
│   ├── Multitouch/
│   │   ├── MultitouchService.swift
│   │   └── MultitouchBridge.swift
│   ├── Haptics/
│   │   └── HapticService.swift
│   └── LaunchAtLogin/
│       └── LaunchAtLoginService.swift
├── Views/
│   ├── CursorFeedbackOverlay.swift
│   ├── CursorFeedbackMode.swift
│   └── PreviewCloseButtonOverlay.swift
└── Utilities/
    ├── Logger.swift
    ├── ScreenGeometry.swift
    ├── KeyboardEventPoster.swift
    └── SymbolImageFactory.swift
```

### Why this layout

- **`App/`** — the two entry points grouped together, clearly separated from
  the rest of the app. Standard convention for the composition root.
- **`Models/Actions/`** — all `ShortcutAction` implementations and the
  protocol. This is the "what the app can do" layer. Subgrouping by action
  domain keeps 6 files scannable.
- **`Models/Gestures/`** — the entire gesture-recognition subsystem
  (engine + 5 recognizers). This is a self-contained concern: frames in,
  `GestureResult` out. Keeping it separate from actions makes the boundary
  between "what the user did" and "what the app does" explicit.
- **`ViewModels/Routing/`** — the two routers + ActionRegistry. These are
  decision-making modules that translate input → action, distinct from the
  ViewModel that wires services. Grouping them signals "this is the routing
  sublayer of the VM tier."
- **`Services/` subgrouped by domain** — each macOS API wrapper gets its own
  folder. This scales (a 6th service doesn't get lost in a flat list) and
  mirrors how the services are actually independent: each wraps a different
  system framework (Accessibility, CGEvent, MultitouchSupport, etc.).
- **`Utilities/`** — the 4 helpers that don't belong to any MVVM layer.
  Logger, ScreenGeometry, KeyboardEventPoster, and SymbolImageFactory are
  pure functions/enums with no domain ownership. Grouping them stops them
  from polluting the layer they happened to be sitting in.

---

## Move List

No file is created or deleted. Every move is a `git mv`.

### 1. Create new directories (empty placeholders, no files yet)

These directories are created by moving a file into them — Swift packages
don't track empty dirs, but the Xcode synchronized group will create the
folder reference on first move.

### 2. Move app entry points → `App/`

| From | To |
|---|---|
| `MCSC/AppDelegate.swift` | `MCSC/App/AppDelegate.swift` |
| `MCSC/main.swift` | `MCSC/App/main.swift` |

### 3. Split `Models/` into `Models/Actions/` and `Models/Gestures/`

| From | To |
|---|---|
| `MCSC/Models/ShortcutAction.swift` | `MCSC/Models/Actions/ShortcutAction.swift` |
| `MCSC/Models/WindowActions.swift` | `MCSC/Models/Actions/WindowActions.swift` |
| `MCSC/Models/AppActions.swift` | `MCSC/Models/Actions/AppActions.swift` |
| `MCSC/Models/TabActions.swift` | `MCSC/Models/Actions/TabActions.swift` |
| `MCSC/Models/TilingActions.swift` | `MCSC/Models/Actions/TilingActions.swift` |
| `MCSC/Models/MissionControlWindowActions.swift` | `MCSC/Models/Actions/MissionControlWindowActions.swift` |
| `MCSC/Models/GestureRecognizer.swift` | `MCSC/Models/Gestures/GestureRecognizer.swift` |
| `MCSC/Models/PinchInRecognizer.swift` | `MCSC/Models/Gestures/PinchInRecognizer.swift` |
| `MCSC/Models/SwipeRecognizer.swift` | `MCSC/Models/Gestures/SwipeRecognizer.swift` |
| `MCSC/Models/TwoFingerSwipeLeftRecognizer.swift` | `MCSC/Models/Gestures/TwoFingerSwipeLeftRecognizer.swift` |
| `MCSC/Models/TwoFingerSwipeRightRecognizer.swift` | `MCSC/Models/Gestures/TwoFingerSwipeRightRecognizer.swift` |
| `MCSC/Models/TwoFingerDoubleTapRecognizer.swift` | `MCSC/Models/Gestures/TwoFingerDoubleTapRecognizer.swift` |

### 4. Split `ViewModels/` — keep root, add `Routing/`

| From | To |
|---|---|
| `MCSC/ViewModels/ShortcutActionRouter.swift` | `MCSC/ViewModels/Routing/ShortcutActionRouter.swift` |
| `MCSC/ViewModels/GestureActionRouter.swift` | `MCSC/ViewModels/Routing/GestureActionRouter.swift` |
| `MCSC/ViewModels/ActionRegistry.swift` | `MCSC/ViewModels/Routing/ActionRegistry.swift` |

`ShortcutViewModel.swift` and `ShortcutConfiguration.swift` stay at
`ViewModels/` root.

### 5. Subgroup `Services/` by domain

| From | To |
|---|---|
| `MCSC/Services/AccessibilityService.swift` | `MCSC/Services/Accessibility/AccessibilityService.swift` |
| `MCSC/Services/EventTapService.swift` | `MCSC/Services/EventTap/EventTapService.swift` |
| `MCSC/Services/MissionControlService.swift` | `MCSC/Services/MissionControl/MissionControlService.swift` |
| `MCSC/Services/MissionControlHoverService.swift` | `MCSC/Services/MissionControl/MissionControlHoverService.swift` |
| `MCSC/Services/MultitouchService.swift` | `MCSC/Services/Multitouch/MultitouchService.swift` |
| `MCSC/Services/MultitouchBridge.swift` | `MCSC/Services/Multitouch/MultitouchBridge.swift` |
| `MCSC/Services/HapticService.swift` | `MCSC/Services/Haptics/HapticService.swift` |
| `MCSC/Services/LaunchAtLoginService.swift` | `MCSC/Services/LaunchAtLogin/LaunchAtLoginService.swift` |

### 6. Create `Utilities/` and move helpers out of their current layers

| From | To |
|---|---|
| `MCSC/Services/Logger.swift` | `MCSC/Utilities/Logger.swift` |
| `MCSC/Models/ScreenGeometry.swift` | `MCSC/Utilities/ScreenGeometry.swift` |
| `MCSC/Models/KeyboardEventPoster.swift` | `MCSC/Utilities/KeyboardEventPoster.swift` |
| `MCSC/Views/SymbolImageFactory.swift` | `MCSC/Utilities/SymbolImageFactory.swift` |

### 7. Update `Tests/run_tests.sh`

The test script lists every source file by explicit path. After the moves,
update the 28 path entries to match the new locations. The file list is
the only content that changes — no test logic, no new tests.

The updated `swiftc` invocation will reference:
- `${ROOT_DIR}/MCSC/App/main.swift` (if main.swift is compiled in tests — verify)
- `${ROOT_DIR}/MCSC/App/AppDelegate.swift` (verify — AppDelegate pulls in AppKit)
- `${ROOT_DIR}/MCSC/Models/Actions/*.swift` (6 files)
- `${ROOT_DIR}/MCSC/Models/Gestures/*.swift` (6 files)
- `${ROOT_DIR}/MCSC/Utilities/*.swift` (4 files)
- `${ROOT_DIR}/MCSC/Services/<Subgroup>/*.swift` (8 files)
- `${ROOT_DIR}/MCSC/ViewModels/*.swift` + `${ROOT_DIR}/MCSC/ViewModels/Routing/*.swift` (5 files)
- `${ROOT_DIR}/MCSC/Views/*.swift` (3 files)

### 8. Verify build

```bash
# Xcode synchronized groups auto-sync on open, but verify compilation:
xcodebuild -project MCSC.xcodeproj -scheme MCSC build 2>&1 | tail -20

# Then run the test suite with the updated paths:
bash Tests/run_tests.sh
```

---

## What does NOT change

- **No file contents are edited** (except `Tests/run_tests.sh` path strings).
- **No files created or deleted.**
- **No `.pbxproj` edits** — `PBXFileSystemSynchronizedRootGroup` auto-syncs.
- **No import statements change** — Swift resolves by module, not path.
- **No code logic changes** — this is purely a physical reorganization.
- **`Assets.xcassets/` and `AppIcon.icns`** stay at `MCSC/` root (resource
  bundles, not source files).
- **`Info.plist`, `MCSC.entitlements`** stay at repo root (not in `MCSC/`).

---

## Execution Order

Run in this order so each step is independently verifiable:

1. **Create the target directories** by moving one file into each:
   `App/`, `Models/Actions/`, `Models/Gestures/`, `ViewModels/Routing/`,
   `Utilities/`, and each `Services/` subgroup.

2. **`git mv` all files** per the tables above (28 moves total).

3. **Update `Tests/run_tests.sh`** — fix all 28 source paths in the `swiftc`
   invocation.

4. **Build verify** — `xcodebuild` should succeed with zero changes beyond
   the moves, because the Xcode project syncs the folder structure.

5. **Test verify** — `bash Tests/run_tests.sh` should pass with the updated
   paths.

6. **Commit** — single commit, message:
   `refactor: reorganize folder structure to MVVM best-practice grouping`

---

## Verification Checklist

- [ ] `git status` shows only renames (R), no additions (A) or deletions (D)
- [ ] `xcodebuild` succeeds
- [ ] `Tests/run_tests.sh` passes
- [ ] No `.swift` file has its contents changed (diff should show 0 line
      changes inside files, only path moves)
- [ ] `Tests/run_tests.sh` is the only file with content changes
- [ ] Xcode project navigator shows the new folder structure after open
