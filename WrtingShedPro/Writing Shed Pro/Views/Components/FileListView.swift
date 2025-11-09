//
//  FileListView.swift
//  Writing Shed Pro
//
//  Created on 2025-11-08.
//  Feature: 008a-file-movement - Phase 2, 6
//

import SwiftUI
import SwiftData

/// Reusable file list component with edit mode, swipe actions, and multi-select toolbar.
///
/// **Key Features:**
/// - Edit mode with selection circles (⚪/⚫)
/// - Swipe actions for quick single-file operations (normal mode only)
/// - Bottom toolbar with Move/Delete for multiple selections
/// - iOS-standard pattern following Mail/Files/Photos apps
/// - **Mac Catalyst**: Cmd+Click multi-select, right-click context menu
///
/// **Usage:**
/// ```swift
/// FileListView(
///     files: folder.textFiles ?? [],
///     onFileSelected: { file in
///         navigationPath.append(file)
///     },
///     onMove: { files in
///         showMoveDestinationPicker = true
///     },
///     onDelete: { files in
///         deleteFiles(files)
///     }
/// )
/// ```
struct FileListView: View {
    // MARK: - Properties
    
    /// Files to display in the list
    let files: [TextFile]
    
    /// Called when user taps a file in normal mode
    let onFileSelected: (TextFile) -> Void
    
    /// Called when user initiates move action (single or multiple files)
    let onMove: ([TextFile]) -> Void
    
    /// Called when user initiates delete action (single or multiple files)
    let onDelete: ([TextFile]) -> Void
    
    /// Called when user drags to reorder files (parent should switch to Custom sort)
    let onReorder: (() -> Void)?
    
    // MARK: - State
    
    /// Edit mode state - read from environment (set by parent view with EditButton)
    @Environment(\.editMode) private var editMode
    
    /// Currently selected file IDs for multi-select operations
    /// Using UUID instead of TextFile for selection to work with List
    @State private var selectedFileIDs: Set<UUID> = []
    
    /// Controls delete confirmation alert
    @State private var showDeleteConfirmation = false
    
    /// Files pending deletion (cached for confirmation alert)
    @State private var filesToDelete: [TextFile] = []
    
    // MARK: - Computed Properties
    
    /// Selected files based on selectedFileIDs
    private var selectedFiles: [TextFile] {
        files.filter { selectedFileIDs.contains($0.id) }
    }
    
    /// Whether edit mode is currently active
    private var isEditMode: Bool {
        editMode?.wrappedValue == .active
    }
    
