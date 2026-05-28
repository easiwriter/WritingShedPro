//
//  CharacterDetailView.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Character detail/edit view
//

import SwiftUI
import SwiftData

/// Detail view for viewing and editing a character
struct CharacterDetailView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    @Bindable var character: Character
    
    // MARK: - State
    
    @State private var isEditing = false
    @State private var editName: String = ""
    @State private var editRole: String = ""
    @State private var selectedThreeActRole: ThreeActCharacterRole?
    @State private var editArchetypes: Set<CharacterArchetype> = []
    @State private var editDetails: String = ""
    @State private var showDeleteConfirmation = false

    private var usesThreeActRoleSet: Bool {
        character.project?.storyStructure == .threeAct
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                if isEditing {
                    editingContent
                } else {
                    viewingContent
                }
            }
            .navigationTitle(character.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditing {
                        Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                            isEditing = false
                        }
                    } else {
                        Button(NSLocalizedString("button.done", comment: "Done")) {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if isEditing {
                        Button(NSLocalizedString("button.save", comment: "Save")) {
                            saveChanges()
                        }
                        .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Button(NSLocalizedString("button.edit", comment: "Edit")) {
                            startEditing()
                        }
                    }
                }
            }
            .alert(
                NSLocalizedString("fiction.characters.deleteConfirm.title", comment: "Delete?"),
                isPresented: $showDeleteConfirmation
            ) {
                Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                    deleteCharacter()
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
            } message: {
                Text(String(format: NSLocalizedString("fiction.characters.deleteConfirm.message", comment: "Delete message"), character.name ?? ""))
            }
        }
    }
    
    // MARK: - Viewing Content
    
    @ViewBuilder
    private var viewingContent: some View {
        // Basic Info
        Section {
            LabeledContent(NSLocalizedString("fiction.character.name", comment: "Name")) {
                Text(character.name ?? "-")
            }
            
            if let role = character.roleDisplayName {
                LabeledContent(NSLocalizedString("fiction.character.role", comment: "Role")) {
                    Text(role)
                }
            }
        } header: {
            Text(NSLocalizedString("fiction.character.section.basic", comment: "Basic Info"))
        }
        
        // Archetypes (Vogler)
        if !character.archetypes.isEmpty {
            Section {
                ForEach(character.archetypes, id: \.self) { archetype in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(archetype.localizedName)
                            .font(.body)
                        Text(archetype.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(NSLocalizedString("fiction.character.section.archetype", comment: "Archetype"))
            }
        }
        
        // Character Details
        let detailsText = consolidatedCharacterDetails()
        if !detailsText.isEmpty {
            Section {
                Text(detailsText)
            } header: {
                Text(NSLocalizedString("fiction.character.section.details", comment: "Character Details"))
            }
        }
        
        // Custom Attributes
        if let attributes = character.customAttributes, !attributes.isEmpty {
            Section {
                ForEach(attributes) { attribute in
                    LabeledContent(attribute.key ?? "") {
                        Text(attribute.value ?? "")
                    }
                }
            } header: {
                Text(NSLocalizedString("fiction.character.attributes", comment: "Custom Attributes"))
            }
        }
        
        // Scenes featuring this character
        if let scenes = character.scenes, !scenes.isEmpty {
            Section {
                ForEach(scenes.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }) { scene in
                    Text(scene.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                }
            } header: {
                Text(NSLocalizedString("fiction.character.scenes", comment: "Appears In"))
            }
        }
        
        // Delete button
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text(NSLocalizedString("fiction.character.delete", comment: "Delete Character"))
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Editing Content
    
    @ViewBuilder
    private var editingContent: some View {
        // Basic Info
        Section {
            TextField(NSLocalizedString("fiction.character.name", comment: "Name"), text: $editName)
            if usesThreeActRoleSet {
                Picker(NSLocalizedString("fiction.character.role", comment: "Role"), selection: $selectedThreeActRole) {
                    Text(NSLocalizedString("fiction.characters.unassigned", comment: "Unassigned"))
                        .tag(nil as ThreeActCharacterRole?)
                    ForEach(ThreeActCharacterRole.allCases, id: \.self) { roleOption in
                        Text(roleOption.localizedName)
                            .tag(Optional(roleOption))
                    }
                }
            } else {
                TextField(NSLocalizedString("fiction.character.role", comment: "Role"), text: $editRole)
            }
        } header: {
            Text(NSLocalizedString("fiction.character.section.basic", comment: "Basic Info"))
        }
        
        // Archetypes
        Section {
            ForEach(CharacterArchetype.allCases, id: \.self) { archetype in
                Button {
                    if editArchetypes.contains(archetype) {
                        editArchetypes.remove(archetype)
                    } else {
                        editArchetypes.insert(archetype)
                    }
                } label: {
                    HStack {
                        Text(archetype.localizedName)
                            .foregroundColor(.primary)
                        Spacer()
                        if editArchetypes.contains(archetype) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            
            if !editArchetypes.isEmpty {
                let sorted = editArchetypes.sorted { $0.rawValue < $1.rawValue }
                Text(sorted.map { $0.localizedName }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text(NSLocalizedString("fiction.character.section.archetype", comment: "Archetype"))
        }
        
        // Character Details
        Section {
            TextEditor(text: $editDetails)
                .frame(minHeight: 120)
        } header: {
            Text(NSLocalizedString("fiction.character.section.details", comment: "Character Details"))
        }
    }
    
    // MARK: - Actions
    
    private func startEditing() {
        editName = character.name ?? ""
        editRole = character.roleDisplayName ?? ""
        selectedThreeActRole = character.threeActRole
        editArchetypes = Set(character.archetypes)
        editDetails = consolidatedCharacterDetails()
        isEditing = true
    }
    
    private func saveChanges() {
        character.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        if usesThreeActRoleSet {
            character.threeActRole = selectedThreeActRole
        } else {
            let trimmed = editRole.trimmingCharacters(in: .whitespacesAndNewlines)
            character.role = trimmed.isEmpty ? nil : trimmed
        }
        character.archetypes = Array(editArchetypes)
        character.pearsonArchetypeRaw = nil
        character.history = editDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editDetails
        character.looks = nil
        character.traits = nil
        character.work = nil
        
        try? modelContext.save()
        isEditing = false
    }
    
    private func deleteCharacter() {
        modelContext.delete(character)
        try? modelContext.save()
        dismiss()
    }

    private func consolidatedCharacterDetails() -> String {
        let parts = [character.history, character.looks, character.traits, character.work]
            .compactMap { value -> String? in
                guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                    return nil
                }
                return trimmed
            }
        return parts.joined(separator: "\n\n")
    }
}
