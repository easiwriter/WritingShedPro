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
            Version.self
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

    func testImageStyleSpacingDefaultsAndOverrides() {
        let defaultStyle = ImageStyle(name: "default", displayName: "Default")
        XCTAssertEqual(defaultStyle.defaultSpacingAbove, 0)
        XCTAssertEqual(defaultStyle.defaultSpacingBelow, 0)

        let spacedStyle = ImageStyle(
            name: "figure",
            displayName: "Figure",
            defaultSpacingAbove: 12,
            defaultSpacingBelow: 8
        )
        XCTAssertEqual(spacedStyle.defaultSpacingAbove, 12)
        XCTAssertEqual(spacedStyle.defaultSpacingBelow, 8)
    }

    func testImageStyleAppliesDefaultsAndPreservesCaptionContent() {
        let imageStyle = ImageStyle(
            name: "figure",
            displayName: "Figure",
            defaultScale: 0.75,
            defaultAlignment: .right,
            hasCaptionByDefault: true,
            defaultCaptionStyle: "caption2",
            defaultSpacingAbove: 12,
            defaultSpacingBelow: 8
        )
        let attachment = ImageAttachment()
        attachment.captionPrefix = "Figure"
        attachment.captionText = "A retained caption"

        imageStyle.apply(to: attachment)

        XCTAssertEqual(attachment.imageStyleName, "figure")
        XCTAssertEqual(attachment.scale, 0.75)
        XCTAssertEqual(attachment.alignment, .right)
        XCTAssertTrue(attachment.hasCaption)
        XCTAssertEqual(attachment.captionStyle, "caption2")
        XCTAssertEqual(attachment.captionPrefix, "Figure")
        XCTAssertEqual(attachment.captionText, "A retained caption")
        XCTAssertEqual(attachment.spacingAbove, 12)
        XCTAssertEqual(attachment.spacingBelow, 8)
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

    func testStyleSheetStyleLookupPrefersMostRecentlyModifiedDuplicate() throws {
        let stylesheet = StyleSheet(name: "Test")
        let staleStyle = TextStyleModel(name: "body", displayName: "Body", fontSize: 17)
        let editedStyle = TextStyleModel(name: "body", displayName: "Body", fontSize: 21)
        staleStyle.modifiedDate = Date(timeIntervalSinceReferenceDate: 100)
        editedStyle.modifiedDate = Date(timeIntervalSinceReferenceDate: 200)
        staleStyle.styleSheet = stylesheet
        editedStyle.styleSheet = stylesheet

        context.insert(stylesheet)
        try context.save()

        XCTAssertEqual(stylesheet.style(named: "body")?.fontSize, 21)
    }

    func testLatestStyleModifiedDateIncludesChildStyleChanges() throws {
        let stylesheet = StyleSheet(name: "Test")
        let bodyStyle = TextStyleModel(name: "body", displayName: "Body")
        stylesheet.modifiedDate = Date(timeIntervalSinceReferenceDate: 100)
        bodyStyle.modifiedDate = Date(timeIntervalSinceReferenceDate: 200)
        bodyStyle.styleSheet = stylesheet

        context.insert(stylesheet)
        try context.save()

        XCTAssertEqual(
            stylesheet.latestStyleModifiedDate,
            Date(timeIntervalSinceReferenceDate: 200)
        )
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
        XCTAssertFalse(style.isFirstParagraphStyle)
    }

    func testSetFirstParagraphStyleAllowsOnlyOneSelectedStyle() throws {
        // Given
        let stylesheet = StyleSheet(name: "Test")
        let bodyStyle = TextStyleModel(name: "body", displayName: "Body", displayOrder: 0)
        let headingStyle = TextStyleModel(name: "title1", displayName: "Title 1", displayOrder: 1)

        bodyStyle.styleSheet = stylesheet
        headingStyle.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()

        // When
        stylesheet.setFirstParagraphStyle(headingStyle)

        // Then
        XCTAssertFalse(bodyStyle.isFirstParagraphStyle)
        XCTAssertTrue(headingStyle.isFirstParagraphStyle)
        XCTAssertEqual(stylesheet.firstParagraphStyle?.id, headingStyle.id)
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

    func testDefaultListStyleMatchesBodyDisplaySize() {
        // Given
        let bodyStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            displayOrder: 0,
            fontSize: 12
        )
        let listStyle = TextStyleModel(
            name: "list-bullet",
            displayName: "Bullet List",
            displayOrder: 1,
            fontSize: 12,
            styleCategory: .list
        )

        // When
        let bodyFont = bodyStyle.generateFont()
        let listFont = listStyle.generateFont()

        // Then
        XCTAssertEqual(listFont.pointSize, bodyFont.pointSize, accuracy: 0.01)
    }

    func testDefaultListStyleKeepsStoredSizeWhenPlatformScalingDisabled() {
        // Given
        let listStyle = TextStyleModel(
            name: "list-numbered",
            displayName: "Numbered List",
            displayOrder: 1,
            fontSize: 12,
            styleCategory: .list
        )

        // When
        let font = listStyle.generateFont(applyPlatformScaling: false)

        // Then
        XCTAssertEqual(font.pointSize, 12, accuracy: 0.01)
    }
}
