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

- **🔍 Type-to-Select Fuzzy Finder** — just start typing any app name in Mission Control (`code`, `ghostty`, `finder`) to instantly rank and highlight matching windows with macOS's native blue outline. A Dock-styled uppercase search pill floats above the Dock; `Tab`/`Arrow` cycles matches, `Enter` activates with a dwell-click. See [SHORTCUTS.md](./docs/SHORTCUTS.md).
- **🖱️ Hover Action Buttons** — a floating, clickable button anchored to the top-left of every window preview. No modifier → Close (`xmark.circle.fill`), `Option` → Minimize (`minus.circle.fill`), `Command` → Force Quit (purple `xmark.circle.fill`). Smooth symbol morph + 1.08× hover scale. See [SHORTCUTS.md](./docs/SHORTCUTS.md).
- **✋ 7 Trackpad Gestures × 2 Variants (14 actions)** — pinch-in/out, 4-direction swipes, and two-finger double-tap. Each has a `Command` variant. Replicates [Swish](https://highlyopinionated.co/swish/) inside Mission Control. Includes one-per-lift guard, 3-finger poison rejection, and 0.5 s cooldown. See [GESTURES.md](./docs/GESTURES.md).
- **⌨️ Global Keyboard Shortcuts** — `Cmd + W` (close/tab), `Cmd + Q` (force quit), `Cmd + M` (minimize), `Cmd + H` (hide), plus `Cmd + Space` to recover stuck Mission Control/Spotlight states. Scoped strictly to Mission Control via `CGWindowListCopyWindowInfo` layer detection. See [SHORTCUTS.md](./docs/SHORTCUTS.md).
- **💿 Auto-Eject Mounted Volumes** — `Cmd+W`/`Cmd+Q` or pinch-in/swipe-left on an ejectable Finder volume window (e.g. DMG installers in `/Volumes`) auto-closes the window and ejects the volume (`NSWorkspace.unmountAndEjectDevice`) with a red `eject.circle.fill` flash. Toggle: *Auto-Eject Mounted Volumes*. See [SHORTCUTS.md](./docs/SHORTCUTS.md).
- **🪟 Window Tiling & Tab Control** — Fill Screen, Make Larger (+33%), Reasonable Size (60%), Almost Maximize (90%), and Toggle Fullscreen via swipe/double-tap; plus Close Tab, Reopen Tab, Close All Tabs (`Cmd+Shift+W`), New Tab (`Cmd+T`) / New Window (`Cmd+N`) via swipe-left/right. See [GESTURES.md](./docs/GESTURES.md).
- **🎯 Cursor Feedback + Haptics** — every action flashes a distinct SF Symbol at the cursor (14 modes: close/minimize/quit/hide/eject/resize/tab) with tinted palettes, `.bounce`/`.wiggle`/`.replace` animations, and a paired `NSHapticFeedbackManager` choreography. Swallow → 0.6 s fade. See [SYMBOLS.md](./docs/SYMBOLS.md).
- **🎯 Dock-Aware Targeting** — point at a window preview → window action; point at a Dock icon → app-level action. Resolves Dock items by `AXURL` bundle-ID first (fixes Catalyst/Electron apps like WhatsApp/Beeper where `AXTitle ≠ localizedName`), with tolerant title fallback. Skips empty wallpaper.
- **🐳 Dock Gestures & Shortcuts Outside Mission Control** — all dock-target shortcuts (`Cmd+W/Q/M/H`) and gestures (pinch, swipe, double-tap) also work hovering Dock icons in normal desktop mode; App Exposé and context menus are suppressed mid-gesture via a dedicated HID event tap. Toggle: *Dock Gestures & Shortcuts (outside MC)*. See [SHORTCUTS.md](./docs/SHORTCUTS.md) and [GESTURES.md](./docs/GESTURES.md).
- **🛡️ Mission Control Scoping** — activates only inside Mission Control using Dock layer analysis (fullscreen overlay at layer 20 + Dock bar ≤ 18). Correctly ignores desktop, Launchpad (layers 27–29), and expanded Finder stacks. 200 ms cache. See [MISSION_CONTROL.md](./docs/MISSION_CONTROL.md).
- **⚡ Zero-Footprint, Event-Driven** — AppKit (not SwiftUI) saves 4–6 MB; baseline **~12.4 MB / <13 MB ceiling**, ~0% idle CPU. No polling — pure `CGEventTap` + Multitouch + Accessibility events. Cached `AXUIElementCreateSystemWide`, `Unmanaged.passUnretained`, `[weak self]` everywhere. See [PERFORMANCE.md](./docs/PERFORMANCE.md) and [ARCHITECTURE.md](./docs/ARCHITECTURE.md).
- **⚙️ Fully Configurable** — per-shortcut and per-gesture toggles in the menu bar (and **Settings…** window), plus Launch at Login via `SMAppService`. All preferences live in `ShortcutConfiguration`.

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

Once Mission Control is open, point at a window preview or start typing to use any of the
actions below.

**Type-to-Select (Fuzzy Finder)**

| Input | Action |
| --- | --- |
| Type letters / numbers (`e.g. ghostty, code`) | Fuzzy-matches window owner names, draws native highlight on best match, displays Dock-style query pill |
| `Enter` / `Return` | Activates and raises the selected window, dismissing Mission Control |
| `Tab` / `Down Arrow` | Cycles forward through matching windows |
| `Up Arrow` | Cycles backward through matching windows |
| `Escape` / `Backspace` | Clears query / deletes last character |

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

- [SHORTCUTS.md](./docs/SHORTCUTS.md) — every keyboard shortcut, type-to-select fuzzy finding, and hover buttons.
- [GESTURES.md](./docs/GESTURES.md) — every trackpad gesture and how recognition works.
- [MISSION_CONTROL.md](./docs/MISSION_CONTROL.md) — how MCSC detects and scopes to Mission Control.
- [SYMBOLS.md](./docs/SYMBOLS.md) — the SF Symbol map behind the feedback overlays.
- [PERFORMANCE.md](./docs/PERFORMANCE.md) — memory and CPU budget and how it stays light.
- [ARCHITECTURE.md](./docs/ARCHITECTURE.md) — the MVVM design, event tap pipelines, and low-level choices.

## Credits & Acknowledgements

- **Inspirations:** MCSC is inspired by [Mission Control Plus](https://www.folivora.ai/missionscontrol) and by [Swish](https://highlyopinionated.co/swish/). Its trackpad gestures replicate the interaction model that Swish popularized.
- **OpenMissionControl:** Special thanks to the [OpenMissionControl](https://github.com/nohackjustnoobb/OpenMissionControl) repository and specifically [PR #3 (changes)](https://github.com/nohackjustnoobb/OpenMissionControl/pull/3/changes) by `nohackjustnoobb` and contributors. Studying their implementation and PR changes unlocked low-level Mission Control window management and keyboard interaction capabilities after being stuck on them for a long time, greatly aiding my learning of private Exposé SPIs (`CoreDockSendNotification`) and Quartz event routing in Mission Control.

> [!NOTE]
> MCSC approximates Swish's gestures but is not a full replacement. Reaching parity with
> Swish's feature set according to my needs only works in mission control right now.

> [!NOTE]
> This is an educational project. It was built with the help of AI coding
> tools, and is not presented as fully handcrafted from scratch. If you want a
> polished, production-grade experience, support the original developers.

Licensed under the MIT License.
