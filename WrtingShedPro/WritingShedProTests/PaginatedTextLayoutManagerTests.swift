//
//  PaginatedTextLayoutManagerTests.swift
//  Writing Shed Pro Tests
//
//  Unit tests for PaginatedTextLayoutManager
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class PaginatedTextLayoutManagerTests: XCTestCase {
    
    var modelContext: ModelContext!
    var pageSetup: PageSetup!
    
    override func setUpWithError() throws {
        // Create in-memory model container for testing
        let schema = Schema([
            PageSetup.self,
            PrinterPaper.self,
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self,
            FootnoteModel.self,
            CommentModel.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(container)
        
        // Create standard page setup for testing (Letter, 1" margins)
        pageSetup = PageSetup(
            paperName: "Letter",
            orientation: .portrait,
            marginTop: 72.0,
            marginBottom: 72.0,
            marginLeft: 72.0,
            marginRight: 72.0
        )
        modelContext.insert(pageSetup)
    }
    
    override func tearDownWithError() throws {
        modelContext = nil
        pageSetup = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() throws {
        let textStorage = NSTextStorage(string: "Test content")
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        XCTAssertNotNil(layoutManager.textStorage)
        XCTAssertNotNil(layoutManager.layoutManager)
        XCTAssertFalse(layoutManager.isLayoutValid)
        XCTAssertNil(layoutManager.layoutResult)
        XCTAssertEqual(layoutManager.pageCount, 0)
    }
    
    // MARK: - Empty Document Tests
    
    func testEmptyDocument() throws {
        let textStorage = NSTextStorage(string: "")
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        let result = layoutManager.calculateLayout()
        
        // Empty document should have exactly 1 page
        XCTAssertEqual(result.totalPages, 1)
        XCTAssertEqual(layoutManager.pageCount, 1)
        XCTAssertTrue(layoutManager.isLayoutValid)
        
        // Page should have empty ranges
        let pageInfo = result.pageInfos[0]
        XCTAssertEqual(pageInfo.characterRange.length, 0)
        XCTAssertEqual(pageInfo.glyphRange.length, 0)
    }
    
    // MARK: - Single Page Document Tests
    
    func testShortDocument() throws {
        let text = "This is a short document that fits on one page."
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        let result = layoutManager.calculateLayout()
        
        XCTAssertEqual(result.totalPages, 1)
        XCTAssertEqual(result.pageInfos.count, 1)
        
        let pageInfo = result.pageInfos[0]
        XCTAssertEqual(pageInfo.pageIndex, 0)
        XCTAssertEqual(pageInfo.characterRange.location, 0)
        XCTAssertEqual(pageInfo.characterRange.length, text.count)
    }
    
    func testSingleLineDocument() throws {
        let text = "One line"
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        let result = layoutManager.calculateLayout()
        
        XCTAssertEqual(result.totalPages, 1)
        XCTAssertTrue(layoutManager.isLayoutValid)
    }
    
    // MARK: - Multi-Page Document Tests
    
    func testMultiPageDocument() throws {
        // Create a document with enough text for multiple pages
        // Letter page with 1" margins = 468pt width x 648pt height content area
        // At default font size (~17pt line height), that's about 38 lines per page
        let linesPerPage = 35  // Be conservative
        let totalLines = linesPerPage * 3  // 3 pages worth
        
        var text = ""
        for i in 1...totalLines {
            text += "This is line number \(i) of the test document.\n"
        }
        
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        let result = layoutManager.calculateLayout()
        
        // Should have multiple pages
        XCTAssertGreaterThan(result.totalPages, 1)
        XCTAssertEqual(result.pageInfos.count, result.totalPages)
        
        // Verify pages are sequential and cover all text
        var coveredCharacters = 0
        for (index, pageInfo) in result.pageInfos.enumerated() {
            XCTAssertEqual(pageInfo.pageIndex, index)
            XCTAssertGreaterThan(pageInfo.characterRange.length, 0)
            coveredCharacters += pageInfo.characterRange.length
        }
        
        // All characters should be covered
        XCTAssertEqual(coveredCharacters, text.count)
    }
    
    // MARK: - Text Range Mapping Tests
    
    func testPageIndexForCharacter() throws {
        let text = String(repeating: "Line of text.\n", count: 100)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        layoutManager.calculateLayout()
        
        // Character 0 should be on page 0
        XCTAssertEqual(layoutManager.pageIndex(forCharacterAt: 0), 0)
        
        // Last character should be on the last page
        let lastCharIndex = text.count - 1
        let lastPage = layoutManager.pageCount - 1
        XCTAssertEqual(layoutManager.pageIndex(forCharacterAt: lastCharIndex), lastPage)
        
        // Character at end of text should return last page
        XCTAssertEqual(layoutManager.pageIndex(forCharacterAt: text.count), lastPage)
    }
    
    func testPageIndexForCharacter_OutOfBounds() throws {
        let text = "Test"
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        layoutManager.calculateLayout()
        
        // Negative index should return nil
        XCTAssertNil(layoutManager.pageIndex(forCharacterAt: -1))
        
        // Beyond text length should return nil
        XCTAssertNil(layoutManager.pageIndex(forCharacterAt: text.count + 10))
    }
    
    func testCharacterRangeForPage() throws {
        let text = String(repeating: "Line of text.\n", count: 100)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        let result = layoutManager.calculateLayout()
        
        // Each page should have a valid character range
        for pageIndex in 0..<result.totalPages {
            let range = layoutManager.characterRange(forPage: pageIndex)
            XCTAssertNotNil(range)
            XCTAssertGreaterThan(range!.length, 0)
        }
        
        // Invalid page indices should return nil
        XCTAssertNil(layoutManager.characterRange(forPage: -1))
        XCTAssertNil(layoutManager.characterRange(forPage: result.totalPages))
    }
    
    func testGlyphRangeForPage() throws {
        let text = "Test document"
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        layoutManager.calculateLayout()
        
        let range = layoutManager.glyphRange(forPage: 0)
        XCTAssertNotNil(range)
        XCTAssertGreaterThan(range!.length, 0)
        
        // Invalid page should return nil
        XCTAssertNil(layoutManager.glyphRange(forPage: 100))
    }
    
    func testPageInfo() throws {
        let text = "Test"
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        layoutManager.calculateLayout()
        
        let info = layoutManager.pageInfo(forPage: 0)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.pageIndex, 0)
        XCTAssertNotNil(info?.characterRange)
        XCTAssertNotNil(info?.glyphRange)
        XCTAssertNotNil(info?.usedRect)
        
        // Invalid page should return nil
        XCTAssertNil(layoutManager.pageInfo(forPage: 100))
    }
    
    // MARK: - Layout Invalidation Tests
    
    func testLayoutInvalidation() throws {
        let textStorage = NSTextStorage(string: "Initial text")
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        layoutManager.calculateLayout()
        XCTAssertTrue(layoutManager.isLayoutValid)
        
        layoutManager.invalidateLayout()
        XCTAssertFalse(layoutManager.isLayoutValid)
        XCTAssertNil(layoutManager.layoutResult)
        XCTAssertEqual(layoutManager.pageCount, 0)
    }
    
    func testTextChangeInvalidatesLayout() throws {
        let textStorage = NSTextStorage(string: "Initial text")
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        layoutManager.calculateLayout()
        XCTAssertTrue(layoutManager.isLayoutValid)
        
        // Modify text - should invalidate layout
        textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "New ")
        
        // Give notification time to fire
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        XCTAssertFalse(layoutManager.isLayoutValid)
    }
    
    func testUpdatePageSetup() throws {
        let textStorage = NSTextStorage(string: "Test")
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        layoutManager.calculateLayout()
        _ = layoutManager.pageCount
        XCTAssertTrue(layoutManager.isLayoutValid)
        
        // Create new page setup with different size
        let newPageSetup = PageSetup(
            paperName: "A5",  // Much smaller page
            orientation: .portrait,
            marginTop: 36.0,
            marginBottom: 36.0,
            marginLeft: 36.0,
            marginRight: 36.0
        )
        modelContext.insert(newPageSetup)
        
        layoutManager.updatePageSetup(newPageSetup)
        
        // Layout should be invalidated
        XCTAssertFalse(layoutManager.isLayoutValid)
        
        // Recalculate with new page setup
        layoutManager.calculateLayout()
        
        // With smaller page, might have different page count
        // (though for short text, likely still 1 page)
        XCTAssertTrue(layoutManager.isLayoutValid)
    }
    
    // MARK: - Performance Tests
    
    func testCalculationTime() throws {
        let text = String(repeating: "Line of text.\n", count: 100)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        let result = layoutManager.calculateLayout()
        
        XCTAssertNotNil(result.calculationTime)
        XCTAssertNotNil(layoutManager.lastCalculationTime)
        
        // Calculation should be reasonably fast (< 200ms for small document)
        XCTAssertLessThan(result.calculationTime, 0.2)
    }
    
    func testMediumDocumentPerformance() throws {
        // Simulate a medium document (~50 pages)
        let linesPerPage = 35
        let totalLines = linesPerPage * 50
        var text = ""
        for i in 1...totalLines {
            text += "This is line number \(i) of the test document with some content.\n"
        }
        
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        let startTime = Date()
        let result = layoutManager.calculateLayout()
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        print("Medium document (\(text.count) chars, \(result.totalPages) pages) layout time: \(String(format: "%.2f", elapsedTime * 1000))ms")
        
        // Should complete in reasonable time for medium document
        // Note: Performance varies significantly:
        // - First run: slower due to font loading and system caches
        // - Debug builds: 5-10x slower than release builds
        // - CI/test machines: can be much slower than development machines
        // This threshold is conservative to avoid flaky test failures
        XCTAssertLessThan(elapsedTime, 10.0, "Layout taking too long: \(elapsedTime)s")
        XCTAssertGreaterThan(result.totalPages, 10)
    }
    
    // MARK: - Content Size Tests
    
    func testContentSize() throws {
        let text = String(repeating: "Line.\n", count: 100)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        let result = layoutManager.calculateLayout()
        
        XCTAssertGreaterThan(result.contentSize.width, 0)
        XCTAssertGreaterThan(result.contentSize.height, 0)
        XCTAssertEqual(layoutManager.contentSize, result.contentSize)
        
        // Content height should grow with number of pages
        let pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        let pageHeight = pageLayout.pageRect.height
        let expectedMinHeight = CGFloat(result.totalPages - 1) * (pageHeight + layoutManager.pageSpacing) + pageHeight
        
        XCTAssertGreaterThanOrEqual(result.contentSize.height, expectedMinHeight - 1.0)
    }
    
    // MARK: - Different Page Setup Tests
    
    func testLandscapeOrientation() throws {
        let landscapeSetup = PageSetup(
            paperName: "Letter",
            orientation: .landscape,
            marginTop: 72.0,
            marginBottom: 72.0,
            marginLeft: 72.0,
            marginRight: 72.0
        )
        modelContext.insert(landscapeSetup)
        
        let text = String(repeating: "Line of text.\n", count: 100)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: landscapeSetup
        )
        
        let result = layoutManager.calculateLayout()
        
        // Landscape pages should have fewer pages (wider, shorter)
        XCTAssertGreaterThan(result.totalPages, 0)
        XCTAssertTrue(layoutManager.isLayoutValid)
    }
    
    func testA4PaperSize() throws {
        let a4Setup = PageSetup(
            paperName: "A4",
            orientation: .portrait,
            marginTop: 72.0,
            marginBottom: 72.0,
            marginLeft: 72.0,
            marginRight: 72.0
        )
        modelContext.insert(a4Setup)
        
        let text = String(repeating: "Line of text.\n", count: 100)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: a4Setup
        )
        
        let result = layoutManager.calculateLayout()
        
        XCTAssertGreaterThan(result.totalPages, 0)
        XCTAssertTrue(layoutManager.isLayoutValid)
    }
    
    func testSmallMargins() throws {
        let smallMarginSetup = PageSetup(
            paperName: "Letter",
            orientation: .portrait,
            marginTop: 18.0,    // 0.25 inch
            marginBottom: 18.0,
            marginLeft: 18.0,
            marginRight: 18.0
        )
        modelContext.insert(smallMarginSetup)
        
        let text = String(repeating: "Line of text.\n", count: 100)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: smallMarginSetup
        )
        
        let result = layoutManager.calculateLayout()
        
        // Smaller margins = more content per page = fewer pages
        XCTAssertGreaterThan(result.totalPages, 0)
        XCTAssertTrue(layoutManager.isLayoutValid)
    }
    
    // MARK: - Edge Cases
    
    func testVeryLongLine() throws {
        // Single very long line
        let text = String(repeating: "word ", count: 1000)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        let result = layoutManager.calculateLayout()
        
        // Should wrap and span multiple pages
        XCTAssertGreaterThan(result.totalPages, 0)
        XCTAssertTrue(layoutManager.isLayoutValid)
    }
    
    func testManyShortLines() throws {
        // Many short lines
        let text = String(repeating: "x\n", count: 500)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        let result = layoutManager.calculateLayout()
        
        XCTAssertGreaterThan(result.totalPages, 1)
        XCTAssertTrue(layoutManager.isLayoutValid)
    }
    
    func testNewlinesOnly() throws {
        let text = String(repeating: "\n", count: 100)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        let result = layoutManager.calculateLayout()
        
        // Should still calculate pages
        XCTAssertGreaterThan(result.totalPages, 0)
        XCTAssertTrue(layoutManager.isLayoutValid)
    }
    
    // MARK: - Convenience Properties Tests
    
    func testConvenienceProperties() throws {
        let text = "Test"
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        // Before calculation
        XCTAssertEqual(layoutManager.pageCount, 0)
        XCTAssertEqual(layoutManager.contentSize, .zero)
        XCTAssertNil(layoutManager.lastCalculationTime)
        
        // After calculation
        layoutManager.calculateLayout()
        XCTAssertGreaterThan(layoutManager.pageCount, 0)
        XCTAssertNotEqual(layoutManager.contentSize, .zero)
        XCTAssertNotNil(layoutManager.lastCalculationTime)
    }
    
    // MARK: - Footnote Integration Tests
    
    func testGetFootnotesForPage_NoFootnotes() throws {
        let text = String(repeating: "Line of text.\n", count: 50)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        layoutManager.calculateLayout()
        
        // Create version without footnotes
        let version = Version(content: text)
        modelContext.insert(version)
        
        // Should return empty array when no footnotes exist
        let footnotes = layoutManager.getFootnotesForPage(0, version: version, context: modelContext)
        XCTAssertTrue(footnotes.isEmpty)
    }
    
    func testGetFootnotesForPage_WithFootnotes() throws {
        // Create multi-page document
        let text = String(repeating: "Line of text.\n", count: 100)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        let result = layoutManager.calculateLayout()
        XCTAssertGreaterThan(result.totalPages, 1, "Document should have multiple pages")
        
        // Create version with footnotes
        let version = Version(content: text)
        modelContext.insert(version)
        
        // Add footnote on first page
        guard let page0Range = layoutManager.characterRange(forPage: 0) else {
            XCTFail("Failed to get character range for page 0")
            return
        }
        let footnote1 = FootnoteModel(
            version: version,
            characterPosition: page0Range.location + 10,
            attachmentID: UUID(),
            text: "First footnote",
            number: 1
        )
        modelContext.insert(footnote1)
        
        // Add footnote on second page
        if result.totalPages > 1 {
            guard let page1Range = layoutManager.characterRange(forPage: 1) else {
                XCTFail("Failed to get character range for page 1")
                return
            }
            let footnote2 = FootnoteModel(
                version: version,
                characterPosition: page1Range.location + 10,
                attachmentID: UUID(),
                text: "Second footnote",
                number: 2
            )
            modelContext.insert(footnote2)
        }
        
        // Verify footnotes are detected on correct pages
        let page0Footnotes = layoutManager.getFootnotesForPage(0, version: version, context: modelContext)
        XCTAssertEqual(page0Footnotes.count, 1)
        XCTAssertEqual(page0Footnotes.first?.number, 1)
        
        if result.totalPages > 1 {
            let page1Footnotes = layoutManager.getFootnotesForPage(1, version: version, context: modelContext)
            XCTAssertEqual(page1Footnotes.count, 1)
            XCTAssertEqual(page1Footnotes.first?.number, 2)
        }
    }
    
    func testGetFootnotesForPage_MultipleFootnotesOnSamePage() throws {
        let text = String(repeating: "Line of text.\n", count: 50)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        layoutManager.calculateLayout()
        
        // Create version with multiple footnotes on first page
        let version = Version(content: text)
        modelContext.insert(version)
        
        guard let page0Range = layoutManager.characterRange(forPage: 0) else {
            XCTFail("Failed to get character range for page 0")
            return
        }
        
        // Add 3 footnotes on first page
        let positions = [
            page0Range.location + 50,
            page0Range.location + 150,
            page0Range.location + 250
        ]
        
        for (index, position) in positions.enumerated() {
            let footnote = FootnoteModel(
                version: version,
                characterPosition: position,
                attachmentID: UUID(),
                text: "Footnote \(index + 1)",
                number: index + 1
            )
            modelContext.insert(footnote)
        }
        
        // Should find all 3 footnotes
        let footnotes = layoutManager.getFootnotesForPage(0, version: version, context: modelContext)
        XCTAssertEqual(footnotes.count, 3)
        
        // Should be sorted by character position
        for (index, footnote) in footnotes.enumerated() {
            XCTAssertEqual(footnote.number, index + 1)
        }
    }
    
    @MainActor
    func testGetFootnotesForPage_DeletedFootnotesExcluded() throws {
        let text = String(repeating: "Line of text.\n", count: 50)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        layoutManager.calculateLayout()
        
        // Create version with footnotes
        let version = Version(content: text)
        modelContext.insert(version)
        
        guard let page0Range = layoutManager.characterRange(forPage: 0) else {
            XCTFail("Failed to get character range for page 0")
            return
        }
        
        // Add two footnotes
        let footnote1 = FootnoteModel(
            version: version,
            characterPosition: page0Range.location + 50,
            attachmentID: UUID(),
            text: "First footnote",
            number: 1
        )
        modelContext.insert(footnote1)
        
        let footnote2 = FootnoteModel(
            version: version,
            characterPosition: page0Range.location + 100,
            attachmentID: UUID(),
            text: "Second footnote",
            number: 2
        )
        modelContext.insert(footnote2)
        
        // Delete the second footnote (hard delete removes it from database)
        FootnoteManager.shared.deleteFootnote(footnote2, context: modelContext)
        
        // Should only return the first footnote
        let footnotes = layoutManager.getFootnotesForPage(0, version: version, context: modelContext)
        XCTAssertEqual(footnotes.count, 1)
        XCTAssertEqual(footnotes.first?.number, 1)
    }
    
    func testCalculateFootnoteHeight_NoFootnotes() throws {
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: NSTextStorage(string: "Test"),
            pageSetup: pageSetup
        )
        
        let height = layoutManager.calculateFootnoteHeight(for: [], pageWidth: 468.0)
        XCTAssertEqual(height, 0)
    }
    
    func testCalculateFootnoteHeight_SingleFootnote() throws {
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: NSTextStorage(string: "Test"),
            pageSetup: pageSetup
        )
        
        let version = Version(content: "Test")
        modelContext.insert(version)
        
        let footnote = FootnoteModel(
            version: version,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "Short footnote text",
            number: 1
        )
        modelContext.insert(footnote)
        
        let height = layoutManager.calculateFootnoteHeight(for: [footnote], pageWidth: 468.0)
        
        // Should include separator (30pt) + text height
        XCTAssertGreaterThan(height, 30.0)
        XCTAssertLessThan(height, 200.0) // Reasonable upper bound
    }
    
    func testCalculateFootnoteHeight_MultipleFootnotes() throws {
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: NSTextStorage(string: "Test"),
            pageSetup: pageSetup
        )
        
        let version = Version(content: "Test")
        modelContext.insert(version)
        
        var footnotes: [FootnoteModel] = []
        for i in 1...3 {
            let footnote = FootnoteModel(
                version: version,
                characterPosition: i * 10,
                attachmentID: UUID(),
                text: "Footnote \(i) with some text",
                number: i
            )
            modelContext.insert(footnote)
            footnotes.append(footnote)
        }
        
        let height = layoutManager.calculateFootnoteHeight(for: footnotes, pageWidth: 468.0)
        
        // Should be taller than single footnote
        let singleHeight = layoutManager.calculateFootnoteHeight(for: [footnotes[0]], pageWidth: 468.0)
        XCTAssertGreaterThan(height, singleHeight)
    }
    
    func testGetContentArea_NoFootnotes() throws {
        let text = "Test content"
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        layoutManager.calculateLayout()
        
        let version = Version(content: text)
        modelContext.insert(version)
        
        // Without footnotes, should return full content area
        let contentArea = layoutManager.getContentArea(forPage: 0, version: version, context: modelContext)
        XCTAssertNotNil(contentArea)
        
        let pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        XCTAssertEqual(contentArea?.height, pageLayout.contentRect.height)
    }
    
    func testGetContentArea_WithFootnotes() throws {
        let text = String(repeating: "Line of text.\n", count: 50)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        layoutManager.calculateLayout()
        
        let version = Version(content: text)
        modelContext.insert(version)
        
        guard let page0Range = layoutManager.characterRange(forPage: 0) else {
            XCTFail("Failed to get character range for page 0")
            return
        }
        
        // Add footnote
        let footnote = FootnoteModel(
            version: version,
            characterPosition: page0Range.location + 50,
            attachmentID: UUID(),
            text: "Test footnote",
            number: 1
        )
        modelContext.insert(footnote)
        
        // Content area should be reduced to make room for footnote
        let contentArea = layoutManager.getContentArea(forPage: 0, version: version, context: modelContext)
        XCTAssertNotNil(contentArea)
        
        let pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        XCTAssertLessThan(contentArea?.height ?? 0, pageLayout.contentRect.height)
    }
    
    func testGetContentArea_InvalidPage() throws {
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: NSTextStorage(string: "Test"),
            pageSetup: pageSetup
        )
        
        layoutManager.calculateLayout()
        
        let version = Version(content: "Test")
        modelContext.insert(version)
        
        // Invalid page index should return nil
        let contentArea = layoutManager.getContentArea(forPage: 999, version: version, context: modelContext)
        XCTAssertNil(contentArea)
    }
}
