import Cocoa

extension CursorFeedbackOverlay {
    /// The set of actions the overlay can flash, plus their visual treatment.
    ///
    /// Adding a new feedback type is *data-only*: add a `case` and fill in the
    /// descriptors below (symbol name, accessibility label, tint palette, and
    /// optional entry animation). The overlay derives the rendered image and
    /// behaviour from these and needs no further changes.
    /// `CaseIterable` lets tests walk the full descriptor set to prove every
    /// mode renders a real SF Symbol and carries a non-empty a11y label.
    enum Mode: CaseIterable, Equatable {
        case close
        case minimize
        case quit
        case hide
        case eject
        case almost
        case reasonable
        case makeSmaller
        case maximize
        case closeTab
        case reopenTab
        case closeAllTabs
        case newWindow
        case newTab
        case fullscreen
        case spaceRight
        case spaceLeft

        /// SF Symbol name rendered by `NSImage(systemSymbolName:)`.
        var symbolName: String {
            switch self {
            case .close: "xmark.circle.fill"
            case .minimize: "minus.circle.fill"
            case .quit: "xmark.circle.fill"
            case .hide: "eye.slash.circle.fill"
            case .eject: "eject.circle.fill"
            case .almost: "inset.filled.rectangle"
            case .reasonable: "inset.filled.center.rectangle"
            case .makeSmaller: "arrow.down.right.and.arrow.up.left"
            case .maximize: "rectangle.fill"
            case .closeTab: "xmark.rectangle.fill"
            case .reopenTab: "plus.rectangle.fill"
            case .closeAllTabs: "rectangle.fill.badge.xmark"
            case .newWindow: "macwindow.badge.plus"
            case .newTab: "plus.rectangle.fill.on.rectangle.fill"
            case .fullscreen: "arrow.down.left.and.arrow.up.right.circle.fill"
            case .spaceRight: "arrow.right.circle.fill"
            case .spaceLeft: "arrow.left.circle.fill"
            }
        }

        /// Accessibility description of the action the symbol represents.
        var accessibilityDescription: String {
            switch self {
            case .close: "Close Window"
            case .minimize: "Minimize Window"
            case .quit: "Force Quit"
            case .hide: "Hide Application"
            case .eject: "Eject Volume"
            case .almost: "Almost Maximize Window"
            case .reasonable: "Reasonable Size"
            case .makeSmaller: "Make Smaller Window"
            case .maximize: "Maximize Window"
            case .closeTab: "Close Tab"
            case .reopenTab: "Reopen Tab"
            case .closeAllTabs: "Close All Tabs"
            case .newWindow: "New Window"
            case .newTab: "New Tab"
            case .fullscreen: "Toggle Fullscreen"
            case .spaceRight: "Move Window to Next Desktop"
            case .spaceLeft: "Move Window to Previous Desktop"
            }
        }

        /// Tint palette painted through the symbol (SF Symbols "palette" /
        /// variable-colour rendering). `nil` keeps the system multicolor
        /// default. Colors map to layers in order: primary → accent → none.
        var paletteColors: [NSColor]? {
            switch self {
            case .close: nil
            case .minimize: [.black, .systemYellow]
            case .quit: [.white, NSColor(red: 0.749, green: 0.353, blue: 0.949, alpha: 1.0)]
            case .hide: [.black, .systemYellow]
            case .eject: [.white, .systemRed]
            case .almost, .reasonable:
                // Single Accent layer (the user's system accent colour), same as Maximize.
                [.controlAccentColor]
            case .makeSmaller:
                // Single Accent layer (the user's system accent colour), same family as Maximize.
                [.controlAccentColor]
            case .maximize:
                // Single Accent layer (the user's system accent colour).
                [.controlAccentColor]
            case .fullscreen:
                [.black, .systemGreen]
            case .spaceRight, .spaceLeft:
                // Primary 100% + Accent 100% (two-layer palette for circle.fill).
                [.white, .controlAccentColor]
            case .closeTab:
                // System multicolor (red X, matching Close).
                nil
            case .reopenTab:
                // Black rectangle body + green plus, both at 100% (palette layer 1: black, layer 2: green).
                [.black, .systemGreen]
            case .closeAllTabs:
                // Primary 100% + Red 100% for Cmd+Shift+W — 2-layer palette for fill variant
                [.white, .systemRed]
            case .newWindow:
                // Green window, white badge, black plus — badge is layer 1, window layer 2 for macwindow.badge.plus
                [.white, .systemGreen, .black]
            case .newTab:
                // Primary (black) rectangles + green plus at 100% — matches reopenTab/newWindow/fullscreen palette.
                [.black, .systemGreen]
            }
        }

