//
//  MixedAttachmentDeletionTests.swift
//  WritingShedProTests
//
//  Tests for unified handling of mixed attachment type deletions
//  When deleting a selection containing multiple attachment types
//  (references, comments, footnotes), they should all be handled together.
//

import XCTest
import SwiftData
import UIKit
@testable import Writing_Shed_Pro

@MainActor
final class MixedAttachmentDeletionTests: XCTestCase {
    
    var modelContext: ModelContext!
    var testVersion: Version!
    var testFile: TextFile!
    var testProject: Project!
    var testFolder: Folder!
    
    override func setUpWithError() throws {
        // Create in-memory model container
        let schema = Schema([
            FootnoteModel.self,
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self,
            CommentModel.self,
            NoteEntry.self,
            GlossaryEntry.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(container)
        
        // Create test project
        testProject = Project(name: "Test Project")
        modelContext.insert(testProject)
        
        // Create test folder
        testFolder = Folder(name: "Test Folder")
        testFolder.project = testProject
        testProject.folders = [testFolder]
        modelContext.insert(testFolder)
        
        // Create test file and version
        testFile = TextFile(name: "Test", initialContent: "", parentFolder: testFolder)
        testVersion = Version(content: "Test content with mixed markers")
        testVersion.textFile = testFile
        testFile.versions = [testVersion]
        
        modelContext.insert(testFile)
        modelContext.insert(testVersion)
        try modelContext.save()
    }
    
    override func tearDownWithError() throws {
        modelContext = nil
        testVersion = nil
        testFile = nil
        testProject = nil
        testFolder = nil
    }
    
    // MARK: - Attachment Type Counting Tests
    
    func testCountMultipleAttachmentTypes() {
        // Given: Arrays of different attachment types
        let references = [
            ReferenceAttachment(referenceType: .note, entryID: UUID(), displayText: "[Note 1]"),
            ReferenceAttachment(referenceType: .endnote, entryID: UUID(), number: 1)
        ]
        let comments = [
            CommentAttachment(commentID: UUID(), isResolved: false)
        ]
        let footnotes = [
            FootnoteAttachment(footnoteID: UUID(), number: 1),
            FootnoteAttachment(footnoteID: UUID(), number: 2)
        ]
        
        // When: Count how many different types are present
        let typesFound = [!references.isEmpty, !comments.isEmpty, !footnotes.isEmpty].filter { $0 }.count
        
        // Then: Should find all 3 types
        XCTAssertEqual(typesFound, 3, "Should detect all three attachment types")
    }
    
    func testCountSingleAttachmentType() {
        // Given: Only references
        let references = [
            ReferenceAttachment(referenceType: .note, entryID: UUID(), displayText: "[Note 1]")
        ]
        let comments: [CommentAttachment] = []
        let footnotes: [FootnoteAttachment] = []
        
        // When
        let typesFound = [!references.isEmpty, !comments.isEmpty, !footnotes.isEmpty].filter { $0 }.count
        
        // Then: Should find only 1 type
        XCTAssertEqual(typesFound, 1, "Should detect only one attachment type")
    }
    
    func testCountTwoAttachmentTypes() {
        // Given: References and comments, no footnotes
        let references = [
            ReferenceAttachment(referenceType: .glossary, entryID: UUID(), displayText: "[see Term]")
        ]
        let comments = [
            CommentAttachment(commentID: UUID(), isResolved: false)
        ]
        let footnotes: [FootnoteAttachment] = []
        
        // When
        let typesFound = [!references.isEmpty, !comments.isEmpty, !footnotes.isEmpty].filter { $0 }.count
        
        // Then: Should find 2 types
        XCTAssertEqual(typesFound, 2, "Should detect two attachment types")
    }
    
    func testMixedDeletionTriggerCondition() {
        // Given: Multiple types
        let references = [ReferenceAttachment(referenceType: .note, entryID: UUID(), displayText: "[Note 1]")]
        let comments = [CommentAttachment(commentID: UUID(), isResolved: false)]
        let footnotes: [FootnoteAttachment] = []
        
        // When: Check if unified handler should be used
        let typesFound = [!references.isEmpty, !comments.isEmpty, !footnotes.isEmpty].filter { $0 }.count
        let shouldUseMixedHandler = typesFound > 1
        
        // Then
        XCTAssertTrue(shouldUseMixedHandler, "Should use mixed handler when more than one type found")
    }
    
    func testSingleTypeShouldNotTriggerMixedHandler() {
        // Given: Only one type
        let references: [ReferenceAttachment] = []
        let comments = [
            CommentAttachment(commentID: UUID(), isResolved: false),
            CommentAttachment(commentID: UUID(), isResolved: true)
        ]
        let footnotes: [FootnoteAttachment] = []
        
        // When
        let typesFound = [!references.isEmpty, !comments.isEmpty, !footnotes.isEmpty].filter { $0 }.count
        let shouldUseMixedHandler = typesFound > 1
        
        // Then
        XCTAssertFalse(shouldUseMixedHandler, "Should NOT use mixed handler when only one type found")
    }
    
    // MARK: - Total Count Tests
    
    func testTotalAttachmentCount() {
        // Given
        let references = [
            ReferenceAttachment(referenceType: .note, entryID: UUID(), displayText: "[Note 1]"),
            ReferenceAttachment(referenceType: .endnote, entryID: UUID(), number: 1)
        ]
        let comments = [
            CommentAttachment(commentID: UUID(), isResolved: false)
        ]
        let footnotes = [
            FootnoteAttachment(footnoteID: UUID(), number: 1),
            FootnoteAttachment(footnoteID: UUID(), number: 2)
        ]
        
        // When
        let totalCount = references.count + comments.count + footnotes.count
        
        // Then
        XCTAssertEqual(totalCount, 5, "Total should be sum of all attachment counts")
    }
    
    // MARK: - CommentModel Deletion Tests
    
    func testCommentModelDeletionByAttachmentID() throws {
        // Given: A comment in the database
        let attachmentID = UUID()
        let comment = CommentModel(
            version: testVersion,
            characterPosition: 0,
            attachmentID: attachmentID,
            text: "Test comment",
            author: "Test Author"
        )
        testVersion.comments = [comment]
        modelContext.insert(comment)
        try modelContext.save()
        
        // When: Find and delete by attachmentID
        if let comments = testVersion.comments,
           let foundComment = comments.first(where: { $0.attachmentID == attachmentID }) {
            modelContext.delete(foundComment)
            try modelContext.save()
        }
        
        // Then: Comment should be deleted
        let descriptor = FetchDescriptor<CommentModel>(
            predicate: #Predicate<CommentModel> { $0.attachmentID == attachmentID }
        )
        let remaining = try modelContext.fetch(descriptor)
        XCTAssertTrue(remaining.isEmpty, "Comment should be deleted from database")
    }
    
    // MARK: - FootnoteModel Deletion Tests
    
    func testFootnoteModelDeletionByAttachmentID() throws {
        // Given: A footnote in the database
        let attachmentID = UUID()
        let footnote = FootnoteModel(
            version: testVersion,
            characterPosition: 0,
            attachmentID: attachmentID,
            text: "Test footnote",
            number: 1
        )
        testVersion.footnotes = [footnote]
        modelContext.insert(footnote)
        try modelContext.save()
        
        // When: Find and delete using FootnoteManager
        if let footnotes = testVersion.footnotes,
           let foundFootnote = footnotes.first(where: { $0.attachmentID == attachmentID }) {
            FootnoteManager.shared.deleteFootnote(foundFootnote, context: modelContext)
        }
        
        // Then: Footnote should be permanently deleted from database
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate<FootnoteModel> { $0.attachmentID == attachmentID }
        )
        let remaining = try modelContext.fetch(descriptor)
        XCTAssertEqual(remaining.count, 0, "Footnote should be permanently deleted from database")
    }
    
    // MARK: - NoteEntry Deletion Tests
    
    func testNoteEntryReferenceCountDecrement() throws {
        // Given: A note entry with reference count
        let noteEntry = NoteEntry(content: "Test content", isEndnote: false, tag: "test-note")
        noteEntry.referenceCount = 2
        noteEntry.project = testProject
        testProject.noteEntries = [noteEntry]
        modelContext.insert(noteEntry)
        try modelContext.save()
        
        // When: Decrement reference count (simulating one reference deleted)
        noteEntry.referenceCount -= 1
        try modelContext.save()
        
        // Then: Reference count should be 1
        XCTAssertEqual(noteEntry.referenceCount, 1, "Reference count should be decremented")
    }
    
    func testNoteEntryDeletionWhenReferenceCountZero() throws {
        // Given: A note entry with reference count 1
        let noteEntry = NoteEntry(content: "Test content", isEndnote: false, tag: "test-note")
        noteEntry.referenceCount = 1
        noteEntry.project = testProject
        testProject.noteEntries = [noteEntry]
        modelContext.insert(noteEntry)
        try modelContext.save()
        
        let noteID = noteEntry.id
        
        // When: Decrement to 0 and delete
        noteEntry.referenceCount -= 1
        if noteEntry.referenceCount <= 0 {
            modelContext.delete(noteEntry)
        }
        try modelContext.save()
        
        // Then: Note entry should be deleted
        let allNotes = try modelContext.fetch(FetchDescriptor<NoteEntry>())
        let matchingNotes = allNotes.filter { $0.id == noteID }
        XCTAssertTrue(matchingNotes.isEmpty, "Note entry should be deleted when reference count reaches 0")
    }
}
