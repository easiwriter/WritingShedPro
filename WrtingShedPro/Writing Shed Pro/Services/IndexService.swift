//
//  IndexService.swift
//  Writing Shed Pro
//
//  Feature 033: Index Generation
//  Created by GitHub Copilot on 04/02/2026.
//
//  Service for managing index entries, references, and index generation
//

import Foundation
import SwiftData
import Observation

// MARK: - Index Display Types

/// Represents a page reference with primary flag
struct PageReference: Equatable {
    let pageNumber: Int
    let isPrimary: Bool
}

/// Represents a section of the index (grouped by letter)
struct IndexSection: Identifiable {
    let id = UUID()
    let letter: String
    let entries: [IndexDisplayEntry]
}

/// Represents an index entry for display in generated index
struct IndexDisplayEntry: Identifiable {
    let id: UUID
    let keyword: String
    let pageReferences: [PageReference]
    let level: Int
    let seeReference: String?
    let seeAlsoReferences: [String]
    let children: [IndexDisplayEntry]
    
    /// Format page references with ranges and bold markup for primary
    /// Example: [1, 2, 3, 5, 7, 8] → "1-3, 5, 7-8"
    var formattedPageNumbers: AttributedString {
        formatPageReferences(pageReferences)
    }
    
    var hasReferences: Bool {
        !pageReferences.isEmpty || seeReference != nil || !seeAlsoReferences.isEmpty
    }
}

/// Formats page references with ranges
/// Primary references are marked for bold rendering
func formatPageReferences(_ refs: [PageReference]) -> AttributedString {
    guard !refs.isEmpty else { return AttributedString() }
    
    let sorted = refs.sorted { $0.pageNumber < $1.pageNumber }
    var result = AttributedString()
    var ranges: [(start: Int, end: Int, hasPrimary: Bool)] = []
    
    for ref in sorted {
        if let last = ranges.last, last.end == ref.pageNumber - 1 {
            ranges[ranges.count - 1] = (last.start, ref.pageNumber, last.hasPrimary || ref.isPrimary)
        } else {
            ranges.append((ref.pageNumber, ref.pageNumber, ref.isPrimary))
        }
    }
    
    for (index, range) in ranges.enumerated() {
        if index > 0 {
            result.append(AttributedString(", "))
        }
        
        let text: String
        if range.start == range.end {
            text = "\(range.start)"
        } else {
            text = "\(range.start)-\(range.end)"
        }
        
        var segment = AttributedString(text)
        if range.hasPrimary {
            segment.inlinePresentationIntent = .stronglyEmphasized // Bold
        }
        result.append(segment)
    }
    
    return result
}

// MARK: - Index Service

/// Service for managing index entries and generating indexes
@Observable
class IndexService {
    
    // MARK: - Properties
    
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    
    init() {}
    
