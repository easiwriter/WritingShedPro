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
            return noteContent != existing.content || noteTag != (existing.tag ?? "")
        }
        return !noteContent.isEmpty || !noteTag.isEmpty
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
            _noteTag = State(initialValue: existing.tag ?? "")
            _mode = State(initialValue: .createNew)
        } else {
            // For new notes, check if there are existing notes to reference
            let existingNotes = (project.noteEntries?.filter { $0.isEndnote == isEndnote } ?? []).isEmpty
            _mode = State(initialValue: existingNotes ? .createNew : .selectOrCreate)
        }
    }
    
    // MARK: - Body
    /// COPILOT NOTE: For standard iOS dialog styling:
    /// 1. Use NavigationStack (not NavigationView) 
    /// 2. Use Form (not VStack) as the main container
    /// Form applies iOS styling conventions that make toolbar buttons render as white outlined.
    /// NavigationStack + Form = standard iOS dialog appearance with correct button styling.
    
    var body: some View {
        NavigationStack {
            Form {
                if !isEditing && existingNotesOfType.isEmpty {
                    // Only create new option if no existing notes
                    createNewNoteForm
                } else if !isEditing && !existingNotesOfType.isEmpty {
                    // Show mode selector
                    Section {
                        modeSelector
                    }
                    
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
    /// COPILOT NOTE: Always use HStack with .buttonBorderShape(.capsule) and .buttonStyle(.bordered)
    /// for toggle-style mode selection. Do NOT use .segmented style.
    
    private var modeSelector: some View {
        HStack(spacing: 8) {
            Button(action: { mode = .createNew }) {
                Text("Create New")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(mode == .createNew ? .white : .gray)
            .background(mode == .createNew ? Color.blue : Color.clear)
            
            Button(action: { mode = .referenceExisting }) {
                Text("Reference Existing")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(mode == .referenceExisting ? .white : .gray)
            .background(mode == .referenceExisting ? Color.blue : Color.clear)
        }
        .padding()
    }
    
    // MARK: - Create New Form
    
    @ViewBuilder
    private var createNewNoteForm: some View {
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
                .frame(minHeight: 300, maxHeight: .infinity)
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
    
    // MARK: - Reference Existing Form
    
    private var referenceExistingForm: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(existingNotesOfType) { note in
                        Button(action: { 
                            if selectedExistingNoteID == note.id {
                                selectedExistingNoteID = nil
                            } else {
                                selectedExistingNoteID = note.id
                            }
                        }) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    if let tag = note.tag {
                                        Text(tag)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    }
                                    if let title = note.title {
                                        Text(title)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(note.content)
                                        .font(.caption)
                                        .lineLimit(2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    if selectedExistingNoteID == note.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                    }
                                    Text("\(note.referenceCount)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .background(selectedExistingNoteID == note.id ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                        }
                        
                        if note.id != existingNotesOfType.last?.id {
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 300)
            .border(Color.gray.opacity(0.2))
            .cornerRadius(8)
            .padding()
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
                    title: nil,  // Title field removed - use tag instead
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
