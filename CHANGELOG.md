# Changelog

## 25 May 2026

- **AppDelegate.swift**: Refined status bar menu labels by removing "Toggle" prefix for cleaner UI. Added `setupStatusBar()` call during initialization to ensure accurate UI state.
- **ShortcutViewModel.swift**:
  - Disabled `Cmd + F` shortcut by default.
  - Refined `Cmd` detection logic to ensure only the `Command` modifier is active (ignoring Shift, Control, and Option) to prevent interference with other system shortcuts.
  - Removed logic related to `Cmd + F` / `maximizeAction`.
