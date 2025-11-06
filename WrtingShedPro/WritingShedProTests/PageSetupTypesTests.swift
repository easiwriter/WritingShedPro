//
//  PageSetupTypesTests.swift
//  WritingShedProTests
//
//  Tests for PageSetup supporting types (Units, Orientation, PaperSizes)
//

import XCTest
@testable import Writing_Shed_Pro

final class PageSetupTypesTests: XCTestCase {
    
    // MARK: - Units Tests
    
    func testUnitsScaleFactorPoints() throws {
        // Given
        let units = Units.points
        
        // Then
        XCTAssertEqual(units.scaleFactor, 1.33, accuracy: 0.01, "Points scale factor should be 1.33")
    }
    
    func testUnitsScaleFactorMillimetres() throws {
        // Given
        let units = Units.millimetres
        
        // Then
        XCTAssertEqual(units.scaleFactor, 3.7795275591, accuracy: 0.0001, 
                      "Millimetres scale factor should be ~3.78")
    }
    
    func testUnitsScaleFactorInches() throws {
        // Given
        let units = Units.inches
        
        // Then
        XCTAssertEqual(units.scaleFactor, 96.0, "Inches scale factor should be 96.0")
    }
    
    func testUnitsAllCases() throws {
        // Given
        let allUnits = Units.allCases
        
        // Then
        XCTAssertEqual(allUnits.count, 3, "Should have 3 unit types")
        XCTAssertTrue(allUnits.contains(.points), "Should include points")
        XCTAssertTrue(allUnits.contains(.millimetres), "Should include millimetres")
        XCTAssertTrue(allUnits.contains(.inches), "Should include inches")
    }
    
    func testUnitsRawValues() throws {
        // Then
        XCTAssertEqual(Units.points.rawValue, "points")
        XCTAssertEqual(Units.millimetres.rawValue, "millimetres")
        XCTAssertEqual(Units.inches.rawValue, "inches")
    }
    
    func testUnitsCodable() throws {
        // Given
        let units = Units.millimetres
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // When
        let encoded = try encoder.encode(units)
        let decoded = try decoder.decode(Units.self, from: encoded)
        
        // Then
        XCTAssertEqual(decoded, units, "Should encode and decode correctly")
    }
    
    // MARK: - Orientation Tests
    
    func testOrientationRawValues() throws {
        // Then
        XCTAssertEqual(Orientation.portrait.rawValue, 0, "Portrait should be 0")
        XCTAssertEqual(Orientation.landscape.rawValue, 1, "Landscape should be 1")
    }
    
    func testOrientationFromRawValue() throws {
        // When
        let portrait = Orientation(rawValue: 0)
        let landscape = Orientation(rawValue: 1)
        let invalid = Orientation(rawValue: 99)
        
        // Then
        XCTAssertEqual(portrait, .portrait, "0 should create portrait")
        XCTAssertEqual(landscape, .landscape, "1 should create landscape")
        XCTAssertNil(invalid, "Invalid raw value should return nil")
    }
    
    func testOrientationAllCases() throws {
        // Given
        let allOrientations = Orientation.allCases
        
        // Then
        XCTAssertEqual(allOrientations.count, 2, "Should have 2 orientations")
        XCTAssertTrue(allOrientations.contains(.portrait), "Should include portrait")
        XCTAssertTrue(allOrientations.contains(.landscape), "Should include landscape")
    }
    
    func testOrientationCodable() throws {
        // Given
        let orientation = Orientation.landscape
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // When
        let encoded = try encoder.encode(orientation)
        let decoded = try decoder.decode(Orientation.self, from: encoded)
        
        // Then
        XCTAssertEqual(decoded, orientation, "Should encode and decode correctly")
    }
    
    // MARK: - PaperSizes Tests
    
    func testPaperSizesRawValues() throws {
        // Then
        XCTAssertEqual(PaperSizes.Letter.rawValue, "Letter")
        XCTAssertEqual(PaperSizes.Legal.rawValue, "Legal")
        XCTAssertEqual(PaperSizes.A4.rawValue, "A4")
        XCTAssertEqual(PaperSizes.A5.rawValue, "A5")
        XCTAssertEqual(PaperSizes.Custom.rawValue, "Custom")
    }
    
    func testPaperSizesAllCases() throws {
        // Given
        let allSizes = PaperSizes.allCases
        
        // Then
        XCTAssertEqual(allSizes.count, 5, "Should have 5 paper sizes")
        XCTAssertTrue(allSizes.contains(.Letter))
        XCTAssertTrue(allSizes.contains(.Legal))
        XCTAssertTrue(allSizes.contains(.A4))
        XCTAssertTrue(allSizes.contains(.A5))
        XCTAssertTrue(allSizes.contains(.Custom))
    }
    
    func testLetterDimensions() throws {
        // Given
        let letter = PaperSizes.Letter
        
        // Then - Letter is 8.5" x 11" = 612 x 792 points
        XCTAssertEqual(letter.dimensions.width, 612.0, accuracy: 0.1)
        XCTAssertEqual(letter.dimensions.height, 792.0, accuracy: 0.1)
    }
    
    func testLegalDimensions() throws {
        // Given
        let legal = PaperSizes.Legal
        
        // Then - Legal is 8.5" x 14" = 612 x 1008 points
        XCTAssertEqual(legal.dimensions.width, 612.0, accuracy: 0.1)
        XCTAssertEqual(legal.dimensions.height, 1008.0, accuracy: 0.1)
    }
    
