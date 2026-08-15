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
    var onExport: ((TextFile) -> Void)? = nil
    var onDismiss: (() -> Void)? = nil
    
    // MARK: - State
    
    @State private var isEditing = false
    @State private var editTitle: String = ""
    @State private var editSummary: String = ""
    @State private var editMonomythStage: MonomythStage?
    @State private var editThreeActStage: ThreeActStage?
    @State private var editLocations: Set<Location> = []
    @State private var editCharacters: Set<Character> = []
    @State private var editPlotElements: Set<PlotElement> = []
    @State private var showDeleteConfirmation = false
    
    // MARK: - Computed
    
    private var isVerseNovel: Bool {
        project.type == .fiction && project.fictionClass == .verseNovel
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
    
    private var availablePlotElements: [PlotElement] {
        (project.plotElements ?? []).sorted {
            ($0.userOrder ?? 0) < ($1.userOrder ?? 0)
        }
    }
    
    // MARK: - File Statistics
    
    private var sceneTextFile: TextFile? {
        scene.textFile
    }
    
    private var wordCount: Int {
        guard let content = sceneTextFile?.currentVersion?.content else { return 0 }
        return content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }
    
    private var characterCount: Int {
        sceneTextFile?.currentVersion?.content.count ?? 0
    }
    
    private var lineCount: Int {
        guard let content = sceneTextFile?.currentVersion?.content else { return 0 }
        return content.components(separatedBy: .newlines).count
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
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
                            closeView()
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
                NSLocalizedString(isVerseNovel ? "fiction.episodes.deleteConfirm.title" : "fiction.scenes.deleteConfirm.title", comment: "Delete?"),
                isPresented: $showDeleteConfirmation
            ) {
                Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                    deleteScene()
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
            } message: {
                Text(String(format: NSLocalizedString(isVerseNovel ? "fiction.episodes.deleteConfirm.message" : "fiction.scenes.deleteConfirm.message", comment: "Delete message"), scene.name ?? ""))
            }
        }
    }
    
    // MARK: - Viewing Content
    
    @ViewBuilder
    private var viewingContent: some View {
        basicInfoSection
        summarySection
        locationSection
        charactersSection
        plotElementsSection
        monomythSection
        associatedFileSection
        fileMetadataSections
        containerSection
        exportSection
        deleteSection
    }

    private var basicInfoSection: some View {
        Section {
            LabeledContent(NSLocalizedString(isVerseNovel ? "fiction.episode.title" : "fiction.scene.title", comment: "Title")) {
                Text(scene.name ?? "-")
            }

            if let userOrder = scene.userOrder {
                LabeledContent(NSLocalizedString(isVerseNovel ? "fiction.episode.number" : "fiction.scene.number", comment: "Scene/Episode #")) {
                    Text("\(userOrder + 1)")
                }
            }
        } header: {
            Text(NSLocalizedString(isVerseNovel ? "fiction.episode.section.basic" : "fiction.scene.section.basic", comment: "Basic Info"))
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        if let synopsis = scene.synopsis, !synopsis.isEmpty {
            Section {
                Text(synopsis)
            } header: {
                Text(NSLocalizedString(isVerseNovel ? "fiction.episode.summary" : "fiction.scene.summary", comment: "Summary"))
            }
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        let locs = scene.locations ?? []
        if !locs.isEmpty {
            Section {
                ForEach(locs.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }) { location in
                    Text(location.name ?? "-")
                }
            } header: {
                Text(NSLocalizedString(isVerseNovel ? "fiction.episode.section.location" : "fiction.scene.section.location", comment: "Location"))
            }
        }
    }

    @ViewBuilder
    private var charactersSection: some View {
        if let characters = scene.characters, !characters.isEmpty {
            Section {
                ForEach(characters.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }) { character in
                    HStack {
                        Text(character.name ?? "")
                        if let role = character.roleDisplayName {
                            Text("(\(role))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text(NSLocalizedString(isVerseNovel ? "fiction.episode.section.characters" : "fiction.scene.section.characters", comment: "Characters"))
            }
        }
    }

    @ViewBuilder
    private var plotElementsSection: some View {
        if let plotElements = scene.plotElements, !plotElements.isEmpty {
            Section {
                ForEach(plotElements.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }) { element in
                    NavigationLink {
                        PlotElementDetailView(plotElement: element, project: project)
                    } label: {
                        plotElementRow(element)
                    }
                }
            } header: {
                Text(NSLocalizedString(isVerseNovel ? "fiction.episode.section.plotElements" : "fiction.scene.section.plotElements", comment: "Plot Elements"))
            }
        }
    }

    private func plotElementRow(_ element: PlotElement) -> some View {
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
                Text(stage.localizedName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var monomythSection: some View {
        if let stage = scene.monomythStage {
            Section {
                LabeledContent(NSLocalizedString("fiction.scene.monomythStage", comment: "Stage")) {
                    Text(stage.localizedName)
                }

                Text(stage.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text(NSLocalizedString(isVerseNovel ? "fiction.episode.section.monomyth" : "fiction.scene.section.monomyth", comment: "Hero's Journey"))
            }
        }
    }

    @ViewBuilder
    private var associatedFileSection: some View {
        if let textFile = scene.textFile {
            Section {
                NavigationLink {
                    if project.type == .drama {
                        DramaSceneEditorView(file: textFile, project: project)
                    } else {
                        FileEditView(file: textFile)
                    }
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        Text(textFile.name)
                    }
                }
            } header: {
                Text(NSLocalizedString(isVerseNovel ? "fiction.episode.file" : "fiction.scene.file", comment: "Scene/Episode File"))
            }
        }
    }

    @ViewBuilder
    private var fileMetadataSections: some View {
        if let textFile = sceneTextFile {
            Section {
                HStack {
                    Text(NSLocalizedString("fileDetails.created", comment: "Created"))
                    Spacer()
                    Text(dateFormatter.string(from: textFile.createdDate))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(NSLocalizedString("fileDetails.modified", comment: "Modified"))
                    Spacer()
                    Text(dateFormatter.string(from: textFile.modifiedDate))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(NSLocalizedString("fileDetails.dates", comment: "Dates"))
            }

            Section {
                HStack {
                    Text(NSLocalizedString("fileDetails.words", comment: "Words"))
                    Spacer()
                    Text("\(wordCount)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(NSLocalizedString("fileDetails.characters", comment: "Characters"))
                    Spacer()
                    Text("\(characterCount)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(NSLocalizedString("fileDetails.lines", comment: "Lines"))
                    Spacer()
                    Text("\(lineCount)")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(NSLocalizedString("fileDetails.statistics", comment: "Statistics"))
            }

            workflowStatusSection(for: textFile)
        }
    }

    @ViewBuilder
    private func workflowStatusSection(for textFile: TextFile) -> some View {
        if let status = textFile.workflowStatus {
            Section {
                HStack {
                    Text(NSLocalizedString("fileDetails.workflowStatus", comment: "Workflow Status"))
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: status.systemImage)
                            .foregroundColor(Color(status.color))
                        Text(status.localizedName)
                            .foregroundColor(Color(status.color))
                    }
                }
            } header: {
                Text(NSLocalizedString("fileDetails.status", comment: "Status"))
            }
        }
    }

    private var containerSection: some View {
        Section {
            if let chapters = scene.chapters, !chapters.isEmpty {
                ForEach(chapters.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }) { chapter in
                    LabeledContent(NSLocalizedString("fileDetails.container.chapter", comment: "Chapter")) {
                        Text(chapter.name ?? "-")
                    }
                }
            }
            if let acts = scene.acts, !acts.isEmpty {
                ForEach(acts.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }) { act in
                    LabeledContent(NSLocalizedString("fileDetails.container.act", comment: "Act")) {
                        Text(act.name ?? "-")
                    }
                }
            }
            if let books = scene.books, !books.isEmpty {
                ForEach(books.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }) { book in
                    LabeledContent(NSLocalizedString("fileDetails.container.book", comment: "Book")) {
                        Text(book.name ?? "-")
                    }
                }
            }
        } header: {
            Text(NSLocalizedString("fileDetails.container", comment: "Container"))
        }
    }

    @ViewBuilder
    private var exportSection: some View {
        if let textFile = sceneTextFile, let onExport = onExport {
            Section {
                Button {
                    onExport(textFile)
                } label: {
                    Label(NSLocalizedString("fileList.export", comment: "Export"), systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text(NSLocalizedString(isVerseNovel ? "fiction.episode.delete" : "fiction.scene.delete", comment: "Delete Scene/Episode"))
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
                Text(NSLocalizedString("fiction.scene.section.location", comment: "Location"))
            }
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
        
        // Stage picker based on story structure
        if project.storyStructure == .monomythVogler {
            Section {
                Picker(NSLocalizedString("fiction.scene.monomythStage", comment: "Stage"), selection: $editMonomythStage) {
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
                
                if let stage = editMonomythStage {
                    Text(stage.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(NSLocalizedString("fiction.scene.section.monomyth", comment: "Hero's Journey"))
            }
        } else if project.storyStructure == .threeAct {
            Section {
                Picker(NSLocalizedString("fiction.scene.storyStage", comment: "Act"), selection: $editThreeActStage) {
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
                
                if let stage = editThreeActStage {
                    Text(stage.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(NSLocalizedString("fiction.scene.section.threeAct", comment: "Three-Act Structure"))
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
                                    if let stageOrder = element.stageOrder {
                                        Text("\(stageOrder).")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(element.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                                        .foregroundColor(.primary)
                                }
                                if let stageName = element.stageLocalizedName {
                                    Text(stageName)
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
    

    private func closeView() {
        onDismiss?()
        dismiss()
        dismissPresentedSheetOnCatalyst()
    }

    private func startEditing() {
        editTitle = scene.name ?? ""
        editSummary = scene.synopsis ?? ""
        editMonomythStage = scene.monomythStage
        editThreeActStage = scene.threeActStage
        editLocations = Set(scene.locations ?? [])
        editCharacters = Set(scene.characters ?? [])
        editPlotElements = Set(scene.plotElements ?? [])
        isEditing = true
    }
    
    private func toggleLocation(_ location: Location) {
        if editLocations.contains(location) {
            editLocations.remove(location)
        } else {
            editLocations.insert(location)
        }
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
        
        // Save the appropriate stage based on story structure
        if let project = scene.project {
            switch project.storyStructure {
            case .freeform:
                scene.monomythStageRaw = nil
                scene.campbellStageRaw = nil
                scene.threeActStageRaw = nil
                scene.pearsonStageRaw = nil
            case .threeAct:
                scene.threeActStage = editThreeActStage
                scene.monomythStageRaw = nil
                scene.campbellStageRaw = nil
                scene.pearsonStageRaw = nil
            case .monomythVogler:
                scene.monomythStage = editMonomythStage
                scene.campbellStageRaw = nil
                scene.threeActStageRaw = nil
                scene.pearsonStageRaw = nil
            }
        } else {
            scene.monomythStage = editMonomythStage
        }
        
        scene.locations = Array(editLocations)
        scene.characters = Array(editCharacters)
        scene.plotElements = Array(editPlotElements)
        scene.modifiedDate = Date()
        project.modifiedDate = Date()
        for plotElement in editPlotElements {
            plotElement.modifiedDate = Date()
        }
        
        WriteCoalescer.shared?.requestSave(reason: "scene-detail-save")
        WriteCoalescer.shared?.flush()
        isEditing = false
    }
    
    private func deleteScene() {
        modelContext.delete(scene)
        project.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "scene-detail-delete")
        WriteCoalescer.shared?.flush()
        dismiss()
    }
}
