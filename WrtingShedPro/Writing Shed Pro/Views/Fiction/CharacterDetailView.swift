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
    
    @Bindable var character: FictionCharacter
    
    // MARK: - State
    
    @State private var isEditing = false
    @State private var editName: String = ""
    @State private var editRole: String = ""
    @State private var editArchetype: CharacterArchetype?
    @State private var editBiography: String = ""
    @State private var showDeleteConfirmation = false
    
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
            
            if let role = character.role, !role.isEmpty {
                LabeledContent(NSLocalizedString("fiction.character.role", comment: "Role")) {
                    Text(role)
                }
            }
        } header: {
            Text(NSLocalizedString("fiction.character.section.basic", comment: "Basic Info"))
        }
        
        // Archetype
        if let archetype = character.archetype {
            Section {
                LabeledContent(NSLocalizedString("fiction.character.archetype", comment: "Archetype")) {
                    Text(NSLocalizedString("archetype.\(archetype.rawValue)", comment: "Archetype"))
                }
                
                Text(NSLocalizedString("archetype.\(archetype.rawValue).description", comment: "Description"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text(NSLocalizedString("fiction.character.section.archetype", comment: "Archetype"))
            }
        }
        
        // Biography
        if let biography = character.biography, !biography.isEmpty {
            Section {
                Text(biography)
            } header: {
                Text(NSLocalizedString("fiction.character.biography", comment: "Biography"))
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
            TextField(NSLocalizedString("fiction.character.role", comment: "Role"), text: $editRole)
        } header: {
            Text(NSLocalizedString("fiction.character.section.basic", comment: "Basic Info"))
        }
        
        // Archetype
        Section {
            Picker(NSLocalizedString("fiction.character.archetype", comment: "Archetype"), selection: $editArchetype) {
                Text(NSLocalizedString("fiction.character.archetype.none", comment: "None"))
                    .tag(nil as CharacterArchetype?)
                
                ForEach(CharacterArchetype.allCases, id: \.self) { archetype in
                    Text(NSLocalizedString("archetype.\(archetype.rawValue)", comment: "Archetype"))
                        .tag(archetype as CharacterArchetype?)
                }
            }
            
            if let archetype = editArchetype {
                Text(NSLocalizedString("archetype.\(archetype.rawValue).description", comment: "Description"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text(NSLocalizedString("fiction.character.section.archetype", comment: "Archetype"))
        }
        
        // Biography
        Section {
            TextEditor(text: $editBiography)
                .frame(minHeight: 100)
        } header: {
            Text(NSLocalizedString("fiction.character.biography", comment: "Biography"))
        }
    }
    
    // MARK: - Actions
    
    private func startEditing() {
        editName = character.name ?? ""
        editRole = character.role ?? ""
        editArchetype = character.archetype
        editBiography = character.biography ?? ""
        isEditing = true
    }
    
    private func saveChanges() {
        character.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        character.role = editRole.isEmpty ? nil : editRole
        character.archetype = editArchetype
        character.biography = editBiography.isEmpty ? nil : editBiography
        
        try? modelContext.save()
        isEditing = false
    }
    
    private func deleteCharacter() {
        modelContext.delete(character)
        try? modelContext.save()
        dismiss()
    }
}
