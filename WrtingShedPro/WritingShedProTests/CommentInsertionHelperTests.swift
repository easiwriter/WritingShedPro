//
//  CommentInsertionHelperTests.swift
//  Writing Shed Pro Tests
//
//  Feature 014: Comments - Unit tests for CommentInsertionHelper
//

import XCTest
import SwiftData
import UIKit
@testable import Writing_Shed_Pro

@MainActor
final class CommentInsertionHelperTests: XCTestCase {
    
    var modelContext: ModelContext!
    var testVersion: Version!
    
    override func setUpWithError() throws {
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
        
        testVersion = Version(content: "Test content")
        modelContext.insert(testVersion)
    }
    
    override func tearDownWithError() throws {
        modelContext = nil
        testVersion = nil
    }
    
    // MARK: - Insert Comment Tests
    
    func testInsertCommentInAttributedString() throws {
        let originalText = NSAttributedString(string: "Hello World")
        let position = 5 // After "Hello"
        
        let (resultString, comment) = CommentInsertionHelper.insertComment(
            in: originalText,
            at: position,
            commentText: "Test comment",
            author: "Test User",
            version: testVersion,
            context: modelContext
        )
        
        // Check that comment was created
        XCTAssertEqual(comment.text, "Test comment")
        XCTAssertEqual(comment.author, "Test User")
        XCTAssertEqual(comment.version?.id, testVersion.id)
        XCTAssertEqual(comment.characterPosition, position)
        
        // Check that attachment was inserted
        XCTAssertEqual(resultString.length, originalText.length + 1) // +1 for attachment
        
        // Verify attachment exists at correct position
        let attachment = resultString.attribute(
            .attachment,
            at: position,
            effectiveRange: nil
        ) as? CommentAttachment
        
        XCTAssertNotNil(attachment)
        XCTAssertEqual(attachment?.commentID, comment.attachmentID)
        XCTAssertFalse(attachment?.isResolved ?? true)
    }
    
