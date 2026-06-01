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

### Accessibility API Integration

Uses `AXUIElement` directly to:
- inspect windows
- manipulate application state
- interact with windows from other apps
- manage focus and visibility

---

### Mission Control Monitoring

Includes dedicated handling for:
- Mission Control
- Exposé
- stuck UI states
- failed transitions

MCSC can automatically attempt recovery sequences when macOS gets stuck during Mission Control interactions.

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
  - Mission Control state monitoring
  - recovery handling

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
