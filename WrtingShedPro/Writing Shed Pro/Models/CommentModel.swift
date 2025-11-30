//
//  CommentModel.swift
//  Writing Shed Pro
//
//  Feature 014: Comments
//  Created by GitHub Copilot on 20/11/2025.
//  UPDATED: 23 November 2025 - Changed to use SwiftData relationships
//

import Foundation
import SwiftData

/// Represents a comment attached to a specific position in a text document version
/// ARCHITECTURE: Comments belong to a specific Version, not TextFile
/// This allows comments to be version-specific and properly cascade when versions are deleted
@Model
@Syncable
final class CommentModel {
    /// Unique identifier for the comment
    var id: UUID = UUID()
    
    /// The Version this comment belongs to (replaces textFileID)
    /// Inverse relationship defined in Version.comments
    var version: Version?
    
    /// Character position in the document where the comment is attached
    var characterPosition: Int = 0
    
    /// ID of the NSTextAttachment in the attributed string
    var attachmentID: UUID = UUID()
    
    /// The comment text content
    var text: String = ""
    
    /// Author of the comment (user name or identifier)
    var author: String = ""
    
    /// When the comment was created
    var createdAt: Date = Date()
    
    /// When the comment was resolved (nil if still active)
    var resolvedAt: Date?
    
    /// Computed property to check if comment is resolved
    var isResolved: Bool {
        resolvedAt != nil
    }
    
    /// Initialize a new comment
    init(
        id: UUID = UUID(),
        version: Version,
        characterPosition: Int,
        attachmentID: UUID = UUID(),
        text: String,
        author: String,
        createdAt: Date = Date(),
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.version = version
        self.characterPosition = characterPosition
        self.attachmentID = attachmentID
        self.text = text
        self.author = author
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
    }
    
    /// Mark the comment as resolved
    func resolve() {
        resolvedAt = Date()
    }
    
    /// Reopen a resolved comment
    func reopen() {
        resolvedAt = nil
    }
    
    /// Update the comment text
    func updateText(_ newText: String) {
        text = newText
    }
    
    /// Update the character position (when text is edited)
    func updatePosition(_ newPosition: Int) {
        characterPosition = newPosition
    }
}
