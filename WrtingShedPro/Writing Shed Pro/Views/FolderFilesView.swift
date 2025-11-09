//
//  FolderFilesView.swift
//  Writing Shed Pro
//
//  Created on 2025-11-08.
//  Feature 008a Integration: Replaces FileEditableList with FileListView
//

import SwiftUI
import SwiftData

/// View for displaying and managing files within a folder
/// Uses the new FileListView component with full file movement support
struct FolderFilesView: View {
    @Bindable var folder: Folder
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    // State for edit mode (shared with FileListView)
    @State private var editMode: EditMode = .inactive
    
    // State for file sorting
    @State private var sortOrder: FileSortOrder = .byName
    
    // State for move destination picker
    @State private var showMoveDestinationPicker = false
    @State private var filesToMove: [TextFile] = []
    
    // State for add file sheet
    @State private var showAddFileSheet = false
    
    // State for navigation
    @State private var selectedFile: TextFile?
    @State private var navigateToFile = false
    
    // Sorted files based on current sort order
    private var sortedFiles: [TextFile] {
        let files = folder.textFiles ?? []
        return FileSortService.sort(files, by: sortOrder)
    }
    
    var body: some View {
        Group {
            if !sortedFiles.isEmpty {
                // Show FileListView with sorted files
                FileListView(
                    files: sortedFiles,
                    onFileSelected: { file in
                        selectedFile = file
                        navigateToFile = true
                    },
                    onMove: { files in
                        filesToMove = files
                        showMoveDestinationPicker = true
                    },
                    onDelete: { files in
                        deleteFiles(files)
                    }
                )
            } else {
                // Empty state
                ContentUnavailableView {
                    Label("No Files", systemImage: "doc.text")
                } description: {
                    Text("Tap + to create your first file")
                }
            }
        }
        .navigationTitle(folder.name ?? "Files")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToFile) {
            if let file = selectedFile {
                FileEditView(file: file)
            }
        }
        .environment(\.editMode, $editMode)
        .onChange(of: editMode) { oldValue, newValue in
            print("🔴 FolderFilesView: editMode changed from \(oldValue) to \(newValue)")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Sort menu
                    if !sortedFiles.isEmpty {
                        Menu {
                            Picker("Sort", selection: $sortOrder) {
                                Text("Name").tag(FileSortOrder.byName)
                                Text("Created").tag(FileSortOrder.byCreationDate)
                                Text("Modified").tag(FileSortOrder.byModifiedDate)
                                Text("Custom").tag(FileSortOrder.byUserOrder)
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .accessibilityLabel("Sort files")
                    }
                    
                    // Add file button (left of Edit)
                    if FolderCapabilityService.canAddFile(to: folder) {
                        Button {
                            showAddFileSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add file")
                    }
                    
                    // Manual Edit/Done button on far right (replaces SwiftUI's EditButton which isn't working)
                    if !sortedFiles.isEmpty {
                        Button {
                            print("🔴 Manual Edit button tapped, current mode: \(editMode)")
                            withAnimation {
                                editMode = editMode == .inactive ? .active : .inactive
                            }
                            print("🔴 After toggle, new mode: \(editMode)")
                        } label: {
                            Text(editMode == .inactive ? "Edit" : "Done")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showMoveDestinationPicker) {
            if let project = folder.project {
                NavigationStack {
                    MoveDestinationPicker(
                        project: project,
                        currentFolder: folder,
                        filesToMove: filesToMove,
                        onDestinationSelected: { destination in
                            moveFiles(to: destination)
                        },
                        onCancel: {
                            showMoveDestinationPicker = false
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showAddFileSheet) {
            AddFileSheet(
                isPresented: $showAddFileSheet,
                parentFolder: folder,
                existingFiles: folder.textFiles ?? []
            )
        }
    }
    
    // MARK: - Actions
    
    private func deleteFiles(_ files: [TextFile]) {
        let service = FileMoveService(modelContext: modelContext)
        
        do {
            try service.deleteFiles(files)
        } catch {
            print("Error deleting files: \(error)")
            // TODO: Show error alert
        }
    }
    
    private func moveFiles(to destination: Folder) {
        let service = FileMoveService(modelContext: modelContext)
        
        do {
            try service.moveFiles(filesToMove, to: destination)
            showMoveDestinationPicker = false
            filesToMove = []
        } catch {
            print("Error moving files: \(error)")
            // TODO: Show error alert
        }
    }
}

// MARK: - Preview

#Preview("With Files") {
    NavigationStack {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Project.self, Folder.self, TextFile.self, configurations: config)
        let context = container.mainContext
        
        let project = Project(name: "Sample Project", type: .blank)
        let folder = Folder(name: "Draft", project: project)
        
        let file1 = TextFile(name: "Chapter 1", initialContent: "", parentFolder: folder)
        let file2 = TextFile(name: "Chapter 2", initialContent: "", parentFolder: folder)
        let file3 = TextFile(name: "Notes", initialContent: "", parentFolder: folder)
        
        folder.textFiles = [file1, file2, file3]
        
        context.insert(project)
        context.insert(folder)
        context.insert(file1)
        context.insert(file2)
        context.insert(file3)
        
        return FolderFilesView(folder: folder)
            .modelContainer(container)
    }
}

#Preview("Empty Folder") {
    NavigationStack {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Project.self, Folder.self, TextFile.self, configurations: config)
        let context = container.mainContext
        
        let project = Project(name: "Sample Project", type: .blank)
        let folder = Folder(name: "Draft", project: project)
        
        context.insert(project)
        context.insert(folder)
        
        return FolderFilesView(folder: folder)
            .modelContainer(container)
    }
}
