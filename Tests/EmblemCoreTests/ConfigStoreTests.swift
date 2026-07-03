import XCTest
@testable import EmblemCore

final class ConfigStoreTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EmblemTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSaveAndReloadRoundTrip() throws {
        let store = ConfigStore(baseDirectory: tempDir)
        let favorite = Favorite(name: "Projects", folderPath: "~/Projects", iconValue: "hammer.fill")
        try store.addFavorite(favorite)

        let reloaded = ConfigStore(baseDirectory: tempDir)
        XCTAssertEqual(reloaded.config.favorites.count, 1)
        XCTAssertEqual(reloaded.config.favorites[0].id, favorite.id)
        XCTAssertEqual(reloaded.config.favorites[0].iconValue, "hammer.fill")
    }

    func testUpdateFavoriteBumpsUpdatedAt() throws {
        let store = ConfigStore(baseDirectory: tempDir)
        var favorite = Favorite(name: "A", folderPath: "~/a")
        try store.addFavorite(favorite)
        let originalUpdatedAt = favorite.updatedAt

        favorite.name = "B"
        try store.updateFavorite(favorite)
        XCTAssertGreaterThan(store.config.favorites[0].updatedAt, originalUpdatedAt)
        XCTAssertEqual(store.config.favorites[0].name, "B")
    }

    func testRemoveFavorite() throws {
        let store = ConfigStore(baseDirectory: tempDir)
        let favorite = Favorite(name: "A", folderPath: "~/a")
        try store.addFavorite(favorite)
        try store.removeFavorite(id: favorite.id)
        XCTAssertTrue(store.config.favorites.isEmpty)
    }

    func testOrphanedIconAppsFlagsStrayBundle() throws {
        let store = ConfigStore(baseDirectory: tempDir)
        let favorite = Favorite(name: "Kept", folderPath: "~/kept")
        try store.addFavorite(favorite)

        let apps = store.appsDirectoryURL
        try FileManager.default.createDirectory(
            at: apps.appendingPathComponent(favorite.appFileName),
            withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: apps.appendingPathComponent("stray-deadbeef.app"),
            withIntermediateDirectories: true)

        let orphans = store.orphanedIconApps()
        XCTAssertEqual(orphans.map(\.lastPathComponent), ["stray-deadbeef.app"])
    }

    func testSettingsDecodeToleratesMissingKeys() throws {
        let json = #"{"version":1,"favorites":[],"settings":{"launchAtLogin":true}}"#
        try json.data(using: .utf8)!.write(to: tempDir.appendingPathComponent("config.json"))
        let store = ConfigStore(baseDirectory: tempDir)
        XCTAssertTrue(store.config.settings.launchAtLogin)
        XCTAssertTrue(store.config.settings.showInMenuBar)
        XCTAssertEqual(store.config.settings.signingIdentity, .automatic)
    }
}
