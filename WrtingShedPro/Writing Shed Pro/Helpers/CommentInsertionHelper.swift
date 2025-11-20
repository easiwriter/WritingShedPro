//
//  CommentInsertionHelper.swift
//  Writing Shed Pro
//
//  Feature 014: Comments
//  Created by GitHub Copilot on 20/11/2025.
//

import Foundation
import UIKit
import SwiftData

/// Helper methods for inserting and managing comment attachments in attributed text
struct CommentInsertionHelper {
    
    // MARK: - Insertion
    
    /// Insert a comment attachment at the specified position
    /// - Parameters:
    ///   - attributedText: The attributed string to modify
    ///   - position: Character position where to insert the comment
    ///   - commentText: The comment text content
    ///   - author: Author of the comment
    ///   - textFileID: ID of the text file
    ///   - context: SwiftData model context
    /// - Returns: Tuple of (updated attributed string, created CommentModel)
    @MainActor
    static func insertComment(
        in attributedText: NSAttributedString,
        at position: Int,
        commentText: String,
        author: String,
        textFileID: UUID,
        context: ModelContext
    ) -> (NSAttributedString, CommentModel) {
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        
        // Create the comment attachment
        let attachmentID = UUID()
        let attachment = CommentAttachment(commentID: attachmentID, isResolved: false)
        
        // Create attributed string with the attachment
        let attachmentString = NSAttributedString(attachment: attachment)
        
        // Insert at the specified position
        let safePosition = min(max(0, position), mutableText.length)
        mutableText.insert(attachmentString, at: safePosition)
        
        // Create the comment model in the database
        let comment = CommentManager.shared.createComment(
            textFileID: textFileID,
            characterPosition: safePosition,
            attachmentID: attachmentID,
            text: commentText,
            author: author,
            context: context
        )
        
        return (mutableText, comment)
    }
    
    /// Insert a comment at the current cursor position in a UITextView
    /// - Parameters:
    ///   - textView: The text view
    ///   - commentText: The comment text content
    ///   - author: Author of the comment
    ///   - textFileID: ID of the text file
    ///   - context: SwiftData model context
    /// - Returns: The created CommentModel
    @MainActor
    @discardableResult
    static func insertCommentAtCursor(
        in textView: UITextView,
        commentText: String,
        author: String,
        textFileID: UUID,
        context: ModelContext
    ) -> CommentModel? {
        let textStorage = textView.textStorage
        
        let insertPosition = textView.selectedRange.location
        
        // Create the comment attachment
        let attachmentID = UUID()
        let attachment = CommentAttachment(commentID: attachmentID, isResolved: false)
        
        // Create attributed string with the attachment
        let attachmentString = NSAttributedString(attachment: attachment)
        
        // Insert at cursor
        textStorage.insert(attachmentString, at: insertPosition)
        
        // Move cursor after the attachment
        textView.selectedRange = NSRange(location: insertPosition + 1, length: 0)
        
        // Create the comment model in the database
        let comment = CommentManager.shared.createComment(
            textFileID: textFileID,
            characterPosition: insertPosition,
            attachmentID: attachmentID,
            text: commentText,
            author: author,
            context: context
        )
        
        return comment
    }
    
    // MARK: - Updating
    
    /// Update a comment attachment's resolved state
    /// - Parameters:
    ///   - attributedText: The attributed string containing the comment
    ///   - commentID: ID of the comment to update
    ///   - isResolved: New resolved state
    /// - Returns: Updated attributed string
    static func updateCommentResolvedState(
        in attributedText: NSAttributedString,
        commentID: UUID,
        isResolved: Bool
    ) -> NSAttributedString {
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        
        // Find the attachment
        var attachmentRange: NSRange?
        var foundAttachment: CommentAttachment?
        
        mutableText.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: mutableText.length),
            options: []
        ) { value, range, stop in
            if let attachment = value as? CommentAttachment,
               attachment.commentID == commentID {
                attachmentRange = range
                foundAttachment = attachment
                stop.pointee = true
            }
        }
        
        guard let range = attachmentRange,
              let _ = foundAttachment else {
            return attributedText
        }
        
        // Create new attachment with updated state
        let newAttachment = CommentAttachment(commentID: commentID, isResolved: isResolved)
        let newAttachmentString = NSAttributedString(attachment: newAttachment)
        
        // Replace the old attachment
        mutableText.replaceCharacters(in: range, with: newAttachmentString)
        
        return mutableText
    }
    
    /// Remove a comment attachment from the attributed text
    /// - Parameters:
    ///   - attributedText: The attributed string containing the comment
    ///   - commentID: ID of the comment to remove
    /// - Returns: Updated attributed string
    static func removeComment(
        from attributedText: NSAttributedString,
        commentID: UUID
    ) -> NSAttributedString {
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        
        // Find and remove the attachment
        var attachmentRange: NSRange?
        
        mutableText.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: mutableText.length),
            options: []
        ) { value, range, stop in
            if let attachment = value as? CommentAttachment,
               attachment.commentID == commentID {
                attachmentRange = range
                stop.pointee = true
            }
        }
        
        if let range = attachmentRange {
            mutableText.deleteCharacters(in: range)
        }
        
        return mutableText
    }
    
    // MARK: - Detection
    
    /// Find the comment at a specific character position
    /// - Parameters:
    ///   - attributedText: The attributed string to search
    ///   - position: Character position to check
    /// - Returns: CommentAttachment if found at that position
    static func commentAttachment(
        in attributedText: NSAttributedString,
        at position: Int
    ) -> CommentAttachment? {
        guard position >= 0 && position < attributedText.length else {
            return nil
        }
        
        return attributedText.attribute(.attachment, at: position, effectiveRange: nil) as? CommentAttachment
    }
    
    /// Get all comment attachments in the attributed text
    /// - Parameter attributedText: The attributed string to search
    /// - Returns: Array of tuples containing (attachment, position)
    static func allCommentAttachments(
        in attributedText: NSAttributedString
    ) -> [(CommentAttachment, Int)] {
        var attachments: [(CommentAttachment, Int)] = []
        
        attributedText.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributedText.length),
            options: []
        ) { value, range, _ in
            if let attachment = value as? CommentAttachment {
                attachments.append((attachment, range.location))
            }
        }
        
        return attachments
    }
}
