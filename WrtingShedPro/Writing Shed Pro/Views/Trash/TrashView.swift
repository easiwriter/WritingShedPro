//
//  TrashView.swift
//  Writing Shed Pro
//
//  Created on 2025-11-08.
//  Feature: 008a-file-movement - Phase 4
//

import SwiftUI
import SwiftData

/// View for displaying and managing trashed files with Put Back functionality.
///
/// **Key Features:**
/// - Lists all trashed files for a project
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
    
    /// Selected trash item IDs
    @State private var selectedItemIDs: Set<UUID> = []
    
    /// Shows Put Back confirmation
    @State private var showPutBackConfirmation = false
    
    /// Shows permanent delete confirmation
    @State private var showPermanentDeleteConfirmation = false
    
    /// Items pending Put Back
    @State private var itemsToPutBack: [TrashItem] = []
    
    /// Items pending permanent deletion
    @State private var itemsToDelete: [TrashItem] = []
    
    /// Shows notification when restored to fallback folder
    @State private var showFallbackNotification = false
    
    /// Message for fallback notification
    @State private var fallbackMessage = ""
    
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
    
    /// Selected trash items based on IDs
    private var selectedItems: [TrashItem] {
        allTrashItems.filter { selectedItemIDs.contains($0.id) }
    }
    
    /// Whether edit mode is active
    private var isEditMode: Bool {
        editMode == .active
    }
    
    /// Whether toolbar should be visible
    private var showToolbar: Bool {
        isEditMode && !selectedItemIDs.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if allTrashItems.isEmpty {
                emptyStateView
            } else {
                trashListView
            }
        }
        .navigationTitle("Trash")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Manual Edit/Done button (EditButton doesn't work with local @State)
                if !allTrashItems.isEmpty {
                    Button {
                        print("🗑️ TrashView: Edit button tapped, current mode: \(editMode)")
                        withAnimation {
                            editMode = editMode == .inactive ? .active : .inactive
                        }
                        print("🗑️ TrashView: After toggle, new mode: \(editMode)")
                    } label: {
                        Text(editMode == .inactive ? "Edit" : "Done")
                    }
                }
            }
            
            // Bottom toolbar for multi-select actions
            ToolbarItemGroup(placement: .bottomBar) {
                if showToolbar {
                    bottomToolbarContent
                }
            }
        }
        .alert("Put Back \(itemsToPutBack.count) \(itemsToPutBack.count == 1 ? "file" : "files")?",
               isPresented: $showPutBackConfirmation) {
            Button("Cancel", role: .cancel) {
                itemsToPutBack = []
            }
            Button("Put Back") {
                confirmPutBack()
            }
        } message: {
            Text("Files will be restored to their original folders.")
        }
        .alert("Permanently Delete \(itemsToDelete.count) \(itemsToDelete.count == 1 ? "file" : "files")?",
               isPresented: $showPermanentDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                itemsToDelete = []
            }
            Button("Delete Forever", role: .destructive) {
                confirmPermanentDelete()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Restored to Draft", isPresented: $showFallbackNotification) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(fallbackMessage)
        }
        .onChange(of: editMode) { _, newValue in
            if newValue == .inactive {
                selectedItemIDs.removeAll()
            }
        }
    }
    
    // MARK: - View Builders
    
    /// Empty state when trash is empty
    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Deleted Files", systemImage: "trash")
        } description: {
            Text("Files you delete will appear here and can be restored.")
        }
    }
    
    /// List of trashed items
    @ViewBuilder
    private var trashListView: some View {
        List(selection: $selectedItemIDs) {
            ForEach(allTrashItems) { item in
                trashItemRow(for: item)
                    .tag(item.id)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !isEditMode {
                            swipeActionButtons(for: item)
                        }
                    }
                    .contextMenu {
                        contextMenuItems(for: item)
                    }
            }
        }
        .environment(\.editMode, $editMode)
        .listStyle(.plain)
    }
    
    /// Row for a single trash item
    @ViewBuilder
    private func trashItemRow(for item: TrashItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.displayName)
                .font(.body)
            
            HStack(spacing: 8) {
                if let folderName = item.originalFolder?.name {
                    Label("From: \(folderName)", systemImage: "folder")
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
            Label("Put Back", systemImage: "arrow.uturn.backward")
        }
        .tint(.blue)
        
        Button(role: .destructive) {
            preparePermanentDelete([item])
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .tint(.red)
    }
    
    /// Bottom toolbar for edit mode
    @ViewBuilder
    private var bottomToolbarContent: some View {
        Button {
            preparePutBack(selectedItems)
        } label: {
            Label(
                "Put Back \(selectedItems.count)",
                systemImage: "arrow.uturn.backward"
            )
        }
        .disabled(selectedItems.isEmpty)
        
        Spacer()
        
        Button(role: .destructive) {
            preparePermanentDelete(selectedItems)
        } label: {
            Label(
                "Delete \(selectedItems.count)",
                systemImage: "trash"
            )
        }
        .disabled(selectedItems.isEmpty)
    }
    
    /// Context menu items for macOS right-click
    @ViewBuilder
    private func contextMenuItems(for item: TrashItem) -> some View {
        #if targetEnvironment(macCatalyst)
        // macOS: Show context menu
        Button {
            preparePutBack([item])
        } label: {
            Label("Put Back", systemImage: "arrow.uturn.backward")
        }
        
        Divider()
        
        Button(role: .destructive) {
            preparePermanentDelete([item])
        } label: {
            Label("Delete Forever", systemImage: "trash")
        }
        #else
        // iOS: Context menu disabled (use swipe actions instead)
        EmptyView()
        #endif
    }
    
    // MARK: - Actions
    
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
                print("Error putting back file: \(error)")
                // Continue with other files
            }
        }
        
        // Show notification if any files went to Draft
        if !restoredToFallback.isEmpty {
            let fileList = restoredToFallback.joined(separator: ", ")
            fallbackMessage = "The following files were restored to Draft because their original folders no longer exist: \(fileList)"
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
                modelContext.delete(textFile)
            }
            // Delete the trash item
            modelContext.delete(item)
        }
        
        try? modelContext.save()
        itemsToDelete = []
        exitEditMode()
    }
    
    /// Exits edit mode
    private func exitEditMode() {
        withAnimation {
            editMode = .inactive
        }
    }
}

