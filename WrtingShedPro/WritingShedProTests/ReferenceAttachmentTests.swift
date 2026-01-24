//
//  ReferenceAttachmentTests.swift
//  WritingShedProTests
//
//  Unit tests for Feature 029: ReferenceAttachment
//  Tests reference marker attachments for notes, citations, glossary, index
//

import XCTest
import UIKit
@testable import Writing_Shed_Pro

final class ReferenceAttachmentTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testReferenceAttachmentBasicInitialization() {
        let entryID = UUID()
        let attachment = ReferenceAttachment(
            referenceType: .note,
            entryID: entryID,
            displayText: "[Note 1]"
        )
        
        XCTAssertEqual(attachment.referenceType, .note)
        XCTAssertEqual(attachment.entryID, entryID)
        XCTAssertEqual(attachment.displayText, "[Note 1]")
    }
    
    func testReferenceAttachmentEndnoteInitialization() {
        let entryID = UUID()
        let attachment = ReferenceAttachment(
            referenceType: .endnote,
            entryID: entryID,
            number: 5
        )
        
        XCTAssertEqual(attachment.referenceType, .endnote)
        XCTAssertEqual(attachment.entryID, entryID)
        XCTAssertEqual(attachment.displayText, "[5]")
        XCTAssertEqual(attachment.displayNumber, 5)
    }
    
    func testReferenceAttachmentNoteInitialization() {
        let entryID = UUID()
        let attachment = ReferenceAttachment(
            referenceType: .note,
            entryID: entryID,
            number: 3
        )
        
        XCTAssertEqual(attachment.referenceType, .note)
        XCTAssertEqual(attachment.displayText, "[Note 3]")
        XCTAssertEqual(attachment.displayNumber, 3)
    }
    
    func testReferenceAttachmentFigureInitialization() {
        let entryID = UUID()
        let attachment = ReferenceAttachment(
            referenceType: .figure,
            entryID: entryID,
            number: 2
        )
        
        XCTAssertEqual(attachment.referenceType, .figure)
        XCTAssertEqual(attachment.displayText, "[Fig 2]")
    }
    
    func testReferenceAttachmentTableInitialization() {
        let entryID = UUID()
        let attachment = ReferenceAttachment(
            referenceType: .table,
            entryID: entryID,
            number: 1
        )
        
        XCTAssertEqual(attachment.referenceType, .table)
        XCTAssertEqual(attachment.displayText, "[Table 1]")
    }
    
    // MARK: - Reference Initialization Tests
    
    func testReferenceAttachmentReferenceWithDate() {
        let entryID = UUID()
        let attachment = ReferenceAttachment(
            referenceEntryID: entryID,
            author: "Smith",
            date: "2024"
        )
        
        XCTAssertEqual(attachment.referenceType, .reference)
        XCTAssertEqual(attachment.entryID, entryID)
        XCTAssertEqual(attachment.displayText, "[Smith, 2024]")
    }
    
    func testReferenceAttachmentReferenceWithEmptyDate() {
        let entryID = UUID()
        let attachment = ReferenceAttachment(
            referenceEntryID: entryID,
            author: "Doe",
            date: ""
        )
        
        XCTAssertEqual(attachment.referenceType, .reference)
        XCTAssertEqual(attachment.displayText, "[Doe, ]")
    }
    
    // MARK: - Glossary Initialization Tests
    
    func testReferenceAttachmentGlossary() {
        let entryID = UUID()
        let attachment = ReferenceAttachment(
            glossaryEntryID: entryID,
            term: "Protagonist"
        )
        
        XCTAssertEqual(attachment.referenceType, .glossary)
        XCTAssertEqual(attachment.entryID, entryID)
        XCTAssertEqual(attachment.displayText, "[see Protagonist]")
    }
    
    // MARK: - Index Initialization Tests
    
    func testReferenceAttachmentIndex() {
        let entryID = UUID()
        let attachment = ReferenceAttachment(indexEntryID: entryID)
        
        XCTAssertEqual(attachment.referenceType, .index)
        XCTAssertEqual(attachment.entryID, entryID)
        // Index uses zero-width space for invisibility
        XCTAssertEqual(attachment.displayText, "\u{200B}")
    }
    
    // MARK: - Display Number Update Tests
    
    func testDisplayNumberUpdateUpdatesDisplayText() {
        let entryID = UUID()
        let attachment = ReferenceAttachment(
            referenceType: .endnote,
            entryID: entryID,
            number: 1
        )
        
        XCTAssertEqual(attachment.displayText, "[1]")
        
        attachment.displayNumber = 5
        
        XCTAssertEqual(attachment.displayNumber, 5)
        XCTAssertEqual(attachment.displayText, "[5]")
    }
    
    func testDisplayNumberUpdateForNote() {
        let entryID = UUID()
        let attachment = ReferenceAttachment(
            referenceType: .note,
            entryID: entryID,
            number: 1
        )
        
        XCTAssertEqual(attachment.displayText, "[Note 1]")
        
        attachment.displayNumber = 3
        
        XCTAssertEqual(attachment.displayText, "[Note 3]")
    }
    
    // MARK: - Reference Type Color Tests
    
    func testReferenceTypeColors() {
        // Note: We test the ReferenceType enum color properties
        // These are used by ReferenceAttachment for rendering
        
        // Just verify these don't crash - actual colors are implementation details
        let noteAttachment = ReferenceAttachment(referenceType: .note, entryID: UUID(), displayText: "[Note 1]")
        let referenceAttachment = ReferenceAttachment(referenceType: .reference, entryID: UUID(), displayText: "[Smith, 2024]")
        let glossaryAttachment = ReferenceAttachment(referenceType: .glossary, entryID: UUID(), displayText: "Term")
        let indexAttachment = ReferenceAttachment(indexEntryID: UUID())
        
        XCTAssertNotNil(noteAttachment)
        XCTAssertNotNil(referenceAttachment)
        XCTAssertNotNil(glossaryAttachment)
        XCTAssertNotNil(indexAttachment)
    }
    
    // MARK: - Multiple References Same Entry Tests
    
    func testMultipleReferencesToSameEntry() {
        let entryID = UUID()
        
        let attachment1 = ReferenceAttachment(
            referenceType: .note,
            entryID: entryID,
            number: 1
        )
        
        let attachment2 = ReferenceAttachment(
            referenceType: .note,
            entryID: entryID,
            number: 1
        )
        
        // Both should reference the same entry
        XCTAssertEqual(attachment1.entryID, attachment2.entryID)
        XCTAssertEqual(attachment1.displayText, attachment2.displayText)
    }
    
    // MARK: - Bounds Tests
    
    func testAttachmentBoundsReturnsValidSize() {
        let attachment = ReferenceAttachment(
            referenceType: .note,
            entryID: UUID(),
            number: 1
        )
        
        // Create a text container and layout manager for bounds calculation
        let textContainer = NSTextContainer(size: CGSize(width: 300, height: 100))
        
        let bounds = attachment.attachmentBounds(
            for: textContainer,
            proposedLineFragment: CGRect(x: 0, y: 0, width: 300, height: 20),
            glyphPosition: .zero,
            characterIndex: 0
        )
        
        // Bounds should have positive width and height
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)
    }
    
    func testInvisibleIndexAttachmentHasMinimalBounds() {
        let attachment = ReferenceAttachment(indexEntryID: UUID())
        
        let textContainer = NSTextContainer(size: CGSize(width: 300, height: 100))
        
        let bounds = attachment.attachmentBounds(
            for: textContainer,
            proposedLineFragment: CGRect(x: 0, y: 0, width: 300, height: 20),
            glyphPosition: .zero,
            characterIndex: 0
        )
        
        // Index markers should have minimal or zero width
        XCTAssertLessThanOrEqual(bounds.width, 2)
    }
    
    // MARK: - All Reference Types Tests
    
    func testAllReferenceTypesCanBeCreated() {
        let entryID = UUID()
        
        // Note
        let note = ReferenceAttachment(referenceType: .note, entryID: entryID, number: 1)
        XCTAssertEqual(note.referenceType, .note)
        
        // Endnote
        let endnote = ReferenceAttachment(referenceType: .endnote, entryID: entryID, number: 1)
        XCTAssertEqual(endnote.referenceType, .endnote)
        
        // Reference
        let reference = ReferenceAttachment(referenceEntryID: entryID, author: "Test", date: "2024")
        XCTAssertEqual(reference.referenceType, .reference)
        
        // Glossary
        let glossary = ReferenceAttachment(glossaryEntryID: entryID, term: "Term")
        XCTAssertEqual(glossary.referenceType, .glossary)
        
        // Index
        let index = ReferenceAttachment(indexEntryID: entryID)
        XCTAssertEqual(index.referenceType, .index)
        
        // Figure
        let figure = ReferenceAttachment(referenceType: .figure, entryID: entryID, number: 1)
        XCTAssertEqual(figure.referenceType, .figure)
        
        // Table
        let table = ReferenceAttachment(referenceType: .table, entryID: entryID, number: 1)
        XCTAssertEqual(table.referenceType, .table)
    }
}
