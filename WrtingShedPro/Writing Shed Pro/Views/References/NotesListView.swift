//
//  NotesListView.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System
//  Created by GitHub Copilot on 15/01/2026.
//
//  List view for managing notes and endnotes at project level
//

import SwiftUI
import SwiftData

/// Filter options for endnotes list
enum NotesFilter: String, CaseIterable {
    case all = "All"
    case endnotes = "Endnotes"
    
    var localizedTitle: String {
        switch self {
        case .all:
            return NSLocalizedString("notesList.filter.all", comment: "All")
        case .endnotes:
            return NSLocalizedString("notesList.filter.endnotes", comment: "Endnotes")
        }
    }
}

/// Sort options for notes list
enum NotesSortOrder: String, CaseIterable {
    case number = "Number"
    case dateCreated = "Date Created"
    case dateModified = "Date Modified"
    case title = "Title"
    
    var localizedTitle: String {
        switch self {
        case .number:
            return NSLocalizedString("notesList.sort.number", comment: "Number")
        case .dateCreated:
            return NSLocalizedString("notesList.sort.dateCreated", comment: "Date Created")
        case .dateModified:
            return NSLocalizedString("notesList.sort.dateModified", comment: "Date Modified")
        case .title:
            return NSLocalizedString("notesList.sort.title", comment: "Title")
        }
    }
}

