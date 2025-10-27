import XCTest
@testable import Writing_Shed_Pro

final class NumberFormatTests: XCTestCase {
    
    // MARK: - Symbol Generation
    
    func testDecimalSymbols() {
        let format = NumberFormat.decimal
        
        XCTAssertEqual(format.symbol(for: 0), "1.")
        XCTAssertEqual(format.symbol(for: 1), "2.")
        XCTAssertEqual(format.symbol(for: 9), "10.")
        XCTAssertEqual(format.symbol(for: 99), "100.")
    }
    
    func testLowercaseRomanSymbols() {
        let format = NumberFormat.lowercaseRoman
        
        XCTAssertEqual(format.symbol(for: 0), "i.")
        XCTAssertEqual(format.symbol(for: 1), "ii.")
        XCTAssertEqual(format.symbol(for: 2), "iii.")
        XCTAssertEqual(format.symbol(for: 3), "iv.")
        XCTAssertEqual(format.symbol(for: 4), "v.")
        XCTAssertEqual(format.symbol(for: 8), "ix.")
        XCTAssertEqual(format.symbol(for: 9), "x.")
    }
    
    func testUppercaseRomanSymbols() {
        let format = NumberFormat.uppercaseRoman
        
        XCTAssertEqual(format.symbol(for: 0), "I.")
        XCTAssertEqual(format.symbol(for: 1), "II.")
        XCTAssertEqual(format.symbol(for: 2), "III.")
        XCTAssertEqual(format.symbol(for: 3), "IV.")
        XCTAssertEqual(format.symbol(for: 4), "V.")
        XCTAssertEqual(format.symbol(for: 8), "IX.")
        XCTAssertEqual(format.symbol(for: 9), "X.")
    }
    
    func testLowercaseLetterSymbols() {
        let format = NumberFormat.lowercaseLetter
        
        XCTAssertEqual(format.symbol(for: 0), "a.")
        XCTAssertEqual(format.symbol(for: 1), "b.")
        XCTAssertEqual(format.symbol(for: 25), "z.")
        XCTAssertEqual(format.symbol(for: 26), "aa.") // After z, should repeat
    }
    
    func testUppercaseLetterSymbols() {
        let format = NumberFormat.uppercaseLetter
        
        XCTAssertEqual(format.symbol(for: 0), "A.")
        XCTAssertEqual(format.symbol(for: 1), "B.")
        XCTAssertEqual(format.symbol(for: 25), "Z.")
        XCTAssertEqual(format.symbol(for: 26), "AA.") // After Z, should repeat
    }
    
    func testFootnoteSymbols() {
        let format = NumberFormat.footnoteSymbols
        
        XCTAssertEqual(format.symbol(for: 0), "*")
        XCTAssertEqual(format.symbol(for: 1), "†")
        XCTAssertEqual(format.symbol(for: 2), "‡")
        XCTAssertEqual(format.symbol(for: 3), "§")
        XCTAssertEqual(format.symbol(for: 4), "¶")
        XCTAssertEqual(format.symbol(for: 5), "*") // Wraps around
    }
    
    func testBulletSymbols() {
        let format = NumberFormat.bulletSymbols
        
        XCTAssertEqual(format.symbol(for: 0), "•")
        XCTAssertEqual(format.symbol(for: 1), "◦")
        XCTAssertEqual(format.symbol(for: 2), "▪")
        XCTAssertEqual(format.symbol(for: 3), "▫")
        XCTAssertEqual(format.symbol(for: 4), "▸")
        XCTAssertEqual(format.symbol(for: 5), "•") // Wraps around
    }
    
    func testNoneSymbol() {
        let format = NumberFormat.none
        
        XCTAssertEqual(format.symbol(for: 0), "")
        XCTAssertEqual(format.symbol(for: 10), "")
    }
    
    // MARK: - Display Names
    
    func testDisplayNames() {
        // Just verify they exist and aren't empty
        XCTAssertFalse(NumberFormat.none.displayName.isEmpty)
        XCTAssertFalse(NumberFormat.decimal.displayName.isEmpty)
        XCTAssertFalse(NumberFormat.lowercaseRoman.displayName.isEmpty)
        XCTAssertFalse(NumberFormat.uppercaseRoman.displayName.isEmpty)
        XCTAssertFalse(NumberFormat.lowercaseLetter.displayName.isEmpty)
        XCTAssertFalse(NumberFormat.uppercaseLetter.displayName.isEmpty)
        XCTAssertFalse(NumberFormat.footnoteSymbols.displayName.isEmpty)
        XCTAssertFalse(NumberFormat.bulletSymbols.displayName.isEmpty)
    }
    
    // MARK: - Codable
    
    func testCodable() throws {
        // Given
        let format = NumberFormat.decimal
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(format)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NumberFormat.self, from: data)
        
        // Then
        XCTAssertEqual(decoded, format)
    }
    
    func testAllCasesCodable() throws {
        for format in NumberFormat.allCases {
            // When
            let encoder = JSONEncoder()
            let data = try encoder.encode(format)
            
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(NumberFormat.self, from: data)
            
            // Then
            XCTAssertEqual(decoded, format, "Should encode/decode \(format)")
        }
    }
    
    // MARK: - NSAttributedString Integration
    
    func testAttributeValueConversion() {
        // Given
        let format = NumberFormat.decimal
        
        // When
        let attributeValue = format.attributeValue
        let restored = NumberFormat.from(attributeValue: attributeValue)
        
        // Then
        XCTAssertEqual(restored, format)
    }
    
    func testFromAttributeValueWithInvalidValue() {
        // Given
        let invalidValue = 12345 // Not a string
        
        // When
        let format = NumberFormat.from(attributeValue: invalidValue)
        
        // Then
        XCTAssertNil(format, "Should return nil for invalid value")
    }
    
    func testFromAttributeValueWithInvalidString() {
        // Given
        let invalidString = "notAValidFormat"
        
        // When
        let format = NumberFormat.from(attributeValue: invalidString)
        
        // Then
        XCTAssertNil(format, "Should return nil for invalid string")
    }
    
    func testCustomAttributeKey() {
        // Given
        let text = "Test text"
        let attributedString = NSMutableAttributedString(string: text)
        let format = NumberFormat.bulletSymbols
        
        // When
        attributedString.addAttribute(.numberFormat, value: format.attributeValue, range: NSRange(location: 0, length: text.count))
        
        // Then
        let retrievedValue = attributedString.attribute(.numberFormat, at: 0, effectiveRange: nil)
        let retrievedFormat = NumberFormat.from(attributeValue: retrievedValue)
        
        XCTAssertNotNil(retrievedFormat)
        XCTAssertEqual(retrievedFormat, format)
    }
    
    // MARK: - All Cases
    
    func testAllCasesCount() {
        XCTAssertEqual(NumberFormat.allCases.count, 8, "Should have 8 format types")
    }
    
    func testAllCasesIncludesExpected() {
        let allCases = Set(NumberFormat.allCases)
        
        XCTAssertTrue(allCases.contains(.none))
        XCTAssertTrue(allCases.contains(.decimal))
        XCTAssertTrue(allCases.contains(.lowercaseRoman))
        XCTAssertTrue(allCases.contains(.uppercaseRoman))
        XCTAssertTrue(allCases.contains(.lowercaseLetter))
        XCTAssertTrue(allCases.contains(.uppercaseLetter))
        XCTAssertTrue(allCases.contains(.footnoteSymbols))
        XCTAssertTrue(allCases.contains(.bulletSymbols))
    }
}
