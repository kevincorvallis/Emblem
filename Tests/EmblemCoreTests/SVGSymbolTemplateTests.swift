import XCTest
@testable import EmblemCore

final class SVGSymbolTemplateTests: XCTestCase {
    var fixtureURL: URL {
        Bundle(for: Self.self).url(forResource: "valid-symbol", withExtension: "svg")!
    }

    func testExtractSymbolNameFromTspanForm() throws {
        let content = try String(contentsOf: fixtureURL, encoding: .utf8)
        XCTAssertEqual(try SVGSymbolTemplate.extractSymbolName(from: content), "sidebar.github.rectangle")
    }

    func testExtractSymbolNameFromDirectTextForm() throws {
        // The form used by the bundled blank template (upstream round-trip bug #6).
        let svg = #"<svg><text id="descriptive-name" style="x">my.custom.symbol</text></svg>"#
        XCTAssertEqual(try SVGSymbolTemplate.extractSymbolName(from: svg), "my.custom.symbol")
    }

    func testExtractSymbolNameMissingThrows() {
        XCTAssertThrowsError(try SVGSymbolTemplate.extractSymbolName(from: "<svg></svg>"))
    }

    func testValidateFixtureIsValid() throws {
        let result = SVGSymbolTemplate.validate(at: fixtureURL)
        XCTAssertTrue(result.isValid, "errors: \(result.errors)")
    }

    func testBundledTemplateRoundTrips() throws {
        // Regression for upstream #6: our own blank template, once given a symbol
        // name and user paths, must validate and re-import cleanly.
        let templateURL = Bundle(for: SVGSymbolTemplateMarker.self)
            .url(forResource: "custom-icon-template", withExtension: "svg")!
        var content = try String(contentsOf: templateURL, encoding: .utf8)
        content = content.replacingOccurrences(
            of: "Generated from rectangle.fill",
            with: "my.exported.icon")

        let result = SVGSymbolTemplate.validate(content: content)
        XCTAssertTrue(result.isValid, "errors: \(result.errors)")
        XCTAssertEqual(try SVGSymbolTemplate.extractSymbolName(from: content), "my.exported.icon")
    }

    func testValidateMissingSymbolsLayerFails() {
        let result = SVGSymbolTemplate.validate(content: #"<svg><g id="Guides"/></svg>"#)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(.missingSymbolsLayer))
    }

    func testSymbolNameWithSpacesIsRejected() {
        let svg = #"<svg><g id="Symbols"><g id="Regular-S"><path d="M0 0"/></g></g><text id="descriptive-name">not a name</text></svg>"#
        let result = SVGSymbolTemplate.validate(content: svg)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(.invalidSymbolName("not a name")))
    }

    func testImportSymbolCopiesIntoIconsDirectory() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("EmblemSVG-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let relative = try SVGSymbolTemplate.importSymbol(
            from: fixtureURL, named: "sidebar.github.rectangle", into: temp)
        XCTAssertEqual(relative, "sidebar.github.rectangle.svg")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: temp.appendingPathComponent(relative).path))
    }
}