    /// Whether toolbar should be visible (edit mode + items selected)
    private var showToolbar: Bool {
        isEditMode && !selectedFileIDs.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        List(selection: $selectedFileIDs) {
            ForEach(files) { file in
                fileRow(for: file)
                    .tag(file.id)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !isEditMode {
                            swipeActionButtons(for: file)
                        }
                    }
            }
            .onMove { indices, destination in
                // Handle reordering - only enabled in edit mode when userOrder sort is active
                handleMove(from: indices, to: destination)
            }
        }
        .listStyle(.plain)
        .toolbar {
            // Bottom toolbar for multi-select actions (only in edit mode)
            ToolbarItemGroup(placement: .bottomBar) {
                if showToolbar {
                    bottomToolbarContent
                }
            }
        }
        .alert(
            "Delete \(filesToDelete.count) \(filesToDelete.count == 1 ? "file" : "files")?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) {
                filesToDelete = []
            }
            Button("Delete", role: .destructive) {
                confirmDelete()
            }
        } message: {
            Text("Deleted files can be restored from Trash.")
        }
        .onChange(of: editMode?.wrappedValue) { _, newValue in
            // Clear selection when exiting edit mode
            if newValue == .inactive {
                selectedFileIDs.removeAll()
            }
        }
    }
    
    // MARK: - View Builders
    
    /// File row view - behavior changes based on edit mode
    @ViewBuilder
    private func fileRow(for file: TextFile) -> some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
            
            Text(file.name ?? "Untitled")
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditMode {
                // Normal mode: navigate to file
                onFileSelected(file)
            }
        }
        .contextMenu {
            contextMenuItems(for: file)
        }
    }
    
    /// Swipe action buttons (only shown in normal mode)
    @ViewBuilder
    private func swipeActionButtons(for file: TextFile) -> some View {
        Button {
            onMove([file])
        } label: {
            Label("Move", systemImage: "folder")
        }
        .tint(.blue)
        
        Button {
            prepareDelete([file])
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .tint(.red)
    }
    
    /// Bottom toolbar content for edit mode
    @ViewBuilder
    private var bottomToolbarContent: some View {
        Button {
            onMove(selectedFiles)
            exitEditMode()
        } label: {
            Label(
                "Move \(selectedFiles.count)",
                systemImage: "folder"
            )
        }
        .disabled(selectedFiles.isEmpty)
        
        Spacer()
        
        Button(role: .destructive) {
            prepareDelete(selectedFiles)
        } label: {
            Label(
                "Delete \(selectedFiles.count)",
                systemImage: "trash"
            )
        }
        .disabled(selectedFiles.isEmpty)
    }
    
    /// Context menu items for macOS right-click
    @ViewBuilder
    private func contextMenuItems(for file: TextFile) -> some View {
        #if targetEnvironment(macCatalyst)
        // macOS: Show context menu
        Button {
            onFileSelected(file)
        } label: {
            Label("Open", systemImage: "doc")
        }
        
        Divider()
        
        Button {
            onMove([file])
        } label: {
            Label("Move To...", systemImage: "folder")
        }
        
        Divider()
        
        Button(role: .destructive) {
            prepareDelete([file])
        } label: {
            Label("Delete", systemImage: "trash")
        }
        #else
        // iOS: Context menu disabled (use swipe actions instead)
        EmptyView()
        #endif
    }
    
    // MARK: - Actions
    
    /// Prepares files for deletion and shows confirmation alert
    private func prepareDelete(_ files: [TextFile]) {
        filesToDelete = files
        showDeleteConfirmation = true
    }
    
    /// Confirms deletion and exits edit mode
    private func confirmDelete() {
        onDelete(filesToDelete)
        filesToDelete = []
        exitEditMode()
    }
    
    /// Exits edit mode (returns to normal mode)
    private func exitEditMode() {
        withAnimation {
            editMode?.wrappedValue = .inactive
        }
    }
    
    /// Handles drag-to-reorder operation
    /// Updates userOrder for files when user manually reorders them
    private func handleMove(from source: IndexSet, to destination: Int) {
        // Create mutable copy of files array to reorder
        var reorderedFiles = files
        reorderedFiles.move(fromOffsets: source, toOffset: destination)
        
        // Update userOrder for all files based on new positions
        for (index, file) in reorderedFiles.enumerated() {
            file.userOrder = index
        }
        
        // Notify parent to switch to Custom sort so changes are visible
        onReorder?()
        
        // Note: TextFile is a SwiftData @Model (reference type), so changes persist automatically
        // Parent view's files array will reflect new order on next refresh
    }
}

// MARK: - Preview

#Preview("Empty List") {
    NavigationStack {
        FileListView(
            files: [],
            onFileSelected: { _ in },
            onMove: { _ in },
            onDelete: { _ in },
            onReorder: nil
        )
        .navigationTitle("Files")
    }
}

#Preview("With Files") {
    NavigationStack {
        FileListView(
            files: [
                TextFile(name: "Chapter 1", parentFolder: nil),
                TextFile(name: "Chapter 2", parentFolder: nil),
                TextFile(name: "Chapter 3", parentFolder: nil),
            ],
            onFileSelected: { file in
                print("Selected: \(file.name)")
            },
            onMove: { files in
                print("Move \(files.count) files")
            },
            onDelete: { files in
                print("Delete \(files.count) files")
            },
            onReorder: nil
        )
        .navigationTitle("Files")
    }
}
