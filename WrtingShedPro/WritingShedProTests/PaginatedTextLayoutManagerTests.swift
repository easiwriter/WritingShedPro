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
            Version.self
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
        let initialPageCount = layoutManager.pageCount
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
        
        // Should complete in reasonable time (< 1 second for medium document)
        // Note: First run may be slower due to font loading and system caches
        XCTAssertLessThan(elapsedTime, 1.0)
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
}
