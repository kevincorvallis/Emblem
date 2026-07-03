import XCTest
@testable import EmblemCore

final class PathClassifierTests: XCTestCase {
    let home = FileManager.default.homeDirectoryForCurrentUser

    func testNormalHomeSubfolder() {
        XCTAssertEqual(PathClassifier.classify("~/Projects"), .normal)
        XCTAssertEqual(PathClassifier.classify("~/code/personal"), .normal)
    }

    func testCloudStoragePath() {
        XCTAssertEqual(
            PathClassifier.classify("~/Library/CloudStorage/GoogleDrive-x@gmail.com/My Drive"),
            .cloudStorage
        )
    }

    func testTCCProtectedFolders() {
        XCTAssertEqual(PathClassifier.classify("~/Desktop"), .tccProtected)
        XCTAssertEqual(PathClassifier.classify("~/Documents"), .tccProtected)
        XCTAssertEqual(PathClassifier.classify("~/Downloads/sub/deeper"), .tccProtected)
    }

    func testDesktopPrefixNameIsNotProtected() {
        // "~/Desktop-archive" must not match the "~/Desktop" prefix.
        XCTAssertEqual(PathClassifier.classify("~/Desktop-archive"), .normal)
    }

    func testSymlinkIntoCloudStorageClassifiesAsCloud() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("EmblemPC-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temp) }

        // Fake home with a real CloudStorage dir and a symlink pointing into it.
        let fakeHome = temp.appendingPathComponent("home")
        let cloudDir = fakeHome.appendingPathComponent("Library/CloudStorage/Drive/data")
        try FileManager.default.createDirectory(at: cloudDir, withIntermediateDirectories: true)
        let link = fakeHome.appendingPathComponent("cloud-link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: cloudDir)

        XCTAssertEqual(PathClassifier.classify(link.path, home: fakeHome), .cloudStorage)
    }
}