        /// Optional entry symbol effect played as the feedback lands.
        ///
        /// Deliberately a small closed enum instead of a stored `SymbolEffect`
        /// existential: `addSymbolEffect` takes `some SymbolEffect` (opaque),
        /// which can't be fed from an `any SymbolEffect` box. The overlay's
        /// single `switch` here is the only place new animations need wiring.
        enum EntryAnimation {
            case bounceUpByLayer
            case wiggleByLayer
        }

        var entryAnimation: EntryAnimation? {
            switch self {
            case .close, .quit, .newWindow: .bounceUpByLayer
            case .closeTab, .reopenTab, .closeAllTabs, .newTab: .wiggleByLayer
            case .minimize, .hide, .eject, .almost, .reasonable, .makeSmaller, .maximize, .fullscreen, .spaceRight,
                 .spaceLeft: nil
            }
        }

        /// Optional symbol *replacement* transition played as the feedback
        /// symbol swaps in. Distinct from `entryAnimation` (an in-place
        /// `addSymbolEffect`): this is a `setSymbolImage` content transition
        /// that visually morphs from the previous symbol, so it pairs with
        /// plain appear for close/minimize or the entry effects for quit/hide.
        enum ReplaceTransition {
            /// `.replace.magic(fallback: .upUp.byLayer)` on macOS 26+; falls
            /// back to `.replace.upUp.byLayer` on macOS 14/15.
            case magicReveal
            /// `.replace.magic(fallback: .downUp.wholeSymbol)` on macOS 26+;
            /// falls back to `.replace.downUp.wholeSymbol` on macOS 14/15.
            case magicDownUpReveal
            /// `.replace.downUp.byLayer` (macOS 14+; no OS-version fallback).
            case downUpReveal
            /// Generic `.replace` — SwiftUI `contentTransition(.symbolEffect(.replace))`.
            case replace
        }

        var replaceTransition: ReplaceTransition? {
            switch self {
            case .almost, .reasonable, .maximize, .minimize, .hide: .downUpReveal
            case .eject: .magicDownUpReveal
            case .spaceRight, .spaceLeft: .downUpReveal
            case .newTab, .closeAllTabs: .replace
            case .close, .quit, .closeTab, .reopenTab, .newWindow, .fullscreen, .makeSmaller: nil
            }
        }

        /// Optional tint palette used *only* for the base symbol painted
        /// before the replace transition. `nil` falls back to
        /// `paletteColors`. Minimize and Hide start from a plain white glyph
        /// so the pre-morph state reads as neutral before filling in.
        var basePaletteColors: [NSColor]? {
            switch self {
            case .minimize, .hide: [.white]
            default: nil
            }
        }

        /// Plain symbol painted *before* the replacement transition fires, so
        /// the swap-in always morphs from a stable base instead of whatever
        /// symbol previously occupied the overlay. The resize modes
        /// (maximize / reasonable / almost) all start from an empty rectangle;
        /// eject starts from its plain `eject.fill` glyph.
        var baseSymbol: String? {
            switch self {
            case .almost, .reasonable, .maximize: "rectangle"
            case .eject: "eject.fill"
            // Outlined/plain glyphs that morph into their filled counterparts
            // (minus.circle.fill / eye.slash.circle.fill) via the replace
            // transitions above.
            case .minimize: "minus.circle"
            case .hide: "eye.slash.circle"
            case .spaceRight: "arrow.right.circle"
            case .spaceLeft: "arrow.left.circle"
            case .newTab: "plus.rectangle.on.rectangle"
            case .closeAllTabs: "rectangle.badge.xmark"
            default: nil
            }
        }
    }
}