    func testA4Dimensions() throws {
        // Given
        let a4 = PaperSizes.A4
        
        // Then - A4 is 210mm x 297mm ≈ 595 x 842 points
        XCTAssertEqual(a4.dimensions.width, 595.0, accuracy: 1.0)
        XCTAssertEqual(a4.dimensions.height, 842.0, accuracy: 1.0)
    }
    
    func testA5Dimensions() throws {
        // Given
        let a5 = PaperSizes.A5
        
        // Then - A5 is 148mm x 210mm ≈ 420 x 595 points
        XCTAssertEqual(a5.dimensions.width, 420.0, accuracy: 1.0)
        XCTAssertEqual(a5.dimensions.height, 595.0, accuracy: 1.0)
    }
    
    func testCustomDimensions() throws {
        // Given
        let custom = PaperSizes.Custom
        
        // Then - Custom defaults to Letter size
        XCTAssertEqual(custom.dimensions.width, 612.0, accuracy: 0.1)
        XCTAssertEqual(custom.dimensions.height, 792.0, accuracy: 0.1)
    }
    
    func testPaperSizeDefaultForRegion() throws {
        // When
        let defaultSize = PaperSizes.defaultForRegion
        
        // Then - Should be either Letter or A4 depending on locale
        let validDefaults: [PaperSizes] = [.Letter, .A4]
        XCTAssertTrue(validDefaults.contains(defaultSize), 
                     "Default should be Letter or A4 based on locale")
        
        // Note: We can't test specific regions without mocking Locale
        // But we can verify the function returns a valid paper size
        XCTAssertNotEqual(defaultSize, .Custom, "Default should not be Custom")
    }
    
    func testPaperSizesCodable() throws {
        // Given
        let paperSize = PaperSizes.A4
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // When
        let encoded = try encoder.encode(paperSize)
        let decoded = try decoder.decode(PaperSizes.self, from: encoded)
        
        // Then
        XCTAssertEqual(decoded, paperSize, "Should encode and decode correctly")
    }
    
    // MARK: - PageSetupDefaults Tests
    
    func testPageSetupDefaultsMargins() throws {
        // Then - All margins should be 1 inch (72 points)
        XCTAssertEqual(PageSetupDefaults.marginTop, 72.0)
        XCTAssertEqual(PageSetupDefaults.marginBottom, 72.0)
        XCTAssertEqual(PageSetupDefaults.marginLeft, 72.0)
        XCTAssertEqual(PageSetupDefaults.marginRight, 72.0)
    }
    
    func testPageSetupDefaultsHeaderFooter() throws {
        // Then - Header and footer should be 0.5 inch (36 points)
        XCTAssertEqual(PageSetupDefaults.headerDepth, 36.0)
        XCTAssertEqual(PageSetupDefaults.footerDepth, 36.0)
    }
    
    func testPageSetupDefaultsScaleFactor() throws {
        // Then - Should default to inches (96.0)
        XCTAssertEqual(PageSetupDefaults.scaleFactorInches, 96.0)
    }
    
    // MARK: - Integration Tests
    
    func testUnitConversionConsistency() throws {
        // Given - 1 inch in different units
        let oneInchInPoints = 72.0
        let pointsScaleFactor = Units.points.scaleFactor
        let inchesScaleFactor = Units.inches.scaleFactor
        
        // Then - Scale factors should maintain consistent conversions
        // Note: These are the scale factors used by the app for unit conversion
        XCTAssertGreaterThan(inchesScaleFactor, pointsScaleFactor, 
                           "Inches scale factor should be larger than points")
        XCTAssertGreaterThan(Units.millimetres.scaleFactor, pointsScaleFactor,
                           "Millimetres scale factor should be larger than points")
    }
    
    func testPaperSizeAspectRatios() throws {
        // Given
        let letter = PaperSizes.Letter
        let a4 = PaperSizes.A4
        
        // When
        let letterRatio = letter.dimensions.width / letter.dimensions.height
        let a4Ratio = a4.dimensions.width / a4.dimensions.height
        
        // Then - Both should be portrait (width < height)
        XCTAssertLessThan(letterRatio, 1.0, "Letter should be portrait")
        XCTAssertLessThan(a4Ratio, 1.0, "A4 should be portrait")
        
        // A4 aspect ratio should be close to 1:√2 ≈ 0.707
        XCTAssertEqual(a4Ratio, 1.0 / sqrt(2.0), accuracy: 0.01, 
                      "A4 should have 1:√2 aspect ratio")
    }
    
    func testDefaultMarginConsistency() throws {
        // Given
        let defaults = PageSetupDefaults.self
        
        // Then - All margins should be equal (1 inch standard)
        XCTAssertEqual(defaults.marginTop, defaults.marginBottom, 
                      "Top and bottom margins should match")
        XCTAssertEqual(defaults.marginLeft, defaults.marginRight,
                      "Left and right margins should match")
        XCTAssertEqual(defaults.marginTop, defaults.marginLeft,
                      "All margins should be equal by default")
    }
    
    func testHeaderFooterDepthConsistency() throws {
        // Given
        let defaults = PageSetupDefaults.self
        
        // Then - Header and footer depths should be equal
        XCTAssertEqual(defaults.headerDepth, defaults.footerDepth,
                      "Header and footer depths should match")
        
        // And should be less than margins
        XCTAssertLessThan(defaults.headerDepth, defaults.marginTop,
                         "Header depth should be less than margin")
    }
}
