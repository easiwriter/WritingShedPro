import SwiftUI
import UniformTypeIdentifiers

extension FolderFilesView {
    
    // MARK: - Sheet Content Views
    
    @ViewBuilder
    var moveDestinationSheet: some View {
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
    
    @ViewBuilder
    var searchSheet: some View {
        MultiFileSearchView(folder: folder, files: deferredSortedFiles ?? sortedFiles)
    }
    
    @ViewBuilder
    var addFileSheetContent: some View {
        AddFileSheet(
            isPresented: $showAddFileSheet,
            parentFolder: folder,
            existingFiles: folder.textFiles ?? []
        )
    }
    
    @ViewBuilder
    var addFolderSheet: some View {
        if let project = folder.project {
            AddFolderSheet(
                isPresented: $showAddFolderSheet,
                project: project,
                parentFolder: folder,
                existingFolders: sortedSubfolders
            )
        }
    }
    
    @ViewBuilder
    var renamePickerSheet: some View {
        if let file = filesToRename.first {
            NavigationStack {
                RenameFileModal(
                    file: file,
                    filesInFolder: deferredSortedFiles ?? sortedFiles,
                    onRename: { newName in
                        renameFile(newName: newName)
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    var folderMoveDestinationSheet: some View {
        if let project = folder.project {
            FolderMoveDestinationPicker(
                project: project,
                currentFolder: folder,
                folderToMove: folderToMove,
                filesToMove: [],
                onDestinationSelected: { destination in
                    if let folderMoving = folderToMove {
                        moveSubfolder(folderMoving, to: destination)
                    }
                    showFolderMoveDestinationPicker = false
                },
                onCancel: {
                    showFolderMoveDestinationPicker = false
                }
            )
        }
    }
    
    @ViewBuilder
    var statusPickerSheet: some View {
        WorkflowStatusPickerSheet(
            files: filesToChangeStatus,
            onStatusSelected: { newStatus in
                changeFilesStatus(filesToChangeStatus, to: newStatus)
                showStatusPicker = false
            },
            onCancel: {
                showStatusPicker = false
            }
        )
    }
    
    @ViewBuilder
    var collectionPickerSheet: some View {
        if let project = folder.project {
            PoetryCollectionPickerSheet(
                project: project,
                selectedFiles: filesToAssignToCollection,
                onAssign: { collection in
                    assignFilesToCollection(filesToAssignToCollection, collection: collection)
                    showCollectionPicker = false
                },
                onCancel: {
                    showCollectionPicker = false
                }
            )
        }
    }
    
    // MARK: - Export Menu Buttons
    
    @ViewBuilder
    var exportMenuButtons: some View {
        Button {
            showExportMenu = false
            // Delay to let confirmation dialog dismiss before presenting sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showCopyToProject = true
            }
        } label: {
            Label(NSLocalizedString("export.copyToProject", comment: "Copy to Project…"), systemImage: "doc.on.doc")
        }
        Button(ExportFormat.pdf.localizedName) {
            exportFiles(format: .pdf)
        }
        Button(ExportFormat.rtf.localizedName) {
            pendingExportAction = { exportFiles(format: .rtf) }
            showImageWarningAfterDelay()
        }
        Button(ExportFormat.html.localizedName) {
            exportFiles(format: .html)
        }
        Button(ExportFormat.word.localizedName) {
            exportFiles(format: .word)
        }
        Button(ExportFormat.markdown.localizedName) {
            pendingExportAction = { exportFiles(format: .markdown) }
            showImageWarningAfterDelay()
        }
        Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
            filesToExport = []
        }
    }
    
    var exportMenuMessage: String {
        String(format: NSLocalizedString("export.dialog.message", comment: "Choose export format"), filesToExport.count)
    }
    
    @ViewBuilder
    var exportFolderMenuButtons: some View {
        Button(ExportFormat.rtf.localizedName) {
            pendingExportAction = { exportCombinedFolder(format: .rtf) }
            showImageWarningAfterDelay()
        }
        Button(ExportFormat.html.localizedName) {
            exportCombinedFolder(format: .html)
        }
        // EPUB reserved for future release
        // Button(ExportFormat.epub.localizedName) {
        //     exportCombinedFolder(format: .epub)
        // }
        Button(ExportFormat.word.localizedName) {
            exportCombinedFolder(format: .word)
        }
        Button(ExportFormat.markdown.localizedName) {
            pendingExportAction = { exportCombinedFolder(format: .markdown) }
            showImageWarningAfterDelay()
        }
        Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
            exportCombinedContent = nil
        }
    }
    
    var exportFolderMenuMessage: String {
        String(format: NSLocalizedString("export.folder.dialog.message", comment: "Export all files combined"), sortedFiles.count)
    }
    
    // MARK: - Permanent Delete
    
    var permanentDeleteMessage: String {
        if filesToPermanentlyDelete.count == 1 {
            return String(format: NSLocalizedString("folderFiles.deletePermanently.message.single", comment: "This will permanently delete the file"), filesToPermanentlyDelete.first?.name ?? "")
        } else {
            return String(format: NSLocalizedString("folderFiles.deletePermanently.message.multiple", comment: "This will permanently delete files"), filesToPermanentlyDelete.count)
        }
    }
    
    func confirmPermanentDelete() {
        deleteFilesPermanently(filesToPermanentlyDelete)
        filesToPermanentlyDelete = []
    }
    
    func cancelPermanentDelete() {
        filesToPermanentlyDelete = []
    }
    
    // MARK: - Copy to Project
    
    @ViewBuilder
    var copyToProjectSheet: some View {
        if let project = folder.project {
            CopyToProjectPickerView(
                sourceProject: project,
                filesToCopy: filesToExport,
                onProjectSelected: { destinationProject in
                    showCopyToProject = false
                    copyFilesToProject(filesToExport, destination: destinationProject)
                    filesToExport = []
                },
                onCancel: {
                    showCopyToProject = false
                    filesToExport = []
                }
            )
        }
    }
    
    /// Copy files to a destination project, placing them in the matching folder by name.
    /// Handles duplicate names by appending a numeric suffix.
    func copyFilesToProject(_ files: [TextFile], destination: Project) {
        guard !files.isEmpty else { return }
        let sourceFolderName = folder.name ?? "Files"

        do {
            let result = try TextFileCreationService.copyFiles(
                files,
                to: destination,
                matchingSourceFolderName: sourceFolderName,
                modelContext: modelContext,
                saveReason: "folder-files-sheet-save"
            )
            copyResultMessage = result.localizedMessage
            copyResultIsError = false
        } catch {
            copyResultMessage = error.localizedDescription
            copyResultIsError = true
        }
        showCopyResult = true
    }
    
    // MARK: - Header/Footer Dialog
    
    @ViewBuilder
    var headerFooterDialog: some View {
        HeaderFooterDialog(
            headerEnabled: folder.project?.pageSetup?.hasHeaders ?? false,
            footerEnabled: folder.project?.pageSetup?.hasFooters ?? false,
            headerLeft: $headerLeft,
            headerCenter: $headerCenter,
            headerRight: $headerRight,
            footerLeft: $footerLeft,
            footerCenter: $footerCenter,
            footerRight: $footerRight,
            headerInsertTarget: $headerInsertTarget,
            footerInsertTarget: $footerInsertTarget,
            showHeaderElementPicker: $showHeaderElementPicker,
            showFooterElementPicker: $showFooterElementPicker,
            isPresented: $showHeaderFooterEditor,
            headerFooterElements: headerFooterElements,
            onCancel: { showHeaderFooterEditor = false },
            onSave: { values in
                if let pageSetup = folder.project?.pageSetup {
                    pageSetup.headerLeft = values.headerLeft
                    pageSetup.headerCenter = values.headerCenter
                    pageSetup.headerRight = values.headerRight
                    pageSetup.footerLeft = values.footerLeft
                    pageSetup.footerCenter = values.footerCenter
                    pageSetup.footerRight = values.footerRight
                    folder.project?.modifiedDate = Date()
                    WriteCoalescer.shared?.requestSave(reason: "folder-files-header-footer-save")
                    WriteCoalescer.shared?.flush()
                }
                showHeaderFooterEditor = false
            }
        )
    }
    
    // MARK: - Initialize Header/Footer Fields
    
    func initializeHeaderFooterFields() {
        if let pageSetup = folder.project?.pageSetup {
            headerLeft = pageSetup.headerLeft ?? ""
            headerCenter = pageSetup.headerCenter ?? ""
            headerRight = pageSetup.headerRight ?? ""
            footerLeft = pageSetup.footerLeft ?? ""
            footerCenter = pageSetup.footerCenter ?? ""
            footerRight = pageSetup.footerRight ?? ""
        }
    }
}
