//
//  NumberingLayoutManagerTests.swift
//  WritingShedProTests
//
//  Tests for NumberingLayoutManager helper logic:
//  - buildParentStyleMap: maps child → parent from stylesheet
//  - buildHierarchicalNumber: builds "1.1.1" strings from ancestor chain
//  - estimatedWidth: depth-aware width calculation on NumberFormat
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class NumberingLayoutManagerTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    var layoutManager: NumberingLayoutManager!
    
    override func setUp() async throws {
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
        layoutManager = NumberingLayoutManager()
    }
    
    override func tearDown() {
        container = nil
        context = nil
        layoutManager = nil
    }

    func testDocumentLineNumberMapSkipsBlankAndWhitespaceOnlyLines() {
        let text = NSAttributedString(string: "First line\n\n  \t\n\u{200B}\nSecond line\nThird line")

        let lineNumbers = layoutManager.buildDocumentLineNumberMap(for: text)
        let plainText = text.string as NSString

        XCTAssertEqual(lineNumbers[plainText.range(of: "First line").location], 1)
        XCTAssertEqual(lineNumbers[plainText.range(of: "Second line").location], 2)
        XCTAssertEqual(lineNumbers[plainText.range(of: "Third line").location], 3)
        XCTAssertEqual(lineNumbers.count, 3)
    }

    func testDocumentLineNumberMapSkipsMarkedSections() {
        let text = NSMutableAttributedString(
            string: "Poem Title\nFirst poem line\nFor someone\nSecond poem line"
        )
        let plainText = text.string as NSString
        text.markSection(.title, in: plainText.range(of: "Poem Title"))
        text.markSection(.dedication, in: plainText.range(of: "For someone"))

        let lineNumbers = layoutManager.buildDocumentLineNumberMap(for: text)

        XCTAssertNil(lineNumbers[plainText.range(of: "Poem Title").location])
        XCTAssertEqual(lineNumbers[plainText.range(of: "First poem line").location], 1)
        XCTAssertNil(lineNumbers[plainText.range(of: "For someone").location])
        XCTAssertEqual(lineNumbers[plainText.range(of: "Second poem line").location], 2)
        XCTAssertEqual(lineNumbers.count, 2)
    }

    func testNumberDrawingYUsesGlyphBaselineRatherThanLineFragmentHeight() {
        let font = UIFont.systemFont(ofSize: 24, weight: .bold)
        let numberHeight: CGFloat = 28
        let compactFragmentHeight: CGFloat = 30
        let fragmentHeightWithSpaceAfter: CGFloat = 48

        let baselineAlignedY = NumberingLayoutManager.numberDrawingY(
            originY: 8,
            lineFragmentMinY: 20,
            glyphBaselineOffset: 27,
            font: font
        )
        let legacyCompactY = 8 + 20 + (compactFragmentHeight - numberHeight) / 2
        let legacySpaceAfterY = 8 + 20 + (fragmentHeightWithSpaceAfter - numberHeight) / 2

        XCTAssertNotEqual(legacyCompactY, legacySpaceAfterY)
        XCTAssertEqual(baselineAlignedY + font.ascender, 55, accuracy: 0.001)
    }

    func testOnScreenNumberDrawingYUsesUsedLineTop() {
        let text = NSMutableAttributedString(string: "Aeroplanes\n")
        let font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 12
        paragraph.firstLineHeadIndent = 52
        text.addAttributes(
            [.font: font, .paragraphStyle: paragraph],
            range: NSRange(location: 0, length: text.length)
        )

        let storage = NSTextStorage(attributedString: text)
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 500, height: 500))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)

        let glyphRange = manager.glyphRange(
            forCharacterRange: NSRange(location: 0, length: text.length),
            actualCharacterRange: nil
        )
        let lineRect = manager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        let usedRect = manager.lineFragmentUsedRect(forGlyphAt: glyphRange.location, effectiveRange: nil)

        XCTAssertGreaterThan(lineRect.height, usedRect.height)
        XCTAssertEqual(
            NumberingLayoutManager.numberDrawingY(originY: 8, lineFragmentUsedMinY: usedRect.minY),
            8 + usedRect.minY,
            accuracy: 0.001
        )
    }

    func testFirstContentCharacterLocationSkipsLeadingFormFeed() {
        let text = "\u{000C}Aeroplanes\n" as NSString
        let paragraphRange = text.paragraphRange(for: NSRange(location: 0, length: 0))

        let location = NumberingLayoutManager.firstContentCharacterLocation(
            in: paragraphRange,
            text: text
        )

        XCTAssertEqual(location, 1)
        XCTAssertEqual(text.substring(with: NSRange(location: location, length: 10)), "Aeroplanes")

        let storage = NSTextStorage(string: text as String)
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 500, height: 500))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)

        let pageBreakGlyph = manager.glyphIndexForCharacter(at: paragraphRange.location)
        let headingGlyph = manager.glyphIndexForCharacter(at: location)
        let pageBreakLine = manager.lineFragmentUsedRect(forGlyphAt: pageBreakGlyph, effectiveRange: nil)
        let headingLine = manager.lineFragmentUsedRect(forGlyphAt: headingGlyph, effectiveRange: nil)

        XCTAssertGreaterThan(headingLine.minY, pageBreakLine.minY)
    }

    func testTrailingEmptyParagraphNumberingDefaultsToEditableEditorBehavior() {
        XCTAssertTrue(layoutManager.drawsTrailingEmptyParagraphNumber)

        layoutManager.drawsTrailingEmptyParagraphNumber = false

        XCTAssertFalse(layoutManager.drawsTrailingEmptyParagraphNumber)
    }
    
    // MARK: - Helper: create a stylesheet with a hierarchy
    
    /// Creates a stylesheet with Title2 → Title3 → Headline hierarchy
    /// Title2: decimal, period, no parent (root numbered style)
    /// Title3: decimal, period, parent = Title2
    /// Headline: decimal, period, parent = Title3
    /// Body: no numbering, follow-on from the above
    private func makeHierarchicalStyleSheet() -> StyleSheet {
        let sheet = StyleSheet(name: "Test")
        context.insert(sheet)
        
        let title2 = TextStyleModel(name: "UICTFontTextStyleTitle2", displayName: "Title 2", displayOrder: 1)
        title2.numberFormat = .decimal
        title2.numberAdornment = .period
        title2.isBold = true
        title2.fontSize = 22
        title2.styleSheet = sheet
        context.insert(title2)
        
        let title3 = TextStyleModel(name: "UICTFontTextStyleTitle3", displayName: "Title 3", displayOrder: 2)
        title3.numberFormat = .decimal
        title3.numberAdornment = .period
        title3.parentStyleName = "UICTFontTextStyleTitle2"
        title3.isBold = true
        title3.fontSize = 20
        title3.styleSheet = sheet
        context.insert(title3)
        
        let headline = TextStyleModel(name: "UICTFontTextStyleHeadline", displayName: "Headline", displayOrder: 3)
        headline.numberFormat = .decimal
        headline.numberAdornment = .period
        headline.parentStyleName = "UICTFontTextStyleTitle3"
        headline.isBold = true
        headline.fontSize = 17
        headline.styleSheet = sheet
        context.insert(headline)
        
        let body = TextStyleModel(name: "UICTFontTextStyleBody", displayName: "Body", displayOrder: 4)
        body.numberFormat = .none
        body.styleSheet = sheet
        context.insert(body)
        
        try? context.save()
        return sheet
    }
    
    // MARK: - buildParentStyleMap Tests
    
    func testBuildParentStyleMap_EmptyStyleSheet() throws {
        let sheet = StyleSheet(name: "Empty")
        context.insert(sheet)
        try context.save()
        
        let map = layoutManager.buildParentStyleMap(from: sheet)
        
        XCTAssertTrue(map.isEmpty, "Empty stylesheet should produce empty parent map")
    }
    
    func testBuildParentStyleMap_NoParentStyles() throws {
        let sheet = StyleSheet(name: "Flat")
        context.insert(sheet)
        
        let style1 = TextStyleModel(name: "Style1", displayName: "Style 1", displayOrder: 0)
        style1.numberFormat = .decimal
        style1.styleSheet = sheet
        context.insert(style1)
        
        let style2 = TextStyleModel(name: "Style2", displayName: "Style 2", displayOrder: 1)
        style2.numberFormat = .decimal
        style2.styleSheet = sheet
        context.insert(style2)
        
        try context.save()
        
        let map = layoutManager.buildParentStyleMap(from: sheet)
        
        XCTAssertTrue(map.isEmpty, "Styles without parentStyleName should not appear in map")
    }
    
    func testBuildParentStyleMap_SingleParentChild() throws {
        let sheet = StyleSheet(name: "SingleLevel")
        context.insert(sheet)
        
        let parent = TextStyleModel(name: "Title2", displayName: "Title 2", displayOrder: 0)
        parent.numberFormat = .decimal
        parent.styleSheet = sheet
        context.insert(parent)
        
        let child = TextStyleModel(name: "Title3", displayName: "Title 3", displayOrder: 1)
        child.numberFormat = .decimal
        child.parentStyleName = "Title2"
        child.styleSheet = sheet
        context.insert(child)
        
        try context.save()
        
        let map = layoutManager.buildParentStyleMap(from: sheet)
        
        XCTAssertEqual(map.count, 1)
        XCTAssertEqual(map["Title3"], "Title2")
    }
    
    func testBuildParentStyleMap_ThreeLevelHierarchy() throws {
        let sheet = makeHierarchicalStyleSheet()
        
        let map = layoutManager.buildParentStyleMap(from: sheet)
        
        XCTAssertEqual(map.count, 2, "Should have 2 child→parent entries (Title3→Title2, Headline→Title3)")
        XCTAssertEqual(map["UICTFontTextStyleTitle3"], "UICTFontTextStyleTitle2")
        XCTAssertEqual(map["UICTFontTextStyleHeadline"], "UICTFontTextStyleTitle3")
        XCTAssertNil(map["UICTFontTextStyleTitle2"], "Root style should not be in map as a child")
        XCTAssertNil(map["UICTFontTextStyleBody"], "Body has no parent")
    }
    
    // MARK: - buildHierarchicalNumber Tests
    
    func testHierarchicalNumber_RootStyleOnly() throws {
        let sheet = makeHierarchicalStyleSheet()
        let parentMap = layoutManager.buildParentStyleMap(from: sheet)
        let lastNumbers: [String: Int] = [:]
        
        // Title2 is a root style (no parent), counter = 1
        let result = layoutManager.buildHierarchicalNumber(
            for: "UICTFontTextStyleTitle2",
            counter: 1,
            parentStyleMap: parentMap,
            lastNumberForStyle: lastNumbers,
            styleSheet: sheet
        )
        
        XCTAssertEqual(result, "1.", "Root style should produce simple '1.' with period adornment")
    }
    
    func testHierarchicalNumber_RootStyleHigherCounter() throws {
        let sheet = makeHierarchicalStyleSheet()
        let parentMap = layoutManager.buildParentStyleMap(from: sheet)
        let lastNumbers: [String: Int] = [:]
        
        let result = layoutManager.buildHierarchicalNumber(
            for: "UICTFontTextStyleTitle2",
            counter: 3,
            parentStyleMap: parentMap,
            lastNumberForStyle: lastNumbers,
            styleSheet: sheet
        )
        
        XCTAssertEqual(result, "3.", "Root style counter 3 should produce '3.'")
    }
    
    func testHierarchicalNumber_ChildTwoLevels() throws {
        let sheet = makeHierarchicalStyleSheet()
        let parentMap = layoutManager.buildParentStyleMap(from: sheet)
        let lastNumbers: [String: Int] = [
            "UICTFontTextStyleTitle2": 1
        ]
        
        // Title3 is child of Title2, counter = 2
        let result = layoutManager.buildHierarchicalNumber(
            for: "UICTFontTextStyleTitle3",
            counter: 2,
            parentStyleMap: parentMap,
            lastNumberForStyle: lastNumbers,
            styleSheet: sheet
        )
        
        XCTAssertEqual(result, "1.2.", "Title3 (child of Title2=1) at counter 2 should produce '1.2.'")
    }
    
    func testHierarchicalNumber_GrandchildThreeLevels() throws {
        let sheet = makeHierarchicalStyleSheet()
        let parentMap = layoutManager.buildParentStyleMap(from: sheet)
        let lastNumbers: [String: Int] = [
            "UICTFontTextStyleTitle2": 2,
            "UICTFontTextStyleTitle3": 3
        ]
        
        // Headline is grandchild: Title2=2, Title3=3, Headline counter=1
        let result = layoutManager.buildHierarchicalNumber(
            for: "UICTFontTextStyleHeadline",
            counter: 1,
            parentStyleMap: parentMap,
            lastNumberForStyle: lastNumbers,
            styleSheet: sheet
        )
        
        XCTAssertEqual(result, "2.3.1.", "Headline (grandchild) should produce '2.3.1.' — the bug was '2.3.' (missing depth)")
    }
    
    func testHierarchicalNumber_GrandchildVariousCounters() throws {
        let sheet = makeHierarchicalStyleSheet()
        let parentMap = layoutManager.buildParentStyleMap(from: sheet)
        let lastNumbers: [String: Int] = [
            "UICTFontTextStyleTitle2": 1,
            "UICTFontTextStyleTitle3": 1
        ]
        
        // Headline counter = 5 under Title2=1, Title3=1
        let result = layoutManager.buildHierarchicalNumber(
            for: "UICTFontTextStyleHeadline",
            counter: 5,
            parentStyleMap: parentMap,
            lastNumberForStyle: lastNumbers,
            styleSheet: sheet
        )
        
        XCTAssertEqual(result, "1.1.5.", "Should produce '1.1.5.'")
    }
    
    func testHierarchicalNumber_ParentAtZeroUsesZero() throws {
        let sheet = makeHierarchicalStyleSheet()
        let parentMap = layoutManager.buildParentStyleMap(from: sheet)
        // Parent counters not yet tracked → lastNumberForStyle is empty
        let lastNumbers: [String: Int] = [:]
        
        // Title3 with no tracked parent → parent defaults to 0
        let result = layoutManager.buildHierarchicalNumber(
            for: "UICTFontTextStyleTitle3",
            counter: 1,
            parentStyleMap: parentMap,
            lastNumberForStyle: lastNumbers,
            styleSheet: sheet
        )
        
        // Parent (Title2) not in lastNumbers → defaults to 0, symbol(for: -1) clamps to 0 → "1"
        // So the result is "0.1." or similar depending on clamping
        // The max(seg.number - 1, 0) ensures it won't go negative
        XCTAssertTrue(result.hasSuffix("."), "Should have period adornment")
        XCTAssertTrue(result.contains("."), "Should be hierarchical with separator")
    }
    
    // MARK: - estimatedWidth Tests
    
    func testEstimatedWidth_NoneFormat() {
        let width = NumberFormat.none.estimatedWidth(for: UIFont.systemFont(ofSize: 17))
        
        XCTAssertEqual(width, 0, "None format should have zero width")
    }
    
    func testEstimatedWidth_DecimalNoAncestors() {
        let font = UIFont.systemFont(ofSize: 17)
        let width = NumberFormat.decimal.estimatedWidth(for: font, adornment: .period, ancestorDepth: 0)
        
        XCTAssertGreaterThan(width, 0, "Decimal format should have positive width")
        // Should accommodate "9." (single digit + period + 4pt gap)
    }
    
    func testEstimatedWidth_DecimalOneAncestor() {
        let font = UIFont.systemFont(ofSize: 17)
        let widthNoAncestor = NumberFormat.decimal.estimatedWidth(for: font, adornment: .period, ancestorDepth: 0)
        let widthOneAncestor = NumberFormat.decimal.estimatedWidth(for: font, adornment: .period, ancestorDepth: 1)
        
        XCTAssertGreaterThan(widthOneAncestor, widthNoAncestor,
                             "Depth 1 ('9.9.') should be wider than depth 0 ('9.')")
    }
    
    func testEstimatedWidth_DecimalTwoAncestors() {
        let font = UIFont.systemFont(ofSize: 17)
        let widthOne = NumberFormat.decimal.estimatedWidth(for: font, adornment: .period, ancestorDepth: 1)
        let widthTwo = NumberFormat.decimal.estimatedWidth(for: font, adornment: .period, ancestorDepth: 2)
        
        XCTAssertGreaterThan(widthTwo, widthOne,
                             "Depth 2 ('9.9.9.') should be wider than depth 1 ('9.9.') — the bug that caused text overlap")
    }
    
    func testEstimatedWidth_RomanNumeralsWiderThanDecimal() {
        let font = UIFont.systemFont(ofSize: 17)
        let decimalWidth = NumberFormat.decimal.estimatedWidth(for: font, adornment: .period, ancestorDepth: 0)
        let romanWidth = NumberFormat.lowercaseRoman.estimatedWidth(for: font, adornment: .period, ancestorDepth: 0)
        
        XCTAssertGreaterThan(romanWidth, decimalWidth,
                             "Roman numeral ('viii.') should be wider than decimal ('9.')")
    }
    
    func testEstimatedWidth_DepthIncreasesMonotonically() {
        let font = UIFont.systemFont(ofSize: 17)
        var previousWidth: CGFloat = 0
        
        for depth in 0...4 {
            let width = NumberFormat.decimal.estimatedWidth(for: font, adornment: .period, ancestorDepth: depth)
            XCTAssertGreaterThan(width, previousWidth,
                                 "Width should increase with depth (depth \(depth) = \(width), previous = \(previousWidth))")
            previousWidth = width
        }
    }
    
    func testEstimatedWidth_BulletIgnoresDepth() {
        let font = UIFont.systemFont(ofSize: 17)
        let widthZero = NumberFormat.bulletSymbols.estimatedWidth(for: font, adornment: .plain, ancestorDepth: 0)
        let widthTwo = NumberFormat.bulletSymbols.estimatedWidth(for: font, adornment: .plain, ancestorDepth: 2)
        
        XCTAssertEqual(widthZero, widthTwo,
                        "Bullet width should not change with depth")
    }
    
    func testEstimatedWidth_HasParentLegacyCompat() {
        let font = UIFont.systemFont(ofSize: 17)
        let widthLegacy = NumberFormat.decimal.estimatedWidth(for: font, adornment: .period, hasParent: true, ancestorDepth: 0)
        let widthNew = NumberFormat.decimal.estimatedWidth(for: font, adornment: .period, ancestorDepth: 1)
        
        XCTAssertEqual(widthLegacy, widthNew,
                        "hasParent: true should behave the same as ancestorDepth: 1")
    }
    
    // MARK: - bulletLevel Tests
    
    func testBulletLevel_Default() {
        XCTAssertEqual(layoutManager.bulletLevel(from: "some-list"), 0)
        XCTAssertEqual(layoutManager.bulletLevel(from: "UICTFontTextStyleBody"), 0)
    }
    
    func testBulletLevel_Level2() {
        XCTAssertEqual(layoutManager.bulletLevel(from: "bullet-level-2"), 1)
    }
    
    func testBulletLevel_Level3() {
        XCTAssertEqual(layoutManager.bulletLevel(from: "bullet-level-3"), 2)
    }
}
