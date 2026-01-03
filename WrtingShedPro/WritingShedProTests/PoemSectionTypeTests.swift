//
//  PoemSectionTypeTests.swift
//  WritingShedProTests
//
//  Tests for poem section type attribute and poem body extraction
//

import XCTest
@testable import Writing_Shed_Pro

final class PoemSectionTypeTests: XCTestCase {
    
    // MARK: - PoemSectionType Enum Tests
    
    func testSectionTypeIsAnalyzed() {
        XCTAssertTrue(PoemSectionType.poem.isAnalyzed)
        XCTAssertFalse(PoemSectionType.title.isAnalyzed)
        XCTAssertFalse(PoemSectionType.epigraph.isAnalyzed)
        XCTAssertFalse(PoemSectionType.signature.isAnalyzed)
        XCTAssertFalse(PoemSectionType.stanzaNumber.isAnalyzed)
        XCTAssertFalse(PoemSectionType.dedication.isAnalyzed)
    }
    
    func testSectionTypeDisplayName() {
        XCTAssertFalse(PoemSectionType.title.displayName.isEmpty)
        XCTAssertFalse(PoemSectionType.poem.displayName.isEmpty)
    }
    
    func testSectionTypeIconName() {
        for sectionType in PoemSectionType.allCases {
            XCTAssertFalse(sectionType.iconName.isEmpty, "Icon name should not be empty for \(sectionType)")
        }
    }
    
    // MARK: - NSAttributedString Extension Tests
    
    func testExtractPoemBodyWithNoSectionMarkers() {
        // All text should be treated as poem when no markers
        let text = "Roses are red\nViolets are blue"
        let attrString = NSAttributedString(string: text)
        
        let poemBody = attrString.extractPoemBody()
        XCTAssertEqual(poemBody, text)
    }
    
    func testExtractPoemBodyExcludesTitle() {
        let mutableString = NSMutableAttributedString(string: "My Poem Title\nFirst line of poem")
        
        // Mark first line as title
        mutableString.markSection(.title, in: NSRange(location: 0, length: 13))
        
        let poemBody = mutableString.extractPoemBody()
        
        // Should only contain the poem line (with newline)
        XCTAssertEqual(poemBody, "\nFirst line of poem")
    }
    
    func testExtractPoemBodyExcludesMultipleSections() {
        let text = "Title Here\nAn epigraph\nFirst poem line\nSecond poem line\n- Author"
        let mutableString = NSMutableAttributedString(string: text)
        
        // Mark title (characters 0-10)
        mutableString.markSection(.title, in: NSRange(location: 0, length: 10))
        
        // Mark epigraph (characters 11-22: "\nAn epigraph")
        mutableString.markSection(.epigraph, in: NSRange(location: 10, length: 12))
        
        // Mark signature (the "- Author" part at the end)
        let authorStart = text.count - 8 // "- Author" is 8 chars
        mutableString.markSection(.signature, in: NSRange(location: authorStart, length: 8))
        
        let poemBody = mutableString.extractPoemBody()
        
        // Should only contain the poem lines
        XCTAssertTrue(poemBody.contains("First poem line"))
        XCTAssertTrue(poemBody.contains("Second poem line"))
        XCTAssertFalse(poemBody.contains("Title Here"))
        XCTAssertFalse(poemBody.contains("An epigraph"))
        XCTAssertFalse(poemBody.contains("Author"))
    }
    
    func testSectionTypeAtLocation() {
        let mutableString = NSMutableAttributedString(string: "Title\nPoem line")
        mutableString.markSection(.title, in: NSRange(location: 0, length: 5))
        
        XCTAssertEqual(mutableString.sectionType(at: 0), .title)
        XCTAssertEqual(mutableString.sectionType(at: 2), .title)
        XCTAssertEqual(mutableString.sectionType(at: 6), .poem) // After title, in poem section
        XCTAssertEqual(mutableString.sectionType(at: 10), .poem)
    }
    
    func testSectionTypeAtInvalidLocation() {
        let attrString = NSAttributedString(string: "Short")
        
        // Out of bounds should return .poem (default)
        XCTAssertEqual(attrString.sectionType(at: -1), .poem)
        XCTAssertEqual(attrString.sectionType(at: 100), .poem)
    }
    
    func testMarkSectionAsPoemClearsAttribute() {
        let mutableString = NSMutableAttributedString(string: "Some text")
        
        // First mark as title
        mutableString.markSection(.title, in: NSRange(location: 0, length: 9))
        XCTAssertEqual(mutableString.sectionType(at: 0), .title)
        
        // Then mark as poem (should clear)
        mutableString.markSection(.poem, in: NSRange(location: 0, length: 9))
        XCTAssertEqual(mutableString.sectionType(at: 0), .poem)
    }
    
    func testExtendToLinesBoundaries() {
        let text = "Line one\nLine two\nLine three"
        let mutableString = NSMutableAttributedString(string: text)
        
        // Select part of "Line two"
        let partialRange = NSRange(location: 12, length: 3) // "two"
        let extended = mutableString.extendToLinesBoundaries(partialRange)
        
        // Should extend to cover entire "Line two\n"
        XCTAssertEqual(extended.location, 9) // Start of "Line two"
        XCTAssertEqual(NSMaxRange(extended), 18) // End of "Line two\n"
    }
    
    func testHasNonPoemSections() {
        let mutableString = NSMutableAttributedString(string: "Title\nPoem")
        mutableString.markSection(.title, in: NSRange(location: 0, length: 5))
        
        XCTAssertTrue(mutableString.hasNonPoemSections(in: NSRange(location: 0, length: 5)))
        XCTAssertFalse(mutableString.hasNonPoemSections(in: NSRange(location: 6, length: 4)))
    }
    
    // MARK: - Serialization Tests
    
    func testPoemSectionTypeSerializationRoundTrip() {
        let mutableString = NSMutableAttributedString(string: "Title\nPoem line\nSignature")
        mutableString.markSection(.title, in: NSRange(location: 0, length: 5))
        mutableString.markSection(.signature, in: NSRange(location: 16, length: 9))
        
        // Serialize
        let data = AttributedStringSerializer.encode(mutableString)
        
        // Deserialize
        let restored = AttributedStringSerializer.decode(data, text: mutableString.string)
        
        // Check section types preserved
        XCTAssertEqual(restored.sectionType(at: 0), .title)
        XCTAssertEqual(restored.sectionType(at: 10), .poem)
        XCTAssertEqual(restored.sectionType(at: 18), .signature)
    }
    
    func testExtractPoemBodyAfterSerialization() {
        let mutableString = NSMutableAttributedString(string: "Title\nPoem line")
        mutableString.markSection(.title, in: NSRange(location: 0, length: 5))
        
        // Serialize and deserialize
        let data = AttributedStringSerializer.encode(mutableString)
        let restored = AttributedStringSerializer.decode(data, text: mutableString.string)
        
        // Extract poem body
        let poemBody = restored.extractPoemBody()
        
        XCTAssertEqual(poemBody, "\nPoem line")
    }
}
