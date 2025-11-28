//
//  FootnoteAttachmentRenumberingTests.swift
//  WritingShedProTests
//
//  Tests for footnote attachment renumbering after deletion
//  Verifies that attachment numbers in text are updated when footnotes are deleted/restored
//

import XCTest
import SwiftData
import UIKit
@testable import Writing_Shed_Pro

@MainActor
final class FootnoteAttachmentRenumberingTests: XCTestCase {
    
    var modelContext: ModelContext!
    var testVersion: Version!
    var testFile: TextFile!
    
    override func setUpWithError() throws {
        // Create in-memory model container
        let schema = Schema([
            FootnoteModel.self,
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(container)
        
        // Create test file and version
        testFile = TextFile(name: "Test", initialContent: "")
        testVersion = Version(content: "Test content")
        testVersion.textFile = testFile
        testFile.versions = [testVersion]
        
        modelContext.insert(testFile)
        modelContext.insert(testVersion)
        try modelContext.save()
    }
    
    override func tearDownWithError() throws {
        // Clean up
        let fetchDescriptor = FetchDescriptor<FootnoteModel>()
        let footnotes = try? modelContext.fetch(fetchDescriptor)
        footnotes?.forEach { modelContext.delete($0) }
        try? modelContext.save()
        
        modelContext = nil
        testVersion = nil
        testFile = nil
    }
    
    // MARK: - Attachment Renumbering Tests
    
    func testFootnoteAttachmentsRenumberAfterDeletion() throws {
        // Create text with three footnotes
        let originalText = NSAttributedString(string: "One Two Three")
        
        let (afterFirst, footnote1) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 3,
            footnoteText: "First",
            version: testVersion,
            context: modelContext
        )
        
        let (afterSecond, footnote2) = FootnoteInsertionHelper.insertFootnote(
            in: afterFirst,
            at: 8,
            footnoteText: "Second",
            version: testVersion,
            context: modelContext
        )
        
        let (textWithThree, footnote3) = FootnoteInsertionHelper.insertFootnote(
            in: afterSecond,
            at: 15,
            footnoteText: "Third",
            version: testVersion,
            context: modelContext
        )
        
        // Verify initial numbers
        XCTAssertEqual(footnote1.number, 1)
        XCTAssertEqual(footnote2.number, 2)
        XCTAssertEqual(footnote3.number, 3)
        
        // Delete first footnote from database
        FootnoteManager.shared.moveFootnoteToTrash(footnote1, context: modelContext)
        
        // Get fresh footnote data
        let activeFootnotes = FootnoteManager.shared.getActiveFootnotes(forVersion: testVersion, context: modelContext)
        let updatedFootnote2 = activeFootnotes.first { $0.id == footnote2.id }
        let updatedFootnote3 = activeFootnotes.first { $0.id == footnote3.id }
        
        // Verify database renumbering occurred
        XCTAssertEqual(updatedFootnote2?.number, 1) // Was 2, now 1
        XCTAssertEqual(updatedFootnote3?.number, 2) // Was 3, now 2
        
        // Now update attachment numbers in the text
        let mutableText = NSMutableAttributedString(attributedString: textWithThree)
        var needsUpdate = false
        
        mutableText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableText.length)) { value, range, stop in
            guard let attachment = value as? FootnoteAttachment else { return }
            
            // Look up current number from database
            if let footnote = FootnoteManager.shared.getFootnoteByAttachment(attachmentID: attachment.footnoteID, context: modelContext) {
                if attachment.number != footnote.number {
                    attachment.number = footnote.number
                    needsUpdate = true
                }
            }
        }
        
        XCTAssertTrue(needsUpdate, "Attachments should need updating")
        
        // Verify attachment numbers were updated
        let attachment2 = mutableText.attribute(.attachment, at: 8, effectiveRange: nil) as? FootnoteAttachment
        let attachment3 = mutableText.attribute(.attachment, at: 15, effectiveRange: nil) as? FootnoteAttachment
        