// MARK: - Preview

#Preview("With Trash Items") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Project.self, Folder.self, TextFile.self, TrashItem.self,
        configurations: config
    )
    
    let context = container.mainContext
    
    // Create test data
    let project = Project(name: "Test Poetry", type: .poetry)
    let draftFolder = Folder(name: "Draft", project: project)
    let readyFolder = Folder(name: "Ready", project: project)
    
    let file1 = TextFile(name: "Deleted Poem 1", parentFolder: nil)
    let file2 = TextFile(name: "Deleted Poem 2", parentFolder: nil)
    let file3 = TextFile(name: "Deleted Poem 3", parentFolder: nil)
    
    let trashItem1 = TrashItem(
        textFile: file1,
        originalFolder: draftFolder,
        project: project
    )
    trashItem1.deletedDate = Date().addingTimeInterval(-3600) // 1 hour ago
    
    let trashItem2 = TrashItem(
        textFile: file2,
        originalFolder: readyFolder,
        project: project
    )
    trashItem2.deletedDate = Date().addingTimeInterval(-86400) // 1 day ago
    
    let trashItem3 = TrashItem(
        textFile: file3,
        originalFolder: draftFolder,
        project: project
    )
    trashItem3.deletedDate = Date().addingTimeInterval(-172800) // 2 days ago
    
    context.insert(project)
    context.insert(draftFolder)
    context.insert(readyFolder)
    context.insert(file1)
    context.insert(file2)
    context.insert(file3)
    context.insert(trashItem1)
    context.insert(trashItem2)
    context.insert(trashItem3)
    
    return NavigationStack {
        TrashView(project: project)
            .modelContainer(container)
    }
}

#Preview("Empty Trash") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Project.self, Folder.self, TextFile.self, TrashItem.self,
        configurations: config
    )
    
    let project = Project(name: "Test Poetry", type: .poetry)
    container.mainContext.insert(project)
    
    return NavigationStack {
        TrashView(project: project)
            .modelContainer(container)
    }
}
