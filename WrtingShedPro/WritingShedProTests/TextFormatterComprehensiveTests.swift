//
//  TextFormatterComprehensiveTests.swift
//  WritingShedProTests
//
//  Comprehensive tests for TextFormatter formatting operations
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class TextFormatterComprehensiveTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var styleSheet: StyleSheet!
    
    override func setUp() async throws {
        let schema = Schema([StyleSheet.self, TextStyleModel.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = modelContainer.mainContext
        
        // Create default stylesheet
        styleSheet = StyleSheet(name: "Default")
        modelContext.insert(styleSheet)
        
        try modelContext.save()
    }
    
    override func tearDown() {
        styleSheet = nil
        modelContainer = nil
        modelContext = nil
    }
    
    // MARK: - Toggle Bold Tests
    
    func testToggleBoldOnPlainText() {
        // Given
        let text = NSMutableAttributedString(string: "Hello")
        let range = NSRange(location: 0, length: 5)
        
        // When
        let result = TextFormatter.toggleBold(in: text, range: range)
        
        // Then
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitBold),
                     "Text should be bold")
    }
    
    func testToggleBoldOffOnBoldText() {
        // Given
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        let text = NSMutableAttributedString(string: "Bold", attributes: [.font: boldFont])
        let range = NSRange(location: 0, length: 4)
        
        // When
        let result = TextFormatter.toggleBold(in: text, range: range)
        
        // Then
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        XCTAssertFalse(font!.fontDescriptor.symbolicTraits.contains(.traitBold),
                      "Text should no longer be bold")
    }
    
    func testToggleBoldPartialSelection() {
        // Given
        let defaultFont = UIFont.systemFont(ofSize: 17)
        let text = NSMutableAttributedString(string: "Hello World", attributes: [.font: defaultFont])
        let range = NSRange(location: 0, length: 5) // Just "Hello"
        
        // When
        let result = TextFormatter.toggleBold(in: text, range: range)
        
        // Then
        let helloFont = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let worldFont = result.attribute(.font, at: 6, effectiveRange: nil) as? UIFont
        
        XCTAssertTrue(helloFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false,
                     "Hello should be bold")
        XCTAssertFalse(worldFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true,
                      "World should not be bold")
    }
    
    func testToggleBoldPreservesOtherAttributes() {
        // Given
        let text = NSMutableAttributedString(string: "Red", attributes: [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.red
        ])
        let range = NSRange(location: 0, length: 3)
        
        // When
        let result = TextFormatter.toggleBold(in: text, range: range)
        
        // Then
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let color = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
        XCTAssertEqual(color, UIColor.red, "Color should be preserved")
    }
    
    // MARK: - Toggle Italic Tests
    
    func testToggleItalicOnPlainText() {
        // Given
        let text = NSMutableAttributedString(string: "Hello")
        let range = NSRange(location: 0, length: 5)
        
        // When
        let result = TextFormatter.toggleItalic(in: text, range: range)
        
        // Then
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitItalic),
                     "Text should be italic")
    }
    
    func testToggleItalicOffOnItalicText() {
        // Given
        let italicFont = UIFont.italicSystemFont(ofSize: 17)
        let text = NSMutableAttributedString(string: "Italic", attributes: [.font: italicFont])
        let range = NSRange(location: 0, length: 6)
        
        // When
        let result = TextFormatter.toggleItalic(in: text, range: range)
        
        // Then
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        XCTAssertFalse(font!.fontDescriptor.symbolicTraits.contains(.traitItalic),
                      "Text should no longer be italic")
    }
    
    func testBoldAndItalicCombination() {
        // Given
        let text = NSMutableAttributedString(string: "Text")
        let range = NSRange(location: 0, length: 4)
        
        // When
        let boldText = TextFormatter.toggleBold(in: text, range: range)
        let result = TextFormatter.toggleItalic(in: boldText, range: range)
        
        // Then
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitBold),
                     "Text should be bold")
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitItalic),
                     "Text should be italic")
    }
    
    // MARK: - Toggle Underline Tests
    
    func testToggleUnderlineOn() {
        // Given
        let text = NSMutableAttributedString(string: "Underline")
        let range = NSRange(location: 0, length: 9)
        
        // When
        let result = TextFormatter.toggleUnderline(in: text, range: range)
        
        // Then
        let underlineStyle = result.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(underlineStyle, NSUnderlineStyle.single.rawValue)
    }
    
    func testToggleUnderlineOff() {
        // Given
        let text = NSMutableAttributedString(string: "Underline", attributes: [
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ])
        let range = NSRange(location: 0, length: 9)
        
        // When
        let result = TextFormatter.toggleUnderline(in: text, range: range)
        
        // Then
        let underlineStyle = result.attribute(.underlineStyle, at: 0, effectiveRange: nil)
        XCTAssertNil(underlineStyle, "Underline should be removed")
    }
    
    func testUnderlineWithBold() {
        // Given
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        let text = NSMutableAttributedString(string: "Bold", attributes: [.font: boldFont])
        let range = NSRange(location: 0, length: 4)
        
        // When
        let result = TextFormatter.toggleUnderline(in: text, range: range)
        
        // Then
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let underlineStyle = result.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false,
                     "Bold should be preserved")
        XCTAssertEqual(underlineStyle, NSUnderlineStyle.single.rawValue,
                      "Underline should be added")
    }
    
    // MARK: - Toggle Strikethrough Tests
    
    func testToggleStrikethroughOn() {
        // Given
        let text = NSMutableAttributedString(string: "Strike")
        let range = NSRange(location: 0, length: 6)
        
        // When
        let result = TextFormatter.toggleStrikethrough(in: text, range: range)
        
        // Then
        let strikeStyle = result.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(strikeStyle, NSUnderlineStyle.single.rawValue)
    }
    
    func testToggleStrikethroughOff() {
        // Given
        let text = NSMutableAttributedString(string: "Strike", attributes: [
            .strikethroughStyle: NSUnderlineStyle.single.rawValue
        ])
        let range = NSRange(location: 0, length: 6)
        
        // When
        let result = TextFormatter.toggleStrikethrough(in: text, range: range)
        
        // Then
        let strikeStyle = result.attribute(.strikethroughStyle, at: 0, effectiveRange: nil)
        XCTAssertNil(strikeStyle, "Strikethrough should be removed")
    }
    
    func testAllFormattingCombined() {
        // Given
        let text = NSMutableAttributedString(string: "All")
        let range = NSRange(location: 0, length: 3)
        
        // When - Apply all formatting
        let step1 = TextFormatter.toggleBold(in: text, range: range)
        let step2 = TextFormatter.toggleItalic(in: step1, range: range)
        let step3 = TextFormatter.toggleUnderline(in: step2, range: range)
        let result = TextFormatter.toggleStrikethrough(in: step3, range: range)
        
        // Then
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let underline = result.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        let strike = result.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false)
        XCTAssertEqual(underline, NSUnderlineStyle.single.rawValue)
        XCTAssertEqual(strike, NSUnderlineStyle.single.rawValue)
    }
    
    // MARK: - Mixed Formatting Scenarios
    
    func testMixedFormattingInSameText() {
        // Given
        let defaultFont = UIFont.systemFont(ofSize: 17)
        let text = NSMutableAttributedString(string: "Normal Bold Italic", attributes: [.font: defaultFont])
        
        // When - Apply different formatting to different parts
        let step1 = TextFormatter.toggleBold(in: text, range: NSRange(location: 7, length: 4)) // "Bold"
        let result = TextFormatter.toggleItalic(in: step1, range: NSRange(location: 12, length: 6)) // "Italic"
        
        // Then
        let normalFont = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let boldFont = result.attribute(.font, at: 7, effectiveRange: nil) as? UIFont
        let italicFont = result.attribute(.font, at: 12, effectiveRange: nil) as? UIFont
        
        XCTAssertFalse(normalFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true)
        XCTAssertTrue(boldFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
        XCTAssertTrue(italicFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false)
    }
    
    func testPartialFormattingRemoval() {
        // Given - All text is bold
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        let text = NSMutableAttributedString(string: "All Bold Text", attributes: [.font: boldFont])
        
        // When - Remove bold from middle word
        let result = TextFormatter.toggleBold(in: text, range: NSRange(location: 4, length: 4)) // "Bold"
        
        // Then
        let firstFont = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let middleFont = result.attribute(.font, at: 4, effectiveRange: nil) as? UIFont
        let lastFont = result.attribute(.font, at: 9, effectiveRange: nil) as? UIFont
        
        XCTAssertTrue(firstFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
        XCTAssertFalse(middleFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true)
        XCTAssertTrue(lastFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
    }
    
    func testOverlappingFormattingRanges() {
        // Given
        let text = NSMutableAttributedString(string: "Overlap Test")
        
        // When - Apply bold to first part
        let step1 = TextFormatter.toggleBold(in: text, range: NSRange(location: 0, length: 7)) // "Overlap"
        
        // When - Apply italic to overlapping part
        let result = TextFormatter.toggleItalic(in: step1, range: NSRange(location: 4, length: 8)) // "lap Test"
        
        // Then
        let boldOnlyFont = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let bothFont = result.attribute(.font, at: 5, effectiveRange: nil) as? UIFont
        let italicOnlyFont = result.attribute(.font, at: 10, effectiveRange: nil) as? UIFont
        
        XCTAssertTrue(boldOnlyFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
        XCTAssertFalse(boldOnlyFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? true)
        
        XCTAssertTrue(bothFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
        XCTAssertTrue(bothFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false)
        
        XCTAssertFalse(italicOnlyFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true)
        XCTAssertTrue(italicOnlyFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false)
    }
    
    // MARK: - Edge Cases
    
    func testEmptySelection() {
        // Given
        let text = NSMutableAttributedString(string: "Text")
        let range = NSRange(location: 0, length: 0)
        
        // When
        let result = TextFormatter.toggleBold(in: text, range: range)
        
        // Then - Should not crash, formatting applies to typing attributes
        XCTAssertEqual(result.string, "Text")
    }
    
    func testSingleCharacterFormatting() {
        // Given
        let text = NSMutableAttributedString(string: "A")
        let range = NSRange(location: 0, length: 1)
        
        // When
        let step1 = TextFormatter.toggleBold(in: text, range: range)
        let result = TextFormatter.toggleItalic(in: step1, range: range)
        
        // Then
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false)
    }
    
    func testFormattingAtEndOfText() {
        // Given
        let defaultFont = UIFont.systemFont(ofSize: 17)
        let text = NSMutableAttributedString(string: "Hello World", attributes: [.font: defaultFont])
        let range = NSRange(location: 6, length: 5) // "World"
        
        // When
        let result = TextFormatter.toggleBold(in: text, range: range)
        
        // Then
        let helloFont = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let worldFont = result.attribute(.font, at: 6, effectiveRange: nil) as? UIFont
        
        XCTAssertFalse(helloFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true)
        XCTAssertTrue(worldFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
    }
    
    func testFormattingWithEmojis() {
        // Given
        let text = NSMutableAttributedString(string: "Hello 😀 World")
        let range = NSRange(location: 0, length: 8) // "Hello 😀"
        
        // When
        let result = TextFormatter.toggleBold(in: text, range: range)
        
        // Then
        XCTAssertEqual(result.string, "Hello 😀 World")
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
    }
    
    func testFormattingMultipleLines() {
        // Given
        let text = NSMutableAttributedString(string: "Line 1\nLine 2\nLine 3")
        let range = NSRange(location: 0, length: text.length)
        
        // When
        let result = TextFormatter.toggleBold(in: text, range: range)
        
        // Then - All lines should be bold
        result.enumerateAttribute(.font, in: range) { value, subrange, stop in
            if let font = value as? UIFont {
                XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold))
            }
        }
    }
    
    func testFormattingSingleLineInMultiline() {
        // Given
        let defaultFont = UIFont.systemFont(ofSize: 17)
        let text = NSMutableAttributedString(string: "Line 1\nLine 2\nLine 3", attributes: [.font: defaultFont])
        let line2Start = 7
        let line2Length = 6
        let range = NSRange(location: line2Start, length: line2Length) // "Line 2"
        
        // When
        let result = TextFormatter.toggleBold(in: text, range: range)
        
        // Then
        let line1Font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let line2Font = result.attribute(.font, at: 7, effectiveRange: nil) as? UIFont
        let line3Font = result.attribute(.font, at: 14, effectiveRange: nil) as? UIFont
        
        XCTAssertFalse(line1Font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true)
        XCTAssertTrue(line2Font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
        XCTAssertFalse(line3Font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true)
    }
    
    // MARK: - Color Formatting Tests
    
    func testApplyTextColor() {
        // Given
        let text = NSMutableAttributedString(string: "Colored Text")
        let range = NSRange(location: 0, length: 12)
        let redColor = UIColor.red
        
        // When
        text.addAttribute(.foregroundColor, value: redColor, range: range)
        
        // Then
        let color = text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, redColor)
    }
    
    func testApplyColorPreservesFormatting() {
        // Given
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        let text = NSMutableAttributedString(string: "Bold", attributes: [.font: boldFont])
        let range = NSRange(location: 0, length: 4)
        
        // When
        text.addAttribute(.foregroundColor, value: UIColor.blue, range: range)
        
        // Then
        let font = text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let color = text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
        XCTAssertEqual(color, .blue)
    }
    
    func testPartialColorChange() {
        // Given
        let text = NSMutableAttributedString(string: "Red and Blue")
        
        // When
        text.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 0, length: 3))
        text.addAttribute(.foregroundColor, value: UIColor.blue, range: NSRange(location: 8, length: 4))
        
        // Then
        let redColor = text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        let defaultColor = text.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? UIColor
        let blueColor = text.attribute(.foregroundColor, at: 8, effectiveRange: nil) as? UIColor
        
        XCTAssertEqual(redColor, .red)
        XCTAssertNil(defaultColor) // "and " has no explicit color
        XCTAssertEqual(blueColor, .blue)
    }
}
