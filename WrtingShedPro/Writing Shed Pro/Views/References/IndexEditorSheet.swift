//
//  IndexEditorSheet.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System
//  Created by GitHub Copilot on 15/01/2026.
//
//  Sheet for creating and editing index entries
//

import SwiftUI
import SwiftData

/// Sheet view for creating or editing an index entry
struct IndexEditorSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    /// The project this index entry belongs to
    let project: Project
    
    /// Existing entry to edit (nil for new entry)
    let existingEntry: IndexEntry?
    
    /// Callback when entry is saved, returns the entry for marker insertion
    var onSave: ((IndexEntry) -> Void)?
    
    /// Callback when cancelled
    var onCancel: (() -> Void)?
    
    // MARK: - State
    
    @State private var keyword: String = ""
    @State private var showDiscardConfirmation = false
    
    // MARK: - Computed Properties
    
    private var isEditing: Bool {
        existingEntry != nil
    }
    
    private var hasChanges: Bool {
        if let existing = existingEntry {
            return keyword != existing.keyword
        }
        return !keyword.isEmpty
    }
    
    private var canSave: Bool {
        !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var navigationTitle: String {
        isEditing
            ? NSLocalizedString("indexEditor.editEntry.title", comment: "Edit Index Entry")
            : NSLocalizedString("indexEditor.newEntry.title", comment: "New Index Entry")
    }
    
    private var termExists: Bool {
        guard !keyword.isEmpty else { return false }
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return project.indexEntries?.contains { entry in
            entry.id != existingEntry?.id &&
            entry.keyword.lowercased() == trimmedKeyword
        } ?? false
    }
    
    // MARK: - Initialization
    
    init(
        project: Project,
        existingEntry: IndexEntry? = nil,
        onSave: ((IndexEntry) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.project = project
        self.existingEntry = existingEntry
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Initialize state from existing entry
        if let existing = existingEntry {
            _keyword = State(initialValue: existing.keyword)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Keyword section
                Section {
                    TextField(
                        NSLocalizedString("indexEditor.keyword.placeholder", comment: "Index keyword"),
                        text: $keyword
                    )
                    .autocapitalization(.words)
                    
                    if termExists {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(NSLocalizedString("indexEditor.keyword.exists", comment: "This keyword already exists"))
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("indexEditor.keyword.header", comment: "Keyword"))
                } footer: {
                    Text(NSLocalizedString("indexEditor.keyword.footer", comment: "The word or phrase to add to the index"))
                }
                
                // Preview section
                Section {
                    previewSection
                } header: {
                    Text(NSLocalizedString("indexEditor.preview.header", comment: "Preview"))
                }
                
                // Info section (for existing entries)
                if let existing = existingEntry {
                    Section {
                        infoSection(for: existing)
                    } header: {
                        Text(NSLocalizedString("indexEditor.info.header", comment: "Information"))
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
                        saveEntry()
                    }
                    .disabled(!canSave || termExists)
                }
            }
            .confirmationDialog(
                NSLocalizedString("indexEditor.discard.title", comment: "Discard Changes?"),
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("indexEditor.discard.button", comment: "Discard"), role: .destructive) {
                    onCancel?()
                    dismiss()
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("indexEditor.discard.message", comment: "Your changes will be lost."))
            }
        }
    }
    
    // MARK: - Preview Section
    
    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // How marker appears (invisible in document)
            HStack {
                Text(NSLocalizedString("indexEditor.preview.marker", comment: "Marker:"))
                    .foregroundColor(.secondary)
                
                Text(NSLocalizedString("indexEditor.preview.invisible", comment: "(invisible in text)"))
                    .font(.caption)
                    .foregroundColor(.purple)
                    .italic()
            }
            
            Divider()
            
            // How it appears in the index
            HStack {
                Text(NSLocalizedString("indexEditor.preview.indexAppearance", comment: "In index:"))
                    .foregroundColor(.secondary)
                
                Text(keyword.isEmpty ? "Keyword" : keyword)
                    .font(.body)
                    .foregroundColor(keyword.isEmpty ? .secondary : .primary)
                
                Text("... 12, 45, 78")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Info Section
    
    @ViewBuilder
    private func infoSection(for entry: IndexEntry) -> some View {
        LabeledContent(NSLocalizedString("indexEditor.info.references", comment: "References")) {
            Text("\(entry.referenceCount)")
                .foregroundColor(entry.referenceCount == 0 ? .orange : .primary)
        }
        
        if let children = entry.childEntries, !children.isEmpty {
            LabeledContent(NSLocalizedString("indexEditor.info.subEntries", comment: "Sub-entries")) {
                Text("\(children.count)")
            }
        }
        
        LabeledContent(NSLocalizedString("indexEditor.info.created", comment: "Created")) {
            Text(entry.createdAt, format: .dateTime.day().month().year())
        }
        
        LabeledContent(NSLocalizedString("indexEditor.info.modified", comment: "Modified")) {
            Text(entry.modifiedAt, format: .dateTime.day().month().year())
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
    
    private func saveEntry() {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else { return }
        
        let entry: IndexEntry
        
        if let existing = existingEntry {
            // Update existing entry
            existing.keyword = trimmedKeyword
            existing.modifiedAt = Date()
            entry = existing
            
            #if DEBUG
            print("📑 Updated index entry: \(entry.keyword)")
            #endif
        } else {
            // Create new entry
            entry = IndexEntry(
                project: project,
                keyword: trimmedKeyword
            )
            
            // Add to project's index entries
            if project.indexEntries == nil {
                project.indexEntries = []
            }
            project.indexEntries?.append(entry)
            
            #if DEBUG
            print("📑 Created new index entry: \(entry.keyword)")
            #endif
        }
        
        // Save context
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("❌ Error saving index entry: \(error)")
            #endif
        }
        
        onSave?(entry)
        dismiss()
    }
}

// MARK: - Localization Keys

/*
 Add these to Localizable.strings:
 
 "indexEditor.editEntry.title" = "Edit Index Entry";
 "indexEditor.newEntry.title" = "New Index Entry";
 "indexEditor.keyword.placeholder" = "Index keyword";
 "indexEditor.keyword.header" = "Keyword";
 "indexEditor.keyword.footer" = "The word or phrase to add to the index";
 "indexEditor.keyword.exists" = "This keyword already exists";
 "indexEditor.preview.header" = "Preview";
 "indexEditor.preview.marker" = "Marker:";
 "indexEditor.preview.invisible" = "(invisible in text)";
 "indexEditor.preview.indexAppearance" = "In index:";
 "indexEditor.info.header" = "Information";
 "indexEditor.info.references" = "References";
 "indexEditor.info.subEntries" = "Sub-entries";
 "indexEditor.info.created" = "Created";
 "indexEditor.info.modified" = "Modified";
 "indexEditor.discard.title" = "Discard Changes?";
 "indexEditor.discard.button" = "Discard";
 "indexEditor.discard.message" = "Your changes will be lost.";
 */
