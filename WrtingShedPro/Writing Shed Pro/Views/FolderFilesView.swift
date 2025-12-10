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
    @State private var showExportFolderMenu = false
    @State private var showExportSaveDialog = false
    @State private var filesToExport: [TextFile] = []
    @State private var exportFormat: ExportFormat = .rtf
    @State private var exportData: Data?
    @State private var exportFilename: String = ""
    @State private var exportCombinedContent: NSAttributedString?
    @State private var exportAttributedStrings: [NSAttributedString] = []  // For HTML multi-file export
    
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
        .navigationDestination(isPresented: $navigateToFile) {
            if let file = selectedFile {
                FileEditView(file: file)
            }
        }
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
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
                    
                    // Export folder button (when NOT in edit mode - combines all files)
                    if !sortedFiles.isEmpty && editMode == .inactive {
                        Button {
                            exportCompleteFolder()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel(NSLocalizedString("folderFiles.exportFolder.accessibility", comment: "Export complete folder"))
                        .help(NSLocalizedString("folderFiles.exportFolder.help", comment: "Export all files combined as one document"))
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
        .sheet(isPresented: $showSearchView) {
            MultiFileSearchView(folder: folder)
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
            allowedContentTypes: [.rtf],
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
            defaultFilename: "\(exportFilename).\(exportFormat.fileExtension)"
        ) { result in
            handleExportResult(result: result)
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
                    print("   File ID: \(file.id)")
                    print("   Version count: \(file.versions?.count ?? 0)")
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
        
        var fileExtension: String {
            switch self {
            case .rtf: return "rtf"
            case .html: return "html"
            case .epub: return "epub"
            }
        }
        
        var displayName: String {
            switch self {
            case .rtf: return NSLocalizedString("export.format.rtf", comment: "RTF (Word-compatible)")
            case .html: return NSLocalizedString("export.format.html", comment: "HTML (Web page)")
            case .epub: return NSLocalizedString("export.format.epub", comment: "EPUB (eBook)")
            }
        }
    }
    
    private func exportCompleteFolder() {
        // Collect all file contents as separate attributed strings (for HTML)
        var attributedStrings: [NSAttributedString] = []
        
        // Also create combined content for RTF/EPUB
        let combinedContent = NSMutableAttributedString()
        
        for (_, file) in sortedFiles.enumerated() {
            guard let version = file.currentVersion,
                  let attributedString = version.attributedContent else {
                continue
            }
            
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
        // Set the export format
        self.exportFormat = format
        
        guard let combinedContent = exportCombinedContent else {
            return
        }
        
        // Prepare export data based on format
        do {
            switch format {
            case .rtf:
                exportData = try WordDocumentService.exportToRTF(combinedContent, filename: exportFilename)
            case .html:
                // Use the array version for HTML to preserve page breaks and prevent CSS conflicts
                exportData = try HTMLExportService.exportMultipleToHTMLData(exportAttributedStrings, filename: exportFilename)
            case .epub:
                // Use the array version for EPUB to preserve page breaks and prevent CSS conflicts
                exportData = try EPUBExportService.exportMultipleToEPUB(exportAttributedStrings, filename: exportFilename)
            }
            
            showExportSaveDialog = true
            
        } catch {
            importErrorMessage = NSLocalizedString("export.error.failed", comment: "Export failed") + ": \(error.localizedDescription)"
            showImportError = true
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
        
        // Prepare export data based on format
        do {
            switch format {
            case .rtf:
                exportData = try WordDocumentService.exportToRTF(attributedString, filename: firstFile.name)
            case .html:
                exportData = try HTMLExportService.exportToHTMLData(attributedString, filename: firstFile.name)
            case .epub:
                exportData = try EPUBExportService.exportToEPUB(attributedString, filename: firstFile.name)
            }
            
            exportFilename = firstFile.name
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
            print("✅ Exported to: \(url.path)")
            // Remove the first file and continue with remaining files if any
            if !filesToExport.isEmpty {
                filesToExport.removeFirst()
                if !filesToExport.isEmpty {
                    // Export next file
                    exportFiles(format: exportFormat)
                }
            }
        case .failure(let error):
            print("❌ Export failed: \(error.localizedDescription)")
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
        }
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

// MARK: - Export Document Type

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { 
        [.rtf, .html, UTType(filenameExtension: "epub") ?? .data, .data] 
    }
    
    static var writableContentTypes: [UTType] { 
        [.rtf, .html, UTType(filenameExtension: "epub") ?? .data, .data] 
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