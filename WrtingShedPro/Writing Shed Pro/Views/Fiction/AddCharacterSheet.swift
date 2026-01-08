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
    @State private var selectedArchetype: CharacterArchetype?
    @State private var biography: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // MARK: - Computed
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section {
                    TextField(NSLocalizedString("fiction.character.name", comment: "Name"), text: $name)
                        .accessibilityLabel(NSLocalizedString("fiction.character.name.accessibility", comment: "Character name"))
                    
                    TextField(NSLocalizedString("fiction.character.role", comment: "Role"), text: $role)
                        .accessibilityLabel(NSLocalizedString("fiction.character.role.accessibility", comment: "Character role"))
                } header: {
                    Text(NSLocalizedString("fiction.character.section.basic", comment: "Basic Info"))
                }
                
                // Archetype (optional)
                Section {
                    Picker(NSLocalizedString("fiction.character.archetype", comment: "Archetype"), selection: $selectedArchetype) {
                        Text(NSLocalizedString("fiction.character.archetype.none", comment: "None"))
                            .tag(nil as CharacterArchetype?)
                        
                        ForEach(CharacterArchetype.allCases, id: \.self) { archetype in
                            Text(NSLocalizedString("archetype.\(archetype.rawValue)", comment: "Archetype name"))
                                .tag(archetype as CharacterArchetype?)
                        }
                    }
                    
                    if let archetype = selectedArchetype {
                        Text(NSLocalizedString("archetype.\(archetype.rawValue).description", comment: "Archetype description"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(NSLocalizedString("fiction.character.section.archetype", comment: "Archetype"))
                } footer: {
                    Text(NSLocalizedString("fiction.character.archetype.footer", comment: "Archetypes help structure your story"))
                }
                
                // Biography
                Section {
                    TextEditor(text: $biography)
                        .frame(minHeight: 100)
                        .accessibilityLabel(NSLocalizedString("fiction.character.biography.accessibility", comment: "Character biography"))
                } header: {
                    Text(NSLocalizedString("fiction.character.biography", comment: "Biography"))
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
            role: role.isEmpty ? nil : role,
            archetype: selectedArchetype,
            biography: biography.isEmpty ? nil : biography
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
}
