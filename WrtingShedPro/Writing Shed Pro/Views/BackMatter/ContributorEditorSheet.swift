//
//  ContributorEditorSheet.swift
//  Writing Shed Pro
//
//  Feature 029: Contributors Section
//  Sheet for adding or editing contributor entries
//

import SwiftUI
import SwiftData

/// Sheet for adding or editing a contributor entry
struct ContributorEditorSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    /// Existing contributor to edit (nil = create new)
    let existingContributor: ContributorEntry?
    /// Callback when save completes
    var onSave: (() -> Void)?
    
    // MARK: - State
    
    @State private var firstName: String = ""
    @State private var surname: String = ""
    @State private var biography: String = ""
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    
    // MARK: - Computed
    
    private var isEditing: Bool {
        existingContributor != nil
    }
    
    private var navigationTitle: String {
        isEditing
            ? NSLocalizedString("contributor.edit.title", comment: "Edit Contributor")
            : NSLocalizedString("contributor.add.title", comment: "Add Contributor")
    }
    
    private var isValid: Bool {
        !surname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Name Section
                Section {
                    TextField(
                        NSLocalizedString("contributor.firstName", comment: "First Name"),
                        text: $firstName
                    )
                    .textContentType(.givenName)
                    .autocapitalization(.words)
                    
                    TextField(
                        NSLocalizedString("contributor.surname", comment: "Surname"),
                        text: $surname
                    )
                    .textContentType(.familyName)
                    .autocapitalization(.words)
                } header: {
                    Text(NSLocalizedString("contributor.section.name", comment: "Name"))
                } footer: {
                    Text(NSLocalizedString("contributor.name.order.hint", comment: "Use the display order toggle in the contributors list to switch between \"Surname, Forename\" and \"Forename Surname\"."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Biography Section
                Section {
                    TextEditor(text: $biography)
                        .frame(minHeight: 150)
                } header: {
                    Text(NSLocalizedString("contributor.section.biography", comment: "Biography"))
                } footer: {
                    Text(NSLocalizedString("contributor.biography.hint", comment: "Write a brief biographical note about this contributor."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.save", comment: "Save")) {
                        saveContributor()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadExistingData()
            }
            .alert(
                NSLocalizedString("contributor.validation.title", comment: "Validation Error"),
                isPresented: $showValidationAlert
            ) {
                Button(NSLocalizedString("button.ok", comment: "OK")) { }
            } message: {
                Text(validationMessage)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadExistingData() {
        guard let contributor = existingContributor else { return }
        // Use legacy fields if available, otherwise parse from unified name
        if !contributor.firstName.isEmpty || !contributor.surname.isEmpty {
            firstName = contributor.firstName
            surname = contributor.surname
        } else if !contributor.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Parse unified name back into parts
            let trimmed = contributor.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let commaIndex = trimmed.firstIndex(of: ",") {
                // "Surname, Forename" format
                surname = String(trimmed[trimmed.startIndex..<commaIndex]).trimmingCharacters(in: .whitespaces)
                firstName = String(trimmed[trimmed.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)
            } else {
                // "Forename Surname" format — last word is surname
                let parts = trimmed.split(separator: " ")
                if parts.count > 1 {
                    surname = String(parts.last!)
                    firstName = parts.dropLast().joined(separator: " ")
                } else {
                    surname = trimmed
                }
            }
        }
        biography = contributor.biography
    }
    
    private func saveContributor() {
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSurname = surname.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBiography = biography.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate
        if trimmedSurname.isEmpty {
            validationMessage = NSLocalizedString(
                "contributor.validation.surnameRequired",
                comment: "Please enter a surname."
            )
            showValidationAlert = true
            return
        }
        
        if isEditing, let contributor = existingContributor {
            // Update existing
            contributor.firstName = trimmedFirstName
            contributor.surname = trimmedSurname
            contributor.name = "" // Clear unified name; use structured fields
            contributor.biography = trimmedBiography
            contributor.modifiedAt = Date()
        } else {
            // Create new
            let newContributor = ContributorEntry(
                project: project,
                firstName: trimmedFirstName,
                surname: trimmedSurname,
                biography: trimmedBiography
            )
            modelContext.insert(newContributor)
            
            // Add to project's contributors
            if project.contributorEntries == nil {
                project.contributorEntries = []
            }
            project.contributorEntries?.append(newContributor)
        }
        
        // Save context
        do {
            try modelContext.save()
            onSave?()
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
            showValidationAlert = true
        }
    }
}
