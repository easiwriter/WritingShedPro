//
//  CommentManager.swift
//  Writing Shed Pro
//
//  Feature 014: Comments
//  Created by GitHub Copilot on 20/11/2025.
//

import Foundation
import SwiftData
import SwiftUI

/// Manages comment operations including CRUD, position tracking, and queries
@MainActor
final class CommentManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = CommentManager()
    
    private init() {}
    
    // MARK: - CRUD Operations
    
    /// Create a new comment and save it to the database
    /// - Parameters:
    ///   - textFileID: ID of the text file
    ///   - characterPosition: Position in the document
    ///   - attachmentID: ID of the text attachment
    ///   - text: Comment text content
    ///   - author: Author name
    ///   - context: SwiftData model context
    /// - Returns: The created CommentModel
    func createComment(
        textFileID: UUID,
        characterPosition: Int,
        attachmentID: UUID = UUID(),
        text: String,
        author: String,
        context: ModelContext
    ) -> CommentModel {
        let comment = CommentModel(
            textFileID: textFileID,
            characterPosition: characterPosition,
            attachmentID: attachmentID,
            text: text,
            author: author
        )
        
        context.insert(comment)
        
        do {
            try context.save()
        } catch {
            print("❌ Failed to save comment: \(error)")
        }
        
        return comment
    }
    
    /// Fetch a comment by its ID
    /// - Parameters:
    ///   - id: Comment ID
    ///   - context: SwiftData model context
    /// - Returns: The comment if found
    func getComment(id: UUID, context: ModelContext) -> CommentModel? {
        let descriptor = FetchDescriptor<CommentModel>(
            predicate: #Predicate { comment in
                comment.id == id
            }
        )
        
        return try? context.fetch(descriptor).first
    }
    
    /// Fetch a comment by its attachment ID
    /// - Parameters:
    ///   - attachmentID: Attachment ID
    ///   - context: SwiftData model context
    /// - Returns: The comment if found
    func getCommentByAttachment(attachmentID: UUID, context: ModelContext) -> CommentModel? {
        let descriptor = FetchDescriptor<CommentModel>(
            predicate: #Predicate { comment in
                comment.attachmentID == attachmentID
            }
        )
        
        return try? context.fetch(descriptor).first
    }
    
    /// Update comment text
    /// - Parameters:
    ///   - comment: The comment to update
    ///   - newText: New text content
    ///   - context: SwiftData model context
    func updateCommentText(_ comment: CommentModel, newText: String, context: ModelContext) {
        comment.updateText(newText)
        
        do {
            try context.save()
        } catch {
            print("❌ Failed to update comment text: \(error)")
        }
    }
    
    /// Delete a comment
    /// - Parameters:
    ///   - comment: The comment to delete
    ///   - context: SwiftData model context
    func deleteComment(_ comment: CommentModel, context: ModelContext) {
        context.delete(comment)
        
        do {
            try context.save()
        } catch {
            print("❌ Failed to delete comment: \(error)")
        }
    }
    
    /// Resolve a comment
    /// - Parameters:
    ///   - comment: The comment to resolve
    ///   - context: SwiftData model context
    func resolveComment(_ comment: CommentModel, context: ModelContext) {
        comment.resolve()
        
        do {
            try context.save()
        } catch {
            print("❌ Failed to resolve comment: \(error)")
        }
    }
    
    /// Reopen a resolved comment
    /// - Parameters:
    ///   - comment: The comment to reopen
    ///   - context: SwiftData model context
    func reopenComment(_ comment: CommentModel, context: ModelContext) {
        comment.reopen()
        
        do {
            try context.save()
        } catch {
            print("❌ Failed to reopen comment: \(error)")
        }
    }
    
    // MARK: - Position Management
    
    /// Update comment positions after text edits
    /// - Parameters:
    ///   - textFileID: ID of the text file
    ///   - editPosition: Where the edit occurred
    ///   - lengthDelta: Change in text length (positive for insertions, negative for deletions)
    ///   - context: SwiftData model context
    func updatePositionsAfterEdit(
        textFileID: UUID,
        editPosition: Int,
        lengthDelta: Int,
        context: ModelContext
    ) {
        let comments = getComments(forTextFile: textFileID, context: context)
        
        for comment in comments {
            // Only update positions after the edit point
            if comment.characterPosition >= editPosition {
                let newPosition = max(editPosition, comment.characterPosition + lengthDelta)
                comment.updatePosition(newPosition)
            }
        }
        
        do {
            try context.save()
        } catch {
            print("❌ Failed to update comment positions: \(error)")
        }
    }
    
    // MARK: - Query Methods
    
    /// Get all comments for a specific text file
    /// - Parameters:
    ///   - textFileID: ID of the text file
    ///   - context: SwiftData model context
    /// - Returns: Array of comments sorted by position
    func getComments(forTextFile textFileID: UUID, context: ModelContext) -> [CommentModel] {
        let descriptor = FetchDescriptor<CommentModel>(
            predicate: #Predicate { comment in
                comment.textFileID == textFileID
            },
            sortBy: [SortDescriptor(\.characterPosition)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Get active (unresolved) comments for a text file
    /// - Parameters:
    ///   - textFileID: ID of the text file
    ///   - context: SwiftData model context
    /// - Returns: Array of active comments sorted by position
    func getActiveComments(forTextFile textFileID: UUID, context: ModelContext) -> [CommentModel] {
        let descriptor = FetchDescriptor<CommentModel>(
            predicate: #Predicate { comment in
                comment.textFileID == textFileID && comment.resolvedAt == nil
            },
            sortBy: [SortDescriptor(\.characterPosition)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Get resolved comments for a text file
    /// - Parameters:
    ///   - textFileID: ID of the text file
    ///   - context: SwiftData model context
    /// - Returns: Array of resolved comments sorted by position
    func getResolvedComments(forTextFile textFileID: UUID, context: ModelContext) -> [CommentModel] {
        let descriptor = FetchDescriptor<CommentModel>(
            predicate: #Predicate { comment in
                comment.textFileID == textFileID && comment.resolvedAt != nil
            },
            sortBy: [SortDescriptor(\.characterPosition)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Get comment count for a text file
    /// - Parameters:
    ///   - textFileID: ID of the text file
    ///   - includeResolved: Whether to include resolved comments
    ///   - context: SwiftData model context
    /// - Returns: Number of comments
    func getCommentCount(forTextFile textFileID: UUID, includeResolved: Bool = true, context: ModelContext) -> Int {
        if includeResolved {
            return getComments(forTextFile: textFileID, context: context).count
        } else {
            return getActiveComments(forTextFile: textFileID, context: context).count
        }
    }
}
