//
//  SceneListView.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Scene management
//

import SwiftUI
import SwiftData

/// List view showing scenes - either for entire project (Short Fiction) or within a chapter (Novel)
struct SceneListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    /// Optional chapter - if provided, shows scenes for that chapter only (Novel mode)
    let chapter: FictionChapter?
    
    // MARK: - State
    
    @State private var showAddScene = false
    @State private var selectedScene: FictionScene?
    @State private var showDeleteConfirmation = false
    @State private var sceneToDelete: FictionScene?
    
    // MARK: - Init
    
    init(project: Project, chapter: FictionChapter? = nil) {
        self.project = project
        self.chapter = chapter
    }
    
    // MARK: - Computed
    
    private var sortedScenes: [FictionScene] {
        let scenes: [FictionScene]
        
        if let chapter = chapter {
            // Novel mode: scenes within a specific chapter
            scenes = chapter.scenes ?? []
        } else {
            // Short Fiction mode: all scenes at project level
            scenes = project.scenes ?? []
        }
        
        return scenes.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
    }
    
    private var title: String {
        if let chapter = chapter {
            return chapter.name ?? NSLocalizedString("fiction.scenes.title", comment: "Scenes")
        }
        return NSLocalizedString("fiction.scenes.title", comment: "Scenes")
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PopToRootBackButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddScene = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NSLocalizedString("fiction.scenes.add", comment: "Add scene"))
            }
        }
        .sheet(isPresented: $showAddScene) {
            AddSceneSheet(project: project, chapter: chapter)
        }
        .sheet(item: $selectedScene) { scene in
            SceneDetailView(scene: scene, project: project)
        }
        .alert(
            NSLocalizedString("fiction.scenes.deleteConfirm.title", comment: "Delete scene?"),
            isPresented: $showDeleteConfirmation,
            presenting: sceneToDelete
        ) { scene in
            Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                deleteScene(scene)
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        } message: { scene in
            Text(String(format: NSLocalizedString("fiction.scenes.deleteConfirm.message", comment: "Delete message"), scene.name ?? ""))
        }
    }
    
    // MARK: - Scene List
    
    private var sceneList: some View {
        List {
            ForEach(sortedScenes) { scene in
                SceneRowView(scene: scene)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedScene = scene
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            sceneToDelete = scene
                            showDeleteConfirmation = true
                        } label: {
                            Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
                        }
                    }
            }
            .onMove(perform: moveScenes)
        }
        .listStyle(.plain)
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
    
    private func deleteScene(_ scene: FictionScene) {
        modelContext.delete(scene)
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
}

// MARK: - Scene Row View

struct SceneRowView: View {
    let scene: FictionScene
    
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
