# MCSC Architecture & Engineering Deep Dive

This document serves as an educational resource and architectural blueprint for **MCSC (Mission Control Shortcuts)**. It explains the "why" behind our technical decisions, specifically focusing on performance optimization and system-level integration.

## 🏛 The Core Dilemma: AppKit vs. SwiftUI

One of the most significant architectural choices in MCSC was the transition from SwiftUI to a pure AppKit/Core Foundation foundation.

### Why AppKit?
For a background utility like MCSC, memory efficiency and low-level control are paramount.

| Feature | SwiftUI | AppKit (Current) |
| :--- | :--- | :--- |
| **Baseline Memory** | ~16-25 MB | **~12.4 MB** |
| **Framework Overhead** | High (SwiftUI Runtime, Combine) | Minimal |
| **Control** | Declarative (Abstracted) | Imperative (Granular) |
| **Lifecycle** | Managed by `@main` | Managed via `main.swift` & `AppDelegate` |

**Enlightenment:** SwiftUI is excellent for data-driven, UI-heavy applications. However, it brings a large runtime overhead. For a "headless" agent that lives in the background, the SwiftUI framework is a heavy guest. By using `main.swift` and `NSApplication`, we bypass the SwiftUI initialization sequence entirely, saving ~4-6 MB of RAM.

## 🏗 MVVM Architecture

We strictly adhere to the **Model-View-ViewModel** pattern, even without a traditional "View." In MCSC, the "View" is the system's event stream.

-   **Models (`MCSC/Models`):** Encapsulate the *actions*. They don't know about shortcuts; they only know how to talk to the Accessibility API to close a window or kill a process.
-   **Services (`MCSC/Services`):** The "Workhorses." These are low-level wrappers.
    -   `EventTapService`: Uses C-level APIs (`CGEvent.tapCreate`) to listen for system-wide key presses.
    -   `AccessibilityService`: Communicates with `AXUIElement` to query and manipulate windows.
-   **ViewModels (`MCSC/ViewModels`):** The "Brain." It receives raw key codes from the `EventTapService`, determines if they match our target shortcuts (Cmd+W/Cmd+Q), and triggers the corresponding `Model` action.

## 🛠 System-Level Integration

### Global Event Taps
MCSC uses a `CGEventTap`. This is a low-level hook into the macOS windowing system (Quartz).
- **Placement:** We place the tap at `.headInsertEventTap` to ensure we see the event before the target application does.
- **Efficiency:** The callback is written to be extremely fast. If we don't handle the shortcut, we pass the event through immediately to avoid lag.

### Accessibility API (AXUIElement)
To interact with windows we don't own, we use the `Accessibility API`. 
- **The Concept:** Every UI element on macOS is an `AXUIElement`. By using `AXUIElementCopyElementAtPosition`, we can find exactly what the user is pointing at.
- **Optimization:** We cache the `SystemWide` element. Re-creating it on every event is a common performance pitfall in macOS tools.

## 🧠 Memory Management Best Practices

To achieve our **< 13MB goal**, we employ several advanced Swift techniques:

1.  **Unmanaged Memory:** When working with Core Foundation (C-based) objects like `CGEvent`, we use `Unmanaged`. We prefer `passUnretained` when we don't need to take ownership, preventing the overhead of extra ARC (Automatic Reference Counting) increments.
2.  **Weak Reference Cycles:** All closures in our ViewModels use `[weak self]` to ensure that stopping the service actually releases the memory.
3.  **Manual Resource Teardown:** Our services have explicit `stop()` methods that invalidate run loops and ports. We don't rely solely on `deinit`.

## 🎓 Educational Takeaway
High-performance macOS development often requires stepping away from modern, high-level abstractions (SwiftUI) and returning to the robust, low-level primitives (AppKit, Core Foundation) that have powered the OS for decades. MCSC is a testament that "simple" tasks should have "simple" footprints.