    /// Configure with a model context
    func configure(with context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Entry Management
    
    /// Find an existing entry by keyword, or create a new one
    /// - Parameters:
    ///   - keyword: The index keyword
    ///   - parent: Optional parent entry for sub-entries
    ///   - project: The project this entry belongs to
    /// - Returns: The existing or newly created IndexEntry
    @MainActor
    func findOrCreateEntry(keyword: String, parent: IndexEntry? = nil, project: Project) -> IndexEntry? {
        guard let context = modelContext else {
            #if DEBUG
            print("[IndexService] ⚠️ No model context configured")
            #endif
            return nil
        }
        
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKeyword.isEmpty else { return nil }
        
        // Check if parent would exceed max depth
        if let parent = parent, !parent.canHaveChildren {
            #if DEBUG
            print("[IndexService] ⚠️ Cannot create child: parent at max depth")
            #endif
            return nil
        }
        
        // Try to find existing entry with same keyword under same parent
        let projectID = project.id
        let descriptor = FetchDescriptor<IndexEntry>(
            predicate: #Predicate { $0.project?.id == projectID }
        )
        
        if let entries = try? context.fetch(descriptor) {
            // Find matching entry (case-insensitive)
            if let existing = entries.first(where: { entry in
                entry.keyword.caseInsensitiveCompare(normalizedKeyword) == .orderedSame &&
                entry.parentEntry?.id == parent?.id
            }) {
                return existing
            }
        }
        
        // Create new entry
        let entry = IndexEntry(
            project: project,
            keyword: normalizedKeyword,
            parentEntry: parent
        )
        context.insert(entry)
        
        #if DEBUG
        print("[IndexService] ✅ Created index entry: '\(normalizedKeyword)' (depth: \(entry.depth))")
        #endif
        
        return entry
    }
    
    /// Find an entry by ID
    @MainActor
    func findEntry(id: UUID) -> IndexEntry? {
        guard let context = modelContext else { return nil }
        
        let descriptor = FetchDescriptor<IndexEntry>(
            predicate: #Predicate { $0.id == id }
        )
        
        return try? context.fetch(descriptor).first
    }
    
    /// Find an entry by keyword (case-insensitive)
    @MainActor
    func findEntry(keyword: String, in project: Project) -> IndexEntry? {
        guard let context = modelContext else { return nil }
        
        let projectID = project.id
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let descriptor = FetchDescriptor<IndexEntry>(
            predicate: #Predicate { $0.project?.id == projectID }
        )
        
        if let entries = try? context.fetch(descriptor) {
            return entries.first { entry in
                entry.keyword.caseInsensitiveCompare(normalizedKeyword) == .orderedSame
            }
        }
        
        return nil
    }
    
    /// Delete an entry and optionally remove all markers referencing it
    /// - Parameters:
    ///   - entry: The entry to delete
    ///   - removeMarkers: Whether to remove reference markers from documents
    ///   - onRemoveMarkers: Callback to remove markers from a specific file
    @MainActor
    func deleteEntry(
        _ entry: IndexEntry,
        removeMarkers: Bool = true,
        onRemoveMarkers: ((UUID, UUID) -> Void)? = nil
    ) {
        guard let context = modelContext else {
            #if DEBUG
            print("[IndexService] ⚠️ No model context configured")
            #endif
            return
        }
        
        let keyword = entry.keyword
        
        // Remove markers from referencing files
        if removeMarkers, let callback = onRemoveMarkers {
            for fileID in entry.referencingFileIDs {
                callback(fileID, entry.id)
            }
        }
        
        // Reparent children to grandparent (or make them top-level)
        if let children = entry.childEntries {
            for child in children {
                child.parentEntry = entry.parentEntry
            }
        }
        
        // Delete the entry
        context.delete(entry)
        
        #if DEBUG
        print("[IndexService] 🗑️ Deleted index entry: '\(keyword)'")
        #endif
    }
    
    /// Merge two entries, combining all references
    /// - Parameters:
    ///   - source: The entry to merge from (will be deleted)
    ///   - target: The entry to merge into
    ///   - onUpdateMarkers: Callback to update markers in files
    @MainActor
    func mergeEntries(
        source: IndexEntry,
        into target: IndexEntry,
        onUpdateMarkers: ((UUID, UUID, UUID) -> Void)? = nil
    ) {
        guard let context = modelContext else {
            #if DEBUG
            print("[IndexService] ⚠️ No model context configured")
            #endif
            return
        }
        
        // Update markers in all files referencing source
        if let callback = onUpdateMarkers {
            for fileID in source.referencingFileIDs {
                callback(fileID, source.id, target.id)
            }
        }
        
        // Merge referencing file IDs
        for fileID in source.referencingFileIDs {
            target.addReferencingFile(fileID)
        }
        
        // Transfer reference count
        target.referenceCount += source.referenceCount
        
        // Reparent children from source to target
        if let children = source.childEntries {
            for child in children {
                // Only reparent if it won't exceed max depth
                if target.canHaveChildren {
                    child.parentEntry = target
                } else {
                    // Make child a sibling of target instead
                    child.parentEntry = target.parentEntry
                }
            }
        }
        
        // Merge "see also" references
        for seeAlsoID in source.seeAlsoEntryIDs {
            target.addSeeAlso(seeAlsoID)
        }
        
        // Delete source entry
        context.delete(source)
        
        #if DEBUG
        print("[IndexService] 🔀 Merged '\(source.keyword)' into '\(target.keyword)'")
        #endif
    }
    
    /// Update an entry's parent (reparenting)
    /// - Parameters:
    ///   - entry: The entry to reparent
    ///   - newParent: The new parent (nil for top-level)
    /// - Returns: true if successful, false if would exceed max depth
    @MainActor
    func reparentEntry(_ entry: IndexEntry, to newParent: IndexEntry?) -> Bool {
        guard entry.canBeChildOf(newParent) else {
            #if DEBUG
            print("[IndexService] ⚠️ Cannot reparent: would exceed max depth of \(IndexEntry.maxDepth)")
            #endif
            return false
        }
        
        entry.parentEntry = newParent
        entry.modifiedAt = Date()
        
        #if DEBUG
        if let parent = newParent {
            print("[IndexService] ✅ Reparented '\(entry.keyword)' under '\(parent.keyword)'")
        } else {
            print("[IndexService] ✅ Moved '\(entry.keyword)' to top level")
        }
        #endif
        
        return true
    }
    
    /// Rename an entry
    @MainActor
    func renameEntry(_ entry: IndexEntry, to newKeyword: String) {
        let normalizedKeyword = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKeyword.isEmpty else { return }
        
        entry.updateKeyword(normalizedKeyword)
        
        #if DEBUG
        print("[IndexService] ✏️ Renamed entry to '\(normalizedKeyword)'")
        #endif
    }
    
    // MARK: - Reference Tracking
    
    /// Add a reference to an entry from a file
    @MainActor
    func addReference(to entry: IndexEntry, fromFile fileID: UUID, isPrimary: Bool = false) {
        entry.incrementReferenceCount()
        entry.addReferencingFile(fileID)
        
        #if DEBUG
        print("[IndexService] ➕ Added reference to '\(entry.keyword)' from file \(fileID.uuidString.prefix(8))...")
        #endif
    }
    
    /// Remove a reference to an entry from a file
    /// - Parameters:
    ///   - entry: The entry being dereferenced
    ///   - fileID: The file containing the reference
    ///   - wasLastInFile: Whether this was the last reference to this entry in the file
    @MainActor
    func removeReference(from entry: IndexEntry, inFile fileID: UUID, wasLastInFile: Bool = false) {
        entry.decrementReferenceCount()
        
        if wasLastInFile {
            entry.removeReferencingFile(fileID)
        }
        
        #if DEBUG
        print("[IndexService] ➖ Removed reference to '\(entry.keyword)' (count: \(entry.referenceCount))")
        #endif
    }
    
    // MARK: - Cross-References
    
    /// Set a "See" reference (redirects to another entry)
    @MainActor
    func setSeeReference(for entry: IndexEntry, to targetEntry: IndexEntry?) {
        entry.seeEntryID = targetEntry?.id
        entry.modifiedAt = Date()
        
        #if DEBUG
        if let target = targetEntry {
            print("[IndexService] 👉 Set '\(entry.keyword)' → See '\(target.keyword)'")
        } else {
            print("[IndexService] 👉 Removed See reference from '\(entry.keyword)'")
        }
        #endif
    }
    
    /// Add a "See also" reference
    @MainActor
    func addSeeAlsoReference(for entry: IndexEntry, to targetEntry: IndexEntry) {
        entry.addSeeAlso(targetEntry.id)
        
        #if DEBUG
        print("[IndexService] 👉 Added See also '\(targetEntry.keyword)' to '\(entry.keyword)'")
        #endif
    }
    
    /// Remove a "See also" reference
    @MainActor
    func removeSeeAlsoReference(for entry: IndexEntry, to targetEntryID: UUID) {
        entry.removeSeeAlso(targetEntryID)
    }
    
    // MARK: - Fetch Methods
    
    /// Fetch all index entries for a project
    @MainActor
    func fetchAllEntries(for project: Project) -> [IndexEntry] {
        guard let context = modelContext else { return [] }
        
        let projectID = project.id
        let descriptor = FetchDescriptor<IndexEntry>(
            predicate: #Predicate { $0.project?.id == projectID },
            sortBy: [SortDescriptor(\IndexEntry.keyword, comparator: .localizedStandard)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Fetch top-level entries only (no parent)
    @MainActor
    func fetchTopLevelEntries(for project: Project) -> [IndexEntry] {
        let allEntries = fetchAllEntries(for: project)
        return allEntries.filter { $0.isTopLevel }
    }
    
    /// Search entries by keyword
    @MainActor
    func searchEntries(keyword: String, in project: Project) -> [IndexEntry] {
        let allEntries = fetchAllEntries(for: project)
        let searchTerm = keyword.lowercased()
        return allEntries.filter { $0.keyword.lowercased().contains(searchTerm) }
    }
    
    // MARK: - Index Generation
    
    /// Generate the complete index for a project
    /// - Parameter project: The project to generate index for
    /// - Returns: Array of IndexSection grouped by first letter
    @MainActor
    func generateIndex(for project: Project) -> [IndexSection] {
        let entries = fetchTopLevelEntries(for: project)
        
        // Group by first letter
        var sectionDict: [String: [IndexDisplayEntry]] = [:]
        
        for entry in entries {
            let displayEntry = buildDisplayEntry(from: entry)
            let firstLetter = String(entry.keyword.prefix(1)).uppercased()
            let letter = firstLetter.first?.isLetter == true ? firstLetter : "#"
            
            if sectionDict[letter] == nil {
                sectionDict[letter] = []
            }
            sectionDict[letter]?.append(displayEntry)
        }
        
        // Sort sections alphabetically
        let sortedLetters = sectionDict.keys.sorted { lhs, rhs in
            if lhs == "#" { return false }
            if rhs == "#" { return true }
            return lhs < rhs
        }
        
        return sortedLetters.compactMap { letter in
            guard let entries = sectionDict[letter] else { return nil }
            let sortedEntries = entries.sorted { $0.keyword.localizedCaseInsensitiveCompare($1.keyword) == .orderedAscending }
            return IndexSection(letter: letter, entries: sortedEntries)
        }
    }
    
    /// Build a display entry from an IndexEntry
    @MainActor
    private func buildDisplayEntry(from entry: IndexEntry, level: Int = 0) -> IndexDisplayEntry {
        // Build page references
        let pageRefs = entry.pageNumbers.map { pageNumber in
            PageReference(pageNumber: pageNumber, isPrimary: entry.isPrimaryPageNumber(pageNumber))
        }
        
        // Get "see" reference keyword
        let seeReference: String?
        if let seeID = entry.seeEntryID {
            seeReference = findEntry(id: seeID)?.keyword
        } else {
            seeReference = nil
        }
        
        // Get "see also" keywords
        let seeAlsoRefs = entry.seeAlsoEntryIDs.compactMap { id in
            findEntry(id: id)?.keyword
        }
        
        // Build children
        let children = (entry.childEntries ?? [])
            .sorted { $0.keyword.localizedCaseInsensitiveCompare($1.keyword) == .orderedAscending }
            .map { buildDisplayEntry(from: $0, level: level + 1) }
        
        return IndexDisplayEntry(
            id: entry.id,
            keyword: entry.keyword,
            pageReferences: pageRefs,
            level: level,
            seeReference: seeReference,
            seeAlsoReferences: seeAlsoRefs,
            children: children
        )
    }
}
