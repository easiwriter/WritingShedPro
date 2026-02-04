//
//  IndexListView.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System
//  Created by GitHub Copilot on 15/01/2026.
//
//  List view for managing index entries at project level
//

import SwiftUI
import SwiftData

/// Sort options for index list
enum IndexSortOrder: String, CaseIterable {
    case alphabetical = "Alphabetical"
    case dateCreated = "Date Added"
    case dateModified = "Date Modified"
    case referenceCount = "Most Used"
    
    var localizedTitle: String {
        switch self {
        case .alphabetical:
            return NSLocalizedString("indexList.sort.alphabetical", comment: "Alphabetical")
        case .dateCreated:
            return NSLocalizedString("indexList.sort.dateCreated", comment: "Date Added")
        case .dateModified:
            return NSLocalizedString("indexList.sort.dateModified", comment: "Date Modified")
        case .referenceCount:
            return NSLocalizedString("indexList.sort.referenceCount", comment: "Most Used")
        }
    }
}

/// List view showing all index entries for a project
struct IndexListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    /// Callback when user wants to jump to an index marker in the text
    var onJumpToEntry: ((IndexEntry) -> Void)?
    
    /// Callback when list is dismissed
    var onDismiss: (() -> Void)?
    
    /// Callback when entry is updated/deleted
    var onEntryChanged: (() -> Void)?
    
    /// Callback when entry is deleted (needs marker removal from text)
    var onEntryDeleted: ((IndexEntry) -> Void)?
    
    // MARK: - State
    
    @State private var entries: [IndexEntry] = []
    @State private var sortOrder: IndexSortOrder = .alphabetical
    @State private var searchText: String = ""
    @State private var editingEntry: IndexEntry?
    @State private var showDeleteConfirmation: IndexEntry?
    @State private var showAddEntrySheet = false
    @State private var expandedEntryID: UUID?
    @State private var mergingEntry: IndexEntry?  // Entry to merge from
    @State private var showMergeSheet = false
    
    // MARK: - Computed Properties
    
    private var filteredEntries: [IndexEntry] {
        var result = entries
        
        // Apply search
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            result = result.filter { entry in
                entry.keyword.lowercased().contains(lowercasedSearch) ||
                (entry.childEntries ?? []).contains { $0.keyword.lowercased().contains(lowercasedSearch) }
            }
        }
        
        // Apply sort
        switch sortOrder {
        case .alphabetical:
            result.sort { $0.keyword.lowercased() < $1.keyword.lowercased() }
        case .dateCreated:
            result.sort { $0.createdAt > $1.createdAt }
        case .dateModified:
            result.sort { $0.modifiedAt > $1.modifiedAt }
        case .referenceCount:
            result.sort { $0.referenceCount > $1.referenceCount }
        }
        
        return result
    }
    
    private var orphanedEntries: [IndexEntry] {
        entries.filter { $0.referenceCount == 0 }
    }
    
    /// Group entries by first letter for alphabetical display
    private var groupedEntries: [(letter: String, entries: [IndexEntry])] {
        guard sortOrder == .alphabetical else {
            return [("", filteredEntries)]
        }
        
        let grouped = Dictionary(grouping: filteredEntries) { entry -> String in
            let firstChar = entry.keyword.first?.uppercased() ?? "#"
            return firstChar.first?.isLetter == true ? firstChar : "#"
        }
        
        return grouped.sorted { $0.key < $1.key }.map { (letter: $0.key, entries: $0.value) }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    entriesList
                }
            }
            .navigationTitle(NSLocalizedString("indexList.title", comment: "Index"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: NSLocalizedString("indexList.search.prompt", comment: "Search index"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        onDismiss?()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddEntrySheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Picker(selection: $sortOrder) {
                            ForEach(IndexSortOrder.allCases, id: \.self) { order in
                                Text(order.localizedTitle)
                                    .tag(order)
                            }
                        } label: {
                            Text(NSLocalizedString("indexList.sort", comment: "Sort"))
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
            }
        }
        .onAppear {
            loadEntries()
        }
        .onChange(of: entries) { oldValue, newValue in
            if newValue.isEmpty && !oldValue.isEmpty {
                onDismiss?()
                dismiss()
            }
        }
        .sheet(isPresented: $showAddEntrySheet) {
            IndexEditorSheet(
                project: project,
                onSave: { _, _ in
                    loadEntries()
                    onEntryChanged?()
                }
            )
        }
        .sheet(item: $editingEntry) { entry in
            IndexEditorSheet(
                project: project,
                existingEntry: entry,
                onSave: { _, _ in
                    loadEntries()
                    onEntryChanged?()
                }
            )
        }
        .confirmationDialog(
            NSLocalizedString("indexList.confirmDelete.title", comment: "Delete Index Entry?"),
            isPresented: .constant(showDeleteConfirmation != nil),
            titleVisibility: .visible,
            presenting: showDeleteConfirmation
        ) { entry in
            Button(NSLocalizedString("indexList.confirmDelete.button", comment: "Delete"), role: .destructive) {
                deleteEntry(entry)
                showDeleteConfirmation = nil
            }
            
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                showDeleteConfirmation = nil
            }
        } message: { entry in
            if entry.referenceCount > 0 {
                Text(String(format: NSLocalizedString("indexList.confirmDelete.messageWithRefs", comment: ""), entry.referenceCount))
            } else {
                Text(NSLocalizedString("indexList.confirmDelete.message", comment: "This entry will be permanently deleted."))
            }
        }
        .sheet(isPresented: $showMergeSheet) {
            if let sourceEntry = mergingEntry {
                IndexMergeSheet(
                    project: project,
                    sourceEntry: sourceEntry,
                    availableTargets: entries.filter { $0.id != sourceEntry.id },
                    onMerge: { targetEntry in
                        mergeEntry(sourceEntry, into: targetEntry)
                        showMergeSheet = false
                        mergingEntry = nil
                    },
                    onCancel: {
                        showMergeSheet = false
                        mergingEntry = nil
                    }
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                NSLocalizedString("indexList.empty.title", comment: "No Index Entries"),
                systemImage: "list.bullet.indent"
            )
        } description: {
            Text(NSLocalizedString("indexList.empty.description", comment: "Add index entries to create your book index."))
        } actions: {
            Button {
                showAddEntrySheet = true
            } label: {
                Label(
                    NSLocalizedString("indexList.addEntry", comment: "Add Entry"),
                    systemImage: "plus.circle.fill"
                )
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Entries List
    
    private var entriesList: some View {
        List {
            // Summary section
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("indexList.summary.total", comment: "Total Entries"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(entries.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(NSLocalizedString("indexList.summary.unreferenced", comment: "Unreferenced"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(orphanedEntries.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(orphanedEntries.isEmpty ? .primary : .orange)
                    }
                }
                .padding(.vertical, 4)
            } footer: {
                Text(NSLocalizedString("indexList.summary.footer", comment: "Index markers are invisible in text. Page numbers are calculated at export."))
                    .font(.caption)
            }
            
            // Entries grouped or flat
            ForEach(groupedEntries, id: \.letter) { group in
                Section {
                    ForEach(group.entries) { entry in
                        entryRow(entry)
                    }
                } header: {
                    if sortOrder == .alphabetical && !group.letter.isEmpty {
                        Text(group.letter)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Entry Row
    
    @ViewBuilder
    private func entryRow(_ entry: IndexEntry) -> some View {
        let childCount = entry.childEntries?.count ?? 0
        
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Entry badge
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "list.bullet.indent")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Main keyword
                    Text(entry.keyword)
                        .font(.headline)
                    
                    // Child entries (if expanded or few)
                    if childCount > 0 {
                        if expandedEntryID == entry.id || childCount <= 2 {
                            ForEach(entry.childEntries ?? [], id: \.id) { child in
                                childEntryRow(child, level: 1)
                            }
                        } else {
                            Text("  \(childCount) sub-terms")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Cross-references - look up "see" entry by ID
                    if let seeEntryID = entry.seeEntryID {
                        let allEntries = project.indexEntries ?? []
                        if let seeEntry = allEntries.first(where: { $0.id == seeEntryID }) {
                            HStack(spacing: 4) {
                                Text(NSLocalizedString("indexList.see", comment: "see"))
                                    .italic()
                                Text(seeEntry.keyword)
                                    .fontWeight(.medium)
                            }
                            .font(.caption)
                            .foregroundStyle(.purple)
                        }
                    }
                    
                    // "See also" cross-references - look up keywords from IDs
                    let seeAlsoIDs = entry.seeAlsoEntryIDs
                    if !seeAlsoIDs.isEmpty {
                        let allEntries = project.indexEntries ?? []
                        let seeAlsoKeywords = seeAlsoIDs.compactMap { id in
                            allEntries.first { $0.id == id }?.keyword
                        }.joined(separator: ", ")
                        
                        if !seeAlsoKeywords.isEmpty {
                            HStack(spacing: 4) {
                                Text(NSLocalizedString("indexList.seeAlso", comment: "see also"))
                                    .italic()
                                Text(seeAlsoKeywords)
                                    .fontWeight(.medium)
                            }
                            .font(.caption)
                            .foregroundStyle(.purple)
                        }
                    }
                    
                    // Metadata
                    HStack(spacing: 8) {
                        // Reference count
                        Label("\(entry.referenceCount)", systemImage: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundStyle(entry.referenceCount == 0 ? .orange : .secondary)
                        
                        if childCount > 0 {
                            Label("\(childCount)", systemImage: "list.bullet")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Actions menu
                Menu {
                    Button {
                        editingEntry = entry
                    } label: {
                        Label(
                            NSLocalizedString("indexList.edit", comment: "Edit"),
                            systemImage: "pencil.circle"
                        )
                    }
                    
                    if childCount > 0 {
                        Button {
                            withAnimation {
                                expandedEntryID = expandedEntryID == entry.id ? nil : entry.id
                            }
                        } label: {
                            Label(
                                expandedEntryID == entry.id
                                    ? NSLocalizedString("indexList.collapse", comment: "Collapse")
                                    : NSLocalizedString("indexList.expand", comment: "Expand"),
                                systemImage: expandedEntryID == entry.id ? "chevron.up" : "chevron.down"
                            )
                        }
                    }
                    
                    if entry.referenceCount > 0 {
                        Button {
                            onJumpToEntry?(entry)
                            dismiss()
                        } label: {
                            Label(
                                NSLocalizedString("indexList.jumpToText", comment: "Jump to Reference"),
                                systemImage: "arrow.right"
                            )
                        }
                    }
                    
                    // Merge option (only if other entries exist)
                    if entries.count > 1 {
                        Button {
                            mergingEntry = entry
                            showMergeSheet = true
                        } label: {
                            Label(
                                NSLocalizedString("indexList.merge", comment: "Merge Into..."),
                                systemImage: "arrow.triangle.merge"
                            )
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = entry
                    } label: {
                        Label(
                            NSLocalizedString("indexList.delete", comment: "Delete"),
                            systemImage: "trash"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if childCount > 0 {
                withAnimation {
                    expandedEntryID = expandedEntryID == entry.id ? nil : entry.id
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showDeleteConfirmation = entry
            } label: {
                Label(
                    NSLocalizedString("indexList.delete", comment: "Delete"),
                    systemImage: "trash"
                )
            }
            
            Button {
                editingEntry = entry
            } label: {
                Label(
                    NSLocalizedString("indexList.edit", comment: "Edit"),
                    systemImage: "pencil.circle"
                )
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if entry.referenceCount > 0 {
                Button {
                    onJumpToEntry?(entry)
                    dismiss()
                } label: {
                    Label(
                        NSLocalizedString("indexList.jump", comment: "Jump"),
                        systemImage: "arrow.right"
                    )
                }
                .tint(.green)
            }
        }
    }
    
    /// Display a child entry row with proper indentation (supports up to 3 levels)
    private func childEntryRow(_ entry: IndexEntry, level: Int) -> AnyView {
        let indent = String(repeating: "  ", count: level)
        let childCount = entry.childEntries?.count ?? 0
        
        return AnyView(
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("\(indent)• \(entry.keyword)")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    if entry.referenceCount > 0 {
                        Text("(\(entry.referenceCount))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                // Show cross-references for child entries too
                if let seeEntryID = entry.seeEntryID {
                    let allEntries = project.indexEntries ?? []
                    if let seeEntry = allEntries.first(where: { $0.id == seeEntryID }) {
                        HStack(spacing: 4) {
                            Text("\(indent)  ")
                            Text(NSLocalizedString("indexList.see", comment: "see"))
                                .italic()
                            Text(seeEntry.keyword)
                                .fontWeight(.medium)
                        }
                        .font(.caption)
                        .foregroundStyle(.purple)
                    }
                }
                
                // Recursively show grandchildren (up to max depth 3)
                if childCount > 0 && level < IndexEntry.maxDepth - 1 {
                    ForEach(entry.childEntries ?? [], id: \.id) { child in
                        childEntryRow(child, level: level + 1)
                    }
                } else if childCount > 0 {
                    Text("\(indent)  (\(childCount) more)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        )
    }
    
    // MARK: - Actions
    
    private func loadEntries() {
        // Fetch top-level index entries for this project
        let projectID = project.id
        let descriptor = FetchDescriptor<IndexEntry>(
            predicate: #Predicate<IndexEntry> { entry in
                entry.project?.id == projectID && entry.parentEntry == nil
            }
        )
        
        entries = (try? modelContext.fetch(descriptor)) ?? []
        
        #if DEBUG
        print("📑 Loaded \(entries.count) index entries for project")
        #endif
    }
    
    private func deleteEntry(_ entry: IndexEntry) {
        // Delete from context (cascade will handle children)
        modelContext.delete(entry)
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("❌ Error deleting index entry: \(error)")
            #endif
        }
        
        loadEntries()
        onEntryChanged?()
        onEntryDeleted?(entry)
        
        #if DEBUG
        print("🗑️ Deleted index entry: \(entry.keyword)")
        #endif
    }
    
    private func mergeEntry(_ source: IndexEntry, into target: IndexEntry) {
        // Transfer reference count
        target.referenceCount += source.referenceCount
        
        // Merge referencing file IDs
        for fileID in source.referencingFileIDs {
            target.addReferencingFile(fileID)
        }
        
        // Reparent children from source to target
        if let children = source.childEntries {
            for child in children {
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
        modelContext.delete(source)
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("❌ Error merging index entry: \(error)")
            #endif
        }
        
        loadEntries()
        onEntryChanged?()
        
        // Notify that markers need to be updated (source ID -> target ID)
        // This is handled by the calling view which has access to the text
        
        #if DEBUG
        print("🔀 Merged index entry '\(source.keyword)' into '\(target.keyword)'")
        #endif
    }
}

// MARK: - Localization Keys

/*
 Add these to Localizable.strings:
 
 "indexList.title" = "Index";
 "indexList.search.prompt" = "Search index";
 "indexList.sort" = "Sort";
 "indexList.sort.alphabetical" = "Alphabetical";
 "indexList.sort.dateCreated" = "Date Added";
 "indexList.sort.dateModified" = "Date Modified";
 "indexList.sort.referenceCount" = "Most Used";
 "indexList.addEntry" = "Add Entry";
 "indexList.empty.title" = "No Index Entries";
 "indexList.empty.description" = "Add index entries to create your book index.";
 "indexList.summary.total" = "Total Entries";
 "indexList.summary.unreferenced" = "Unreferenced";
 "indexList.summary.footer" = "Index markers are invisible in text. Page numbers are calculated at export.";
 "indexList.edit" = "Edit";
 "indexList.expand" = "Expand";
 "indexList.collapse" = "Collapse";
 "indexList.jumpToText" = "Jump to Reference";
 "indexList.jump" = "Jump";
 "indexList.delete" = "Delete";
 "indexList.confirmDelete.title" = "Delete Index Entry?";
 "indexList.confirmDelete.button" = "Delete";
 "indexList.confirmDelete.message" = "This entry will be permanently deleted.";
 "indexList.confirmDelete.messageWithRefs" = "This entry is referenced %d times. The markers will be removed.";
 */
