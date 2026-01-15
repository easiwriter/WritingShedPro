//
//  NSAttributedStringReferencesTests.swift
//  WritingShedProTests
//
//  Unit tests for Feature 029: NSAttributedString+References extension
//  Tests reference marker storage and retrieval in attributed strings
//

import XCTest
import UIKit
@testable import Writing_Shed_Pro

final class NSAttributedStringReferencesTests: XCTestCase {
    
    // MARK: - Custom Attribute Key Tests
    
    func testReferenceTypeAttributeKeyExists() {
        let key = NSAttributedString.Key.referenceType
        XCTAssertEqual(key.rawValue, "com.writingshed.referenceType")
    }
    
    func testReferenceIDAttributeKeyExists() {
        let key = NSAttributedString.Key.referenceID
        XCTAssertEqual(key.rawValue, "com.writingshed.referenceID")
    }
    
    // MARK: - ReferenceMarkerInfo Tests
    
    func testReferenceMarkerInfoInitialization() {
        let entryID = UUID()
        let range = NSRange(location: 10, length: 5)
        
        let info = ReferenceMarkerInfo(
            type: .note,
            entryID: entryID,
            range: range,
            markerText: "[Note 1]"
        )
        
        XCTAssertNotNil(info.id)
        XCTAssertEqual(info.type, .note)
        XCTAssertEqual(info.entryID, entryID)
        XCTAssertEqual(info.range, range)
        XCTAssertEqual(info.markerText, "[Note 1]")
    }
    
    func testReferenceMarkerInfoEquality() {
        let entryID = UUID()
        let range = NSRange(location: 10, length: 5)
        
        let info1 = ReferenceMarkerInfo(type: .note, entryID: entryID, range: range, markerText: "[1]")
        let info2 = ReferenceMarkerInfo(type: .note, entryID: entryID, range: range, markerText: "[1]")
        
        // Should be equal based on entryID and location
        XCTAssertEqual(info1, info2)
    }
    
    func testReferenceMarkerInfoInequality() {
        let entryID1 = UUID()
        let entryID2 = UUID()
        
        let info1 = ReferenceMarkerInfo(type: .note, entryID: entryID1, range: NSRange(location: 10, length: 5), markerText: "[1]")
        let info2 = ReferenceMarkerInfo(type: .note, entryID: entryID2, range: NSRange(location: 10, length: 5), markerText: "[1]")
        
        // Different entryIDs = not equal
        XCTAssertNotEqual(info1, info2)
    }
    
    // MARK: - allReferences Tests
    
    func testAllReferencesOnEmptyString() {
        let attrString = NSAttributedString(string: "")
        let refs = attrString.allReferences()
        
        XCTAssertTrue(refs.isEmpty)
    }
    
    func testAllReferencesWithNoReferences() {
        let attrString = NSAttributedString(string: "This is plain text without any references.")
        let refs = attrString.allReferences()
        
        XCTAssertTrue(refs.isEmpty)
    }
    
    func testAllReferencesWithSingleReference() {
        let entryID = UUID()
        let mutableString = NSMutableAttributedString(string: "Text with a reference marker here.")
        
        // Add reference attributes to "reference"
        let refRange = (mutableString.string as NSString).range(of: "reference")
        mutableString.addAttributes([
            .referenceType: ReferenceType.note.rawValue,
            .referenceID: entryID.uuidString
        ], range: refRange)
        
        let refs = mutableString.allReferences()
        
        XCTAssertEqual(refs.count, 1)
        XCTAssertEqual(refs[0].type, .note)
        XCTAssertEqual(refs[0].entryID, entryID)
        XCTAssertEqual(refs[0].markerText, "reference")
    }
    
