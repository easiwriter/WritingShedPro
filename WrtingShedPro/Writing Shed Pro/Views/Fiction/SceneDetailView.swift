//
//  SceneDetailView.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Scene detail/edit view
//

import SwiftUI
import SwiftData

/// Detail view for viewing and editing a scene
struct SceneDetailView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    @Bindable var scene: FictionScene
    let project: Project
    
    // MARK: - State
    
    @State private var isEditing = false
    @State private var editTitle: String = ""
    @State private var editSummary: String = ""
    @State private var editMonomythStage: MonomythStage?
    @State private var editLocation: FictionLocation?
    @State private var editCharacters: Set<FictionCharacter> = []
    @State private var showDeleteConfirmation = false
    
    // MARK: - Computed
    
    private var availableLocations: [FictionLocation] {
        (project.locations ?? []).sorted { 
            ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
        }
    }
    
    private var availableCharacters: [FictionCharacter] {
        (project.characters ?? []).sorted { 
            ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
        }
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
            .navigationTitle(scene.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
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
                        .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Button(NSLocalizedString("button.edit", comment: "Edit")) {
                            startEditing()
                        }
                    }
                }
            }
            .alert(
                NSLocalizedString("fiction.scenes.deleteConfirm.title", comment: "Delete?"),
                isPresented: $showDeleteConfirmation
            ) {
                Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                    deleteScene()
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
            } message: {
                Text(String(format: NSLocalizedString("fiction.scenes.deleteConfirm.message", comment: "Delete message"), scene.name ?? ""))
            }
        }
    }
    
    // MARK: - Viewing Content
    
    @ViewBuilder
    private var viewingContent: some View {
        // Basic Info
        Section {
            LabeledContent(NSLocalizedString("fiction.scene.title", comment: "Title")) {
                Text(scene.name ?? "-")
            }
            
            if let userOrder = scene.userOrder {
                LabeledContent(NSLocalizedString("fiction.scene.number", comment: "Scene #")) {
                    Text("\(userOrder + 1)")
                }
            }
        } header: {
            Text(NSLocalizedString("fiction.scene.section.basic", comment: "Basic Info"))
        }
        
        // Summary
        if let synopsis = scene.synopsis, !synopsis.isEmpty {
            Section {
                Text(synopsis)
            } header: {
                Text(NSLocalizedString("fiction.scene.summary", comment: "Summary"))
            }
        }
        
        // Location
        if let location = scene.location {
            Section {
                LabeledContent(NSLocalizedString("fiction.scene.location", comment: "Location")) {
                    Text(location.name ?? "-")
                }
            } header: {
                Text(NSLocalizedString("fiction.scene.section.location", comment: "Location"))
            }
        }
        
        // Characters
        if let characters = scene.characters, !characters.isEmpty {
            Section {
                ForEach(characters.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }) { character in
                    HStack {
                        Text(character.name ?? "")
                        if let role = character.role {
                            Text("(\(role))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text(NSLocalizedString("fiction.scene.section.characters", comment: "Characters"))
            }
        }
        
        // Monomyth Stage
        if let stage = scene.monomythStage {
            Section {
                LabeledContent(NSLocalizedString("fiction.scene.monomythStage", comment: "Stage")) {
                    Text(NSLocalizedString("monomyth.\(stage.rawValue)", comment: "Stage name"))
                }
                
                Text(NSLocalizedString("monomyth.\(stage.rawValue).description", comment: "Description"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text(NSLocalizedString("fiction.scene.section.monomyth", comment: "Hero's Journey"))
            }
        }
        
        // Associated file
        if let textFile = scene.textFile {
            Section {
                NavigationLink {
                    // Navigate to file
                    FileDetailView(file: textFile)
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        Text(textFile.name)
                    }
                }
            } header: {
                Text(NSLocalizedString("fiction.scene.file", comment: "Scene File"))
            }
        }
        
        // Delete button
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text(NSLocalizedString("fiction.scene.delete", comment: "Delete Scene"))
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
            TextField(NSLocalizedString("fiction.scene.title", comment: "Title"), text: $editTitle)
        } header: {
            Text(NSLocalizedString("fiction.scene.section.basic", comment: "Basic Info"))
        }
        
        // Summary
        Section {
            TextEditor(text: $editSummary)
                .frame(minHeight: 80)
        } header: {
            Text(NSLocalizedString("fiction.scene.summary", comment: "Summary"))
        }
        
        // Location
        Section {
            Picker(NSLocalizedString("fiction.scene.location", comment: "Location"), selection: $editLocation) {
                Text(NSLocalizedString("fiction.scene.location.none", comment: "None"))
                    .tag(nil as FictionLocation?)
                
                ForEach(availableLocations) { location in
                    Text(location.name ?? "")
                        .tag(location as FictionLocation?)
                }
            }
        } header: {
            Text(NSLocalizedString("fiction.scene.section.location", comment: "Location"))
        }
        
        // Characters
        if !availableCharacters.isEmpty {
            Section {
                ForEach(availableCharacters) { character in
                    Button {
                        toggleCharacter(character)
                    } label: {
                        HStack {
                            Text(character.name ?? "")
                                .foregroundColor(.primary)
                            Spacer()
                            if editCharacters.contains(character) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text(NSLocalizedString("fiction.scene.section.characters", comment: "Characters"))
            }
        }
        
        // Monomyth Stage
        if project.useMonomyth {
            Section {
                Picker(NSLocalizedString("fiction.scene.monomythStage", comment: "Stage"), selection: $editMonomythStage) {
                    Text(NSLocalizedString("fiction.scene.monomythStage.none", comment: "None"))
                        .tag(nil as MonomythStage?)
                    
                    ForEach(MonomythStage.allCases, id: \.self) { stage in
                        Text(NSLocalizedString("monomyth.\(stage.rawValue)", comment: "Stage"))
                            .tag(stage as MonomythStage?)
                    }
                }
                
                if let stage = editMonomythStage {
                    Text(NSLocalizedString("monomyth.\(stage.rawValue).description", comment: "Description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(NSLocalizedString("fiction.scene.section.monomyth", comment: "Hero's Journey"))
            }
        }
    }
    
    // MARK: - Actions
    
    private func startEditing() {
        editTitle = scene.name ?? ""
        editSummary = scene.synopsis ?? ""
        editMonomythStage = scene.monomythStage
        editLocation = scene.location
        editCharacters = Set(scene.characters ?? [])
        isEditing = true
    }
    
    private func toggleCharacter(_ character: FictionCharacter) {
        if editCharacters.contains(character) {
            editCharacters.remove(character)
        } else {
            editCharacters.insert(character)
        }
    }
    
    private func saveChanges() {
        scene.name = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        scene.synopsis = editSummary.isEmpty ? nil : editSummary
        scene.monomythStage = editMonomythStage
        scene.location = editLocation
        scene.characters = Array(editCharacters)
        
        try? modelContext.save()
        isEditing = false
    }
    
    private func deleteScene() {
        modelContext.delete(scene)
        try? modelContext.save()
        dismiss()
    }
}
