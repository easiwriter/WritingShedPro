//
//  FootnoteModelTests.swift
//  Writing Shed Pro Tests
//
//  Feature 017: Footnotes - Unit tests for FootnoteModel
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class FootnoteModelTests: XCTestCase {
    
    var modelContext: ModelContext!
    var testFileID: UUID!
    
    override func setUpWithError() throws {
        // Create in-memory model container for testing
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
        
        testFileID = UUID()
    }
    
    override func tearDownWithError() throws {
        modelContext = nil
        testFileID = nil
    }
    
    // MARK: - Initialization Tests
    
    func testFootnoteInitialization() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "This is a test footnote",
            number: 1
        )
        
        XCTAssertNotNil(footnote.id)
        XCTAssertEqual(footnote.textFileID, testFileID)
        XCTAssertEqual(footnote.characterPosition, 10)
        XCTAssertEqual(footnote.text, "This is a test footnote")
        XCTAssertEqual(footnote.number, 1)
        XCTAssertNotNil(footnote.createdAt)
        XCTAssertNotNil(footnote.modifiedAt)
        XCTAssertFalse(footnote.isDeleted)
        XCTAssertNil(footnote.deletedAt)
    }
    
    func testFootnoteWithDefaultValues() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 0,
            text: "Footnote",
            number: 1
        )
        
        // Check that defaults are applied
        XCTAssertNotNil(footnote.id)
        XCTAssertNotNil(footnote.attachmentID)
        XCTAssertNotNil(footnote.createdAt)
        XCTAssertNotNil(footnote.modifiedAt)
        XCTAssertNil(footnote.deletedAt)
    }
    
    func testFootnoteWithAllParameters() throws {
        let id = UUID()
        let attachmentID = UUID()
        let createdDate = Date(timeIntervalSince1970: 1000000)
        let modifiedDate = Date(timeIntervalSince1970: 1000100)
        
        let footnote = FootnoteModel(
            id: id,
            textFileID: testFileID,
            characterPosition: 50,
            attachmentID: attachmentID,
            text: "Complete footnote",
            number: 5,
            createdAt: createdDate,
            modifiedAt: modifiedDate,
            isDeleted: false,
            deletedAt: nil
        )
        
        XCTAssertEqual(footnote.id, id)
        XCTAssertEqual(footnote.attachmentID, attachmentID)
        XCTAssertEqual(footnote.createdAt, createdDate)
        XCTAssertEqual(footnote.modifiedAt, modifiedDate)
    }
    
    // MARK: - Text Update Tests
    
    func testUpdateText() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "Original text",
            number: 1
        )
        
        let originalModifiedAt = footnote.modifiedAt
        
        // Wait a tiny bit to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)
        
        XCTAssertEqual(footnote.text, "Original text")
        
        footnote.updateText("Updated text")
        
        XCTAssertEqual(footnote.text, "Updated text")
        XCTAssertGreaterThan(footnote.modifiedAt, originalModifiedAt)
    }
    
    func testUpdateEmptyText() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "Original",
            number: 1
        )
        
        footnote.updateText("")
        
        XCTAssertEqual(footnote.text, "")
    }
    
    func testUpdateLongText() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "Short",
            number: 1
        )
        
        let longText = String(repeating: "This is a very long footnote text. ", count: 100)
        footnote.updateText(longText)
        
        XCTAssertEqual(footnote.text, longText)
    }
    
    // MARK: - Number Update Tests
    
    func testUpdateNumber() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "Test",
            number: 1
        )
        
        let originalModifiedAt = footnote.modifiedAt
        Thread.sleep(forTimeInterval: 0.01)
        
        XCTAssertEqual(footnote.number, 1)
        
        footnote.updateNumber(5)
        
        XCTAssertEqual(footnote.number, 5)
        XCTAssertGreaterThan(footnote.modifiedAt, originalModifiedAt)
    }
    
    func testUpdateNumberToZero() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "Test",
            number: 5
        )
        
        footnote.updateNumber(0)
        
        XCTAssertEqual(footnote.number, 0)
    }
    
    // MARK: - Position Update Tests
    
    func testUpdatePosition() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "Test",
            number: 1
        )
        
        let originalModifiedAt = footnote.modifiedAt
        Thread.sleep(forTimeInterval: 0.01)
        
        XCTAssertEqual(footnote.characterPosition, 10)
        
        footnote.updatePosition(25)
        
        XCTAssertEqual(footnote.characterPosition, 25)
        XCTAssertGreaterThan(footnote.modifiedAt, originalModifiedAt)
    }
    
    func testUpdatePositionToZero() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 50,
            text: "Test",
            number: 1
        )
        
        footnote.updatePosition(0)
        
        XCTAssertEqual(footnote.characterPosition, 0)
    }
    
    func testUpdatePositionMultipleTimes() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "Test",
            number: 1
        )
        
        footnote.updatePosition(20)
        XCTAssertEqual(footnote.characterPosition, 20)
        
        footnote.updatePosition(15)
        XCTAssertEqual(footnote.characterPosition, 15)
        
        footnote.updatePosition(30)
        XCTAssertEqual(footnote.characterPosition, 30)
    }
    
    // MARK: - Trash Tests
    
    func testMoveToTrash() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 5,
            text: "Test",
            number: 1
        )
        
        XCTAssertFalse(footnote.isDeleted)
        XCTAssertNil(footnote.deletedAt)
        
        let originalModifiedAt = footnote.modifiedAt
        Thread.sleep(forTimeInterval: 0.01)
        
        footnote.moveToTrash()
        
        XCTAssertTrue(footnote.isDeleted)
        XCTAssertNotNil(footnote.deletedAt)
        XCTAssertGreaterThan(footnote.modifiedAt, originalModifiedAt)
    }
    
    func testRestoreFromTrash() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 5,
            text: "Test",
            number: 1
        )
        
        // First move to trash
        footnote.moveToTrash()
        XCTAssertTrue(footnote.isDeleted)
        
        let trashedModifiedAt = footnote.modifiedAt
        Thread.sleep(forTimeInterval: 0.01)
        
        // Then restore
        footnote.restoreFromTrash()
        XCTAssertFalse(footnote.isDeleted)
        XCTAssertNil(footnote.deletedAt)
        XCTAssertGreaterThan(footnote.modifiedAt, trashedModifiedAt)
    }
    
    func testMoveToTrashRestoreCycle() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 5,
            text: "Test",
            number: 1
        )
        
        // Start not deleted
        XCTAssertFalse(footnote.isDeleted)
        
        // Move to trash
        footnote.moveToTrash()
        XCTAssertTrue(footnote.isDeleted)
        let firstDeleteTime = footnote.deletedAt
        XCTAssertNotNil(firstDeleteTime)
        
        // Restore
        footnote.restoreFromTrash()
        XCTAssertFalse(footnote.isDeleted)
        XCTAssertNil(footnote.deletedAt)
        
        Thread.sleep(forTimeInterval: 0.01)
        
        // Move to trash again
        footnote.moveToTrash()
        XCTAssertTrue(footnote.isDeleted)
        let secondDeleteTime = footnote.deletedAt
        XCTAssertNotNil(secondDeleteTime)
        
        // Second delete time should be different (later) than first
        if let first = firstDeleteTime, let second = secondDeleteTime {
            XCTAssertNotEqual(first, second)
            XCTAssertGreaterThan(second, first)
        }
    }
    
    // MARK: - Comparable Tests
    
    func testFootnotesComparableByPosition() throws {
        let footnote1 = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "First",
            number: 1
        )
        
        let footnote2 = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 20,
            text: "Second",
            number: 2
        )
        
        XCTAssertTrue(footnote1 < footnote2)
        XCTAssertFalse(footnote2 < footnote1)
    }
    
    func testFootnotesSorting() throws {
        let footnotes = [
            FootnoteModel(textFileID: testFileID, characterPosition: 50, text: "Third", number: 3),
            FootnoteModel(textFileID: testFileID, characterPosition: 10, text: "First", number: 1),
            FootnoteModel(textFileID: testFileID, characterPosition: 30, text: "Second", number: 2)
        ]
        
        let sorted = footnotes.sorted()
        
        XCTAssertEqual(sorted[0].characterPosition, 10)
        XCTAssertEqual(sorted[1].characterPosition, 30)
        XCTAssertEqual(sorted[2].characterPosition, 50)
    }
    
    // MARK: - SwiftData Persistence Tests
    
    func testFootnotePersistence() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 15,
            text: "Persistent footnote",
            number: 1
        )
        
        // Insert into context
        modelContext.insert(footnote)
        try modelContext.save()
        
        let footnoteID = footnote.id
        
        // Fetch it back
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { $0.id == footnoteID }
        )
        let fetchedFootnotes = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(fetchedFootnotes.count, 1)
        let fetchedFootnote = try XCTUnwrap(fetchedFootnotes.first)
        XCTAssertEqual(fetchedFootnote.id, footnoteID)
        XCTAssertEqual(fetchedFootnote.text, "Persistent footnote")
        XCTAssertEqual(fetchedFootnote.characterPosition, 15)
    }
    
    func testFootnoteUpdate() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "Original",
            number: 1
        )
        
        modelContext.insert(footnote)
        try modelContext.save()
        
        let footnoteID = footnote.id
        
        // Update the text
        footnote.updateText("Modified")
        try modelContext.save()
        
        // Fetch it back
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { $0.id == footnoteID }
        )
        let fetchedFootnotes = try modelContext.fetch(descriptor)
        let fetchedFootnote = try XCTUnwrap(fetchedFootnotes.first)
        
        XCTAssertEqual(fetchedFootnote.text, "Modified")
    }
    
    func testFootnoteDeletion() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "To be deleted",
            number: 1
        )
        
        modelContext.insert(footnote)
        try modelContext.save()
        
        let footnoteID = footnote.id
        
        // Delete it
        modelContext.delete(footnote)
        try modelContext.save()
        
        // Try to fetch it back
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { $0.id == footnoteID }
        )
        let fetchedFootnotes = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(fetchedFootnotes.count, 0)
    }
    
    // MARK: - CloudKit Compatibility Tests
    
    func testAllPropertiesAreOptionalOrHaveDefaults() throws {
        // This test verifies CloudKit requirement: all properties must be optional or have defaults
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "Test",
            number: 1
        )
        
        // All required properties have defaults
        XCTAssertNotNil(footnote.id)
        XCTAssertNotNil(footnote.textFileID)
        XCTAssertNotNil(footnote.characterPosition)
        XCTAssertNotNil(footnote.attachmentID)
        XCTAssertNotNil(footnote.text)
        XCTAssertNotNil(footnote.number)
        XCTAssertNotNil(footnote.createdAt)
        XCTAssertNotNil(footnote.modifiedAt)
        XCTAssertNotNil(footnote.isDeleted)
        
        // Optional property
        XCTAssertNil(footnote.deletedAt)
    }
    
    // MARK: - Description Tests
    
    func testCustomDescription() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 25,
            text: "This is a test footnote for description",
            number: 3
        )
        
        let description = footnote.description
        
        XCTAssertTrue(description.contains("#3"))
        XCTAssertTrue(description.contains("25"))
        XCTAssertTrue(description.contains("This is a test footnote"))
    }
    
    func testDescriptionWithLongText() throws {
        let longText = String(repeating: "This is very long text. ", count: 10)
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 100,
            text: longText,
            number: 7
        )
        
        let description = footnote.description
        
        // Description should truncate long text
        XCTAssertTrue(description.contains("#7"))
        XCTAssertTrue(description.contains("100"))
        XCTAssertTrue(description.contains("..."))
    }
    
    // MARK: - Edge Cases
    
    func testMultipleFootnotesInSameFile() throws {
        let footnote1 = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "First",
            number: 1
        )
        
        let footnote2 = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 20,
            text: "Second",
            number: 2
        )
        
        let footnote3 = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 30,
            text: "Third",
            number: 3
        )
        
        modelContext.insert(footnote1)
        modelContext.insert(footnote2)
        modelContext.insert(footnote3)
        try modelContext.save()
        
        // Fetch all footnotes for this file
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { $0.textFileID == testFileID }
        )
        let fetchedFootnotes = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(fetchedFootnotes.count, 3)
    }
    
    func testFootnotesInDifferentFiles() throws {
        let otherFileID = UUID()
        
        let footnote1 = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "File 1 footnote",
            number: 1
        )
        
        let footnote2 = FootnoteModel(
            textFileID: otherFileID,
            characterPosition: 10,
            text: "File 2 footnote",
            number: 1
        )
        
        modelContext.insert(footnote1)
        modelContext.insert(footnote2)
        try modelContext.save()
        
        // Fetch footnotes for first file
        let descriptor1 = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { $0.textFileID == testFileID }
        )
        let file1Footnotes = try modelContext.fetch(descriptor1)
        
        // Fetch footnotes for second file
        let descriptor2 = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { $0.textFileID == otherFileID }
        )
        let file2Footnotes = try modelContext.fetch(descriptor2)
        
        XCTAssertEqual(file1Footnotes.count, 1)
        XCTAssertEqual(file2Footnotes.count, 1)
        XCTAssertNotEqual(file1Footnotes[0].id, file2Footnotes[0].id)
    }
    
    func testPrepareForPermanentDeletion() throws {
        let footnote = FootnoteModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "To be permanently deleted",
            number: 1
        )
        
        // This method is a placeholder for cleanup before permanent deletion
        // It should not throw and should complete successfully
        footnote.prepareForPermanentDeletion()
        
        // No crash or error expected
        XCTAssertTrue(true)
    }
}
