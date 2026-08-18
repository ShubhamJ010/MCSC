# Performance

MCSC is built to stay a near-zero-footprint background utility. This document
explains the memory and CPU budget, the techniques that keep it small, and how
to reason about regressions. For the architectural rationale behind these
choices, see [ARCHITECTURE.md](./ARCHITECTURE.md).

---

## The budget

The project treats memory as a hard ceiling, not a target. AGENTS.md sets the
operating limit at **13 MB** of baseline memory, and the app is designed to sit
just under it. Typical observed runtime characteristics are:

| Metric | Typical value |
| --- | --- |
| Idle CPU | ~0% |
| Baseline memory | ~12.4 MB |
| Peak memory under normal use | ~14 MB RSS |
| Battery impact | Negligible |

Any new feature must be evaluated for memory impact before implementation. If a
feature needs a heavy framework or large data structure, the team rejects or
redesigns it rather than crossing the ceiling.

---

## Why it stays light

MCSC avoids the usual sources of bloat in macOS utilities:

- **AppKit over SwiftUI.** The app launches through `main.swift` and
  `NSApplication` instead of the SwiftUI runtime, saving roughly 4 to 6 MB of
  baseline RAM. SwiftUI's runtime and Combine overhead are unnecessary for a
  headless event-driven agent.
- **Event-driven, not polling.** Shortcuts and gestures fire from system events
  (event taps, multitouch frames, Dock notifications). There are no continuous
  timers scanning the system. The only scheduled work is the hover service's
  window-list refresh, which runs at most every 0.5 seconds and only while
  Mission Control is open.
- **Cached detection.** Mission Control detection is cached for 200 ms, so a
  trackpad frame never pays for a fresh `CGWindowListCopyWindowInfo` scan.
- **Lightweight action structs.** Window-management operations are `struct`s
  with no heap allocation and no long-lived state, so a single shared instance
  per action is reused for the app's lifetime.
- **Cached system-wide element.** The `AXUIElement` system-wide object is
  created once and reused, avoiding a common AX performance pitfall.
- **Explicit Core Foundation management.** `Unmanaged.passUnretained` is used
  unless ownership is required, and services expose `stop()` methods that
  invalidate run loops and ports instead of relying on `deinit`.
- **Weak closures.** Every service callback captures `self` weakly
  (`[weak self]`), so stopping a service actually releases its memory.

---

## Where the budget can break

Watch for these patterns when adding or reviewing code:

- Introducing SwiftUI views into the core path.
- Adding a high-frequency timer or a per-frame polling loop.
- Retaining a service or overlay strongly inside a closure (a retain cycle).
- Allocating large in-memory caches or decoded assets at launch.
- Re-creating the system-wide `AXUIElement` on every event.

---

## Measuring

To check the current footprint, launch the app, let it idle on the desktop, then
read its memory and CPU from Activity Monitor or `top -l 1 -pid <pid>`. Measure
while Mission Control is closed (the quiet baseline) and again during active use
(gestures over previews) to capture both extremes. A regression past the 13 MB
ceiling means the change needs redesign before merge.

---

## Source references

- Memory and framework choices: [ARCHITECTURE.md](./ARCHITECTURE.md)
- Project memory rules: `AGENTS.md`
- Lazy, cached, and event-driven wiring: `MCSC/ViewModels/ShortcutViewModel.swift`
- Cached Mission Control detection: `MCSC/Services/MissionControlService.swift`
- Minimal hover polling: `MCSC/Services/MissionControlHoverService.swift`
- Lightweight action structs: `MCSC/Models/ShortcutActions.swift`
