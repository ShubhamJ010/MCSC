import Cocoa

/// Shared SF Symbol rendering utility configured for consistent icon size, weight,
/// and color palette tints across overlays.
enum SymbolImageFactory {
    static func make(
        symbolName: String,
        description: String,
        paletteColors: [NSColor]?,
        pointSize: CGFloat = 24,
        weight: NSFont.Weight = .semibold
    ) -> NSImage? {
        var config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        if let colors = paletteColors {
            config = config.applying(NSImage.SymbolConfiguration(paletteColors: colors))
        } else {
            config = config.applying(NSImage.SymbolConfiguration.preferringMulticolor())
        }
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: description)?
            .withSymbolConfiguration(config)
    }
}
