import Foundation
import AppKit

/// Runtime SF Symbol enumeration and validation.
public struct SymbolCatalog {
    private static let coreGlyphsPlist =
        "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/name_availability.plist"

    private static let cachedAll: [String] = loadAllSymbols()

    /// Every SF Symbol name macOS knows about, or `curated` if the private
    /// CoreGlyphs bundle can't be parsed on some future macOS.
    public static func allSymbols() -> [String] {
        cachedAll
    }

    /// True if the system can render this symbol name.
    public static func isValid(_ name: String) -> Bool {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }

    /// Case-insensitive substring search over the full catalog.
    public static func search(_ query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return curated }
        return cachedAll.filter { $0.lowercased().contains(trimmed) }
    }

    private static func loadAllSymbols() -> [String] {
        guard let plist = NSDictionary(contentsOfFile: coreGlyphsPlist),
              let symbols = plist["symbols"] as? [String: Any],
              symbols.count > curated.count else {
            return curated
        }
        return symbols.keys.sorted()
    }
}
