# Changelog

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
