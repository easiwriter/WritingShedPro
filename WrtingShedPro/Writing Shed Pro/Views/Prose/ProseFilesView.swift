//
//  ProseFilesView.swift
//  Writing Shed Pro
//
//  View for displaying and managing text files within a Prose Section
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// View for displaying text files within a Prose section
struct ProseFilesView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Properties
    
    let project: Project
    let section: ProseSection
    
    // MARK: - State
    
    @State private var selectedFile: TextFile?
    @State private var editMode: EditMode = .inactive
    @State private var selectedFileIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    
    /// Export state
    @State private var showExportMenu = false
    @State private var filesToExport: [TextFile] = []
    @State private var showExportSaveDialog = false
    @State private var exportFormat: ExportFormat = .rtf
    @State private var exportData: Data?
    @State private var exportFilename: String = ""
    @State private var showExportImageWarning = false
    @State private var pendingExportAction: (() -> Void)?
    
    /// IAP gating
    @State private var upgradePromptReason: UpgradePromptReason?
    
    /// Copy to Project state
    @State private var showCopyToProject = false
    @State private var showCopyResult = false
    @State private var copyResultMessage = ""
    @State private var copyResultIsError = false
    
    /// Submission state
    @State private var showSubmissionNamePrompt = false
    @State private var newSubmissionName: String = ""
    @State private var showSubmissionCreated = false
    @State private var createdSubmissionName: String = ""
    @State private var showDuplicateSubmission = false
    
    // MARK: - Computed
    
    private var sortedFiles: [TextFile] {
        (section.textFiles ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
    }
    
    private var isEditMode: Bool {
        editMode == .active
    }
    
    private var selectedFiles: [TextFile] {
        sortedFiles.filter { selectedFileIDs.contains($0.id) }
    }
    
    private var showToolbar: Bool {
        isEditMode && !selectedFileIDs.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if sortedFiles.isEmpty {
                emptyState
            } else {
                fileList
            }
        }
        .navigationTitle(section.name ?? NSLocalizedString("prose.untitled", comment: "Untitled"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Edit/Done button
                if !sortedFiles.isEmpty {
                    Button {
                        withAnimation {
                            if editMode == .active {
                                editMode = .inactive
                                selectedFileIDs.removeAll()
                            } else {
                                editMode = .active
                            }
                        }
                    } label: {
                        Text(isEditMode ? NSLocalizedString("button.done", comment: "Done") : NSLocalizedString("button.edit", comment: "Edit"))
                    }
                }
            }
            
            // Bottom toolbar for multi-select actions
            ToolbarItemGroup(placement: .bottomBar) {
                if showToolbar {
                    bottomToolbarContent
                }
            }
        }
        .alert(
            selectedFiles.count == 1 
                ? NSLocalizedString("prose.files.removeConfirm.title", comment: "Remove from section?")
                : String(format: NSLocalizedString("prose.files.removeMultiple.title", comment: "Remove files?"), selectedFiles.count),
            isPresented: $showDeleteConfirmation
        ) {
            Button(NSLocalizedString("button.remove", comment: "Remove"), role: .destructive) {
                removeSelectedFiles()
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("prose.files.removeConfirm.message", comment: "Files will be unassigned from this section but not deleted."))
        }
        .onChange(of: editMode) { _, newValue in
            if newValue == .inactive {
                selectedFileIDs.removeAll()
            }
        }
        .alert(NSLocalizedString("submissions.name.title", comment: "Name Submission"), isPresented: $showSubmissionNamePrompt) {
            TextField(NSLocalizedString("submissions.name.placeholder", comment: "Name"), text: $newSubmissionName)
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                newSubmissionName = ""
            }
            Button(NSLocalizedString("button.create", comment: "Create")) {
                createSubmissionFromFiles(name: newSubmissionName)
                newSubmissionName = ""
            }
            .disabled(newSubmissionName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text(NSLocalizedString("submissions.name.message", comment: "Enter a name"))
        }
        .alert(NSLocalizedString("submissions.created.title", comment: "Submission Created"), isPresented: $showSubmissionCreated) {
            Button(NSLocalizedString("button.ok", comment: "OK")) { }
        } message: {
            Text(String(format: NSLocalizedString("submissions.created.message", comment: "Created message"), createdSubmissionName))
        }
        .alert(NSLocalizedString("submissions.duplicate.title", comment: "Duplicate Submission"), isPresented: $showDuplicateSubmission) {
            Button(NSLocalizedString("button.ok", comment: "OK")) { }
        } message: {
            Text(String(format: NSLocalizedString("submissions.duplicate.message", comment: "Duplicate message"), createdSubmissionName))
        }
        .confirmationDialog(
            NSLocalizedString("export.dialog.title", comment: "Export Format"),
            isPresented: $showExportMenu,
            titleVisibility: .visible
        ) {
            exportDialogButtons
        }
        .alert(NSLocalizedString("export.imageWarning.title", comment: "Images Not Included"), isPresented: $showExportImageWarning) {
            Button(NSLocalizedString("export.imageWarning.continue", comment: "Continue")) {
                pendingExportAction?()
                pendingExportAction = nil
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                pendingExportAction = nil
            }
        } message: {
            Text(NSLocalizedString("export.imageWarning.message", comment: "Images will not be included"))
        }
        .fileExporter(
            isPresented: $showExportSaveDialog,
            document: ExportDocument(
                data: exportData ?? Data(),
                filename: exportFilename,
                contentType: contentTypeForFormat(exportFormat)
            ),
            contentType: contentTypeForFormat(exportFormat),
            defaultFilename: exportFilename,
            onCompletion: { result in
                switch result {
                case .success:
                    #if DEBUG
                    print("✅ [ProseFilesView] Export saved successfully")
                    #endif
                case .failure(let error):
                    #if DEBUG
                    print("❌ [ProseFilesView] Export save failed: \(error)")
                    #endif
                }
                exportData = nil
                exportFilename = ""
            }
        )
        .sheet(isPresented: $showCopyToProject) {
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
        .alert(
            copyResultIsError
                ? NSLocalizedString("copyToProject.error.title", comment: "Copy Failed")
                : NSLocalizedString("copyToProject.success.title", comment: "Files Copied"),
            isPresented: $showCopyResult
        ) {
            Button(NSLocalizedString("button.ok", comment: "OK")) { }
        } message: {
            Text(copyResultMessage)
        }
        .upgradePrompt(reason: $upgradePromptReason)
    }
    
    // MARK: - Bottom Toolbar
    
    @ViewBuilder
    private var bottomToolbarContent: some View {
        // Add to submission button
        if !selectedFiles.isEmpty {
            Button {
                showSubmissionNamePrompt = true
            } label: {
                Label(NSLocalizedString("fileList.addToSubmission", comment: "Add to submission"), systemImage: "tray.and.arrow.down")
            }
        }
        
        // Export button
        if !selectedFiles.isEmpty {
            Button {
                filesToExport = selectedFiles
                showExportMenu = true
            } label: {
                Label(NSLocalizedString("fileList.export", comment: "Export files"), systemImage: "square.and.arrow.up")
            }
        }
        
        Spacer()
        
        // Remove from section button
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label(
                NSLocalizedString("prose.files.removeFromSection", comment: "Remove from Section"),
                systemImage: "minus.circle"
            )
        }
        .disabled(selectedFiles.isEmpty)
    }
    
    // MARK: - File List
    
    private var fileList: some View {
        List(selection: $selectedFileIDs) {
            ForEach(sortedFiles) { file in
                Group {
                    if isEditMode {
                        FileRowView(file: file)
                    } else {
                        NavigationLink {
                            FileEditView(file: file)
                        } label: {
                            FileRowView(file: file)
                        }
                    }
                }
                // Enable drag-to-reorder without edit mode
                .onDrag {
                    return NSItemProvider(object: file.id.uuidString as NSString)
                }
            }
            .onMove(perform: moveFiles)
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("prose.files.empty.title", comment: "No files"))
                .font(.headline)
            
            Text(NSLocalizedString("prose.files.empty.message", comment: "Empty message"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Export
    
    @ViewBuilder
    private var exportDialogButtons: some View {
        Button {
            showExportMenu = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showCopyToProject = true
            }
        } label: {
            Label(NSLocalizedString("export.copyToProject", comment: "Copy to Project…"), systemImage: "doc.on.doc")
        }
        Button(ExportFormat.pdf.localizedName) {
            exportFiles(filesToExport, format: .pdf)
        }
        Button(ExportFormat.rtf.localizedName) {
            pendingExportAction = { [self] in exportFiles(filesToExport, format: .rtf) }
            showImageWarningAfterDelay()
        }
        Button(ExportFormat.html.localizedName) {
            exportFiles(filesToExport, format: .html)
        }
        Button(ExportFormat.word.localizedName) {
            exportFiles(filesToExport, format: .word)
        }
        Button(ExportFormat.markdown.localizedName) {
            pendingExportAction = { [self] in exportFiles(filesToExport, format: .markdown) }
            showImageWarningAfterDelay()
        }
        Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
            filesToExport = []
        }
    }
    
    private func showImageWarningAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showExportImageWarning = true
        }
    }
    
    private func exportFiles(_ files: [TextFile], format: ExportFormat) {
        self.exportFormat = format
        guard !files.isEmpty else { return }
        
        // Check entitlement for export
        if !EntitlementManager.shared.canExport(projectType: project.type) {
            upgradePromptReason = .exportBlocked(projectType: project.type)
            return
        }
        
        var attributedStrings: [NSAttributedString] = []
        
        for file in files {
            guard let version = file.currentVersion else { continue }
            var content: NSAttributedString
            if let formatted = version.attributedContent {
                content = formatted
            } else if !version.content.isEmpty {
                content = NSAttributedString(
                    string: version.content,
                    attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
                )
            } else {
                continue
            }
            
            if file.isMarkdown && format != .markdown && format != .plainText {
                if let rendered = try? MarkdownImportService.importMarkdown(from: content.string, styleSheet: file.project?.styleSheet) {
                    content = rendered
                }
            }
            
            attributedStrings.append(content)
        }
        
        guard !attributedStrings.isEmpty else {
            filesToExport = []
            return
        }
        
        if attributedStrings.count == 1, let firstFile = files.first {
            performSingleFileExport(format: format, content: attributedStrings[0], filename: firstFile.name)
            filesToExport = []
            return
        }
        
        let filename = project.name ?? "Export"
        
        Task {
            do {
                let data: Data
                switch format {
                case .pdf:
                    let assembled = NSMutableAttributedString()
                    var isFirst = true
                    for attrStr in attributedStrings {
                        if !isFirst {
                            assembled.append(NSAttributedString(string: "\u{000C}"))
                        }
                        isFirst = false
                        assembled.append(attrStr)
                    }
                    let manuscriptContent = ManuscriptContent(
                        attributedString: assembled,
                        sections: [],
                        fileOffsets: [:],
                        frontMatterFileCount: 0,
                        frontMatterCharacterLength: 0,
                        assembledFootnotes: []
                    )
                    guard let pdfData = PrintService.generatePDF(
                        from: manuscriptContent,
                        project: project,
                        pageSetup: project.pageSetup,
                        context: modelContext
                    ) else { return }
                    data = pdfData
                case .rtf:
                    data = try WordDocumentService.exportMultipleToRTF(attributedStrings, filename: filename)
                case .html:
                    data = try HTMLExportService.exportMultipleToHTMLData(attributedStrings, filename: filename)
                case .word:
                    let exportService = DOCXExportService(modelContext: modelContext)
                    data = try exportService.exportMultipleToDOCX(attributedStrings, filename: filename)
                case .markdown:
                    data = try MarkdownExportService.exportMultipleToMarkdownData(attributedStrings, filename: filename)
                default:
                    return
                }
                
                await MainActor.run {
                    exportData = data
                    exportFilename = "\(filename).\(format.fileExtension)"
                    showExportSaveDialog = true
                }
            } catch {
                #if DEBUG
                await MainActor.run {
                    print("❌ [ProseFilesView] Multi-file export failed: \(error)")
                }
                #endif
            }
        }
        
        filesToExport = []
    }
    
    private func performSingleFileExport(format: ExportFormat, content: NSAttributedString, filename: String) {
        do {
            switch format {
            case .pdf:
                let assembled = NSMutableAttributedString()
                assembled.append(content)
                let manuscriptContent = ManuscriptContent(
                    attributedString: assembled,
                    sections: [],
                    fileOffsets: [:],
                    frontMatterFileCount: 0,
                    frontMatterCharacterLength: 0,
                    assembledFootnotes: []
                )
                guard let pdfData = PrintService.generatePDF(
                    from: manuscriptContent,
                    project: project,
                    pageSetup: project.pageSetup,
                    context: modelContext
                ) else { return }
                exportData = pdfData
            case .rtf:
                exportData = try WordDocumentService.exportToRTF(content, filename: filename)
            case .html:
                exportData = try HTMLExportService.exportToHTMLData(content, filename: filename)
            case .word:
                let exportService = DOCXExportService(modelContext: modelContext)
                exportData = try exportService.exportToDOCX(content, filename: filename)
            case .markdown:
                exportData = try MarkdownExportService.exportToMarkdownData(content, filename: filename)
            default:
                return
            }
            
            exportFilename = "\(filename).\(format.fileExtension)"
            showExportSaveDialog = true
        } catch {
            #if DEBUG
            print("❌ [ProseFilesView] Single export failed: \(error)")
            #endif
        }
    }
    
    private func contentTypeForFormat(_ format: ExportFormat) -> UTType {
        switch format {
        case .rtf: return .rtf
        case .html: return .html
        case .word: return UTType("org.openxmlformats.wordprocessingml.document") ?? .data
        case .pdf: return .pdf
        case .markdown: return UTType(filenameExtension: "md") ?? .plainText
        case .plainText: return .plainText
        case .epub: return UTType(filenameExtension: "epub") ?? .data
        case .fountain: return UTType(filenameExtension: "fountain") ?? .plainText
        case .finalDraft: return UTType(filenameExtension: "fdx") ?? .xml
        }
    }
    
    // MARK: - Copy to Project
    
    private func copyFilesToProject(_ files: [TextFile], destination: Project) {
        guard !files.isEmpty else { return }
        
        let sourceFolderName = "Prose"
        let destinationFolder = findMatchingFolder(in: destination, named: sourceFolderName)
        
        guard let destFolder = destinationFolder else {
            copyResultMessage = String(format: NSLocalizedString("copyToProject.error.noFolder", comment: "No matching folder found"), sourceFolderName, destination.name ?? "")
            copyResultIsError = true
            showCopyResult = true
            return
        }
        
        var usedNames = Set((destFolder.textFiles ?? []).map { $0.name })
        var copiedCount = 0
        let maxSceneOrder = (destination.type == .fiction || destination.type == .drama)
            ? (destination.scenes ?? []).filter({ !$0.isTrashed }).compactMap(\.userOrder).max() ?? -1
            : 0
        
        for file in files {
            guard let currentVersion = file.currentVersion else { continue }
            
            let uniqueName = generateUniqueName(for: file.name, usedNames: usedNames)
            usedNames.insert(uniqueName)
            
            let newFile = TextFile(
                name: uniqueName,
                initialContent: currentVersion.content,
                parentFolder: destFolder,
                poetryFormId: file.poetryFormId,
                poetryFormName: file.poetryFormName
            )
            
            newFile.workflowStatusRaw = file.workflowStatusRaw
            newFile.contentTypeRaw = file.contentTypeRaw
            
            if let formattedData = currentVersion.formattedContent,
               let newVersion = newFile.currentVersion {
                newVersion.formattedContent = formattedData
            }

            if let newVersion = newFile.currentVersion {
                newVersion.comment = currentVersion.comment
                newVersion.notes = currentVersion.notes
            }
            
            if let refMetadata = currentVersion.referenceMetadataData,
               let newVersion = newFile.currentVersion {
                newVersion.referenceMetadataData = refMetadata
            }
            
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
    
    private func findMatchingFolder(in project: Project, named sourceName: String) -> Folder? {
        guard let folders = project.folders else { return nil }
        if let match = folders.first(where: { $0.name == sourceName }) {
            return match
        }
        let contentFolderNames: Set<String> = ["Poems", "Scenes", "Stories", "Episodes", "Scripts", "Sections", "Prose"]
        if let contentFolder = folders.first(where: { contentFolderNames.contains($0.name ?? "") }) {
            return contentFolder
        }
        return folders.first(where: { FolderCapabilityService.canAddFile(to: $0) })
    }
    
    private func generateUniqueName(for name: String, usedNames: Set<String>) -> String {
        if !usedNames.contains(name) { return name }
        var counter = 2
        while counter <= 1000 {
            let candidate = "\(name) \(counter)"
            if !usedNames.contains(candidate) { return candidate }
            counter += 1
        }
        return "\(name) \(UUID().uuidString.prefix(6))"
    }
    
    // MARK: - Actions
    
    private func removeSelectedFiles() {
        for file in selectedFiles {
            file.section = nil
        }
        
        try? modelContext.save()
        selectedFileIDs.removeAll()
        renumberFiles()
        exitEditMode()
    }
    
    private func moveFiles(from source: IndexSet, to destination: Int) {
        var files = sortedFiles
        files.move(fromOffsets: source, toOffset: destination)
        
        // Update order indices
        for (index, file) in files.enumerated() {
            file.userOrder = index
        }
        
        try? modelContext.save()
    }
    
    private func renumberFiles() {
        for (index, file) in sortedFiles.enumerated() {
            file.userOrder = index
        }
        try? modelContext.save()
    }
    
    private func exitEditMode() {
        withAnimation {
            editMode = .inactive
        }
    }
    
    private func createSubmissionFromFiles(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if hasDuplicateSubmissionNamed(trimmedName) {
            createdSubmissionName = trimmedName
            showDuplicateSubmission = true
            return
        }
        
        let submission = Submission(
            project: project,
            submittedDate: Date()
        )
        submission.name = trimmedName
        submission.isCollection = false
        modelContext.insert(submission)
        
        for file in selectedFiles {
            let submittedFile = SubmittedFile(
                submission: submission,
                textFile: file,
                version: file.currentVersion,
                status: .pending,
                statusDate: Date(),
                project: project
            )
            modelContext.insert(submittedFile)
        }
        
        try? modelContext.save()
        createdSubmissionName = trimmedName
        showSubmissionCreated = true
        selectedFileIDs.removeAll()
        exitEditMode()
    }

    private func hasDuplicateSubmissionNamed(_ name: String) -> Bool {
        let submissions = project.submissions ?? []
        return submissions.contains { submission in
            submission.isCollection == false && submission.name == name
        }
    }
}

// MARK: - File Row View

private struct FileRowView: View {
    let file: TextFile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(file.name.isEmpty ? NSLocalizedString("prose.untitled", comment: "Untitled") : file.name)
                .font(.body)
            
            // Modified date
            Text(file.modifiedDate, style: .date)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}
