//
//  AddSceneSheet.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Add scene form
//

import SwiftUI
import SwiftData

/// Sheet for adding a new scene to a fiction project
struct AddSceneSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    let chapter: Chapter?
    let act: Act?
    let book: Book?
    
    // MARK: - State
    
    @State private var title: String = ""
    @State private var summary: String = ""
    @State private var selectedMonomythStage: MonomythStage?
    @State private var selectedThreeActStage: ThreeActStage?
    @State private var selectedLocation: Location?
    @State private var selectedCharacters: Set<Character> = []
    @State private var selectedContentType: FileContentType = .richText
    @State private var selectedPoetryForm: PoetryForm?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var upgradePromptReason: UpgradePromptReason?
    
    // MARK: - Computed
    
    /// Whether this is a verse novel project (episodes use poetry editor)
    private var isVerseNovel: Bool {
        project.fictionClass == .verseNovel
    }
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
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
    
    private var nextOrderIndex: Int {
        let scenes: [StoryScene]
        if let chapter = chapter {
            scenes = chapter.scenes ?? []
        } else if let act = act {
            scenes = act.scenes ?? []
        } else if let book = book {
            scenes = book.scenes ?? []
        } else {
            scenes = project.scenes ?? []
        }
        return (scenes.map { $0.userOrder ?? 0 }.max() ?? -1) + 1
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Info
                Section {
                    TextField(isVerseNovel
                        ? NSLocalizedString("fiction.episode.title", comment: "Title")
                        : NSLocalizedString("fiction.scene.title", comment: "Title"), text: $title)
                        .accessibilityLabel(isVerseNovel
                            ? NSLocalizedString("fiction.episode.title.accessibility", comment: "Episode title")
                            : NSLocalizedString("fiction.scene.title.accessibility", comment: "Scene title"))
                } header: {
                    Text(isVerseNovel
                        ? NSLocalizedString("fiction.episode.section.basic", comment: "Basic Info")
                        : NSLocalizedString("fiction.scene.section.basic", comment: "Basic Info"))
                }
                
                // Poetry Form picker (Verse Novel only)
                if isVerseNovel {
                    Section {
                        PoetryFormPickerCompact(selectedForm: $selectedPoetryForm)
                    } header: {
                        Text(NSLocalizedString("fiction.episode.poetryForm", comment: "Poetry Form"))
                    } footer: {
                        Text(NSLocalizedString("fiction.episode.poetryFormFooter", comment: "Select a poetry form for this episode"))
                    }
                }
                
                // Summary
                Section {
                    TextEditor(text: $summary)
                        .frame(minHeight: 80)
                        .accessibilityLabel(isVerseNovel
                            ? NSLocalizedString("fiction.episode.summary.accessibility", comment: "Episode summary")
                            : NSLocalizedString("fiction.scene.summary.accessibility", comment: "Scene summary"))
                } header: {
                    Text(isVerseNovel
                        ? NSLocalizedString("fiction.episode.summary", comment: "Summary")
                        : NSLocalizedString("fiction.scene.summary", comment: "Summary"))
                } footer: {
                    Text(isVerseNovel
                        ? NSLocalizedString("fiction.episode.summary.footer", comment: "Brief description of what happens")
                        : NSLocalizedString("fiction.scene.summary.footer", comment: "Brief description of what happens"))
                }
                
                // Content type picker (not for Verse Novel - they use rich text for poetry)
                if !isVerseNovel {
                    Section {
                        Picker(NSLocalizedString("addFile.contentType", comment: "Content Type"), selection: $selectedContentType) {
                            ForEach(FileContentType.allCases, id: \.self) { contentType in
                                Label(contentType.localizedName, systemImage: contentType.systemImage)
                                    .tag(contentType)
                            }
                        }
                        .pickerStyle(.menu)
                    } header: {
                        Text(NSLocalizedString("addFile.contentTypeHeader", comment: "Content Type section header"))
                    } footer: {
                        Text(selectedContentType.description)
                    }
                }
                
                // Location (optional)
                Section {
                    Picker(NSLocalizedString("fiction.scene.location", comment: "Location"), selection: $selectedLocation) {
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
                        Text(NSLocalizedString("fiction.scene.section.characters", comment: "Characters"))
                    } footer: {
                        Text(String(format: NSLocalizedString("fiction.scene.characters.selected", comment: "Selected count"), selectedCharacters.count))
                    }
                }
                
                // Stage picker based on story structure
                if project.storyStructure == .monomythVogler {
                    Section {
                        Picker(NSLocalizedString("fiction.scene.monomythStage", comment: "Story Stage"), selection: $selectedMonomythStage) {
                            Text(NSLocalizedString("fiction.scene.monomythStage.none", comment: "None"))
                                .tag(nil as MonomythStage?)
                            
                            ForEach(MonomythStage.allCases, id: \.self) { stage in
                                HStack {
                                    Text("\(stage.order).")
                                    Text(stage.localizedName)
                                }
                                .tag(stage as MonomythStage?)
                            }
                        }
                        
                        if let stage = selectedMonomythStage {
                            Text(stage.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text(NSLocalizedString("fiction.scene.section.monomyth", comment: "Hero's Journey"))
                    }
                } else if project.storyStructure == .threeAct {
                    Section {
                        Picker(NSLocalizedString("fiction.scene.storyStage", comment: "Act"), selection: $selectedThreeActStage) {
                            Text(NSLocalizedString("fiction.scene.monomythStage.none", comment: "None"))
                                .tag(nil as ThreeActStage?)
                            
                            ForEach(ThreeActStage.allCases, id: \.self) { stage in
                                HStack {
                                    Text("\(stage.order).")
                                    Text(stage.localizedName)
                                }
                                .tag(stage as ThreeActStage?)
                            }
                        }
                        
                        if let stage = selectedThreeActStage {
                            Text(stage.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text(NSLocalizedString("fiction.scene.section.threeAct", comment: "Three-Act Structure"))
                    }
                }
            }
            .navigationTitle(isVerseNovel
                ? NSLocalizedString("fiction.episode.add.title", comment: "Add Episode")
                : NSLocalizedString("fiction.scene.add.title", comment: "Add Scene"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.add", comment: "Add")) {
                        addScene()
                    }
                    .disabled(!isValid)
                }
            }
            .alert(NSLocalizedString("error.title", comment: "Error"), isPresented: $showErrorAlert) {
                Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .upgradePrompt(reason: $upgradePromptReason) {
                self.addScene()
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
    
    private func addScene() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            errorMessage = isVerseNovel
                ? NSLocalizedString("fiction.episode.error.titleRequired", comment: "Title required")
                : NSLocalizedString("fiction.scene.error.titleRequired", comment: "Title required")
            showErrorAlert = true
            return
        }
        
        // Check entitlement for free tier file limits
        let existingFileCount = ProjectGateCounterService.activeFileCount(in: project)
        if !EntitlementManager.shared.canCreateFile(forProjectType: project.type, existingCount: existingFileCount) {
            upgradePromptReason = .fileLimit(projectType: project.type)
            return
        }
        
        // Find content folder
        let contentFolderName = isVerseNovel ? "Episodes" : "Scenes"
        guard let scenesFolder = project.folders?.first(where: { $0.name == contentFolderName }) else {
            errorMessage = String(format: NSLocalizedString("fiction.scene.error.folderMissing", comment: "Missing content folder"), contentFolderName)
            showErrorAlert = true
            return
        }
        
        let scene = StoryScene(
            name: trimmedTitle,
            synopsis: summary.isEmpty ? nil : summary,
            userOrder: nextOrderIndex
        )
        scene.project = project
        scene.chapter = chapter
        scene.act = act
        scene.book = book
        
        // Also add to project.scenes to ensure relationship is synced
        if project.scenes == nil {
            project.scenes = []
        }
        project.scenes?.append(scene)

        if let chapter {
            if chapter.scenes == nil {
                chapter.scenes = []
            }
            chapter.scenes?.append(scene)
        }

        if let act {
            if act.scenes == nil {
                act.scenes = []
            }
            act.scenes?.append(scene)
        }

        if let book {
            if book.scenes == nil {
                book.scenes = []
            }
            book.scenes?.append(scene)
        }
        
        // Set relationships
        scene.location = selectedLocation
        scene.characters = Array(selectedCharacters)
        
        // Set stage based on story structure
        switch project.storyStructure {
        case .monomythVogler:
            scene.monomythStage = selectedMonomythStage
            scene.campbellStageRaw = nil
            scene.pearsonStageRaw = nil
        case .threeAct:
            scene.threeActStage = selectedThreeActStage
            scene.monomythStageRaw = nil
            scene.campbellStageRaw = nil
            scene.pearsonStageRaw = nil
        case .freeform:
            scene.monomythStageRaw = nil
            scene.campbellStageRaw = nil
            scene.threeActStageRaw = nil
            scene.pearsonStageRaw = nil
            break
        }
        
        // Create TextFile for scene content in Draft folder
        let textFile: TextFile
        
        if isVerseNovel {
            // Verse Novel episodes always use poetry editor
            // Use selected form, or free verse if none selected
            let formId = selectedPoetryForm?.id ?? PoetryForm.freeVerseId
            let formName = selectedPoetryForm?.name ?? "Free Verse"
            textFile = TextFile(
                name: trimmedTitle,
                initialContent: "",
                parentFolder: scenesFolder,
                poetryFormId: formId,
                poetryFormName: formName
            )
            textFile.contentType = .richText  // Poetry always uses rich text
        } else {
            textFile = TextFile(name: trimmedTitle, initialContent: "", parentFolder: scenesFolder)
            textFile.contentType = selectedContentType
        }
        
        textFile.workflowStatus = .draft  // New scenes start as drafts
        textFile.scene = scene
        scene.textFile = textFile
        scene.modifiedDate = Date()
        textFile.modifiedDate = Date()
        project.modifiedDate = Date()
        
        modelContext.insert(scene)
        modelContext.insert(textFile)
        
        WriteCoalescer.shared?.requestSave(reason: "add-scene")
        WriteCoalescer.shared?.flush()
        dismiss()
    }

}