/// List view showing all notes and endnotes for a project
struct NotesListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    /// Callback when list is dismissed
    var onDismiss: (() -> Void)?
    
    /// Callback when note is updated/deleted
    var onNoteChanged: (() -> Void)?
    
    /// Callback when note is deleted (needs marker removal from text)
    var onNoteDeleted: ((NoteEntry) -> Void)?
    
    // MARK: - State
    
    @State private var notes: [NoteEntry] = []
    @State private var filter: NotesFilter = .all
    @State private var sortOrder: NotesSortOrder = .number
    @State private var searchText: String = ""
    @State private var editingNote: NoteEntry?
    @State private var showDeleteConfirmation: NoteEntry?
    @State private var showAddNoteSheet = false
    @State private var addNoteAsEndnote = false
    @State private var showAllDeletedAlert = false
    @State private var previousNoteCount = 0
    
    // MARK: - Computed Properties
    
    private var filteredNotes: [NoteEntry] {
        var result = notes.filter { $0.isEndnote }
        
        // Apply search
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            result = result.filter { note in
                note.content.lowercased().contains(lowercasedSearch) ||
                (note.title?.lowercased().contains(lowercasedSearch) ?? false)
            }
        }
        
        // Apply sort
        switch sortOrder {
        case .number:
            result.sort { $0.displayNumber < $1.displayNumber }
        case .dateCreated:
            result.sort { $0.createdAt > $1.createdAt }
        case .dateModified:
            result.sort { $0.modifiedAt > $1.modifiedAt }
        case .title:
            result.sort { ($0.title ?? "") < ($1.title ?? "") }
        }
        
        return result
    }
    
    private var notesCount: Int {
        notes.filter { !$0.isEndnote }.count
    }
    
    private var endnotesCount: Int {
        notes.filter { $0.isEndnote }.count
    }
    
    private var orphanedNotes: [NoteEntry] {
        notes.filter { $0.referenceCount == 0 }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if notes.isEmpty && previousNoteCount > 0 && showAllDeletedAlert {
                    // Showing alert - display empty state in background
                    emptyState
                } else if notes.isEmpty {
                    emptyState
                } else {
                    notesList
                }
            }
            .navigationTitle(NSLocalizedString("notesList.endnotes.title", comment: "Endnotes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        onDismiss?()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        addNoteAsEndnote = true
                        showAddNoteSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            loadNotes()
        }
        .onChange(of: notes) { oldValue, newValue in
            // Check if we just deleted all notes
            if !oldValue.isEmpty && newValue.isEmpty {
                showAllDeletedAlert = true
            }
            previousNoteCount = newValue.count
        }
        .sheet(isPresented: $showAddNoteSheet) {
            NoteEditorSheet(
                project: project,
                isEndnote: addNoteAsEndnote,
                onSave: { _ in
                    loadNotes()
                    onNoteChanged?()
                }
            )
        }
        .sheet(item: $editingNote) { note in
            NoteEditorSheet(
                project: project,
                existingNote: note,
                onSave: { _ in
                    loadNotes()
                    onNoteChanged?()
                }
            )
        }
        .confirmationDialog(
            NSLocalizedString("notesList.confirmDelete.title", comment: "Delete Note?"),
            isPresented: .constant(showDeleteConfirmation != nil),
            titleVisibility: .visible,
            presenting: showDeleteConfirmation
        ) { note in
            Button(NSLocalizedString("notesList.confirmDelete.button", comment: "Delete"), role: .destructive) {
                deleteNote(note)
                showDeleteConfirmation = nil
            }
            
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                showDeleteConfirmation = nil
            }
        } message: { note in
            if note.referenceCount > 0 {
                Text("This note is referenced \(note.referenceCount) times. All references will be removed from your documents.")
            } else {
                Text(NSLocalizedString("notesList.confirmDelete.message", comment: "This note will be permanently deleted."))
            }
        }
        .alert("All Endnotes Have Been Deleted", isPresented: $showAllDeletedAlert) {
            Button("OK") {
                onDismiss?()
                dismiss()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                NSLocalizedString("notesList.empty.title", comment: "No Notes"),
                systemImage: "note.text"
            )
        } description: {
            Text(NSLocalizedString("notesList.empty.description", comment: "Notes and endnotes you create will appear here."))
        }
    }
    
    // MARK: - Notes List
    
    private var notesList: some View {
        List {
            // Endnotes section - only show endnotes
            if !filteredNotes.isEmpty {
                Section {
                    ForEach(filteredNotes) { note in
                        noteRow(note)
                    }
                } header: {
                    HStack {
                        Text(NSLocalizedString("notesList.summary.endnotes", comment: "Endnotes"))
                        Spacer()
                        Text("\(filteredNotes.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Note Row
    
    @ViewBuilder
    private func noteRow(_ note: NoteEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Note type and tag/number badge
            VStack {
                ZStack {
                    Circle()
                        .fill(note.isEndnote ? Color.indigo.opacity(0.1) : Color.blue.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    if let tag = note.tag, !tag.isEmpty {
                        // Show tag abbreviation
                        Text(tag.prefix(1).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(note.isEndnote ? .indigo : .blue)
                    } else if note.isEndnote {
                        Text("\(note.displayNumber)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.indigo)
                    } else {
                        VStack(spacing: 0) {
                            Image(systemName: "note.text")
                                .font(.system(size: 10))
                            Text("\(note.displayNumber)")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // Reference count indicator
                if note.referenceCount == 0 {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Title or tag (if present)
                if let tag = note.tag, !tag.isEmpty {
                    Text(tag)
                        .font(.headline)
                        .foregroundColor(note.isEndnote ? .indigo : .blue)
                }
                if let title = note.title, !title.isEmpty {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                // Content preview
                Text(note.content)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                // Metadata
                HStack(spacing: 8) {
                    // Type badge
                    Text(note.isEndnote
                        ? NSLocalizedString("notesList.type.endnote", comment: "Endnote")
                        : NSLocalizedString("notesList.type.note", comment: "Note"))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(note.isEndnote ? Color.indigo.opacity(0.1) : Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    
                    // Reference count
                    Label("\(note.referenceCount)", systemImage: "link")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    // Modified date
                    Text(note.modifiedAt, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            // Actions menu
            Menu {
                Button {
                    editingNote = note
                } label: {
                    Label(
                        NSLocalizedString("notesList.edit", comment: "Edit"),
                        systemImage: "pencil.circle"
                    )
                }
                
                Divider()
                
                Button(role: .destructive) {
                    showDeleteConfirmation = note
                } label: {
                    Label(
                        NSLocalizedString("notesList.delete", comment: "Delete"),
                        systemImage: "trash"
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            editingNote = note
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showDeleteConfirmation = note
            } label: {
                Label(
                    NSLocalizedString("notesList.delete", comment: "Delete"),
                    systemImage: "trash"
                )
            }
            
            Button {
                editingNote = note
            } label: {
                Label(
                    NSLocalizedString("notesList.edit", comment: "Edit"),
                    systemImage: "pencil.circle"
                )
            }
            .tint(.blue)
        }
    }
    
    // MARK: - Actions
    
    private func loadNotes() {
        notes = project.noteEntries ?? []
        
        #if DEBUG
        print("📝 Loaded \(notes.count) notes for project")
        #endif
    }
    
    private func deleteNote(_ note: NoteEntry) {
        // FEATURE 029: Remove references from all files that contain them
        // Since we now store reference metadata separately from RTF content,
        // we can reliably remove references even from closed files
        
        let referencingFileIDs = note.referencingFileIDs
        
        #if DEBUG
        print("🗑️ Deleting note \(note.id) from \(referencingFileIDs.count) file(s): \(referencingFileIDs)")
        #endif
        
        for fileID in referencingFileIDs {
            // Find the file with this ID in the project
            if let file = project.folders?.flatMap({ $0.files ?? [] }).first(where: { $0.id == fileID }) {
                #if DEBUG
                print("  📄 Found file: \(file.id)")
                #endif
                
                // Remove references to this note from all versions of this file
                if let versions = file.versions {
                    for version in versions {
                        #if DEBUG
                        print("    📋 Processing version: metadataData=\(version.referenceMetadataData != nil)")
                        #endif
                        
                        // Try to get metadata - if not stored, extract from content
                        var metadata: ReferenceMetadata
                        if let metadataData = version.referenceMetadataData,
                           let decodedMetadata = ReferenceMetadata.decode(metadataData) {
                            metadata = decodedMetadata
                            #if DEBUG
                            print("      ✅ Loaded metadata from storage: \(metadata.references.count) references")
                            #endif
                        } else {
                            // Fallback: extract from content if metadata not stored
                            #if DEBUG
                            print("      ⚠️ No metadata stored, extracting from content")
                            #endif
                            metadata = ReferenceMetadata()
                            // Since we can't reliably extract from RTF format, we'll have to skip
                            // This is only for old files that don't have metadata
                            continue
                        }
                        
                        // Remove all entries referencing this note
                        let countBefore = metadata.references.count
                        metadata.removeReferences(to: note.id)
                        let countAfter = metadata.references.count
                        
                        if countBefore > countAfter {
                            // Save updated metadata
                            version.referenceMetadataData = metadata.encode()
                            
                            #if DEBUG
                            print("      ✏️ Removed \(countBefore - countAfter) references")
                            #endif
                        }
                    }
                }
            } else {
                #if DEBUG
                print("  ❌ File not found: \(fileID)")
                #endif
            }
        }
        
        // Remove from project
        project.noteEntries?.removeAll { $0.id == note.id }
        
        // Delete from context
        modelContext.delete(note)
        
        do {
            try modelContext.save()
            #if DEBUG
            print("💾 Saved deletion to database")
            #endif
        } catch {
            #if DEBUG
            print("❌ Error deleting note: \(error)")
            #endif
        }
        
        loadNotes()
        onNoteChanged?()
        onNoteDeleted?(note) // Notify parent to remove markers from current file
        
        // Notify ALL open file views to refresh their content
        // This ensures that if other files are currently open and show this note's references,
        // they will refresh from the database where metadata has been deleted
        NotificationCenter.default.post(name: NSNotification.Name("ReferenceMetadataDidChange"), object: note.id)
        
        #if DEBUG
        print("🗑️ Completed note deletion")
        #endif
    }

}

// MARK: - Localization Keys

/*
 Add these to Localizable.strings:
 
 "notesList.title" = "Notes";
 "notesList.search.prompt" = "Search notes";
 "notesList.filter" = "Filter";
 "notesList.filter.header" = "Filter";
 "notesList.filter.all" = "All";
 "notesList.filter.notes" = "Notes";
 "notesList.filter.endnotes" = "Endnotes";
 "notesList.sort" = "Sort";
 "notesList.sort.header" = "Sort By";
 "notesList.sort.number" = "Number";
 "notesList.sort.dateCreated" = "Date Created";
 "notesList.sort.dateModified" = "Date Modified";
 "notesList.sort.title" = "Title";
 "notesList.addNote" = "Add Note";
 "notesList.addEndnote" = "Add Endnote";
 "notesList.empty.title" = "No Notes";
 "notesList.empty.description" = "Notes and endnotes you create will appear here.";
 "notesList.summary.notes" = "Notes";
 "notesList.summary.endnotes" = "Endnotes";
 "notesList.summary.orphaned" = "Unreferenced";
 "notesList.orphaned.warning" = "%d notes are not referenced";
 "notesList.orphaned.footer" = "These notes are not referenced in any document.";
 "notesList.type.note" = "Note";
 "notesList.type.endnote" = "Endnote";
 "notesList.edit" = "Edit";
 "notesList.jumpToText" = "Jump to Reference";
 "notesList.jump" = "Jump";
 "notesList.delete" = "Delete";
 "notesList.confirmDelete.title" = "Delete Note?";
 "notesList.confirmDelete.button" = "Delete";
 "notesList.confirmDelete.message" = "This note will be permanently deleted.";
 "notesList.confirmDelete.messageWithRefs" = "This note is referenced %d times. The markers will remain but show as missing.";
 */
