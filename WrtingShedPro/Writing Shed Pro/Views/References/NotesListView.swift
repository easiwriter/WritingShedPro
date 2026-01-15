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

/// Filter options for notes list
enum NotesFilter: String, CaseIterable {
    case all = "All"
    case notes = "Notes"
    case endnotes = "Endnotes"
    
    var localizedTitle: String {
        switch self {
        case .all:
            return NSLocalizedString("notesList.filter.all", comment: "All")
        case .notes:
            return NSLocalizedString("notesList.filter.notes", comment: "Notes")
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
    
    /// Callback when user wants to jump to a note marker in the text
    var onJumpToNote: ((NoteEntry) -> Void)?
    
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
    
    // MARK: - Computed Properties
    
    private var filteredNotes: [NoteEntry] {
        var result = notes
        
        // Apply filter
        switch filter {
        case .all:
            break
        case .notes:
            result = result.filter { !$0.isEndnote }
        case .endnotes:
            result = result.filter { $0.isEndnote }
        }
        
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
        NavigationView {
            Group {
                if notes.isEmpty {
                    emptyState
                } else {
                    notesList
                }
            }
            .navigationTitle(NSLocalizedString("notesList.title", comment: "Notes"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: NSLocalizedString("notesList.search.prompt", comment: "Search notes"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        onDismiss?()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            addNoteAsEndnote = false
                            showAddNoteSheet = true
                        } label: {
                            Label(
                                NSLocalizedString("notesList.addNote", comment: "Add Note"),
                                systemImage: "note.text.badge.plus"
                            )
                        }
                        
                        Button {
                            addNoteAsEndnote = true
                            showAddNoteSheet = true
                        } label: {
                            Label(
                                NSLocalizedString("notesList.addEndnote", comment: "Add Endnote"),
                                systemImage: "number.circle.fill"
                            )
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        // Filter section
                        Section(NSLocalizedString("notesList.filter.header", comment: "Filter")) {
                            Picker(selection: $filter) {
                                ForEach(NotesFilter.allCases, id: \.self) { filterOption in
                                    Text(filterOption.localizedTitle)
                                        .tag(filterOption)
                                }
                            } label: {
                                Text(NSLocalizedString("notesList.filter", comment: "Filter"))
                            }
                        }
                        
                        // Sort section
                        Section(NSLocalizedString("notesList.sort.header", comment: "Sort By")) {
                            Picker(selection: $sortOrder) {
                                ForEach(NotesSortOrder.allCases, id: \.self) { sortOption in
                                    Text(sortOption.localizedTitle)
                                        .tag(sortOption)
                                }
                            } label: {
                                Text(NSLocalizedString("notesList.sort", comment: "Sort"))
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .onAppear {
            loadNotes()
        }
        .onChange(of: notes) { oldValue, newValue in
            // Auto-dismiss when all notes are deleted
            if newValue.isEmpty && !oldValue.isEmpty {
                onDismiss?()
                dismiss()
            }
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
                Text(String(format: NSLocalizedString("notesList.confirmDelete.messageWithRefs", comment: ""), note.referenceCount))
            } else {
                Text(NSLocalizedString("notesList.confirmDelete.message", comment: "This note will be permanently deleted."))
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
        } actions: {
            HStack(spacing: 16) {
                Button {
                    addNoteAsEndnote = false
                    showAddNoteSheet = true
                } label: {
                    Label(
                        NSLocalizedString("notesList.addNote", comment: "Add Note"),
                        systemImage: "note.text.badge.plus"
                    )
                }
                .buttonStyle(.bordered)
                
                Button {
                    addNoteAsEndnote = true
                    showAddNoteSheet = true
                } label: {
                    Label(
                        NSLocalizedString("notesList.addEndnote", comment: "Add Endnote"),
                        systemImage: "number.circle.fill"
                    )
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // MARK: - Notes List
    
    private var notesList: some View {
        List {
            // Summary section
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("notesList.summary.notes", comment: "Notes"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(notesCount)")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center) {
                        Text(NSLocalizedString("notesList.summary.endnotes", comment: "Endnotes"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(endnotesCount)")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(NSLocalizedString("notesList.summary.orphaned", comment: "Unreferenced"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(orphanedNotes.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(orphanedNotes.isEmpty ? .primary : .orange)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Orphaned notes warning
            if !orphanedNotes.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(String(format: NSLocalizedString("notesList.orphaned.warning", comment: ""), orphanedNotes.count))
                            .font(.subheadline)
                    }
                } footer: {
                    Text(NSLocalizedString("notesList.orphaned.footer", comment: "These notes are not referenced in any document."))
                }
            }
            
            // Notes list
            Section {
                ForEach(filteredNotes) { note in
                    noteRow(note)
                }
            } header: {
                HStack {
                    Text(filter.localizedTitle)
                    Spacer()
                    Text("\(filteredNotes.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Note Row
    
    @ViewBuilder
    private func noteRow(_ note: NoteEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Note type and number badge
            VStack {
                ZStack {
                    Circle()
                        .fill(note.isEndnote ? Color.indigo.opacity(0.1) : Color.blue.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    if note.isEndnote {
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
                // Title (if present)
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
                
                if note.referenceCount > 0 {
                    Button {
                        onJumpToNote?(note)
                        dismiss()
                    } label: {
                        Label(
                            NSLocalizedString("notesList.jumpToText", comment: "Jump to Reference"),
                            systemImage: "arrow.right"
                        )
                    }
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
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if note.referenceCount > 0 {
                Button {
                    onJumpToNote?(note)
                    dismiss()
                } label: {
                    Label(
                        NSLocalizedString("notesList.jump", comment: "Jump"),
                        systemImage: "arrow.right"
                    )
                }
                .tint(.green)
            }
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
        // Remove from project
        project.noteEntries?.removeAll { $0.id == note.id }
        
        // Delete from context
        modelContext.delete(note)
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("❌ Error deleting note: \(error)")
            #endif
        }
        
        loadNotes()
        onNoteChanged?()
        onNoteDeleted?(note) // Notify parent to remove markers from text
        
        #if DEBUG
        print("🗑️ Deleted note: \(note.id)")
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
