import SwiftUI
import AppKit
import EmblemCore

enum FavoriteStatus: Equatable {
    case generating
    case active
    case awaitingSetup
    case folderMissing
    case error(String)
}

/// UI-facing state: wraps ConfigStore + IconAppEngine and tracks per-favorite status.
@Observable @MainActor
final class FavoriteStore {
    private let configStore: ConfigStore
    private let engine: IconAppEngine

    private(set) var favorites: [Favorite] = []
    private(set) var statuses: [UUID: FavoriteStatus] = [:]
    var settings: Config.Settings
    /// Set by the ⌘N menu command; ContentView observes and opens the Add sheet.
    var addSheetRequested = false

    init(configStore: ConfigStore = ConfigStore()) {
        self.configStore = configStore
        self.engine = IconAppEngine(
            store: configStore,
            templateURL: Bundle.main.url(forResource: "IconAppTemplate", withExtension: "app"))
        self.favorites = configStore.config.favorites
        self.settings = configStore.config.settings
    }

    var iconsDirectoryURL: URL { configStore.iconsDirectoryURL }

    func customIconURL(relativePath: String) -> URL {
        configStore.customIconURL(relativePath: relativePath)
    }

    // MARK: - CRUD + generation

    /// Persists the favorite, regenerates its icon app, and launches it hidden.
    /// Returns the persisted favorite (updatedAt refreshed) or nil on failure.
    @discardableResult
    func addOrUpdate(_ favorite: Favorite) async -> Favorite? {
        statuses[favorite.id] = .generating
        do {
            if let old = configStore.favorite(id: favorite.id) {
                // Renaming changes appFileName; remove the old bundle so it
                // can't linger as a registered orphan.
                if old.appFileName != favorite.appFileName {
                    try? await engine.remove(for: old)
                }
                // Re-pointing the favorite leaves the old folder stamped.
                if old.expandedFolderPath != favorite.expandedFolderPath {
                    FolderIconStamper.reset(at: old.folderURL)
                }
                try configStore.updateFavorite(favorite)
            } else {
                try configStore.addFavorite(favorite)
            }
            favorites = configStore.config.favorites

            guard let saved = configStore.favorite(id: favorite.id) else { return nil }
            try await engine.generate(for: saved)
            applyFolderIcon(for: saved)
            await launchIconApp(for: saved)
            await refreshStatus(for: saved, force: true)
            return saved
        } catch {
            statuses[favorite.id] = .error(error.localizedDescription)
            favorites = configStore.config.favorites
            return nil
        }
    }

    func delete(_ favorite: Favorite) async {
        try? await engine.remove(for: favorite)
        terminateIconApp(for: favorite)
        FolderIconStamper.reset(at: favorite.folderURL)
        try? configStore.removeFavorite(id: favorite.id)
        favorites = configStore.config.favorites
        statuses[favorite.id] = nil
    }

    func regenerate(_ favorite: Favorite) async {
        _ = await addOrUpdate(favorite)
    }

    // MARK: - Status

    func refreshStatuses() async {
        for favorite in favorites {
            await refreshStatus(for: favorite)
        }
    }

    /// Recomputes a favorite's status. A background refresh (list/menu-bar
    /// polling) must not clobber an in-flight `.generating` — only the
    /// generation completion path passes `force`.
    func refreshStatus(for favorite: Favorite, force: Bool = false) async {
        if !force {
            switch statuses[favorite.id] {
            case .generating, .error:
                return  // in-flight or needs user attention; don't clobber
            default:
                break
            }
        }
        if !FileManager.default.fileExists(atPath: favorite.expandedFolderPath) {
            statuses[favorite.id] = .folderMissing
            return
        }
        let enabled = await engine.isExtensionEnabled(for: favorite)
        statuses[favorite.id] = enabled ? .active : .awaitingSetup
    }

    // MARK: - Icon app processes

    /// Icon apps are LSBackgroundOnly stubs; launching them (hidden) helps Launch
    /// Services and System Settings pick up the extension — upstream behavior.
    func launchIconApp(for favorite: Favorite) async {
        let appURL = configStore.iconAppURL(for: favorite)
        guard FileManager.default.fileExists(atPath: appURL.path) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.hides = true
        _ = try? await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
    }

    private func terminateIconApp(for favorite: Favorite) {
        for app in NSWorkspace.shared.runningApplications
        where app.bundleIdentifier == favorite.bundleIdentifier {
            app.terminate()
        }
    }

    func restartFinder() async {
        await engine.restartFinder()
    }

    // MARK: - Folder icons

    /// Stamps the favorite's folder with its symbol (SF Symbols only; custom
    /// SVG stamping needs the template renderer and is a follow-up).
    private func applyFolderIcon(for favorite: Favorite) {
        guard settings.matchFolderIcon, favorite.iconType == .sfSymbol else { return }
        try? FolderIconStamper.apply(symbolName: favorite.iconValue, to: favorite.folderURL)
    }

    /// Called when the Settings toggle flips: stamp or clear every favorite.
    func setMatchFolderIcon(_ enabled: Bool) {
        settings.matchFolderIcon = enabled
        saveSettings()
        for favorite in favorites {
            if enabled {
                applyFolderIcon(for: favorite)
            } else {
                FolderIconStamper.reset(at: favorite.folderURL)
            }
        }
    }

    // MARK: - Settings

    func saveSettings() {
        try? configStore.updateSettings(settings)
    }

    func availableSigningIdentities() async -> [String] {
        await engine.availableSigningIdentities()
    }

    // MARK: - Housekeeping

    func orphanedApps() -> [URL] {
        configStore.orphanedIconApps()
    }

    func cleanOrphans() async {
        for orphan in configStore.orphanedIconApps() {
            try? await engine.removeOrphan(at: orphan)
        }
    }

    /// Full teardown: every generated icon app removed and unregistered.
    func uninstallAll() async {
        for favorite in favorites {
            try? await engine.remove(for: favorite)
            terminateIconApp(for: favorite)
            FolderIconStamper.reset(at: favorite.folderURL)
        }
        await cleanOrphans()
        statuses = [:]
    }
}
