//
//  CitationEditorSheet.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System
//  Created by GitHub Copilot on 15/01/2026.
//
//  Sheet for creating and editing citations/bibliography entries
//

import SwiftUI
import SwiftData

/// Citation style options
enum CitationStyle: String, CaseIterable {
    case authorYear = "Author-Year"
    case numbered = "Numbered"
    case footnoteStyle = "Footnote"
    
    var localizedTitle: String {
        switch self {
        case .authorYear:
            return NSLocalizedString("citationStyle.authorYear", comment: "Author-Year (Smith, 2024)")
        case .numbered:
            return NSLocalizedString("citationStyle.numbered", comment: "Numbered [1]")
        case .footnoteStyle:
            return NSLocalizedString("citationStyle.footnote", comment: "Footnote Style")
        }
    }
}

/// Sheet view for creating or editing a citation
struct CitationEditorSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    /// The project this citation belongs to
    let project: Project
    
    /// Existing citation to edit (nil for new citation)
    let existingCitation: CitationEntry?
    
    /// Callback when citation is saved, returns the entry for marker insertion
    var onSave: ((CitationEntry) -> Void)?
    
    /// Callback when cancelled
    var onCancel: (() -> Void)?
    
    // MARK: - State
    
    @State private var authorName: String = ""
    @State private var year: String = ""
    @State private var title: String = ""
    @State private var source: String = ""
    @State private var pages: String = ""
    @State private var url: String = ""
    @State private var accessDate: Date = Date()
    @State private var showAccessDate = false
    @State private var showDiscardConfirmation = false
    
    // MARK: - Computed Properties
    
    private var isEditing: Bool {
        existingCitation != nil
    }
    
    private var hasChanges: Bool {
        if let existing = existingCitation {
            let existingAuthor = existing.authors.first ?? ""
            let existingYear = existing.year.map { String($0) } ?? ""
            return authorName != existingAuthor ||
                   year != existingYear ||
                   title != existing.title ||
                   source != (existing.source ?? "") ||
                   pages != (existing.pages ?? "") ||
                   url != (existing.url ?? "")
        }
        return !authorName.isEmpty || !year.isEmpty || !title.isEmpty
    }
    
    private var canSave: Bool {
        !authorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !year.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var navigationTitle: String {
        isEditing
            ? NSLocalizedString("citationEditor.editCitation.title", comment: "Edit Citation")
            : NSLocalizedString("citationEditor.newCitation.title", comment: "New Citation")
    }
    
    /// Preview of the inline marker
    private var markerPreview: String {
        let author = authorName.isEmpty ? "Author" : authorName.components(separatedBy: " ").last ?? authorName
        let yearText = year.isEmpty ? "Year" : year
        return "[\(author), \(yearText)]"
    }
    
    /// Preview of the bibliography entry
    private var bibliographyPreview: String {
        var parts: [String] = []
        
        let authorText = authorName.isEmpty ? "Author" : authorName
        let yearText = year.isEmpty ? "Year" : year
        let titleText = title.isEmpty ? "Title" : title
        
        parts.append("\(authorText) (\(yearText)).")
        parts.append("\(titleText).")
        
        if !source.isEmpty {
            parts.append(source + ".")
        }
        
        if !pages.isEmpty {
            parts.append("pp. \(pages).")
        }
        
        if !url.isEmpty {
            parts.append("Retrieved from \(url)")
        }
        
        return parts.joined(separator: " ")
    }
    
    // MARK: - Initialization
    
    init(
        project: Project,
        existingCitation: CitationEntry? = nil,
        onSave: ((CitationEntry) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.project = project
        self.existingCitation = existingCitation
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Initialize state from existing citation
        if let existing = existingCitation {
            _authorName = State(initialValue: existing.authors.first ?? "")
            _year = State(initialValue: existing.year.map { String($0) } ?? "")
            _title = State(initialValue: existing.title)
            _source = State(initialValue: existing.source ?? "")
            _pages = State(initialValue: existing.pages ?? "")
            _url = State(initialValue: existing.url ?? "")
            if let date = existing.accessDate {
                _accessDate = State(initialValue: date)
                _showAccessDate = State(initialValue: true)
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Required fields section
                Section {
                    TextField(
                        NSLocalizedString("citationEditor.author.placeholder", comment: "Author name(s)"),
                        text: $authorName
                    )
                    .autocapitalization(.words)
                    
                    TextField(
                        NSLocalizedString("citationEditor.year.placeholder", comment: "Year"),
                        text: $year
                    )
                    .keyboardType(.numberPad)
                    
                    TextField(
                        NSLocalizedString("citationEditor.title.placeholder", comment: "Title"),
                        text: $title
                    )
                } header: {
                    Text(NSLocalizedString("citationEditor.required.header", comment: "Required"))
                } footer: {
                    Text(NSLocalizedString("citationEditor.required.footer", comment: "Author, year, and title are required"))
                }
                
                // Optional fields section
                Section {
                    TextField(
                        NSLocalizedString("citationEditor.source.placeholder", comment: "Journal, publisher, or website"),
                        text: $source
                    )
                    
                    TextField(
                        NSLocalizedString("citationEditor.pages.placeholder", comment: "Page numbers (e.g., 123-145)"),
                        text: $pages
                    )
                    .keyboardType(.numbersAndPunctuation)
                    
                    TextField(
                        NSLocalizedString("citationEditor.url.placeholder", comment: "URL"),
                        text: $url
                    )
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    
                    Toggle(NSLocalizedString("citationEditor.accessDate.toggle", comment: "Include access date"), isOn: $showAccessDate)
                    
                    if showAccessDate {
                        DatePicker(
                            NSLocalizedString("citationEditor.accessDate.label", comment: "Accessed"),
                            selection: $accessDate,
                            displayedComponents: .date
                        )
                    }
                } header: {
                    Text(NSLocalizedString("citationEditor.optional.header", comment: "Optional"))
                }
                
                // Preview section
                Section {
                    previewSection
                } header: {
                    Text(NSLocalizedString("citationEditor.preview.header", comment: "Preview"))
                }
                
                // Info section (for existing citations)
                if let existing = existingCitation {
                    Section {
                        infoSection(for: existing)
                    } header: {
                        Text(NSLocalizedString("citationEditor.info.header", comment: "Information"))
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
                        saveCitation()
                    }
                    .disabled(!canSave)
                }
            }
            .confirmationDialog(
                NSLocalizedString("citationEditor.discard.title", comment: "Discard Changes?"),
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("citationEditor.discard.button", comment: "Discard"), role: .destructive) {
                    onCancel?()
                    dismiss()
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("citationEditor.discard.message", comment: "Your changes will be lost."))
            }
        }
    }
    
    // MARK: - Preview Section
    
    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Inline marker preview
            HStack {
                Text(NSLocalizedString("citationEditor.preview.marker", comment: "In-text:"))
                    .foregroundColor(.secondary)
                
                Text(markerPreview)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.indigo)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.indigo.opacity(0.1))
                    .cornerRadius(3)
            }
            
            Divider()
            
            // Bibliography preview
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("citationEditor.preview.bibliography", comment: "Bibliography:"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(bibliographyPreview)
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Info Section
    
    @ViewBuilder
    private func infoSection(for citation: CitationEntry) -> some View {
        LabeledContent(NSLocalizedString("citationEditor.info.references", comment: "References")) {
            Text("\(citation.referenceCount)")
                .foregroundColor(citation.referenceCount == 0 ? .orange : .primary)
        }
        
        LabeledContent(NSLocalizedString("citationEditor.info.created", comment: "Created")) {
            Text(citation.createdAt, format: .dateTime.day().month().year())
        }
        
        LabeledContent(NSLocalizedString("citationEditor.info.modified", comment: "Modified")) {
            Text(citation.modifiedAt, format: .dateTime.day().month().year())
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
    
    private func saveCitation() {
        let trimmedAuthor = authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedYear = year.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedAuthor.isEmpty, !trimmedYear.isEmpty, !trimmedTitle.isEmpty else { return }
        
        let yearInt = Int(trimmedYear)
        
        let entry: CitationEntry
        
        if let existing = existingCitation {
            // Update existing citation
            existing.authors = [trimmedAuthor]
            existing.year = yearInt
            existing.title = trimmedTitle
            existing.source = source.isEmpty ? nil : source
            existing.pages = pages.isEmpty ? nil : pages
            existing.url = url.isEmpty ? nil : url
            existing.accessDate = showAccessDate ? accessDate : nil
            existing.modifiedAt = Date()
            entry = existing
            
            #if DEBUG
            print("📚 Updated citation: \(existing.primaryAuthorLastName) (\(existing.year ?? 0))")
            #endif
        } else {
            // Create new citation
            entry = CitationEntry(
                project: project,
                authors: [trimmedAuthor],
                year: yearInt,
                title: trimmedTitle,
                source: source.isEmpty ? nil : source,
                url: url.isEmpty ? nil : url
            )
            entry.pages = pages.isEmpty ? nil : pages
            entry.accessDate = showAccessDate ? accessDate : nil
            
            modelContext.insert(entry)
            
            #if DEBUG
            print("📚 Created new citation: \(entry.primaryAuthorLastName) (\(entry.year ?? 0))")
            #endif
        }
        
        // Save context
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("❌ Error saving citation: \(error)")
            #endif
        }
        
        onSave?(entry)
        dismiss()
    }
}

// MARK: - Localization Keys

/*
 Add these to Localizable.strings:
 
 "citationStyle.authorYear" = "Author-Year (Smith, 2024)";
 "citationStyle.numbered" = "Numbered [1]";
 "citationStyle.footnote" = "Footnote Style";
 "citationEditor.editCitation.title" = "Edit Citation";
 "citationEditor.newCitation.title" = "New Citation";
 "citationEditor.required.header" = "Required";
 "citationEditor.required.footer" = "Author, year, and title are required";
 "citationEditor.author.placeholder" = "Author name(s)";
 "citationEditor.year.placeholder" = "Year";
 "citationEditor.title.placeholder" = "Title";
 "citationEditor.optional.header" = "Optional";
 "citationEditor.source.placeholder" = "Journal, publisher, or website";
 "citationEditor.pages.placeholder" = "Page numbers (e.g., 123-145)";
 "citationEditor.url.placeholder" = "URL";
 "citationEditor.accessDate.toggle" = "Include access date";
 "citationEditor.accessDate.label" = "Accessed";
 "citationEditor.preview.header" = "Preview";
 "citationEditor.preview.marker" = "In-text:";
 "citationEditor.preview.bibliography" = "Bibliography:";
 "citationEditor.info.header" = "Information";
 "citationEditor.info.references" = "References";
 "citationEditor.info.created" = "Created";
 "citationEditor.info.modified" = "Modified";
 "citationEditor.discard.title" = "Discard Changes?";
 "citationEditor.discard.button" = "Discard";
 "citationEditor.discard.message" = "Your changes will be lost.";
 */
