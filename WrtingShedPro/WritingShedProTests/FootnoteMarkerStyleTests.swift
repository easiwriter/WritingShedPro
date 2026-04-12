import XCTest
@testable import Writing_Shed_Pro

final class FootnoteMarkerStyleTests: XCTestCase {

    // MARK: - Numeric Style

    func testNumeric_ReturnsNumberAsString() {
        let style = FootnoteMarkerStyle.numeric
        XCTAssertEqual(style.displayString(for: 1), "1")
        XCTAssertEqual(style.displayString(for: 5), "5")
        XCTAssertEqual(style.displayString(for: 99), "99")
    }

    // MARK: - Typographic Style: Base Symbols (1–7)

    func testTypographic_BaseSymbols() {
        let style = FootnoteMarkerStyle.typographic
        XCTAssertEqual(style.displayString(for: 1), "*")
        XCTAssertEqual(style.displayString(for: 2), "†")
        XCTAssertEqual(style.displayString(for: 3), "‡")
        XCTAssertEqual(style.displayString(for: 4), "§")
        XCTAssertEqual(style.displayString(for: 5), "‖")
        XCTAssertEqual(style.displayString(for: 6), "¶")
        XCTAssertEqual(style.displayString(for: 7), "#")
    }

    // MARK: - Typographic Style: Doubled Symbols (8–14)

    func testTypographic_DoubledSymbols() {
        let style = FootnoteMarkerStyle.typographic
        XCTAssertEqual(style.displayString(for: 8), "**")
        XCTAssertEqual(style.displayString(for: 9), "††")
        XCTAssertEqual(style.displayString(for: 10), "‡‡")
        XCTAssertEqual(style.displayString(for: 11), "§§")
        XCTAssertEqual(style.displayString(for: 12), "‖‖")
        XCTAssertEqual(style.displayString(for: 13), "¶¶")
        XCTAssertEqual(style.displayString(for: 14), "##")
    }

    // MARK: - Typographic Style: Tripled Symbols (15–21)

    func testTypographic_TripledSymbols() {
        let style = FootnoteMarkerStyle.typographic
        XCTAssertEqual(style.displayString(for: 15), "***")
        XCTAssertEqual(style.displayString(for: 21), "###")
    }

    // MARK: - Edge Cases

    func testTypographic_ZeroOrNegative_ReturnsStar() {
        let style = FootnoteMarkerStyle.typographic
        XCTAssertEqual(style.displayString(for: 0), "*")
        XCTAssertEqual(style.displayString(for: -1), "*")
    }

    // MARK: - Codable Round-Trip

    func testCodable_RoundTrip() throws {
        for style in FootnoteMarkerStyle.allCases {
            let data = try JSONEncoder().encode(style)
            let decoded = try JSONDecoder().decode(FootnoteMarkerStyle.self, from: data)
            XCTAssertEqual(decoded, style)
        }
    }

    // MARK: - CaseIterable

    func testAllCases_ContainsBothStyles() {
        XCTAssertEqual(FootnoteMarkerStyle.allCases.count, 2)
        XCTAssertTrue(FootnoteMarkerStyle.allCases.contains(.numeric))
        XCTAssertTrue(FootnoteMarkerStyle.allCases.contains(.typographic))
    }
}
