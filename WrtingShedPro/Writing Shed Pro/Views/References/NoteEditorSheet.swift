//
//  NoteEditorSheet.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System
//  Created by GitHub Copilot on 15/01/2026.
//
//  Sheet for creating and editing notes/endnotes
//

import SwiftUI
import SwiftData

/// Sheet view for creating or editing a note/endnote
struct NoteEditorSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    /// The project this note belongs to
    let project: Project
    
    /// Existing note to edit (nil for new note)
    let existingNote: NoteEntry?
    
    /// Whether this is an endnote (superscript [n]) or general note ([Note n])
    let isEndnote: Bool
    
    /// Callback when note is saved, returns the note entry for marker insertion
    var onSave: ((NoteEntry) -> Void)?
    
    /// Callback when cancelled
    var onCancel: (() -> Void)?
    
    // MARK: - State
    
    @State private var noteContent: String = ""
    @State private var noteTitle: String = ""
    @State private var noteTag: String = ""
    @State private var selectedExistingNoteID: UUID?
    @State private var mode: EditorMode = .createNew
    
    // MARK: - Mode enum
    
    enum EditorMode {
        case selectOrCreate
        case createNew
        case referenceExisting
    }
    
    // MARK: - Computed Properties
    
    private var isEditing: Bool {
        existingNote != nil
    }
    
    private var hasChanges: Bool {
        if let existing = existingNote {
            return noteContent != existing.content || noteTitle != (existing.title ?? "") || noteTag != (existing.tag ?? "")
        }
        return !noteContent.isEmpty || !noteTitle.isEmpty || !noteTag.isEmpty
    }
    
    private var canSave: Bool {
        !noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !noteTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var existingNotesOfType: [NoteEntry] {
        project.noteEntries?.filter { $0.isEndnote == isEndnote } ?? []
    }
    
    private var navigationTitle: String {
        if isEditing {
            return isEndnote 
                ? NSLocalizedString("noteEditor.editEndnote.title", comment: "Edit Endnote")
                : NSLocalizedString("noteEditor.editNote.title", comment: "Edit Note")
        } else {
            return isEndnote
                ? NSLocalizedString("noteEditor.newEndnote.title", comment: "New Endnote")
                : NSLocalizedString("noteEditor.newNote.title", comment: "New Note")
        }
    }
    
    // MARK: - Initialization
    
    init(
        project: Project,
        existingNote: NoteEntry? = nil,
        isEndnote: Bool = false,
        onSave: ((NoteEntry) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.project = project
        self.existingNote = existingNote
        self.isEndnote = existingNote?.isEndnote ?? isEndnote
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Initialize state from existing note
        if let existing = existingNote {
            _noteContent = State(initialValue: existing.content)
            _noteTitle = State(initialValue: existing.title ?? "")
            _noteTag = State(initialValue: existing.tag ?? "")
            _mode = State(initialValue: .createNew)
        } else {
            // For new notes, check if there are existing notes to reference
            let existingNotes = (project.noteEntries?.filter { $0.isEndnote == isEndnote } ?? []).isEmpty
            _mode = State(initialValue: existingNotes ? .createNew : .selectOrCreate)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !isEditing && existingNotesOfType.isEmpty {
                    // Only create new option if no existing notes
                    createNewNoteForm
                } else if !isEditing && !existingNotesOfType.isEmpty {
                    // Show mode selector
                    modeSelector
                    Divider()
                    
                    // Content based on mode
                    if mode == .referenceExisting {
                        referenceExistingForm
                    } else {
                        createNewNoteForm
                    }
                } else {
                    // Editing existing note
                    createNewNoteForm
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        onCancel?()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.save", comment: "Save")) {
                        saveNote()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
    
    // MARK: - Mode Selector
    
    private var modeSelector: some View {
        Picker("Note Action", selection: $mode) {
            Text("Create New").tag(EditorMode.createNew)
            Text("Reference Existing").tag(EditorMode.referenceExisting)
        }
        .pickerStyle(.segmented)
        .padding()
    }
    
    // MARK: - Create New Form
    
    private var createNewNoteForm: some View {
        Form {
            // Title section
            Section {
                TextField(
                    NSLocalizedString("noteEditor.title.placeholder", comment: "Title (optional)"),
                    text: $noteTitle
                )
            } header: {
                Text(NSLocalizedString("noteEditor.title.header", comment: "Title"))
            } footer: {
                Text(NSLocalizedString("noteEditor.title.footer", comment: "Optional title for organizing notes"))
            }
            
            // Tag section (required for tag-based system)
            Section {
                TextField(
                    "e.g., timeline-1, character-insight",
                    text: $noteTag
                )
                .autocorrectionDisabled()
            } header: {
                Text("Tag")
            } footer: {
                Text("Unique identifier for this note (e.g., 'timeline-1' or 'foreshadow')")
            }
            
            // Content section
            Section {
                TextEditor(text: $noteContent)
                    .font(.body)
            } header: {
                Text(NSLocalizedString("noteEditor.content.header", comment: "Content"))
            }
            
            // Info section (for existing notes)
            if let existing = existingNote {
                Section {
                    infoSection(for: existing)
                } header: {
                    Text(NSLocalizedString("noteEditor.info.header", comment: "Information"))
                }
            }
        }
    }
    
    // MARK: - Reference Existing Form
    
    private var referenceExistingForm: some View {
        Form {
            Section {
                Picker("Select Note", selection: $selectedExistingNoteID) {
                    ForEach(existingNotesOfType) { note in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    if let tag = note.tag {
                                        Text(tag)
                                            .font(.headline)
                                    }
                                    if let title = note.title {
                                        Text(title)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(note.referenceCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(Optional(note.id))
                    }
                }
            } header: {
                Text("Choose Existing Note")
            } footer: {
                Text("Select an existing note to reference from this location")
            }
        }
    }
    
    // MARK: - Info Section
    
    @ViewBuilder
    private func infoSection(for note: NoteEntry) -> some View {
        LabeledContent(NSLocalizedString("noteEditor.info.number", comment: "Number")) {
            Text("\(note.displayNumber)")
        }
        
        LabeledContent(NSLocalizedString("noteEditor.info.references", comment: "References")) {
            Text("\(note.referenceCount)")
                .foregroundColor(note.referenceCount == 0 ? .orange : .primary)
        }
        
        LabeledContent(NSLocalizedString("noteEditor.info.created", comment: "Created")) {
            Text(note.createdAt, format: .dateTime.day().month().year())
        }
        
        LabeledContent(NSLocalizedString("noteEditor.info.modified", comment: "Modified")) {
            Text(note.modifiedAt, format: .dateTime.day().month().year())
        }
    }
    
    // MARK: - Actions
    
    private func saveNote() {
        if mode == .referenceExisting, let selectedID = selectedExistingNoteID,
           let selectedNote = existingNotesOfType.first(where: { $0.id == selectedID }) {
            // Reference existing note
            onSave?(selectedNote)
            dismiss()
        } else {
            // Create new note or update existing
            let trimmedContent = noteContent.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedTag = noteTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedContent.isEmpty && !trimmedTag.isEmpty else { return }
            
            let note: NoteEntry
            
            if let existing = existingNote {
                // Update existing note
                existing.content = trimmedContent
                existing.title = noteTitle.isEmpty ? nil : noteTitle
                existing.tag = trimmedTag.isEmpty ? nil : trimmedTag
                existing.modifiedAt = Date()
                note = existing
                
                #if DEBUG
                print("📝 Updated note: \(note.id), tag: \(trimmedTag)")
                #endif
            } else {
                // Create new note
                note = NoteEntry(
                    project: project,
                    content: trimmedContent,
                    isEndnote: isEndnote,
                    displayNumber: calculateNextNumber(),
                    title: noteTitle.isEmpty ? nil : noteTitle,
                    tag: trimmedTag
                )
                
                // Add to project's notes
                if project.noteEntries == nil {
                    project.noteEntries = []
                }
                project.noteEntries?.append(note)
                
                #if DEBUG
                print("📝 Created new note: \(note.id), tag: \(trimmedTag)")
                #endif
            }
            
            // Save context
            do {
                try modelContext.save()
            } catch {
                #if DEBUG
                print("❌ Error saving note: \(error)")
                #endif
            }
            
            onSave?(note)
            dismiss()
        }
    }
    
    private func calculateNextNumber() -> Int {
        // Get all existing notes of the same type and find the max number
        let existingNotes = project.noteEntries?.filter { $0.isEndnote == isEndnote } ?? []
        let maxNumber = existingNotes.map { $0.displayNumber }.max() ?? 0
        return maxNumber + 1
    }
}

// MARK: - Localization Keys

/*
 Add these to Localizable.strings:
 
 "noteEditor.editEndnote.title" = "Edit Endnote";
 "noteEditor.editNote.title" = "Edit Note";
 "noteEditor.newEndnote.title" = "New Endnote";
 "noteEditor.newNote.title" = "New Note";
 "noteEditor.title.placeholder" = "Title (optional)";
 "noteEditor.title.header" = "Title";
 "noteEditor.title.footer" = "Optional title for organizing notes";
 "noteEditor.content.header" = "Content";
 "noteEditor.endnote.footer" = "Endnotes appear as superscript numbers in the text";
 "noteEditor.note.footer" = "Notes appear as [Note n] in the text";
 "noteEditor.preview.header" = "Preview";
 "noteEditor.preview.marker" = "Marker:";
 "noteEditor.preview.markerNote" = "(number assigned on insert)";
 "noteEditor.info.header" = "Information";
 "noteEditor.info.number" = "Number";
 "noteEditor.info.references" = "References";
 "noteEditor.info.created" = "Created";
 "noteEditor.info.modified" = "Modified";
 "noteEditor.discard.title" = "Discard Changes?";
 "noteEditor.discard.button" = "Discard";
 "noteEditor.discard.message" = "Your changes will be lost.";
 */
