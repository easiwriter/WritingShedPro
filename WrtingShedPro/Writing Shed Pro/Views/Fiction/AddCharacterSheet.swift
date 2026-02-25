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
    @State private var selectedPearsonArchetype: PearsonArchetype?
    @State private var history: String = ""
    @State private var looks: String = ""
    @State private var traits: String = ""
    @State private var work: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // MARK: - Computed
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
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
                    if project.storyStructure.usesPearsonArchetypes {
                        // Pearson's 12 archetypes grouped by phase
                        Picker(NSLocalizedString("fiction.character.archetype", comment: "Archetype"), selection: $selectedPearsonArchetype) {
                            Text(NSLocalizedString("fiction.character.archetype.none", comment: "None"))
                                .tag(nil as PearsonArchetype?)
                            
                            ForEach(PearsonStage.allCases, id: \.self) { phase in
                                Section(header: Text(phase.localizedName)) {
                                    ForEach(phase.archetypes, id: \.self) { archetype in
                                        Text(archetype.localizedName)
                                            .tag(archetype as PearsonArchetype?)
                                    }
                                }
                            }
                        }
                        
                        if let archetype = selectedPearsonArchetype {
                            Text(archetype.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(String(format: NSLocalizedString("fiction.character.pearsonPhase", comment: "Phase: %@"), archetype.phase.localizedName))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Vogler's 8 archetypes (default)
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
                    }
                } header: {
                    Text(NSLocalizedString("fiction.character.section.archetype", comment: "Archetype"))
                } footer: {
                    Text(NSLocalizedString("fiction.character.archetype.footer", comment: "Archetypes help structure your story"))
                }
                
                // Character Details
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("fiction.character.history", comment: "History"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $history)
                            .frame(minHeight: 60)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("fiction.character.looks", comment: "Looks"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $looks)
                            .frame(minHeight: 60)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("fiction.character.traits", comment: "Traits"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $traits)
                            .frame(minHeight: 60)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("fiction.character.work", comment: "Work"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $work)
                            .frame(minHeight: 60)
                    }
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
            role: role.isEmpty ? nil : role,
            archetype: selectedArchetype,
            pearsonArchetype: selectedPearsonArchetype,
            history: history.isEmpty ? nil : history,
            looks: looks.isEmpty ? nil : looks,
            traits: traits.isEmpty ? nil : traits,
            work: work.isEmpty ? nil : work
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