    func testAllReferencesWithMultipleReferences() {
        let entryID1 = UUID()
        let entryID2 = UUID()
        let mutableString = NSMutableAttributedString(string: "First note and second citation here.")
        
        // Add note reference
        let noteRange = (mutableString.string as NSString).range(of: "note")
        mutableString.addAttributes([
            .referenceType: ReferenceType.note.rawValue,
            .referenceID: entryID1.uuidString
        ], range: noteRange)
        
        // Add citation reference
        let citationRange = (mutableString.string as NSString).range(of: "citation")
        mutableString.addAttributes([
            .referenceType: ReferenceType.citation.rawValue,
            .referenceID: entryID2.uuidString
        ], range: citationRange)
        
        let refs = mutableString.allReferences()
        
        XCTAssertEqual(refs.count, 2)
        
        // Should be sorted by location
        XCTAssertEqual(refs[0].type, .note)
        XCTAssertEqual(refs[1].type, .citation)
    }
    
    // MARK: - references(in:) Tests
    
    func testReferencesInRangeEmpty() {
        let attrString = NSAttributedString(string: "Plain text")
        let refs = attrString.references(in: NSRange(location: 0, length: 5))
        
        XCTAssertTrue(refs.isEmpty)
    }
    
    func testReferencesInRangeFindsReferenceInRange() {
        let entryID = UUID()
        let mutableString = NSMutableAttributedString(string: "Start [Note 1] End")
        
        // Add reference to "[Note 1]"
        let refRange = (mutableString.string as NSString).range(of: "[Note 1]")
        mutableString.addAttributes([
            .referenceType: ReferenceType.note.rawValue,
            .referenceID: entryID.uuidString
        ], range: refRange)
        
        // Search in a range that includes the reference
        let refs = mutableString.references(in: NSRange(location: 0, length: 14))
        
        XCTAssertEqual(refs.count, 1)
        XCTAssertEqual(refs[0].entryID, entryID)
    }
    
    func testReferencesInRangeExcludesReferenceOutsideRange() {
        let entryID = UUID()
        let mutableString = NSMutableAttributedString(string: "Start [Note 1] End")
        
        // Add reference to "[Note 1]"
        let refRange = (mutableString.string as NSString).range(of: "[Note 1]")
        mutableString.addAttributes([
            .referenceType: ReferenceType.note.rawValue,
            .referenceID: entryID.uuidString
        ], range: refRange)
        
        // Search in range before the reference
        let refs = mutableString.references(in: NSRange(location: 0, length: 5))
        
        XCTAssertTrue(refs.isEmpty)
    }
    
    // MARK: - references(ofType:) Tests
    
    func testReferencesOfTypeFindsMatchingType() {
        let noteID = UUID()
        let citationID = UUID()
        let mutableString = NSMutableAttributedString(string: "[1] and [Smith, 2024]")
        
        // Add endnote
        let endnoteRange = NSRange(location: 0, length: 3)
        mutableString.addAttributes([
            .referenceType: ReferenceType.endnote.rawValue,
            .referenceID: noteID.uuidString
        ], range: endnoteRange)
        
        // Add citation
        let citationRange = NSRange(location: 8, length: 13)
        mutableString.addAttributes([
            .referenceType: ReferenceType.citation.rawValue,
            .referenceID: citationID.uuidString
        ], range: citationRange)
        
        let endnotes = mutableString.references(ofType: .endnote)
        let citations = mutableString.references(ofType: .citation)
        let notes = mutableString.references(ofType: .note)
        
        XCTAssertEqual(endnotes.count, 1)
        XCTAssertEqual(citations.count, 1)
        XCTAssertTrue(notes.isEmpty)
    }
    
    // MARK: - references(toEntry:) Tests
    
    func testReferencesToEntryFindsSameEntry() {
        let targetID = UUID()
        let otherID = UUID()
        let mutableString = NSMutableAttributedString(string: "First [1] and second [1] markers.")
        
        // Add two references to same entry
        mutableString.addAttributes([
            .referenceType: ReferenceType.endnote.rawValue,
            .referenceID: targetID.uuidString
        ], range: NSRange(location: 6, length: 3))
        
        mutableString.addAttributes([
            .referenceType: ReferenceType.endnote.rawValue,
            .referenceID: targetID.uuidString
        ], range: NSRange(location: 21, length: 3))
        
        // Add one reference to different entry
        mutableString.addAttributes([
            .referenceType: ReferenceType.note.rawValue,
            .referenceID: otherID.uuidString
        ], range: NSRange(location: 0, length: 5))
        
        let targetRefs = mutableString.references(toEntry: targetID)
        let otherRefs = mutableString.references(toEntry: otherID)
        
        XCTAssertEqual(targetRefs.count, 2)
        XCTAssertEqual(otherRefs.count, 1)
    }
    
