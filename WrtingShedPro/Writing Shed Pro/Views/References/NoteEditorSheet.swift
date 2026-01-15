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
    @State private var showDiscardConfirmation = false
    
    // MARK: - Computed Properties
    
    private var isEditing: Bool {
        existingNote != nil
    }
    
    private var hasChanges: Bool {
        if let existing = existingNote {
            return noteContent != existing.content || noteTitle != (existing.title ?? "")
        }
        return !noteContent.isEmpty || !noteTitle.isEmpty
    }
    
    private var canSave: Bool {
        !noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Title section (optional)
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
                
                // Content section
                Section {
                    TextEditor(text: $noteContent)
                        .frame(minHeight: 150)
                        .font(.body)
                } header: {
                    Text(NSLocalizedString("noteEditor.content.header", comment: "Content"))
                } footer: {
                    if isEndnote {
                        Text(NSLocalizedString("noteEditor.endnote.footer", comment: "Endnotes appear as superscript numbers in the text"))
                    } else {
                        Text(NSLocalizedString("noteEditor.note.footer", comment: "Notes appear as [Note n] in the text"))
                    }
                }
                
                // Preview section
                Section {
                    previewSection
                } header: {
                    Text(NSLocalizedString("noteEditor.preview.header", comment: "Preview"))
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
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        handleCancel()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.save", comment: "Save")) {
                        saveNote()
                    }
                    .disabled(!canSave)
                }
            }
            .confirmationDialog(
                NSLocalizedString("noteEditor.discard.title", comment: "Discard Changes?"),
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("noteEditor.discard.button", comment: "Discard"), role: .destructive) {
                    onCancel?()
                    dismiss()
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("noteEditor.discard.message", comment: "Your changes will be lost."))
            }
        }
    }
    
    // MARK: - Preview Section
    
    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Marker preview
            HStack {
                Text(NSLocalizedString("noteEditor.preview.marker", comment: "Marker:"))
                    .foregroundColor(.secondary)
                
                if isEndnote {
                    Text("[n]")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(3)
                } else {
                    Text("[Note n]")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(3)
                }
                
                Text(NSLocalizedString("noteEditor.preview.markerNote", comment: "(number assigned on insert)"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Content preview
            if !noteContent.isEmpty {
                Divider()
                
                Text(noteContent)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(5)
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
    
    private func handleCancel() {
        if hasChanges {
            showDiscardConfirmation = true
        } else {
            onCancel?()
            dismiss()
        }
    }
    
    private func saveNote() {
        let trimmedContent = noteContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        let note: NoteEntry
        
        if let existing = existingNote {
            // Update existing note
            existing.content = trimmedContent
            existing.title = noteTitle.isEmpty ? nil : noteTitle
            existing.modifiedAt = Date()
            note = existing
            
            #if DEBUG
            print("📝 Updated note: \(note.id)")
            #endif
        } else {
            // Create new note
            note = NoteEntry(
                project: project,
                content: trimmedContent,
                isEndnote: isEndnote,
                displayNumber: calculateNextNumber(),
                title: noteTitle.isEmpty ? nil : noteTitle
            )
            
            // Add to project's notes
            if project.noteEntries == nil {
                project.noteEntries = []
            }
            project.noteEntries?.append(note)
            
            #if DEBUG
            print("📝 Created new note: \(note.id), number: \(note.displayNumber)")
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
