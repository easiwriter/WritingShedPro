//
//  CommentModel.swift
//  Writing Shed Pro
//
//  Feature 014: Comments
//  Created by GitHub Copilot on 20/11/2025.
//

import Foundation
import SwiftData

/// Represents a comment attached to a specific position in a text document
@Model
final class CommentModel {
    /// Unique identifier for the comment
    var id: UUID = UUID()
    
    /// ID of the TextFile this comment belongs to
    var textFileID: UUID = UUID()
    
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
        textFileID: UUID,
        characterPosition: Int,
        attachmentID: UUID = UUID(),
        text: String,
        author: String,
        createdAt: Date = Date(),
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.textFileID = textFileID
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
