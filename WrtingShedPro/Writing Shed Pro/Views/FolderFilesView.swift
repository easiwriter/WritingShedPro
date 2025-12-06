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
    
    // Query all folders to ensure we have fresh relationships
    @Query private var allFolders: [Folder]
    
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
    
    // State for rename
    @State private var showRenamePicker = false
    @State private var filesToRename: [TextFile] = []
    
    // State for Word document import
    @State private var showImportPicker = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    
    // State for export
    @State private var showExportMenu = false
    @State private var filesToExport: [TextFile] = []
    
    // Sorted files based on current sort order
    private var sortedFiles: [TextFile] {
        let files: [TextFile]
        
        // Special handling for "All" folder - compute from multiple folders
        if folder.name == "All" {
            if let project = folder.project {
                files = allFilesFromProject(project)
            } else {
                files = []
            }
        } else {
            files = folder.textFiles ?? []
        }
        
        return FileSortService.sort(files, by: sortOrder)
    }
    
    // Get all files from Draft, Ready, Set Aside, and Published folders
    private func allFilesFromProject(_ project: Project) -> [TextFile] {
        // Use the queried folders instead of project.folders for fresh relationships
        let projectFolders = allFolders.filter { $0.project?.id == project.id }
        
        guard !projectFolders.isEmpty else {
            return []
        }
        
        let targetFolderNames = ["Draft", "Ready", "Set Aside", "Published"]
        var allFiles: [TextFile] = []
        
        for folder in projectFolders {
            if targetFolderNames.contains(folder.name ?? "") {
                allFiles.append(contentsOf: folder.textFiles ?? [])
            }
        }
        
        return allFiles
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
                    onExport: { files in
                        filesToExport = files
                        showExportMenu = true
                    },
                    onSubmit: fileListOnSubmit,
                    onAddToCollection: fileListOnAddToCollection,
                    onReorder: {
                        sortOrder = .byUserOrder
                    },
                    onRename: { files in
                        filesToRename = files
                        showRenamePicker = true
                    }
                )
            } else {
                // Empty state
                ContentUnavailableView {
                    Label("folderFiles.noFiles", systemImage: "doc.text")
                } description: {
                    Text("folderFiles.noFiles.hint")
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
                            ForEach(FileSortService.sortOptions(), id: \.order) { option in
                                Button(action: {
                                    sortOrder = option.order
                                }) {
                                    HStack {
                                        Text(option.title)
                                        if sortOrder == option.order {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .accessibilityLabel("folderFiles.sort.accessibility")
                        .disabled(editMode == .active)
                    }
                    
                    // Import Word document button (between Edit and +)
                    if FolderCapabilityService.canAddFile(to: folder) {
                        Button {
                            showImportPicker = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .accessibilityLabel("Import Word document")
                        .help("Import Word document")
                        .disabled(editMode == .active)
                    }
                    
                    // Add file button (left of Edit)
                    if FolderCapabilityService.canAddFile(to: folder) {
                        Button {
                            showAddFileSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("folderFiles.addFile.accessibility")
                        .disabled(editMode == .active)
                    }
                    
                    // Manual Edit/Done button on far right (replaces SwiftUI's EditButton which isn't working)
                    if !sortedFiles.isEmpty {
                        Button {
                            withAnimation {
                                editMode = editMode == .inactive ? .active : .inactive
                            }
                        } label: {
                            Text(editMode == .inactive ? "button.edit" : "button.done")
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
        .sheet(isPresented: $showRenamePicker) {
            if let file = filesToRename.first {
                NavigationStack {
                    RenameFileModal(
                        file: file,
                        filesInFolder: sortedFiles,
                        onRename: { newName in
                            renameFile(newName: newName)
                        }
                    )
                }
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.init(filenameExtension: "docx")!, .rtf],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
        .confirmationDialog("Export Format", isPresented: $showExportMenu) {
            Button("Word Document (.docx)") {
                exportFiles(format: .docx)
            }
            Button("Rich Text Format (.rtf)") {
                exportFiles(format: .rtf)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose export format for \(filesToExport.count) file(s)")
        }
    }
    
    // MARK: - Computed Properties for Callbacks
    
    private var fileListOnSubmit: (([TextFile]) -> Void)? {
        isReadyFolder ? { files in
            filesToSubmit = files
            showSubmissionPicker = true
        } : nil
    }
    
    private var fileListOnAddToCollection: (([TextFile]) -> Void)? {
        isReadyFolder ? { files in
            filesToAddToCollection = files
            showCollectionPicker = true
        } : nil
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
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let (plainText, rtfData, filename) = try WordDocumentService.importWordDocument(from: url)
                
                // Create new text file
                let file = TextFile(name: filename, folder: folder)
                folder.addToTextFiles(file)
                
                // Create initial version with imported content
                let version = Version()
                version.content = plainText
                version.formattedContent = rtfData
                version.textFile = file
                file.addToVersions(version)
                
                modelContext.insert(file)
                
                do {
                    try modelContext.save()
                    print("✅ Imported '\(filename)' successfully")
                } catch {
                    importErrorMessage = "Failed to save imported file: \(error.localizedDescription)"
                    showImportError = true
                }
                
            } catch {
                importErrorMessage = error.localizedDescription
                showImportError = true
            }
            
        case .failure(let error):
            importErrorMessage = "Failed to access file: \(error.localizedDescription)"
            showImportError = true
        }
    }
    
    private enum ExportFormat {
        case docx
        case rtf
    }
    
    private func exportFiles(format: ExportFormat) {
        // Get the root view controller for presenting share sheet
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        // Export each file
        for file in filesToExport {
            guard let version = file.currentVersion,
                  let attributedString = version.attributedContent else {
                continue
            }
            
            switch format {
            case .docx:
                WordDocumentService.shareAsWordDocument(
                    attributedString,
                    filename: file.name,
                    from: rootViewController
                )
            case .rtf:
                WordDocumentService.shareAsRTF(
                    attributedString,
                    filename: file.name,
                    from: rootViewController
                )
            }
        }
        
        filesToExport = []
    }
    
    private func renameFile(newName: String) {
        guard let file = filesToRename.first else { return }
        
        file.name = newName
        
        do {
            try modelContext.save()
        } catch {
            print("Error renaming file: \(error)")
            // TODO: Show error alert
        }
        
        filesToRename = []
        showRenamePicker = false
    }
}