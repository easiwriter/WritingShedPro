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
    
    // MARK: - Footnote Attachment Tests (Feature 015)
    
    func testRoundTripFootnoteAttachment() {
        // Given
        let text = "Hello World"
        let attributedString = NSMutableAttributedString(string: text)
        
        // Add a footnote attachment at position 5
        let footnoteID = UUID()
        let footnoteAttachment = FootnoteAttachment(footnoteID: footnoteID, number: 1)
        let attachmentString = NSAttributedString(attachment: footnoteAttachment)
        attributedString.insert(attachmentString, at: 5)
        
        // When - Use encode/decode which preserves custom attachments via JSON metadata
        let encodedData = AttributedStringSerializer.encode(attributedString)
        let plainText = attributedString.string
        let restored = AttributedStringSerializer.decode(encodedData, text: plainText)
        
        // Then
        XCTAssertEqual(restored.length, attributedString.length, "Length should match")
        
        // Verify attachment was preserved
        let restoredAttachment = restored.attribute(.attachment, at: 5, effectiveRange: nil) as? FootnoteAttachment
        XCTAssertNotNil(restoredAttachment, "Footnote attachment should be preserved")
        XCTAssertEqual(restoredAttachment?.footnoteID, footnoteID, "Footnote ID should match")
        XCTAssertEqual(restoredAttachment?.number, 1, "Footnote number should match")
    }
    
    func testRoundTripMultipleFootnoteAttachments() {
        // Given
        let text = "First Second Third"
        let attributedString = NSMutableAttributedString(string: text)
        
        // Add footnotes at different positions
        let footnote1 = FootnoteAttachment(footnoteID: UUID(), number: 1)
        let footnote2 = FootnoteAttachment(footnoteID: UUID(), number: 2)
        let footnote3 = FootnoteAttachment(footnoteID: UUID(), number: 3)
        
        attributedString.insert(NSAttributedString(attachment: footnote1), at: 5)
        attributedString.insert(NSAttributedString(attachment: footnote2), at: 13)
        attributedString.insert(NSAttributedString(attachment: footnote3), at: 19)
        
        // When - Use encode/decode which preserves custom attachments via JSON metadata
        let encodedData = AttributedStringSerializer.encode(attributedString)
        let plainText = attributedString.string
        let restored = AttributedStringSerializer.decode(encodedData, text: plainText)
        
        // Then
        XCTAssertEqual(restored.length, attributedString.length, "Length should match")
        
        // Verify all attachments were preserved
        let attachment1 = restored.attribute(.attachment, at: 5, effectiveRange: nil) as? FootnoteAttachment
        let attachment2 = restored.attribute(.attachment, at: 13, effectiveRange: nil) as? FootnoteAttachment
        let attachment3 = restored.attribute(.attachment, at: 19, effectiveRange: nil) as? FootnoteAttachment
        
        XCTAssertNotNil(attachment1)
        XCTAssertNotNil(attachment2)
        XCTAssertNotNil(attachment3)
        
        XCTAssertEqual(attachment1?.number, 1)
        XCTAssertEqual(attachment2?.number, 2)
        XCTAssertEqual(attachment3?.number, 3)
    }
    
    func testRoundTripFootnoteWithFormatting() {
        // Given
        let text = "Formatted text with footnote"
        let attributedString = NSMutableAttributedString(string: text)
        
        // Add formatting
        attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location: 0, length: 9))
        
        // Add footnote
        let footnoteAttachment = FootnoteAttachment(footnoteID: UUID(), number: 5)
        attributedString.insert(NSAttributedString(attachment: footnoteAttachment), at: 14)
        
        // When - Use encode/decode which preserves custom attachments via JSON metadata
        let encodedData = AttributedStringSerializer.encode(attributedString)
        let plainText = attributedString.string
        let restored = AttributedStringSerializer.decode(encodedData, text: plainText)
        
        // Then
        // Verify formatting preserved
        let font = restored.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false, "Bold should be preserved")
        
        // Verify attachment preserved
        let attachment = restored.attribute(.attachment, at: 14, effectiveRange: nil) as? FootnoteAttachment
        XCTAssertNotNil(attachment)
        XCTAssertEqual(attachment?.number, 5)
    }
    
    func testRoundTripFootnoteAttachmentNumberUpdate() {
        // Given
        let text = "Text with footnote"
        let attributedString = NSMutableAttributedString(string: text)
        
        let footnoteAttachment = FootnoteAttachment(footnoteID: UUID(), number: 1)
        attributedString.insert(NSAttributedString(attachment: footnoteAttachment), at: 4)
        
        // Update the number before serialization
        footnoteAttachment.number = 42
        
        // When - Use encode/decode which preserves custom attachments via JSON metadata
        let encodedData = AttributedStringSerializer.encode(attributedString)
        let plainText = attributedString.string
        let restored = AttributedStringSerializer.decode(encodedData, text: plainText)
        
        // Then
        let attachment = restored.attribute(.attachment, at: 4, effectiveRange: nil) as? FootnoteAttachment
        XCTAssertEqual(attachment?.number, 42, "Updated number should be preserved")
    }
    
    func testRoundTripFootnoteIDsPersistence() {
        // Given
        let text = "Text with multiple footnotes"
        let attributedString = NSMutableAttributedString(string: text)
        
        let id1 = UUID()
        let id2 = UUID()
        
        let footnote1 = FootnoteAttachment(footnoteID: id1, number: 1)
        let footnote2 = FootnoteAttachment(footnoteID: id2, number: 2)
        
        attributedString.insert(NSAttributedString(attachment: footnote1), at: 4)
        attributedString.insert(NSAttributedString(attachment: footnote2), at: 10)
        
        // When - Use encode/decode which preserves custom attachments via JSON metadata
        let encodedData = AttributedStringSerializer.encode(attributedString)
        let plainText = attributedString.string
        let restored = AttributedStringSerializer.decode(encodedData, text: plainText)
        
        // Then
        let attachment1 = restored.attribute(.attachment, at: 4, effectiveRange: nil) as? FootnoteAttachment
        let attachment2 = restored.attribute(.attachment, at: 10, effectiveRange: nil) as? FootnoteAttachment
        
        XCTAssertEqual(attachment1?.footnoteID, id1, "First footnote ID should match")
        XCTAssertEqual(attachment2?.footnoteID, id2, "Second footnote ID should match")
    }
    
    func testRoundTripEmptyStringWithFootnote() {
        // Given - just a footnote attachment, no text
        let attributedString = NSMutableAttributedString()
        let footnoteAttachment = FootnoteAttachment(footnoteID: UUID(), number: 1)
        attributedString.append(NSAttributedString(attachment: footnoteAttachment))
        
        // When - Use encode/decode which preserves custom attachments via JSON metadata
        let encodedData = AttributedStringSerializer.encode(attributedString)
        let plainText = attributedString.string
        let restored = AttributedStringSerializer.decode(encodedData, text: plainText)
        
        // Then
        XCTAssertEqual(restored.length, 1, "Should have attachment character")
        let attachment = restored.attribute(.attachment, at: 0, effectiveRange: nil) as? FootnoteAttachment
        XCTAssertNotNil(attachment, "Footnote should be preserved")
    }
    
    func testRoundTripFootnoteWithLargeNumber() {
        // Given
        let text = "Text"
        let attributedString = NSMutableAttributedString(string: text)
        let footnoteAttachment = FootnoteAttachment(footnoteID: UUID(), number: 999)
        attributedString.insert(NSAttributedString(attachment: footnoteAttachment), at: 2)
        
        // When - Use encode/decode which preserves custom attachments via JSON metadata
        let encodedData = AttributedStringSerializer.encode(attributedString)
        let plainText = attributedString.string
        let restored = AttributedStringSerializer.decode(encodedData, text: plainText)
        
        // Then
        let attachment = restored.attribute(.attachment, at: 2, effectiveRange: nil) as? FootnoteAttachment
        XCTAssertEqual(attachment?.number, 999, "Large number should be preserved")
    }
    
    func testValidateRoundTripWithFootnotes() {
        // Given
        let text = "Text with footnote"
        let attributedString = NSMutableAttributedString(string: text)
        let footnoteAttachment = FootnoteAttachment(footnoteID: UUID(), number: 1)
        attributedString.insert(NSAttributedString(attachment: footnoteAttachment), at: 4)
        
        // When - Use encode/decode for validation
        let encodedData = AttributedStringSerializer.encode(attributedString)
        let plainText = attributedString.string
        let restored = AttributedStringSerializer.decode(encodedData, text: plainText)
        
        // Verify the footnote attachment was preserved
        let attachment = restored.attribute(.attachment, at: 4, effectiveRange: nil) as? FootnoteAttachment
        
        // Then
        XCTAssertNotNil(attachment, "Footnote should be preserved")
        XCTAssertEqual(restored.string, attributedString.string, "Text should match")
    }
}
