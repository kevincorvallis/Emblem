import Foundation

/// A single sidebar favorite: a folder plus the icon it should show.
public struct Favorite: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var folderPath: String
    public var iconType: IconType
    public var iconValue: String  // SF Symbol name or custom symbol name
    public var customSVGPath: String?  // Relative path in Icons/ directory
    public var enabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public enum IconType: String, Codable, Sendable {
        case sfSymbol
        case custom
    }

    public init(
        id: UUID = UUID(),
        name: String,
        folderPath: String,
        iconType: IconType = .sfSymbol,
        iconValue: String = "folder.fill",
        customSVGPath: String? = nil,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.folderPath = folderPath
        self.iconType = iconType
        self.iconValue = iconValue
        self.customSVGPath = customSVGPath
        self.enabled = enabled
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public var expandedFolderPath: String {
        (folderPath as NSString).expandingTildeInPath
    }

    public var folderURL: URL {
        URL(fileURLWithPath: expandedFolderPath)
    }

    public var sanitizedName: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return name
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .lowercased()
    }

    /// Bundle ID is derived from the immutable UUID so renames can't orphan bundles.
    public var bundleIdentifier: String {
        "page.klee.emblem.icon.\(id.uuidString.lowercased())"
    }

    public var extensionBundleIdentifier: String {
        "\(bundleIdentifier).sync"
    }

    /// Human-readable but collision-proof: name is display sugar, UUID prefix is identity.
    public var appFileName: String {
        "\(sanitizedName)-\(id.uuidString.prefix(8).lowercased()).app"
    }

    public mutating func markUpdated() {
        updatedAt = Date()
    }
}
