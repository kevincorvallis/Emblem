import Foundation

/// How a folder path relates to macOS restrictions that affect FinderSync sidebar icons.
public enum PathClassification: Equatable, Sendable {
    /// FinderSync works normally.
    case normal
    /// FileProvider mount (iCloud/Drive/Dropbox): FinderSync can't provide sidebar icons.
    case cloudStorage
    /// TCC-protected (Desktop/Documents/Downloads): extension may need Full Disk Access.
    case tccProtected
}

public struct PathClassifier {
    public static func classify(
        _ path: String,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> PathClassification {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)

        // Cloud check follows symlinks: a link pointing into CloudStorage is still cloud.
        let cloudRoot = home.appendingPathComponent("Library/CloudStorage").standardizedFileURL
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        if isDescendant(resolved, of: cloudRoot) {
            return .cloudStorage
        }

        // TCC check uses the literal path: a symlink elsewhere is exactly the workaround.
        for protected in ["Desktop", "Documents", "Downloads"] {
            let root = home.appendingPathComponent(protected).standardizedFileURL
            if isDescendant(url.standardizedFileURL, of: root) {
                return .tccProtected
            }
        }

        return .normal
    }

    /// Component-wise prefix check so "~/Desktop-archive" doesn't match "~/Desktop".
    private static func isDescendant(_ url: URL, of root: URL) -> Bool {
        let urlParts = url.pathComponents
        let rootParts = root.pathComponents
        guard urlParts.count >= rootParts.count else { return false }
        return Array(urlParts.prefix(rootParts.count)) == rootParts
    }
}
