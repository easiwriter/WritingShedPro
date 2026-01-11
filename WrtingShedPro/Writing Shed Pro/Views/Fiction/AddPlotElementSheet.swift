//
//  AddPlotElementSheet.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Add plot element form
//

import SwiftUI
import SwiftData

/// Sheet for adding a new plot element to a fiction project
struct AddPlotElementSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var title: String = ""
    @State private var plotDescription: String = ""
    @State private var selectedMonomythStage: MonomythStage = .ordinaryWorld
    @State private var selectedCampbellStage: CampbellMonomythStage = .theOrdinaryWorld
    @State private var selectedThreeActStage: ThreeActStage = .actOne
    @State private var selectedCharacters: Set<Character> = []
    @State private var selectedLocations: Set<Location> = []
    @State private var selectedScenes: Set<StoryScene> = []
    @State private var sceneName: String = ""  // Optional scene to auto-create
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // MARK: - Computed
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var nextOrderIndex: Int {
        let elements = project.plotElements ?? []
        return (elements.map { $0.userOrder ?? 0 }.max() ?? -1) + 1
    }
    
    private var nextSceneOrderIndex: Int {
        let scenes = project.scenes ?? []
        return (scenes.map { $0.userOrder ?? 0 }.max() ?? -1) + 1
    }
    
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
    
    private var availableScenes: [StoryScene] {
        // Scenes are attached to TextFiles in folders, not directly in project.scenes
        // Find all scenes by looking at TextFiles in project folders that have a scene
        var scenes: [StoryScene] = []
        
        for folder in project.folders ?? [] {
            for textFile in folder.textFiles ?? [] {
                if let scene = textFile.scene {
                    scenes.append(scene)
                }
            }
        }
        
        let sorted = scenes.sorted {
            ($0.userOrder ?? 0) < ($1.userOrder ?? 0)
        }
        
        #if DEBUG
        print("📋 AddPlotElementSheet: Found \(sorted.count) scenes via folder traversal")
        for s in sorted {
            print("📋   - Scene: \(s.name ?? "nil")")
        }
        #endif
        
        return sorted
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Info
                Section {
                    TextField(NSLocalizedString("fiction.plot.element.title", comment: "Title"), text: $title)
                        .accessibilityLabel(NSLocalizedString("fiction.plot.element.title.accessibility", comment: "Plot element title"))
                } header: {
                    Text(NSLocalizedString("fiction.plot.element.section.basic", comment: "Basic Info"))
                }
                
                // Description
                Section {
                    TextEditor(text: $plotDescription)
                        .frame(minHeight: 100)
                        .accessibilityLabel(NSLocalizedString("fiction.plot.element.description.accessibility", comment: "Plot element description"))
                } header: {
                    Text(NSLocalizedString("fiction.plot.element.description", comment: "Description"))
                } footer: {
                    Text(NSLocalizedString("fiction.plot.element.description.footer", comment: "Describe what happens at this plot point"))
                }
                
                // Create Scene (optional)
                Section {
                    TextField(NSLocalizedString("fiction.plot.element.sceneName", comment: "Scene Name"), text: $sceneName)
                        .accessibilityLabel(NSLocalizedString("fiction.plot.element.sceneName.accessibility", comment: "Scene name to create"))
                } header: {
                    Text(NSLocalizedString("fiction.plot.element.section.createScene", comment: "Create Scene"))
                } footer: {
                    Text(NSLocalizedString("fiction.plot.element.sceneName.footer", comment: "Optionally name a scene to create for this plot beat"))
                }
                
                // Monomyth Stage (if project uses monomyth)
                if project.storyStructure.usesMonomyth {
                    Section {
                        if project.storyStructure == .monomythCampbell {
                            // Campbell's 17 stages
                            Picker(selectedCampbellStage.description, selection: $selectedCampbellStage) {
                                ForEach(CampbellMonomythStage.allCases, id: \.self) { stage in
                                    HStack {
                                        Text("\(stage.order).")
                                        Text(stage.localizedName)
                                    }
                                    .tag(stage)
                                }
                            }
                        } else {
                            // Vogler's 12 stages (default)
                            Picker(selectedMonomythStage.description, selection: $selectedMonomythStage) {
                                ForEach(MonomythStage.allCases, id: \.self) { stage in
                                    HStack {
                                        Text("\(stage.order).")
                                        Text(stage.localizedName)
                                    }
                                    .tag(stage)
                                }
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("fiction.plot.element.section.monomyth", comment: "Hero's Journey"))
                    } footer: {
                        Text(NSLocalizedString("fiction.plot.element.stage.footer", comment: "Assign to a stage of the Hero's Journey"))
                    }
                } else if project.storyStructure == .threeAct {
                    Section {
                        Picker(selectedThreeActStage.description, selection: $selectedThreeActStage) {
                            ForEach(ThreeActStage.allCases, id: \.self) { stage in
                                HStack {
                                    Text("\(stage.order).")
                                    Text(stage.localizedName)
                                }
                                .tag(stage)
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("fiction.plot.element.section.threeAct", comment: "Three-Act Structure"))
                    } footer: {
                        Text(NSLocalizedString("fiction.plot.element.stage.threeAct.footer", comment: "Assign to an act"))
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
                                    if selectedCharacters.contains(character) {
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
                                    if selectedLocations.contains(location) {
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
                
                // Link Existing Scenes (multi-select)
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
                                            Text(String(format: NSLocalizedString("fiction.scene.orderLabel", comment: "Scene #"), order + 1))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if selectedScenes.contains(scene) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("fiction.plot.element.section.linkScenes", comment: "Link Existing Scenes"))
                    } footer: {
                        Text(NSLocalizedString("fiction.plot.element.linkScenes.footer", comment: "Select scenes to associate with this plot beat"))
                    }
                }
            }
            .navigationTitle(NSLocalizedString("fiction.plot.element.add.title", comment: "Add Plot Element"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.add", comment: "Add")) {
                        addPlotElement()
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
    
    private func toggleCharacter(_ character: Character) {
        if selectedCharacters.contains(character) {
            selectedCharacters.remove(character)
        } else {
            selectedCharacters.insert(character)
        }
    }
    
    private func toggleLocation(_ location: Location) {
        if selectedLocations.contains(location) {
            selectedLocations.remove(location)
        } else {
            selectedLocations.insert(location)
        }
    }
    
    private func toggleScene(_ scene: StoryScene) {
        if selectedScenes.contains(scene) {
            selectedScenes.remove(scene)
        } else {
            selectedScenes.insert(scene)
        }
    }
    
    private func addPlotElement() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            errorMessage = NSLocalizedString("fiction.plot.element.error.titleRequired", comment: "Title required")
            showErrorAlert = true
            return
        }
        
        // Create element with appropriate stage based on story structure
        let element: PlotElement
        switch project.storyStructure {
        case .monomythVogler:
            element = PlotElement(
                name: trimmedTitle,
                notes: plotDescription.isEmpty ? nil : plotDescription,
                monomythStage: selectedMonomythStage,
                userOrder: nextOrderIndex
            )
        case .monomythCampbell:
            element = PlotElement(
                name: trimmedTitle,
                notes: plotDescription.isEmpty ? nil : plotDescription,
                campbellStage: selectedCampbellStage,
                userOrder: nextOrderIndex
            )
        case .threeAct:
            element = PlotElement(
                name: trimmedTitle,
                notes: plotDescription.isEmpty ? nil : plotDescription,
                threeActStage: selectedThreeActStage,
                userOrder: nextOrderIndex
            )
        case .freeform:
            element = PlotElement(
                name: trimmedTitle,
                notes: plotDescription.isEmpty ? nil : plotDescription,
                userOrder: nextOrderIndex
            )
        }
        element.project = project
        element.characters = Array(selectedCharacters)
        element.locations = Array(selectedLocations)
        element.linkedScenes = Array(selectedScenes)
        
        // Update inverse relationships for selected scenes
        for scene in selectedScenes {
            var scenePlotElements = scene.plotElements ?? []
            scenePlotElements.append(element)
            scene.plotElements = scenePlotElements
        }
        
        modelContext.insert(element)
        
        // Create scene if name provided
        let trimmedSceneName = sceneName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSceneName.isEmpty {
            // Find Draft folder
            let scenesFolder = project.folders?.first { $0.name == "Scenes" }
            
            let scene = StoryScene(
                name: trimmedSceneName,
                userOrder: nextSceneOrderIndex
            )
            scene.project = project
            
            // Also add to project.scenes to ensure relationship is synced
            if project.scenes == nil {
                project.scenes = []
            }
            project.scenes?.append(scene)
            
            // Set stage based on story structure
            switch project.storyStructure {
            case .monomythVogler:
                scene.monomythStage = selectedMonomythStage
            case .monomythCampbell:
                scene.campbellStage = selectedCampbellStage
            case .threeAct:
                scene.threeActStage = selectedThreeActStage
            case .freeform:
                break
            }
            scene.characters = Array(selectedCharacters)
            // Set first location if any selected
            scene.location = selectedLocations.first
            // Link scene to plot element (set both sides of relationship)
            scene.plotElements = [element]
            element.linkedScenes = [scene]
            
            // Create TextFile for scene content in Draft folder
            let textFile = TextFile(name: trimmedSceneName, initialContent: "", parentFolder: scenesFolder)
            textFile.workflowStatus = .draft  // New scenes start as drafts
            textFile.scene = scene
            scene.textFile = textFile
            
            modelContext.insert(scene)
            modelContext.insert(textFile)
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