    // MARK: - reference(at:) Tests
    
    func testReferenceAtLocationFindsReference() {
        let entryID = UUID()
        let mutableString = NSMutableAttributedString(string: "Start [Note 1] End")
        
        let refRange = (mutableString.string as NSString).range(of: "[Note 1]")
        mutableString.addAttributes([
            .referenceType: ReferenceType.note.rawValue,
            .referenceID: entryID.uuidString
        ], range: refRange)
        
        // Check inside the reference
        let ref = mutableString.reference(at: refRange.location + 2)
        
        XCTAssertNotNil(ref)
        XCTAssertEqual(ref?.entryID, entryID)
    }
    
    func testReferenceAtLocationReturnsNilOutsideReference() {
        let entryID = UUID()
        let mutableString = NSMutableAttributedString(string: "Start [Note 1] End")
        
        let refRange = (mutableString.string as NSString).range(of: "[Note 1]")
        mutableString.addAttributes([
            .referenceType: ReferenceType.note.rawValue,
            .referenceID: entryID.uuidString
        ], range: refRange)
        
        // Check before the reference
        let ref = mutableString.reference(at: 0)
        
        XCTAssertNil(ref)
    }
    
    func testReferenceAtInvalidLocation() {
        let attrString = NSAttributedString(string: "Short")
        
        let ref1 = attrString.reference(at: -1)
        let ref2 = attrString.reference(at: 100)
        
        XCTAssertNil(ref1)
        XCTAssertNil(ref2)
    }
    
    // MARK: - NSMutableAttributedString Insert Tests
    
    func testInsertReferenceMarker() {
        let entryID = UUID()
        let mutableString = NSMutableAttributedString(string: "Text here.")
        
        // Create a reference marker
        let marker = NSMutableAttributedString(string: "[Note 1]")
        marker.addAttributes([
            .referenceType: ReferenceType.note.rawValue,
            .referenceID: entryID.uuidString
        ], range: NSRange(location: 0, length: marker.length))
        
        // Insert at position 5
        mutableString.insert(marker, at: 5)
        
        XCTAssertTrue(mutableString.string.contains("[Note 1]"))
        
        let refs = mutableString.allReferences()
        XCTAssertEqual(refs.count, 1)
        XCTAssertEqual(refs[0].type, .note)
    }
    
    // MARK: - All Reference Types Detection Tests
    
    func testDetectsAllReferenceTypes() {
        let mutableString = NSMutableAttributedString(string: "note endnote citation glossary index figure table")
        
        let types: [(String, ReferenceType)] = [
            ("note", .note),
            ("endnote", .endnote),
            ("citation", .citation),
            ("glossary", .glossary),
            ("index", .index),
            ("figure", .figure),
            ("table", .table)
        ]
        
        for (text, type) in types {
            let range = (mutableString.string as NSString).range(of: text)
            mutableString.addAttributes([
                .referenceType: type.rawValue,
                .referenceID: UUID().uuidString
            ], range: range)
        }
        
        let refs = mutableString.allReferences()
        
        XCTAssertEqual(refs.count, 7)
        
        // Verify each type is found
        let foundTypes = Set(refs.map { $0.type })
        XCTAssertTrue(foundTypes.contains(.note))
        XCTAssertTrue(foundTypes.contains(.endnote))
        XCTAssertTrue(foundTypes.contains(.citation))
        XCTAssertTrue(foundTypes.contains(.glossary))
        XCTAssertTrue(foundTypes.contains(.index))
        XCTAssertTrue(foundTypes.contains(.figure))
        XCTAssertTrue(foundTypes.contains(.table))
    }
}
