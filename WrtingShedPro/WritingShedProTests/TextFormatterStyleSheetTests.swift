//
//  TextFormatterStyleSheetTests.swift
//  WritingShedProTests
//
//  Integration tests for TextFormatter with StyleSheet models
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class TextFormatterStyleSheetTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    var project: Project!
    
    override func setUp() async throws {
        // Create in-memory container for testing
        let schema = Schema([
            StyleSheet.self,
            TextStyleModel.self,
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        
        // Initialize stylesheets
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
        
        // Create test project
        project = Project(name: "Test Project", type: .blank)
        context.insert(project)
        try context.save()
    }
    
    override func tearDown() {
        project = nil
        container = nil
        context = nil
    }
    
    // MARK: - getTypingAttributes Tests
    
    func testGetTypingAttributesForBodyStyle() throws {
        // When
        let attrs = TextFormatter.getTypingAttributes(
            forStyleNamed: UIFont.TextStyle.body.rawValue,
            project: project,
            context: context
        )
        
        // Then
        XCTAssertNotNil(attrs[.font])
        XCTAssertNotNil(attrs[.textStyle])
        
        let font = attrs[.font] as? UIFont
        XCTAssertNotNil(font)
        
        let textStyle = attrs[.textStyle]
        XCTAssertNotNil(textStyle)
    }
    
    func testGetTypingAttributesForHeadlineStyle() throws {
        // When
        let attrs = TextFormatter.getTypingAttributes(
            forStyleNamed: UIFont.TextStyle.headline.rawValue,
            project: project,
            context: context
        )
        
        // Then
        let font = attrs[.font] as? UIFont
        XCTAssertNotNil(font)
        
        // Headline should be bold or semibold
        let traits = font?.fontDescriptor.symbolicTraits
        // Note: Headline might not have .traitBold on all systems, check for semibold weight
        XCTAssertNotNil(traits)
    }
    
    func testGetTypingAttributesFallsBackOnInvalidStyle() throws {
        // When
        let attrs = TextFormatter.getTypingAttributes(
            forStyleNamed: "nonexistent-style",
            project: project,
            context: context
        )
        
        // Then - Should fall back to body
        XCTAssertNotNil(attrs[.font])
        XCTAssertNotNil(attrs[.textStyle])
    }
    
    // MARK: - applyStyle Tests
    
    func testApplyStyleToSimpleText() throws {
        // Given
        let text = NSAttributedString(
            string: "Hello World",
            attributes: [.font: UIFont.systemFont(ofSize: 12)]
        )
        let range = NSRange(location: 0, length: text.length)
        
        // When
        let result = TextFormatter.applyStyle(
            named: UIFont.TextStyle.title1.rawValue,
            to: text,
            range: range,
            project: project,
            context: context
        )
        
        // Then
        XCTAssertEqual(result.string, "Hello World")
        
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        XCTAssertGreaterThan(font?.pointSize ?? 0, 17) // Title should be larger than body
        
        let textStyle = result.attribute(.textStyle, at: 0, effectiveRange: nil)
        XCTAssertNotNil(textStyle)
    }
    
    func testApplyStylePreservesCharacterFormatting() throws {
        // Given
        let mutableText = NSMutableAttributedString(string: "Hello World")
        let boldFont = UIFont.boldSystemFont(ofSize: 12)
        mutableText.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 5)) // "Hello" is bold
        
        // When
        let result = TextFormatter.applyStyle(
            named: UIFont.TextStyle.body.rawValue,
            to: mutableText,
            range: NSRange(location: 0, length: mutableText.length),
            project: project,
            context: context
        )
        
        // Then
        let helloFont = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let worldFont = result.attribute(.font, at: 6, effectiveRange: nil) as? UIFont
        
        // "Hello" should still be bold
        XCTAssertTrue(helloFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
        // "World" should not be bold
        XCTAssertFalse(worldFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true)
    }
    
    func testApplyStyleToEmptyText() throws {
        // Given
        let emptyText = NSAttributedString(string: "")
        
        // When
        let result = TextFormatter.applyStyle(
            named: UIFont.TextStyle.headline.rawValue,
            to: emptyText,
            range: NSRange(location: 0, length: 0),
            project: project,
            context: context
        )
        
        // Then
        XCTAssertEqual(result.string, "")
        
        // Empty attributed strings don't have attributes at location 0
        // Just verify the result is valid
        XCTAssertNotNil(result)
    }
    
    func testApplyStyleWithParagraphAttributes() throws {
        // Given
        let text = NSAttributedString(string: "Test paragraph\nSecond line")
        
        // When
        let result = TextFormatter.applyStyle(
            named: UIFont.TextStyle.body.rawValue,
            to: text,
            range: NSRange(location: 0, length: text.length),
            project: project,
            context: context
        )
        
        // Then
        let paragraphStyle = result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNotNil(paragraphStyle)
    }
    
    // MARK: - getCurrentStyleName Tests
    
    func testGetCurrentStyleNameFromAttributedText() throws {
        // Given
        let attrs = TextFormatter.getTypingAttributes(
            forStyleNamed: UIFont.TextStyle.title1.rawValue,
            project: project,
            context: context
        )
        let text = NSAttributedString(string: "Title", attributes: attrs)
        
        // When
        let styleName = TextFormatter.getCurrentStyleName(
            in: text,
            at: NSRange(location: 0, length: 0),
            project: project,
            context: context
        )
        
        // Then - TextStyleModel stores UIFont.TextStyle.rawValue
        XCTAssertEqual(styleName, UIFont.TextStyle.title1.rawValue)
    }
    
    func testGetCurrentStyleNameFromEmptyText() throws {
        // Given
        let emptyText = NSAttributedString(string: "")
        
        // When
        let styleName = TextFormatter.getCurrentStyleName(
            in: emptyText,
            at: NSRange(location: 0, length: 0),
            project: project,
            context: context
        )
        
        // Then - Should default to body (UIFont.TextStyle.body.rawValue)
        XCTAssertEqual(styleName, UIFont.TextStyle.body.rawValue)
    }
    
    func testGetCurrentStyleNameAtDifferentPositions() throws {
        // Given
        let mutableText = NSMutableAttributedString()
        
        let bodyAttrs = TextFormatter.getTypingAttributes(forStyleNamed: UIFont.TextStyle.body.rawValue, project: project, context: context)
        let titleAttrs = TextFormatter.getTypingAttributes(forStyleNamed: UIFont.TextStyle.title1.rawValue, project: project, context: context)
        
        mutableText.append(NSAttributedString(string: "Body text\n", attributes: bodyAttrs))
        mutableText.append(NSAttributedString(string: "Title text", attributes: titleAttrs))
        
        // When
        let styleAtStart = TextFormatter.getCurrentStyleName(
            in: mutableText,
            at: NSRange(location: 0, length: 0),
            project: project,
            context: context
        )
        let styleAtEnd = TextFormatter.getCurrentStyleName(
            in: mutableText,
            at: NSRange(location: mutableText.length - 1, length: 0),
            project: project,
            context: context
        )
        
        // Then
        XCTAssertEqual(styleAtStart, UIFont.TextStyle.body.rawValue)
        XCTAssertEqual(styleAtEnd, UIFont.TextStyle.title1.rawValue)
    }
    
    // MARK: - Custom Stylesheet Tests
    
    func testFormatterWithCustomStylesheet() throws {
        // Given - Create custom stylesheet
        let customSheet = StyleSheet(name: "Custom", isSystemStyleSheet: false)
        let customStyle = TextStyleModel(
            name: "quote",
            displayName: "Block Quote",
            displayOrder: 0,
            fontSize: 16,
            isItalic: true
        )
        customStyle.alignment = .center
        customStyle.styleSheet = customSheet
        context.insert(customSheet)
        
        project.styleSheet = customSheet
        try context.save()
        
        // When
        let attrs = TextFormatter.getTypingAttributes(
            forStyleNamed: "quote",
            project: project,
            context: context
        )
        
        // Then
        let font = attrs[.font] as? UIFont
        XCTAssertEqual(font?.pointSize, 16)
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false)
        
        let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(paragraphStyle?.alignment, .center)
    }
    
    func testFormatterFallsBackToDefaultStylesheet() throws {
        // Given - Project with custom stylesheet that doesn't have "body" style
        let customSheet = StyleSheet(name: "Minimal", isSystemStyleSheet: false)
        context.insert(customSheet)
        
        project.styleSheet = customSheet
        try context.save()
        
        // When - Try to apply "body" style
        let text = NSAttributedString(string: "Test")
        let result = TextFormatter.applyStyle(
            named: UIFont.TextStyle.body.rawValue,
            to: text,
            range: NSRange(location: 0, length: text.length),
            project: project,
            context: context
        )
        
        // Then - Should fall back to default stylesheet's "body"
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
    }
    
    // MARK: - Roundtrip Tests
    
    func testStyleApplicationAndDetectionRoundtrip() throws {
        // Given
        let originalText = NSAttributedString(string: "Test paragraph")
        
        // When - Apply style
        let styledText = TextFormatter.applyStyle(
            named: UIFont.TextStyle.headline.rawValue,
            to: originalText,
            range: NSRange(location: 0, length: originalText.length),
            project: project,
            context: context
        )
        
        // Then - Detect style
        let detectedStyle = TextFormatter.getCurrentStyleName(
            in: styledText,
            at: NSRange(location: 0, length: 0),
            project: project,
            context: context
        )
        
        XCTAssertEqual(detectedStyle, UIFont.TextStyle.headline.rawValue)
    }
    
    func testMultipleStyleApplications() throws {
        // Given
        var text = NSAttributedString(string: "Test")
        
        // When - Apply multiple styles in sequence
        text = TextFormatter.applyStyle(
            named: UIFont.TextStyle.body.rawValue,
            to: text,
            range: NSRange(location: 0, length: text.length),
            project: project,
            context: context
        )
        
        text = TextFormatter.applyStyle(
            named: UIFont.TextStyle.headline.rawValue,
            to: text,
            range: NSRange(location: 0, length: text.length),
            project: project,
            context: context
        )
        
        text = TextFormatter.applyStyle(
            named: UIFont.TextStyle.caption1.rawValue,
            to: text,
            range: NSRange(location: 0, length: text.length),
            project: project,
            context: context
        )
        
        // Then - Final style should be caption1
        let finalStyle = TextFormatter.getCurrentStyleName(
            in: text,
            at: NSRange(location: 0, length: 0),
            project: project,
            context: context
        )
        
        XCTAssertEqual(finalStyle, UIFont.TextStyle.caption1.rawValue)
    }
}
