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
        // At least surname or first name must be provided
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
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
        firstName = contributor.firstName
        surname = contributor.surname
        biography = contributor.biography
    }
    
    private func saveContributor() {
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSurname = surname.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBiography = biography.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate
        if trimmedFirstName.isEmpty && trimmedSurname.isEmpty {
            validationMessage = NSLocalizedString(
                "contributor.validation.nameRequired",
                comment: "Please enter at least a first name or surname."
            )
            showValidationAlert = true
            return
        }
        
        if isEditing, let contributor = existingContributor {
            // Update existing
            contributor.update(
                firstName: trimmedFirstName,
                surname: trimmedSurname,
                biography: trimmedBiography
            )
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
