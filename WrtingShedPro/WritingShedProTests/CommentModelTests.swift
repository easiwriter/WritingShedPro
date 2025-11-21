//
//  CommentModelTests.swift
//  Writing Shed Pro Tests
//
//  Feature 014: Comments - Unit tests for CommentModel
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class CommentModelTests: XCTestCase {
    
    var modelContext: ModelContext!
    var testFileID: UUID!
    
    override func setUpWithError() throws {
        // Create in-memory model container for testing
        let schema = Schema([
            CommentModel.self,
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
    
    func testCommentInitialization() throws {
        let comment = CommentModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "This is a test comment",
            author: "Test User"
        )
        
        XCTAssertNotNil(comment.id)
        XCTAssertEqual(comment.textFileID, testFileID)
        XCTAssertEqual(comment.characterPosition, 10)
        XCTAssertEqual(comment.text, "This is a test comment")
        XCTAssertEqual(comment.author, "Test User")
        XCTAssertNotNil(comment.createdAt)
        XCTAssertNil(comment.resolvedAt)
        XCTAssertFalse(comment.isResolved)
    }
    
    func testCommentWithDefaultValues() throws {
        let comment = CommentModel(
            textFileID: testFileID,
            characterPosition: 0,
            text: "Comment",
            author: "User"
        )
        
        // Check that defaults are applied
        XCTAssertNotNil(comment.id)
        XCTAssertNotNil(comment.attachmentID)
        XCTAssertNotNil(comment.createdAt)
        XCTAssertNil(comment.resolvedAt)
    }
    
    // MARK: - Resolved State Tests
    
    func testResolveComment() throws {
        let comment = CommentModel(
            textFileID: testFileID,
            characterPosition: 5,
            text: "Test",
            author: "User"
        )
        
        XCTAssertFalse(comment.isResolved)
        XCTAssertNil(comment.resolvedAt)
        
        comment.resolve()
        
        XCTAssertTrue(comment.isResolved)
        XCTAssertNotNil(comment.resolvedAt)
    }
    
    func testReopenComment() throws {
        let comment = CommentModel(
            textFileID: testFileID,
            characterPosition: 5,
            text: "Test",
            author: "User"
        )
        
        // First resolve it
        comment.resolve()
        XCTAssertTrue(comment.isResolved)
        
        // Then reopen it
        comment.reopen()
        XCTAssertFalse(comment.isResolved)
        XCTAssertNil(comment.resolvedAt)
    }
    
    func testResolveReopenCycle() throws {
        let comment = CommentModel(
            textFileID: testFileID,
            characterPosition: 5,
            text: "Test",
            author: "User"
        )
        
        // Start unresolved
        XCTAssertFalse(comment.isResolved)
        
        // Resolve
        comment.resolve()
        XCTAssertTrue(comment.isResolved)
        let firstResolveTime = comment.resolvedAt
        XCTAssertNotNil(firstResolveTime)
        
        // Reopen
        comment.reopen()
        XCTAssertFalse(comment.isResolved)
        XCTAssertNil(comment.resolvedAt)
        
        // Resolve again
        comment.resolve()
        XCTAssertTrue(comment.isResolved)
        let secondResolveTime = comment.resolvedAt
        XCTAssertNotNil(secondResolveTime)
        
        // Second resolve time should be different (later) than first
        if let first = firstResolveTime, let second = secondResolveTime {
            XCTAssertNotEqual(first, second)
        }
    }
    
    // MARK: - Text Update Tests
    
    func testUpdateText() throws {
        let comment = CommentModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "Original text",
            author: "User"
        )
        
        XCTAssertEqual(comment.text, "Original text")
        
        comment.updateText("Updated text")
        
        XCTAssertEqual(comment.text, "Updated text")
    }
    
    func testUpdateEmptyText() throws {
        let comment = CommentModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "Original",
            author: "User"
        )
        
        comment.updateText("")
        
        XCTAssertEqual(comment.text, "")
    }
    
    // MARK: - Position Update Tests
    
    func testUpdatePosition() throws {
        let comment = CommentModel(
            textFileID: testFileID,
            characterPosition: 10,
            text: "Test",
            author: "User"
        )
        
        XCTAssertEqual(comment.characterPosition, 10)
        
        comment.updatePosition(25)
        
        XCTAssertEqual(comment.characterPosition, 25)
    }
    
    func testUpdatePositionToZero() throws {
        let comment = CommentModel(
            textFileID: testFileID,
            characterPosition: 50,
            text: "Test",
            author: "User"
        )
        
        comment.updatePosition(0)
        
        XCTAssertEqual(comment.characterPosition, 0)
    }
    
    // MARK: - Persistence Tests
    
    func testSaveAndFetchComment() throws {
        let comment = CommentModel(
            textFileID: testFileID,
            characterPosition: 15,
            text: "Persistent comment",
            author: "Test User"
        )
        
        modelContext.insert(comment)
        try modelContext.save()
        
        // Fetch the comment back
        let fetchDescriptor = FetchDescriptor<CommentModel>()
        let comments = try modelContext.fetch(fetchDescriptor)
        
        XCTAssertEqual(comments.count, 1)
        let fetchedComment = comments.first!
        XCTAssertEqual(fetchedComment.text, "Persistent comment")
        XCTAssertEqual(fetchedComment.author, "Test User")
        XCTAssertEqual(fetchedComment.characterPosition, 15)
    }
    
    func testFetchCommentsByFileID() throws {
        let fileID1 = UUID()
        let fileID2 = UUID()
        
        // Create comments for different files
        let comment1 = CommentModel(textFileID: fileID1, characterPosition: 0, text: "File 1 Comment 1", author: "User")
        let comment2 = CommentModel(textFileID: fileID1, characterPosition: 10, text: "File 1 Comment 2", author: "User")
        let comment3 = CommentModel(textFileID: fileID2, characterPosition: 0, text: "File 2 Comment", author: "User")
        
        modelContext.insert(comment1)
        modelContext.insert(comment2)
        modelContext.insert(comment3)
        try modelContext.save()
        
        // Fetch comments for fileID1
        let fetchDescriptor = FetchDescriptor<CommentModel>(
            predicate: #Predicate { $0.textFileID == fileID1 }
        )
        let file1Comments = try modelContext.fetch(fetchDescriptor)
        
        XCTAssertEqual(file1Comments.count, 2)
    }
    
    func testFetchResolvedComments() throws {
        let comment1 = CommentModel(textFileID: testFileID, characterPosition: 0, text: "Active", author: "User")
        let comment2 = CommentModel(textFileID: testFileID, characterPosition: 10, text: "Resolved", author: "User")
        comment2.resolve()
        
        modelContext.insert(comment1)
        modelContext.insert(comment2)
        try modelContext.save()
        
        // Fetch only resolved comments
        let fetchDescriptor = FetchDescriptor<CommentModel>(
            predicate: #Predicate { $0.resolvedAt != nil }
        )
        let resolvedComments = try modelContext.fetch(fetchDescriptor)
        
        XCTAssertEqual(resolvedComments.count, 1)
        XCTAssertEqual(resolvedComments.first?.text, "Resolved")
    }
    
    // MARK: - Edge Cases
    
    func testVeryLongCommentText() throws {
        let longText = String(repeating: "A", count: 10000)
        let comment = CommentModel(
            textFileID: testFileID,
            characterPosition: 0,
            text: longText,
            author: "User"
        )
        
        XCTAssertEqual(comment.text.count, 10000)
        
        modelContext.insert(comment)
        XCTAssertNoThrow(try modelContext.save())
    }
    
    func testSpecialCharactersInText() throws {
        let specialText = "Test with émojis 🎉 and spëcial çharåctérs!@#$%^&*()"
        let comment = CommentModel(
            textFileID: testFileID,
            characterPosition: 0,
            text: specialText,
            author: "User"
        )
        
        XCTAssertEqual(comment.text, specialText)
        
        modelContext.insert(comment)
        try modelContext.save()
        
        let fetchDescriptor = FetchDescriptor<CommentModel>()
        let comments = try modelContext.fetch(fetchDescriptor)
        XCTAssertEqual(comments.first?.text, specialText)
    }
}
