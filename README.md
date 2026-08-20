<div align="center">

# MCSC

### Mission Control Shortcuts — keyboard and trackpad window management for macOS

[![Platform](https://img.shields.io/badge/platform-macOS-000000)](https://www.apple.com/macos/)
[![Language](https://img.shields.io/badge/language-Swift-FA7343)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue)](https://opensource.org/licenses/MIT)

A lightweight, event-driven menu bar utility that adds window-management
shortcuts and gestures to Mission Control.

[Features](#features) · [Installation](#installation) · [Usage](#usage) · [Documentation](#documentation)

</div>

---

MCSC is a small background app that brings fast window management to Mission
Control. It is built as a learning project to explore low-level macOS APIs,
event systems, and accessibility automation while staying tiny — near-zero idle
CPU and a memory footprint under 13 MB.

It is heavily inspired by the original [Mission Control Plus](https://www.folivora.ai/missionscontrol)
and by [Swish](https://highlyopinionated.co/swish/), whose trackpad gestures MCSC
tries to replicate.

> [!NOTE]
> Every shortcut and gesture is **scoped to Mission Control only**. It fires
> while Mission Control is open and stays silent on the desktop, in Launchpad,
> and in expanded Finder folder stacks.

## Features

- **Global keyboard shortcuts** — `Cmd + W`, `Cmd + Q`, `Cmd + M`, `Cmd + H`,
  a `Cmd + Space` recovery sequence, and a clickable hover button on each window
  preview. `Cmd+W`/`Cmd+Q` (and pinch-in / swipe-left) on an ejectable Finder volume window auto-close and eject the volume. See [SHORTCUTS.md](./docs/SHORTCUTS.md).
- **Trackpad gestures** — pinch, directional swipes, and a two-finger double
  tap, each with a `Command` variant (pinch-in / swipe-left on ejectable Finder volumes auto-eject). See [GESTURES.md](./docs/GESTURES.md).
- **Mission Control scoping** — window-layer detection that activates the app
  only inside Mission Control, with a recovery sequence for stuck states.
  See [MISSION_CONTROL.md](./docs/MISSION_CONTROL.md).
- **Accessibility API integration** — drives `AXUIElement` directly to inspect
  and manipulate windows in other apps.
- **Launch at login** — registers MCSC through `SMAppService`.
- **Performance focused** — a near-zero-footprint, event-driven background
  agent. See [PERFORMANCE.md](./docs/PERFORMANCE.md) and
  [ARCHITECTURE.md](./docs/ARCHITECTURE.md).

## Requirements

MCSC needs the **Accessibility** permission to inspect windows and intercept
global input. Grant it from:

```text
System Settings → Privacy & Security → Accessibility
```

Without it, the app runs but cannot act on windows. The first launch prompts
for the permission, and MCSC boots the moment it is granted.

## Installation

Clone the repository and build with Xcode:

```bash
git clone https://github.com/yourusername/MCSC.git
cd MCSC
open MCSC.xcodeproj
```

Build using the `MCSC` scheme, then run. To sign a distributed build, for
example with Sentinel:

```bash
sentinel sign --app MCSC.app --identity "Developer ID Application: Your Name (TeamID)"
codesign -dv --verbose=4 MCSC.app
```

## Usage

MCSC runs as a menu bar icon (no Dock presence). Use the menu to toggle
individual shortcuts and gestures on or off, enable launch at login, and quit.

Once Mission Control is open, point at a window preview and use any of the
actions below.

**Keyboard shortcuts**

| Shortcut | Action |
| --- | --- |
| `Cmd + W` | Close window / active tab (ejectable Finder volume → close + eject) |
| `Cmd + Q` | Force quit app (ejectable Finder volume window → close + eject) |
| `Cmd + M` | Minimize window |
| `Cmd + H` | Hide app |
| `Cmd + Space` | Recover a stuck Mission Control / Spotlight state |

**Trackpad gestures**

| Gesture | Action | `Cmd` + gesture |
| --- | --- | --- |
| Pinch in | Close window / quit app (ejectable Finder volume → eject) | Force quit app (ejectable Finder volume → eject) |
| Swipe left | Close active tab (ejectable Finder volume → eject) | Close all tabs |
| Swipe right | Reopen closed tab | New window |
| Swipe up | Minimize window | Hide app |
| Swipe down | Fill screen | Make larger (+33%) |
| Two-finger double tap | Reasonable size (60%) | Almost maximize (90%) |

Each gesture fires **once per finger lift**, so holding your fingers down and
repeating the motion will not re-trigger it. For the full mapping, hover
buttons, and how recognition works, see [SHORTCUTS.md](./docs/SHORTCUTS.md) and
[GESTURES.md](./docs/GESTURES.md).

## Documentation

These guides go deeper than the summaries above:

- [SHORTCUTS.md](./docs/SHORTCUTS.md) — every keyboard shortcut and the hover button.
- [GESTURES.md](./docs/GESTURES.md) — every trackpad gesture and how recognition works.
- [MISSION_CONTROL.md](./docs/MISSION_CONTROL.md) — how MCSC detects and scopes to Mission Control.
- [SYMBOLS.md](./docs/SYMBOLS.md) — the SF Symbol map behind the feedback overlays.
- [PERFORMANCE.md](./docs/PERFORMANCE.md) — memory and CPU budget and how it stays light.
- [ARCHITECTURE.md](./docs/ARCHITECTURE.md) — the MVVM design and low-level choices.

## Credits

MCSC is inspired by [Mission Control Plus](https://www.folivora.ai/missionscontrol) and
by [Swish](https://highlyopinionated.co/swish/). Its trackpad gestures are an attempt to
replicate the interaction model that Swish popularized, so MCSC can serve as a partial,
open alternative to Swish.

> [!NOTE]
> MCSC approximates Swish's gestures but is not a full replacement. Reaching parity with
> Swish's feature set according to my needs only works in mission control right now.

> [!NOTE]
> This is an educational project. It was built with the help of AI coding
> tools, and is not presented as fully handcrafted from scratch. If you want a
> polished, production-grade experience, support the original developers.

Licensed under the MIT License.
