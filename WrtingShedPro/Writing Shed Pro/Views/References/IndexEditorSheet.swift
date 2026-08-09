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
    
    /// Keyword pre-filled from context menu selection
    let prefilledKeyword: String?
    
    /// Callback when entry is saved, returns the entry for marker insertion
    var onSave: ((IndexEntry, Bool) -> Void)?  // Bool is isPrimaryReference
    
    /// Callback when cancelled
    var onCancel: (() -> Void)?
    
    // MARK: - State
    
    @State private var keyword: String = ""
    @State private var selectedParent: IndexEntry? = nil
    @State private var isPrimaryReference: Bool = false
    @State private var selectedSeeEntry: IndexEntry? = nil  // "see" cross-reference entry
    @State private var selectedSeeAlsoEntries: Set<UUID> = []  // "see also" entry IDs
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    @State private var isSaving = false
    
    // MARK: - Computed Properties
    
    private var isEditing: Bool {
        existingEntry != nil
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
        if isSaving { return false }
        guard !keyword.isEmpty else { return false }
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return project.indexEntries?.contains { entry in
            entry.id != existingEntry?.id &&
            entry.keyword.lowercased() == trimmedKeyword &&
            entry.parentEntry?.id == selectedParent?.id  // Same parent = duplicate
        } ?? false
    }
    
    /// Keyword suggestions based on partial input (for autocomplete)
    private var keywordSuggestions: [IndexEntry] {
        guard !keyword.isEmpty, keyword.count >= 2, existingEntry == nil else { return [] }
        let searchTerm: String = keyword.lowercased()
        guard let entries = project.indexEntries else { return [] }
        return entries.filter { (entry: IndexEntry) -> Bool in
            entry.keyword.lowercased().contains(searchTerm) &&
            entry.keyword.lowercased() != searchTerm  // Don't suggest exact match
        }
        .sorted { (a: IndexEntry, b: IndexEntry) -> Bool in a.keyword.localizedCaseInsensitiveCompare(b.keyword) == .orderedAscending }
        .prefix(5)
        .map { $0 }
    }
    
    /// Available parent entries (only show entries that can have children - depth < 3)
    private var availableParents: [IndexEntry] {
        guard let entries = project.indexEntries else { return [] }
        return entries.filter { (entry: IndexEntry) -> Bool in
            entry.id != existingEntry?.id &&  // Can't be parent of itself
            entry.canHaveChildren &&  // Respects max depth
            !isDescendant(entry, of: existingEntry)  // Prevent circular references
        }.sorted { (a: IndexEntry, b: IndexEntry) -> Bool in a.keyword.localizedCaseInsensitiveCompare(b.keyword) == .orderedAscending }
    }
    
    /// Available entries for "see also" cross-references (exclude self)
    private var availableSeeAlsoEntries: [IndexEntry] {
        guard let entries = project.indexEntries else { return [] }
        return entries.filter { (entry: IndexEntry) -> Bool in
            entry.id != existingEntry?.id  // Can't reference itself
        }.sorted { (a: IndexEntry, b: IndexEntry) -> Bool in a.keyword.localizedCaseInsensitiveCompare(b.keyword) == .orderedAscending }
    }
    
    /// Check if potentialDescendant is a descendant of ancestor (for circular reference prevention)
    private func isDescendant(_ potentialDescendant: IndexEntry, of ancestor: IndexEntry?) -> Bool {
        guard let ancestor = ancestor else { return false }
        if potentialDescendant.id == ancestor.id { return true }
        return isDescendant(potentialDescendant, of: ancestor.parentEntry)
    }
    
    /// Generate a display label for a parent entry in the picker
    private func parentEntryLabel(for entry: IndexEntry) -> String {
        let indent = String(repeating: "  ", count: entry.depth - 1)
        let maxIndicator = entry.depth == IndexEntry.maxDepth - 1 ? " (max)" : ""
        return "\(indent)\(entry.keyword)\(maxIndicator)"
    }
    
    // MARK: - Initialization
    
    init(
        project: Project,
        existingEntry: IndexEntry? = nil,
        prefilledKeyword: String? = nil,
        onSave: ((IndexEntry, Bool) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.project = project
        self.existingEntry = existingEntry
        self.prefilledKeyword = prefilledKeyword
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Initialize state values directly in init
        if let existing = existingEntry {
            _keyword = State(initialValue: existing.keyword)
            _selectedParent = State(initialValue: existing.parentEntry)
            if let seeID = existing.seeEntryID {
                _selectedSeeEntry = State(initialValue: project.indexEntries?.first { $0.id == seeID })
            }
            _selectedSeeAlsoEntries = State(initialValue: Set(existing.seeAlsoEntryIDs))
            
            #if DEBUG
            print("📑 IndexEditorSheet init: EDITING existing entry")
            print("   - entry.id: \(existing.id)")
            print("   - entry.keyword: '\(existing.keyword)'")
            print("   - entry.parentEntry: \(existing.parentEntry?.keyword ?? "nil")")
            #endif
        } else if let prefilled = prefilledKeyword, !prefilled.isEmpty {
            _keyword = State(initialValue: prefilled)
            #if DEBUG
            print("📑 IndexEditorSheet init: Pre-filled keyword from selection: '\(prefilled)'")
            #endif
        }
        
        #if DEBUG
        print("📑 IndexEditorSheet init: project.indexEntries count = \(project.indexEntries?.count ?? 0)")
        if let entries = project.indexEntries {
            for entry in entries {
                print("   - '\(entry.keyword)' (depth: \(entry.depth), canHaveChildren: \(entry.canHaveChildren))")
            }
        }
        #endif
    }
    
    // MARK: - Body
    
    /// Whether the keyword field should be locked (pre-filled from selection)
    private var isKeywordLocked: Bool {
        if let prefilled = prefilledKeyword, 
           !prefilled.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           existingEntry == nil {
            return true
        }
        return false
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Keyword section
                Section {
                    if isKeywordLocked {
                        // When pre-filled from context menu, show as read-only
                        HStack {
                            Text(keyword)
                                .font(.body)
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else {
                        TextField(
                            NSLocalizedString("indexEditor.keyword.placeholder", comment: "Index keyword"),
                            text: $keyword
                        )
                        .autocapitalization(.words)
                    }
                    
                    if termExists {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(NSLocalizedString("indexEditor.keyword.exists", comment: "This keyword already exists"))
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Keyword suggestions (autocomplete)
                    if !keywordSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("indexEditor.suggestions", comment: "Suggestions:"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(keywordSuggestions) { suggestion in
                                Button {
                                    keyword = suggestion.keyword
                                    selectedParent = suggestion.parentEntry
                                } label: {
                                    HStack {
                                        Text(suggestion.keyword)
                                            .foregroundColor(.primary)
                                        if suggestion.parentEntry != nil {
                                            Text("(\(NSLocalizedString("indexEditor.suggestion.subEntry", comment: "sub-entry")))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.left")
                                            .font(.caption)
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text(NSLocalizedString("indexEditor.keyword.header", comment: "Keyword"))
                } footer: {
                    Text(NSLocalizedString("indexEditor.keyword.footer", comment: "The word or phrase to add to the index"))
                }
                
                // Parent entry section (for hierarchical index)
                // Always show the section so users can see the hierarchy option
                Section {
                    Picker(
                        NSLocalizedString("indexEditor.parent.label", comment: "Parent Entry"),
                        selection: $selectedParent
                    ) {
                        Text(NSLocalizedString("indexEditor.parent.none", comment: "None (Top Level)"))
                            .tag(nil as IndexEntry?)
                        
                        ForEach(availableParents) { parent in
                            Text(parentEntryLabel(for: parent))
                                .tag(parent as IndexEntry?)
                        }
                    }
                    .onChange(of: selectedParent) { oldValue, newValue in
                        #if DEBUG
                        print("📑 Parent changed: \(oldValue?.keyword ?? "nil") → \(newValue?.keyword ?? "nil")")
                        #endif
                    }
                } header: {
                    Text(NSLocalizedString("indexEditor.parent.header", comment: "Hierarchy"))
                } footer: {
                    Text(NSLocalizedString("indexEditor.parent.footer", comment: "Place this entry under a parent for nested index entries (max 3 levels)"))
                }
                
                // Primary reference toggle (only for new entries with pre-filled keyword from selection)
                if existingEntry == nil && isKeywordLocked {
                    Section {
                        Toggle(
                            NSLocalizedString("indexEditor.primary.label", comment: "Primary Reference"),
                            isOn: $isPrimaryReference
                        )
                    } footer: {
                        Text(NSLocalizedString("indexEditor.primary.footer", comment: "Primary references are shown in bold in the generated index"))
                    }
                }
                
                // Cross-references section (for editing or advanced mode)
                if existingEntry != nil || !availableSeeAlsoEntries.isEmpty {
                    Section {
                        // "See" cross-reference (redirects to another term)
                        Picker(
                            NSLocalizedString("indexEditor.see.label", comment: "See"),
                            selection: $selectedSeeEntry
                        ) {
                            Text(NSLocalizedString("indexEditor.see.none", comment: "None"))
                                .tag(nil as IndexEntry?)
                            ForEach(availableSeeAlsoEntries) { entry in
                                Text(entry.keyword)
                                    .tag(Optional(entry))
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("indexEditor.see.header", comment: "See Reference"))
                    } footer: {
                        Text(NSLocalizedString("indexEditor.see.footer", comment: "Redirects reader to another term (e.g., 'Dogs, see Animals')"))
                    }
                    
                    // "See also" cross-references
                    if !availableSeeAlsoEntries.isEmpty {
                        Section {
                            ForEach(availableSeeAlsoEntries) { entry in
                                Button {
                                    toggleSeeAlsoEntry(entry)
                                } label: {
                                    HStack {
                                        Text(entry.keyword)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedSeeAlsoEntries.contains(entry.id) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                }
                            }
                        } header: {
                            Text(NSLocalizedString("indexEditor.seeAlso.header", comment: "See Also"))
                        } footer: {
                            Text(NSLocalizedString("indexEditor.seeAlso.footer", comment: "Related terms shown after page numbers"))
                        }
                    }
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
                    .disabled(isSaving || !canSave || termExists)
                }
            }
            .onAppear {
                #if DEBUG
                print("📑 IndexEditorSheet onAppear: keyword='\(keyword)', prefilledKeyword='\(prefilledKeyword ?? "nil")'")
                print("   availableParents count: \(availableParents.count)")
                print("   project.indexEntries count: \(project.indexEntries?.count ?? 0)")
                #endif
            }
            .alert(
                NSLocalizedString("indexEditor.error.save", comment: "Failed to save index entry"),
                isPresented: $showSaveError
            ) {
                Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
        }
    }
    
    // MARK: - Preview Section
    
    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // How it appears in the index
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("indexEditor.preview.indexAppearance", comment: "In index:"))
                    .foregroundColor(.secondary)
                
                if let parent = selectedParent {
                    // Show as sub-entry
                    HStack(alignment: .top, spacing: 4) {
                        Text(parent.keyword)
                            .font(.body)
                            .foregroundColor(.secondary)
                        Text("/")
                            .foregroundColor(.secondary)
                        Text(keyword.isEmpty ? NSLocalizedString("indexEditor.preview.keyword", comment: "keyword") : keyword)
                            .font(.body)
                            .fontWeight(isPrimaryReference ? .bold : .regular)
                            .foregroundColor(keyword.isEmpty ? .secondary : .primary)
                    }
                } else {
                    // Top-level entry
                    Text(keyword.isEmpty ? NSLocalizedString("indexEditor.preview.keyword", comment: "keyword") : keyword)
                        .font(.body)
                        .fontWeight(isPrimaryReference ? .bold : .regular)
                        .foregroundColor(keyword.isEmpty ? .secondary : .primary)
                }
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
    
    private func toggleSeeAlsoEntry(_ entry: IndexEntry) {
        if selectedSeeAlsoEntries.contains(entry.id) {
            selectedSeeAlsoEntries.remove(entry.id)
        } else {
            selectedSeeAlsoEntries.insert(entry.id)
        }
    }
    
    private func handleCancel() {
        onCancel?()
        dismissSheet()
    }

    private func dismissSheet() {
        dismiss()
        dismissPresentedSheetOnCatalyst()
    }
    
    private func saveEntry() {
        guard !isSaving else { return }

        #if DEBUG
        print("📑 saveEntry() called")
        print("   existingEntry: \(existingEntry?.keyword ?? "nil")")
        print("   keyword field: '\(keyword)'")
        #endif

        isSaving = true
        defer {
            // Keep true on successful dismiss path; reset on early return/error paths.
            if showSaveError {
                isSaving = false
            }
        }
        
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else {
            isSaving = false
            return
        }
        
        let entry: IndexEntry
        
        if let existing = existingEntry {
            // Update existing entry
            existing.keyword = trimmedKeyword
            existing.parentEntry = selectedParent
            existing.seeEntryID = selectedSeeEntry?.id
            // Update see also entry IDs
            existing.seeAlsoEntryIDs = Array(selectedSeeAlsoEntries)
            existing.modifiedAt = Date()
            entry = existing
            
            #if DEBUG
            print("📑 Updated index entry: \(entry.keyword)")
            print("   - parent: \(selectedParent?.keyword ?? "none")")
            print("   - see: \(selectedSeeEntry?.keyword ?? "none")")
            print("   - seeAlso count: \(selectedSeeAlsoEntries.count)")
            print("   - entry.id: \(entry.id)")
            #endif
        } else {
            // Create new entry
            #if DEBUG
            print("📑 Creating new entry with keyword: '\(trimmedKeyword)', selectedParent: \(selectedParent?.keyword ?? "nil")")
            #endif
            
            entry = IndexEntry(
                project: project,
                keyword: trimmedKeyword,
                parentEntry: selectedParent
            )
            
            // Insert into model context first
            modelContext.insert(entry)
            
            // For SwiftData + CloudKit: set relationships from BOTH sides
            entry.parentEntry = selectedParent
            if let parent = selectedParent {
                // Also add to parent's childEntries to ensure inverse relationship is established
                if parent.childEntries == nil {
                    parent.childEntries = []
                }
                parent.childEntries?.append(entry)
                #if DEBUG
                print("📑 Added entry to parent's childEntries. Parent now has \(parent.childEntries?.count ?? 0) children")
                #endif
            }
            
            // Set cross-references for new entry
            entry.seeEntryID = selectedSeeEntry?.id
            entry.seeAlsoEntryIDs = Array(selectedSeeAlsoEntries)
            
            // Add to project's index entries
            if project.indexEntries == nil {
                project.indexEntries = []
            }
            project.indexEntries?.append(entry)
            
            #if DEBUG
            print("📑 Created new index entry: \(entry.keyword) (parent: \(entry.parentEntry?.keyword ?? "none"), primary: \(isPrimaryReference))")
            #endif
        }
        
        // Save context
        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "index-editor-save")
            #if DEBUG
            print("✅ Index entry saved successfully")
            // Verify the relationship persisted
            print("📑 POST-SAVE verification:")
            print("   entry.parentEntry = \(entry.parentEntry?.keyword ?? "nil")")
            print("   entry.isTopLevel = \(entry.isTopLevel)")
            if let parent = entry.parentEntry {
                print("   parent.childEntries = \(parent.childEntries?.map { $0.keyword } ?? [])")
            }
            #endif
            
            dismissSheet()
            let callback = onSave
            let savedEntry = entry
            let savedIsPrimaryReference = isPrimaryReference
            DispatchQueue.main.async {
                callback?(savedEntry, savedIsPrimaryReference)
            }
        } catch {
            #if DEBUG
            print("❌ Error saving index entry: \(error)")
            print("   Error details: \(error.localizedDescription)")
            #endif
            saveErrorMessage = error.localizedDescription
            showSaveError = true
            isSaving = false
            // Don't dismiss - let user see the error and try again
        }
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
