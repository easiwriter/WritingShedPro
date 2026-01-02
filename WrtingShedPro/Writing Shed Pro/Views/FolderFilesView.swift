//
//  FolderFilesView.swift
//  Writing Shed Pro
//
//  Created on 2025-11-08.
//  Feature 008a Integration: Replaces FileEditableList with FileListView
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
    
    // State for move destination picker
    @State private var showMoveDestinationPicker = false
    @State private var filesToMove: [TextFile] = []
    
    // State for add file sheet
    @State private var showAddFileSheet = false
    
    // State for add folder sheet (for mixed-content folders)
    @State private var showAddFolderSheet = false
    
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
    
    // State for folder movement (for mixed-content folders)
    @State private var showFolderMoveDestinationPicker = false
    @State private var folderToMove: Folder?
    
    // State for multi-select in mixed content view
    @State private var selectedFileIDs: Set<UUID> = []
    @State private var selectedFolderIDs: Set<UUID> = []
    
    // State for sorting in mixed content view
    @State private var fileSortOrder: FileSortOrder = .byName
    @State private var folderSortOrder: FolderSortOrder = .byName
    
    // State for Word document import
    @State private var showImportPicker = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    
    // State for export
    @State private var showExportMenu = false
    @State private var showExportFolderMenu = false
    @State private var showExportSaveDialog = false
    @State private var filesToExport: [TextFile] = []
    @State private var exportFormat: ExportFormat = .rtf
    @State private var exportData: Data?
    @State private var exportFilename: String = ""
    @State private var exportCombinedContent: NSAttributedString?
    @State private var exportAttributedStrings: [NSAttributedString] = []  // For HTML multi-file export
    @State private var showImageWarning = false  // Show warning for RTF with images
    @State private var imageWarningMessage = ""
    
    // State for search
    @State private var showSearchView = false
    
    // Files sorted alphabetically
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
        
        // Always sort alphabetically by name
        return FileSortService.sort(files, by: .byName)
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
        var seenFileIDs = Set<UUID>()
        
        for folder in projectFolders {
            if targetFolderNames.contains(folder.name ?? "") {
                for file in folder.textFiles ?? [] {
                    // Only add if we haven't seen this file ID before (deduplicate)
                    if !seenFileIDs.contains(file.id) {
                        allFiles.append(file)
                        seenFileIDs.insert(file.id)
                    }
                }
            }
        }
        
        return allFiles
    }
    
    // Check if this is the Ready folder (supports submissions)
    private var isReadyFolder: Bool {
        return folder.name == "Ready"
    }
    
    // Check if this folder supports mixed content (both files and subfolders)
    private var isMixedContentFolder: Bool {
        return FolderCapabilityService.canAddSubfolder(to: folder) && FolderCapabilityService.canAddFile(to: folder)
    }
    
    // Get subfolders sorted by current sort order
    private var sortedSubfolders: [Folder] {
        return FolderSortService.sort(folder.folders ?? [], by: folderSortOrder)
    }
    
    // Get files sorted by current sort order (for mixed content view)
    private var sortedMixedFiles: [TextFile] {
        return FileSortService.sort(folder.textFiles ?? [], by: fileSortOrder)
    }
    
    // Whether edit mode is currently active
    private var isEditMode: Bool {
        editMode == .active
    }
    
    // Selected files based on selectedFileIDs
    private var selectedFiles: [TextFile] {
        sortedFiles.filter { selectedFileIDs.contains($0.id) }
    }
    
    // Selected folders based on selectedFolderIDs
    private var selectedFolders: [Folder] {
        sortedSubfolders.filter { selectedFolderIDs.contains($0.id) }
    }
    
    // Whether bottom toolbar should be visible (edit mode + items selected)
    private var showMixedContentToolbar: Bool {
        isEditMode && (!selectedFileIDs.isEmpty || !selectedFolderIDs.isEmpty)
    }
    
    var body: some View {
        Group {
            if isMixedContentFolder {
                // Mixed content folder - show both subfolders and files
                mixedContentBody
            } else if !sortedFiles.isEmpty {
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
                    onReorder: nil,
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
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToFile) {
            if let file = selectedFile {
                FileEditView(file: file)
            }
        }
        .environment(\.editMode, $editMode)
        .onPopToRoot {
            dismiss()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PopToRootBackButton()
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Search button
                if !sortedFiles.isEmpty {
                    Button {
                        showSearchView = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search files in folder")
                    .help("Search and replace across all files")
                    .disabled(editMode == .active)
                }
                
                // Import Word document button
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
                
                // Add file button
                if FolderCapabilityService.canAddFile(to: folder) {
                    if isMixedContentFolder {
                        // Show menu with options for both file and folder
                        Menu {
                            Button {
                                showAddFileSheet = true
                            } label: {
                                Label(NSLocalizedString("folderFiles.addFile", comment: "Add File"), systemImage: "doc.badge.plus")
                            }
                            
                            Button {
                                showAddFolderSheet = true
                            } label: {
                                Label(NSLocalizedString("folderFiles.addFolder", comment: "Add Folder"), systemImage: "folder.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("folderFiles.add.accessibility")
                        .disabled(editMode == .active)
                    } else {
                        Button {
                            showAddFileSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("folderFiles.addFile.accessibility")
                        .disabled(editMode == .active)
                    }
                }
                
                // Manual Edit/Done button on far right (replaces SwiftUI's EditButton which isn't working)
                if !sortedFiles.isEmpty || (isMixedContentFolder && !sortedSubfolders.isEmpty) {
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
        .sheet(isPresented: $showSearchView) {
            MultiFileSearchView(folder: folder, files: sortedFiles)
        }
        .sheet(isPresented: $showAddFileSheet) {
            AddFileSheet(
                isPresented: $showAddFileSheet,
                parentFolder: folder,
                existingFiles: folder.textFiles ?? []
            )
        }
        .sheet(isPresented: $showAddFolderSheet) {
            if let project = folder.project {
                AddFolderSheet(
                    isPresented: $showAddFolderSheet,
                    project: project,
                    parentFolder: folder,
                    existingFolders: sortedSubfolders
                )
            }
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
        .sheet(isPresented: $showFolderMoveDestinationPicker) {
            if let project = folder.project {
                FolderMoveDestinationPicker(
                    project: project,
                    currentFolder: folder,
                    folderToMove: folderToMove,
                    filesToMove: filesToMove,
                    onDestinationSelected: { destination in
                        if let folderMoving = folderToMove {
                            moveSubfolder(folderMoving, to: destination)
                        } else {
                            moveFilesToFolder(filesToMove, to: destination)
                        }
                        showFolderMoveDestinationPicker = false
                    },
                    onCancel: {
                        showFolderMoveDestinationPicker = false
                    }
                )
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.rtf, UTType("org.openxmlformats.wordprocessingml.document") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
        .confirmationDialog(NSLocalizedString("export.dialog.title", comment: "Export Format"), isPresented: $showExportMenu) {
            Button(ExportFormat.rtf.displayName) {
                exportFiles(format: .rtf)
            }
            
            Button(ExportFormat.html.displayName) {
                exportFiles(format: .html)
            }
            
            Button(ExportFormat.epub.displayName) {
                exportFiles(format: .epub)
            }
            
            Button(ExportFormat.docx.displayName) {
                exportFiles(format: .docx)
            }
            
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                filesToExport = []
            }
        } message: {
            Text(String(format: NSLocalizedString("export.dialog.message", comment: "Choose export format"), filesToExport.count))
        }
        .confirmationDialog(NSLocalizedString("export.folder.dialog.title", comment: "Export Folder"), isPresented: $showExportFolderMenu) {
            Button(ExportFormat.rtf.displayName) {
                exportCombinedFolder(format: .rtf)
            }
            
            Button(ExportFormat.html.displayName) {
                exportCombinedFolder(format: .html)
            }
            
            Button(ExportFormat.epub.displayName) {
                exportCombinedFolder(format: .epub)
            }
            
            Button(ExportFormat.docx.displayName) {
                exportCombinedFolder(format: .docx)
            }
            
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                exportCombinedContent = nil
            }
        } message: {
            Text(String(format: NSLocalizedString("export.folder.dialog.message", comment: "Export all files combined"), sortedFiles.count))
        }
        .fileExporter(
            isPresented: $showExportSaveDialog,
            document: ExportDocument(
                data: exportData ?? Data(),
                filename: exportFilename,
                contentType: contentTypeForFormat(exportFormat)
            ),
            contentType: contentTypeForFormat(exportFormat),
            defaultFilename: exportFilename
        ) { result in
            handleExportResult(result: result)
        }
        .alert("Images Not Supported", isPresented: $showImageWarning) {
            Button("Continue Export", role: nil) {
                // Continue with export after user acknowledges the warning
                if let content = exportCombinedContent {
                    performCombinedExport(format: exportFormat, content: content)
                } else if let firstFile = filesToExport.first,
                          let version = firstFile.currentVersion,
                          let attributedString = version.attributedContent {
                    performSingleFileExport(format: exportFormat, content: attributedString, filename: firstFile.name)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(imageWarningMessage)
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
    
    // MARK: - Mixed Content View
    
    /// View for folders that support both subfolders and files
    @ViewBuilder
    private var mixedContentBody: some View {
        List {
            // Subfolders section
            if !sortedSubfolders.isEmpty {
                Section {
                    ForEach(sortedSubfolders) { subfolder in
                        mixedContentSubfolderRow(subfolder)
                    }
                    .onMove(perform: moveSubfolders)
                } header: {
                    HStack {
                        Text(NSLocalizedString("folderFiles.subfoldersHeader", comment: "Subfolders section header"))
                        Spacer()
                        if !isEditMode {
                            folderSortMenu
                        }
                    }
                }
            }
            
            // Files section
            if !sortedMixedFiles.isEmpty {
                Section {
                    ForEach(sortedMixedFiles) { file in
                        mixedContentFileRow(file)
                    }
                    .onMove(perform: moveMixedFiles)
                } header: {
                    HStack {
                        Text(NSLocalizedString("folderFiles.filesHeader", comment: "Files section header"))
                        Spacer()
                        if !isEditMode {
                            fileSortMenu
                        }
                    }
                }
            }
            
            // Empty state when both are empty
            if sortedSubfolders.isEmpty && sortedMixedFiles.isEmpty {
                ContentUnavailableView {
                    Label(NSLocalizedString("folderFiles.emptyFolder", comment: "Empty folder"), systemImage: "folder")
                } description: {
                    Text(NSLocalizedString("folderFiles.emptyFolder.hint", comment: "Empty folder hint"))
                }
            }
        }
        .environment(\.editMode, $editMode)
        .toolbar {
            // Bottom toolbar for multi-select actions (only in edit mode)
            ToolbarItemGroup(placement: .bottomBar) {
                if showMixedContentToolbar {
                    mixedContentBottomToolbar
                }
            }
        }
        .onChange(of: editMode) { _, newValue in
            if newValue == .inactive {
                // Clear selection when exiting edit mode
                selectedFileIDs.removeAll()
                selectedFolderIDs.removeAll()
            }
        }
    }
    
    /// Sort menu for folders section
    @ViewBuilder
    private var folderSortMenu: some View {
        Menu {
            ForEach(FolderSortService.sortOptions(), id: \.order) { option in
                Button {
                    folderSortOrder = option.order
                } label: {
                    HStack {
                        Text(option.title)
                        if folderSortOrder == option.order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    /// Sort menu for files section
    @ViewBuilder
    private var fileSortMenu: some View {
        Menu {
            ForEach(FileSortService.sortOptions(), id: \.order) { option in
                Button {
                    fileSortOrder = option.order
                } label: {
                    HStack {
                        Text(option.title)
                        if fileSortOrder == option.order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    /// Row for a subfolder in mixed content view - supports edit mode selection
    @ViewBuilder
    private func mixedContentSubfolderRow(_ subfolder: Folder) -> some View {
        HStack {
            // Selection circle in edit mode - tappable to toggle selection
            if isEditMode {
                Button {
                    toggleFolderSelection(subfolder)
                } label: {
                    Image(systemName: selectedFolderIDs.contains(subfolder.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedFolderIDs.contains(subfolder.id) ? .blue : .gray)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            
            // Main content - NavigationLink works in both modes
            NavigationLink(destination: FolderFilesView(folder: subfolder)) {
                Label(subfolder.name ?? NSLocalizedString("folderList.untitledFolder", comment: "Untitled folder"), systemImage: "folder")
            }
        }
        .contextMenu {
            Button {
                folderToMove = subfolder
                showFolderMoveDestinationPicker = true
            } label: {
                Label(NSLocalizedString("folderFiles.moveToFolder", comment: "Move to Folder"), systemImage: "folder")
            }
            
            Divider()
            
            Button(role: .destructive) {
                deleteSubfolder(subfolder)
            } label: {
                Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isEditMode {
                Button(role: .destructive) {
                    deleteSubfolder(subfolder)
                } label: {
                    Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
                }
            }
        }
    }
    
    /// Row for a file in mixed content view - supports edit mode selection
    @ViewBuilder
    private func mixedContentFileRow(_ file: TextFile) -> some View {
        HStack {
            // Selection circle in edit mode - tappable to toggle selection
            if isEditMode {
                Button {
                    toggleFileSelection(file)
                } label: {
                    Image(systemName: selectedFileIDs.contains(file.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedFileIDs.contains(file.id) ? .blue : .gray)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            
            // Main content - tappable for navigation
            Button {
                selectedFile = file
                navigateToFile = true
            } label: {
                HStack {
                    Label(file.name.isEmpty ? NSLocalizedString("folderFiles.untitledFile", comment: "Untitled file") : file.name, systemImage: "doc.text")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
        .contextMenu {
            Button {
                folderToMove = nil  // Moving files, not folder
                filesToMove = [file]
                showFolderMoveDestinationPicker = true
            } label: {
                Label(NSLocalizedString("folderFiles.moveToFolder", comment: "Move to Folder"), systemImage: "folder")
            }
            
            Divider()
            
            Button(role: .destructive) {
                deleteFiles([file])
            } label: {
                Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isEditMode {
                Button(role: .destructive) {
                    deleteFiles([file])
                } label: {
                    Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
                }
            }
        }
    }
    
    /// Bottom toolbar for mixed content multi-select actions
    @ViewBuilder
    private var mixedContentBottomToolbar: some View {
        let totalSelected = selectedFileIDs.count + selectedFolderIDs.count
        
        // Move button with count
        Button {
            // Move selected files and folders
            filesToMove = selectedFiles
            if let firstFolder = selectedFolders.first {
                folderToMove = firstFolder
            }
            showFolderMoveDestinationPicker = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                Text("(\(totalSelected))")
                    .font(.caption)
            }
        }
        .disabled(totalSelected == 0)
        .accessibilityLabel(String(format: NSLocalizedString("fileList.moveCount", comment: "Move count"), totalSelected))
        
        Spacer()
        
        // Deselect all button
        Button {
            selectedFileIDs.removeAll()
            selectedFolderIDs.removeAll()
        } label: {
            Image(systemName: "circle.slash")
        }
        .disabled(totalSelected == 0)
        .accessibilityLabel(NSLocalizedString("fileList.deselectAll", comment: "Deselect all"))
        
        Spacer()
        
        // Trash button
        Button(role: .destructive) {
            // Delete selected files and folders
            for subfolder in selectedFolders {
                deleteSubfolder(subfolder)
            }
            deleteFiles(selectedFiles)
            selectedFileIDs.removeAll()
            selectedFolderIDs.removeAll()
            editMode = .inactive
        } label: {
            Image(systemName: "trash")
        }
        .disabled(totalSelected == 0)
        .accessibilityLabel(String(format: NSLocalizedString("fileList.deleteCount", comment: "Delete count"), totalSelected))
    }
    
    /// Toggle file selection
    private func toggleFileSelection(_ file: TextFile) {
        if selectedFileIDs.contains(file.id) {
            selectedFileIDs.remove(file.id)
        } else {
            selectedFileIDs.insert(file.id)
        }
    }
    
    /// Toggle folder selection
    private func toggleFolderSelection(_ folder: Folder) {
        if selectedFolderIDs.contains(folder.id) {
            selectedFolderIDs.remove(folder.id)
        } else {
            selectedFolderIDs.insert(folder.id)
        }
    }
    
    /// Move subfolders for drag-to-reorder (updates userOrder)
    private func moveSubfolders(from source: IndexSet, to destination: Int) {
        var folders = sortedSubfolders
        folders.move(fromOffsets: source, toOffset: destination)
        
        // Update userOrder for all folders
        for (index, folder) in folders.enumerated() {
            folder.userOrder = index
        }
        
        // Switch to user order sorting to show the new order
        folderSortOrder = .byUserOrder
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error saving folder order: \(error)")
            #endif
        }
    }
    
    /// Move files for drag-to-reorder (updates userOrder)
    private func moveMixedFiles(from source: IndexSet, to destination: Int) {
        var files = sortedMixedFiles
        files.move(fromOffsets: source, toOffset: destination)
        
        // Update userOrder for all files
        for (index, file) in files.enumerated() {
            file.userOrder = index
        }
        
        // Switch to user order sorting to show the new order
        fileSortOrder = .byUserOrder
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error saving file order: \(error)")
            #endif
        }
    }
    
    /// Delete a single subfolder
    private func deleteSubfolder(_ subfolder: Folder) {
        modelContext.delete(subfolder)
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error deleting subfolder: \(error)")
            #endif
        }
    }
    
    // MARK: - Actions
    
    private func deleteFiles(_ files: [TextFile]) {
        let service = FileMoveService(modelContext: modelContext)
        
        do {
            try service.deleteFiles(files)
        } catch {
            #if DEBUG
            print("Error deleting files: \(error)")
            #endif
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
            #if DEBUG
            print("Error moving files: \(error)")
            #endif
            // TODO: Show error alert
        }
    }
    
    /// Move a subfolder to a new destination folder
    private func moveSubfolder(_ subfolder: Folder, to destination: Folder) {
        let service = FileMoveService(modelContext: modelContext)
        
        do {
            try service.moveFolder(subfolder, to: destination)
            folderToMove = nil
        } catch {
            #if DEBUG
            print("Error moving folder: \(error)")
            #endif
            // TODO: Show error alert
        }
    }
    
    /// Move files to a destination folder (for General Purpose mixed content folders)
    private func moveFilesToFolder(_ files: [TextFile], to destination: Folder) {
        let service = FileMoveService(modelContext: modelContext)
        
        do {
            try service.moveFiles(files, to: destination)
            filesToMove = []
        } catch {
            #if DEBUG
            print("Error moving files to folder: \(error)")
            #endif
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
            #if DEBUG
            print("Error adding files to collection: \(error)")
            #endif
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
                
                // Create new text file with initial empty content
                let file = TextFile(name: filename, initialContent: "", parentFolder: folder)
                
                // Update the first version with imported content
                if let firstVersion = file.versions?.first {
                    firstVersion.content = plainText
                    firstVersion.formattedContent = rtfData
                    // Version uses createdDate, not modifiedDate
                }
                
                file.modifiedDate = Date()
                
                // Insert and save immediately
                modelContext.insert(file)
                
                do {
                    try modelContext.save()
                    
                    #if DEBUG
                    print("✅ Imported '\(filename)' successfully")
                    #if DEBUG
                    print("   File ID: \(file.id)")
                    #endif
                    #if DEBUG
                    print("   Version count: \(file.versions?.count ?? 0)")
                    #endif
                    #endif
                    
                    // CRITICAL: Process pending changes to avoid "store went missing" error
                    // This ensures SwiftData has fully committed the object before CloudKit sync
                    modelContext.processPendingChanges()
                    
                } catch {
                    // If save fails, remove the file from context
                    modelContext.delete(file)
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
        case rtf
        case html
        case epub
        case docx
        
        var fileExtension: String {
            switch self {
            case .rtf: return "rtf"
            case .html: return "html"
            case .epub: return "epub"
            case .docx: return "docx"
            }
        }
        
        var displayName: String {
            switch self {
            case .rtf: return NSLocalizedString("export.format.rtf", comment: "RTF (Word-compatible)")
            case .html: return NSLocalizedString("export.format.html", comment: "HTML (Web page)")
            case .epub: return NSLocalizedString("export.format.epub", comment: "EPUB (eBook)")
            case .docx: return NSLocalizedString("export.format.docx", comment: "DOCX (Word format)")
            }
        }
    }
    
    private func exportCompleteFolder() {
        // Collect all file contents as separate attributed strings (for HTML)
        var attributedStrings: [NSAttributedString] = []
        
        // Also create combined content for RTF/EPUB
        let combinedContent = NSMutableAttributedString()
        
        for (index, file) in sortedFiles.enumerated() {
            guard let version = file.currentVersion,
                  let attributedString = version.attributedContent else {
                continue
            }
            
            #if DEBUG
            // Check if this attributed string contains images
            var imageCount = 0
            attributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedString.length)) { value, _, _ in
                if value is ImageAttachment {
                    imageCount += 1
                }
            }
            #if DEBUG
            print("📄 FolderFilesView: File \(index + 1) '\(file.name)' has \(imageCount) images in attributedContent")
            #endif
            #endif
            
            // Store individual attributed string for HTML export
            attributedStrings.append(attributedString)
            
            // Don't add title heading - the content already has it
            // Just add the file content directly
            combinedContent.append(attributedString)
            
            // Add page break after each file (including last file) for RTF/EPUB
            let pageBreak = NSAttributedString(string: "\u{000C}")
            combinedContent.append(pageBreak)
        }
        
        // Store both formats for export
        exportAttributedStrings = attributedStrings
        exportCombinedContent = combinedContent
        // Use the project name for the exported file, not the folder name
        exportFilename = folder.project?.name ?? folder.name ?? "Project"
        
        // Show format selection dialog
        showExportFolderMenu = true
    }
    
    private func exportCombinedFolder(format: ExportFormat) {
        // ALWAYS print, not just in DEBUG
        #if DEBUG
        print("📁 exportCombinedFolder() called with format: \(format)")
        #endif
        #if DEBUG
        print("📁 exportAttributedStrings count: \(exportAttributedStrings.count)")
        #endif
        #if DEBUG
        print("📁 exportCombinedContent length: \(exportCombinedContent?.length ?? 0)")
        #endif
        
        // Set the export format
        self.exportFormat = format
        
        guard let combinedContent = exportCombinedContent else {
            #if DEBUG
            print("❌ exportCombinedContent is nil!")
            #endif
            return
        }
        
        // Check for images in RTF export
        if format == .rtf && RTFImageEncoder.containsImages(combinedContent) {
            imageWarningMessage = "RTF format does not support embedded images. Images will be replaced with '[Image omitted]' placeholders. For documents with images, please use HTML or EPUB export instead."
            showImageWarning = true
            // Don't proceed with export yet - wait for user to dismiss alert
            return
        }
        
        // Perform the actual export
        performCombinedExport(format: format, content: combinedContent)
    }
    
    private func performCombinedExport(format: ExportFormat, content: NSAttributedString) {
        // Run export in background to keep UI responsive
        Task {
            do {
                #if DEBUG
                print("📁 About to call export service for format: \(format)")
                #endif
                
                // Capture array locally to avoid main actor isolation issues
                let attributedStrings = exportAttributedStrings
                let filename = exportFilename
                
                let data: Data
                
                switch format {
                case .rtf:
                    // Use the array version for RTF to respect page break preferences
                    data = try await Task.detached {
                        try WordDocumentService.exportMultipleToRTF(attributedStrings, filename: filename)
                    }.value
                case .html:
                    // Use the array version for HTML to preserve page breaks and prevent CSS conflicts
                    #if DEBUG
                    print("📁 Calling HTMLExportService.exportMultipleToHTMLData with \(attributedStrings.count) strings")
                    #endif
                    data = try await Task.detached {
                        try HTMLExportService.exportMultipleToHTMLData(attributedStrings, filename: filename)
                    }.value
                case .epub:
                    // Use the array version for EPUB to preserve page breaks and prevent CSS conflicts
                    data = try await Task.detached {
                        try EPUBExportService.exportMultipleToEPUB(attributedStrings, filename: filename)
                    }.value
                case .docx:
                    // Export to DOCX using DOCXExportService - use array version for page breaks
                    data = try await Task.detached { [weak modelContext] in
                        guard let modelContext = modelContext else {
                            throw DOCXExportError.noContent
                        }
                        let exportService = DOCXExportService(modelContext: modelContext)
                        return try exportService.exportMultipleToDOCX(attributedStrings, filename: filename)
                    }.value
                }
                
                await MainActor.run {
                    exportData = data
                    showExportSaveDialog = true
                }
                
            } catch {
                await MainActor.run {
                    importErrorMessage = NSLocalizedString("export.error.failed", comment: "Export failed") + ": \(error.localizedDescription)"
                    showImportError = true
                }
            }
        }
    }
    
    private func exportFiles(format: ExportFormat) {
        // Set the export format
        self.exportFormat = format
        
        // If multiple files, export them one at a time
        guard let firstFile = filesToExport.first,
              let version = firstFile.currentVersion,
              let attributedString = version.attributedContent else {
            filesToExport = []
            return
        }
        
        // Check for images in RTF export
        if format == .rtf && RTFImageEncoder.containsImages(attributedString) {
            imageWarningMessage = "RTF format does not support embedded images. Images will be replaced with '[Image omitted]' placeholders. For documents with images, please use HTML or EPUB export instead."
            showImageWarning = true
            // Don't proceed with export yet - wait for user to dismiss alert
            return
        }
        
        // Perform the actual export
        performSingleFileExport(format: format, content: attributedString, filename: firstFile.name)
    }
    
    private func performSingleFileExport(format: ExportFormat, content: NSAttributedString, filename: String) {
        // Prepare export data based on format
        do {
            switch format {
            case .rtf:
                exportData = try WordDocumentService.exportToRTF(content, filename: filename)
            case .html:
                exportData = try HTMLExportService.exportToHTMLData(content, filename: filename)
            case .epub:
                exportData = try EPUBExportService.exportToEPUB(content, filename: filename)
            case .docx:
                // Export to DOCX using DOCXExportService
                let exportService = DOCXExportService(modelContext: modelContext)
                exportData = try exportService.exportToDOCX(content, filename: filename)
            }
            
            exportFilename = filename
            showExportSaveDialog = true
            
        } catch {
            importErrorMessage = NSLocalizedString("export.error.failed", comment: "Export failed") + ": \(error.localizedDescription)"
            showImportError = true
            filesToExport = []
        }
    }
    
    private func handleExportResult(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            #if DEBUG
            print("✅ Exported to: \(url.path)")
            #endif
            // Remove the first file and continue with remaining files if any
            if !filesToExport.isEmpty {
                filesToExport.removeFirst()
                if !filesToExport.isEmpty {
                    // Export next file
                    exportFiles(format: exportFormat)
                }
            }
        case .failure(let error):
            #if DEBUG
            print("❌ Export failed: \(error.localizedDescription)")
            #endif
            filesToExport = []
        }
    }
    
    private func contentTypeForFormat(_ format: ExportFormat) -> UTType {
        switch format {
        case .rtf:
            return .rtf
        case .html:
            return .html
        case .epub:
            // EPUB uses a custom UTType
            return UTType(filenameExtension: "epub") ?? .data
        case .docx:
            // DOCX uses the official UTType identifier
            return UTType("org.openxmlformats.wordprocessingml.document") ?? .data
        }
    }
    
    private func renameFile(newName: String) {
        guard let file = filesToRename.first else { return }
        
        file.name = newName
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error renaming file: \(error)")
            #endif
            // TODO: Show error alert
        }
        
        filesToRename = []
        showRenamePicker = false
    }
}

// MARK: - Export Document Type

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { 
        [.rtf, .html, UTType(filenameExtension: "epub") ?? .data, UTType("org.openxmlformats.wordprocessingml.document") ?? .data, .data] 
    }
    
    static var writableContentTypes: [UTType] { 
        [.rtf, .html, UTType(filenameExtension: "epub") ?? .data, UTType("org.openxmlformats.wordprocessingml.document") ?? .data, .data] 
    }
    
    var data: Data
    var filename: String
    var contentType: UTType
    
    init(data: Data, filename: String, contentType: UTType = .rtf) {
        self.data = data
        self.filename = filename
        self.contentType = contentType
    }
    
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        filename = ""
        contentType = .data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}
