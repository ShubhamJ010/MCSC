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
        case maximize
        case closeTab
        case reopenTab
        case closeAllTabs
        case newWindow

        /// SF Symbol name rendered by `NSImage(systemSymbolName:)`.
        var symbolName: String {
            switch self {
            case .close: return "xmark.circle.fill"
            case .minimize: return "minus.circle.fill"
            case .quit: return "xmark.circle.fill"
            case .hide: return "eye.slash.circle.fill"
            case .eject: return "eject.circle.fill"
            case .almost: return "inset.filled.rectangle"
            case .reasonable: return "inset.filled.center.rectangle"
            case .maximize: return "rectangle.fill"
            case .closeTab: return "xmark.rectangle.fill"
            case .reopenTab: return "plus.rectangle.fill"
            case .closeAllTabs: return "rectangle.badge.xmark"
            case .newWindow: return "rectangle.badge.plus"
            }
        }

        /// Accessibility description of the action the symbol represents.
        var accessibilityDescription: String {
            switch self {
            case .close: return "Close Window"
            case .minimize: return "Minimize Window"
            case .quit: return "Force Quit"
            case .hide: return "Hide Application"
            case .eject: return "Eject Volume"
            case .almost: return "Almost Maximize Window"
            case .reasonable: return "Reasonable Size"
            case .maximize: return "Maximize Window"
            case .closeTab: return "Close Tab"
            case .reopenTab: return "Reopen Tab"
            case .closeAllTabs: return "Close All Tabs"
            case .newWindow: return "New Window"
            }
        }

        /// Tint palette painted through the symbol (SF Symbols "palette" /
        /// variable-colour rendering). `nil` keeps the system multicolor
        /// default. Colors map to layers in order: primary → accent → none.
        var paletteColors: [NSColor]? {
            switch self {
            case .close: return nil
            case .minimize: return [.black, .systemYellow]
            case .quit: return [.white, NSColor(red: 0.749, green: 0.353, blue: 0.949, alpha: 1.0)]
            case .hide: return [.black, .systemYellow]
            case .eject: return [.white, .systemRed]
            case .almost, .reasonable:
                // Single Accent layer (the user's system accent colour), same as Maximize.
                return [.controlAccentColor]
            case .maximize:
                // Single Accent layer (the user's system accent colour).
                return [.controlAccentColor]
            case .closeTab:
                // System multicolor (red X, matching Close).
                return nil
            case .reopenTab:
                // Positive/additive green plus.
                return [.systemGreen]
            case .closeAllTabs:
                // System multicolor (red X badge, matching Close).
                return nil
            case .newWindow:
                // Positive/additive green badge, matching the reopen plus.
                return [.systemGreen]
            }
        }

        /// Optional entry symbol effect played as the feedback lands.
        ///
        /// Deliberately a small closed enum instead of a stored `SymbolEffect`
        /// existential: `addSymbolEffect` takes `some SymbolEffect` (opaque),
        /// which can't be fed from an `any SymbolEffect` box. The overlay's
        /// single `switch` here is the only place new animations need wiring.
        enum EntryAnimation {
            case bounce
            case wiggleByLayer
        }

        var entryAnimation: EntryAnimation? {
            switch self {
            case .hide: return .bounce
            case .closeTab, .reopenTab, .closeAllTabs, .newWindow: return .wiggleByLayer
            case .close, .minimize, .quit, .eject, .almost, .reasonable, .maximize: return nil
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
            /// `.replace.downUp.byLayer` (macOS 14+; no OS-version fallback).
            case downUpReveal
        }

        var replaceTransition: ReplaceTransition? {
            switch self {
            case .almost, .reasonable, .maximize: return .downUpReveal
            case .close, .minimize, .quit, .hide, .eject, .closeTab, .reopenTab, .closeAllTabs, .newWindow: return nil
            }
        }

        /// Plain symbol painted *before* the replacement transition fires, so
        /// the swap-in always morphs from a stable base instead of whatever
        /// symbol previously occupied the overlay. The resize modes
        /// (maximize / reasonable / almost) all start from an empty rectangle.
        var baseSymbol: String? {
            switch self {
            case .almost, .reasonable, .maximize: return "rectangle"
            default: return nil
            }
        }
    }
}
