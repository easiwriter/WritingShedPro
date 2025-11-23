//
//  FootnoteModel.swift
//  Writing Shed Pro
//
//  Feature 015: Footnotes
//  Created by GitHub Copilot on 21/11/2025.
//  UPDATED: 23 November 2025 - Changed to use SwiftData relationships
//

import Foundation
import SwiftData

/// Represents a footnote attached to a specific position in a text document version
/// ARCHITECTURE: Footnotes belong to a specific Version, not TextFile
/// This allows footnotes to be version-specific and properly cascade when versions are deleted
@Model
final class FootnoteModel {
    /// Unique identifier for the footnote
    var id: UUID = UUID()
    
    /// The Version this footnote belongs to (replaces textFileID)
    /// Inverse relationship defined in Version.footnotes
    var version: Version?
    
    /// Character position in the document where the footnote marker appears
    var characterPosition: Int = 0
    
    /// ID of the NSTextAttachment for the marker
    var attachmentID: UUID = UUID()
    
    /// The footnote content/text (supports rich text formatting)
    var text: String = ""
    
    /// Footnote number (for display, automatically assigned)
    var number: Int = 0
    
    /// When the footnote was created
    var createdAt: Date = Date()
    
    /// When the footnote was last modified
    var modifiedAt: Date = Date()
    
    /// Whether the footnote has been deleted (soft delete for trash)
    var isDeleted: Bool = false
    
    /// When the footnote was deleted (for trash functionality)
    var deletedAt: Date?
    
    /// Initialize a new footnote
    init(
        id: UUID = UUID(),
        version: Version,
        characterPosition: Int,
        attachmentID: UUID = UUID(),
        text: String,
        number: Int,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.version = version
        self.characterPosition = characterPosition
        self.attachmentID = attachmentID
        self.text = text
        self.number = number
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
    }
    
    /// Update the footnote text
    func updateText(_ newText: String) {
        text = newText
        modifiedAt = Date()
    }
    
    /// Update the footnote number
    func updateNumber(_ newNumber: Int) {
        number = newNumber
        modifiedAt = Date()
    }
    
    /// Update the character position (when text is edited)
    func updatePosition(_ newPosition: Int) {
        characterPosition = newPosition
        modifiedAt = Date()
    }
    
    /// Move to trash (soft delete)
    func moveToTrash() {
        isDeleted = true
        deletedAt = Date()
        modifiedAt = Date()
    }
    
    /// Restore from trash
    func restoreFromTrash() {
        isDeleted = false
        deletedAt = nil
        modifiedAt = Date()
    }
    
    /// Permanently delete (called when emptying trash)
    /// Note: Actual deletion handled by SwiftData context
    func prepareForPermanentDeletion() {
        // Cleanup any references before permanent deletion
        // This is called before context.delete()
    }
}

// MARK: - Comparable for sorting by position
extension FootnoteModel: Comparable {
    static func < (lhs: FootnoteModel, rhs: FootnoteModel) -> Bool {
        lhs.characterPosition < rhs.characterPosition
    }
}

// MARK: - CustomStringConvertible for debugging
extension FootnoteModel: CustomStringConvertible {
    var description: String {
        "Footnote #\(number) at position \(characterPosition): \"\(text.prefix(30))...\""
    }
}
