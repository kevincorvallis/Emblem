import AppKit

/// Stamps a folder's own Finder icon with the favorite's SF Symbol, so the
/// custom look carries into icon views, open/save dialogs, and Spotlight — not
/// just the sidebar. Fully reversible via `reset`.
public struct FolderIconStamper {
    public enum StamperError: LocalizedError {
        case folderNotFound(String)
        case invalidSymbol(String)
        case setIconFailed(String)

        public var errorDescription: String? {
            switch self {
            case .folderNotFound(let path):
                return "Folder not found: \(path)"
            case .invalidSymbol(let name):
                return "Invalid SF Symbol: \(name)"
            case .setIconFailed(let path):
                return "Finder refused the custom icon for \(path)"
            }
        }
    }

    /// Renders the system folder icon with the symbol engraved in its center,
    /// matching how macOS badges special folders (Applications, Developer, …).
    public static func compositeIcon(symbolName: String, size: CGFloat = 1024) -> NSImage? {
        guard NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) != nil else {
            return nil
        }

        let folderIcon = NSWorkspace.shared.icon(for: .folder)

        let config = NSImage.SymbolConfiguration(pointSize: size * 0.34, weight: .medium)
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else {
            return nil
        }

        return NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            folderIcon.draw(in: rect)

            // Engrave color sampled from macOS's own badged folders: a darker
            // shade of the folder blue, drawn slightly below center.
            let engrave = NSColor(calibratedRed: 0.043, green: 0.494, blue: 0.741, alpha: 0.9)
            let tinted = NSImage(size: symbol.size, flipped: false) { r in
                symbol.draw(in: r)
                engrave.set()
                r.fill(using: .sourceAtop)
                return true
            }

            let glyph = tinted.size
            let maxSide = rect.width * 0.42
            let scale = min(maxSide / max(glyph.width, glyph.height), 1.0)
            let drawSize = NSSize(width: glyph.width * scale, height: glyph.height * scale)
            let origin = NSPoint(
                x: rect.midX - drawSize.width / 2,
                y: rect.midY - drawSize.height / 2 - rect.height * 0.06)
            tinted.draw(
                in: NSRect(origin: origin, size: drawSize),
                from: .zero, operation: .sourceOver, fraction: 1.0)
            return true
        }
    }

    /// Applies the composite icon to the folder itself.
    public static func apply(symbolName: String, to folderURL: URL) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDir),
              isDir.boolValue else {
            throw StamperError.folderNotFound(folderURL.path)
        }
        guard let icon = compositeIcon(symbolName: symbolName) else {
            throw StamperError.invalidSymbol(symbolName)
        }
        guard NSWorkspace.shared.setIcon(icon, forFile: folderURL.path) else {
            throw StamperError.setIconFailed(folderURL.path)
        }
    }

    /// Restores the folder's default icon.
    public static func reset(at folderURL: URL) {
        NSWorkspace.shared.setIcon(nil, forFile: folderURL.path)
    }
}
