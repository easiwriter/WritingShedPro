//
//  TrashView.swift
//  Writing Shed Pro
//
//  Created on 2025-11-08.
//  Feature: 008a-file-movement - Phase 4
//  Updated: 2026-01-08 - Added Fiction scene trash support (Feature 022)
//

import SwiftUI
import SwiftData

/// View for displaying and managing trashed files and scenes with Put Back functionality.
///
/// **Key Features:**
/// - Lists all trashed files for a project
/// - Lists all trashed scenes for Fiction projects
/// - Shows "From: {folder}" and deletion date
/// - Edit mode with multi-select
/// - Swipe actions for Put Back and Permanent Delete
/// - Toolbar with batch Put Back action
/// - Empty state when no trashed items
///
/// **Usage:**
/// ```swift
/// NavigationLink(destination: TrashView(project: project)) {
///     Label("Trash", systemImage: "trash")
/// }
/// ```
struct TrashView: View {
    // MARK: - Properties
    
    let project: Project
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State
    
    /// Edit mode state for multi-select (manual button instead of EditButton)
    @State private var editMode: EditMode = .inactive
    
    /// Selected trash item IDs (for files)
    @State private var selectedItemIDs: Set<UUID> = []
    
    /// Selected scene IDs (for trashed scenes)
    @State private var selectedSceneIDs: Set<UUID> = []
    
    /// Shows Put Back confirmation
    @State private var showPutBackConfirmation = false
    
    /// Shows permanent delete confirmation
    @State private var showPermanentDeleteConfirmation = false
    
    /// Items pending Put Back
    @State private var itemsToPutBack: [TrashItem] = []
    
    /// Scenes pending restore
    @State private var scenesToRestore: [StoryScene] = []
    
    /// Items pending permanent deletion
    @State private var itemsToDelete: [TrashItem] = []
    
    /// Scenes pending permanent deletion
    @State private var scenesToDelete: [StoryScene] = []
    
    /// Shows notification when restored to fallback folder
    @State private var showFallbackNotification = false
    
    /// Message for fallback notification
    @State private var fallbackMessage = ""
    
    /// Shows scene restore confirmation
    @State private var showSceneRestoreConfirmation = false
    
    /// Shows scene delete confirmation
    @State private var showSceneDeleteConfirmation = false
    
    // MARK: - Queries
    
    /// Fetch all trash items for this project, sorted by deleted date (newest first)
    @Query private var allTrashItems: [TrashItem]
    
