//
//  ReferenceCreatorSheet.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System
//  Sheet for creating and editing references
//

import SwiftUI
import SwiftData

/// Sheet view for creating or editing a reference
struct ReferenceCreatorSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    /// The project this reference belongs to
    let project: Project
    
    /// Existing reference to edit (nil for new reference)
    let existingReference: ReferenceEntry?
    
    /// Callback when reference is saved, returns the entry for marker insertion
    var onSave: ((ReferenceEntry) -> Void)?
    
    /// Callback when cancelled
    var onCancel: (() -> Void)?
    
    // MARK: - State
    
    @State private var author: String = ""
    @State private var publicationDate: String = ""
    @State private var details: String = ""
    @State private var selectedExistingReferenceID: UUID?
    @State private var showingReferenceExistingList: Bool = false
    @State private var showDiscardConfirmation = false
    @State private var showDuplicateWarning = false
    
    // MARK: - Computed Properties
    
    private var isEditing: Bool {
        existingReference != nil
    }
    
    private var hasChanges: Bool {
        if let existing = existingReference {
            return author != existing.author ||
                   publicationDate != existing.publicationDate ||
                   details != existing.details
        }
        return !author.isEmpty || !publicationDate.isEmpty || !details.isEmpty
    }
    
    private var canSave: Bool {
        if isReferencingExisting {
            return selectedExistingReferenceID != nil
        }
        
        return !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !publicationDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var existingReferences: [ReferenceEntry] {
        let projectId = project.id
        let projectName = project.name
        if let fetchedReferences = try? ModelContext(modelContext.container).fetch(FetchDescriptor<ReferenceEntry>()) {
            let projectReferences = fetchedReferences.filter { $0.project?.id == projectId || $0.project?.name == projectName }
            if !projectReferences.isEmpty {
                return sortedReferences(projectReferences)
            }
        }

        return sortedReferences(project.referenceEntries ?? [])
    }
    
    private var isReferencingExisting: Bool {
        showingReferenceExistingList && !existingReferences.isEmpty
    }
    
    /// Check if a reference with the same author and date already exists
    private var duplicateReference: ReferenceEntry? {
        guard !isEditing else { return nil }
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedDate = publicationDate.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedAuthor.isEmpty && !trimmedDate.isEmpty else { return nil }
        
        return existingReferences.first { entry in
            entry.author.lowercased() == trimmedAuthor &&
            entry.publicationDate.lowercased() == trimmedDate
        }
    }
    
    private var navigationTitle: String {
        isEditing
            ? NSLocalizedString("referenceCreator.editReference.title", comment: "Edit Reference")
            : NSLocalizedString("referenceCreator.newReference.title", comment: "New Reference")
    }
    
    // MARK: - Initialization
    
    init(
        project: Project,
        existingReference: ReferenceEntry? = nil,
        onSave: ((ReferenceEntry) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.project = project
        self.existingReference = existingReference
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Initialize state from existing reference
        if let existing = existingReference {
            _author = State(initialValue: existing.author)
            _publicationDate = State(initialValue: existing.publicationDate)
            _details = State(initialValue: existing.details)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                if !isEditing {
                    if !existingReferences.isEmpty {
                        Section {
                            referenceExistingToggle
                        }
                        if isReferencingExisting {
                            Section {
                                referenceExistingForm
                            } header: {
                                Text("Select a reference to reuse")
                                    .font(.subheadline)
                            }
                        }
                    }
                    if !isReferencingExisting {
                        createNewReferenceForm
                    }
                } else {
                    createNewReferenceForm
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        if hasChanges {
                            showDiscardConfirmation = true
                        } else {
                            onCancel?()
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.save", comment: "Save")) {
                        // Check for duplicates when creating new reference
                        if !isEditing && !isReferencingExisting && duplicateReference != nil {
                            showDuplicateWarning = true
                        } else {
                            saveReference()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .alert(
                NSLocalizedString("referenceCreator.duplicate.title", comment: "Duplicate Reference"),
                isPresented: $showDuplicateWarning
            ) {
                Button(NSLocalizedString("referenceCreator.duplicate.continue", comment: "Create Anyway")) {
                    saveReference()
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {}
            } message: {
                if let duplicate = duplicateReference {
                    Text(String(format: NSLocalizedString("referenceCreator.duplicate.message", comment: "A reference by '%@' (%@) already exists."), duplicate.author, duplicate.publicationDate))
                }
            }
            .confirmationDialog(
                NSLocalizedString("referenceCreator.discard.title", comment: "Discard Changes?"),
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("referenceCreator.discard.button", comment: "Discard"), role: .destructive) {
                    onCancel?()
                    dismiss()
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("referenceCreator.discard.message", comment: "Your changes will be lost."))
            }
        }
    }
    
    private var referenceExistingToggle: some View {
        Button(action: {
            showingReferenceExistingList.toggle()
            if !showingReferenceExistingList {
                selectedExistingReferenceID = nil
            }
        }) {
            HStack {
                Text(showingReferenceExistingList ? "Hide Existing References" : "Use Existing Reference")
                Spacer()
                Image(systemName: showingReferenceExistingList ? "chevron.up" : "chevron.down")
            }
            .font(.headline)
        }
        .buttonStyle(.bordered)
        .tint(.gray)
    }
    
    // MARK: - Create New Form

    private func sortedReferences(_ references: [ReferenceEntry]) -> [ReferenceEntry] {
        references.sorted {
            ($0.author.localizedLowercase, $0.publicationDate.localizedLowercase, $0.id.uuidString) <
            ($1.author.localizedLowercase, $1.publicationDate.localizedLowercase, $1.id.uuidString)
        }
    }
    
    @ViewBuilder
    private var createNewReferenceForm: some View {
        // Author section
        Section {
            TextField(
                NSLocalizedString("referenceCreator.author.placeholder", comment: "Author or Organisation"),
                text: $author
            )
            .autocapitalization(.words)
        } header: {
            Text(NSLocalizedString("referenceCreator.author.header", comment: "Author"))
        } footer: {
            Text(NSLocalizedString("referenceCreator.author.footer", comment: "Author name or organisation"))
        }
        
        // Publication date section
        Section {
            TextField(
                NSLocalizedString("referenceCreator.date.placeholder", comment: "Year or date"),
                text: $publicationDate
            )
            .keyboardType(.numbersAndPunctuation)
        } header: {
            Text(NSLocalizedString("referenceCreator.date.header", comment: "Publication Date"))
        } footer: {
            Text(NSLocalizedString("referenceCreator.date.footer", comment: "Year or full publication date"))
        }
        
        // Details section (optional)
        Section {
            TextEditor(text: $details)
                .font(.body)
        } header: {
            Text(NSLocalizedString("referenceCreator.details.header", comment: "Further Details"))
        } footer: {
            Text(NSLocalizedString("referenceCreator.details.footer", comment: "Journal, publisher, URL, etc."))
        }
        
        // Info section (for existing references)
        if let existing = existingReference {
            Section {
                infoSection(for: existing)
            } header: {
                Text(NSLocalizedString("referenceCreator.info.header", comment: "Information"))
            }
        }
    }
    
    // MARK: - Reference Existing Form
    
    private var referenceExistingForm: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(existingReferences) { reference in
                        referenceExistingRow(for: reference)
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
    
    @ViewBuilder
    private func referenceExistingRow(for reference: ReferenceEntry) -> some View {
        let isSelected: Bool = selectedExistingReferenceID == reference.id
        let authorLine: String = "\(reference.author), \(reference.publicationDate)"
        let bgColor: Color = isSelected ? Color.blue.opacity(0.1) : Color.clear
        let isLast: Bool = reference.id == existingReferences.last?.id
        let refCountText: String = "\(reference.referenceCount)"
        
        Button(action: {
            if isSelected {
                selectedExistingReferenceID = nil
            } else {
                selectedExistingReferenceID = reference.id
            }
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(authorLine)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !reference.details.isEmpty {
                        Text(reference.details)
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    Text(refCountText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(bgColor)
            .cornerRadius(8)
        }
        
        if !isLast {
            Divider()
                .padding(.horizontal)
        }
    }
    
    // MARK: - Info Section
    
    @ViewBuilder
    private func infoSection(for reference: ReferenceEntry) -> some View {
        LabeledContent(NSLocalizedString("referenceCreator.info.references", comment: "References")) {
            Text("\(reference.referenceCount)")
                .foregroundColor(reference.referenceCount == 0 ? .orange : .primary)
        }
        
        LabeledContent(NSLocalizedString("referenceCreator.info.created", comment: "Created")) {
            Text(reference.createdAt, format: .dateTime.day().month().year())
        }
        
        LabeledContent(NSLocalizedString("referenceCreator.info.modified", comment: "Modified")) {
            Text(reference.modifiedAt, format: .dateTime.day().month().year())
        }
    }
    
    // MARK: - Actions
    
    private func saveReference() {
        if isReferencingExisting,
           let selectedID = selectedExistingReferenceID,
           let selectedReference = existingReferences.first(where: { $0.id == selectedID }) {
            // Reference existing
            onSave?(selectedReference)
            dismiss()
        } else {
            // Create new or update existing
            let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDate = publicationDate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedAuthor.isEmpty && !trimmedDate.isEmpty else { return }
            
            let reference: ReferenceEntry
            
            if let existing = existingReference {
                // Update existing
                existing.author = trimmedAuthor
                existing.publicationDate = trimmedDate
                existing.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
                existing.modifiedAt = Date()
                reference = existing
                
                #if DEBUG
                print("📚 Updated reference: \(reference.author), \(reference.publicationDate)")
                #endif
            } else {
                // Create new
                reference = ReferenceEntry(
                    project: project,
                    author: trimmedAuthor,
                    publicationDate: trimmedDate,
                    details: details.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                // Add to project's references
                if project.referenceEntries == nil {
                    project.referenceEntries = []
                }
                project.referenceEntries?.append(reference)
                
                #if DEBUG
                print("📚 Created new reference: \(reference.author), \(reference.publicationDate)")
                #endif
            }
            
            // Save context
            do {
                try WriteCoalescer.shared.requestSaveAndFlush(reason: "reference-creator-save")
            } catch {
                #if DEBUG
                print("❌ Error saving reference: \(error)")
                #endif
            }
            
            onSave?(reference)
            dismiss()
        }
    }
}

// MARK: - Localization Keys

/*
 Add these to Localizable.strings:
 
 "referenceCreator.editReference.title" = "Edit Reference";
 "referenceCreator.newReference.title" = "New Reference";
 "referenceCreator.author.placeholder" = "Author or Organisation";
 "referenceCreator.author.header" = "Author";
 "referenceCreator.author.footer" = "Author name or organisation";
 "referenceCreator.date.placeholder" = "Year or date";
 "referenceCreator.date.header" = "Publication Date";
 "referenceCreator.date.footer" = "Year or full publication date";
 "referenceCreator.details.header" = "Further Details";
 "referenceCreator.details.footer" = "Journal, publisher, URL, etc.";
 "referenceCreator.info.header" = "Information";
 "referenceCreator.info.references" = "References";
 "referenceCreator.info.created" = "Created";
 "referenceCreator.info.modified" = "Modified";
 "referenceCreator.discard.title" = "Discard Changes?";
 "referenceCreator.discard.button" = "Discard";
 "referenceCreator.discard.message" = "Your changes will be lost.";
 */
