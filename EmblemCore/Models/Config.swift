import Foundation

/// Code signing identity preference for generated icon apps.
public enum SigningIdentity: String, Codable, CaseIterable, Sendable {
    case automatic = "automatic"
    case adHoc = "-"
    case appleDevelopment = "Apple Development"
    case developerID = "Developer ID Application"

    public var displayName: String {
        switch self {
        case .automatic: return "Automatic (recommended)"
        case .adHoc: return "Ad-hoc (no certificate)"
        case .appleDevelopment: return "Apple Development"
        case .developerID: return "Developer ID Application"
        }
    }
}

/// Root configuration model persisted to config.json.
public struct Config: Codable, Sendable {
    public var version: Int = 1
    public var favorites: [Favorite]
    public var settings: Settings

    public struct Settings: Codable, Sendable {
        public var launchAtLogin: Bool
        public var showInMenuBar: Bool
        public var signingIdentity: SigningIdentity
        /// Also stamp the folder's own Finder icon with the favorite's symbol.
        public var matchFolderIcon: Bool

        enum CodingKeys: String, CodingKey {
            case launchAtLogin, showInMenuBar, signingIdentity, matchFolderIcon
        }

        public init(
            launchAtLogin: Bool = false,
            showInMenuBar: Bool = true,
            signingIdentity: SigningIdentity = .automatic,
            matchFolderIcon: Bool = true
        ) {
            self.launchAtLogin = launchAtLogin
            self.showInMenuBar = showInMenuBar
            self.signingIdentity = signingIdentity
            self.matchFolderIcon = matchFolderIcon
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
            showInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? true
            signingIdentity = try container.decodeIfPresent(SigningIdentity.self, forKey: .signingIdentity) ?? .automatic
            matchFolderIcon = try container.decodeIfPresent(Bool.self, forKey: .matchFolderIcon) ?? true
        }
    }

    public init(favorites: [Favorite] = [], settings: Settings = Settings()) {
        self.favorites = favorites
        self.settings = settings
    }

    public var enabledFavorites: [Favorite] {
        favorites.filter(\.enabled)
    }
}