    init(project: Project) {
        self.project = project
        
        // Set up query filter for this project
        let projectID = project.id
        _allTrashItems = Query(
            filter: #Predicate<TrashItem> { item in
                item.project?.id == projectID
            },
            sort: \.deletedDate,
            order: .reverse
        )
    }
    
    // MARK: - Computed Properties
    
    /// Whether this is a fiction project
    private var isFictionProject: Bool {
        project.type == .fiction
    }
    
    /// Trashed scenes for fiction projects
    private var trashedScenes: [StoryScene] {
        guard isFictionProject else { return [] }
        return (project.scenes ?? [])
            .filter { $0.isTrashed }
            .sorted { ($0.trashedDate ?? Date.distantPast) > ($1.trashedDate ?? Date.distantPast) }
    }
    
    /// Selected trash items based on IDs
    private var selectedItems: [TrashItem] {
        allTrashItems.filter { selectedItemIDs.contains($0.id) }
    }
    
    /// Selected scenes based on IDs
    private var selectedScenes: [StoryScene] {
        trashedScenes.filter { selectedSceneIDs.contains($0.id) }
    }
    
    /// Whether edit mode is active
    private var isEditMode: Bool {
        editMode == .active
    }
    
    /// Whether toolbar should be visible
    private var showToolbar: Bool {
        isEditMode && (!selectedItemIDs.isEmpty || !selectedSceneIDs.isEmpty)
    }
    
    /// Total selected count for toolbar
    private var totalSelectedCount: Int {
        selectedItemIDs.count + selectedSceneIDs.count
    }
    
    /// Whether trash is empty (no files or scenes)
    private var isTrashEmpty: Bool {
        allTrashItems.isEmpty && trashedScenes.isEmpty
    }
    
    /// Whether there are any items that can be edited
    private var hasAnyItems: Bool {
        !allTrashItems.isEmpty || !trashedScenes.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isTrashEmpty {
                emptyStateView
            } else {
                trashListView
            }
        }
        .navigationTitle("trashView.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Manual Edit/Done button (EditButton doesn't work with local @State)
                if hasAnyItems {
                    Button {
                        #if DEBUG
                        print("🗑️ TrashView: Edit button tapped, current mode: \(editMode)")
                        #endif
                        withAnimation {
                            editMode = editMode == .inactive ? .active : .inactive
                        }
                        #if DEBUG
                        print("🗑️ TrashView: After toggle, new mode: \(editMode)")
                        #endif
                    } label: {
                        Text(editMode == .inactive ? "button.edit" : "button.done")
                    }
                    .accessibilityLabel(editMode == .inactive ? "trashView.editMode.accessibility" : "trashView.doneEditing.accessibility")
                }
            }
            
            // Bottom toolbar for multi-select actions
            ToolbarItemGroup(placement: .bottomBar) {
                if showToolbar {
                    bottomToolbarContent
                }
            }
        }
        .alert(String(format: NSLocalizedString("trashView.putBackAlert.title", comment: ""), itemsToPutBack.count, itemsToPutBack.count == 1 ? NSLocalizedString("trashView.file", comment: "") : NSLocalizedString("trashView.files", comment: "")),
               isPresented: $showPutBackConfirmation) {
            Button("button.cancel", role: .cancel) {
                itemsToPutBack = []
            }
            Button("trashView.putBack") {
                confirmPutBack()
            }
        } message: {
            Text("trashView.putBackAlert.message")
        }
        .alert(String(format: NSLocalizedString("trashView.deleteAlert.title", comment: ""), itemsToDelete.count, itemsToDelete.count == 1 ? NSLocalizedString("trashView.file", comment: "") : NSLocalizedString("trashView.files", comment: "")),
               isPresented: $showPermanentDeleteConfirmation) {
            Button("button.cancel", role: .cancel) {
                itemsToDelete = []
            }
            Button("trashView.deleteForever", role: .destructive) {
                confirmPermanentDelete()
            }
        } message: {
            Text("trashView.deleteAlert.message")
        }
        .alert("trashView.restoredToDraft.title", isPresented: $showFallbackNotification) {
            Button("button.ok", role: .cancel) {}
        } message: {
            Text(fallbackMessage)
        }
        // Scene restore confirmation
        .confirmationDialog(
            String(format: NSLocalizedString("trashView.restoreScenes.title", comment: "Restore scenes?"), scenesToRestore.count),
            isPresented: $showSceneRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("trashView.restoreScene", comment: "Restore")) {
                confirmRestoreScenes()
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                scenesToRestore = []
            }
        } message: {
            Text(NSLocalizedString("trashView.restoreScenes.message", comment: "Scenes will be restored to your project"))
        }
        // Scene delete confirmation
        .confirmationDialog(
            String(format: NSLocalizedString("trashView.deleteScenes.title", comment: "Delete scenes?"), scenesToDelete.count),
            isPresented: $showSceneDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("trashView.deleteForever", comment: "Delete Forever"), role: .destructive) {
                confirmDeleteScenes()
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                scenesToDelete = []
            }
        } message: {
            Text(NSLocalizedString("trashView.deleteScenes.message", comment: "This cannot be undone"))
        }
        .onChange(of: editMode) { _, newValue in
            if newValue == .inactive {
                selectedItemIDs.removeAll()
                selectedSceneIDs.removeAll()
            }
        }
    }
    
    // MARK: - View Builders
    
    /// Empty state when trash is empty
    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("trashView.empty.title", systemImage: "trash")
        } description: {
            Text("trashView.empty.description")
        }
    }
    
    /// List of trashed items and scenes
    @ViewBuilder
    private var trashListView: some View {
        List {
            // Trashed Scenes section (Fiction projects only)
            if !trashedScenes.isEmpty {
                Section {
                    ForEach(trashedScenes) { scene in
                        HStack {
                            // Selection indicator in edit mode
                            if isEditMode {
                                Image(systemName: selectedSceneIDs.contains(scene.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedSceneIDs.contains(scene.id) ? .blue : .gray)
                                    .imageScale(.large)
                            }
                            
                            trashedSceneRow(for: scene)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditMode {
                                toggleSceneSelection(for: scene)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !isEditMode {
                                sceneSwipeActionButtons(for: scene)
                            }
                        }
                    }
                } header: {
                    Text(NSLocalizedString("trashView.scenes.header", comment: "Scenes"))
                }
            }
            
            // Trashed Files section
            if !allTrashItems.isEmpty {
                Section {
                    ForEach(allTrashItems) { item in
                        HStack {
                            // Selection indicator in edit mode
                            if isEditMode {
                                Image(systemName: selectedItemIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedItemIDs.contains(item.id) ? .blue : .gray)
                                    .imageScale(.large)
                            }
                            
                            trashItemRow(for: item)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditMode {
                                toggleSelection(for: item)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !isEditMode {
                                swipeActionButtons(for: item)
                            }
                        }
                        .contextMenu {
                            contextMenuItems(for: item)
                        }
                    }
                } header: {
                    if !trashedScenes.isEmpty {
                        Text(NSLocalizedString("trashView.files.header", comment: "Files"))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    /// Row for a trashed scene
    @ViewBuilder
    private func trashedSceneRow(for scene: StoryScene) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "film")
                    .foregroundStyle(.secondary)
                Text(scene.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                    .font(.body)
            }
            
            if let trashedDate = scene.trashedDate {
                Text(trashedDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    /// Swipe actions for scenes
    @ViewBuilder
    private func sceneSwipeActionButtons(for scene: StoryScene) -> some View {
        Button {
            prepareRestoreScenes([scene])
        } label: {
            Label(NSLocalizedString("trashView.restoreScene", comment: "Restore"), systemImage: "arrow.uturn.backward")
        }
        .tint(.blue)
        
        Button(role: .destructive) {
            prepareDeleteScenes([scene])
        } label: {
            Label(NSLocalizedString("trashView.delete", comment: "Delete"), systemImage: "trash")
        }
        .tint(.red)
    }
    
    /// Row for a single trash item (file)
    @ViewBuilder
    private func trashItemRow(for item: TrashItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.displayName)
                .font(.body)
            
            HStack(spacing: 8) {
                if let folderName = item.originalFolder?.name {
                    Label(String(format: NSLocalizedString("trashView.from", comment: ""), folderName), systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text("•")
                    .foregroundStyle(.tertiary)
                
                Text(item.deletedDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    /// Swipe action buttons (only in normal mode)
    @ViewBuilder
    private func swipeActionButtons(for item: TrashItem) -> some View {
        Button {
            preparePutBack([item])
        } label: {
            Label("trashView.putBack", systemImage: "arrow.uturn.backward")
        }
        .tint(.blue)
        
        Button(role: .destructive) {
            preparePermanentDelete([item])
        } label: {
            Label("trashView.delete", systemImage: "trash")
        }
        .tint(.red)
    }
    
    /// Bottom toolbar for edit mode
    @ViewBuilder
    private var bottomToolbarContent: some View {
        // Restore/Put Back button
        Button {
            // Handle files
            if !selectedItems.isEmpty {
                preparePutBack(selectedItems)
            }
            // Handle scenes
            if !selectedScenes.isEmpty {
                prepareRestoreScenes(selectedScenes)
            }
        } label: {
            Label(
                String(format: NSLocalizedString("trashView.restoreCount", comment: ""), totalSelectedCount),
                systemImage: "arrow.uturn.backward"
            )
        }
        .disabled(totalSelectedCount == 0)
        .accessibilityLabel("trashView.restoreSelected.accessibility")
        
        Spacer()
        
        // Delete button
        Button(role: .destructive) {
            // Handle files
            if !selectedItems.isEmpty {
                preparePermanentDelete(selectedItems)
            }
            // Handle scenes
            if !selectedScenes.isEmpty {
                prepareDeleteScenes(selectedScenes)
            }
        } label: {
            Label(
                String(format: NSLocalizedString("trashView.deleteCount", comment: ""), totalSelectedCount),
                systemImage: "trash"
            )
        }
        .disabled(totalSelectedCount == 0)
        .accessibilityLabel("trashView.deleteSelected.accessibility")
    }
    
    /// Context menu items for macOS right-click
    @ViewBuilder
    private func contextMenuItems(for item: TrashItem) -> some View {
        #if targetEnvironment(macCatalyst)
        // macOS: Show context menu
        Button {
            preparePutBack([item])
        } label: {
            Label("trashView.putBack", systemImage: "arrow.uturn.backward")
        }
        
        Divider()
        
        Button(role: .destructive) {
            preparePermanentDelete([item])
        } label: {
            Label("trashView.deleteForever", systemImage: "trash")
        }
        #else
        // iOS: Context menu disabled (use swipe actions instead)
        EmptyView()
        #endif
    }
    
    // MARK: - Actions
    
    /// Toggle selection for an item in edit mode
    private func toggleSelection(for item: TrashItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }
    
    /// Toggle selection for a scene in edit mode
    private func toggleSceneSelection(for scene: StoryScene) {
        if selectedSceneIDs.contains(scene.id) {
            selectedSceneIDs.remove(scene.id)
        } else {
            selectedSceneIDs.insert(scene.id)
        }
    }
    
    /// Prepares items for Put Back and shows confirmation
    private func preparePutBack(_ items: [TrashItem]) {
        itemsToPutBack = items
        showPutBackConfirmation = true
    }
    
    /// Confirms Put Back and restores files
    private func confirmPutBack() {
        let service = FileMoveService(modelContext: modelContext)
        var restoredToFallback: [String] = []
        
        for item in itemsToPutBack {
            do {
                // Check if original folder still exists
                let originalFolderExists = item.originalFolder != nil
                
                try service.putBack(item)
                
                // Track if restored to fallback
                if !originalFolderExists {
                    restoredToFallback.append(item.displayName)
                }
            } catch {
                #if DEBUG
                print("Error putting back file: \(error)")
                #endif
                // Continue with other files
            }
        }
        
        // Show notification if any files went to Draft
        if !restoredToFallback.isEmpty {
            let fileList = restoredToFallback.joined(separator: ", ")
            fallbackMessage = String(format: NSLocalizedString("trashView.restoredToDraft.message", comment: ""), fileList)
            showFallbackNotification = true
        }
        
        itemsToPutBack = []
        exitEditMode()
    }
    
    /// Prepares items for permanent deletion and shows confirmation
    private func preparePermanentDelete(_ items: [TrashItem]) {
        itemsToDelete = items
        showPermanentDeleteConfirmation = true
    }
    
    /// Confirms permanent deletion and removes files
    private func confirmPermanentDelete() {
        for item in itemsToDelete {
            // Delete the text file
            if let textFile = item.textFile {
                // Clean up index references before deleting
                FileMoveService.cleanupIndexReferences(for: textFile, context: modelContext)
                modelContext.delete(textFile)
            }
            // Delete the trash item
            modelContext.delete(item)
        }
        
        try? modelContext.save()
        itemsToDelete = []
        exitEditMode()
    }
    
    // MARK: - Scene Actions
    
    /// Prepares scenes for restoration and shows confirmation
    private func prepareRestoreScenes(_ scenes: [StoryScene]) {
        scenesToRestore = scenes
        showSceneRestoreConfirmation = true
    }
    
    /// Confirms restoration of scenes from trash
    private func confirmRestoreScenes() {
        for scene in scenesToRestore {
            scene.restore()
        }
        
        try? modelContext.save()
        scenesToRestore = []
        exitEditMode()
    }
    
    /// Prepares scenes for permanent deletion and shows confirmation
    private func prepareDeleteScenes(_ scenes: [StoryScene]) {
        scenesToDelete = scenes
        showSceneDeleteConfirmation = true
    }
    
    /// Confirms permanent deletion of scenes
    private func confirmDeleteScenes() {
        for scene in scenesToDelete {
            // Delete associated TextFile if exists
            if let textFile = scene.textFile {
                // Clean up index references before deleting
                FileMoveService.cleanupIndexReferences(for: textFile, context: modelContext)
                modelContext.delete(textFile)
            }
            // Delete the scene
            modelContext.delete(scene)
        }
        
        try? modelContext.save()
        scenesToDelete = []
        exitEditMode()
    }
    
    /// Exits edit mode
    private func exitEditMode() {
        withAnimation {
            editMode = .inactive
        }
    }
}

