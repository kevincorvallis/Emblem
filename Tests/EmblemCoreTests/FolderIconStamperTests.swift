import XCTest
@testable import EmblemCore

final class FolderIconStamperTests: XCTestCase {
    var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("EmblemStamp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private var iconResourceFile: URL {
        folder.appendingPathComponent("Icon\r")
    }

    func testCompositeRendersNonEmptyImage() throws {
        let image = try XCTUnwrap(FolderIconStamper.compositeIcon(symbolName: "star.fill"))
        XCTAssertGreaterThan(image.size.width, 0)
    }

    func testCompositeRejectsInvalidSymbol() {
        XCTAssertNil(FolderIconStamper.compositeIcon(symbolName: "not.a.symbol.zzz"))
    }

    func testApplyCreatesCustomIconAndResetRemovesIt() throws {
        try FolderIconStamper.apply(symbolName: "star.fill", to: folder)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: iconResourceFile.path),
            "setIcon should create the invisible Icon\\r resource file")

        FolderIconStamper.reset(at: folder)
        XCTAssertFalse(FileManager.default.fileExists(atPath: iconResourceFile.path))
    }

    func testApplyToMissingFolderThrows() {
        let missing = folder.appendingPathComponent("nope")
        XCTAssertThrowsError(try FolderIconStamper.apply(symbolName: "star.fill", to: missing))
    }
}
