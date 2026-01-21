//
//  ReferenceTrackingService.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System
//  Created by GitHub Copilot on 15/01/2026.
//
//  Service for tracking reference counts, detecting orphans, and managing reference lifecycle
//

import Foundation
import SwiftData
import Observation

/// Service for managing reference counts and lifecycle
/// Tracks references when text is edited, copied, pasted, or deleted
@Observable
class ReferenceTrackingService {
    
    // MARK: - Properties
    
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    
    init() {}
    
    /// Configure with a model context
    func configure(with context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Reference Count Management
    
    /// Increment reference count for an entry
    /// Called when a reference marker is added or pasted
    @MainActor
    func incrementReferenceCount(forEntryID entryID: UUID, type: ReferenceType) {
        guard let context = modelContext else {
            #if DEBUG
            print("[ReferenceTrackingService] ⚠️ No model context configured")
            #endif
            return
        }
        
        switch type {
        case .note, .endnote:
            if let entry = fetchNoteEntry(id: entryID, in: context) {
                entry.incrementReferenceCount()
                #if DEBUG
                print("[ReferenceTrackingService] ✅ Incremented note \(entryID) count to \(entry.referenceCount)")
                #endif
            }
        case .glossary:
            if let entry = fetchGlossaryEntry(id: entryID, in: context) {
                entry.incrementReferenceCount()
                #if DEBUG
                print("[ReferenceTrackingService] ✅ Incremented glossary \(entryID) count to \(entry.referenceCount)")
                #endif
            }
        case .reference:
            if let entry = fetchReferenceEntry(id: entryID, in: context) {
                entry.incrementReferenceCount()
                #if DEBUG
                print("[ReferenceTrackingService] ✅ Incremented reference \(entryID) count to \(entry.referenceCount)")
                #endif
            }
        case .index, .figure, .table:
            if let entry = fetchIndexEntry(id: entryID, in: context) {
                entry.incrementReferenceCount()
                #if DEBUG
                print("[ReferenceTrackingService] ✅ Incremented index \(entryID) count to \(entry.referenceCount)")
                #endif
            }
        }
    }
    
    /// Decrement reference count for an entry
    /// Called when a reference marker is deleted or cut
    @MainActor
    func decrementReferenceCount(forEntryID entryID: UUID, type: ReferenceType) {
        guard let context = modelContext else {
            #if DEBUG
            print("[ReferenceTrackingService] ⚠️ No model context configured")
            #endif
            return
        }
        
        switch type {
        case .note, .endnote:
            if let entry = fetchNoteEntry(id: entryID, in: context) {
                entry.decrementReferenceCount()
                #if DEBUG
                print("[ReferenceTrackingService] ✅ Decremented note \(entryID) count to \(entry.referenceCount)")
                #endif
            }
        case .glossary:
            if let entry = fetchGlossaryEntry(id: entryID, in: context) {
                entry.decrementReferenceCount()
                #if DEBUG
                print("[ReferenceTrackingService] ✅ Decremented glossary \(entryID) count to \(entry.referenceCount)")
                #endif
            }
        case .reference:
            if let entry = fetchReferenceEntry(id: entryID, in: context) {
                entry.decrementReferenceCount()
                #if DEBUG
                print("[ReferenceTrackingService] ✅ Decremented reference \(entryID) count to \(entry.referenceCount)")
                #endif
            }
        case .index, .figure, .table:
            if let entry = fetchIndexEntry(id: entryID, in: context) {
                entry.decrementReferenceCount()
                #if DEBUG
                print("[ReferenceTrackingService] ✅ Decremented index \(entryID) count to \(entry.referenceCount)")
                #endif
            }
        }
    }
    
    /// Process references in a range that was added (paste, typing)
    /// Increments counts for all references found
    @MainActor
    func processAddedReferences(in attributedString: NSAttributedString, range: NSRange) {
        let references = attributedString.references(in: range)
        for ref in references {
            incrementReferenceCount(forEntryID: ref.entryID, type: ref.type)
        }
    }
    
    /// Process references in a range that was removed (delete, cut)
    /// Decrements counts for all references found
    @MainActor
    func processRemovedReferences(_ references: [ReferenceMarkerInfo]) {
        for ref in references {
            decrementReferenceCount(forEntryID: ref.entryID, type: ref.type)
        }
    }
    
    // MARK: - Orphan Detection
    
    /// Find all orphaned note entries (referenceCount == 0)
    @MainActor
    func orphanedNotes(in project: Project) -> [NoteEntry] {
        guard let context = modelContext else { return [] }
        
        let projectID = project.id
        let descriptor = FetchDescriptor<NoteEntry>(
            predicate: #Predicate { $0.project?.id == projectID && $0.referenceCount == 0 }
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Find all orphaned glossary entries
    @MainActor
    func orphanedGlossaryEntries(in project: Project) -> [GlossaryEntry] {
        guard let context = modelContext else { return [] }
        
        let projectID = project.id
        let descriptor = FetchDescriptor<GlossaryEntry>(
            predicate: #Predicate { $0.project?.id == projectID && $0.referenceCount == 0 }
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Find all orphaned citations
    @MainActor
    func orphanedCitations(in project: Project) -> [CitationEntry] {
        guard let context = modelContext else { return [] }
        
        let projectID = project.id
        let descriptor = FetchDescriptor<CitationEntry>(
            predicate: #Predicate { $0.project?.id == projectID && $0.referenceCount == 0 }
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Find all orphaned index entries
    @MainActor
    func orphanedIndexEntries(in project: Project) -> [IndexEntry] {
        guard let context = modelContext else { return [] }
        
        let projectID = project.id
        let descriptor = FetchDescriptor<IndexEntry>(
            predicate: #Predicate { $0.project?.id == projectID && $0.referenceCount == 0 }
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Check if a project has any orphaned entries
    @MainActor
    func hasOrphanedEntries(in project: Project) -> Bool {
        !orphanedNotes(in: project).isEmpty ||
        !orphanedGlossaryEntries(in: project).isEmpty ||
        !orphanedCitations(in: project).isEmpty ||
        !orphanedIndexEntries(in: project).isEmpty
    }
    
    /// Get count of all orphaned entries in a project
    @MainActor
    func orphanedEntryCount(in project: Project) -> Int {
        orphanedNotes(in: project).count +
        orphanedGlossaryEntries(in: project).count +
        orphanedCitations(in: project).count +
        orphanedIndexEntries(in: project).count
    }
    
    // MARK: - Entry Deletion
    
    /// Result of attempting to delete an entry
    enum DeletionResult {
        case success
        case hasReferences(count: Int)
        case notFound
        case error(Error)
    }
    
    /// Delete a note entry
    /// - Parameters:
    ///   - entry: The entry to delete
    ///   - force: If true, delete even if it has references
    /// - Returns: Result of the deletion attempt
    @MainActor
    func deleteNoteEntry(_ entry: NoteEntry, force: Bool = false) -> DeletionResult {
        guard let context = modelContext else { return .error(NSError(domain: "ReferenceTrackingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No context"])) }
        
        if !force && entry.referenceCount > 0 {
            return .hasReferences(count: entry.referenceCount)
        }
        
        context.delete(entry)
        
        #if DEBUG
        print("[ReferenceTrackingService] 🗑️ Deleted note entry \(entry.id)")
        #endif
        
        return .success
    }
    
    /// Delete a glossary entry
    @MainActor
    func deleteGlossaryEntry(_ entry: GlossaryEntry, force: Bool = false) -> DeletionResult {
        guard let context = modelContext else { return .error(NSError(domain: "ReferenceTrackingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No context"])) }
        
        if !force && entry.referenceCount > 0 {
            return .hasReferences(count: entry.referenceCount)
        }
        
        context.delete(entry)
        
        #if DEBUG
        print("[ReferenceTrackingService] 🗑️ Deleted glossary entry \(entry.id)")
        #endif
        
        return .success
    }
    
    /// Delete a citation entry
    @MainActor
    func deleteCitationEntry(_ entry: CitationEntry, force: Bool = false) -> DeletionResult {
        guard let context = modelContext else { return .error(NSError(domain: "ReferenceTrackingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No context"])) }
        
        if !force && entry.referenceCount > 0 {
            return .hasReferences(count: entry.referenceCount)
        }
        
        context.delete(entry)
        
        #if DEBUG
        print("[ReferenceTrackingService] 🗑️ Deleted citation entry \(entry.id)")
        #endif
        
        return .success
    }
    
    /// Delete an index entry
    @MainActor
    func deleteIndexEntry(_ entry: IndexEntry, force: Bool = false) -> DeletionResult {
        guard let context = modelContext else { return .error(NSError(domain: "ReferenceTrackingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No context"])) }
        
        if !force && entry.referenceCount > 0 {
            return .hasReferences(count: entry.referenceCount)
        }
        
        context.delete(entry)
        
        #if DEBUG
        print("[ReferenceTrackingService] 🗑️ Deleted index entry \(entry.id)")
        #endif
        
        return .success
    }
    
    /// Delete all orphaned entries in a project
    @MainActor
    func deleteAllOrphanedEntries(in project: Project) -> Int {
        var deletedCount = 0
        
        for entry in orphanedNotes(in: project) {
            if case .success = deleteNoteEntry(entry, force: true) {
                deletedCount += 1
            }
        }
        
        for entry in orphanedGlossaryEntries(in: project) {
            if case .success = deleteGlossaryEntry(entry, force: true) {
                deletedCount += 1
            }
        }
        
        for entry in orphanedCitations(in: project) {
            if case .success = deleteCitationEntry(entry, force: true) {
                deletedCount += 1
            }
        }
        
        for entry in orphanedIndexEntries(in: project) {
            if case .success = deleteIndexEntry(entry, force: true) {
                deletedCount += 1
            }
        }
        
        #if DEBUG
        print("[ReferenceTrackingService] 🗑️ Deleted \(deletedCount) orphaned entries")
        #endif
        
        return deletedCount
    }
    
    // MARK: - Entry Lookup
    
    /// Fetch all notes for a project
    @MainActor
    func notes(for project: Project) -> [NoteEntry] {
        guard let context = modelContext else { return [] }
        
        let projectID = project.id
        let descriptor = FetchDescriptor<NoteEntry>(
            predicate: #Predicate { $0.project?.id == projectID },
            sortBy: [SortDescriptor(\.displayNumber)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Fetch all glossary entries for a project
    @MainActor
    func glossaryEntries(for project: Project) -> [GlossaryEntry] {
        guard let context = modelContext else { return [] }
        
        let projectID = project.id
        let descriptor = FetchDescriptor<GlossaryEntry>(
            predicate: #Predicate { $0.project?.id == projectID },
            sortBy: [SortDescriptor(\.term)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Fetch all citations for a project
    @MainActor
    func citations(for project: Project) -> [CitationEntry] {
        guard let context = modelContext else { return [] }
        
        let projectID = project.id
        let descriptor = FetchDescriptor<CitationEntry>(
            predicate: #Predicate { $0.project?.id == projectID }
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Fetch all index entries for a project
    @MainActor
    func indexEntries(for project: Project) -> [IndexEntry] {
        guard let context = modelContext else { return [] }
        
        let projectID = project.id
        let descriptor = FetchDescriptor<IndexEntry>(
            predicate: #Predicate { $0.project?.id == projectID },
            sortBy: [SortDescriptor(\.keyword)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Fetch top-level index entries (no parent)
    @MainActor
    func topLevelIndexEntries(for project: Project) -> [IndexEntry] {
        indexEntries(for: project).filter { $0.isTopLevel }
    }
    
    /// Find a glossary entry by term
    @MainActor
    func findGlossaryEntry(term: String, in project: Project) -> GlossaryEntry? {
        glossaryEntries(for: project).first { $0.term.lowercased() == term.lowercased() }
    }
    
    /// Find an index entry by keyword
    @MainActor
    func findIndexEntry(keyword: String, in project: Project) -> IndexEntry? {
        indexEntries(for: project).first { $0.keyword.lowercased() == keyword.lowercased() }
    }
    
    // MARK: - Private Helpers
    
    private func fetchNoteEntry(id: UUID, in context: ModelContext) -> NoteEntry? {
        let descriptor = FetchDescriptor<NoteEntry>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }
    
    private func fetchGlossaryEntry(id: UUID, in context: ModelContext) -> GlossaryEntry? {
        let descriptor = FetchDescriptor<GlossaryEntry>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }
    
    private func fetchReferenceEntry(id: UUID, in context: ModelContext) -> ReferenceEntry? {
        let descriptor = FetchDescriptor<ReferenceEntry>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }
    
    private func fetchIndexEntry(id: UUID, in context: ModelContext) -> IndexEntry? {
        let descriptor = FetchDescriptor<IndexEntry>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }
    
    // MARK: - Reference Count Validation
    
    /// Recalculate all reference counts for a project by scanning document content
    /// Use this to fix inconsistencies between counts and actual references
    @MainActor
    func recalculateReferenceCounts(for project: Project, documentContents: [NSAttributedString]) {
        // Reset all counts to 0
        for entry in notes(for: project) {
            entry.referenceCount = 0
        }
        for entry in glossaryEntries(for: project) {
            entry.referenceCount = 0
        }
        for entry in citations(for: project) {
            entry.referenceCount = 0
        }
        for entry in indexEntries(for: project) {
            entry.referenceCount = 0
        }
        
        // Scan all documents and count references
        for content in documentContents {
            for ref in content.allReferences() {
                incrementReferenceCount(forEntryID: ref.entryID, type: ref.type)
            }
        }
        
        #if DEBUG
        print("[ReferenceTrackingService] ✅ Recalculated reference counts for project \(project.id)")
        #endif
    }
}

// MARK: - Undo/Redo Support

extension ReferenceTrackingService {
    
    /// Create an undo action for incrementing a reference count
    @MainActor
    func registerUndoForIncrement(
        entryID: UUID,
        type: ReferenceType,
        undoManager: UndoManager?
    ) {
        undoManager?.registerUndo(withTarget: self) { service in
            Task { @MainActor in
                service.decrementReferenceCount(forEntryID: entryID, type: type)
                service.registerUndoForDecrement(
                    entryID: entryID,
                    type: type,
                    undoManager: undoManager
                )
            }
        }
    }
    
    /// Create an undo action for decrementing a reference count
    @MainActor
    func registerUndoForDecrement(
        entryID: UUID,
        type: ReferenceType,
        undoManager: UndoManager?
    ) {
        undoManager?.registerUndo(withTarget: self) { service in
            Task { @MainActor in
                service.incrementReferenceCount(forEntryID: entryID, type: type)
                service.registerUndoForIncrement(
                    entryID: entryID,
                    type: type,
                    undoManager: undoManager
                )
            }
        }
    }
}
