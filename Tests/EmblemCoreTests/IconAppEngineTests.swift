import XCTest
@testable import EmblemCore

/// Integration tests: run the real pipeline (copy, plist mutation, codesign,
/// lsregister) against the actual built template. actool/codesign are available
/// on dev machines and GitHub macOS runners alike.
final class IconAppEngineTests: XCTestCase {
    var tempDir: URL!
    var store: ConfigStore!
    var engine: IconAppEngine!
    var watchedFolder: URL!

    var templateURL: URL {
        // The unhosted test bundle sits in Build/Products/<Config>/ next to the
        // template app (built via the Emblem target's dependency).
        Bundle(for: Self.self).bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("IconAppTemplate.app")
    }

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EmblemEngine-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = ConfigStore(baseDirectory: tempDir)
        engine = IconAppEngine(store: store, templateURL: templateURL)
        watchedFolder = tempDir.appendingPathComponent("watched")
        try FileManager.default.createDirectory(at: watchedFolder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func plist(at url: URL) -> [String: Any] {
        (NSDictionary(contentsOf: url) as? [String: Any]) ?? [:]
    }

    func testGenerateSystemSymbolApp() async throws {
        let favorite = Favorite(
            name: "Test Star", folderPath: watchedFolder.path,
            iconType: .sfSymbol, iconValue: "star.fill")
        try store.addFavorite(favorite)

        try await engine.generate(for: favorite)

        let appURL = store.iconAppURL(for: favorite)
        XCTAssertTrue(FileManager.default.fileExists(atPath: appURL.path))

        // Main plist: our bundle ID, symbol name, timestamp-derived version.
        let main = plist(at: appURL.appendingPathComponent("Contents/Info.plist"))
        XCTAssertEqual(main["CFBundleIdentifier"] as? String, favorite.bundleIdentifier)
        let icons = main["CFBundleIcons"] as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        XCTAssertEqual(primary?["CFBundleSymbolName"] as? String, "star.fill")
        XCTAssertEqual(main["CFBundleVersion"] as? String,
                       String(Int(favorite.updatedAt.timeIntervalSince1970)))

        // Extension plist: .sync ID and the expanded watched path.
        let ext = plist(at: appURL.appendingPathComponent(
            "Contents/PlugIns/IconAppSync.appex/Contents/Info.plist"))
        XCTAssertEqual(ext["CFBundleIdentifier"] as? String, favorite.extensionBundleIdentifier)
        XCTAssertEqual(ext["SidebarFolderPaths"] as? [String], [favorite.expandedFolderPath])

        // FolderPath.txt read by the extension at runtime.
        let folderPath = try String(contentsOf: appURL.appendingPathComponent(
            "Contents/PlugIns/IconAppSync.appex/Contents/Resources/FolderPath.txt"), encoding: .utf8)
        XCTAssertEqual(folderPath, favorite.expandedFolderPath)

        // Valid signature (identity depends on machine: Apple Development or ad-hoc).
        let verify = Process()
        verify.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        verify.arguments = ["--verify", "--deep", appURL.path]
        try verify.run()
        verify.waitUntilExit()
        XCTAssertEqual(verify.terminationStatus, 0, "codesign --verify failed")

        let current = await engine.isCurrent(for: favorite)
        XCTAssertTrue(current)
    }

    func testGenerateCustomSVGAppCompilesAssets() async throws {
        let fixture = Bundle(for: Self.self).url(forResource: "valid-symbol", withExtension: "svg")!
        let relative = try SVGSymbolTemplate.importSymbol(
            from: fixture, named: "sidebar.github.rectangle", into: store.iconsDirectoryURL)

        let favorite = Favorite(
            name: "Custom", folderPath: watchedFolder.path,
            iconType: .custom, iconValue: "sidebar.github.rectangle", customSVGPath: relative)
        try store.addFavorite(favorite)

        try await engine.generate(for: favorite)

        let appURL = store.iconAppURL(for: favorite)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: appURL.appendingPathComponent("Contents/Resources/Assets.car").path))

        let main = plist(at: appURL.appendingPathComponent("Contents/Info.plist"))
        let icons = main["CFBundleIcons"] as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        XCTAssertEqual(primary?["CFBundleSymbolName"] as? String, "sidebar.github.rectangle")
    }

    func testRemoveDeletesBundle() async throws {
        let favorite = Favorite(
            name: "Doomed", folderPath: watchedFolder.path, iconValue: "trash.fill")
        try store.addFavorite(favorite)
        try await engine.generate(for: favorite)

        let appURL = store.iconAppURL(for: favorite)
        XCTAssertTrue(FileManager.default.fileExists(atPath: appURL.path))

        try await engine.remove(for: favorite)
        XCTAssertFalse(FileManager.default.fileExists(atPath: appURL.path))
    }

    func testGenerateWithoutTemplateThrows() async throws {
        let broken = IconAppEngine(store: store, templateURL: nil)
        let favorite = Favorite(name: "X", folderPath: watchedFolder.path)
        do {
            try await broken.generate(for: favorite)
            XCTFail("expected templateNotFound")
        } catch let error as IconAppEngine.EngineError {
            guard case .templateNotFound = error else {
                return XCTFail("wrong error: \(error)")
            }
        }
    }
}
