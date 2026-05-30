//
//  AddCharacterSheet.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Add character form
//

import SwiftUI
import SwiftData

/// Sheet for adding a new character to a fiction project
struct AddCharacterSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var name: String = ""
    @State private var role: String = ""
    @State private var selectedStructuredRoleRaw: String = ""
    @State private var details: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // MARK: - Computed
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var usesStructuredRoleSet: Bool {
        project.storyStructure != .freeform
    }

    private var structuredRoleOptions: [CharacterRoleOption] {
        project.storyStructure.characterRoleOptions
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Info
                Section {
                    TextField(NSLocalizedString("fiction.character.name", comment: "Name"), text: $name)
                        .accessibilityLabel(NSLocalizedString("fiction.character.name.accessibility", comment: "Character name"))

                    if usesStructuredRoleSet {
                        Picker(NSLocalizedString("fiction.character.role", comment: "Role"), selection: $selectedStructuredRoleRaw) {
                            Text(NSLocalizedString("fiction.characters.unassigned", comment: "Unassigned"))
                                .tag("")
                            ForEach(structuredRoleOptions) { roleOption in
                                Text(roleOption.localizedName)
                                    .tag(roleOption.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityLabel(NSLocalizedString("fiction.character.role.accessibility", comment: "Character role"))
                    } else {
                        TextField(NSLocalizedString("fiction.character.role", comment: "Role"), text: $role)
                            .accessibilityLabel(NSLocalizedString("fiction.character.role.accessibility", comment: "Character role"))
                    }
                } header: {
                    Text(NSLocalizedString("fiction.character.section.basic", comment: "Basic Info"))
                }
                
                // Character Details
                Section {
                    TextEditor(text: $details)
                        .frame(minHeight: 120)
                } header: {
                    Text(NSLocalizedString("fiction.character.section.details", comment: "Character Details"))
                }
            }
            .navigationTitle(NSLocalizedString("fiction.character.add.title", comment: "Add Character"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.add", comment: "Add")) {
                        addCharacter()
                    }
                    .disabled(!isValid)
                }
            }
            .alert(NSLocalizedString("error.title", comment: "Error"), isPresented: $showErrorAlert) {
                Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Actions
    
    private func addCharacter() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorMessage = NSLocalizedString("fiction.character.error.nameRequired", comment: "Name required")
            showErrorAlert = true
            return
        }
        
        let character = Character(
            name: trimmedName,
            role: resolvedRoleValue(),
            history: details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : details,
            looks: nil,
            traits: nil,
            work: nil
        )
        character.project = project
        
        modelContext.insert(character)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func resolvedRoleValue() -> String? {
        if usesStructuredRoleSet {
            let trimmed = selectedStructuredRoleRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        let trimmed = role.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
