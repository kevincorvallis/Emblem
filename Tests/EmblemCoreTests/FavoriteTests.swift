import XCTest
@testable import EmblemCore

final class FavoriteTests: XCTestCase {
    func testBundleIdentifierFormat() {
        let favorite = Favorite(name: "My Projects", folderPath: "~/Projects")
        XCTAssertEqual(
            favorite.bundleIdentifier,
            "page.klee.emblem.icon.\(favorite.id.uuidString.lowercased())"
        )
    }

    func testExtensionBundleIdentifierSuffix() {
        let favorite = Favorite(name: "Docs", folderPath: "~/Documents/notes")
        XCTAssertEqual(favorite.extensionBundleIdentifier, favorite.bundleIdentifier + ".sync")
    }

    func testAppFileNameContainsSanitizedNameAndUUIDPrefix() {
        let favorite = Favorite(name: "My Cool/Folder!", folderPath: "~/x")
        let prefix = String(favorite.id.uuidString.prefix(8)).lowercased()
        XCTAssertEqual(favorite.appFileName, "my-cool-folder-\(prefix).app")
    }

    func testSanitizedNameStripsUnsafeCharacters() {
        let favorite = Favorite(name: "A B/C:D", folderPath: "~/x")
        XCTAssertEqual(favorite.sanitizedName, "a-b-c-d")
    }

    func testExpandedFolderPath() {
        let favorite = Favorite(name: "Home", folderPath: "~/stuff")
        XCTAssertEqual(favorite.expandedFolderPath, NSHomeDirectory() + "/stuff")
    }
}
