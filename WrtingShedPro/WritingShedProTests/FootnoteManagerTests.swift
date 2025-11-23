//
//  FootnoteManagerTests.swift
//  Writing Shed Pro Tests
//
//  Feature 015: Footnotes - Unit tests for FootnoteManager
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class FootnoteManagerTests: XCTestCase {
    
    var manager: FootnoteManager!
    var modelContext: ModelContext!
    var testVersion: Version!
    
    override func setUpWithError() throws {
        manager = FootnoteManager.shared
        
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
        
        // Create a test version
        testVersion = Version(content: "Test content")
        modelContext.insert(testVersion)
    }
    
    override func tearDownWithError() throws {
        // Clean up all footnotes
        let fetchDescriptor = FetchDescriptor<FootnoteModel>()
        let footnotes = try? modelContext.fetch(fetchDescriptor)
        footnotes?.forEach { modelContext.delete($0) }
        try? modelContext.save()
        
        manager = nil
        modelContext = nil
        testVersion = nil
    }
    
    // MARK: - Create Footnote Tests
    
    func testCreateFootnote() throws {
        let footnote = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Test footnote",
            context: modelContext
        )
        
        XCTAssertNotNil(footnote.id)
        XCTAssertEqual(footnote.version?.id, testVersion.id)
        XCTAssertEqual(footnote.characterPosition, 10)
        XCTAssertEqual(footnote.text, "Test footnote")
        XCTAssertEqual(footnote.number, 1)
        XCTAssertNotNil(footnote.createdAt)
        XCTAssertFalse(footnote.isDeleted)
    }
    
    func testCreateMultipleFootnotes() throws {
        let footnote1 = manager.createFootnote(
            version: testVersion,
            characterPosition: 5,
            attachmentID: UUID(),
            text: "First",
            context: modelContext
        )
        
        let footnote2 = manager.createFootnote(
            version: testVersion,
            characterPosition: 15,
            attachmentID: UUID(),
            text: "Second",
            context: modelContext
        )
        
        XCTAssertNotEqual(footnote1.id, footnote2.id)
        XCTAssertNotEqual(footnote1.attachmentID, footnote2.attachmentID)
        XCTAssertEqual(footnote1.number, 1)
        XCTAssertEqual(footnote2.number, 2)
    }
    
    func testCreateFootnotesOutOfOrder() throws {
        // Create at position 50
        let footnote1 = manager.createFootnote(
            version: testVersion,
            characterPosition: 50,
            attachmentID: UUID(),
            text: "Third",
            context: modelContext
        )
        
        // Create at position 10 (before the first one)
        let footnote2 = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "First",
            context: modelContext
        )
        
        // Create at position 25 (in the middle)
        let footnote3 = manager.createFootnote(
            version: testVersion,
            characterPosition: 25,
            attachmentID: UUID(),
            text: "Second",
            context: modelContext
        )
        
        // Numbers should be based on position order
        XCTAssertEqual(footnote2.number, 1) // Position 10
        XCTAssertEqual(footnote3.number, 2) // Position 25
        XCTAssertEqual(footnote1.number, 3) // Position 50
    }
    
    // MARK: - Get Footnote Tests
    
    func testGetFootnoteByID() throws {
        let footnote = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Find me",
            context: modelContext
        )
        
        let retrieved = manager.getFootnote(id: footnote.id, context: modelContext)
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, footnote.id)
        XCTAssertEqual(retrieved?.text, "Find me")
    }
    
    func testGetFootnoteByIDNotFound() throws {
        let randomID = UUID()
        let retrieved = manager.getFootnote(id: randomID, context: modelContext)
        
        XCTAssertNil(retrieved)
    }
    
    func testGetFootnoteByAttachmentID() throws {
        let attachmentID = UUID()
        let footnote = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: attachmentID,
            text: "Find by attachment",
            context: modelContext
        )
        
        let retrieved = manager.getFootnoteByAttachment(attachmentID: attachmentID, context: modelContext)
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, footnote.id)
        XCTAssertEqual(retrieved?.attachmentID, attachmentID)
    }
    
    // MARK: - Get All Footnotes Tests
    
    func testGetAllFootnotesForFile() throws {
        // Create footnotes for test file
        _ = manager.createFootnote(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "Footnote 1",
            context: modelContext
        )
        
        _ = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Footnote 2",
            context: modelContext
        )
        
        // Create footnote for different file
        let otherVersion = Version(content: "Other content")
        modelContext.insert(otherVersion)
        _ = manager.createFootnote(
            version: otherVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "Other file footnote",
            context: modelContext
        )
        
        let footnotes = manager.getAllFootnotes(forVersion: testVersion, context: modelContext)
        
        XCTAssertEqual(footnotes.count, 2)
        XCTAssertTrue(footnotes.allSatisfy { $0.version?.id == testVersion.id })
    }
    
    func testGetAllFootnotesEmptyFile() throws {
        let emptyVersion = Version(content: "Empty content")
        modelContext.insert(emptyVersion)
        let footnotes = manager.getAllFootnotes(forVersion: emptyVersion, context: modelContext)
        
        XCTAssertEqual(footnotes.count, 0)
    }
    
    func testGetAllFootnotesOrderedByPosition() throws {
        // Create footnotes out of order
        _ = manager.createFootnote(
            version: testVersion,
            characterPosition: 50,
            attachmentID: UUID(),
            text: "Last",
            context: modelContext
        )
        
        _ = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "First",
            context: modelContext
        )
        
        _ = manager.createFootnote(
            version: testVersion,
            characterPosition: 25,
            attachmentID: UUID(),
            text: "Middle",
            context: modelContext
        )
        
        let footnotes = manager.getAllFootnotes(forVersion: testVersion, context: modelContext)
        
        XCTAssertEqual(footnotes.count, 3)
        XCTAssertEqual(footnotes[0].characterPosition, 10)
        XCTAssertEqual(footnotes[1].characterPosition, 25)
        XCTAssertEqual(footnotes[2].characterPosition, 50)
    }
    
    // MARK: - Get Active Footnotes Tests
    
    func testGetActiveFootnotes() throws {
        let footnote1 = manager.createFootnote(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "Active",
            context: modelContext
        )
        
        let footnote2 = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Deleted",
            context: modelContext
        )
        
        // Use manager method to move to trash (handles renumbering and save)
        manager.moveFootnoteToTrash(footnote2, context: modelContext)
        
        let activeFootnotes = manager.getActiveFootnotes(forVersion: testVersion, context: modelContext)
        
        XCTAssertEqual(activeFootnotes.count, 1)
        XCTAssertEqual(activeFootnotes.first?.id, footnote1.id)
        XCTAssertFalse(activeFootnotes.first?.isDeleted ?? true)
    }
    
    func testGetActiveFootnotesWhenAllDeleted() throws {
        let footnote = manager.createFootnote(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "Deleted",
            context: modelContext
        )
        
        // Use manager method to move to trash (handles renumbering and save)
        manager.moveFootnoteToTrash(footnote, context: modelContext)
        
        let activeFootnotes = manager.getActiveFootnotes(forVersion: testVersion, context: modelContext)
        
        XCTAssertEqual(activeFootnotes.count, 0)
    }
    
    // MARK: - Get Deleted Footnotes Tests
    
    func testGetDeletedFootnotes() throws {
        let footnote1 = manager.createFootnote(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "Active",
            context: modelContext
        )
        
        let footnote2 = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Deleted 1",
            context: modelContext
        )
        
        let footnote3 = manager.createFootnote(
            version: testVersion,
            characterPosition: 20,
            attachmentID: UUID(),
            text: "Deleted 2",
            context: modelContext
        )
        
        // Use manager methods to move to trash (triggers proper renumbering and save)
        manager.moveFootnoteToTrash(footnote2, context: modelContext)
        manager.moveFootnoteToTrash(footnote3, context: modelContext)
        
        // Test behavior: check that deleted footnotes are returned by query
        let deletedFootnotes = manager.getDeletedFootnotes(forVersion: testVersion, context: modelContext)
        XCTAssertEqual(deletedFootnotes.count, 2, "Should return 2 deleted footnotes")
        
        // Test behavior: check that active footnotes doesn't include deleted ones
        let activeFootnotes = manager.getActiveFootnotes(forVersion: testVersion, context: modelContext)
        XCTAssertEqual(activeFootnotes.count, 1, "Should only return 1 active footnote")
        XCTAssertEqual(activeFootnotes.first?.id, footnote1.id, "Active footnote should be footnote1")
    }
    
    func testGetAllDeletedFootnotesAcrossFiles() throws {
        // File 1
        let footnote1 = manager.createFootnote(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "File 1 deleted",
            context: modelContext
        )
        
        // File 2
        let otherVersion = Version(content: "Other content")
        modelContext.insert(otherVersion)
        let footnote2 = manager.createFootnote(
            version: otherVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "File 2 deleted",
            context: modelContext
        )
        
        // Use manager methods to move to trash
        manager.moveFootnoteToTrash(footnote1, context: modelContext)
        manager.moveFootnoteToTrash(footnote2, context: modelContext)
        
        // Test behavior: check that deleted footnotes query returns them
        let allDeletedFootnotes = manager.getAllDeletedFootnotes(context: modelContext)
        XCTAssertEqual(allDeletedFootnotes.count, 2, "Should return 2 deleted footnotes across all files")
        
        // Verify they're from different files
        let fileIDs = Set(allDeletedFootnotes.map { $0.version?.id })
        XCTAssertEqual(fileIDs.count, 2, "Deleted footnotes should be from 2 different files")
    }
    
    // MARK: - Update Tests
    
    func testUpdateFootnoteText() throws {
        let footnote = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Original text",
            context: modelContext
        )
        
        manager.updateFootnoteText(footnote, newText: "Updated text", context: modelContext)
        
        XCTAssertEqual(footnote.text, "Updated text")
    }
    
    // MARK: - Trash Tests
    
    func testMoveFootnoteToTrash() throws {
        let footnote = manager.createFootnote(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "To trash",
            context: modelContext
        )
        
        let footnoteID = footnote.id
        
        manager.moveFootnoteToTrash(footnote, context: modelContext)
        
        // Test behavior: footnote should appear in deleted query
        let deletedFootnotes = manager.getDeletedFootnotes(forVersion: testVersion, context: modelContext)
        XCTAssertEqual(deletedFootnotes.count, 1, "Should have 1 deleted footnote")
        XCTAssertEqual(deletedFootnotes.first?.id, footnoteID, "Deleted footnote should be the one we moved to trash")
        
        // Test behavior: footnote should NOT appear in active query
        let activeFootnotes = manager.getActiveFootnotes(forVersion: testVersion, context: modelContext)
        XCTAssertEqual(activeFootnotes.count, 0, "Should have no active footnotes")
    }
    
    func testRestoreFootnote() throws {
        let footnote = manager.createFootnote(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "To restore",
            context: modelContext
        )
        
        let footnoteID = footnote.id
        manager.moveFootnoteToTrash(footnote, context: modelContext)
        
        // Test behavior: footnote should be in deleted query
        let deletedFootnotes = manager.getDeletedFootnotes(forVersion: testVersion, context: modelContext)
        XCTAssertEqual(deletedFootnotes.count, 1, "Should have 1 deleted footnote")
        
        manager.restoreFootnote(footnote, context: modelContext)
        
        // Test behavior: footnote should be back in active query
        let activeFootnotes = manager.getActiveFootnotes(forVersion: testVersion, context: modelContext)
        XCTAssertEqual(activeFootnotes.count, 1, "Should have 1 active footnote after restore")
        XCTAssertEqual(activeFootnotes.first?.id, footnoteID, "Active footnote should be the restored one")
        
        // Test behavior: footnote should NOT be in deleted query anymore
        let stillDeletedFootnotes = manager.getDeletedFootnotes(forVersion: testVersion, context: modelContext)
        XCTAssertEqual(stillDeletedFootnotes.count, 0, "Should have no deleted footnotes after restore")
    }
    
    func testPermanentlyDeleteFootnote() throws {
        let footnote = manager.createFootnote(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "To permanently delete",
            context: modelContext
        )
        try modelContext.save()
        
        let footnotesBefore = manager.getAllFootnotes(forVersion: testVersion, context: modelContext)
        XCTAssertEqual(footnotesBefore.count, 1)
        
        manager.permanentlyDeleteFootnote(footnote, context: modelContext)
        
        let footnotesAfter = manager.getAllFootnotes(forVersion: testVersion, context: modelContext)
        XCTAssertEqual(footnotesAfter.count, 0)
    }
    
    // MARK: - Calculate Footnote Number Tests
    
    func testCalculateFootnoteNumberFirst() throws {
        let number = manager.calculateFootnoteNumber(
            forVersion: testVersion,
            at: 10,
            context: modelContext
        )
        
        XCTAssertEqual(number, 1)
    }
    
    func testCalculateFootnoteNumberAfterExisting() throws {
        _ = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "First",
            context: modelContext
        )
        
        _ = manager.createFootnote(
            version: testVersion,
            characterPosition: 20,
            attachmentID: UUID(),
            text: "Second",
            context: modelContext
        )
        
        // New footnote at position 30 should be number 3
        let number = manager.calculateFootnoteNumber(
            forVersion: testVersion,
            at: 30,
            context: modelContext
        )
        
        XCTAssertEqual(number, 3)
    }
    
    func testCalculateFootnoteNumberInMiddle() throws {
        _ = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "First",
            context: modelContext
        )
        
        _ = manager.createFootnote(
            version: testVersion,
            characterPosition: 30,
            attachmentID: UUID(),
            text: "Third",
            context: modelContext
        )
        
        // New footnote at position 20 should be number 2 (between 1 and 3)
        let number = manager.calculateFootnoteNumber(
            forVersion: testVersion,
            at: 20,
            context: modelContext
        )
        
        XCTAssertEqual(number, 2)
    }
    
    func testCalculateFootnoteNumberAtStart() throws {
        _ = manager.createFootnote(
            version: testVersion,
            characterPosition: 20,
            attachmentID: UUID(),
            text: "Second",
            context: modelContext
        )
        
        _ = manager.createFootnote(
            version: testVersion,
            characterPosition: 30,
            attachmentID: UUID(),
            text: "Third",
            context: modelContext
        )
        
        // New footnote at position 5 should be number 1 (before all)
        let number = manager.calculateFootnoteNumber(
            forVersion: testVersion,
            at: 5,
            context: modelContext
        )
        
        XCTAssertEqual(number, 1)
    }
    
    // MARK: - Renumber Footnotes Tests
    
    func testRenumberFootnotesAfterInsertion() throws {
        let footnote1 = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "First",
            context: modelContext
        )
        
        let footnote2 = manager.createFootnote(
            version: testVersion,
            characterPosition: 30,
            attachmentID: UUID(),
            text: "Third",
            context: modelContext
        )
        
        XCTAssertEqual(footnote1.number, 1)
        XCTAssertEqual(footnote2.number, 2)
        
        // Insert in the middle
        let footnote3 = manager.createFootnote(
            version: testVersion,
            characterPosition: 20,
            attachmentID: UUID(),
            text: "Second",
            context: modelContext
        )
        
        // All should be renumbered correctly
        XCTAssertEqual(footnote1.number, 1) // Position 10
        XCTAssertEqual(footnote3.number, 2) // Position 20
        XCTAssertEqual(footnote2.number, 3) // Position 30
    }
    
    func testRenumberFootnotesAfterDeletion() throws {
        let footnote1 = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "First",
            context: modelContext
        )
        
        let footnote2 = manager.createFootnote(
            version: testVersion,
            characterPosition: 20,
            attachmentID: UUID(),
            text: "Second",
            context: modelContext
        )
        
        let footnote3 = manager.createFootnote(
            version: testVersion,
            characterPosition: 30,
            attachmentID: UUID(),
            text: "Third",
            context: modelContext
        )
        
        XCTAssertEqual(footnote1.number, 1)
        XCTAssertEqual(footnote2.number, 2)
        XCTAssertEqual(footnote3.number, 3)
        
        // Delete the middle one
        manager.moveFootnoteToTrash(footnote2, context: modelContext)
        
        // Get fresh footnote data from database
        let activeFootnotes = manager.getActiveFootnotes(forVersion: testVersion, context: modelContext)
        let refreshedFootnote1 = activeFootnotes.first { $0.id == footnote1.id }!
        let refreshedFootnote3 = activeFootnotes.first { $0.id == footnote3.id }!
        
        // Remaining should renumber
        XCTAssertEqual(refreshedFootnote1.number, 1)
        XCTAssertEqual(refreshedFootnote3.number, 2) // Was 3, now 2
    }
    
    func testRenumberFootnotesAfterRestore() throws {
        let footnote1 = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "First",
            context: modelContext
        )
        
        let footnote2 = manager.createFootnote(
            version: testVersion,
            characterPosition: 20,
            attachmentID: UUID(),
            text: "Second",
            context: modelContext
        )
        
        // Delete footnote2
        manager.moveFootnoteToTrash(footnote2, context: modelContext)
        
        // Get fresh data after deletion
        var activeFootnotes = manager.getActiveFootnotes(forVersion: testVersion, context: modelContext)
        let refreshedFootnote1AfterDelete = activeFootnotes.first { $0.id == footnote1.id }!
        XCTAssertEqual(refreshedFootnote1AfterDelete.number, 1)
        
        // Restore footnote2
        manager.restoreFootnote(footnote2, context: modelContext)
        
        // Get fresh data after restore
        activeFootnotes = manager.getActiveFootnotes(forVersion: testVersion, context: modelContext)
        let refreshedFootnote1AfterRestore = activeFootnotes.first { $0.id == footnote1.id }!
        let refreshedFootnote2AfterRestore = activeFootnotes.first { $0.id == footnote2.id }!
        
        // Should renumber correctly
        XCTAssertEqual(refreshedFootnote1AfterRestore.number, 1)
        XCTAssertEqual(refreshedFootnote2AfterRestore.number, 2)
    }
    
    // MARK: - Position Update Tests
    
    func testUpdatePositionsAfterInsertion() throws {
        let footnote1 = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "First",
            context: modelContext
        )
        
        let footnote2 = manager.createFootnote(
            version: testVersion,
            characterPosition: 20,
            attachmentID: UUID(),
            text: "Second",
            context: modelContext
        )
        
        let footnote3 = manager.createFootnote(
            version: testVersion,
            characterPosition: 30,
            attachmentID: UUID(),
            text: "Third",
            context: modelContext
        )
        
        // Text inserted at position 15, length 5 characters
        manager.updatePositionsAfterEdit(
            version: testVersion,
            editPosition: 15,
            lengthDelta: 5,
            context: modelContext
        )
        
        // Footnote1 at position 10 should not move (before edit)
        XCTAssertEqual(footnote1.characterPosition, 10)
        
        // Footnote2 at position 20 should move to 25 (after edit)
        XCTAssertEqual(footnote2.characterPosition, 25)
        
        // Footnote3 at position 30 should move to 35 (after edit)
        XCTAssertEqual(footnote3.characterPosition, 35)
    }
    
    func testUpdatePositionsAfterDeletion() throws {
        let footnote1 = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "First",
            context: modelContext
        )
        
        let footnote2 = manager.createFootnote(
            version: testVersion,
            characterPosition: 30,
            attachmentID: UUID(),
            text: "Second",
            context: modelContext
        )
        
        let footnote3 = manager.createFootnote(
            version: testVersion,
            characterPosition: 50,
            attachmentID: UUID(),
            text: "Third",
            context: modelContext
        )
        
        // Text deleted at position 20, length 10 characters (negative delta)
        manager.updatePositionsAfterEdit(
            version: testVersion,
            editPosition: 20,
            lengthDelta: -10,
            context: modelContext
        )
        
        // Footnote1 at position 10 should not move (before deletion)
        XCTAssertEqual(footnote1.characterPosition, 10)
        
        // Footnote2 at position 30 should move to 20 (after deletion)
        XCTAssertEqual(footnote2.characterPosition, 20)
        
        // Footnote3 at position 50 should move to 40 (after deletion)
        XCTAssertEqual(footnote3.characterPosition, 40)
    }
    
    func testUpdatePositionsDoesNotMoveBelowEditPosition() throws {
        let footnote = manager.createFootnote(
            version: testVersion,
            characterPosition: 25,
            attachmentID: UUID(),
            text: "Test",
            context: modelContext
        )
        
        // Large deletion that would move footnote before edit position
        // Deletion at position 20, length 20 characters
        manager.updatePositionsAfterEdit(
            version: testVersion,
            editPosition: 20,
            lengthDelta: -20,
            context: modelContext
        )
        
        // Footnote should not move below edit position
        XCTAssertGreaterThanOrEqual(footnote.characterPosition, 20)
    }
    
    // MARK: - Edge Cases
    
    func testMultipleFootnotesAtSamePosition() throws {
        // While unlikely in practice, test that footnotes at same position are handled
        let footnote1 = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "First",
            context: modelContext
        )
        
        let footnote2 = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Second",
            context: modelContext
        )
        
        // Both should exist and have sequential numbers
        XCTAssertEqual(footnote1.number, 1)
        XCTAssertEqual(footnote2.number, 2)
    }
    
    func testFootnotesInDifferentFiles() throws {
        let otherVersion = Version(content: "Other file content")
        modelContext.insert(otherVersion)
        
        let footnote1 = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "File 1 footnote",
            context: modelContext
        )
        
        let footnote2 = manager.createFootnote(
            version: otherVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "File 2 footnote",
            context: modelContext
        )
        
        // Both should be numbered independently
        XCTAssertEqual(footnote1.number, 1)
        XCTAssertEqual(footnote2.number, 1)
        
        // Fetch should be file-specific
        let file1Footnotes = manager.getActiveFootnotes(forVersion: testVersion, context: modelContext)
        let file2Footnotes = manager.getActiveFootnotes(forVersion: otherVersion, context: modelContext)
        
        XCTAssertEqual(file1Footnotes.count, 1)
        XCTAssertEqual(file2Footnotes.count, 1)
        XCTAssertNotEqual(file1Footnotes[0].id, file2Footnotes[0].id)
    }
}
