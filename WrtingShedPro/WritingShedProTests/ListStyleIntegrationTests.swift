//
//  ListStyleIntegrationTests.swift
//  WritingShedProTests
//
//  Integration tests for list style features including:
//  - hasListStyles computed property
//  - List style attribute generation (headIndent, firstLineIndent, textStyle)
//  - Default stylesheet list style configuration
//  - Stylesheet duplication preserving list properties
//  - Hierarchical numbering and parent style relationships
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class ListStyleIntegrationTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUp() async throws {
        let schema = Schema([
            StyleSheet.self,
            TextStyleModel.self,
            ImageStyle.self,
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
    
    // MARK: - Helper: Create a stylesheet with list styles matching default config
    
    private func createStyleSheetWithListStyles() -> StyleSheet {
        let stylesheet = StyleSheet(name: "Test", isSystemStyleSheet: false)
        
        let listIndentPerLevel: CGFloat = 36.0
        
        let listStyles: [(String, String, NumberFormat, Int, Int, String?)] = [
            ("list-numbered", "Numbered List", .decimal, 11, 0, nil),
            ("list-numbered-level-2", "Numbered List Level 2", .lowercaseLetter, 12, 1, "list-numbered"),
            ("list-numbered-level-3", "Numbered List Level 3", .lowercaseRoman, 13, 2, "list-numbered-level-2"),
            ("list-bullet", "Bullet List", .bulletSymbols, 14, 0, nil),
            ("list-bullet-level-2", "Bullet List Level 2", .bulletSymbols, 15, 1, "list-bullet"),
            ("list-bullet-level-3", "Bullet List Level 3", .bulletSymbols, 16, 2, "list-bullet-level-2")
        ]
        
        for (name, displayName, numberFormat, order, level, parentStyle) in listStyles {
            let headIndent = listIndentPerLevel * CGFloat(level + 1)
            let style = TextStyleModel(
                name: name,
                displayName: displayName,
                displayOrder: order,
                fontSize: 17,
                alignment: .left,
                headIndent: headIndent,
                numberFormat: numberFormat,
                styleCategory: .list,
                isSystemStyle: false
            )
            style.parentStyleName = parentStyle
            style.styleSheet = stylesheet
        }
        
        return stylesheet
    }
    
    // MARK: - hasListStyles Tests
    
    func testHasListStyles_EmptyStyleSheet_ReturnsFalse() {
        let stylesheet = StyleSheet(name: "Empty")
        XCTAssertFalse(stylesheet.hasListStyles)
    }
    
    func testHasListStyles_TextStylesOnly_ReturnsFalse() {
        let stylesheet = StyleSheet(name: "Text Only")
        let bodyStyle = TextStyleModel(name: "body", displayName: "Body", displayOrder: 0)
        bodyStyle.styleCategory = .text
        bodyStyle.styleSheet = stylesheet
        
        let headingStyle = TextStyleModel(name: "title1", displayName: "Title 1", displayOrder: 1)
        headingStyle.styleCategory = .heading
        headingStyle.styleSheet = stylesheet
        
        XCTAssertFalse(stylesheet.hasListStyles)
    }
    
    func testHasListStyles_WithListStyles_ReturnsTrue() {
        let stylesheet = createStyleSheetWithListStyles()
        XCTAssertTrue(stylesheet.hasListStyles)
    }
    
    func testHasListStyles_MixedStyles_ReturnsTrue() {
        let stylesheet = StyleSheet(name: "Mixed")
        
        let bodyStyle = TextStyleModel(name: "body", displayName: "Body", displayOrder: 0)
        bodyStyle.styleCategory = .text
        bodyStyle.styleSheet = stylesheet
        
        let listStyle = TextStyleModel(
            name: "list-numbered",
            displayName: "Numbered List",
            displayOrder: 1,
            numberFormat: .decimal,
            styleCategory: .list
        )
        listStyle.styleSheet = stylesheet
        
        XCTAssertTrue(stylesheet.hasListStyles)
    }
    
    func testHasListStyles_FootnoteStylesOnly_ReturnsFalse() {
        let stylesheet = StyleSheet(name: "Footnotes Only")
        let footnoteStyle = TextStyleModel(name: "footnote", displayName: "Footnote", displayOrder: 0)
        footnoteStyle.styleCategory = .footnote
        footnoteStyle.styleSheet = stylesheet
        
        XCTAssertFalse(stylesheet.hasListStyles)
    }
    
    // MARK: - Default Stylesheet List Style Configuration
    
    func testDefaultStyleSheetHasListStyles() {
        let stylesheet = StyleSheetService.createDefaultStyleSheet()
        XCTAssertTrue(stylesheet.hasListStyles)
    }
    
    func testDefaultStyleSheetHasSixListStyles() {
        let stylesheet = StyleSheetService.createDefaultStyleSheet()
        let listStyles = stylesheet.textStyles?.filter { $0.styleCategory == .list } ?? []
        XCTAssertEqual(listStyles.count, 6)
    }
    
    func testDefaultStyleSheetListStyleNames() {
        let stylesheet = StyleSheetService.createDefaultStyleSheet()
        let listNames = Set(stylesheet.textStyles?.filter { $0.styleCategory == .list }.map { $0.name } ?? [])
        
        let expectedNames: Set<String> = [
            "list-numbered", "list-numbered-level-2", "list-numbered-level-3",
            "list-bullet", "list-bullet-level-2", "list-bullet-level-3"
        ]
        XCTAssertEqual(listNames, expectedNames)
    }
    
    func testDefaultStyleSheetListNumberFormats() {
        let stylesheet = StyleSheetService.createDefaultStyleSheet()
        
        let numbered = stylesheet.style(named: "list-numbered")
        XCTAssertEqual(numbered?.numberFormat, .decimal)
        
        let level2 = stylesheet.style(named: "list-numbered-level-2")
        XCTAssertEqual(level2?.numberFormat, .lowercaseLetter)
        
        let level3 = stylesheet.style(named: "list-numbered-level-3")
        XCTAssertEqual(level3?.numberFormat, .lowercaseRoman)
        
        let bullet = stylesheet.style(named: "list-bullet")
        XCTAssertEqual(bullet?.numberFormat, .bulletSymbols)
        
        let bulletLevel2 = stylesheet.style(named: "list-bullet-level-2")
        XCTAssertEqual(bulletLevel2?.numberFormat, .bulletSymbols)
        
        let bulletLevel3 = stylesheet.style(named: "list-bullet-level-3")
        XCTAssertEqual(bulletLevel3?.numberFormat, .bulletSymbols)
    }
    
    func testDefaultStyleSheetListHeadIndents() {
        let stylesheet = StyleSheetService.createDefaultStyleSheet()
        let indentPerLevel: CGFloat = 36.0
        
        // Level 0: headIndent = 36 (1 * 36)
        XCTAssertEqual(stylesheet.style(named: "list-numbered")?.headIndent, indentPerLevel * 1)
        XCTAssertEqual(stylesheet.style(named: "list-bullet")?.headIndent, indentPerLevel * 1)
        
        // Level 1: headIndent = 72 (2 * 36)
        XCTAssertEqual(stylesheet.style(named: "list-numbered-level-2")?.headIndent, indentPerLevel * 2)
        XCTAssertEqual(stylesheet.style(named: "list-bullet-level-2")?.headIndent, indentPerLevel * 2)
        
        // Level 2: headIndent = 108 (3 * 36)
        XCTAssertEqual(stylesheet.style(named: "list-numbered-level-3")?.headIndent, indentPerLevel * 3)
        XCTAssertEqual(stylesheet.style(named: "list-bullet-level-3")?.headIndent, indentPerLevel * 3)
    }
    
    func testDefaultStyleSheetListParentStyles() {
        let stylesheet = StyleSheetService.createDefaultStyleSheet()
        
        // Base levels have no parent
        XCTAssertNil(stylesheet.style(named: "list-numbered")?.parentStyleName)
        XCTAssertNil(stylesheet.style(named: "list-bullet")?.parentStyleName)
        
        // Level 2 has level 1 as parent
        XCTAssertEqual(stylesheet.style(named: "list-numbered-level-2")?.parentStyleName, "list-numbered")
        XCTAssertEqual(stylesheet.style(named: "list-bullet-level-2")?.parentStyleName, "list-bullet")
        
        // Level 3 has level 2 as parent
        XCTAssertEqual(stylesheet.style(named: "list-numbered-level-3")?.parentStyleName, "list-numbered-level-2")
        XCTAssertEqual(stylesheet.style(named: "list-bullet-level-3")?.parentStyleName, "list-bullet-level-2")
    }
    
    func testDefaultStyleSheetListStyleCategories() {
        let stylesheet = StyleSheetService.createDefaultStyleSheet()
        let listStyles = stylesheet.textStyles?.filter { $0.name.hasPrefix("list-") } ?? []
        
        for style in listStyles {
            XCTAssertEqual(style.styleCategory, .list,
                          "Style '\(style.name)' should have .list category but has \(style.styleCategory)")
        }
    }
    
    // MARK: - List Style generateAttributes() Tests
    
    func testListStyleGenerateAttributes_IncludesTextStyleKey() {
        let style = TextStyleModel(
            name: "list-numbered",
            displayName: "Numbered List",
            displayOrder: 0,
            numberFormat: .decimal,
            styleCategory: .list
        )
        
        let attrs = style.generateAttributes()
        let textStyleValue = attrs[.textStyle] as? String
        XCTAssertEqual(textStyleValue, "list-numbered")
    }
    
    func testListStyleGenerateAttributes_HeadIndentMatchesFirstLineIndent() {
        // For list styles, firstLineHeadIndent should equal headIndent
        // so all text aligns at the same position (number is drawn separately)
        let style = TextStyleModel(
            name: "list-numbered",
            displayName: "Numbered List",
            displayOrder: 0,
            headIndent: 36.0,
            numberFormat: .decimal,
            styleCategory: .list
        )
        
        let attrs = style.generateAttributes()
        let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle
        
        XCTAssertNotNil(paragraphStyle)
        XCTAssertEqual(paragraphStyle?.headIndent, 36.0)
        XCTAssertEqual(paragraphStyle?.firstLineHeadIndent, 36.0,
                       "List style firstLineHeadIndent should equal headIndent")
    }
    
    func testListStyleGenerateAttributes_Level2HasCorrectIndent() {
        let style = TextStyleModel(
            name: "list-numbered-level-2",
            displayName: "Numbered List Level 2",
            displayOrder: 0,
            headIndent: 72.0,
            numberFormat: .lowercaseLetter,
            styleCategory: .list
        )
        
        let attrs = style.generateAttributes()
        let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle
        
        XCTAssertEqual(paragraphStyle?.headIndent, 72.0)
        XCTAssertEqual(paragraphStyle?.firstLineHeadIndent, 72.0)
    }
    
    func testListStyleGenerateAttributes_Level3HasCorrectIndent() {
        let style = TextStyleModel(
            name: "list-numbered-level-3",
            displayName: "Numbered List Level 3",
            displayOrder: 0,
            headIndent: 108.0,
            numberFormat: .lowercaseRoman,
            styleCategory: .list
        )
        
        let attrs = style.generateAttributes()
        let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle
        
        XCTAssertEqual(paragraphStyle?.headIndent, 108.0)
        XCTAssertEqual(paragraphStyle?.firstLineHeadIndent, 108.0)
    }
    
    func testListStyleGenerateAttributes_DifferentLevelsHaveDifferentIndents() {
        let stylesheet = createStyleSheetWithListStyles()
        
        let level1Attrs = stylesheet.style(named: "list-numbered")?.generateAttributes()
        let level2Attrs = stylesheet.style(named: "list-numbered-level-2")?.generateAttributes()
        let level3Attrs = stylesheet.style(named: "list-numbered-level-3")?.generateAttributes()
        
        let level1Indent = (level1Attrs?[.paragraphStyle] as? NSParagraphStyle)?.headIndent ?? 0
        let level2Indent = (level2Attrs?[.paragraphStyle] as? NSParagraphStyle)?.headIndent ?? 0
        let level3Indent = (level3Attrs?[.paragraphStyle] as? NSParagraphStyle)?.headIndent ?? 0
        
        XCTAssertLessThan(level1Indent, level2Indent, "Level 2 should be more indented than level 1")
        XCTAssertLessThan(level2Indent, level3Indent, "Level 3 should be more indented than level 2")
    }
    
    func testListStyleGenerateAttributes_EachLevelHasCorrectTextStyleName() {
        let stylesheet = createStyleSheetWithListStyles()
        
        let names = ["list-numbered", "list-numbered-level-2", "list-numbered-level-3",
                     "list-bullet", "list-bullet-level-2", "list-bullet-level-3"]
        
        for name in names {
            let attrs = stylesheet.style(named: name)?.generateAttributes()
            let textStyleValue = attrs?[.textStyle] as? String
            XCTAssertEqual(textStyleValue, name,
                          ".textStyle attribute should match the style name '\(name)'")
        }
    }
    
    // MARK: - Stylesheet Duplication Tests
    
    func testDuplicateStyleSheet_PreservesStyleCategory() throws {
        let original = createStyleSheetWithListStyles()
        context.insert(original)
        try context.save()
        
        // Simulate duplication (same as StyleSheetManagementView.duplicateStyleSheet)
        let duplicate = StyleSheet(name: "Copy of \(original.name)", isSystemStyleSheet: false)
        
        for style in original.textStyles ?? [] {
            let newStyle = TextStyleModel(
                name: style.name,
                displayName: style.displayName,
                displayOrder: style.displayOrder
            )
            // Copy all properties including the ones we fixed
            newStyle.fontSize = style.fontSize
            newStyle.fontFamily = style.fontFamily
            newStyle.fontName = style.fontName
            newStyle.isBold = style.isBold
            newStyle.isItalic = style.isItalic
            newStyle.alignment = style.alignment
            newStyle.headIndent = style.headIndent
            newStyle.numberFormat = style.numberFormat
            newStyle.numberAdornment = style.numberAdornment
            newStyle.styleCategory = style.styleCategory
            newStyle.parentStyleName = style.parentStyleName
            newStyle.followOnStyleName = style.followOnStyleName
            newStyle.includeInTOC = style.includeInTOC
            newStyle.tocLevel = style.tocLevel
            newStyle.styleSheet = duplicate
        }
        
        context.insert(duplicate)
        try context.save()
        
        // Verify list styles preserved their category
        let duplicateListStyles = duplicate.textStyles?.filter { $0.styleCategory == .list } ?? []
        XCTAssertEqual(duplicateListStyles.count, 6,
                       "Duplicated stylesheet should have 6 list styles with .list category")
    }
    
    func testDuplicateStyleSheet_PreservesNumberFormat() throws {
        let original = createStyleSheetWithListStyles()
        context.insert(original)
        try context.save()
        
        let duplicate = StyleSheet(name: "Copy", isSystemStyleSheet: false)
        
        for style in original.textStyles ?? [] {
            let newStyle = TextStyleModel(
                name: style.name,
                displayName: style.displayName,
                displayOrder: style.displayOrder
            )
            newStyle.numberFormat = style.numberFormat
            newStyle.numberAdornment = style.numberAdornment
            newStyle.styleCategory = style.styleCategory
            newStyle.headIndent = style.headIndent
            newStyle.parentStyleName = style.parentStyleName
            newStyle.styleSheet = duplicate
        }
        
        context.insert(duplicate)
        try context.save()
        
        XCTAssertEqual(duplicate.style(named: "list-numbered")?.numberFormat, .decimal)
        XCTAssertEqual(duplicate.style(named: "list-numbered-level-2")?.numberFormat, .lowercaseLetter)
        XCTAssertEqual(duplicate.style(named: "list-numbered-level-3")?.numberFormat, .lowercaseRoman)
        XCTAssertEqual(duplicate.style(named: "list-bullet")?.numberFormat, .bulletSymbols)
    }
    
    func testDuplicateStyleSheet_PreservesParentStyleName() throws {
        let original = createStyleSheetWithListStyles()
        context.insert(original)
        try context.save()
        
        let duplicate = StyleSheet(name: "Copy", isSystemStyleSheet: false)
        
        for style in original.textStyles ?? [] {
            let newStyle = TextStyleModel(
                name: style.name,
                displayName: style.displayName,
                displayOrder: style.displayOrder
            )
            newStyle.styleCategory = style.styleCategory
            newStyle.parentStyleName = style.parentStyleName
            newStyle.styleSheet = duplicate
        }
        
        context.insert(duplicate)
        try context.save()
        
        XCTAssertNil(duplicate.style(named: "list-numbered")?.parentStyleName)
        XCTAssertEqual(duplicate.style(named: "list-numbered-level-2")?.parentStyleName, "list-numbered")
        XCTAssertEqual(duplicate.style(named: "list-numbered-level-3")?.parentStyleName, "list-numbered-level-2")
    }
    
    func testDuplicateStyleSheet_PreservesHeadIndent() throws {
        let original = createStyleSheetWithListStyles()
        context.insert(original)
        try context.save()
        
        let duplicate = StyleSheet(name: "Copy", isSystemStyleSheet: false)
        
        for style in original.textStyles ?? [] {
            let newStyle = TextStyleModel(
                name: style.name,
                displayName: style.displayName,
                displayOrder: style.displayOrder
            )
            newStyle.headIndent = style.headIndent
            newStyle.styleCategory = style.styleCategory
            newStyle.styleSheet = duplicate
        }
        
        context.insert(duplicate)
        try context.save()
        
        XCTAssertEqual(duplicate.style(named: "list-numbered")?.headIndent, 36.0)
        XCTAssertEqual(duplicate.style(named: "list-numbered-level-2")?.headIndent, 72.0)
        XCTAssertEqual(duplicate.style(named: "list-numbered-level-3")?.headIndent, 108.0)
    }
    
    func testDuplicateStyleSheet_HasListStyles() throws {
        let original = createStyleSheetWithListStyles()
        context.insert(original)
        try context.save()
        
        let duplicate = StyleSheet(name: "Copy", isSystemStyleSheet: false)
        
        for style in original.textStyles ?? [] {
            let newStyle = TextStyleModel(
                name: style.name,
                displayName: style.displayName,
                displayOrder: style.displayOrder
            )
            newStyle.styleCategory = style.styleCategory
            newStyle.styleSheet = duplicate
        }
        
        context.insert(duplicate)
        try context.save()
        
        XCTAssertTrue(duplicate.hasListStyles,
                      "Duplicated stylesheet should report hasListStyles = true")
    }
    
    /// Regression test: previously, duplication didn't copy styleCategory,
    /// so all duplicated list styles defaulted to .text category
    func testDuplicateWithoutCategoryFix_WouldLoseListStyles() {
        let original = createStyleSheetWithListStyles()
        let duplicate = StyleSheet(name: "No Category Copy", isSystemStyleSheet: false)
        
        for style in original.textStyles ?? [] {
            let newStyle = TextStyleModel(
                name: style.name,
                displayName: style.displayName,
                displayOrder: style.displayOrder
            )
            // Intentionally skip: newStyle.styleCategory = style.styleCategory
            // This simulates the old bug
            newStyle.styleSheet = duplicate
        }
        
        // Without the fix, all styles default to .text, so hasListStyles would be false
        XCTAssertFalse(duplicate.hasListStyles,
                       "Without copying styleCategory, duplicate should NOT have list styles")
    }
    
    // MARK: - fixStyleCategories Tests
    
    func testFixStyleCategories_FixesMissingListCategory() throws {
        // Simulate a stylesheet where list styles have wrong category
        let stylesheet = StyleSheet(name: "Broken")
        context.insert(stylesheet)
        
        let listStyle = TextStyleModel(
            name: "list-numbered",
            displayName: "Numbered List",
            displayOrder: 11,
            numberFormat: .decimal,
            styleCategory: .text  // Wrong! Should be .list
        )
        listStyle.styleSheet = stylesheet
        context.insert(listStyle)
        try context.save()
        
        // When
        StyleSheetService.fixStyleCategories(in: stylesheet, context: context)
        
        // Then
        XCTAssertEqual(listStyle.styleCategory, .list,
                       "fixStyleCategories should correct list-numbered to .list category")
    }
    
    func testFixStyleCategories_DoesNotAddMissingNestedListStyles() throws {
        // Stylesheet with only base list styles, missing nested ones
        let stylesheet = StyleSheet(name: "Missing Nested")
        context.insert(stylesheet)
        
        let numbered = TextStyleModel(
            name: "list-numbered",
            displayName: "Numbered List",
            displayOrder: 11,
            numberFormat: .decimal,
            styleCategory: .list
        )
        numbered.styleSheet = stylesheet
        context.insert(numbered)
        try context.save()
        
        // When
        StyleSheetService.fixStyleCategories(in: stylesheet, context: context)
        
        // Then - missing styles are not auto-created here (to avoid sync-time duplication)
        let level2 = stylesheet.style(named: "list-numbered-level-2")
        let level3 = stylesheet.style(named: "list-numbered-level-3")
        XCTAssertNil(level2, "fixStyleCategories should not add list-numbered-level-2")
        XCTAssertNil(level3, "fixStyleCategories should not add list-numbered-level-3")
    }
    
    // MARK: - List Style Attribute Application Tests
    
    func testApplyListStyleToAttributedString() {
        let style = TextStyleModel(
            name: "list-numbered",
            displayName: "Numbered List",
            displayOrder: 0,
            headIndent: 36.0,
            numberFormat: .decimal,
            styleCategory: .list
        )
        
        let text = NSMutableAttributedString(string: "First list item")
        let range = NSRange(location: 0, length: text.length)
        let attrs = style.generateAttributes()
        text.addAttributes(attrs, range: range)
        
        // Verify the style was applied
        let appliedTextStyle = text.attribute(.textStyle, at: 0, effectiveRange: nil) as? String
        XCTAssertEqual(appliedTextStyle, "list-numbered")
        
        let appliedParagraph = text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(appliedParagraph?.headIndent, 36.0)
        XCTAssertEqual(appliedParagraph?.firstLineHeadIndent, 36.0)
    }
    
    func testApplyDifferentListLevelsToMultiParagraphText() {
        let stylesheet = createStyleSheetWithListStyles()
        
        let text = NSMutableAttributedString(string: "Level 1\nLevel 2\nLevel 3")
        
        // Apply different list levels to each paragraph
        let nsString = text.string as NSString
        
        let para1Range = nsString.paragraphRange(for: NSRange(location: 0, length: 0))
        let para2Range = nsString.paragraphRange(for: NSRange(location: 8, length: 0))
        let para3Range = nsString.paragraphRange(for: NSRange(location: 16, length: 0))
        
        if let level1 = stylesheet.style(named: "list-numbered") {
            text.addAttributes(level1.generateAttributes(), range: para1Range)
        }
        if let level2 = stylesheet.style(named: "list-numbered-level-2") {
            text.addAttributes(level2.generateAttributes(), range: para2Range)
        }
        if let level3 = stylesheet.style(named: "list-numbered-level-3") {
            text.addAttributes(level3.generateAttributes(), range: para3Range)
        }
        
        // Verify each paragraph has the correct style
        let style1 = text.attribute(.textStyle, at: 0, effectiveRange: nil) as? String
        let style2 = text.attribute(.textStyle, at: 8, effectiveRange: nil) as? String
        let style3 = text.attribute(.textStyle, at: 16, effectiveRange: nil) as? String
        
        XCTAssertEqual(style1, "list-numbered")
        XCTAssertEqual(style2, "list-numbered-level-2")
        XCTAssertEqual(style3, "list-numbered-level-3")
        
        // Verify increasing indents
        let indent1 = (text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.headIndent ?? 0
        let indent2 = (text.attribute(.paragraphStyle, at: 8, effectiveRange: nil) as? NSParagraphStyle)?.headIndent ?? 0
        let indent3 = (text.attribute(.paragraphStyle, at: 16, effectiveRange: nil) as? NSParagraphStyle)?.headIndent ?? 0
        
        XCTAssertLessThan(indent1, indent2)
        XCTAssertLessThan(indent2, indent3)
    }
    
    // MARK: - List Indent Level Transition Tests
    
    /// Verify that transitioning from one list level to the next produces correct attributes
    func testListLevelTransition_Level1ToLevel2() {
        let stylesheet = createStyleSheetWithListStyles()
        
        let level1 = stylesheet.style(named: "list-numbered")
        let level2 = stylesheet.style(named: "list-numbered-level-2")
        
        XCTAssertNotNil(level1)
        XCTAssertNotNil(level2)
        
        let attrs1 = level1!.generateAttributes()
        let attrs2 = level2!.generateAttributes()
        
        // Style name changes
        XCTAssertEqual(attrs1[.textStyle] as? String, "list-numbered")
        XCTAssertEqual(attrs2[.textStyle] as? String, "list-numbered-level-2")
        
        // Indent increases
        let para1 = attrs1[.paragraphStyle] as! NSParagraphStyle
        let para2 = attrs2[.paragraphStyle] as! NSParagraphStyle
        XCTAssertGreaterThan(para2.headIndent, para1.headIndent)
        
        // Both firstLine and headIndent should match within each level
        XCTAssertEqual(para1.firstLineHeadIndent, para1.headIndent)
        XCTAssertEqual(para2.firstLineHeadIndent, para2.headIndent)
    }
    
    func testListLevelTransition_Level2ToLevel3() {
        let stylesheet = createStyleSheetWithListStyles()
        
        let level2 = stylesheet.style(named: "list-numbered-level-2")
        let level3 = stylesheet.style(named: "list-numbered-level-3")
        
        let attrs2 = level2!.generateAttributes()
        let attrs3 = level3!.generateAttributes()
        
        XCTAssertEqual(attrs2[.textStyle] as? String, "list-numbered-level-2")
        XCTAssertEqual(attrs3[.textStyle] as? String, "list-numbered-level-3")
        
        let para2 = attrs2[.paragraphStyle] as! NSParagraphStyle
        let para3 = attrs3[.paragraphStyle] as! NSParagraphStyle
        XCTAssertGreaterThan(para3.headIndent, para2.headIndent)
    }
    
    /// Verify that the textStyle attribute is preserved when applying level attributes
    /// over existing content. This is key for the Enter handler fix.
    func testListStyleAttributeOverwrite_PreservesNewTextStyle() {
        let stylesheet = createStyleSheetWithListStyles()
        
        // Start with level-1 ZWS
        let zwsChar = "\u{200B}"
        let text = NSMutableAttributedString(string: zwsChar)
        let level1Attrs = stylesheet.style(named: "list-numbered")!.generateAttributes()
        text.addAttributes(level1Attrs, range: NSRange(location: 0, length: 1))
        
        // Verify it's level 1
        XCTAssertEqual(text.attribute(.textStyle, at: 0, effectiveRange: nil) as? String, "list-numbered")
        
        // Now apply level 2 (simulates increaseListIndent on non-empty paragraph)
        let level2Attrs = stylesheet.style(named: "list-numbered-level-2")!.generateAttributes()
        text.addAttributes(level2Attrs, range: NSRange(location: 0, length: 1))
        
        // Verify it's now level 2 (not still level 1)
        XCTAssertEqual(text.attribute(.textStyle, at: 0, effectiveRange: nil) as? String,
                       "list-numbered-level-2",
                       "addAttributes should overwrite .textStyle with the new level")
        
        let paraStyle = text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(paraStyle?.headIndent, 72.0,
                       "addAttributes should overwrite paragraph style with level 2 indent")
    }
    
    // MARK: - Hierarchical Number Formatting Tests
    
    func testHierarchicalNumberFormat_Level1Decimal() {
        let format = NumberFormat.decimal
        let symbol = format.symbol(for: 0, adornment: .period, level: 0)
        XCTAssertEqual(symbol, "1.")
    }
    
    func testHierarchicalNumberFormat_Level2LowercaseLetter() {
        let format = NumberFormat.lowercaseLetter
        let symbol = format.symbol(for: 0, adornment: .period, level: 1)
        XCTAssertEqual(symbol, "a.")
    }
    
    func testHierarchicalNumberFormat_Level3LowercaseRoman() {
        let format = NumberFormat.lowercaseRoman
        let symbol = format.symbol(for: 0, adornment: .period, level: 2)
        XCTAssertEqual(symbol, "i.")
    }
    
    func testHierarchicalNumberFormat_MultipleItems() {
        let format = NumberFormat.lowercaseLetter
        XCTAssertEqual(format.symbol(for: 0, adornment: .period, level: 1), "a.")
        XCTAssertEqual(format.symbol(for: 1, adornment: .period, level: 1), "b.")
        XCTAssertEqual(format.symbol(for: 2, adornment: .period, level: 1), "c.")
    }
    
    func testHierarchicalNumberFormat_PlainAdornment() {
        let format = NumberFormat.decimal
        let symbol = format.symbol(for: 0, adornment: .plain, level: 0)
        XCTAssertEqual(symbol, "1")
    }
    
    func testHierarchicalNumberFormat_CombinedParentChild() {
        // Simulate how NumberingLayoutManager builds "1.a" etc.
        let parentFormat = NumberFormat.decimal
        let childFormat = NumberFormat.lowercaseLetter
        let adornment = NumberingAdornment.period
        
        let parentSymbol = parentFormat.symbol(for: 0, adornment: .plain, level: 0)  // "1"
        let childSymbol = childFormat.symbol(for: 0, adornment: .plain, level: 1)    // "a"
        let combined = adornment.apply(to: "\(parentSymbol).\(childSymbol)")          // "1.a."
        
        XCTAssertEqual(combined, "1.a.")
    }
    
    func testHierarchicalNumberFormat_SecondChildItem() {
        let parentFormat = NumberFormat.decimal
        let childFormat = NumberFormat.lowercaseLetter
        let adornment = NumberingAdornment.period
        
        let parentSymbol = parentFormat.symbol(for: 1, adornment: .plain, level: 0)  // "2"
        let childSymbol = childFormat.symbol(for: 2, adornment: .plain, level: 1)    // "c"
        let combined = adornment.apply(to: "\(parentSymbol).\(childSymbol)")          // "2.c."
        
        XCTAssertEqual(combined, "2.c.")
    }
    
    func testHierarchicalNumberFormat_ThirdLevel() {
        let level1Format = NumberFormat.decimal
        let level2Format = NumberFormat.lowercaseLetter
        let level3Format = NumberFormat.lowercaseRoman
        let adornment = NumberingAdornment.period
        
        // Build "1.a.i." (level 3 under level 2 under level 1)
        _ = level1Format.symbol(for: 0, adornment: .plain, level: 0)  // "1" (used by grandparent chain)
        let level2Symbol = level2Format.symbol(for: 0, adornment: .plain, level: 1)  // "a"
        
        // NumberingLayoutManager builds parent prefix as "parentSymbol.childSymbol"
        // For level 3, parent is level 2 whose parent prefix is "1.a"
        // So level 3 renders as adornment.apply(to: "a.i") with "1" from grandparent
        let level3Symbol = level3Format.symbol(for: 0, adornment: .plain, level: 2)  // "i"
        
        // The layout manager builds it as: parent chain gives "a", grandparent gives "1"
        // Actually for level 3, parentStyleName = "list-numbered-level-2"
        // and level 2's parentStyleName = "list-numbered"
        // The layout manager only looks one level up, so level 3 gets "a.i."
        let combined = adornment.apply(to: "\(level2Symbol).\(level3Symbol)")
        XCTAssertEqual(combined, "a.i.")
    }
    
    // MARK: - Bullet Style Tests
    
    func testBulletStylesHaveCorrectSymbols() {
        let format = NumberFormat.bulletSymbols
        
        XCTAssertEqual(format.symbol(for: 0, adornment: .plain, level: 0), "•")
        XCTAssertEqual(format.symbol(for: 0, adornment: .plain, level: 1), "◦")
        XCTAssertEqual(format.symbol(for: 0, adornment: .plain, level: 2), "▪")
    }
    
    func testBulletStylesAreSameForAllItems() {
        let format = NumberFormat.bulletSymbols
        
        // All items at the same level get the same bullet
        XCTAssertEqual(format.symbol(for: 0, adornment: .plain, level: 0),
                       format.symbol(for: 5, adornment: .plain, level: 0))
        XCTAssertEqual(format.symbol(for: 0, adornment: .plain, level: 1),
                       format.symbol(for: 3, adornment: .plain, level: 1))
    }
    
    // MARK: - NumberingAdornment Tests
    
    func testAdornmentApply() {
        XCTAssertEqual(NumberingAdornment.plain.apply(to: "1"), "1")
        XCTAssertEqual(NumberingAdornment.period.apply(to: "1"), "1.")
        XCTAssertEqual(NumberingAdornment.parentheses.apply(to: "1"), "(1)")
        XCTAssertEqual(NumberingAdornment.rightParen.apply(to: "1"), "1)")
    }
    
    func testAdornmentApplyToHierarchical() {
        // Hierarchical numbers like "1.a" should get adornment applied to the whole thing
        XCTAssertEqual(NumberingAdornment.period.apply(to: "1.a"), "1.a.")
        XCTAssertEqual(NumberingAdornment.parentheses.apply(to: "1.a"), "(1.a)")
        XCTAssertEqual(NumberingAdornment.plain.apply(to: "1.a"), "1.a")
    }
    
    // MARK: - ZWS (Zero-Width Space) Anchor Tests
    
    /// Verify that a ZWS character preserves list style attributes when used as
    /// a paragraph anchor (the fix for list number clipping on Enter)
    func testZWSPreservesListStyleAttributes() {
        let stylesheet = createStyleSheetWithListStyles()
        let level2 = stylesheet.style(named: "list-numbered-level-2")!
        let attrs = level2.generateAttributes()
        
        // Create "\n" + ZWS with list style attrs (mimics Enter handler)
        let newlineAttrs = attrs
        let zwsAttrs = attrs
        
        let text = NSMutableAttributedString(string: "Previous line")
        text.addAttributes(stylesheet.style(named: "list-numbered")!.generateAttributes(),
                          range: NSRange(location: 0, length: text.length))
        
        // Append newline + ZWS with level 2 attrs
        let newline = NSAttributedString(string: "\n", attributes: newlineAttrs)
        let zws = NSAttributedString(string: "\u{200B}", attributes: zwsAttrs)
        text.append(newline)
        text.append(zws)
        
        // Verify ZWS has the correct level 2 style
        let zwsIndex = text.length - 1
        let zwsTextStyle = text.attribute(.textStyle, at: zwsIndex, effectiveRange: nil) as? String
        XCTAssertEqual(zwsTextStyle, "list-numbered-level-2",
                       "ZWS should carry the list-numbered-level-2 style")
        
        let zwsParagraph = text.attribute(.paragraphStyle, at: zwsIndex, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(zwsParagraph?.headIndent, 72.0,
                       "ZWS should carry the level 2 headIndent")
    }
    
    /// Verify that overwriting a ZWS paragraph's attributes with a new level
    /// correctly updates the textStyle (simulates increaseListIndent on ZWS paragraph)
    func testZWSAttributeOverwrite_SimulatesIndentChange() {
        let stylesheet = createStyleSheetWithListStyles()
        
        // Create text with newline + ZWS at level 1
        let level1Attrs = stylesheet.style(named: "list-numbered")!.generateAttributes()
        let text = NSMutableAttributedString(string: "Item\n\u{200B}", attributes: level1Attrs)
        
        // The ZWS paragraph range
        let nsString = text.string as NSString
        let zwsParagraphRange = nsString.paragraphRange(for: NSRange(location: text.length - 1, length: 0))
        
        // Apply level 2 attributes (simulating increaseListIndent on non-empty paragraph)
        let level2Attrs = stylesheet.style(named: "list-numbered-level-2")!.generateAttributes()
        text.addAttributes(level2Attrs, range: zwsParagraphRange)
        
        // Verify the ZWS now has level 2
        let zwsTextStyle = text.attribute(.textStyle, at: text.length - 1, effectiveRange: nil) as? String
        XCTAssertEqual(zwsTextStyle, "list-numbered-level-2")
    }
    
    // MARK: - Style Resolution for Project-Attached Stylesheet
    
    func testProjectWithListStyleSheet_ResolvesListStyles() throws {
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
        
        let project = Project(name: "Test", type: .prose)
        context.insert(project)
        try context.save()
        
        // Ensure project has a stylesheet
        let _ = StyleSheetService.getStyleSheet(for: project, context: context)
        
        // Resolve list styles
        let numbered = StyleSheetService.resolveStyle(named: "list-numbered", for: project, context: context)
        XCTAssertNotNil(numbered)
        XCTAssertEqual(numbered?.styleCategory, .list)
        XCTAssertEqual(numbered?.numberFormat, .decimal)
        
        let level2 = StyleSheetService.resolveStyle(named: "list-numbered-level-2", for: project, context: context)
        XCTAssertNotNil(level2)
        XCTAssertEqual(level2?.styleCategory, .list)
        XCTAssertEqual(level2?.numberFormat, .lowercaseLetter)
    }
}
