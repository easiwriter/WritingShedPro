//
//  CommentManagerTests.swift
//  Writing Shed Pro Tests
//
//  Feature 014: Comments - Unit tests for CommentManager
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class CommentManagerTests: XCTestCase {
    
    var manager: CommentManager!
    var modelContext: ModelContext!
    var testVersion: Version!
    
    override func setUpWithError() throws {
        manager = CommentManager.shared
        
        // Create in-memory model container
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
        
        // Create a test version
        testVersion = Version(content: "Test content")
        modelContext.insert(testVersion)
    }
    
    override func tearDownWithError() throws {
        // Clean up all comments
        let fetchDescriptor = FetchDescriptor<CommentModel>()
        let comments = try? modelContext.fetch(fetchDescriptor)
        comments?.forEach { modelContext.delete($0) }
        try? modelContext.save()
        
        manager = nil
        modelContext = nil
        testVersion = nil
    }
    
    // MARK: - Create Comment Tests
    
    func testCreateComment() throws {
        let comment = manager.createComment(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Test comment",
            author: "Test User",
            context: modelContext
        )
        
        XCTAssertNotNil(comment.id)
        XCTAssertEqual(comment.version?.id, testVersion.id)
        XCTAssertEqual(comment.characterPosition, 10)
        XCTAssertEqual(comment.text, "Test comment")
        XCTAssertEqual(comment.author, "Test User")
        XCTAssertNotNil(comment.createdAt)
        XCTAssertFalse(comment.isResolved)
    }
    
    func testCreateMultipleComments() throws {
        let comment1 = manager.createComment(
            version: testVersion,
            characterPosition: 5,
            attachmentID: UUID(),
            text: "First",
            author: "User",
            context: modelContext
        )
        
        let comment2 = manager.createComment(
            version: testVersion,
            characterPosition: 15,
            attachmentID: UUID(),
            text: "Second",
            author: "User",
            context: modelContext
        )
        
        XCTAssertNotEqual(comment1.id, comment2.id)
        XCTAssertNotEqual(comment1.attachmentID, comment2.attachmentID)
    }
    
    // MARK: - Get Comments Tests
    
    func testGetCommentsForFile() throws {
        // Create comments for test file
        _ = manager.createComment(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "Comment 1",
            author: "User",
            context: modelContext
        )
        
        _ = manager.createComment(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Comment 2",
            author: "User",
            context: modelContext
        )
        
        // Create comment for different file
        let otherVersion = Version(content: "Other content")
        modelContext.insert(otherVersion)
        _ = manager.createComment(
            version: otherVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "Other file comment",
            author: "User",
            context: modelContext
        )
        
        let comments = manager.getComments(forVersion: testVersion, context: modelContext)
        
        XCTAssertEqual(comments.count, 2)
        XCTAssertTrue(comments.allSatisfy { $0.version?.id == testVersion.id })
    }
    
    func testGetCommentsEmptyFile() throws {
        let emptyVersion = Version(content: "Empty content")
        modelContext.insert(emptyVersion)
        let comments = manager.getComments(forVersion: emptyVersion, context: modelContext)
        
        XCTAssertEqual(comments.count, 0)
    }
    
    func testGetCommentsOrderedByPosition() throws {
        // Create comments out of order
        _ = manager.createComment(
            version: testVersion,
            characterPosition: 50,
            attachmentID: UUID(),
            text: "Last",
            author: "User",
            context: modelContext
        )
        
        _ = manager.createComment(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "First",
            author: "User",
            context: modelContext
        )
        
        _ = manager.createComment(
            version: testVersion,
            characterPosition: 25,
            attachmentID: UUID(),
            text: "Middle",
            author: "User",
            context: modelContext
        )
        
        let comments = manager.getComments(forVersion: testVersion, context: modelContext)
        
        XCTAssertEqual(comments.count, 3)
        XCTAssertEqual(comments[0].characterPosition, 10)
        XCTAssertEqual(comments[1].characterPosition, 25)
        XCTAssertEqual(comments[2].characterPosition, 50)
    }
    
    // MARK: - Get Active Comments Tests
    
    func testGetActiveComments() throws {
        let comment1 = manager.createComment(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "Active",
            author: "User",
            context: modelContext
        )
        
        let comment2 = manager.createComment(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Resolved",
            author: "User",
            context: modelContext
        )
        comment2.resolve()
        try modelContext.save()
        
        let activeComments = manager.getActiveComments(forVersion: testVersion, context: modelContext)
        
        XCTAssertEqual(activeComments.count, 1)
        XCTAssertEqual(activeComments.first?.id, comment1.id)
        XCTAssertFalse(activeComments.first?.isResolved ?? true)
    }
    
    func testGetActiveCommentsWhenAllResolved() throws {
        let comment = manager.createComment(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "Resolved",
            author: "User",
            context: modelContext
        )
        comment.resolve()
        try modelContext.save()
        
        let activeComments = manager.getActiveComments(forVersion: testVersion, context: modelContext)
        
        XCTAssertEqual(activeComments.count, 0)
    }
    
    // MARK: - Get Resolved Comments Tests
    
    func testGetResolvedComments() throws {
        _ = manager.createComment(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "Active",
            author: "User",
            context: modelContext
        )
        
        let comment2 = manager.createComment(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Resolved 1",
            author: "User",
            context: modelContext
        )
        comment2.resolve()
        
        let comment3 = manager.createComment(
            version: testVersion,
            characterPosition: 20,
            attachmentID: UUID(),
            text: "Resolved 2",
            author: "User",
            context: modelContext
        )
        comment3.resolve()
        
        try modelContext.save()
        
        let resolvedComments = manager.getResolvedComments(forVersion: testVersion, context: modelContext)
        
        XCTAssertEqual(resolvedComments.count, 2)
        XCTAssertTrue(resolvedComments.allSatisfy { $0.isResolved })
    }
    
    // MARK: - Delete Comment Tests
    
    func testDeleteComment() throws {
        let comment = manager.createComment(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "To delete",
            author: "User",
            context: modelContext
        )
        try modelContext.save()
        
        let commentsBefore = manager.getComments(forVersion: testVersion, context: modelContext)
        XCTAssertEqual(commentsBefore.count, 1)
        
        manager.deleteComment(comment, context: modelContext)
        try modelContext.save()
        
        let commentsAfter = manager.getComments(forVersion: testVersion, context: modelContext)
        XCTAssertEqual(commentsAfter.count, 0)
    }
    
    func testDeleteMultipleComments() throws {
        let comment1 = manager.createComment(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "Keep",
            author: "User",
            context: modelContext
        )
        
        let comment2 = manager.createComment(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Delete",
            author: "User",
            context: modelContext
        )
        
        try modelContext.save()
        
        manager.deleteComment(comment2, context: modelContext)
        try modelContext.save()
        
        let comments = manager.getComments(forVersion: testVersion, context: modelContext)
        XCTAssertEqual(comments.count, 1)
        XCTAssertEqual(comments.first?.id, comment1.id)
    }
    
    // MARK: - Update Comment Positions Tests
    
    func testUpdateCommentPositionsInsert() throws {
        // Create comments at positions 10, 20, 30
        let comment1 = manager.createComment(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "First",
            author: "User",
            context: modelContext
        )
        
        let comment2 = manager.createComment(
            version: testVersion,
            characterPosition: 20,
            attachmentID: UUID(),
            text: "Second",
            author: "User",
            context: modelContext
        )
        
        let comment3 = manager.createComment(
            version: testVersion,
            characterPosition: 30,
            attachmentID: UUID(),
            text: "Third",
            author: "User",
            context: modelContext
        )
        
        try modelContext.save()
        
        // Insert 5 characters at position 15 (between first and second)
        manager.updatePositionsAfterEdit(
            version: testVersion,
            editPosition: 15,
            lengthDelta: 5,
            context: modelContext
        )
        try modelContext.save()
        
        // Reload comments
        let comments = manager.getComments(forVersion: testVersion, context: modelContext)
        let updated1 = comments.first { $0.id == comment1.id }
        let updated2 = comments.first { $0.id == comment2.id }
        let updated3 = comments.first { $0.id == comment3.id }
        
        // First comment should stay at 10 (before insertion)
        XCTAssertEqual(updated1?.characterPosition, 10)
        // Second and third should shift by +5
        XCTAssertEqual(updated2?.characterPosition, 25)
        XCTAssertEqual(updated3?.characterPosition, 35)
    }
    
    func testUpdateCommentPositionsDelete() throws {
        // Create comments at positions 10, 30, 50
        let comment1 = manager.createComment(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "First",
            author: "User",
            context: modelContext
        )
        
        let comment2 = manager.createComment(
            version: testVersion,
            characterPosition: 30,
            attachmentID: UUID(),
            text: "Second",
            author: "User",
            context: modelContext
        )
        
        let comment3 = manager.createComment(
            version: testVersion,
            characterPosition: 50,
            attachmentID: UUID(),
            text: "Third",
            author: "User",
            context: modelContext
        )
        
        try modelContext.save()
        
        // Delete 5 characters at position 20 (before second comment)
        manager.updatePositionsAfterEdit(
            version: testVersion,
            editPosition: 20,
            lengthDelta: -5,
            context: modelContext
        )
        try modelContext.save()
        
        // Reload comments
        let comments = manager.getComments(forVersion: testVersion, context: modelContext)
        let updated1 = comments.first { $0.id == comment1.id }
        let updated2 = comments.first { $0.id == comment2.id }
        let updated3 = comments.first { $0.id == comment3.id }
        
        // First comment should stay at 10 (before deletion)
        XCTAssertEqual(updated1?.characterPosition, 10)
        // Second and third should shift by -5
        XCTAssertEqual(updated2?.characterPosition, 25)
        XCTAssertEqual(updated3?.characterPosition, 45)
    }
    
    func testUpdatePositionsDoesNotAffectOtherFiles() throws {
        let otherVersion = Version(content: "Other content")
        modelContext.insert(otherVersion)
        
        // Create comment in test file
        _ = manager.createComment(
            version: testVersion,
            characterPosition: 20,
            attachmentID: UUID(),
            text: "Test file",
            author: "User",
            context: modelContext
        )
        
        // Create comment in other file
        _ = manager.createComment(
            version: otherVersion,
            characterPosition: 20,
            attachmentID: UUID(),
            text: "Other file",
            author: "User",
            context: modelContext
        )
        
        try modelContext.save()
        
        // Update positions only for test file
        manager.updatePositionsAfterEdit(
            version: testVersion,
            editPosition: 10,
            lengthDelta: 5,
            context: modelContext
        )
        try modelContext.save()
        
        // Reload comments
        let testComments = manager.getComments(forVersion: testVersion, context: modelContext)
        let otherComments = manager.getComments(forVersion: otherVersion, context: modelContext)
        
        // Test file comment should update
        XCTAssertEqual(testComments.first?.characterPosition, 25)
        // Other file comment should remain unchanged
        XCTAssertEqual(otherComments.first?.characterPosition, 20)
    }
    
    // MARK: - Edge Cases
    
    func testCreateCommentAtPositionZero() throws {
        let comment = manager.createComment(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "At start",
            author: "User",
            context: modelContext
        )
        
        XCTAssertEqual(comment.characterPosition, 0)
    }
    
    func testUpdatePositionsWithZeroDelta() throws {
        _ = manager.createComment(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Test",
            author: "User",
            context: modelContext
        )
        try modelContext.save()
        
        manager.updatePositionsAfterEdit(
            version: testVersion,
            editPosition: 5,
            lengthDelta: 0,
            context: modelContext
        )
        try modelContext.save()
        
        let comments = manager.getComments(forVersion: testVersion, context: modelContext)
        XCTAssertEqual(comments.first?.characterPosition, 10) // Should remain unchanged
    }
    
    func testMultipleFilesIndependence() throws {
        let version1 = Version(content: "File 1 content")
        let version2 = Version(content: "File 2 content")
        modelContext.insert(version1)
        modelContext.insert(version2)
        
        // Create comments in different files
        _ = manager.createComment(
            version: version1,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "File 1",
            author: "User",
            context: modelContext
        )
        
        _ = manager.createComment(
            version: version2,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "File 2",
            author: "User",
            context: modelContext
        )
        
        let file1Comments = manager.getComments(forVersion: version1, context: modelContext)
        let file2Comments = manager.getComments(forVersion: version2, context: modelContext)
        
        XCTAssertEqual(file1Comments.count, 1)
        XCTAssertEqual(file2Comments.count, 1)
        XCTAssertNotEqual(file1Comments.first?.version?.id, file2Comments.first?.version?.id)
    }
}
