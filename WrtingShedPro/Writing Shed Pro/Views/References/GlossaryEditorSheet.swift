//
//  GlossaryEditorSheet.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System
//  Created by GitHub Copilot on 15/01/2026.
//
//  Sheet for creating and editing glossary terms
//

import SwiftUI
import SwiftData

/// Sheet view for creating or editing a glossary term
struct GlossaryEditorSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    /// The project this glossary term belongs to
    let project: Project
    
    /// Existing term to edit (nil for new term)
    let existingTerm: GlossaryEntry?
    
    /// Callback when term is saved, returns the entry for marker insertion
    var onSave: ((GlossaryEntry) -> Void)?
    
    /// Callback when cancelled
    var onCancel: (() -> Void)?
    
    // MARK: - State
    
    @State private var termName: String = ""
    @State private var termDefinition: String = ""
    @State private var showDiscardConfirmation = false
    
    // MARK: - Computed Properties
    
    private var isEditing: Bool {
        existingTerm != nil
    }
    
    private var hasChanges: Bool {
        if let existing = existingTerm {
            return termName != existing.term ||
                   termDefinition != existing.definition
        }
        return !termName.isEmpty || !termDefinition.isEmpty
    }
    
    private var canSave: Bool {
        !termName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !termDefinition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var navigationTitle: String {
        isEditing
            ? NSLocalizedString("glossaryEditor.editTerm.title", comment: "Edit Term")
            : NSLocalizedString("glossaryEditor.newTerm.title", comment: "New Glossary Term")
    }
    
    private var termExists: Bool {
        guard !termName.isEmpty else { return false }
        let trimmedTerm = termName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return project.glossaryEntries?.contains { entry in
            entry.id != existingTerm?.id &&
            entry.term.lowercased() == trimmedTerm
        } ?? false
    }
    
    // MARK: - Initialization
    
    init(
        project: Project,
        existingTerm: GlossaryEntry? = nil,
        onSave: ((GlossaryEntry) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.project = project
        self.existingTerm = existingTerm
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Initialize state from existing term
        if let existing = existingTerm {
            _termName = State(initialValue: existing.term)
            _termDefinition = State(initialValue: existing.definition)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Term section
                Section {
                    TextField(
                        NSLocalizedString("glossaryEditor.term.placeholder", comment: "Term"),
                        text: $termName
                    )
                    .autocapitalization(.words)
                    
                    if termExists {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(NSLocalizedString("glossaryEditor.term.exists", comment: "This term already exists"))
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("glossaryEditor.term.header", comment: "Term"))
                } footer: {
                    Text(NSLocalizedString("glossaryEditor.term.footer", comment: "The word or phrase to define"))
                }
                
                // Definition section
                Section {
                    TextEditor(text: $termDefinition)
                        .frame(minHeight: 100)
                        .font(.body)
                } header: {
                    Text(NSLocalizedString("glossaryEditor.definition.header", comment: "Definition"))
                } footer: {
                    Text(NSLocalizedString("glossaryEditor.definition.footer", comment: "Explanation of the term"))
                }
                
                // Preview section
                Section {
                    previewSection
                } header: {
                    Text(NSLocalizedString("glossaryEditor.preview.header", comment: "Preview"))
                }
                
                // Info section (for existing terms)
                if let existing = existingTerm {
                    Section {
                        infoSection(for: existing)
                    } header: {
                        Text(NSLocalizedString("glossaryEditor.info.header", comment: "Information"))
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
                        saveTerm()
                    }
                    .disabled(!canSave || termExists)
                }
            }
            .confirmationDialog(
                NSLocalizedString("glossaryEditor.discard.title", comment: "Discard Changes?"),
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("glossaryEditor.discard.button", comment: "Discard"), role: .destructive) {
                    onCancel?()
                    dismiss()
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("glossaryEditor.discard.message", comment: "Your changes will be lost."))
            }
        }
    }
    
    // MARK: - Preview Section
    
    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Marker preview
            HStack {
                Text(NSLocalizedString("glossaryEditor.preview.marker", comment: "Marker:"))
                    .foregroundColor(.secondary)
                
                if !termName.isEmpty {
                    Text("[\(termName)]")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.teal)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.teal.opacity(0.1))
                        .cornerRadius(3)
                } else {
                    Text("[Term]")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.teal.opacity(0.5))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.teal.opacity(0.05))
                        .cornerRadius(3)
                }
            }
            
            // Definition preview
            if !termDefinition.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(termName.isEmpty ? "Term" : termName)
                        .font(.headline)
                    
                    Text(termDefinition)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }
            }
        }
    }
    
    // MARK: - Info Section
    
    @ViewBuilder
    private func infoSection(for term: GlossaryEntry) -> some View {
        LabeledContent(NSLocalizedString("glossaryEditor.info.references", comment: "References")) {
            Text("\(term.referenceCount)")
                .foregroundColor(term.referenceCount == 0 ? .orange : .primary)
        }
        
        LabeledContent(NSLocalizedString("glossaryEditor.info.created", comment: "Created")) {
            Text(term.createdAt, format: .dateTime.day().month().year())
        }
        
        LabeledContent(NSLocalizedString("glossaryEditor.info.modified", comment: "Modified")) {
            Text(term.modifiedAt, format: .dateTime.day().month().year())
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
    
    private func saveTerm() {
        let trimmedTerm = termName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDefinition = termDefinition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty, !trimmedDefinition.isEmpty else { return }
        
        let entry: GlossaryEntry
        
        if let existing = existingTerm {
            // Update existing term
            existing.term = trimmedTerm
            existing.definition = trimmedDefinition
            existing.modifiedAt = Date()
            entry = existing
            
            #if DEBUG
            print("📖 Updated glossary term: \(entry.term)")
            #endif
        } else {
            // Create new term
            entry = GlossaryEntry(
                project: project,
                term: trimmedTerm,
                definition: trimmedDefinition
            )
            
            // Add to project's glossary
            if project.glossaryEntries == nil {
                project.glossaryEntries = []
            }
            project.glossaryEntries?.append(entry)
            
            #if DEBUG
            print("📖 Created new glossary term: \(entry.term)")
            #endif
        }
        
        // Save context
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("❌ Error saving glossary term: \(error)")
            #endif
        }
        
        onSave?(entry)
        dismiss()
    }
}

// MARK: - Localization Keys

/*
 Add these to Localizable.strings:
 
 "glossaryEditor.editTerm.title" = "Edit Term";
 "glossaryEditor.newTerm.title" = "New Glossary Term";
 "glossaryEditor.term.placeholder" = "Term";
 "glossaryEditor.term.header" = "Term";
 "glossaryEditor.term.footer" = "The word or phrase to define";
 "glossaryEditor.term.exists" = "This term already exists";
 "glossaryEditor.definition.header" = "Definition";
 "glossaryEditor.definition.footer" = "Explanation of the term";
 "glossaryEditor.pronunciation.placeholder" = "e.g., /ˈɡlɒsəri/";
 "glossaryEditor.pronunciation.header" = "Pronunciation";
 "glossaryEditor.pronunciation.footer" = "Optional phonetic spelling";
 "glossaryEditor.preview.header" = "Preview";
 "glossaryEditor.preview.marker" = "Marker:";
 "glossaryEditor.info.header" = "Information";
 "glossaryEditor.info.references" = "References";
 "glossaryEditor.info.created" = "Created";
 "glossaryEditor.info.modified" = "Modified";
 "glossaryEditor.discard.title" = "Discard Changes?";
 "glossaryEditor.discard.button" = "Discard";
 "glossaryEditor.discard.message" = "Your changes will be lost.";
 */
