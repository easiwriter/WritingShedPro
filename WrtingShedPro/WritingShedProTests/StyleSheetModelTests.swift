//
//  StyleSheetModelTests.swift
//  WritingShedProTests
//
//  Tests for StyleSheet and TextStyleModel database models
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class StyleSheetModelTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUp() async throws {
        // Create in-memory container for testing
        let schema = Schema([
            StyleSheet.self,
            TextStyleModel.self,
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self,
            TrashItem.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }
    
    override func tearDown() {
        container = nil
        context = nil
    }
    
    // MARK: - StyleSheet Tests
    
    func testStyleSheetCreation() throws {
        // Given
        let stylesheet = StyleSheet(name: "Test Stylesheet", isSystemStyleSheet: false)
        
        // When
        context.insert(stylesheet)
        try context.save()
        
        // Then
        XCTAssertEqual(stylesheet.name, "Test Stylesheet")
        XCTAssertFalse(stylesheet.isSystemStyleSheet)
        XCTAssertNotNil(stylesheet.id)
        XCTAssertNotNil(stylesheet.createdDate)
        XCTAssertNotNil(stylesheet.modifiedDate)
    }
    
    func testStyleSheetDefaultValues() throws {
        // Given
        let stylesheet = StyleSheet(name: "Test")
        
        // Then - CloudKit compatibility defaults
        XCTAssertEqual(stylesheet.name, "Test")
        XCTAssertFalse(stylesheet.isSystemStyleSheet)
        XCTAssertNotNil(stylesheet.textStyles)
        XCTAssertEqual(stylesheet.textStyles?.count, 0)
    }
    
    func testStyleSheetTextStyleRelationship() throws {
        // Given
        let stylesheet = StyleSheet(name: "Test Stylesheet")
        let textStyle = TextStyleModel(
            name: "body",
            displayName: "Body",
            displayOrder: 0
        )
        
        // When
        textStyle.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()
        
        // Then
        XCTAssertEqual(stylesheet.textStyles?.count, 1)
        XCTAssertEqual(stylesheet.textStyles?.first?.name, "body")
        XCTAssertEqual(textStyle.styleSheet?.name, "Test Stylesheet")
    }
    
    func testStyleSheetStyleLookup() throws {
        // Given
        let stylesheet = StyleSheet(name: "Test")
        let bodyStyle = TextStyleModel(name: "body", displayName: "Body", displayOrder: 0)
        let titleStyle = TextStyleModel(name: "title1", displayName: "Title 1", displayOrder: 1)
        
        bodyStyle.styleSheet = stylesheet
        titleStyle.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()
        
        // When
        let foundBody = stylesheet.style(named: "body")
        let foundTitle = stylesheet.style(named: "title1")
        let notFound = stylesheet.style(named: "nonexistent")
        
        // Then
        XCTAssertNotNil(foundBody)
        XCTAssertEqual(foundBody?.displayName, "Body")
        XCTAssertNotNil(foundTitle)
        XCTAssertEqual(foundTitle?.displayName, "Title 1")
        XCTAssertNil(notFound)
    }
    
    func testStyleSheetSortedStyles() throws {
        // Given
        let stylesheet = StyleSheet(name: "Test")
        let style1 = TextStyleModel(name: "style1", displayName: "Style 1", displayOrder: 2)
        let style2 = TextStyleModel(name: "style2", displayName: "Style 2", displayOrder: 0)
        let style3 = TextStyleModel(name: "style3", displayName: "Style 3", displayOrder: 1)
        
        style1.styleSheet = stylesheet
        style2.styleSheet = stylesheet
        style3.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()
        
        // When
        let sorted = stylesheet.sortedStyles
        
        // Then
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].name, "style2") // displayOrder: 0
        XCTAssertEqual(sorted[1].name, "style3") // displayOrder: 1
        XCTAssertEqual(sorted[2].name, "style1") // displayOrder: 2
    }
    
    func testStyleSheetCascadeDelete() throws {
        // Given
        let stylesheet = StyleSheet(name: "Test")
        let textStyle1 = TextStyleModel(name: "body", displayName: "Body", displayOrder: 0)
        let textStyle2 = TextStyleModel(name: "title", displayName: "Title", displayOrder: 1)
        
        textStyle1.styleSheet = stylesheet
        textStyle2.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()
        
        // When - Delete stylesheet
        context.delete(stylesheet)
        try context.save()
        
        // Then - Text styles should be deleted too (cascade)
        let descriptor = FetchDescriptor<TextStyleModel>()
        let remainingStyles = try context.fetch(descriptor)
        XCTAssertEqual(remainingStyles.count, 0)
    }
    
    // MARK: - TextStyleModel Tests
    
    func testTextStyleModelCreation() throws {
        // Given
        let style = TextStyleModel(
            name: "body",
            displayName: "Body Text",
            displayOrder: 0,
            fontSize: 17,
            isBold: false
        )
        
        // When
        context.insert(style)
        try context.save()
        
        // Then
        XCTAssertEqual(style.name, "body")
        XCTAssertEqual(style.displayName, "Body Text")
        XCTAssertEqual(style.displayOrder, 0)
        XCTAssertEqual(style.fontSize, 17)
        XCTAssertFalse(style.isBold)
    }
    
    func testTextStyleModelDefaultValues() throws {
        // Given
        let style = TextStyleModel(name: "test", displayName: "Test", displayOrder: 0)
        
        // Then - CloudKit compatibility defaults
        XCTAssertEqual(style.fontSize, 17)
        XCTAssertFalse(style.isBold)
        XCTAssertFalse(style.isItalic)
        XCTAssertFalse(style.isUnderlined)
        XCTAssertFalse(style.isStrikethrough)
        XCTAssertEqual(style.lineSpacing, 0)
        XCTAssertEqual(style.alignment, .natural)
        XCTAssertEqual(style.numberFormat, .none)
        XCTAssertEqual(style.styleCategory, .text)
    }
    
    func testTextStyleModelComputedProperties() throws {
        // Given
        let style = TextStyleModel(name: "test", displayName: "Test", displayOrder: 0)
        
        // When
        style.alignment = .center
        style.numberFormat = .decimal
        style.styleCategory = .heading
        
        // Then
        XCTAssertEqual(style.alignmentRaw, NSTextAlignment.center.rawValue)
        XCTAssertEqual(style.numberFormatRaw, "decimal")
        XCTAssertEqual(style.styleCategoryRaw, "heading")
        
        // And reverse
        XCTAssertEqual(style.alignment, .center)
        XCTAssertEqual(style.numberFormat, .decimal)
        XCTAssertEqual(style.styleCategory, .heading)
    }
    
    func testTextStyleModelTextColor() throws {
        // Given
        let style = TextStyleModel(name: "test", displayName: "Test", displayOrder: 0)
        
        // When
        style.textColor = UIColor.red
        
        // Then
        XCTAssertNotNil(style.textColorHex)
        XCTAssertNotNil(style.textColor)
        
        // Verify roundtrip
        let retrievedColor = style.textColor
        XCTAssertNotNil(retrievedColor)
    }
    
    func testTextStyleModelGenerateFont() throws {
        // Given
        let style = TextStyleModel(
            name: "test",
            displayName: "Test",
            displayOrder: 0,
            fontSize: 20,
            isBold: true,
            isItalic: true
        )
        
        // When
        let font = style.generateFont()
        
        // Then
        XCTAssertEqual(font.pointSize, 20)
        
        let traits = font.fontDescriptor.symbolicTraits
        XCTAssertTrue(traits.contains(.traitBold))
        XCTAssertTrue(traits.contains(.traitItalic))
    }
    
    func testTextStyleModelGenerateAttributes() throws {
        // Given
        let style = TextStyleModel(
            name: "test",
            displayName: "Test",
            displayOrder: 0,
            fontSize: 18,
            isBold: true,
            lineSpacing: 5.0,
            paragraphSpacingBefore: 10.0
        )
        style.textColor = UIColor.blue
        style.alignment = .center
        
        // When
        let attrs = style.generateAttributes()
        
        // Then
        XCTAssertNotNil(attrs[.font])
        XCTAssertNotNil(attrs[.textStyle])
        XCTAssertNotNil(attrs[.foregroundColor])
        XCTAssertNotNil(attrs[.paragraphStyle])
        
        let font = attrs[.font] as? UIFont
        XCTAssertEqual(font?.pointSize, 18)
        
        let color = attrs[.foregroundColor] as? UIColor
        XCTAssertNotNil(color)
        
        let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(paragraphStyle?.alignment, .center)
        XCTAssertEqual(paragraphStyle?.lineSpacing, 5.0)
        XCTAssertEqual(paragraphStyle?.paragraphSpacingBefore, 10.0)
    }
    
    func testTextStyleModelWithCustomFont() throws {
        // Given
        let style = TextStyleModel(
            name: "test",
            displayName: "Test",
            displayOrder: 0,
            fontFamily: "Helvetica",
            fontSize: 16
        )
        
        // When
        let font = style.generateFont()
        
        // Then
        XCTAssertTrue(font.familyName.contains("Helvetica"))
        XCTAssertEqual(font.pointSize, 16)
    }
}
