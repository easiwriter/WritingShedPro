//
//  PageLayoutCalculatorTests.swift
//  Writing Shed Pro Tests
//
//  Unit tests for PageLayoutCalculator
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class PageLayoutCalculatorTests: XCTestCase {
    
    var modelContext: ModelContext!
    
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
    }
    
    override func tearDownWithError() throws {
        modelContext = nil
    }
    
    // MARK: - Page Rect Tests
    
    func testCalculatePageRect_Letter_Portrait() throws {
        let pageRect = PageLayoutCalculator.calculatePageRect(
            paperSize: .Letter,
            orientation: .portrait
        )
        
        // Letter: 8.5" x 11" = 612 x 792 points
        XCTAssertEqual(pageRect.width, 612.0, accuracy: 0.1)
        XCTAssertEqual(pageRect.height, 792.0, accuracy: 0.1)
        XCTAssertEqual(pageRect.origin.x, 0)
        XCTAssertEqual(pageRect.origin.y, 0)
    }
    
    func testCalculatePageRect_Letter_Landscape() throws {
        let pageRect = PageLayoutCalculator.calculatePageRect(
            paperSize: .Letter,
            orientation: .landscape
        )
        
        // Landscape swaps dimensions: 11" x 8.5" = 792 x 612 points
        XCTAssertEqual(pageRect.width, 792.0, accuracy: 0.1)
        XCTAssertEqual(pageRect.height, 612.0, accuracy: 0.1)
    }
    
    func testCalculatePageRect_A4_Portrait() throws {
        let pageRect = PageLayoutCalculator.calculatePageRect(
            paperSize: .A4,
            orientation: .portrait
        )
        
        // A4: 210mm x 297mm = 595 x 842 points
        XCTAssertEqual(pageRect.width, 595.0, accuracy: 0.1)
        XCTAssertEqual(pageRect.height, 842.0, accuracy: 0.1)
    }
    
    func testCalculatePageRect_A4_Landscape() throws {
        let pageRect = PageLayoutCalculator.calculatePageRect(
            paperSize: .A4,
            orientation: .landscape
        )
        
        // Landscape: 842 x 595 points
        XCTAssertEqual(pageRect.width, 842.0, accuracy: 0.1)
        XCTAssertEqual(pageRect.height, 595.0, accuracy: 0.1)
    }
    
    func testCalculatePageRect_Legal_Portrait() throws {
        let pageRect = PageLayoutCalculator.calculatePageRect(
            paperSize: .Legal,
            orientation: .portrait
        )
        
        // Legal: 8.5" x 14" = 612 x 1008 points
        XCTAssertEqual(pageRect.width, 612.0, accuracy: 0.1)
        XCTAssertEqual(pageRect.height, 1008.0, accuracy: 0.1)
    }
    
    func testCalculatePageRect_A5_Portrait() throws {
        let pageRect = PageLayoutCalculator.calculatePageRect(
            paperSize: .A5,
            orientation: .portrait
        )
        
        // A5: 148mm x 210mm = 420 x 595 points
        XCTAssertEqual(pageRect.width, 420.0, accuracy: 0.1)
        XCTAssertEqual(pageRect.height, 595.0, accuracy: 0.1)
    }
    
    // MARK: - Text Rect Tests
    
    func testCalculateTextRect_WithStandardMargins() throws {
        let pageSetup = PageSetup(
            paperName: "Letter",
            orientation: .portrait,
            marginTop: 72.0,    // 1 inch
            marginBottom: 72.0,
            marginLeft: 72.0,
            marginRight: 72.0
        )
        modelContext.insert(pageSetup)
        
        let pageRect = PageLayoutCalculator.calculatePageRect(
            paperSize: .Letter,
            orientation: .portrait
        )
        let textRect = PageLayoutCalculator.calculateTextRect(
            pageRect: pageRect,
            pageSetup: pageSetup
        )
        
        // Letter is 612 x 792 points
        // With 1" (72pt) margins on all sides:
        // Width: 612 - 72 - 72 = 468
        // Height: 792 - 72 - 72 = 648
        XCTAssertEqual(textRect.width, 468.0, accuracy: 0.1)
        XCTAssertEqual(textRect.height, 648.0, accuracy: 0.1)
        XCTAssertEqual(textRect.origin.x, 72.0, accuracy: 0.1)
        XCTAssertEqual(textRect.origin.y, 72.0, accuracy: 0.1)
    }
    
    func testCalculateTextRect_WithZeroMargins() throws {
        let pageSetup = PageSetup(
            paperName: "Letter",
            orientation: .portrait,
            marginTop: 0,
            marginBottom: 0,
            marginLeft: 0,
            marginRight: 0
        )
        modelContext.insert(pageSetup)
        
        let pageRect = PageLayoutCalculator.calculatePageRect(
            paperSize: .Letter,
            orientation: .portrait
        )
        let textRect = PageLayoutCalculator.calculateTextRect(
            pageRect: pageRect,
            pageSetup: pageSetup
        )
        
        // With zero margins, text rect should equal page rect
        XCTAssertEqual(textRect.width, pageRect.width, accuracy: 0.1)
        XCTAssertEqual(textRect.height, pageRect.height, accuracy: 0.1)
        XCTAssertEqual(textRect.origin.x, 0)
        XCTAssertEqual(textRect.origin.y, 0)
    }
    
    func testCalculateTextRect_WithAsymmetricMargins() throws {
        let pageSetup = PageSetup(
            paperName: "A4",
            orientation: .portrait,
            marginTop: 36.0,    // 0.5 inch
            marginBottom: 72.0,  // 1 inch
            marginLeft: 54.0,    // 0.75 inch
            marginRight: 90.0    // 1.25 inch
        )
        modelContext.insert(pageSetup)
        
        let pageRect = PageLayoutCalculator.calculatePageRect(
            paperSize: .A4,
            orientation: .portrait
        )
        let textRect = PageLayoutCalculator.calculateTextRect(
            pageRect: pageRect,
            pageSetup: pageSetup
        )
        
        // A4 is 595 x 842 points
        // Width: 595 - 54 - 90 = 451
        // Height: 842 - 36 - 72 = 734
        XCTAssertEqual(textRect.width, 451.0, accuracy: 0.1)
        XCTAssertEqual(textRect.height, 734.0, accuracy: 0.1)
        XCTAssertEqual(textRect.origin.x, 54.0, accuracy: 0.1)
        XCTAssertEqual(textRect.origin.y, 36.0, accuracy: 0.1)
    }
    
    // MARK: - Content Rect Tests
    
    func testCalculateContentRect_NoHeadersOrFooters() throws {
        let pageSetup = PageSetup(
            paperName: "Letter",
            orientation: .portrait,
            headers: false,
            footers: false,
            marginTop: 72.0,
            marginBottom: 72.0,
            marginLeft: 72.0,
            marginRight: 72.0
        )
        modelContext.insert(pageSetup)
        
        let pageRect = PageLayoutCalculator.calculatePageRect(
            paperSize: .Letter,
            orientation: .portrait
        )
        let textRect = PageLayoutCalculator.calculateTextRect(
            pageRect: pageRect,
            pageSetup: pageSetup
        )
        let contentRect = PageLayoutCalculator.calculateContentRect(
            textRect: textRect,
            pageSetup: pageSetup
        )
        
        // Without headers/footers, content rect should equal text rect
        XCTAssertEqual(contentRect.width, textRect.width, accuracy: 0.1)
        XCTAssertEqual(contentRect.height, textRect.height, accuracy: 0.1)
        XCTAssertEqual(contentRect.origin.x, textRect.origin.x, accuracy: 0.1)
        XCTAssertEqual(contentRect.origin.y, textRect.origin.y, accuracy: 0.1)
    }
    
    func testCalculateContentRect_WithHeaders() throws {
        let pageSetup = PageSetup(
            paperName: "Letter",
            orientation: .portrait,
            headers: true,
            footers: false,
            marginTop: 72.0,
            marginBottom: 72.0,
            marginLeft: 72.0,
            marginRight: 72.0,
            headerDepth: 36.0   // 0.5 inch
        )
        modelContext.insert(pageSetup)
        
        let pageRect = PageLayoutCalculator.calculatePageRect(
            paperSize: .Letter,
            orientation: .portrait
        )
        let textRect = PageLayoutCalculator.calculateTextRect(
            pageRect: pageRect,
            pageSetup: pageSetup
        )
        let contentRect = PageLayoutCalculator.calculateContentRect(
            textRect: textRect,
            pageSetup: pageSetup
        )
        
        // With 36pt header, content should be:
        // - Moved down 36pt
        // - 36pt shorter
        XCTAssertEqual(contentRect.width, textRect.width, accuracy: 0.1)
        XCTAssertEqual(contentRect.height, textRect.height - 36.0, accuracy: 0.1)
        XCTAssertEqual(contentRect.origin.x, textRect.origin.x, accuracy: 0.1)
        XCTAssertEqual(contentRect.origin.y, textRect.origin.y + 36.0, accuracy: 0.1)
    }
    
    func testCalculateContentRect_WithFooters() throws {
        let pageSetup = PageSetup(
            paperName: "Letter",
            orientation: .portrait,
            headers: false,
            footers: true,
            marginTop: 72.0,
            marginBottom: 72.0,
            marginLeft: 72.0,
            marginRight: 72.0,
            footerDepth: 36.0   // 0.5 inch
        )
        modelContext.insert(pageSetup)
        
        let pageRect = PageLayoutCalculator.calculatePageRect(
            paperSize: .Letter,
            orientation: .portrait
        )
        let textRect = PageLayoutCalculator.calculateTextRect(
            pageRect: pageRect,
            pageSetup: pageSetup
        )
        let contentRect = PageLayoutCalculator.calculateContentRect(
            textRect: textRect,
            pageSetup: pageSetup
        )
        
        // With 36pt footer, content should be:
        // - Same origin
        // - 36pt shorter
        XCTAssertEqual(contentRect.width, textRect.width, accuracy: 0.1)
        XCTAssertEqual(contentRect.height, textRect.height - 36.0, accuracy: 0.1)
        XCTAssertEqual(contentRect.origin.x, textRect.origin.x, accuracy: 0.1)
        XCTAssertEqual(contentRect.origin.y, textRect.origin.y, accuracy: 0.1)
    }
    
    func testCalculateContentRect_WithBothHeadersAndFooters() throws {
        let pageSetup = PageSetup(
            paperName: "Letter",
            orientation: .portrait,
            headers: true,
            footers: true,
            marginTop: 72.0,
            marginBottom: 72.0,
            marginLeft: 72.0,
            marginRight: 72.0,
            headerDepth: 36.0,
            footerDepth: 36.0
        )
        modelContext.insert(pageSetup)
        
        let pageRect = PageLayoutCalculator.calculatePageRect(
            paperSize: .Letter,
            orientation: .portrait
        )
        let textRect = PageLayoutCalculator.calculateTextRect(
            pageRect: pageRect,
            pageSetup: pageSetup
        )
        let contentRect = PageLayoutCalculator.calculateContentRect(
            textRect: textRect,
            pageSetup: pageSetup
        )
        
        // With both 36pt header and footer, content should be:
        // - Moved down 36pt
        // - 72pt shorter total (36 + 36)
        XCTAssertEqual(contentRect.width, textRect.width, accuracy: 0.1)
        XCTAssertEqual(contentRect.height, textRect.height - 72.0, accuracy: 0.1)
        XCTAssertEqual(contentRect.origin.x, textRect.origin.x, accuracy: 0.1)
        XCTAssertEqual(contentRect.origin.y, textRect.origin.y + 36.0, accuracy: 0.1)
    }
    
    // MARK: - Header/Footer Rect Tests
    
    func testCalculateHeaderRect() throws {
        let pageSetup = PageSetup(
            paperName: "Letter",
            orientation: .portrait,
            headers: true,
            marginTop: 72.0,
            marginBottom: 72.0,
            marginLeft: 72.0,
            marginRight: 72.0,
            headerDepth: 36.0
        )
        modelContext.insert(pageSetup)
        
        let pageRect = PageLayoutCalculator.calculatePageRect(
            paperSize: .Letter,
            orientation: .portrait
        )
        let textRect = PageLayoutCalculator.calculateTextRect(
            pageRect: pageRect,
            pageSetup: pageSetup
        )
        let headerRect = PageLayoutCalculator.calculateHeaderRect(
            textRect: textRect,
            pageSetup: pageSetup
        )
        
        // Header should be at top of text rect, full width, 36pt high
        XCTAssertEqual(headerRect.width, textRect.width, accuracy: 0.1)
        XCTAssertEqual(headerRect.height, 36.0, accuracy: 0.1)
        XCTAssertEqual(headerRect.origin.x, textRect.origin.x, accuracy: 0.1)
        XCTAssertEqual(headerRect.origin.y, textRect.origin.y, accuracy: 0.1)
    }
    
    func testCalculateFooterRect() throws {
        let pageSetup = PageSetup(
            paperName: "Letter",
            orientation: .portrait,
            footers: true,
            marginTop: 72.0,
            marginBottom: 72.0,
            marginLeft: 72.0,
            marginRight: 72.0,
            footerDepth: 36.0
        )
        modelContext.insert(pageSetup)
        
        let pageRect = PageLayoutCalculator.calculatePageRect(
            paperSize: .Letter,
            orientation: .portrait
        )
        let textRect = PageLayoutCalculator.calculateTextRect(
            pageRect: pageRect,
            pageSetup: pageSetup
        )
        let footerRect = PageLayoutCalculator.calculateFooterRect(
            textRect: textRect,
            pageSetup: pageSetup
        )
        
        // Footer should be at bottom of text rect, full width, 36pt high
        XCTAssertEqual(footerRect.width, textRect.width, accuracy: 0.1)
        XCTAssertEqual(footerRect.height, 36.0, accuracy: 0.1)
        XCTAssertEqual(footerRect.origin.x, textRect.origin.x, accuracy: 0.1)
        XCTAssertEqual(footerRect.origin.y, textRect.maxY - 36.0, accuracy: 0.1)
    }
    
    // MARK: - Complete Layout Tests
    
    func testCalculateLayout_StandardSetup() throws {
        let pageSetup = PageSetup(
            paperName: "Letter",
            orientation: .portrait,
            headers: true,
            footers: true,
            marginTop: 72.0,
            marginBottom: 72.0,
            marginLeft: 72.0,
            marginRight: 72.0,
            headerDepth: 36.0,
            footerDepth: 36.0
        )
        modelContext.insert(pageSetup)
        
        let layout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        
        XCTAssertEqual(layout.paperSize, .Letter)
        XCTAssertEqual(layout.orientation, .portrait)
        XCTAssertNotNil(layout.headerRect)
        XCTAssertNotNil(layout.footerRect)
        
        // Verify the hierarchy: page > text > content
        XCTAssertGreaterThan(layout.pageRect.width, layout.textRect.width)
        XCTAssertGreaterThan(layout.pageRect.height, layout.textRect.height)
        XCTAssertGreaterThan(layout.textRect.height, layout.contentRect.height)
    }
    
    func testCalculateLayout_MinimalSetup() throws {
        let pageSetup = PageSetup(
            paperName: "A4",
            orientation: .landscape,
            headers: false,
            footers: false,
            marginTop: 0,
            marginBottom: 0,
            marginLeft: 0,
            marginRight: 0
        )
        modelContext.insert(pageSetup)
        
        let layout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        
        XCTAssertEqual(layout.paperSize, .A4)
        XCTAssertEqual(layout.orientation, .landscape)
        XCTAssertNil(layout.headerRect)
        XCTAssertNil(layout.footerRect)
        
        // With no margins or headers/footers, all rects should be equal
        XCTAssertEqual(layout.pageRect.size, layout.textRect.size)
        XCTAssertEqual(layout.textRect.size, layout.contentRect.size)
    }
    
    // MARK: - Convenience Method Tests
    
    func testContentWidth() throws {
        let pageSetup = PageSetup(
            paperName: "Letter",
            orientation: .portrait,
            marginLeft: 72.0,
            marginRight: 72.0
        )
        modelContext.insert(pageSetup)
        
        let width = PageLayoutCalculator.contentWidth(from: pageSetup)
        
        // Letter width (612) - left margin (72) - right margin (72) = 468
        XCTAssertEqual(width, 468.0, accuracy: 0.1)
    }
    
    func testContentHeight() throws {
        let pageSetup = PageSetup(
            paperName: "Letter",
            orientation: .portrait,
            headers: true,
            footers: true,
            marginTop: 72.0,
            marginBottom: 72.0,
            headerDepth: 36.0,
            footerDepth: 36.0
        )
        modelContext.insert(pageSetup)
        
        let height = PageLayoutCalculator.contentHeight(from: pageSetup)
        
        // Letter height (792) - top margin (72) - bottom margin (72) - header (36) - footer (36) = 576
        XCTAssertEqual(height, 576.0, accuracy: 0.1)
    }
    
    func testContentSize() throws {
        let pageSetup = PageSetup(
            paperName: "A4",
            orientation: .portrait,
            marginTop: 72.0,
            marginBottom: 72.0,
            marginLeft: 72.0,
            marginRight: 72.0
        )
        modelContext.insert(pageSetup)
        
        let size = PageLayoutCalculator.contentSize(from: pageSetup)
        
        // A4: 595 x 842
        // With 72pt margins: 451 x 698
        XCTAssertEqual(size.width, 451.0, accuracy: 0.1)
        XCTAssertEqual(size.height, 698.0, accuracy: 0.1)
    }
    
    func testEstimatePageCount() throws {
        let pageSetup = PageSetup(
            paperName: "Letter",
            orientation: .portrait,
            marginTop: 72.0,
            marginBottom: 72.0
        )
        modelContext.insert(pageSetup)
        
        let contentHeight = PageLayoutCalculator.contentHeight(from: pageSetup)
        
        // Test various text heights
        XCTAssertEqual(PageLayoutCalculator.estimatePageCount(textHeight: contentHeight * 0.5, pageSetup: pageSetup), 1)
        XCTAssertEqual(PageLayoutCalculator.estimatePageCount(textHeight: contentHeight, pageSetup: pageSetup), 1)
        XCTAssertEqual(PageLayoutCalculator.estimatePageCount(textHeight: contentHeight * 1.5, pageSetup: pageSetup), 2)
        XCTAssertEqual(PageLayoutCalculator.estimatePageCount(textHeight: contentHeight * 2.5, pageSetup: pageSetup), 3)
        
        // Empty document should always be 1 page
        XCTAssertEqual(PageLayoutCalculator.estimatePageCount(textHeight: 0, pageSetup: pageSetup), 1)
    }
    
    // MARK: - Page Position Tests
    
    func testYPosition_FirstPage() throws {
        let pageSetup = PageSetup(paperName: "Letter", orientation: .portrait)
        modelContext.insert(pageSetup)
        
        let yPos = PageLayoutCalculator.yPosition(forPage: 0, pageSetup: pageSetup)
        
        XCTAssertEqual(yPos, 0)
    }
    
    func testYPosition_SecondPage() throws {
        let pageSetup = PageSetup(paperName: "Letter", orientation: .portrait)
        modelContext.insert(pageSetup)
        
        let yPos = PageLayoutCalculator.yPosition(forPage: 1, pageSetup: pageSetup, pageSpacing: 20)
        
        // Letter height (792) + spacing (20) = 812
        XCTAssertEqual(yPos, 812.0, accuracy: 0.1)
    }
    
    func testPageIndex_AtPageBoundaries() throws {
        let pageSetup = PageSetup(paperName: "Letter", orientation: .portrait)
        modelContext.insert(pageSetup)
        
        XCTAssertEqual(PageLayoutCalculator.pageIndex(at: 0, pageSetup: pageSetup, pageSpacing: 20), 0)
        XCTAssertEqual(PageLayoutCalculator.pageIndex(at: 400, pageSetup: pageSetup, pageSpacing: 20), 0)
        XCTAssertEqual(PageLayoutCalculator.pageIndex(at: 812, pageSetup: pageSetup, pageSpacing: 20), 1)
        XCTAssertEqual(PageLayoutCalculator.pageIndex(at: 1624, pageSetup: pageSetup, pageSpacing: 20), 2)
    }
    
    func testPageIndex_NeverNegative() throws {
        let pageSetup = PageSetup(paperName: "Letter", orientation: .portrait)
        modelContext.insert(pageSetup)
        
        // Even with negative Y, should return 0
        XCTAssertEqual(PageLayoutCalculator.pageIndex(at: -100, pageSetup: pageSetup), 0)
    }
}
