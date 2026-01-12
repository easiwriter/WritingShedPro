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
    
    // Query all files (lazily loaded by SwiftData)
    @Query(sort: [SortDescriptor(\TextFile.name, order: .forward)]) var allTextFiles: [TextFile]
    
    // State for edit mode (shared with FileListView)
    @State var editMode: EditMode = .inactive
    
    // State for add file sheet
    @State var showAddFileSheet = false
    
    // State for add folder sheet (for mixed-content folders)
    @State var showAddFolderSheet = false
    
    // State for navigation
    @State private var selectedFile: TextFile?
    @State private var navigateToFile = false
    
    // State for submission picker
    @State var showSubmissionPicker = false
    @State var filesToSubmit: [TextFile] = []
    
    // State for collection picker
    @State var showCollectionPicker = false
    @State var filesToAddToCollection: [TextFile] = []
    
    // State for rename
    @State var showRenamePicker = false
    @State var filesToRename: [TextFile] = []
    
    // State for folder movement (for mixed-content folders)
    @State var showFolderMoveDestinationPicker = false
    @State var folderToMove: Folder?
    
    // State for multi-select in mixed content view
    @State var selectedFileIDs: Set<UUID> = []
    @State var selectedFolderIDs: Set<UUID> = []
    
    // State for sorting in mixed content view
    @State var fileSortOrder: FileSortOrder = .byName
    @State var folderSortOrder: FolderSortOrder = .byName
    
    // State for Word document import
    @State var showImportPicker = false
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
    @State var showSearchView = false
    
    // State for header/footer editor
    @State var showHeaderFooterEditor = false
    @State private var headerLeft: String = ""
    @State private var headerCenter: String = ""
    @State private var headerRight: String = ""
    @State private var footerLeft: String = ""
    @State private var footerCenter: String = ""
    @State private var footerRight: String = ""
    @State private var headerInsertTarget: HeaderFooterField = .none
    @State private var footerInsertTarget: HeaderFooterField = .none
    @State private var showHeaderElementPicker = false
    @State private var showFooterElementPicker = false
    
    // Available elements for header/footer insertion
    private var headerFooterElements: [String] {
        ["Page Number", "Total Pages", "Date", "Time", "Title", "Author"]
    }
    
    // State for permanent delete confirmation
    @State private var showPermanentDeleteConfirmation = false
    @State private var filesToPermanentlyDelete: [TextFile] = []
    
    // State for workflow status filtering (for Poems, Scenes, Scripts folders)
    @State var statusFilter: WorkflowStatus? = nil  // nil = show all
    
    // State for status change sheet
    @State var showStatusPicker = false
    @State var filesToChangeStatus: [TextFile] = []
    
    // State for file movement (General Purpose projects only)
    @State var showMoveDestinationPicker = false
    @State var filesToMove: [TextFile] = []
    
    // Computed properties moved to FolderFilesView+Helpers.swift
    
    // MARK: - File List View (extracted to reduce body complexity)
    @ViewBuilder
    private var fileListSection: some View {
        FileListView(
            files: sortedFiles,
            onFileSelected: handleFileSelected,
            onMove: isGeneralPurposeProject ? handleMove : nil,
            onDelete: deleteFiles,
            onExport: handleExport,
            onSubmit: fileListOnSubmit,
            onAddToCollection: fileListOnAddToCollection,
            onReorder: nil,
            onRename: handleRename,
            onDeletePermanently: deleteFilesPermanently,
            onChangeStatus: isContentFolder ? handleChangeStatus : nil
        )
    }
    
    private func handleFileSelected(_ file: TextFile) {
        selectedFile = file
        navigateToFile = true
    }
    
    private func handleMove(_ files: [TextFile]) {
        filesToMove = files
        showMoveDestinationPicker = true
    }
    
    private func handleExport(_ files: [TextFile]) {
        filesToExport = files
        showExportMenu = true
    }
    
    private func handleRename(_ files: [TextFile]) {
        filesToRename = files
        showRenamePicker = true
    }
    
    private func handleChangeStatus(_ files: [TextFile]) {
        filesToChangeStatus = files
        showStatusPicker = true
    }
    
    @ViewBuilder
    private var navigationDestinationContent: some View {
        if let file = selectedFile {
            if let project = folder.project, project.type == .drama,
               FolderCapabilityService.isContentFolder(folder) {
                DramaSceneEditorView(file: file, project: project)
            } else {
                FileEditView(file: file)
            }
        }
    }
    
    var body: some View {
        mainContent
            .navigationTitle(folder.name ?? "Files")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $navigateToFile) {
                navigationDestinationContent
            }
            .environment(\.editMode, $editMode)
            .onPopToRoot { dismiss() }
            .toolbar { folderToolbar }
            .sheet(isPresented: $showMoveDestinationPicker) { moveDestinationSheet }
            .sheet(isPresented: $showSearchView) { searchSheet }
            .sheet(isPresented: $showAddFileSheet) { addFileSheetContent }
            .sheet(isPresented: $showAddFolderSheet) { addFolderSheet }
            .sheet(isPresented: $showSubmissionPicker) { submissionPickerSheet }
            .sheet(isPresented: $showCollectionPicker) { collectionPickerSheet }
            .sheet(isPresented: $showRenamePicker) { renamePickerSheet }
            .sheet(isPresented: $showFolderMoveDestinationPicker) { folderMoveDestinationSheet }
            .sheet(isPresented: $showStatusPicker) { statusPickerSheet }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.rtf, UTType("org.openxmlformats.wordprocessingml.document") ?? .data],
                allowsMultipleSelection: false,
                onCompletion: handleImport
            )
            .fileExporter(
                isPresented: $showExportSaveDialog,
                document: ExportDocument(data: exportData ?? Data(), filename: exportFilename, contentType: contentTypeForFormat(exportFormat)),
                contentType: contentTypeForFormat(exportFormat),
                defaultFilename: exportFilename,
                onCompletion: handleExportResult
            )
            .alert("Import Failed", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: { Text(importErrorMessage) }
            .alert("Images Not Supported", isPresented: $showImageWarning) {
                Button("Continue Export") { continueExportAfterImageWarning() }
                Button("Cancel", role: .cancel) { }
            } message: { Text(imageWarningMessage) }
            .confirmationDialog(
                NSLocalizedString("folderFiles.deletePermanently.title", comment: "Delete Permanently"),
                isPresented: $showPermanentDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("folderFiles.deletePermanently.confirm", comment: ""), role: .destructive) { confirmPermanentDelete() }
                Button(NSLocalizedString("button.cancel", comment: ""), role: .cancel) { cancelPermanentDelete() }
            } message: { Text(permanentDeleteMessage) }
            .confirmationDialog(NSLocalizedString("export.dialog.title", comment: ""), isPresented: $showExportMenu) {
                exportMenuButtons
            } message: { Text(exportMenuMessage) }
            .confirmationDialog(NSLocalizedString("export.folder.dialog.title", comment: ""), isPresented: $showExportFolderMenu) {
                exportFolderMenuButtons
            } message: { Text(exportFolderMenuMessage) }
            .dialog(isPresented: $showHeaderFooterEditor) { headerFooterDialog }
            .onAppear { initializeHeaderFooterFields() }
    }
    
    // MARK: - Main Content (extracted to reduce body complexity)
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            if isContentFolder {
                workflowStatusFilter
            }
            Group {
                if isMixedContentFolder {
                    mixedContentBody
                } else if !sortedFiles.isEmpty {
                    fileListSection
                } else {
                    ContentUnavailableView {
                        Label("folderFiles.noFiles", systemImage: "doc.text")
                    } description: {
                        Text("folderFiles.noFiles.hint")
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties for Callbacks
    
    private var fileListOnSubmit: (([TextFile]) -> Void)? {
        supportsSubmissions ? { files in
            filesToSubmit = files
            showSubmissionPicker = true
        } : nil
    }
    
    private var fileListOnAddToCollection: (([TextFile]) -> Void)? {
        supportsAddToCollection ? { files in
            filesToAddToCollection = files
            showCollectionPicker = true
        } : nil
    }
    
    // MARK: - Workflow Status Filter
    
    /// Segmented control for filtering files by workflow status
    @ViewBuilder
    private var workflowStatusFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" option with count
                workflowStatusButton(nil, label: NSLocalizedString("workflow.filter.all", comment: "All"), count: fileCount(for: nil))
                
                // Individual status options with counts
                ForEach(WorkflowStatus.allCases, id: \.self) { status in
                    workflowStatusButton(status, label: status.localizedName, count: fileCount(for: status))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    @ViewBuilder
    private func workflowStatusButton(_ status: WorkflowStatus?, label: String, count: Int) -> some View {
        let isSelected = statusFilter == status
        let statusColor: Color = status.map { Color($0.color) } ?? .primary
        
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                statusFilter = status
            }
        } label: {
            Text("\(label) (\(count))")
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? statusColor.opacity(0.2) : Color(.secondarySystemGroupedBackground))
                .foregroundColor(statusColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(statusColor, lineWidth: isSelected ? 2 : 0)
                )
        }
        .buttonStyle(.plain)
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
            Button(role: .destructive) {
                deleteFiles([file])
            } label: {
                Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
            }
            
            Button(role: .destructive) {
                filesToPermanentlyDelete = [file]
                showPermanentDeleteConfirmation = true
            } label: {
                Label(NSLocalizedString("folderFiles.deletePermanently", comment: "Delete Forever"), systemImage: "trash.slash")
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
        let filesOnlySelected = !selectedFileIDs.isEmpty && selectedFolderIDs.isEmpty
        
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
        
        // Submit button (only when files selected, no folders)
        if filesOnlySelected {
            Button {
                filesToSubmit = selectedFiles
                showSubmissionPicker = true
            } label: {
                Image(systemName: "paperplane")
            }
            .accessibilityLabel(NSLocalizedString("fileList.submit", comment: "Submit files"))
            
            Spacer()
        }
        
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
    
    private func deleteFilesPermanently(_ files: [TextFile]) {
        let service = FileMoveService(modelContext: modelContext)
        
        do {
            try service.deleteFilesPermanently(files)
        } catch {
            #if DEBUG
            print("Error permanently deleting files: \(error)")
            #endif
            // TODO: Show error alert
        }
    }
    
    /// Change the workflow status of files
    /// Also resets submission status when changing away from published
    func changeFilesStatus(_ files: [TextFile], to newStatus: WorkflowStatus) {
        for file in files {
            let wasPublished = file.workflowStatus == .published
            file.workflowStatus = newStatus
            
            // If changing away from published, reset any accepted submission records to pending
            if wasPublished && newStatus != .published {
                resetSubmissionStatus(for: file)
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error changing file status: \(error)")
            #endif
        }
    }
    
    /// Reset submission status for a file when it's no longer published
    private func resetSubmissionStatus(for file: TextFile) {
        // Get all SubmittedFile records for this file
        let fileId = file.id
        let descriptor = FetchDescriptor<SubmittedFile>(
            predicate: #Predicate { submittedFile in
                submittedFile.textFile?.id == fileId
            }
        )
        
        do {
            let submittedFiles = try modelContext.fetch(descriptor)
            for submittedFile in submittedFiles {
                if submittedFile.status == .accepted {
                    submittedFile.status = .pending
                    submittedFile.statusDate = Date()
                }
            }
        } catch {
            #if DEBUG
            print("Error resetting submission status: \(error)")
            #endif
        }
    }
    
    /// Move files to a destination folder (General Purpose projects only)
    func moveFiles(to destination: Folder) {
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
    func moveSubfolder(_ subfolder: Folder, to destination: Folder) {
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
    
    func createSubmission(for publication: Publication, name: String) {
        guard let project = folder.project else { return }
        
        // Create submission
        let submission = Submission(
            publication: publication,
            project: project,
            submittedDate: Date(),
            notes: nil
        )
        submission.name = name
        submission.isCollection = false  // This is a submission to a publication
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
        
        // Clear selection after submission
        selectedFileIDs.removeAll()
        editMode = .inactive
        filesToSubmit = []
    }
    
    func addFilesToCollection(_ collection: Submission) {
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
                
                // Set default workflow status for imported files
                file.workflowStatus = .draft
                
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
    
    // Uses ExportFormat from ManuscriptModels.swift
    
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
                case .word:
                    // Export to DOCX using DOCXExportService - use array version for page breaks
                    data = try await Task.detached { [weak modelContext] in
                        guard let modelContext = modelContext else {
                            throw DOCXExportError.noContent
                        }
                        let exportService = DOCXExportService(modelContext: modelContext)
                        return try exportService.exportMultipleToDOCX(attributedStrings, filename: filename)
                    }.value
                case .pdf, .plainText:
                    // Not supported for combined folder export
                    return
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
            case .word:
                // Export to DOCX using DOCXExportService
                let exportService = DOCXExportService(modelContext: modelContext)
                exportData = try exportService.exportToDOCX(content, filename: filename)
            case .pdf, .plainText:
                // Not supported for single file export from this view
                return
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
        case .word:
            // DOCX uses the official UTType identifier
            return UTType("org.openxmlformats.wordprocessingml.document") ?? .data
        case .pdf:
            return .pdf
        case .plainText:
            return .plainText
        }
    }
    
    func renameFile(newName: String) {
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
