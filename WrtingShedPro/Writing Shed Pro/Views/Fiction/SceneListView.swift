//
//  SceneListView.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Scene management
//

import SwiftUI
import SwiftData

/// List view showing scenes - either for entire project (Short Fiction) or within a chapter (Novel)
/// Matches FileListView pattern with:
/// - Edit mode with selection circles
/// - Bottom toolbar for multi-select actions
/// - Confirmation dialog with Delete (to trash) and Delete Forever options
struct SceneListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    /// Optional chapter - if provided, shows scenes for that chapter only (Novel mode)
    let chapter: Chapter?
    
    // MARK: - State
    
    @State private var showAddScene = false
    @State private var selectedScene: StoryScene?
    
    /// Edit mode binding
    @State private var editMode: EditMode = .inactive
    
    /// Selected scene IDs for multi-select
    @State private var selectedSceneIDs: Set<UUID> = []
    
    /// Delete confirmation dialog
    @State private var showDeleteConfirmation = false
    @State private var scenesToDelete: [StoryScene] = []
    
    // MARK: - Init
    
    init(project: Project, chapter: Chapter? = nil) {
        self.project = project
        self.chapter = chapter
    }
    
    // MARK: - Computed
    
    private var sortedScenes: [StoryScene] {
        let scenes: [StoryScene]
        
        if let chapter = chapter {
            // Novel mode: scenes within a specific chapter
            scenes = chapter.scenes ?? []
        } else {
            // Short Fiction mode: all scenes at project level
            scenes = project.scenes ?? []
        }
        
        // Filter out trashed scenes and sort by order
        return scenes
            .filter { !$0.isTrashed }
            .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
    }
    
    private var title: String {
        if let chapter = chapter {
            return chapter.name ?? NSLocalizedString("fiction.scenes.title", comment: "Scenes")
        }
        return NSLocalizedString("fiction.scenes.title", comment: "Scenes")
    }
    
    /// Whether edit mode is currently active
    private var isEditMode: Bool {
        editMode == .active
    }
    
    /// Selected scenes based on selectedSceneIDs
    private var selectedScenes: [StoryScene] {
        sortedScenes.filter { selectedSceneIDs.contains($0.id) }
    }
    
    /// Whether bottom toolbar should show
    private var showToolbar: Bool {
        isEditMode && !selectedSceneIDs.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if sortedScenes.isEmpty {
                emptyState
            } else {
                sceneList
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onPopToRoot {
            dismiss()
        }
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PopToRootBackButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if !sortedScenes.isEmpty {
                    Button {
                        withAnimation {
                            if editMode == .active {
                                editMode = .inactive
                                selectedSceneIDs.removeAll()
                            } else {
                                editMode = .active
                            }
                        }
                    } label: {
                        Text(isEditMode ? NSLocalizedString("button.done", comment: "Done") : NSLocalizedString("button.edit", comment: "Edit"))
                    }
                    .accessibilityLabel(isEditMode ? NSLocalizedString("button.done", comment: "Done") : NSLocalizedString("fiction.scenes.edit", comment: "Edit scenes"))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddScene = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NSLocalizedString("fiction.scenes.add", comment: "Add scene"))
            }
            
            // Bottom toolbar for multi-select actions
            ToolbarItemGroup(placement: .bottomBar) {
                if showToolbar {
                    bottomToolbarContent
                }
            }
        }
        .sheet(isPresented: $showAddScene) {
            AddSceneSheet(project: project, chapter: chapter)
        }
        .sheet(item: $selectedScene) { scene in
            SceneDetailView(scene: scene, project: project)
        }
        .confirmationDialog(
            scenesToDelete.count == 1
                ? NSLocalizedString("fiction.scenes.deleteConfirm.title", comment: "Delete scene?")
                : String(format: NSLocalizedString("fiction.scenes.deleteMultiple.title", comment: "Delete scenes?"), scenesToDelete.count),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("fiction.scenes.delete.toTrash", comment: "Move to Trash"), role: .destructive) {
                moveScenesToTrash(scenesToDelete)
                scenesToDelete = []
                exitEditMode()
            }
            Button(NSLocalizedString("fiction.scenes.delete.permanently", comment: "Delete Forever"), role: .destructive) {
                deleteScenesPermanently(scenesToDelete)
                scenesToDelete = []
                exitEditMode()
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                scenesToDelete = []
            }
        } message: {
            Text(NSLocalizedString("fiction.scenes.deleteConfirm.message.enhanced", comment: "Move to Trash keeps the scene's file, Delete Forever is permanent"))
        }
        .onChange(of: editMode) { _, newValue in
            if newValue == .inactive {
                selectedSceneIDs.removeAll()
            }
        }
    }
    
    // MARK: - Bottom Toolbar
    
    @ViewBuilder
    private var bottomToolbarContent: some View {
        Spacer()
        
        Button(role: .destructive) {
            prepareDelete(selectedScenes)
        } label: {
            Label(
                String(format: NSLocalizedString("fiction.scenes.deleteCount", comment: "Delete count"), selectedScenes.count),
                systemImage: "trash"
            )
        }
        .disabled(selectedScenes.isEmpty)
        .accessibilityLabel(NSLocalizedString("fiction.scenes.deleteSelected", comment: "Delete selected scenes"))
    }
    
    // MARK: - Scene List
    
    private var sceneList: some View {
        List {
            ForEach(sortedScenes) { scene in
                sceneRow(for: scene)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !isEditMode {
                            Button(role: .destructive) {
                                prepareDelete([scene])
                            } label: {
                                Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
                            }
                        }
                    }
            }
            .onMove(perform: moveScenes)
        }
        .listStyle(.plain)
    }
    
    // MARK: - Scene Row
    
    @ViewBuilder
    private func sceneRow(for scene: StoryScene) -> some View {
        HStack {
            // Selection circle in edit mode
            if isEditMode {
                Image(systemName: selectedSceneIDs.contains(scene.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedSceneIDs.contains(scene.id) ? .blue : .gray)
                    .imageScale(.large)
            }
            
            SceneRowView(scene: scene)
            
            Spacer(minLength: 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditMode {
                toggleSelection(for: scene)
            } else {
                selectedScene = scene
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("fiction.scenes.empty.title", comment: "No scenes"))
                .font(.headline)
            
            Text(NSLocalizedString("fiction.scenes.empty.message", comment: "Empty message"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showAddScene = true
            } label: {
                Label(NSLocalizedString("fiction.scenes.add", comment: "Add scene"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func toggleSelection(for scene: StoryScene) {
        if selectedSceneIDs.contains(scene.id) {
            selectedSceneIDs.remove(scene.id)
        } else {
            selectedSceneIDs.insert(scene.id)
        }
    }
    
    private func prepareDelete(_ scenes: [StoryScene]) {
        scenesToDelete = scenes
        showDeleteConfirmation = true
    }
    
    private func moveScenesToTrash(_ scenes: [StoryScene]) {
        for scene in scenes {
            // Soft delete the scene (marks as trashed)
            scene.moveToTrash()
        }
        
        try? modelContext.save()
        renumberScenes()
    }
    
    private func deleteScenesPermanently(_ scenes: [StoryScene]) {
        for scene in scenes {
            // Delete associated TextFile if exists
            if let textFile = scene.textFile {
                modelContext.delete(textFile)
            }
            // Delete the scene
            modelContext.delete(scene)
        }
        
        try? modelContext.save()
        renumberScenes()
    }
    
    private func moveScenes(from source: IndexSet, to destination: Int) {
        var scenes = sortedScenes
        scenes.move(fromOffsets: source, toOffset: destination)
        
        // Update order indices
        for (index, scene) in scenes.enumerated() {
            scene.userOrder = index
        }
        
        try? modelContext.save()
    }
    
    private func renumberScenes() {
        for (index, scene) in sortedScenes.enumerated() {
            scene.userOrder = index
        }
        try? modelContext.save()
    }
    
    private func exitEditMode() {
        withAnimation {
            editMode = .inactive
        }
    }
}

// MARK: - Scene Row View

struct SceneRowView: View {
    let scene: StoryScene
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Scene number
                if let userOrder = scene.userOrder {
                    Text("\(userOrder + 1).")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .leading)
                }
                
                Text(scene.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                    .font(.headline)
            }
            
            // Summary preview
            if let synopsis = scene.synopsis, !synopsis.isEmpty {
                Text(synopsis)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Monomyth stage if applicable
            if let stage = scene.monomythStage {
                HStack(spacing: 4) {
                    Image(systemName: "circle.grid.3x3")
                        .font(.caption)
                    Text(NSLocalizedString("monomyth.\(stage.rawValue)", comment: "Stage name"))
                        .font(.caption)
                }
                .foregroundColor(.purple)
            }
            
            // Character and location indicators
            HStack(spacing: 12) {
                if let characters = scene.characters, !characters.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "person.2")
                            .font(.caption2)
                        Text("\(characters.count)")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                
                if let location = scene.location {
                    HStack(spacing: 2) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(location.name ?? "")
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
