import XCTest
@testable import EmblemCore

final class SymbolCatalogTests: XCTestCase {
    func testAllSymbolsEnumeratesSystemCatalog() {
        let all = SymbolCatalog.allSymbols()
        // CoreGlyphs holds thousands; anything near the curated count means the
        // parse failed and we silently fell back.
        XCTAssertGreaterThan(all.count, 1000)
        XCTAssertTrue(all.contains("folder.fill"))
    }

    func testIsValidAcceptsRealSymbol() {
        XCTAssertTrue(SymbolCatalog.isValid("folder.fill"))
    }

    func testIsValidRejectsGarbage() {
        XCTAssertFalse(SymbolCatalog.isValid("not.a.symbol.zzz"))
    }

    func testEveryCuratedSymbolIsValid() {
        let invalid = SymbolCatalog.curated.filter { !SymbolCatalog.isValid($0) }
        XCTAssertEqual(invalid, [], "curated list contains invalid symbols")
    }

    func testCuratedListHasNoDuplicates() {
        XCTAssertEqual(SymbolCatalog.curated.count, Set(SymbolCatalog.curated).count)
    }

    func testSearchFindsSubstringMatches() {
        let results = SymbolCatalog.search("hammer")
        XCTAssertTrue(results.contains("hammer.fill"))
    }
}
