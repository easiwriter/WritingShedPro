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
    ///   - version: The version this comment belongs to
    ///   - characterPosition: Position in the document
    ///   - attachmentID: ID of the text attachment
    ///   - text: Comment text content
    ///   - author: Author name
    ///   - context: SwiftData model context
    /// - Returns: The created CommentModel
    func createComment(
        version: Version,
        characterPosition: Int,
        attachmentID: UUID = UUID(),
        text: String,
        author: String,
        context: ModelContext
    ) -> CommentModel {
        let comment = CommentModel(
            version: version,
            characterPosition: characterPosition,
            attachmentID: attachmentID,
            text: text,
            author: author
        )
        
        context.insert(comment)
        
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("❌ Failed to save comment: \(error)")
            #endif
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
            #if DEBUG
            print("❌ Failed to update comment text: \(error)")
            #endif
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
            #if DEBUG
            print("❌ Failed to delete comment: \(error)")
            #endif
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
            #if DEBUG
            print("❌ Failed to resolve comment: \(error)")
            #endif
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
            #if DEBUG
            print("❌ Failed to reopen comment: \(error)")
            #endif
        }
    }
    
    // MARK: - Position Management
    
    /// Update comment positions after text edits
    /// - Parameters:
    ///   - version: The version being edited
    ///   - editPosition: Where the edit occurred
    ///   - lengthDelta: Change in text length (positive for insertions, negative for deletions)
    ///   - context: SwiftData model context
    func updatePositionsAfterEdit(
        version: Version,
        editPosition: Int,
        lengthDelta: Int,
        context: ModelContext
    ) {
        let comments = getComments(forVersion: version, context: context)
        
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
            #if DEBUG
            print("❌ Failed to update comment positions: \(error)")
            #endif
        }
    }
    
    // MARK: - Query Methods
    
    /// Get all comments for a specific version
    /// - Parameters:
    ///   - version: The version to get comments for
    ///   - context: SwiftData model context
    /// - Returns: Array of comments sorted by position
    func getComments(forVersion version: Version, context: ModelContext) -> [CommentModel] {
        // Use FetchDescriptor to query database directly instead of relying on cached relationship
        let versionID = version.id
        let descriptor = FetchDescriptor<CommentModel>(
            predicate: #Predicate { comment in
                comment.version?.id == versionID
            },
            sortBy: [SortDescriptor(\.characterPosition, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Get active (unresolved) comments for a version
    /// - Parameters:
    ///   - version: The version to get comments for
    ///   - context: SwiftData model context
    /// - Returns: Array of active comments sorted by position
    func getActiveComments(forVersion version: Version, context: ModelContext) -> [CommentModel] {
        // Use FetchDescriptor to query database directly instead of relying on cached relationship
        let versionID = version.id
        let descriptor = FetchDescriptor<CommentModel>(
            predicate: #Predicate { comment in
                comment.version?.id == versionID && comment.resolvedAt == nil
            },
            sortBy: [SortDescriptor(\.characterPosition, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Get resolved comments for a version
    /// - Parameters:
    ///   - version: The version to get comments for
    ///   - context: SwiftData model context
    /// - Returns: Array of resolved comments sorted by position
    func getResolvedComments(forVersion version: Version, context: ModelContext) -> [CommentModel] {
        // Use FetchDescriptor to query database directly instead of relying on cached relationship
        let versionID = version.id
        let descriptor = FetchDescriptor<CommentModel>(
            predicate: #Predicate { comment in
                comment.version?.id == versionID && comment.resolvedAt != nil
            },
            sortBy: [SortDescriptor(\.characterPosition, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Get comment count for a version
    /// - Parameters:
    ///   - version: The version to get comments for
    ///   - includeResolved: Whether to include resolved comments
    ///   - context: SwiftData model context
    /// - Returns: Number of comments
    func getCommentCount(forVersion version: Version, includeResolved: Bool = true, context: ModelContext) -> Int {
        if includeResolved {
            return version.comments?.count ?? 0
        } else {
            return getActiveComments(forVersion: version, context: context).count
        }
    }
}
