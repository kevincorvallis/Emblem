import Foundation

/// Persists configuration and owns the on-disk layout under Application Support.
/// Directory-injectable so tests run against temp directories.
public final class ConfigStore {
    public private(set) var config: Config

    public let baseDirectory: URL
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public static var defaultBaseDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Emblem")
    }

    public init(baseDirectory: URL = ConfigStore.defaultBaseDirectory) {
        self.baseDirectory = baseDirectory
        self.config = Config()

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)

        if let data = try? Data(contentsOf: configFileURL),
           let loaded = try? decoder.decode(Config.self, from: data) {
            self.config = loaded
        }
    }

    // MARK: - Directories

    public var appsDirectoryURL: URL {
        let url = baseDirectory.appendingPathComponent("Apps")
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public var iconsDirectoryURL: URL {
        let url = baseDirectory.appendingPathComponent("Icons")
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var configFileURL: URL {
        baseDirectory.appendingPathComponent("config.json")
    }

    public func iconAppURL(for favorite: Favorite) -> URL {
        appsDirectoryURL.appendingPathComponent(favorite.appFileName)
    }

    public func customIconURL(relativePath: String) -> URL {
        iconsDirectoryURL.appendingPathComponent(relativePath)
    }

    // MARK: - Mutations

    public func save() throws {
        let data = try encoder.encode(config)
        try data.write(to: configFileURL)
    }

    public func addFavorite(_ favorite: Favorite) throws {
        config.favorites.append(favorite)
        try save()
    }

    public func updateFavorite(_ favorite: Favorite) throws {
        guard let index = config.favorites.firstIndex(where: { $0.id == favorite.id }) else {
            throw ConfigError.favoriteNotFound
        }
        var updated = favorite
        updated.markUpdated()
        config.favorites[index] = updated
        try save()
    }

    public func removeFavorite(id: UUID) throws {
        config.favorites.removeAll { $0.id == id }
        try save()
    }

    public func favorite(id: UUID) -> Favorite? {
        config.favorites.first { $0.id == id }
    }

    public func updateSettings(_ settings: Config.Settings) throws {
        config.settings = settings
        try save()
    }

    // MARK: - Housekeeping

    /// Icon app bundles on disk that no current favorite claims.
    public func orphanedIconApps() -> [URL] {
        let current = Set(config.favorites.map(\.appFileName))
        let contents = (try? fileManager.contentsOfDirectory(
            at: appsDirectoryURL, includingPropertiesForKeys: nil)) ?? []
        return contents
            .filter { $0.pathExtension == "app" && !current.contains($0.lastPathComponent) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public enum ConfigError: LocalizedError {
        case favoriteNotFound

        public var errorDescription: String? {
            switch self {
            case .favoriteNotFound:
                return "Favorite not found in configuration"
            }
        }
    }
}
