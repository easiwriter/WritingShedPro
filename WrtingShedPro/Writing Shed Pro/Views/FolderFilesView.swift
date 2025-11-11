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
    
    // State for submission picker
    @State private var showSubmissionPicker = false
    @State private var filesToSubmit: [TextFile] = []
    
    // State for collection picker
    @State private var showCollectionPicker = false
    @State private var filesToAddToCollection: [TextFile] = []
    
    // Sorted files based on current sort order
    private var sortedFiles: [TextFile] {
        let files = folder.textFiles ?? []
        return FileSortService.sort(files, by: sortOrder)
    }
    
    // Check if this is the Ready folder (supports submissions)
    private var isReadyFolder: Bool {
        return folder.name == "Ready"
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
                    },
                    onSubmit: isReadyFolder ? { files in
                        filesToSubmit = files
                        showSubmissionPicker = true
                    } : nil,
                    onAddToCollection: isReadyFolder ? { files in
                        filesToAddToCollection = files
                        showCollectionPicker = true
                    } : nil,
                    onReorder: {
                        // User dragged to reorder - switch to Custom sort
                        sortOrder = .byUserOrder
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
                            withAnimation {
                                editMode = editMode == .inactive ? .active : .inactive
                            }
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
        .sheet(isPresented: $showSubmissionPicker) {
            if let project = folder.project {
                NavigationStack {
                    SubmissionPickerView(
                        project: project,
                        filesToSubmit: filesToSubmit,
                        collectionToSubmit: nil,
                        onPublicationSelected: { publication in
                            createSubmission(for: publication)
                            showSubmissionPicker = false
                        },
                        onCancel: {
                            showSubmissionPicker = false
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showCollectionPicker) {
            if let project = folder.project {
                NavigationStack {
                    CollectionPickerView(
                        project: project,
                        filesToAddToCollection: filesToAddToCollection,
                        collectionsToAddToPublication: nil,
                        mode: .addFilesToCollection,
                        onCollectionSelected: { collection in
                            addFilesToCollection(collection)
                            showCollectionPicker = false
                        },
                        onCancel: {
                            showCollectionPicker = false
                        }
                    )
                }
            }
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
    
    private func createSubmission(for publication: Publication) {
        guard let project = folder.project else { return }
        
        // Create submission
        let submission = Submission(
            publication: publication,
            project: project,
            submittedDate: Date(),
            notes: nil
        )
        modelContext.insert(submission)
        
        // Create submitted file records for each selected file
        for file in filesToSubmit {
            if let currentVersion = file.currentVersion {
                let submittedFile = SubmittedFile(
                    submission: submission,
                    textFile: file,
                    version: currentVersion,
                    status: .pending,
                    statusDate: Date(),
                    project: project
                )
                modelContext.insert(submittedFile)
            }
        }
        
        filesToSubmit = []
    }
    
    private func addFilesToCollection(_ collection: Submission) {
        guard let project = folder.project else { return }
        
        // Create submitted file records for each selected file in the collection
        for file in filesToAddToCollection {
            if let currentVersion = file.currentVersion {
                let submittedFile = SubmittedFile(
                    submission: collection,
                    textFile: file,
                    version: currentVersion,
                    status: .pending,
                    statusDate: Date(),
                    project: project
                )
                modelContext.insert(submittedFile)
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error adding files to collection: \(error)")
            // TODO: Show error alert
        }
        
        filesToAddToCollection = []
    }
}