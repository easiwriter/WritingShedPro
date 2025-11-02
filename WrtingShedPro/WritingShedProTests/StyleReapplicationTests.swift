//
//  StyleReapplicationTests.swift
//  WritingShedProTests
//
//  Tests for reapplying styles after modifications and style change tracking
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class StyleReapplicationTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUp() async throws {
        // Create in-memory container for testing
        let schema = Schema([
            StyleSheet.self,
            TextStyleModel.self,
            Project.self,
            Folder.self,
            File.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        
        // Initialize default stylesheets
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
    }
    
    override func tearDown() {
        container = nil
        context = nil
    }
    
    // MARK: - Style Attribute Generation Tests
    
    func testGenerateAttributesWithAllProperties() throws {
        // Given - A style with comprehensive formatting
        let style = TextStyleModel(
            name: "test-style",
            displayName: "Test Style",
            displayOrder: 0,
            fontSize: 24,
            isBold: true,
            isItalic: true
        )
        style.isUnderlined = true
        style.isStrikethrough = true
        style.textColor = UIColor.systemBlue
        style.alignment = .center
        style.lineSpacing = 8.0
        style.paragraphSpacingAfter = 12.0
        style.paragraphSpacingBefore = 10.0
        style.firstLineIndent = 20.0
        style.headIndent = 15.0
        style.tailIndent = -15.0
        
        context.insert(style)
        try context.save()
        
        // When
        let attributes = style.generateAttributes()
        
        // Then - Verify all attributes are present
        XCTAssertNotNil(attributes[.font], "Font should be present")
        XCTAssertNotNil(attributes[.foregroundColor], "Text color should be present")
        XCTAssertNotNil(attributes[.paragraphStyle], "Paragraph style should be present")
        XCTAssertNotNil(attributes[.textStyle], "Text style identifier should be present")
        
        // Verify font attributes
        let font = attributes[.font] as? UIFont
        XCTAssertEqual(font?.pointSize, 24)
        let traits = font?.fontDescriptor.symbolicTraits ?? []
        XCTAssertTrue(traits.contains(.traitBold), "Font should be bold")
        XCTAssertTrue(traits.contains(.traitItalic), "Font should be italic")
        
        // Verify text decorations
        if style.isUnderlined {
            XCTAssertNotNil(attributes[.underlineStyle], "Underline should be present")
        }
        if style.isStrikethrough {
            XCTAssertNotNil(attributes[.strikethroughStyle], "Strikethrough should be present")
        }
        
        // Verify color
        let color = attributes[.foregroundColor] as? UIColor
        XCTAssertNotNil(color, "Color should be present")
        
        // Verify paragraph style
        let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(paragraphStyle?.alignment, .center)
        XCTAssertEqual(paragraphStyle?.lineSpacing, 8.0)
        XCTAssertEqual(paragraphStyle?.paragraphSpacing, 12.0)
        XCTAssertEqual(paragraphStyle?.paragraphSpacingBefore, 10.0)
        XCTAssertEqual(paragraphStyle?.firstLineHeadIndent, 20.0)
        XCTAssertEqual(paragraphStyle?.headIndent, 15.0)
        XCTAssertEqual(paragraphStyle?.tailIndent, -15.0)
        
        // Verify style identifier
        let styleIdentifier = attributes[.textStyle] as? String
        XCTAssertEqual(styleIdentifier, "test-style")
    }
    
    func testGenerateAttributesWithMinimalProperties() throws {
        // Given - A style with minimal formatting
        let style = TextStyleModel(
            name: "minimal",
            displayName: "Minimal",
            displayOrder: 0
        )
        
        context.insert(style)
        try context.save()
        
        // When
        let attributes = style.generateAttributes()
        
        // Then - Should still have basic attributes
        XCTAssertNotNil(attributes[.font])
        XCTAssertNotNil(attributes[.paragraphStyle])
        XCTAssertNotNil(attributes[.textStyle])
        
        let font = attributes[.font] as? UIFont
        XCTAssertEqual(font?.pointSize, 17) // Default size
        
        let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(paragraphStyle?.alignment, .natural)
        XCTAssertEqual(paragraphStyle?.lineSpacing, 0)
    }
    
    func testGenerateAttributesWithCustomFont() throws {
        // Given - A style with custom font family
        let style = TextStyleModel(
            name: "custom-font",
            displayName: "Custom Font",
            displayOrder: 0,
            fontFamily: "Courier",
            fontSize: 14
        )
        
        context.insert(style)
        try context.save()
        
        // When
        let attributes = style.generateAttributes()
        
        // Then
        let font = attributes[.font] as? UIFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font?.familyName.contains("Courier") ?? false)
        XCTAssertEqual(font?.pointSize, 14)
    }
    
    func testGenerateAttributesWithListFormatting() throws {
        // Given - A style with list formatting
        let style = TextStyleModel(
            name: "numbered-list",
            displayName: "Numbered List",
            displayOrder: 0
        )
        style.styleCategory = .list
        style.numberFormat = .decimal
        style.headIndent = 30.0
        
        context.insert(style)
        try context.save()
        
        // When
        let attributes = style.generateAttributes()
        
        // Then
        let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(paragraphStyle?.headIndent, 30.0)
        XCTAssertEqual(style.numberFormat, .decimal)
        XCTAssertEqual(style.styleCategory, .list)
    }
    
    // MARK: - TextFormatter Integration Tests
    
    func testApplyStyleWithModelBasedFormatting() throws {
        // Given
        let project = Project(name: "Test Project", type: .blank)
        context.insert(project)
        
        let stylesheet = StyleSheet(name: "Test Stylesheet")
        let bodyStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            displayOrder: 0,
            fontSize: 18
        )
        bodyStyle.textColor = UIColor.systemBlue
        bodyStyle.styleSheet = stylesheet
        
        project.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()
        
        let originalText = NSAttributedString(string: "Test text")
        let range = NSRange(location: 0, length: originalText.length)
        
        // When
        let styledText = TextFormatter.applyStyle(
            named: UIFont.TextStyle.body.rawValue,
            to: originalText,
            range: range,
            project: project,
            context: context
        )
        
        // Then
        XCTAssertGreaterThan(styledText.length, 0)
        
        let attributes = styledText.attributes(at: 0, effectiveRange: nil)
        let font = attributes[.font] as? UIFont
        XCTAssertEqual(font?.pointSize, 18)
        
        let color = attributes[.foregroundColor] as? UIColor
        XCTAssertNotNil(color)
        
        let styleIdentifier = attributes[.textStyle] as? String
        XCTAssertEqual(styleIdentifier, UIFont.TextStyle.body.rawValue)
    }
    
    func testApplyStylePreservesCharacterFormatting() throws {
        // Given
        let project = Project(name: "Test Project", type: .blank)
        context.insert(project)
        
        let stylesheet = StyleSheet(name: "Test Stylesheet")
        let bodyStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            displayOrder: 0,
            fontSize: 16
        )
        bodyStyle.styleSheet = stylesheet
        project.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()
        
        // Create text with bold formatting
        let baseFont = UIFont.systemFont(ofSize: 14)
        let boldFont = UIFont.boldSystemFont(ofSize: 14)
        
        let mutableText = NSMutableAttributedString(string: "Normal ")
        mutableText.addAttribute(.font, value: baseFont, range: NSRange(location: 0, length: 7))
        
        let boldText = NSAttributedString(string: "bold", attributes: [.font: boldFont])
        mutableText.append(boldText)
        
        let range = NSRange(location: 0, length: mutableText.length)
        
        // When - Apply paragraph style
        let styledText = TextFormatter.applyStyle(
            named: UIFont.TextStyle.body.rawValue,
            to: mutableText,
            range: range,
            project: project,
            context: context
        )
        
        // Then - Bold trait should be preserved on "bold" text
        let normalAttrs = styledText.attributes(at: 0, effectiveRange: nil)
        let boldAttrs = styledText.attributes(at: 7, effectiveRange: nil)
        
        let normalFont = normalAttrs[.font] as? UIFont
        let boldFontResult = boldAttrs[.font] as? UIFont
        
        XCTAssertEqual(normalFont?.pointSize, 16)
        XCTAssertEqual(boldFontResult?.pointSize, 16)
        
        let boldTraits = boldFontResult?.fontDescriptor.symbolicTraits ?? []
        XCTAssertTrue(boldTraits.contains(.traitBold), "Bold formatting should be preserved")
    }
    
    func testGetCurrentStyleName() throws {
        // Given
        let project = Project(name: "Test Project", type: .blank)
        context.insert(project)
        try context.save()
        
        let stylesheet = StyleSheet(name: "Test Stylesheet")
        let headlineStyle = TextStyleModel(
            name: UIFont.TextStyle.headline.rawValue,
            displayName: "Headline",
            displayOrder: 0
        )
        headlineStyle.styleSheet = stylesheet
        project.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()
        
        // Create attributed text with style
        let attrs = headlineStyle.generateAttributes()
        let text = NSAttributedString(string: "Headline text", attributes: attrs)
        
        let range = NSRange(location: 5, length: 0) // Cursor in middle of text
        
        // When
        let styleName = TextFormatter.getCurrentStyleName(
            in: text,
            at: range,
            project: project,
            context: context
        )
        
        // Then
        XCTAssertEqual(styleName, UIFont.TextStyle.headline.rawValue)
    }
    
    // MARK: - Document Reapplication Simulation Tests
    
    func testMultipleStylesInDocument() throws {
        // Given - Document with multiple paragraph styles
        let project = Project(name: "Test Project", type: .blank)
        context.insert(project)
        
        let stylesheet = StyleSheet(name: "Test Stylesheet")
        
        let titleStyle = TextStyleModel(
            name: UIFont.TextStyle.title1.rawValue,
            displayName: "Title 1",
            displayOrder: 0,
            fontSize: 28
        )
        titleStyle.textColor = UIColor.systemRed
        titleStyle.styleSheet = stylesheet
        
        let bodyStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            displayOrder: 1,
            fontSize: 17
        )
        bodyStyle.textColor = UIColor.label
        bodyStyle.styleSheet = stylesheet
        
        project.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()
        
        // Create document with mixed styles
        let titleAttrs = titleStyle.generateAttributes()
        let bodyAttrs = bodyStyle.generateAttributes()
        
        let document = NSMutableAttributedString()
        document.append(NSAttributedString(string: "Title\n", attributes: titleAttrs))
        document.append(NSAttributedString(string: "Body paragraph", attributes: bodyAttrs))
        
        // When - Modify the styles
        titleStyle.fontSize = 32
        titleStyle.textColor = UIColor.systemBlue
        bodyStyle.fontSize = 18
        try context.save()
        
        // Simulate reapplication
        let reappliedDocument = NSMutableAttributedString(attributedString: document)
        
        // Reapply title style
        if let styleName = titleAttrs[.textStyle] as? String,
           let updatedStyle = StyleSheetService.resolveStyle(named: styleName, for: project, context: context) {
            let newAttrs = updatedStyle.generateAttributes()
            reappliedDocument.setAttributes(newAttrs, range: NSRange(location: 0, length: 6))
        }
        
        // Reapply body style
        if let styleName = bodyAttrs[.textStyle] as? String,
           let updatedStyle = StyleSheetService.resolveStyle(named: styleName, for: project, context: context) {
            let newAttrs = updatedStyle.generateAttributes()
            reappliedDocument.setAttributes(newAttrs, range: NSRange(location: 6, length: reappliedDocument.length - 6))
        }
        
        // Then - Verify updated attributes
        let titleFont = reappliedDocument.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(titleFont?.pointSize, 32, "Title font size should be updated")
        
        let titleColor = reappliedDocument.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(titleColor, "Title color should be updated")
        
        let bodyFont = reappliedDocument.attribute(.font, at: 7, effectiveRange: nil) as? UIFont
        XCTAssertEqual(bodyFont?.pointSize, 18, "Body font size should be updated")
    }
    
    func testReapplicationPreservesLocalFormatting() throws {
        // Given - Text with paragraph style AND local character formatting
        let project = Project(name: "Test Project", type: .blank)
        context.insert(project)
        
        let stylesheet = StyleSheet(name: "Test Stylesheet")
        let bodyStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            displayOrder: 0,
            fontSize: 16
        )
        bodyStyle.textColor = UIColor.label
        bodyStyle.styleSheet = stylesheet
        project.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()
        
        // Create text with bold word in middle
        let baseAttrs = bodyStyle.generateAttributes()
        let _ = baseAttrs[.font] as! UIFont  // Get base font for reference
        let boldFont = UIFont.boldSystemFont(ofSize: 16)
        
        let document = NSMutableAttributedString(string: "Normal bold normal", attributes: baseAttrs)
        document.setAttributes([.font: boldFont], range: NSRange(location: 7, length: 4))
        
        // When - Style changes
        bodyStyle.fontSize = 18
        try context.save()
        
        // Simulate reapplication with trait preservation
        let reappliedDocument = NSMutableAttributedString(attributedString: document)
        let updatedStyle = StyleSheetService.resolveStyle(
            named: UIFont.TextStyle.body.rawValue,
            for: project,
            context: context
        )!
        let newBaseAttrs = updatedStyle.generateAttributes()
        let newBaseFont = newBaseAttrs[.font] as! UIFont
        
        reappliedDocument.enumerateAttributes(
            in: NSRange(location: 0, length: reappliedDocument.length),
            options: []
        ) { attrs, range, _ in
            var updatedAttrs = newBaseAttrs
            
            // Preserve bold trait
            if let existingFont = attrs[.font] as? UIFont {
                let traits = existingFont.fontDescriptor.symbolicTraits
                if traits.contains(.traitBold) {
                    if let descriptor = newBaseFont.fontDescriptor.withSymbolicTraits(.traitBold) {
                        updatedAttrs[.font] = UIFont(descriptor: descriptor, size: 0)
                    }
                }
            }
            
            reappliedDocument.setAttributes(updatedAttrs, range: range)
        }
        
        // Then - Bold trait should be preserved
        let normalFont = reappliedDocument.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(normalFont?.pointSize, 18, "Normal text should have new size")
        
        let boldFontResult = reappliedDocument.attribute(.font, at: 7, effectiveRange: nil) as? UIFont
        XCTAssertEqual(boldFontResult?.pointSize, 18, "Bold text should have new size")
        
        let boldTraits = boldFontResult?.fontDescriptor.symbolicTraits ?? []
        XCTAssertTrue(boldTraits.contains(.traitBold), "Bold trait should be preserved")
    }
    
    // MARK: - Style Enumeration Tests
    
    func testEnumerateTextStyleAttributeInDocument() throws {
        // Given - Document with multiple styled paragraphs
        let project = Project(name: "Test Project", type: .blank)
        context.insert(project)
        
        let stylesheet = StyleSheet(name: "Test Stylesheet")
        
        let title = TextStyleModel(
            name: UIFont.TextStyle.title1.rawValue,
            displayName: "Title",
            displayOrder: 0
        )
        let body = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            displayOrder: 1
        )
        let caption = TextStyleModel(
            name: UIFont.TextStyle.caption1.rawValue,
            displayName: "Caption",
            displayOrder: 2
        )
        
        title.styleSheet = stylesheet
        body.styleSheet = stylesheet
        caption.styleSheet = stylesheet
        project.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()
        
        // Build document
        let document = NSMutableAttributedString()
        document.append(NSAttributedString(string: "Title\n", attributes: title.generateAttributes()))
        document.append(NSAttributedString(string: "Body text\n", attributes: body.generateAttributes()))
        document.append(NSAttributedString(string: "Caption", attributes: caption.generateAttributes()))
        
        // When - Enumerate styles
        var foundStyles: [String: NSRange] = [:]
        document.enumerateAttribute(
            .textStyle,
            in: NSRange(location: 0, length: document.length),
            options: []
        ) { value, range, _ in
            if let styleName = value as? String {
                foundStyles[styleName] = range
            }
        }
        
        // Then
        XCTAssertEqual(foundStyles.count, 3, "Should find all three styles")
        XCTAssertNotNil(foundStyles[UIFont.TextStyle.title1.rawValue])
        XCTAssertNotNil(foundStyles[UIFont.TextStyle.body.rawValue])
        XCTAssertNotNil(foundStyles[UIFont.TextStyle.caption1.rawValue])
    }
}
