import XCTest
import UIKit
@testable import Writing_Shed_Pro

final class AttributedStringSerializerTests: XCTestCase {
    
    // MARK: - Plain Text Round Trip
    
    func testRoundTripPlainText() {
        // Given
        let plainText = "Hello, World!"
        let attributedString = NSAttributedString(string: plainText)
        
        // When
        guard let rtfData = AttributedStringSerializer.toRTF(attributedString) else {
            XCTFail("Failed to convert to RTF")
            return
        }
        
        guard let restored = AttributedStringSerializer.fromRTF(rtfData) else {
            XCTFail("Failed to convert from RTF")
            return
        }
        
        // Then
        XCTAssertEqual(restored.string, plainText, "Plain text should be preserved")
    }
    
    // MARK: - Bold Formatting
    
    func testRoundTripBoldFormatting() {
        // Given
        let text = "Hello, World!"
        let attributedString = NSMutableAttributedString(string: text)
        let boldFont = UIFont.systemFont(ofSize: 17, weight: .bold)
        attributedString.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 5)) // "Hello"
        
        // When
        guard let rtfData = AttributedStringSerializer.toRTF(attributedString) else {
            XCTFail("Failed to convert to RTF")
            return
        }
        
        guard let restored = AttributedStringSerializer.fromRTF(rtfData) else {
            XCTFail("Failed to convert from RTF")
            return
        }
        
        // Then
        XCTAssertEqual(restored.string, text, "Text should be preserved")
        
        // Check that "Hello" is bold
        let restoredFont = restored.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(restoredFont, "Font attribute should exist")
        XCTAssertTrue(restoredFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false, "Should be bold")
    }
    
    // MARK: - Italic Formatting
    
    func testRoundTripItalicFormatting() {
        // Given
        let text = "Hello, World!"
        let attributedString = NSMutableAttributedString(string: text)
        let italicFont = UIFont.italicSystemFont(ofSize: 17)
        attributedString.addAttribute(.font, value: italicFont, range: NSRange(location: 7, length: 5)) // "World"
        
        // When
        guard let rtfData = AttributedStringSerializer.toRTF(attributedString) else {
            XCTFail("Failed to convert to RTF")
            return
        }
        
        guard let restored = AttributedStringSerializer.fromRTF(rtfData) else {
            XCTFail("Failed to convert from RTF")
            return
        }
        
        // Then
        XCTAssertEqual(restored.string, text, "Text should be preserved")
        
        // Check that "World" is italic
        let restoredFont = restored.attribute(.font, at: 7, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(restoredFont, "Font attribute should exist")
        XCTAssertTrue(restoredFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false, "Should be italic")
    }
    
    // MARK: - Underline and Strikethrough
    
    func testRoundTripUnderlineFormatting() {
        // Given
        let text = "Underlined text"
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: text.count))
        
        // When
        guard let rtfData = AttributedStringSerializer.toRTF(attributedString) else {
            XCTFail("Failed to convert to RTF")
            return
        }
        
        guard let restored = AttributedStringSerializer.fromRTF(rtfData) else {
            XCTFail("Failed to convert from RTF")
            return
        }
        
        // Then
        XCTAssertEqual(restored.string, text, "Text should be preserved")
        
        let underlineStyle = restored.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertNotNil(underlineStyle, "Underline style should exist")
        XCTAssertEqual(underlineStyle, NSUnderlineStyle.single.rawValue, "Should be underlined")
    }
    
    func testRoundTripStrikethroughFormatting() {
        // Given
        let text = "Strikethrough text"
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: text.count))
        
        // When
        guard let rtfData = AttributedStringSerializer.toRTF(attributedString) else {
            XCTFail("Failed to convert to RTF")
            return
        }
        
        guard let restored = AttributedStringSerializer.fromRTF(rtfData) else {
            XCTFail("Failed to convert from RTF")
            return
        }
        
        // Then
        XCTAssertEqual(restored.string, text, "Text should be preserved")
        
        let strikethroughStyle = restored.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertNotNil(strikethroughStyle, "Strikethrough style should exist")
    }
    
    // MARK: - Text Color
    
    func testRoundTripTextColor() {
        // Given
        let text = "Colored text"
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 0, length: text.count))
        
        // When
        guard let rtfData = AttributedStringSerializer.toRTF(attributedString) else {
            XCTFail("Failed to convert to RTF")
            return
        }
        
        guard let restored = AttributedStringSerializer.fromRTF(rtfData) else {
            XCTFail("Failed to convert from RTF")
            return
        }
        
        // Then
        XCTAssertEqual(restored.string, text, "Text should be preserved")
        
        let color = restored.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(color, "Color attribute should exist")
    }
    
    // MARK: - Paragraph Styles
    
    func testRoundTripParagraphAlignment() {
        // Given
        let text = "Centered text"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: text.count))
        
        // When
        guard let rtfData = AttributedStringSerializer.toRTF(attributedString) else {
            XCTFail("Failed to convert to RTF")
            return
        }
        
        guard let restored = AttributedStringSerializer.fromRTF(rtfData) else {
            XCTFail("Failed to convert from RTF")
            return
        }
        
        // Then
        XCTAssertEqual(restored.string, text, "Text should be preserved")
        
        let restoredStyle = restored.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNotNil(restoredStyle, "Paragraph style should exist")
        XCTAssertEqual(restoredStyle?.alignment, .center, "Should be center aligned")
    }
    
    // MARK: - Mixed Formatting
    
    func testRoundTripMixedFormatting() {
        // Given
        let text = "Bold and italic text"
        let attributedString = NSMutableAttributedString(string: text)
        
        // Make "Bold" bold
        let boldFont = UIFont.systemFont(ofSize: 17, weight: .bold)
        attributedString.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 4))
        
        // Make "italic" italic
        let italicFont = UIFont.italicSystemFont(ofSize: 17)
        attributedString.addAttribute(.font, value: italicFont, range: NSRange(location: 9, length: 6))
        
        // When
        guard let rtfData = AttributedStringSerializer.toRTF(attributedString) else {
            XCTFail("Failed to convert to RTF")
            return
        }
        
        guard let restored = AttributedStringSerializer.fromRTF(rtfData) else {
            XCTFail("Failed to convert from RTF")
            return
        }
        
        // Then
        XCTAssertEqual(restored.string, text, "Text should be preserved")
    }
    
    // MARK: - Utility Methods
    
    func testToPlainText() {
        // Given
        let plainText = "Hello, World!"
        let attributedString = NSMutableAttributedString(string: plainText)
        attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location: 0, length: 5))
        
        // When
        let extracted = AttributedStringSerializer.toPlainText(attributedString)
        
        // Then
        XCTAssertEqual(extracted, plainText, "Should extract plain text")
    }
    
    func testEstimatedSize() {
        // Given
        let text = "Hello, World!"
        let attributedString = NSAttributedString(string: text)
        
        // When
        let size = AttributedStringSerializer.estimatedSize(attributedString)
        
        // Then
        XCTAssertGreaterThan(size, 0, "Size should be greater than 0")
        XCTAssertGreaterThan(size, text.count, "RTF size should be larger than plain text")
    }
    
    func testValidateRoundTrip() {
        // Given
        let text = "Test validation"
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location: 0, length: 4))
        
        // When
        let isValid = AttributedStringSerializer.validateRoundTrip(attributedString)
        
        // Then
        XCTAssertTrue(isValid, "Round trip should be valid")
    }
    
    // MARK: - Empty String
    
    func testEmptyString() {
        // Given
        let attributedString = NSAttributedString(string: "")
        
        // When
        guard let rtfData = AttributedStringSerializer.toRTF(attributedString) else {
            XCTFail("Failed to convert empty string to RTF")
            return
        }
        
        guard let restored = AttributedStringSerializer.fromRTF(rtfData) else {
            XCTFail("Failed to convert from RTF")
            return
        }
        
        // Then
        XCTAssertEqual(restored.string, "", "Empty string should be preserved")
    }
    
    // MARK: - Large Document
    
    func testLargeDocument() {
        // Given: 10,000 words (~60KB)
        let words = Array(repeating: "word", count: 10000).joined(separator: " ")
        let attributedString = NSAttributedString(string: words)
        
        // When
        let start = Date()
        guard let rtfData = AttributedStringSerializer.toRTF(attributedString) else {
            XCTFail("Failed to convert large document to RTF")
            return
        }
        let conversionTime = Date().timeIntervalSince(start)
        
        guard let restored = AttributedStringSerializer.fromRTF(rtfData) else {
            XCTFail("Failed to convert from RTF")
            return
        }
        
        // Then
        XCTAssertEqual(restored.string, words, "Large document should be preserved")
        XCTAssertLessThan(conversionTime, 1.0, "Conversion should be fast (< 1 second)")
    }
}
