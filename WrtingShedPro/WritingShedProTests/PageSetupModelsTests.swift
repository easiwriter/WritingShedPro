//
//  PageSetupModelsTests.swift
//  WritingShedProTests
//
//  Tests for PageSetup and PrinterPaper models
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class PageSetupModelsTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory container for testing
        let schema = Schema([
            Project.self,
            Folder.self,
            TextFile.self,
            PageSetup.self,
            PrinterPaper.self,
            StyleSheet.self,
            TextStyleModel.self,
            ImageStyle.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - PageSetup Initialization Tests
    
    func testPageSetupDefaultInitialization() throws {
        // Given
        let pageSetup = PageSetup()
        
        // Then
        XCTAssertNotNil(pageSetup.id, "Should have UUID")
        XCTAssertEqual(pageSetup.orientation, 0, "Should default to portrait (0)")
        XCTAssertEqual(pageSetup.headers, 0, "Should default to no headers")
        XCTAssertEqual(pageSetup.footers, 0, "Should default to no footers")
        XCTAssertEqual(pageSetup.facingPages, 0, "Should default to no facing pages")
        XCTAssertEqual(pageSetup.marginTop, PageSetupDefaults.marginTop, "Should have default top margin")
        XCTAssertEqual(pageSetup.marginBottom, PageSetupDefaults.marginBottom, "Should have default bottom margin")
        XCTAssertEqual(pageSetup.marginLeft, PageSetupDefaults.marginLeft, "Should have default left margin")
        XCTAssertEqual(pageSetup.marginRight, PageSetupDefaults.marginRight, "Should have default right margin")
        XCTAssertEqual(pageSetup.headerDepth, PageSetupDefaults.headerDepth, "Should have default header depth")
        XCTAssertEqual(pageSetup.footerDepth, PageSetupDefaults.footerDepth, "Should have default footer depth")
        XCTAssertEqual(pageSetup.scaleFactor, PageSetupDefaults.scaleFactorInches, "Should default to inches scale factor")
        XCTAssertNotNil(pageSetup.paperName, "Should have default paper name")
        XCTAssertEqual(pageSetup.printerPapers?.count, 0, "Should have empty printer papers array")
    }
    
    func testPageSetupDefaultPaperSizeForUSRegion() throws {
        // Given - Simulate US locale
        let pageSetup = PageSetup()
        
        // Then - paperName should be set to region default
        XCTAssertNotNil(pageSetup.paperName, "Should have paper name")
        
        // Note: Actual default depends on system locale
        // In production, US locale gets Letter, others get A4
        let expectedPapers = ["Letter", "A4"]
        XCTAssertTrue(expectedPapers.contains(pageSetup.paperName ?? ""), 
                     "Should be either Letter or A4 based on locale")
    }
    
    func testPageSetupCustomInitialization() throws {
        // Given
        let customMarginTop = 100.0
        let customMarginLeft = 80.0
        
        // When
        let pageSetup = PageSetup(
            paperName: "Legal",
            orientation: .landscape,
            headers: true,
            footers: true,
            facingPages: true,
            marginTop: customMarginTop,
            marginLeft: customMarginLeft,
            scaleFactor: Units.millimetres.scaleFactor
        )
        
        // Then
        XCTAssertEqual(pageSetup.paperName, "Legal")
        XCTAssertEqual(pageSetup.orientation, 1, "Landscape should be 1")
        XCTAssertEqual(pageSetup.headers, 1, "Headers enabled should be 1")
        XCTAssertEqual(pageSetup.footers, 1, "Footers enabled should be 1")
        XCTAssertEqual(pageSetup.facingPages, 1, "Facing pages enabled should be 1")
        XCTAssertEqual(pageSetup.marginTop, customMarginTop)
        XCTAssertEqual(pageSetup.marginLeft, customMarginLeft)
        XCTAssertEqual(pageSetup.scaleFactor, Units.millimetres.scaleFactor)
    }
    
    // MARK: - Computed Properties Tests
    
    func testOrientationEnumConversion() throws {
        // Given
        let pageSetup = PageSetup()
        
        // When - Set to landscape using enum
        pageSetup.orientationEnum = .landscape
        
        // Then
        XCTAssertEqual(pageSetup.orientation, 1, "Landscape raw value should be 1")
        XCTAssertEqual(pageSetup.orientationEnum, .landscape, "Should return landscape enum")
        
        // When - Set to portrait using enum
        pageSetup.orientationEnum = .portrait
        
        // Then
        XCTAssertEqual(pageSetup.orientation, 0, "Portrait raw value should be 0")
        XCTAssertEqual(pageSetup.orientationEnum, .portrait, "Should return portrait enum")
    }
    
    func testHeadersComputedProperty() throws {
        // Given
        let pageSetup = PageSetup()
        
        // When
        pageSetup.hasHeaders = true
        
        // Then
        XCTAssertEqual(pageSetup.headers, 1, "hasHeaders=true should set headers to 1")
        XCTAssertTrue(pageSetup.hasHeaders, "hasHeaders should return true")
        
        // When
        pageSetup.hasHeaders = false
        
        // Then
        XCTAssertEqual(pageSetup.headers, 0, "hasHeaders=false should set headers to 0")
        XCTAssertFalse(pageSetup.hasHeaders, "hasHeaders should return false")
    }
    
    func testFootersComputedProperty() throws {
        // Given
        let pageSetup = PageSetup()
        
        // When
        pageSetup.hasFooters = true
        
        // Then
        XCTAssertEqual(pageSetup.footers, 1, "hasFooters=true should set footers to 1")
        XCTAssertTrue(pageSetup.hasFooters, "hasFooters should return true")
        
        // When
        pageSetup.hasFooters = false
        
        // Then
        XCTAssertEqual(pageSetup.footers, 0, "hasFooters=false should set footers to 0")
        XCTAssertFalse(pageSetup.hasFooters, "hasFooters should return false")
    }
    
    func testFacingPagesComputedProperty() throws {
        // Given
        let pageSetup = PageSetup()
        
        // When
        pageSetup.hasFacingPages = true
        
        // Then
        XCTAssertEqual(pageSetup.facingPages, 1, "hasFacingPages=true should set facingPages to 1")
        XCTAssertTrue(pageSetup.hasFacingPages, "hasFacingPages should return true")
        
        // When
        pageSetup.hasFacingPages = false
        
        // Then
        XCTAssertEqual(pageSetup.facingPages, 0, "hasFacingPages=false should set facingPages to 0")
        XCTAssertFalse(pageSetup.hasFacingPages, "hasFacingPages should return false")
    }
    
    func testPaperSizeEnumConversion() throws {
        // Given
        let pageSetup = PageSetup()
        
        // When
        pageSetup.paperSize = .A4
        
        // Then
        XCTAssertEqual(pageSetup.paperName, "A4", "Should set paperName to A4")
        XCTAssertEqual(pageSetup.paperSize, .A4, "Should return A4 enum")
        
        // When
        pageSetup.paperSize = .Legal
        
        // Then
        XCTAssertEqual(pageSetup.paperName, "Legal", "Should set paperName to Legal")
        XCTAssertEqual(pageSetup.paperSize, .Legal, "Should return Legal enum")
    }
    
    func testPaperSizeWithInvalidName() throws {
        // Given
        let pageSetup = PageSetup()
        pageSetup.paperName = "InvalidPaper"
        
        // When
        let paperSize = pageSetup.paperSize
        
        // Then - Should return default for region
        let expectedDefault = PaperSizes.defaultForRegion
        XCTAssertEqual(paperSize, expectedDefault, "Invalid paper name should return region default")
    }
    
    // MARK: - PrinterPaper Tests
    
    func testPrinterPaperDefaultInitialization() throws {
        // Given
        let printerPaper = PrinterPaper()
        
        // Then
        XCTAssertNotNil(printerPaper.id, "Should have UUID")
        XCTAssertNil(printerPaper.paperName, "Should default to nil")
        XCTAssertEqual(printerPaper.sizeH, 0.0, "Should default to 0")
        XCTAssertEqual(printerPaper.sizeV, 0.0, "Should default to 0")
        XCTAssertEqual(printerPaper.rectH, 0.0, "Should default to 0")
        XCTAssertEqual(printerPaper.rectV, 0.0, "Should default to 0")
        XCTAssertEqual(printerPaper.scalefactor, 96.0, "Should default to inches scale factor")
        XCTAssertNil(printerPaper.pageSetup, "Should have no page setup relationship")
    }
    
    func testPrinterPaperCustomInitialization() throws {
        // Given
        let paperName = "Letter"
        let sizeH = 612.0
        let sizeV = 792.0
        let rectH = 576.0  // With margins
        let rectV = 720.0  // With margins
        let scaleFactor = Units.millimetres.scaleFactor
        
        // When
        let printerPaper = PrinterPaper(
            paperName: paperName,
            sizeH: sizeH,
            sizeV: sizeV,
            rectH: rectH,
            rectV: rectV,
            scalefactor: scaleFactor
        )
        
        // Then
        XCTAssertEqual(printerPaper.paperName, paperName)
        XCTAssertEqual(printerPaper.sizeH, sizeH)
        XCTAssertEqual(printerPaper.sizeV, sizeV)
        XCTAssertEqual(printerPaper.rectH, rectH)
        XCTAssertEqual(printerPaper.rectV, rectV)
        XCTAssertEqual(printerPaper.scalefactor, scaleFactor)
    }
    
    // MARK: - Relationship Tests
    
    func testPageSetupProjectRelationship() throws {
        // Given
        let project = Project(name: "Test Project", type: .blank)
        let pageSetup = PageSetup()
        
        // When
        modelContext.insert(project)
        modelContext.insert(pageSetup)
        project.pageSetup = pageSetup
        
        // Then
        XCTAssertEqual(pageSetup.project?.id, project.id, "PageSetup should reference project")
        XCTAssertEqual(project.pageSetup?.id, pageSetup.id, "Project should reference pageSetup")
    }
    
    func testPageSetupPrinterPapersRelationship() throws {
        // Given
        let pageSetup = PageSetup()
        let printerPaper1 = PrinterPaper(paperName: "Letter")
        let printerPaper2 = PrinterPaper(paperName: "Legal")
        
        // When
        modelContext.insert(pageSetup)
        modelContext.insert(printerPaper1)
        modelContext.insert(printerPaper2)
        
        printerPaper1.pageSetup = pageSetup
        printerPaper2.pageSetup = pageSetup
        
        // Then
        XCTAssertEqual(printerPaper1.pageSetup?.id, pageSetup.id, "PrinterPaper should reference pageSetup")
        XCTAssertEqual(printerPaper2.pageSetup?.id, pageSetup.id, "PrinterPaper should reference pageSetup")
    }
    
    // MARK: - Margin Tests
    
    func testDefaultMargins() throws {
        // Given
        let pageSetup = PageSetup()
        
        // Then - All margins should be 1 inch (72 points)
        XCTAssertEqual(pageSetup.marginTop, 72.0)
        XCTAssertEqual(pageSetup.marginBottom, 72.0)
        XCTAssertEqual(pageSetup.marginLeft, 72.0)
        XCTAssertEqual(pageSetup.marginRight, 72.0)
    }
    
    func testCustomMargins() throws {
        // Given
        let customTop = 36.0     // 0.5 inch
        let customBottom = 54.0  // 0.75 inch
        let customLeft = 90.0    // 1.25 inch
        let customRight = 108.0  // 1.5 inch
        
        // When
        let pageSetup = PageSetup(
            marginTop: customTop,
            marginBottom: customBottom,
            marginLeft: customLeft,
            marginRight: customRight
        )
        
        // Then
        XCTAssertEqual(pageSetup.marginTop, customTop)
        XCTAssertEqual(pageSetup.marginBottom, customBottom)
        XCTAssertEqual(pageSetup.marginLeft, customLeft)
        XCTAssertEqual(pageSetup.marginRight, customRight)
    }
    
    func testHeaderFooterDepths() throws {
        // Given
        let pageSetup = PageSetup()
        
        // Then - Default depths should be 0.5 inch (36 points)
        XCTAssertEqual(pageSetup.headerDepth, 36.0)
        XCTAssertEqual(pageSetup.footerDepth, 36.0)
    }
    
    func testCustomHeaderFooterDepths() throws {
        // Given
        let customHeaderDepth = 48.0  // 0.67 inch
        let customFooterDepth = 60.0  // 0.83 inch
        
        // When
        let pageSetup = PageSetup(
            headerDepth: customHeaderDepth,
            footerDepth: customFooterDepth
        )
        
        // Then
        XCTAssertEqual(pageSetup.headerDepth, customHeaderDepth)
        XCTAssertEqual(pageSetup.footerDepth, customFooterDepth)
    }
}
