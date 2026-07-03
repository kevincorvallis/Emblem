import AppKit

enum SystemActions {
    /// Deep link to System Settings' Extensions area. The query form targets the
    /// extension-points list on macOS 15+; the plain form is the macOS 13/14
    /// fallback. Deeper navigation (straight to Finder extensions) is private.
    static func openExtensionsSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.ExtensionsPreferences?extension-points",
            "x-apple.systempreferences:com.apple.ExtensionsPreferences",
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    static func revealInFinder(_ path: String) {
        let expanded = (path as NSString).expandingTildeInPath
        NSWorkspace.shared.selectFile(expanded, inFileViewerRootedAtPath: (expanded as NSString).deletingLastPathComponent)
    }
}
