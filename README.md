# MCSC — Mission Control Shortcuts

A lightweight, high-performance macOS utility focused on fast window management and keyboard-driven workflows.

MCSC is a small background app built as a learning project to explore low-level macOS APIs, event systems, accessibility automation, and performance-focused desktop tooling.

It is heavily inspired by the original Mission Control Plus app.

> “Wouldn’t be possible without the original Mission Control Plus.”

---

## Why This Exists

Most macOS utilities in this category are either:
- Electron-heavy
- Resource intensive
- Over-engineered
- Closed ecosystems

MCSC was built with a different goal:
- native macOS APIs
- minimal memory usage
- near-zero idle CPU usage
- instant keyboard response
- small and understandable codebase

This project intentionally avoids unnecessary abstraction layers where possible and uses direct AppKit/Core Foundation integration instead of large UI frameworks.

---

## Features

### Global Keyboard Shortcuts

System-wide shortcuts powered by low-level `CGEventTap`.

Supported actions:

| Shortcut | Action |
|---|---|
| `Cmd + W` | Close active window |
| `Cmd + Q` | Quit active application |
| `Cmd + M` | Minimize active window |
| `Cmd + H` | Hide active application |
| `Cmd + Space` | Trigger Mission Control UI fix |

---

### Trackpad Gestures

Two-finger and pinch gestures, also scoped to **Mission Control only**:

| Gesture | Action |
|---|---|
| Two-finger swipe up | Hide / minimize active window |
| Two-finger swipe down | Toggle fullscreen |
| Two-finger swipe left | Close tab |
| Two-finger swipe right | Reopen tab |
| Pinch in | Close window / quit app |
| Two-finger double tap | Reasonable size / almost maximize |

Holding `Cmd` while gesturing maps to the force-quit / app-level variant of the
same action. Each gesture fires **once per finger lift** — keeping fingers down
and repeating the motion will not re-trigger it until you lift and touch again.

### Accessibility API Integration

Uses `AXUIElement` directly to:
- inspect windows
- manipulate application state
- interact with windows from other apps
- manage focus and visibility

---

### Mission Control Monitoring

All gestures and `Cmd` shortcuts are scoped to **Mission Control only**. They
fire while Mission Control is open and are deliberately suppressed in:

- **Launchpad**
- expanded **Finder folder stacks** in the Dock
- the **normal desktop**

Detection is performed by inspecting the Dock's window layers via
`CGWindowListCopyWindowInfo` — Mission Control exposes a full-screen Dock overlay
at layer 20 together with the Dock bar at layer ≤ 18, whereas Launchpad
(layers 27–29) and Finder folder stacks (overlay only, no Dock bar) do not match
this signature. The result is cached for 200ms to avoid polling on every
trackpad frame.

MCSC can also automatically attempt recovery sequences (`Cmd + Space`) when
macOS gets stuck during Mission Control interactions.

---

### Launch at Login

Integrated using `SMAppService`.

The app can automatically start with macOS and remain quietly available in the background.

---

### Performance Focused

MCSC is designed to stay lightweight at all times.

Typical runtime characteristics:
- ~0% idle CPU usage
- ~14MB memory usage
- negligible battery impact
- event-driven architecture
- no unnecessary polling loops

---

## Technical Overview

MCSC uses a service-oriented architecture inspired by MVVM principles.

### Core Services

- `EventTapService`
  - global keyboard interception
  - low-level event processing

- `AccessibilityService`
  - window inspection and manipulation
  - AX API communication

- `MissionControlService`
  - Mission Control detection via Dock window-layer analysis (`CGWindowList`)
  - scopes gestures & shortcuts to Mission Control only
  - recovery handling (`Cmd + Space` fix sequence)

- `LaunchAtLoginService`
  - startup integration using `SMAppService`

---

## Technologies Used

- Swift
- AppKit
- Core Foundation
- Accessibility APIs
- CGEventTap
- SMAppService

The project also experiments with:
- explicit Core Foundation memory management
- `Unmanaged<T>`
- manual teardown strategies
- low-level macOS event handling

---

## Installation

### Clone the Repository

```bash
git clone https://github.com/yourusername/MCSC.git
cd MCSC
```

### Open in Xcode

```bash
open MCSC.xcodeproj
```

### Build

Build using the `MCSC` scheme inside Xcode.

---

## First Launch

When launching for the first time, macOS will ask for:

### Accessibility Permissions

Required for:
- controlling windows
- listening to global shortcuts
- interacting with other applications

Grant access from:

```text
System Settings
→ Privacy & Security
→ Accessibility
```

---

## Code Signing

If you use Sentinel for signing:

```bash
sentinel sign --app MCSC.app --identity "Developer ID Application: Your Name (TeamID)"
```

Verify signature:

```bash
codesign -dv --verbose=4 MCSC.app
```

---

## Performance Notes

Observed during runtime testing on macOS:

| Metric | Typical Usage |
|---|---|
| CPU | ~0% idle |
| Memory | ~14MB RSS |
| Battery Impact | Negligible |

The app is intentionally event-driven to avoid unnecessary background activity.

---

## Learning Project Disclosure

This project exists primarily as an educational exercise.

It was built to better understand:
- macOS internals
- accessibility APIs
- event taps
- Mission Control behavior
- low-level Swift patterns
- background utilities

### AI Usage Disclosure

Codex / AI agentic coding tools were used during development.

This project is not presented as fully handcrafted from scratch.

---

## Important Note

> “It is an educational project for me.  
> Except bugs — if you want something better, pay for the original app.”

Support the original developers if you want a polished production-grade experience.

---

## Credits

Inspired by:
- Mission Control Plus

Massive respect to the original creators whose work inspired this project.

---

## License

MIT License