    func testInsertCommentAtStart() throws {
        let originalText = NSAttributedString(string: "Hello")
        
        let (resultString, comment) = CommentInsertionHelper.insertComment(
            in: originalText,
            at: 0,
            commentText: "Start comment",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(comment.characterPosition, 0)
        XCTAssertEqual(resultString.length, 6) // 5 chars + 1 attachment
        
        // Attachment should be at position 0
        let attachment = resultString.attribute(.attachment, at: 0, effectiveRange: nil) as? CommentAttachment
        XCTAssertNotNil(attachment)
    }
    
    func testInsertCommentAtEnd() throws {
        let originalText = NSAttributedString(string: "Hello")
        let position = originalText.length
        
        let (resultString, comment) = CommentInsertionHelper.insertComment(
            in: originalText,
            at: position,
            commentText: "End comment",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(comment.characterPosition, position)
        XCTAssertEqual(resultString.length, 6)
        
        // Attachment should be at the end
        let attachment = resultString.attribute(.attachment, at: 5, effectiveRange: nil) as? CommentAttachment
        XCTAssertNotNil(attachment)
    }
    
    func testInsertMultipleComments() throws {
        let originalText = NSAttributedString(string: "Hello World")
        
        // Insert first comment
        let (afterFirst, comment1) = CommentInsertionHelper.insertComment(
            in: originalText,
            at: 5,
            commentText: "First",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        // Insert second comment (adjust position for first attachment)
        let (final, comment2) = CommentInsertionHelper.insertComment(
            in: afterFirst,
            at: 7, // After " W" including first attachment
            commentText: "Second",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(final.length, 13) // 11 chars + 2 attachments
        
        // Verify both attachments exist
        let attachment1 = final.attribute(.attachment, at: 5, effectiveRange: nil) as? CommentAttachment
        let attachment2 = final.attribute(.attachment, at: 7, effectiveRange: nil) as? CommentAttachment
        
        XCTAssertNotNil(attachment1)
        XCTAssertNotNil(attachment2)
        XCTAssertEqual(attachment1?.commentID, comment1.attachmentID)
        XCTAssertEqual(attachment2?.commentID, comment2.attachmentID)
    }
    
    func testInsertCommentPreservesFormatting() throws {
        let originalText = NSMutableAttributedString(string: "Hello World")
        originalText.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 20), range: NSRange(location: 0, length: 5))
        originalText.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 6, length: 5))
        
        let (resultString, _) = CommentInsertionHelper.insertComment(
            in: originalText,
            at: 5,
            commentText: "Test",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        // Check that original formatting is preserved
        let fontAtStart = resultString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(fontAtStart?.pointSize, 20)
        
        let colorAfterAttachment = resultString.attribute(.foregroundColor, at: 7, effectiveRange: nil) as? UIColor
        XCTAssertEqual(colorAfterAttachment, UIColor.red)
    }
    
    // MARK: - Insert Comment at Cursor Tests
    
    func testInsertCommentAtCursor() throws {
        let textView = UITextView()
        textView.text = "Hello World"
        textView.selectedRange = NSRange(location: 5, length: 0)
        
        let comment = CommentInsertionHelper.insertCommentAtCursor(
            in: textView,
            commentText: "Cursor comment",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertNotNil(comment)
        XCTAssertEqual(comment?.characterPosition, 5)
        XCTAssertEqual(comment?.text, "Cursor comment")
        
        // Check that textView was updated
        XCTAssertEqual(textView.attributedText.length, 12) // 11 chars + 1 attachment
        
        let attachment = textView.attributedText.attribute(.attachment, at: 5, effectiveRange: nil) as? CommentAttachment
        XCTAssertNotNil(attachment)
    }
    
    func testInsertCommentAtCursorWithSelection() throws {
        let textView = UITextView()
        textView.text = "Hello World"
        textView.selectedRange = NSRange(location: 6, length: 5) // "World" selected
        
        let comment = CommentInsertionHelper.insertCommentAtCursor(
            in: textView,
            commentText: "Selection comment",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertNotNil(comment)
        // Should insert at start of selection
        XCTAssertEqual(comment?.characterPosition, 6)
    }
    
    func testInsertCommentInEmptyTextView() throws {
        let textView = UITextView()
        textView.text = ""
        textView.selectedRange = NSRange(location: 0, length: 0)
        
        let comment = CommentInsertionHelper.insertCommentAtCursor(
            in: textView,
            commentText: "Empty comment",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertNotNil(comment)
        XCTAssertEqual(comment?.characterPosition, 0)
        XCTAssertEqual(textView.attributedText.length, 1) // Just the attachment
    }
    
    // MARK: - Update Comment Resolved State Tests
    
    func testUpdateCommentResolvedState() throws {
        // Create attributed string with a comment
        let originalText = NSAttributedString(string: "Hello")
        let (stringWithComment, comment) = CommentInsertionHelper.insertComment(
            in: originalText,
            at: 2,
            commentText: "Test",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        // Update to resolved
        let updatedString = CommentInsertionHelper.updateCommentResolvedState(
            in: stringWithComment,
            commentID: comment.attachmentID,
            isResolved: true
        )
        
        // Check that attachment was updated
        let attachment = updatedString.attribute(.attachment, at: 2, effectiveRange: nil) as? CommentAttachment
        XCTAssertNotNil(attachment)
        XCTAssertTrue(attachment?.isResolved ?? false)
        XCTAssertEqual(attachment?.commentID, comment.attachmentID)
    }
    
    func testUpdateNonexistentComment() throws {
        let text = NSAttributedString(string: "Hello World")
        let fakeID = UUID()
        
        let result = CommentInsertionHelper.updateCommentResolvedState(
            in: text,
            commentID: fakeID,
            isResolved: true
        )
        
        // Should return unchanged string
        XCTAssertEqual(result.length, text.length)
        XCTAssertEqual(result.string, text.string)
    }
    
    func testUpdateMultipleComments() throws {
        let originalText = NSAttributedString(string: "Hello World")
        
        // Insert two comments
        let (afterFirst, comment1) = CommentInsertionHelper.insertComment(
            in: originalText,
            at: 5,
            commentText: "First",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        let (withBoth, comment2) = CommentInsertionHelper.insertComment(
            in: afterFirst,
            at: 7,
            commentText: "Second",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        // Resolve only the second one
        let result = CommentInsertionHelper.updateCommentResolvedState(
            in: withBoth,
            commentID: comment2.attachmentID,
            isResolved: true
        )
        
        // Check first is still active
        let attachment1 = result.attribute(.attachment, at: 5, effectiveRange: nil) as? CommentAttachment
        XCTAssertFalse(attachment1?.isResolved ?? true)
        
        // Check second is resolved
        let attachment2 = result.attribute(.attachment, at: 7, effectiveRange: nil) as? CommentAttachment
        XCTAssertTrue(attachment2?.isResolved ?? false)
    }
    
    // MARK: - Remove Comment Tests
    
    func testRemoveComment() throws {
        // Create string with comment
        let originalText = NSAttributedString(string: "Hello World")
        let (withComment, comment) = CommentInsertionHelper.insertComment(
            in: originalText,
            at: 5,
            commentText: "Test",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(withComment.length, 12) // 11 + 1 attachment
        
        // Remove the comment
        let result = CommentInsertionHelper.removeComment(
            from: withComment,
            commentID: comment.attachmentID
        )
        
        XCTAssertEqual(result.length, 11) // Back to original length
        XCTAssertEqual(result.string, "Hello World")
        
        // Verify no attachment exists
        var foundAttachment = false
        result.enumerateAttribute(.attachment, in: NSRange(location: 0, length: result.length), options: []) { value, range, stop in
            if let attachment = value as? CommentAttachment {
                if attachment.commentID == comment.attachmentID {
                    foundAttachment = true
                }
            }
        }
        XCTAssertFalse(foundAttachment)
    }
    
    func testRemoveCommentFromMultiple() throws {
        let originalText = NSAttributedString(string: "Hello World")
        
        // Insert two comments
        let (afterFirst, comment1) = CommentInsertionHelper.insertComment(
            in: originalText,
            at: 5,
            commentText: "First",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        let (withBoth, comment2) = CommentInsertionHelper.insertComment(
            in: afterFirst,
            at: 7,
            commentText: "Second",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(withBoth.length, 13) // 11 + 2 attachments
        
        // Remove only the first comment
        let result = CommentInsertionHelper.removeComment(
            from: withBoth,
            commentID: comment1.attachmentID
        )
        
        XCTAssertEqual(result.length, 12) // 11 + 1 attachment
        
        // First should be gone
        let attachment1 = result.attribute(.attachment, at: 5, effectiveRange: nil) as? CommentAttachment
        XCTAssertNil(attachment1)
        
        // Second should still exist (now at position 6)
        let attachment2 = result.attribute(.attachment, at: 6, effectiveRange: nil) as? CommentAttachment
        XCTAssertNotNil(attachment2)
        XCTAssertEqual(attachment2?.commentID, comment2.attachmentID)
    }
    
    func testRemoveNonexistentComment() throws {
        let originalText = NSAttributedString(string: "Hello")
        let fakeID = UUID()
        
        let result = CommentInsertionHelper.removeComment(
            from: originalText,
            commentID: fakeID
        )
        
        // Should return unchanged string
        XCTAssertEqual(result.length, originalText.length)
        XCTAssertEqual(result.string, originalText.string)
    }
    
    // MARK: - Comment Attachment at Position Tests
    
    func testCommentAttachmentAtPosition() throws {
        let originalText = NSAttributedString(string: "Hello World")
        let (withComment, comment) = CommentInsertionHelper.insertComment(
            in: originalText,
            at: 5,
            commentText: "Test",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        let attachment = CommentInsertionHelper.commentAttachment(in: withComment, at: 5)
        
        XCTAssertNotNil(attachment)
        XCTAssertEqual(attachment?.commentID, comment.attachmentID)
    }
    
    func testCommentAttachmentAtWrongPosition() throws {
        let originalText = NSAttributedString(string: "Hello World")
        let (withComment, _) = CommentInsertionHelper.insertComment(
            in: originalText,
            at: 5,
            commentText: "Test",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        // Check position without attachment
        let attachment = CommentInsertionHelper.commentAttachment(in: withComment, at: 0)
        
        XCTAssertNil(attachment)
    }
    
    // MARK: - All Comment Attachments Tests
    
    func testAllCommentAttachments() throws {
        let originalText = NSAttributedString(string: "Hello World")
        
        // Insert three comments
        let (after1, comment1) = CommentInsertionHelper.insertComment(
            in: originalText,
            at: 0,
            commentText: "First",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        let (after2, comment2) = CommentInsertionHelper.insertComment(
            in: after1,
            at: 6,
            commentText: "Second",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        let (final, comment3) = CommentInsertionHelper.insertComment(
            in: after2,
            at: 13,
            commentText: "Third",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        let allAttachments = CommentInsertionHelper.allCommentAttachments(in: final)
        
        XCTAssertEqual(allAttachments.count, 3)
        
        let commentIDs = allAttachments.map { $0.0.commentID }
        XCTAssertTrue(commentIDs.contains(comment1.attachmentID))
        XCTAssertTrue(commentIDs.contains(comment2.attachmentID))
        XCTAssertTrue(commentIDs.contains(comment3.attachmentID))
        
        // Check positions are correct
        XCTAssertEqual(allAttachments[0].1, 0)
        XCTAssertEqual(allAttachments[1].1, 6)
        XCTAssertEqual(allAttachments[2].1, 13)
    }
    
    func testAllCommentAttachmentsEmpty() throws {
        let text = NSAttributedString(string: "No comments here")
        
        let attachments = CommentInsertionHelper.allCommentAttachments(in: text)
        
        XCTAssertEqual(attachments.count, 0)
    }
    
    // MARK: - Edge Cases
    
    func testInsertCommentInEmptyString() throws {
        let emptyText = NSAttributedString(string: "")
        
        let (result, comment) = CommentInsertionHelper.insertComment(
            in: emptyText,
            at: 0,
            commentText: "Empty string comment",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(result.length, 1)
        XCTAssertEqual(comment.characterPosition, 0)
    }
    
    func testInsertCommentWithEmptyText() throws {
        let text = NSAttributedString(string: "Hello")
        
        let (result, comment) = CommentInsertionHelper.insertComment(
            in: text,
            at: 2,
            commentText: "",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(comment.text, "")
        XCTAssertEqual(result.length, 6) // Attachment still inserted
    }
    
    func testRemoveAllComments() throws {
        let originalText = NSAttributedString(string: "Test")
        
        // Add multiple comments
        let (after1, comment1) = CommentInsertionHelper.insertComment(
            in: originalText,
            at: 0,
            commentText: "1",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        let (after2, comment2) = CommentInsertionHelper.insertComment(
            in: after1,
            at: 2,
            commentText: "2",
            author: "User",
            version: testVersion,
            context: modelContext
        )
        
        // Remove all
        let afterRemove1 = CommentInsertionHelper.removeComment(from: after2, commentID: comment1.attachmentID)
        let final = CommentInsertionHelper.removeComment(from: afterRemove1, commentID: comment2.attachmentID)
        
        XCTAssertEqual(final.length, 4)
        XCTAssertEqual(final.string, "Test")
        XCTAssertEqual(CommentInsertionHelper.allCommentAttachments(in: final).count, 0)
    }
}
