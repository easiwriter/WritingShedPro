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
    @State private var selectedThreeActRole: ThreeActCharacterRole?
    @State private var selectedArchetypes: Set<CharacterArchetype> = []
    @State private var details: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // MARK: - Computed
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var usesThreeActRoleSet: Bool {
        project.storyStructure == .threeAct
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Info
                Section {
                    TextField(NSLocalizedString("fiction.character.name", comment: "Name"), text: $name)
                        .accessibilityLabel(NSLocalizedString("fiction.character.name.accessibility", comment: "Character name"))

                    if usesThreeActRoleSet {
                        Picker(NSLocalizedString("fiction.character.role", comment: "Role"), selection: $selectedThreeActRole) {
                            Text(NSLocalizedString("fiction.characters.unassigned", comment: "Unassigned"))
                                .tag(nil as ThreeActCharacterRole?)
                            ForEach(ThreeActCharacterRole.allCases, id: \.self) { roleOption in
                                Text(roleOption.localizedName)
                                    .tag(Optional(roleOption))
                            }
                        }
                        .accessibilityLabel(NSLocalizedString("fiction.character.role.accessibility", comment: "Character role"))
                    } else {
                        TextField(NSLocalizedString("fiction.character.role", comment: "Role"), text: $role)
                            .accessibilityLabel(NSLocalizedString("fiction.character.role.accessibility", comment: "Character role"))
                    }
                } header: {
                    Text(NSLocalizedString("fiction.character.section.basic", comment: "Basic Info"))
                }
                
                // Archetype (optional)
                Section {
                    ForEach(CharacterArchetype.allCases, id: \.self) { archetype in
                        Button {
                            if selectedArchetypes.contains(archetype) {
                                selectedArchetypes.remove(archetype)
                            } else {
                                selectedArchetypes.insert(archetype)
                            }
                        } label: {
                            HStack {
                                Text(archetype.localizedName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedArchetypes.contains(archetype) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                    
                    if !selectedArchetypes.isEmpty {
                        let sorted = selectedArchetypes.sorted { $0.rawValue < $1.rawValue }
                        Text(sorted.map { $0.localizedName }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(NSLocalizedString("fiction.character.section.archetype", comment: "Archetype"))
                } footer: {
                    Text(NSLocalizedString("fiction.character.archetype.footer", comment: "Archetypes help structure your story"))
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
            archetypes: Array(selectedArchetypes),
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
        if usesThreeActRoleSet {
            return selectedThreeActRole?.rawValue
        }
        let trimmed = role.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