        XCTAssertEqual(attachment2?.number, 1) // Updated from 2 to 1
        XCTAssertEqual(attachment3?.number, 2) // Updated from 3 to 2
    }
    
    func testFootnoteAttachmentsRenumberAfterMiddleDeletion() throws {
        // Create text with three footnotes
        let originalText = NSAttributedString(string: "One Two Three")
        
        let (afterFirst, footnote1) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 3,
            footnoteText: "First",
            version: testVersion,
            context: modelContext
        )
        
        let (afterSecond, footnote2) = FootnoteInsertionHelper.insertFootnote(
            in: afterFirst,
            at: 8,
            footnoteText: "Second",
            version: testVersion,
            context: modelContext
        )
        
        let (textWithThree, footnote3) = FootnoteInsertionHelper.insertFootnote(
            in: afterSecond,
            at: 15,
            footnoteText: "Third",
            version: testVersion,
            context: modelContext
        )
        
        // Delete middle footnote
        FootnoteManager.shared.moveFootnoteToTrash(footnote2, context: modelContext)
        
        // Get fresh data
        let activeFootnotes = FootnoteManager.shared.getActiveFootnotes(forVersion: testVersion, context: modelContext)
        let updatedFootnote1 = activeFootnotes.first { $0.id == footnote1.id }
        let updatedFootnote3 = activeFootnotes.first { $0.id == footnote3.id }
        
        // Verify database renumbering
        XCTAssertEqual(updatedFootnote1?.number, 1) // Unchanged
        XCTAssertEqual(updatedFootnote3?.number, 2) // Was 3, now 2
        
        // Update attachment numbers
        let mutableText = NSMutableAttributedString(attributedString: textWithThree)
        
        mutableText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableText.length)) { value, range, stop in
            guard let attachment = value as? FootnoteAttachment else { return }
            
            if let footnote = FootnoteManager.shared.getFootnoteByAttachment(attachmentID: attachment.footnoteID, context: modelContext) {
                if attachment.number != footnote.number {
                    attachment.number = footnote.number
                }
            }
        }
        
        // Verify attachment numbers
        let attachment1 = mutableText.attribute(.attachment, at: 3, effectiveRange: nil) as? FootnoteAttachment
        let attachment3 = mutableText.attribute(.attachment, at: 15, effectiveRange: nil) as? FootnoteAttachment
        
        XCTAssertEqual(attachment1?.number, 1) // Unchanged
        XCTAssertEqual(attachment3?.number, 2) // Updated from 3 to 2
    }
    
    func testFootnoteAttachmentsRenumberAfterRestore() throws {
        // Create and delete a footnote
        let originalText = NSAttributedString(string: "One Two")
        
        let (afterFirst, footnote1) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 3,
            footnoteText: "First",
            version: testVersion,
            context: modelContext
        )
        
        let (textWithTwo, footnote2) = FootnoteInsertionHelper.insertFootnote(
            in: afterFirst,
            at: 8,
            footnoteText: "Second",
            version: testVersion,
            context: modelContext
        )
        
        // Delete first footnote
        FootnoteManager.shared.moveFootnoteToTrash(footnote1, context: modelContext)
        
        // Verify renumbering
        let activeAfterDelete = FootnoteManager.shared.getActiveFootnotes(forVersion: testVersion, context: modelContext)
        let footnote2AfterDelete = activeAfterDelete.first { $0.id == footnote2.id }
        XCTAssertEqual(footnote2AfterDelete?.number, 1) // Was 2, now 1
        
        // Restore first footnote
        FootnoteManager.shared.restoreFootnote(footnote1, context: modelContext)
        
        // Verify renumbering again
        let activeAfterRestore = FootnoteManager.shared.getActiveFootnotes(forVersion: testVersion, context: modelContext)
        let footnote1AfterRestore = activeAfterRestore.first { $0.id == footnote1.id }
        let footnote2AfterRestore = activeAfterRestore.first { $0.id == footnote2.id }
        
        XCTAssertEqual(footnote1AfterRestore?.number, 1) // Restored to 1
        XCTAssertEqual(footnote2AfterRestore?.number, 2) // Back to 2
        
        // Update attachment numbers
        let mutableText = NSMutableAttributedString(attributedString: textWithTwo)
        
        mutableText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableText.length)) { value, range, stop in
            guard let attachment = value as? FootnoteAttachment else { return }
            
            if let footnote = FootnoteManager.shared.getFootnoteByAttachment(attachmentID: attachment.footnoteID, context: modelContext) {
                attachment.number = footnote.number
            }
        }
        
        // Verify final numbers
        let attachment1 = mutableText.attribute(.attachment, at: 3, effectiveRange: nil) as? FootnoteAttachment
        let attachment2 = mutableText.attribute(.attachment, at: 8, effectiveRange: nil) as? FootnoteAttachment
        
        XCTAssertEqual(attachment1?.number, 1)
        XCTAssertEqual(attachment2?.number, 2)
    }
    
    func testLookupByAttachmentIDNotDatabaseID() throws {
        // This test verifies the fix: we must use attachmentID, not database ID
        
        let originalText = NSAttributedString(string: "Hello")
        let (textWithFootnote, footnote) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 5,
            footnoteText: "Test",
            version: testVersion,
            context: modelContext
        )
        
        // Extract the attachment
        let attachment = textWithFootnote.attribute(.attachment, at: 5, effectiveRange: nil) as? FootnoteAttachment
        XCTAssertNotNil(attachment)
        
        // CRITICAL: attachment.footnoteID corresponds to FootnoteModel.attachmentID, NOT FootnoteModel.id
        XCTAssertEqual(attachment?.footnoteID, footnote.attachmentID)
        XCTAssertNotEqual(attachment?.footnoteID, footnote.id) // These are different!
        
        // Verify we can look up by attachmentID
        let foundByAttachmentID = FootnoteManager.shared.getFootnoteByAttachment(
            attachmentID: attachment!.footnoteID,
            context: modelContext
        )
        XCTAssertNotNil(foundByAttachmentID)
        XCTAssertEqual(foundByAttachmentID?.id, footnote.id)
        
        // Verify lookup by database ID would FAIL (this was the bug)
        let foundByDatabaseID = FootnoteManager.shared.getFootnote(
            id: attachment!.footnoteID, // WRONG - using attachmentID as database ID
            context: modelContext
        )
        XCTAssertNil(foundByDatabaseID, "Should NOT find footnote when using attachmentID as database ID")
    }
    
    func testNoUpdateNeededWhenNumbersMatch() throws {
        // Create footnote
        let originalText = NSAttributedString(string: "Hello")
        let (textWithFootnote, footnote) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 5,
            footnoteText: "Test",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(footnote.number, 1)
        
        // Check if update is needed
        let mutableText = NSMutableAttributedString(attributedString: textWithFootnote)
        var needsUpdate = false
        
        mutableText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableText.length)) { value, range, stop in
            guard let attachment = value as? FootnoteAttachment else { return }
            
            if let footnote = FootnoteManager.shared.getFootnoteByAttachment(attachmentID: attachment.footnoteID, context: modelContext) {
                if attachment.number != footnote.number {
                    needsUpdate = true
                }
            }
        }
        
        XCTAssertFalse(needsUpdate, "Should not need update when numbers already match")
    }
}
