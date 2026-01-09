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
    
    @Bindable var scene: StoryScene
    let project: Project
    
    // MARK: - State
    
    @State private var isEditing = false
    @State private var editTitle: String = ""
    @State private var editSummary: String = ""
    @State private var editMonomythStage: MonomythStage?
    @State private var editLocation: Location?
    @State private var editCharacters: Set<Character> = []
    @State private var editPlotElements: Set<PlotElement> = []
    @State private var showDeleteConfirmation = false
    
    // MARK: - Computed
    
    private var availableLocations: [Location] {
        (project.locations ?? []).sorted { 
            ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
        }
    }
    
    private var availableCharacters: [Character] {
        (project.characters ?? []).sorted { 
            ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
        }
    }
    
    private var availablePlotElements: [PlotElement] {
        (project.plotElements ?? []).sorted {
            ($0.userOrder ?? 0) < ($1.userOrder ?? 0)
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
        
        // Plot Elements
        if let plotElements = scene.plotElements, !plotElements.isEmpty {
            Section {
                ForEach(plotElements.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }) { element in
                    NavigationLink {
                        PlotElementDetailView(plotElement: element, project: project)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                if let stage = element.monomythStage {
                                    Text("\(stage.order).")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(element.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                            }
                            if let stage = element.monomythStage {
                                Text(NSLocalizedString("monomyth.\(stage.rawValue)", comment: "Stage name"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text(NSLocalizedString("fiction.scene.section.plotElements", comment: "Plot Elements"))
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
                    // Navigate to file - use drama editor for drama projects
                    if project.type == .drama {
                        DramaSceneEditorView(file: textFile, project: project)
                    } else {
                        FileDetailView(file: textFile)
                    }
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
                    .tag(nil as Location?)
                
                ForEach(availableLocations) { location in
                    Text(location.name ?? "")
                        .tag(location as Location?)
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
        
        // Plot Elements (multi-select)
        if !availablePlotElements.isEmpty {
            Section {
                ForEach(availablePlotElements) { element in
                    Button {
                        togglePlotElement(element)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    if let stage = element.monomythStage {
                                        Text("\(stage.order).")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(element.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                                        .foregroundColor(.primary)
                                }
                                if let stage = element.monomythStage {
                                    Text(NSLocalizedString("monomyth.\(stage.rawValue)", comment: "Stage name"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if editPlotElements.contains(element) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text(NSLocalizedString("fiction.scene.section.plotElements", comment: "Plot Elements"))
            } footer: {
                Text(NSLocalizedString("fiction.scene.plotElements.footer", comment: "Plot beats this scene implements"))
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
        editPlotElements = Set(scene.plotElements ?? [])
        isEditing = true
    }
    
    private func toggleCharacter(_ character: Character) {
        if editCharacters.contains(character) {
            editCharacters.remove(character)
        } else {
            editCharacters.insert(character)
        }
    }
    
    private func togglePlotElement(_ element: PlotElement) {
        if editPlotElements.contains(element) {
            editPlotElements.remove(element)
        } else {
            editPlotElements.insert(element)
        }
    }
    
    private func saveChanges() {
        scene.name = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        scene.synopsis = editSummary.isEmpty ? nil : editSummary
        scene.monomythStage = editMonomythStage
        scene.location = editLocation
        scene.characters = Array(editCharacters)
        scene.plotElements = Array(editPlotElements)
        
        // Update inverse relationships for plot elements
        for element in availablePlotElements {
            var elementScenes = Set(element.linkedScenes ?? [])
            if editPlotElements.contains(element) {
                elementScenes.insert(scene)
            } else {
                elementScenes.remove(scene)
            }
            element.linkedScenes = Array(elementScenes)
        }
        
        try? modelContext.save()
        isEditing = false
    }
    
    private func deleteScene() {
        modelContext.delete(scene)
        try? modelContext.save()
        dismiss()
    }
}
