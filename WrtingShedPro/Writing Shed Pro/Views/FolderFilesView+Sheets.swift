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
        
        // Find the matching folder in the destination project
        let sourceFolderName = folder.name ?? "Files"
        let destinationFolder = findMatchingFolder(in: destination, named: sourceFolderName)
        
        guard let destFolder = destinationFolder else {
            copyResultMessage = String(format: NSLocalizedString("copyToProject.error.noFolder", comment: "No matching folder found"), sourceFolderName, destination.name ?? "")
            copyResultIsError = true
            showCopyResult = true
            return
        }
        
        // Collect all existing names in the destination (including names assigned to earlier copies in this batch)
        var usedNames = Set((destFolder.textFiles ?? []).map { $0.name })
        var copiedCount = 0
        let maxSceneOrder = (destination.type == .fiction || destination.type == .drama)
            ? (destination.scenes ?? []).filter({ !$0.isTrashed }).compactMap(\.userOrder).max() ?? -1
            : 0
        
        for file in files {
            guard let currentVersion = file.currentVersion else { continue }
            
            // Generate a unique name in the destination
            let uniqueName = generateUniqueName(for: file.name, usedNames: usedNames)
            usedNames.insert(uniqueName)
            
            // Create the new TextFile
            let newFile = TextFile(
                name: uniqueName,
                initialContent: currentVersion.content,
                parentFolder: destFolder,
                poetryFormId: file.poetryFormId,
                poetryFormName: file.poetryFormName
            )
            
            // Preserve workflow status
            newFile.workflowStatusRaw = file.workflowStatusRaw
            
            // Preserve content type
            newFile.contentTypeRaw = file.contentTypeRaw
            
            // Copy formatted content (rich text data) to the new version
            if let formattedData = currentVersion.formattedContent,
               let newVersion = newFile.currentVersion {
                newVersion.formattedContent = formattedData
            }
            
            // Copy reference metadata if present
            if let refMetadata = currentVersion.referenceMetadataData,
               let newVersion = newFile.currentVersion {
                newVersion.referenceMetadataData = refMetadata
            }
            
            // Set userOrder to end of destination folder
            let maxOrder = (destFolder.textFiles ?? []).compactMap { $0.userOrder }.max() ?? -1
            newFile.userOrder = maxOrder + 1 + copiedCount
            
            modelContext.insert(newFile)
            
            // For Fiction/Drama projects, create a StoryScene linked to the TextFile
            if destination.type == .fiction || destination.type == .drama {
                let scene = StoryScene(name: uniqueName, userOrder: maxSceneOrder + 1 + copiedCount)
                scene.project = destination
                scene.textFile = newFile
                modelContext.insert(scene)
            }
            
            copiedCount += 1
        }
        
        do {
            try modelContext.save()
            let format = copiedCount == 1
                ? NSLocalizedString("copyToProject.success.single", comment: "1 file copied")
                : NSLocalizedString("copyToProject.success.multiple", comment: "%d files copied")
            copyResultMessage = String(format: format, copiedCount) + " " + String(format: NSLocalizedString("copyToProject.success.destination", comment: "to project"), destination.name ?? "")
            copyResultIsError = false
            showCopyResult = true
        } catch {
            copyResultMessage = NSLocalizedString("copyToProject.error.saveFailed", comment: "Save failed") + ": \(error.localizedDescription)"
            copyResultIsError = true
            showCopyResult = true
        }
    }
    
    /// Find a folder in the destination project with the same name as the source folder.
    /// Falls back to the first content folder if no exact match.
    private func findMatchingFolder(in project: Project, named sourceName: String) -> Folder? {
        guard let folders = project.folders else { return nil }
        
        // Try exact name match first
        if let match = folders.first(where: { $0.name == sourceName }) {
            return match
        }
        
        // Fall back to the first content folder (Poems, Scenes, Scripts, etc.)
        let contentFolderNames: Set<String> = ["Poems", "Scenes", "Stories", "Episodes", "Scripts", "Sections", "Prose"]
        if let contentFolder = folders.first(where: { contentFolderNames.contains($0.name ?? "") }) {
            return contentFolder
        }
        
        // Last resort: first folder that accepts files
        return folders.first(where: { FolderCapabilityService.canAddFile(to: $0) })
    }
    
    /// Generate a unique file name by appending a numeric suffix if needed.
    /// "Poem" → "Poem 2" → "Poem 3" etc.
    private func generateUniqueName(for name: String, usedNames: Set<String>) -> String {
        if !usedNames.contains(name) {
            return name
        }
        
        // Try numeric suffixes: "Name 2", "Name 3", ...
        var counter = 2
        while counter <= 1000 {
            let candidate = "\(name) \(counter)"
            if !usedNames.contains(candidate) {
                return candidate
            }
            counter += 1
        }
        // Safety fallback
        return "\(name) \(UUID().uuidString.prefix(6))"
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
