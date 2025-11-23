//
//  FootnoteManager.swift
//  Writing Shed Pro
//
//  Feature 017: Footnotes
//  Created by GitHub Copilot on 21/11/2025.
//

import Foundation
import SwiftData
import SwiftUI

/// Manages footnote operations including CRUD, numbering, position tracking, and queries
@MainActor
final class FootnoteManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = FootnoteManager()
    
    private init() {}
    
    // MARK: - CRUD Operations
    
    /// Create a new footnote and save it to the database
    /// - Parameters:
    ///   - textFileID: ID of the text file
    ///   - characterPosition: Position in the document
    ///   - attachmentID: ID of the text attachment
    ///   - text: Footnote text content
    ///   - context: SwiftData model context
    /// - Returns: The created FootnoteModel
    func createFootnote(
        textFileID: UUID,
        characterPosition: Int,
        attachmentID: UUID = UUID(),
        text: String,
        context: ModelContext
    ) -> FootnoteModel {
        // Determine the footnote number based on current position
        let number = calculateFootnoteNumber(
            forTextFile: textFileID,
            at: characterPosition,
            context: context
        )
        
        let footnote = FootnoteModel(
            textFileID: textFileID,
            characterPosition: characterPosition,
            attachmentID: attachmentID,
            text: text,
            number: number
        )
        
        context.insert(footnote)
        
        do {
            try context.save()
            // Renumber all footnotes after insertion
            renumberFootnotes(forTextFile: textFileID, context: context)
        } catch {
            print("❌ Failed to save footnote: \(error)")
        }
        
        return footnote
    }
    
    /// Fetch a footnote by its ID
    /// - Parameters:
    ///   - id: Footnote ID
    ///   - context: SwiftData model context
    /// - Returns: The footnote if found
    func getFootnote(id: UUID, context: ModelContext) -> FootnoteModel? {
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { footnote in
                footnote.id == id
            }
        )
        
        return try? context.fetch(descriptor).first
    }
    
    /// Fetch a footnote by its attachment ID
    /// - Parameters:
    ///   - attachmentID: Attachment ID
    ///   - context: SwiftData model context
    /// - Returns: The footnote if found
    func getFootnoteByAttachment(attachmentID: UUID, context: ModelContext) -> FootnoteModel? {
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { footnote in
                footnote.attachmentID == attachmentID
            }
        )
        
        return try? context.fetch(descriptor).first
    }
    
    /// Update footnote text
    /// - Parameters:
    ///   - footnote: The footnote to update
    ///   - newText: New text content
    ///   - context: SwiftData model context
    func updateFootnoteText(_ footnote: FootnoteModel, newText: String, context: ModelContext) {
        footnote.updateText(newText)
        
        do {
            try context.save()
        } catch {
            print("❌ Failed to update footnote text: \(error)")
        }
    }
    
    /// Move footnote to trash (soft delete)
    /// - Parameters:
    ///   - footnote: The footnote to delete
    ///   - context: SwiftData model context
    func moveFootnoteToTrash(_ footnote: FootnoteModel, context: ModelContext) {
        let footnoteID = footnote.id
        let textFileID = footnote.textFileID
        
        // Set all properties at once
        footnote.isDeleted = true
        footnote.deletedAt = Date()
        footnote.modifiedAt = Date()
        
        // Force SwiftData to recognize the changes
        context.processPendingChanges()
        
        do {
            try context.save()
            context.processPendingChanges()
            print("✅ Footnote \(footnoteID) moved to trash, isDeleted=\(footnote.isDeleted)")
        } catch {
            print("❌ Failed to move footnote to trash: \(error)")
            return
        }
        
        // Renumber remaining footnotes after all saves complete
        renumberFootnotes(forTextFile: textFileID, context: context)
    }
    
    /// Restore footnote from trash
    /// - Parameters:
    ///   - footnote: The footnote to restore
    ///   - context: SwiftData model context
    func restoreFootnote(_ footnote: FootnoteModel, context: ModelContext) {
        let textFileID = footnote.textFileID
        
        // Set all properties at once
        footnote.isDeleted = false
        footnote.deletedAt = nil
        footnote.modifiedAt = Date()
        
        // Force SwiftData to recognize the changes
        context.processPendingChanges()
        
        do {
            try context.save()
            context.processPendingChanges()
            print("✅ Footnote \(footnote.id) restored, isDeleted=\(footnote.isDeleted)")
        } catch {
            print("❌ Failed to restore footnote: \(error)")
            return
        }
        
        // Renumber all footnotes after all saves complete
        renumberFootnotes(forTextFile: textFileID, context: context)
    }
    
    /// Permanently delete a footnote
    /// - Parameters:
    ///   - footnote: The footnote to delete
    ///   - context: SwiftData model context
    func permanentlyDeleteFootnote(_ footnote: FootnoteModel, context: ModelContext) {
        footnote.prepareForPermanentDeletion()
        context.delete(footnote)
        
        do {
            try context.save()
        } catch {
            print("❌ Failed to permanently delete footnote: \(error)")
        }
    }
    
    // MARK: - Numbering Logic
    
    /// Calculate the appropriate footnote number for a new footnote at the given position
    /// - Parameters:
    ///   - textFileID: ID of the text file
    ///   - characterPosition: Position where the footnote will be inserted
    ///   - context: SwiftData model context
    /// - Returns: The footnote number
    internal func calculateFootnoteNumber(
        forTextFile textFileID: UUID,
        at characterPosition: Int,
        context: ModelContext
    ) -> Int {
        let activeFootnotes = getActiveFootnotes(forTextFile: textFileID, context: context)
        
        // Count how many footnotes come before this position
        let footnotesBeforeCount = activeFootnotes.filter { $0.characterPosition < characterPosition }.count
        
        return footnotesBeforeCount + 1
    }
    
    /// Renumber all footnotes in a document based on their character positions
    /// - Parameters:
    ///   - textFileID: ID of the text file
    ///   - context: SwiftData model context
    func renumberFootnotes(forTextFile textFileID: UUID, context: ModelContext) {
        let activeFootnotes = getActiveFootnotes(forTextFile: textFileID, context: context)
        
        // Sort by position
        let sortedFootnotes = activeFootnotes.sorted()
        
        // Renumber sequentially
        for (index, footnote) in sortedFootnotes.enumerated() {
            let newNumber = index + 1
            if footnote.number != newNumber {
                footnote.updateNumber(newNumber)
                print("📝🔢 Renumbered footnote \(footnote.id) from \(footnote.number) to \(newNumber) at position \(footnote.characterPosition)")
            }
        }
        
        do {
            try context.save()
        } catch {
            print("❌ Failed to save renumbered footnotes: \(error)")
        }
    }
    
    // MARK: - Position Management
    
    /// Update footnote positions after text edits
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
        let footnotes = getActiveFootnotes(forTextFile: textFileID, context: context)
        
        for footnote in footnotes {
            // Only update positions after the edit point
            if footnote.characterPosition >= editPosition {
                let newPosition = max(editPosition, footnote.characterPosition + lengthDelta)
                footnote.updatePosition(newPosition)
            }
        }
        
        do {
            try context.save()
            // Renumber in case order changed
            renumberFootnotes(forTextFile: textFileID, context: context)
        } catch {
            print("❌ Failed to update footnote positions: \(error)")
        }
    }
    
    // MARK: - Query Methods
    
    /// Get all footnotes for a specific text file (including deleted)
    /// - Parameters:
    ///   - textFileID: ID of the text file
    ///   - context: SwiftData model context
    /// - Returns: Array of footnotes sorted by position
    func getAllFootnotes(forTextFile textFileID: UUID, context: ModelContext) -> [FootnoteModel] {
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { footnote in
                footnote.textFileID == textFileID
            },
            sortBy: [SortDescriptor(\.characterPosition)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Get active (not deleted) footnotes for a text file
    /// - Parameters:
    ///   - textFileID: ID of the text file
    ///   - context: SwiftData model context
    /// - Returns: Array of active footnotes sorted by position
    func getActiveFootnotes(forTextFile textFileID: UUID, context: ModelContext) -> [FootnoteModel] {
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { footnote in
                footnote.textFileID == textFileID && footnote.isDeleted == false
            },
            sortBy: [SortDescriptor(\.characterPosition)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Get deleted footnotes for a text file (in trash)
    /// - Parameters:
    ///   - textFileID: ID of the text file
    ///   - context: SwiftData model context
    /// - Returns: Array of deleted footnotes sorted by deletion date
    func getDeletedFootnotes(forTextFile textFileID: UUID, context: ModelContext) -> [FootnoteModel] {
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { footnote in
                footnote.textFileID == textFileID && footnote.isDeleted == true
            },
            sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Get all deleted footnotes across all files (for trash view)
    /// - Parameter context: SwiftData model context
    /// - Returns: Array of deleted footnotes sorted by deletion date
    func getAllDeletedFootnotes(context: ModelContext) -> [FootnoteModel] {
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { footnote in
                footnote.isDeleted == true
            },
            sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Get footnote count for a text file
    /// - Parameters:
    ///   - textFileID: ID of the text file
    ///   - includeDeleted: Whether to include deleted footnotes
    ///   - context: SwiftData model context
    /// - Returns: Number of footnotes
    func getFootnoteCount(forTextFile textFileID: UUID, includeDeleted: Bool = false, context: ModelContext) -> Int {
        if includeDeleted {
            return getAllFootnotes(forTextFile: textFileID, context: context).count
        } else {
            return getActiveFootnotes(forTextFile: textFileID, context: context).count
        }
    }
    
    /// Get the next available footnote number for a text file
    /// - Parameters:
    ///   - textFileID: ID of the text file
    ///   - context: SwiftData model context
    /// - Returns: The next sequential number
    func getNextFootnoteNumber(forTextFile textFileID: UUID, context: ModelContext) -> Int {
        let activeFootnotes = getActiveFootnotes(forTextFile: textFileID, context: context)
        return activeFootnotes.count + 1
    }
}
