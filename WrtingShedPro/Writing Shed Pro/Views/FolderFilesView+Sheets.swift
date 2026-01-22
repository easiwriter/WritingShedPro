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
        MultiFileSearchView(folder: folder, files: sortedFiles)
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
    var submissionPickerSheet: some View {
        if let project = folder.project {
            NavigationStack {
                SubmissionPickerView(
                    project: project,
                    filesToSubmit: filesToSubmit,
                    collectionToSubmit: nil,
                    onPublicationSelected: { publication, name in
                        createSubmission(for: publication, name: name)
                        showSubmissionPicker = false
                    },
                    onCancel: {
                        showSubmissionPicker = false
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    var collectionPickerSheet: some View {
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
    
    @ViewBuilder
    var renamePickerSheet: some View {
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
    
    // MARK: - Export Menu Buttons
    
    @ViewBuilder
    var exportMenuButtons: some View {
        Button(ExportFormat.rtf.localizedName) {
            exportFiles(format: .rtf)
        }
        Button(ExportFormat.html.localizedName) {
            exportFiles(format: .html)
        }
        Button(ExportFormat.epub.localizedName) {
            exportFiles(format: .epub)
        }
        Button(ExportFormat.word.localizedName) {
            exportFiles(format: .word)
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
            exportCombinedFolder(format: .rtf)
        }
        Button(ExportFormat.html.localizedName) {
            exportCombinedFolder(format: .html)
        }
        Button(ExportFormat.epub.localizedName) {
            exportCombinedFolder(format: .epub)
        }
        Button(ExportFormat.word.localizedName) {
            exportCombinedFolder(format: .word)
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
    
    // MARK: - Image Warning Continue
    
    func continueExportAfterImageWarning() {
        if let content = exportCombinedContent {
            performCombinedExport(format: exportFormat, content: content)
        } else if let firstFile = filesToExport.first,
                  let version = firstFile.currentVersion,
                  let attributedString = version.attributedContent {
            performSingleFileExport(format: exportFormat, content: attributedString, filename: firstFile.name)
        }
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
            headerFooterElements: headerFooterElements,
            onCancel: { showHeaderFooterEditor = false },
            onSave: {
                if let pageSetup = folder.project?.pageSetup {
                    pageSetup.headerLeft = headerLeft
                    pageSetup.headerCenter = headerCenter
                    pageSetup.headerRight = headerRight
                    pageSetup.footerLeft = footerLeft
                    pageSetup.footerCenter = footerCenter
                    pageSetup.footerRight = footerRight
                    try? modelContext.save()
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
