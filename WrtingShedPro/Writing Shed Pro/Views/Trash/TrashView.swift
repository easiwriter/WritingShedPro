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
    @Environment(\.dismiss) private var dismiss
    
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
        .navigationTitle("trashView.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onPopToRoot {
            dismiss()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PopToRootBackButton()
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Manual Edit/Done button (EditButton doesn't work with local @State)
                if !allTrashItems.isEmpty {
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
            Label("trashView.empty.title", systemImage: "trash")
        } description: {
            Text("trashView.empty.description")
        }
    }
    
    /// List of trashed items
    @ViewBuilder
    private var trashListView: some View {
        List {
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
                        // Edit mode: toggle selection
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
        }
        .listStyle(.insetGrouped)
    }
    
    /// Row for a single trash item
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
        Button {
            preparePutBack(selectedItems)
        } label: {
            Label(
                String(format: NSLocalizedString("trashView.putBackCount", comment: ""), selectedItems.count),
                systemImage: "arrow.uturn.backward"
            )
        }
        .disabled(selectedItems.isEmpty)
        .accessibilityLabel("trashView.putBackSelected.accessibility")
        
        Spacer()
        
        Button(role: .destructive) {
            preparePermanentDelete(selectedItems)
        } label: {
            Label(
                String(format: NSLocalizedString("trashView.deleteCount", comment: ""), selectedItems.count),
                systemImage: "trash"
            )
        }
        .disabled(selectedItems.isEmpty)
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

