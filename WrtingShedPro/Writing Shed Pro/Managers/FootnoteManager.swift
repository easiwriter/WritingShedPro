//
//  FootnoteManager.swift
//  Writing Shed Pro
//
//  Feature 015: Footnotes
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
    ///   - version: The version to attach the footnote to
    ///   - characterPosition: Position in the document
    ///   - attachmentID: ID of the text attachment
    ///   - text: Footnote text content
    ///   - context: SwiftData model context
    /// - Returns: The created FootnoteModel
    func createFootnote(
        version: Version,
        characterPosition: Int,
        attachmentID: UUID = UUID(),
        text: String,
        context: ModelContext
    ) -> FootnoteModel {
        // Determine the footnote number based on current position
        let number = calculateFootnoteNumber(
            forVersion: version,
            at: characterPosition,
            context: context
        )
        
        let footnote = FootnoteModel(
            version: version,
            characterPosition: characterPosition,
            attachmentID: attachmentID,
            text: text,
            number: number
        )
        
        context.insert(footnote)
        
        do {
            try context.save()
            // Renumber all footnotes after insertion
            renumberFootnotes(forVersion: version, context: context)
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
        guard let version = footnote.version else {
            print("❌ Cannot move footnote to trash: no version relationship")
            return
        }
        
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
        renumberFootnotes(forVersion: version, context: context)
    }
    
    /// Restore footnote from trash
    /// - Parameters:
    ///   - footnote: The footnote to restore
    ///   - context: SwiftData model context
    func restoreFootnote(_ footnote: FootnoteModel, context: ModelContext) {
        guard let version = footnote.version else {
            print("❌ Cannot restore footnote: no version relationship")
            return
        }
        
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
        renumberFootnotes(forVersion: version, context: context)
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
    ///   - version: The version to calculate footnote number for
    ///   - characterPosition: Position where the footnote will be inserted
    ///   - context: SwiftData model context
    /// - Returns: The footnote number
    internal func calculateFootnoteNumber(
        forVersion version: Version,
        at characterPosition: Int,
        context: ModelContext
    ) -> Int {
        let activeFootnotes = getActiveFootnotes(forVersion: version, context: context)
        
        // Count how many footnotes come before this position
        let footnotesBeforeCount = activeFootnotes.filter { $0.characterPosition < characterPosition }.count
        
        return footnotesBeforeCount + 1
    }
    
    /// Renumber all footnotes in a document based on their character positions
    /// - Parameters:
    ///   - version: The version to renumber footnotes for
    ///   - context: SwiftData model context
    func renumberFootnotes(forVersion version: Version, context: ModelContext) {
        let activeFootnotes = getActiveFootnotes(forVersion: version, context: context)
        
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
    ///   - version: The version to update footnote positions for
    ///   - editPosition: Where the edit occurred
    ///   - lengthDelta: Change in text length (positive for insertions, negative for deletions)
    ///   - context: SwiftData model context
    func updatePositionsAfterEdit(
        version: Version,
        editPosition: Int,
        lengthDelta: Int,
        context: ModelContext
    ) {
        let footnotes = getActiveFootnotes(forVersion: version, context: context)
        
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
            renumberFootnotes(forVersion: version, context: context)
        } catch {
            print("❌ Failed to update footnote positions: \(error)")
        }
    }
    
    // MARK: - Query Methods
    
    /// Get all footnotes for a specific version (including deleted)
    /// - Parameters:
    ///   - version: The version to get footnotes for
    ///   - context: SwiftData model context
    /// - Returns: Array of footnotes sorted by position
    nonisolated func getAllFootnotes(forVersion version: Version, context: ModelContext) -> [FootnoteModel] {
        // Use FetchDescriptor to query database directly instead of relying on cached relationship
        let versionID = version.id
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { footnote in
                footnote.version?.id == versionID
            },
            sortBy: [SortDescriptor(\.characterPosition, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Get active (not deleted) footnotes for a version
    /// - Parameters:
    ///   - version: The version to get footnotes for
    ///   - context: SwiftData model context
    /// - Returns: Array of active footnotes sorted by position
    nonisolated func getActiveFootnotes(forVersion version: Version, context: ModelContext) -> [FootnoteModel] {
        // Use FetchDescriptor to query database directly instead of relying on cached relationship
        let versionID = version.id
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { footnote in
                footnote.version?.id == versionID && footnote.isDeleted == false
            },
            sortBy: [SortDescriptor(\.characterPosition, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Get deleted footnotes for a version (in trash)
    /// - Parameters:
    ///   - version: The version to get deleted footnotes for
    ///   - context: SwiftData model context
    /// - Returns: Array of deleted footnotes sorted by deletion date
    nonisolated func getDeletedFootnotes(forVersion version: Version, context: ModelContext) -> [FootnoteModel] {
        // Use FetchDescriptor to query database directly instead of relying on cached relationship
        let versionID = version.id
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { footnote in
                footnote.version?.id == versionID && footnote.isDeleted == true
            },
            sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Get all deleted footnotes across all files (for trash view)
    /// - Parameter context: SwiftData model context
    /// - Returns: Array of deleted footnotes sorted by deletion date
    nonisolated func getAllDeletedFootnotes(context: ModelContext) -> [FootnoteModel] {
        let descriptor = FetchDescriptor<FootnoteModel>(
            predicate: #Predicate { footnote in
                footnote.isDeleted == true
            },
            sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Get footnote count for a version
    /// - Parameters:
    ///   - version: The version to get footnote count for
    ///   - includeDeleted: Whether to include deleted footnotes
    ///   - context: SwiftData model context
    /// - Returns: Number of footnotes
    nonisolated func getFootnoteCount(forVersion version: Version, includeDeleted: Bool = false, context: ModelContext) -> Int {
        if includeDeleted {
            return getAllFootnotes(forVersion: version, context: context).count
        } else {
            return getActiveFootnotes(forVersion: version, context: context).count
        }
    }
    
    /// Get the next available footnote number for a version
    /// - Parameters:
    ///   - version: The version to get next footnote number for
    ///   - context: SwiftData model context
    /// - Returns: The next sequential number
    func getNextFootnoteNumber(forVersion version: Version, context: ModelContext) -> Int {
        let activeFootnotes = getActiveFootnotes(forVersion: version, context: context)
        return activeFootnotes.count + 1
    }
}
