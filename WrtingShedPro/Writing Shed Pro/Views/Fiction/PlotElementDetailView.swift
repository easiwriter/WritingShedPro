//
//  PlotElementDetailView.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Plot element detail/edit view
//

import SwiftUI
import SwiftData

/// Detail view for viewing and editing a plot element
struct PlotElementDetailView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    @Bindable var plotElement: PlotElement
    let project: Project
    
    // MARK: - State
    
    @State private var isEditing = false
    @State private var editTitle: String = ""
    @State private var editDescription: String = ""
    @State private var editMonomythStage: MonomythStage?
    @State private var editThreeActStage: ThreeActStage?
    @State private var editCharacters: Set<Character> = []
    @State private var editLocations: Set<Location> = []
    @State private var editLinkedScenes: Set<StoryScene> = []
    @State private var showDeleteConfirmation = false
    @State private var showCreateSceneSheet = false
    
    // MARK: - Computed
    
    private var availableCharacters: [Character] {
        (project.characters ?? []).sorted { 
            ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
        }
    }
    
    private var availableLocations: [Location] {
        (project.locations ?? []).sorted { 
            ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
        }
    }
    
    private var linkedScenes: [StoryScene] {
        (plotElement.linkedScenes ?? []).sorted {
            ($0.userOrder ?? 0) < ($1.userOrder ?? 0)
        }
    }
    
    private var isVerseNovel: Bool {
        project.fictionClass == .verseNovel
    }
    
    private var availableScenes: [StoryScene] {
        // Scenes are attached to TextFiles in folders, not directly in project.scenes
        var scenes: [StoryScene] = []
        for folder in project.folders ?? [] {
            for textFile in folder.textFiles ?? [] {
                if let scene = textFile.scene {
                    scenes.append(scene)
                }
            }
        }
        return scenes.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
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
            .navigationTitle(plotElement.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
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
                NSLocalizedString("fiction.plot.deleteConfirm.title", comment: "Delete?"),
                isPresented: $showDeleteConfirmation
            ) {
                Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                    deletePlotElement()
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
            } message: {
                Text(String(format: NSLocalizedString("fiction.plot.deleteConfirm.message", comment: "Delete message"), plotElement.name ?? ""))
            }
            .sheet(isPresented: $showCreateSceneSheet) {
                CreateSceneForPlotElementSheet(project: project, plotElement: plotElement)
            }
        }
    }
    
    // MARK: - Viewing Content
    
    @ViewBuilder
    private var viewingContent: some View {
        // Basic Info
        Section {
            LabeledContent(NSLocalizedString("fiction.plot.element.title", comment: "Title")) {
                Text(plotElement.name ?? "-")
            }
        } header: {
            Text(NSLocalizedString("fiction.plot.element.section.basic", comment: "Basic Info"))
        }
        
        // Description
        if let notes = plotElement.notes, !notes.isEmpty {
            Section {
                Text(notes)
            } header: {
                Text(NSLocalizedString("fiction.plot.element.description", comment: "Description"))
            }
        }
        
        // Stage (based on story structure)
        if let stageOrder = plotElement.stageOrder, let stageName = plotElement.stageLocalizedName {
            Section {
                LabeledContent(NSLocalizedString("fiction.plot.element.stage", comment: "Stage")) {
                    Text("\(stageOrder). \(stageName)")
                }
            } header: {
                if project.storyStructure.usesMonomyth {
                    Text(NSLocalizedString("fiction.plot.element.section.monomyth", comment: "Hero's Journey"))
                } else {
                    Text(NSLocalizedString("fiction.plot.element.section.threeAct", comment: "Three-Act Structure"))
                }
            }
        }
        
        // Characters
        if let characters = plotElement.characters, !characters.isEmpty {
            Section {
                ForEach(characters.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }) { character in
                    Text(character.name ?? "")
                }
            } header: {
                Text(NSLocalizedString("fiction.plot.element.section.characters", comment: "Characters"))
            }
        }
        
        // Locations
        if let locations = plotElement.locations, !locations.isEmpty {
            Section {
                ForEach(locations.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }) { location in
                    Text(location.name ?? "")
                }
            } header: {
                Text(NSLocalizedString("fiction.plot.element.section.locations", comment: "Locations"))
            }
        }
        
        // Linked Scenes/Episodes
        Section {
            if !linkedScenes.isEmpty {
                ForEach(linkedScenes) { scene in
                    NavigationLink {
                        SceneDetailView(scene: scene, project: project)
                    } label: {
                        HStack {
                            Text(scene.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                            Spacer()
                            if let order = scene.userOrder {
                                Text("#\(order + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            Button {
                showCreateSceneSheet = true
            } label: {
                Label(isVerseNovel
                    ? NSLocalizedString("fiction.plot.element.createEpisode", comment: "Create Episode")
                    : NSLocalizedString("fiction.plot.element.createScene", comment: "Create Scene"), systemImage: "plus.circle")
            }
        } header: {
            Text(isVerseNovel
                ? NSLocalizedString("fiction.plot.element.section.linkedEpisodes", comment: "Linked Episodes")
                : NSLocalizedString("fiction.plot.element.section.scenes", comment: "Scenes"))
        } footer: {
            if linkedScenes.isEmpty {
                Text(isVerseNovel
                    ? NSLocalizedString("fiction.plot.element.episodes.empty", comment: "No episodes linked to this plot element")
                    : NSLocalizedString("fiction.plot.element.scenes.empty", comment: "No scenes linked to this plot element"))
            }
        }
        
        // Delete button
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text(NSLocalizedString("fiction.plot.element.delete", comment: "Delete Plot Element"))
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
            TextField(NSLocalizedString("fiction.plot.element.title", comment: "Title"), text: $editTitle)
        } header: {
            Text(NSLocalizedString("fiction.plot.element.section.basic", comment: "Basic Info"))
        }
        
        // Description
        Section {
            TextEditor(text: $editDescription)
                .frame(minHeight: 100)
        } header: {
            Text(NSLocalizedString("fiction.plot.element.description", comment: "Description"))
        }
        
        // Stage picker based on story structure
        if project.storyStructure.usesMonomyth {
            Section {
                Picker(NSLocalizedString("fiction.plot.element.stage", comment: "Stage"), selection: $editMonomythStage) {
                    Text(NSLocalizedString("fiction.plot.element.stage.none", comment: "None"))
                        .tag(nil as MonomythStage?)
                    
                    ForEach(MonomythStage.allCases, id: \.self) { stage in
                        HStack {
                            Text("\(stage.order).")
                            Text(stage.localizedName)
                        }
                        .tag(stage as MonomythStage?)
                    }
                }
                
                if let stage = editMonomythStage {
                    Text(stage.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(NSLocalizedString("fiction.plot.element.section.monomyth", comment: "Hero's Journey"))
            }
        } else if project.storyStructure == .threeAct {
            Section {
                Picker(NSLocalizedString("fiction.plot.element.stage", comment: "Stage"), selection: $editThreeActStage) {
                    Text(NSLocalizedString("fiction.plot.element.stage.none", comment: "None"))
                        .tag(nil as ThreeActStage?)
                    
                    ForEach(ThreeActStage.allCases, id: \.self) { stage in
                        HStack {
                            Text("\(stage.order).")
                            Text(stage.localizedName)
                        }
                        .tag(stage as ThreeActStage?)
                    }
                }
                
                if let stage = editThreeActStage {
                    Text(stage.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(NSLocalizedString("fiction.plot.element.section.threeAct", comment: "Three-Act Structure"))
            }
        }
        
        // Characters (multi-select)
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
                Text(NSLocalizedString("fiction.plot.element.section.characters", comment: "Characters"))
            } footer: {
                Text(NSLocalizedString("fiction.plot.element.characters.footer", comment: "Characters involved in this plot beat"))
            }
        }
        
        // Locations (multi-select)
        if !availableLocations.isEmpty {
            Section {
                ForEach(availableLocations) { location in
                    Button {
                        toggleLocation(location)
                    } label: {
                        HStack {
                            Text(location.name ?? "")
                                .foregroundColor(.primary)
                            Spacer()
                            if editLocations.contains(location) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text(NSLocalizedString("fiction.plot.element.section.locations", comment: "Locations"))
            } footer: {
                Text(NSLocalizedString("fiction.plot.element.locations.footer", comment: "Where this plot beat takes place"))
            }
        }
        
        // Linked Scenes/Episodes (multi-select)
        if !availableScenes.isEmpty {
            Section {
                ForEach(availableScenes) { scene in
                    Button {
                        toggleScene(scene)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(scene.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                                    .foregroundColor(.primary)
                                if let order = scene.userOrder {
                                    Text(String(format: NSLocalizedString(isVerseNovel ? "fiction.episode.orderLabel" : "fiction.scene.orderLabel", comment: "Scene/Episode #"), order + 1))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if editLinkedScenes.contains(scene) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text(NSLocalizedString(isVerseNovel ? "fiction.plot.element.section.linkedEpisodes" : "fiction.plot.element.section.linkedScenes", comment: "Linked Scenes/Episodes"))
            } footer: {
                Text(NSLocalizedString(isVerseNovel ? "fiction.plot.element.linkedEpisodes.footer" : "fiction.plot.element.linkedScenes.footer", comment: "Scenes/Episodes that implement this plot beat"))
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleCharacter(_ character: Character) {
        if editCharacters.contains(character) {
            editCharacters.remove(character)
        } else {
            editCharacters.insert(character)
        }
    }
    
    private func toggleLocation(_ location: Location) {
        if editLocations.contains(location) {
            editLocations.remove(location)
        } else {
            editLocations.insert(location)
        }
    }
    
    private func toggleScene(_ scene: StoryScene) {
        if editLinkedScenes.contains(scene) {
            editLinkedScenes.remove(scene)
        } else {
            editLinkedScenes.insert(scene)
        }
    }
    
    private func startEditing() {
        editTitle = plotElement.name ?? ""
        editDescription = plotElement.notes ?? ""
        editMonomythStage = plotElement.monomythStage
        editThreeActStage = plotElement.threeActStage
        editCharacters = Set(plotElement.characters ?? [])
        editLocations = Set(plotElement.locations ?? [])
        editLinkedScenes = Set(plotElement.linkedScenes ?? [])
        isEditing = true
    }
    
    private func saveChanges() {
        plotElement.name = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        plotElement.notes = editDescription.isEmpty ? nil : editDescription
        
        // Save stage based on story structure
        switch project.storyStructure {
        case .monomythVogler:
            plotElement.monomythStage = editMonomythStage
            plotElement.campbellStageRaw = nil
            plotElement.threeActStage = nil
            plotElement.pearsonStageRaw = nil
        case .threeAct:
            plotElement.threeActStage = editThreeActStage
            plotElement.monomythStage = nil
            plotElement.campbellStageRaw = nil
            plotElement.pearsonStageRaw = nil
        case .freeform:
            plotElement.monomythStage = nil
            plotElement.campbellStageRaw = nil
            plotElement.threeActStage = nil
            plotElement.pearsonStageRaw = nil
        }
        
        plotElement.characters = Array(editCharacters)
        plotElement.locations = Array(editLocations)
        plotElement.linkedScenes = Array(editLinkedScenes)
        
        // Update inverse relationships for scenes
        for scene in availableScenes {
            var scenePlotElements = Set(scene.plotElements ?? [])
            if editLinkedScenes.contains(scene) {
                scenePlotElements.insert(plotElement)
            } else {
                scenePlotElements.remove(plotElement)
            }
            scene.plotElements = Array(scenePlotElements)
        }
        
        try? modelContext.save()
        isEditing = false
    }
    
    private func deletePlotElement() {
        modelContext.delete(plotElement)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Create Scene for Plot Element Sheet

/// Sheet for creating a scene/episode linked to a specific plot element
struct CreateSceneForPlotElementSheet: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    let plotElement: PlotElement
    
    @State private var sceneName: String = ""
    @State private var summary: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    private var isVerseNovel: Bool {
        project.fictionClass == .verseNovel
    }
    
    private var isValid: Bool {
        !sceneName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var nextSceneOrderIndex: Int {
        let scenes = project.scenes ?? []
        return (scenes.map { $0.userOrder ?? 0 }.max() ?? -1) + 1
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(isVerseNovel
                        ? NSLocalizedString("fiction.episode.title", comment: "Title")
                        : NSLocalizedString("fiction.scene.title", comment: "Title"), text: $sceneName)
                } header: {
                    Text(isVerseNovel
                        ? NSLocalizedString("fiction.episode.section.basic", comment: "Basic Info")
                        : NSLocalizedString("fiction.scene.section.basic", comment: "Basic Info"))
                }
                
                Section {
                    TextEditor(text: $summary)
                        .frame(minHeight: 80)
                } header: {
                    Text(isVerseNovel
                        ? NSLocalizedString("fiction.episode.summary", comment: "Summary")
                        : NSLocalizedString("fiction.scene.summary", comment: "Summary"))
                }
                
                // Show what will be inherited from plot element
                Section {
                    LabeledContent(NSLocalizedString("fiction.plot.element.title", comment: "Plot Element")) {
                        Text(plotElement.name ?? "-")
                    }
                    
                    if let characters = plotElement.characters, !characters.isEmpty {
                        LabeledContent(NSLocalizedString("fiction.plot.element.section.characters", comment: "Characters")) {
                            Text(characters.compactMap { $0.name }.joined(separator: ", "))
                                .font(.caption)
                        }
                    }
                    
                    if let locations = plotElement.locations, !locations.isEmpty {
                        LabeledContent(NSLocalizedString("fiction.plot.element.section.locations", comment: "Locations")) {
                            Text(locations.compactMap { $0.name }.joined(separator: ", "))
                                .font(.caption)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("fiction.scene.inheritedFromPlot", comment: "From Plot Element"))
                } footer: {
                    Text(NSLocalizedString("fiction.scene.inheritedFromPlot.footer", comment: "Characters and location will be copied from the plot element"))
                }
            }
            .navigationTitle(isVerseNovel
                ? NSLocalizedString("fiction.plot.element.createEpisode", comment: "Create Episode")
                : NSLocalizedString("fiction.plot.element.createScene", comment: "Create Scene"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.create", comment: "Create")) {
                        createScene()
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
    
    private func createScene() {
        let trimmedName = sceneName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorMessage = isVerseNovel
                ? NSLocalizedString("fiction.episode.error.titleRequired", comment: "Title required")
                : NSLocalizedString("fiction.scene.error.titleRequired", comment: "Title required")
            showErrorAlert = true
            return
        }
        
        // Find appropriate folder (Episodes for verse novel, Scenes otherwise)
        let folderName = isVerseNovel ? "Episodes" : "Scenes"
        let scenesFolder = project.folders?.first { $0.name == folderName }
        
        let scene = StoryScene(
            name: trimmedName,
            synopsis: summary.isEmpty ? nil : summary,
            userOrder: nextSceneOrderIndex
        )
        scene.project = project
        
        // Also add to project.scenes to ensure relationship is synced
        if project.scenes == nil {
            project.scenes = []
        }
        project.scenes?.append(scene)
        
        scene.monomythStage = plotElement.monomythStage
        scene.threeActStage = plotElement.threeActStage
        scene.campbellStageRaw = nil
        scene.pearsonStageRaw = nil
        scene.characters = plotElement.characters
        scene.location = plotElement.locations?.first
        
        // Link scene to plot element without creating duplicate join links.
        // Setting both sides with append can duplicate ScenePlotElementLink rows.
        scene.plotElements = [plotElement]
        
        // Create TextFile for scene/episode content
        let textFile: TextFile
        if isVerseNovel {
            // Verse Novel episodes use poetry editor with free verse by default
            textFile = TextFile(
                name: trimmedName,
                initialContent: "",
                parentFolder: scenesFolder,
                poetryFormId: PoetryForm.freeVerseId,
                poetryFormName: "Free Verse"
            )
            textFile.contentType = .richText
        } else {
            textFile = TextFile(name: trimmedName, initialContent: "", parentFolder: scenesFolder)
        }
        textFile.workflowStatus = .draft  // New scenes/episodes start as drafts
        textFile.scene = scene
        scene.textFile = textFile
        
        modelContext.insert(scene)
        modelContext.insert(textFile)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
