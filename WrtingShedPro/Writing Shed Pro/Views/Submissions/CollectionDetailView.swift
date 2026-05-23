//
//  CollectionDetailView.swift
//  Writing Shed Pro
//
//  Extracted from CollectionsView.swift during Feature 036 refactor.
//  These views are used by the Submissions system for collection-type submissions.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Supporting Types

struct EditVersionItem: Identifiable {
    let submittedFile: SubmittedFile
    let textFile: TextFile
    
    var id: UUID { submittedFile.id }
}

// MARK: - Collection Detail View

struct CollectionDetailView: View {
    @Bindable var submission: Submission
    @Environment(\.modelContext) var modelContext
    
    @State private var showAddFilesSheet = false
    @State private var editingVersionItem: EditVersionItem?
    @State private var showSubmissionPicker = false
    @State private var showDuplicateSubmission = false
    @State private var duplicateSubmissionName: String = ""
    @State private var showPrintError = false
    @State private var printErrorMessage = ""
    @State private var showSearchView = false
    
    // Export state
    @State private var showExportMenu = false
    @State private var exportFormat: ExportFormat = .rtf
    @State private var showExportSaveDialog = false
    @State private var exportData: Data?
    @State private var exportFilename: String = ""
    @State private var saveAsRequested = false
    @State private var showExportImageWarning = false
    @State private var pendingExportAction: (() -> Void)?
    @State private var shareableFileURL: URL?
    @State private var showShareSheet = false
    
    // IAP gating
    @State private var upgradePromptReason: UpgradePromptReason?
    
    // Copy to Project state
    @State private var showCopyToProject = false
    @State private var showCopyResult = false
    @State private var copyResultMessage = ""
    @State private var copyResultIsError = false
    
    // Edit Dates state
    @State private var showEditDates = false
    
    // Edit mode state
    @State private var editMode: EditMode = .inactive
    @State private var selectedFileIDs: Set<UUID> = []
    
    private var submittedFiles: [SubmittedFile] {
        let files = submission.submittedFiles ?? []
        return files.sorted { file1, file2 in
            let name1 = file1.textFile?.name ?? ""
            let name2 = file2.textFile?.name ?? ""
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }

    @ViewBuilder
    private func submittedFileRow(_ submittedFile: SubmittedFile) -> some View {
        if let file = submittedFile.textFile {
            HStack {
                NavigationLink(destination: FileEditView(file: file)) {
                    CollectionFileRowView(submittedFile: submittedFile)
                }

                if editMode == .inactive {
                    Button {
                        editingVersionItem = EditVersionItem(submittedFile: submittedFile, textFile: file)
                    } label: {
                        Image(systemName: "pencil.circle.circle")
                            .foregroundStyle(.blue)
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("collectionsView.detail.editVersion.accessibility")
                }
            }
            .tag(submittedFile.id)
        }
    }

    private var submittedFilesList: some View {
        List(selection: $selectedFileIDs) {
            ForEach(submittedFiles) { submittedFile in
                submittedFileRow(submittedFile)
            }
            .onDelete(perform: deleteFiles)
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
        .safeAreaInset(edge: .bottom) {
            if editMode == .active && !selectedFileIDs.isEmpty {
                HStack {
                    Button {
                        saveAsRequested = false
                        showExportMenu = true
                    } label: {
                        Label(
                            NSLocalizedString("button.export", comment: "Export"),
                            systemImage: "square.and.arrow.up"
                        )
                    }
                    .accessibilityLabel("Export selected files")

                    #if os(macOS) || targetEnvironment(macCatalyst)
                    Button {
                        saveAsRequested = true
                        showExportMenu = true
                    } label: {
                        Label(NSLocalizedString("manuscript.saveAs", comment: "Save As…"), systemImage: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Save selected files as")
                    #endif

                    Spacer()
                }
                .padding()
                .background(.bar)
            }
        }
    }

    private var emptyCollectionView: some View {
        ContentUnavailableView {
            Label("collectionsView.detail.empty.title", systemImage: "doc.text")
        } description: {
            Text("collectionsView.detail.empty.description")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("collectionsView.detail.empty.accessibility")
    }

    @ViewBuilder
    private var detailContent: some View {
        if !submittedFiles.isEmpty {
            submittedFilesList
        } else {
            emptyCollectionView
        }
    }

    private var titleToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
                Text(submission.name ?? NSLocalizedString("collectionsView.untitled", comment: "Untitled Collection"))
                    .font(.headline)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var trailingToolbarButtons: some View {
        if !submittedFiles.isEmpty {
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
                Text(editMode == .active
                     ? NSLocalizedString("button.done", comment: "Done")
                     : NSLocalizedString("button.edit", comment: "Edit"))
            }
        }

        if !submittedFiles.isEmpty {
            Button {
                showSearchView = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel("Search files in collection")
            .help("Search and replace across all files in this collection")
        }

        Menu {
            Button(action: { showAddFilesSheet = true }) {
                Label("Add Files", systemImage: "plus")
            }

            Button(action: { showEditDates = true }) {
                Label(NSLocalizedString("submissions.editDates", comment: "Edit Dates"), systemImage: "calendar.badge.clock")
            }

            if !submittedFiles.isEmpty {
                Divider()

                Button(action: {
                    prepareExport(saveAs: false)
                }) {
                    Label(NSLocalizedString("button.export", comment: "Export"), systemImage: "square.and.arrow.up")
                }

                #if os(macOS) || targetEnvironment(macCatalyst)
                Button(action: {
                    prepareExport(saveAs: true)
                }) {
                    Label(NSLocalizedString("manuscript.saveAs", comment: "Save As…"), systemImage: "square.and.arrow.down")
                }
                #endif

                Button(action: { showSubmissionPicker = true }) {
                    Label("Submit to Publication", systemImage: "paperplane")
                }

                Button(action: { printCollection() }) {
                    Label("Print Collection", systemImage: "printer")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("collectionsView.actions.accessibility")
    }

    private var actionsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                trailingToolbarButtons
            }
        }
    }
    
    var body: some View {
        baseDetailView
        .sheet(isPresented: $showSearchView) {
            searchSheetContent
        }
        .sheet(isPresented: $showAddFilesSheet) {
            addFilesSheetContent
        }
        .sheet(item: $editingVersionItem) { item in
            editVersionSheetContent(for: item)
        }
        .sheet(isPresented: $showSubmissionPicker) {
            submissionPickerSheetContent
        }
        .sheet(isPresented: $showEditDates) {
            EditSubmissionDatesView(submission: submission)
        }
        .onAppear {
            prefetchSubmittedFiles()
        }
        .alert("Print Error", isPresented: $showPrintError) {
            Button("OK", role: .cancel) { }
        } message: {
            printErrorAlertMessage
        }
        .alert(NSLocalizedString("submissions.duplicate.title", comment: "Duplicate Submission"), isPresented: $showDuplicateSubmission) {
            Button(NSLocalizedString("button.ok", comment: "OK")) { }
        } message: {
            duplicateSubmissionAlertMessage
        }
        .confirmationDialog(
            NSLocalizedString("export.dialog.title", comment: "Export Format"),
            isPresented: $showExportMenu,
            titleVisibility: .visible
        ) {
            exportDialogButtons
        }
        .alert(NSLocalizedString("export.imageWarning.title", comment: "Images Not Included"), isPresented: $showExportImageWarning) {
            exportImageWarningButtons
        } message: {
            exportImageWarningMessage
        }
        .sheet(isPresented: $showShareSheet) {
            if let fileURL = shareableFileURL {
                ShareSheet(urls: [fileURL])
            }
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
            onCompletion: { _ in
                exportData = nil
                exportFilename = ""
                saveAsRequested = false
            }
        )
    }

    private var baseDetailView: some View {
        detailContent
        .navigationTitle("collectionsView.detail.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            titleToolbarItem
            actionsToolbarItem
        }
    }

    private var searchSheetContent: some View {
        MultiFileSearchView(collection: submission)
    }

    private var addFilesSheetContent: some View {
        AddFilesToCollectionSheet(
            submission: submission,
            onCancel: {
                showAddFilesSheet = false
            },
            onFilesAdded: {
                showAddFilesSheet = false
            }
        )
    }

    private func editVersionSheetContent(for item: EditVersionItem) -> some View {
        NavigationStack {
            EditVersionSheet(
                submittedFile: item.submittedFile,
                textFile: item.textFile,
                onCancel: {
                    editingVersionItem = nil
                },
                onSave: {
                    editingVersionItem = nil
                    try? modelContext.save()
                }
            )
            .id(item.submittedFile.id)
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var submissionPickerSheetContent: some View {
        if let project = submission.project {
            NavigationStack {
                SubmissionPickerView(
                    project: project,
                    filesToSubmit: nil,
                    collectionToSubmit: submission,
                    onPublicationSelected: { publication, name, expectedDate, reminderDate in
                        createSubmissionFromCollection(to: publication, name: name, expectedResponseDate: expectedDate, reminderDate: reminderDate)
                        showSubmissionPicker = false
                    },
                    onCancel: {
                        showSubmissionPicker = false
                    }
                )
            }
        }
    }

    private func prefetchSubmittedFiles() {
        let count = submission.submittedFiles?.count ?? 0
        _ = count
    }

    private var printErrorAlertMessage: some View {
        Text(printErrorMessage)
    }

    private var duplicateSubmissionAlertMessage: some View {
        Text(String(format: NSLocalizedString("submissions.duplicate.message", comment: "Duplicate message"), duplicateSubmissionName))
    }

    private var exportImageWarningMessage: some View {
        Text(NSLocalizedString("export.imageWarning.message", comment: "Images will not be included"))
    }

    @ViewBuilder
    private var exportImageWarningButtons: some View {
        Button(NSLocalizedString("export.imageWarning.continue", comment: "Continue")) {
            pendingExportAction?()
            pendingExportAction = nil
        }
        Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
            pendingExportAction = nil
        }
        .sheet(isPresented: $showCopyToProject) {
            if let project = submission.project {
                CopyToProjectPickerView(
                    sourceProject: project,
                    filesToCopy: filesToCopyToProject,
                    onProjectSelected: { destinationProject in
                        showCopyToProject = false
                        copyFilesToProject(filesToCopyToProject, destination: destinationProject)
                    },
                    onCancel: {
                        showCopyToProject = false
                    }
                )
            }
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
    
    // MARK: - Export
    
    private func prepareExport(saveAs: Bool = false) {
        saveAsRequested = saveAs
        showExportMenu = true
    }
    
    @ViewBuilder
    private var exportDialogButtons: some View {
        if submission.project != nil {
            Button {
                showExportMenu = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showCopyToProject = true
                }
            } label: {
                Label(NSLocalizedString("export.copyToProject", comment: "Copy to Project…"), systemImage: "doc.on.doc")
            }
        }
        Button(ExportFormat.pdf.localizedName) {
            exportCollectionFiles(format: .pdf)
        }
        Button(ExportFormat.rtf.localizedName) {
            pendingExportAction = { exportCollectionFiles(format: .rtf) }
            showImageWarningAfterDelay()
        }
        Button(ExportFormat.html.localizedName) {
            exportCollectionFiles(format: .html)
        }
        Button(ExportFormat.word.localizedName) {
            exportCollectionFiles(format: .word)
        }
        Button(ExportFormat.markdown.localizedName) {
            pendingExportAction = { exportCollectionFiles(format: .markdown) }
            showImageWarningAfterDelay()
        }
        Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
    }
    
    private func showImageWarningAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showExportImageWarning = true
        }
    }
    
    private func exportCollectionFiles(format: ExportFormat) {
        self.exportFormat = format
        
        // Check entitlement for export
        if let project = submission.project {
            if !EntitlementManager.shared.canExport(projectType: project.type) {
                upgradePromptReason = .exportBlocked(projectType: project.type)
                return
            }
        }
        
        // If in edit mode with selections, export only selected files
        let filesToExport: [SubmittedFile]
        if editMode == .active && !selectedFileIDs.isEmpty {
            filesToExport = submittedFiles.filter { selectedFileIDs.contains($0.id) }
        } else {
            filesToExport = submittedFiles
        }
        
        // Use the submitted version, falling back to current version
        let versions = filesToExport
            .compactMap { $0.version ?? $0.textFile?.currentVersion }
        
        guard !versions.isEmpty else { return }
        
        var attributedStrings: [NSAttributedString] = []
        
        for version in versions {
            let content: NSAttributedString
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
            attributedStrings.append(content)
        }
        
        guard !attributedStrings.isEmpty else { return }
        
        let filename = submission.name ?? "Collection"
        
        Task {
            do {
                let data: Data
                switch format {
                case .pdf:
                    let textFiles = filesToExport
                        .compactMap { $0.textFile }
                    guard !textFiles.isEmpty, let project = submission.project else { return }
                    
                    // Assemble content like manuscript export for proper page views
                    let assembled = NSMutableAttributedString()
                    var isFirst = true
                    for tf in textFiles {
                        guard let version = tf.currentVersion, let content = version.attributedContent else { continue }
                        if !isFirst {
                            assembled.append(NSAttributedString(string: "\u{000C}"))
                        }
                        isFirst = false
                        assembled.append(content)
                    }
                    guard assembled.length > 0 else { return }
                    
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
                    data = try await Task.detached {
                        try WordDocumentService.exportMultipleToRTF(attributedStrings, filename: filename)
                    }.value
                case .html:
                    data = try await Task.detached {
                        try HTMLExportService.exportMultipleToHTMLData(attributedStrings, filename: filename)
                    }.value
                case .word:
                    data = try await Task.detached { [weak modelContext] in
                        guard let modelContext = modelContext else { throw DOCXExportError.noContent }
                        let exportService = DOCXExportService(modelContext: modelContext)
                        return try exportService.exportMultipleToDOCX(attributedStrings, filename: filename)
                    }.value
                case .markdown:
                    data = try await Task.detached {
                        try MarkdownExportService.exportMultipleToMarkdownData(attributedStrings, filename: filename)
                    }.value
                default:
                    return
                }
                
                await MainActor.run {
                    presentShareFile(data: data, filename: "\(filename).\(format.fileExtension)", format: format)
                }
            } catch {
                #if DEBUG
                print("❌ Export failed: \(error)")
                #endif
            }
        }
    }

    private func presentShareFile(data: Data, filename: String, format: ExportFormat) {
        if saveAsRequested {
            exportData = data
            exportFilename = filename
            exportFormat = format
            showExportSaveDialog = true
            if editMode == .active {
                withAnimation {
                    editMode = .inactive
                    selectedFileIDs.removeAll()
                }
            }
            return
        }

        if let fileURL = ShareService.shared.createShareableFile(
            data: data,
            filename: filename,
            contentType: contentTypeForFormat(format)
        ) {
            shareableFileURL = fileURL
            showShareSheet = true
            if editMode == .active {
                withAnimation {
                    editMode = .inactive
                    selectedFileIDs.removeAll()
                }
            }
        }
    }
    
    private func contentTypeForFormat(_ format: ExportFormat) -> UTType {
        switch format {
        case .rtf: return .rtf
        case .html: return .html
        case .word: return UTType("org.openxmlformats.wordprocessingml.document") ?? .data
        case .pdf: return .pdf
        case .plainText: return .plainText
        case .epub: return UTType(filenameExtension: "epub") ?? .data
        case .markdown: return UTType(filenameExtension: "md") ?? .plainText
        case .fountain: return UTType(filenameExtension: "fountain") ?? .plainText
        case .finalDraft: return UTType(filenameExtension: "fdx") ?? .xml
        }
    }
    
    // MARK: - Copy to Project
    
    /// TextFiles to copy — uses edit mode selection if active, otherwise all files.
    private var filesToCopyToProject: [TextFile] {
        let files: [SubmittedFile]
        if editMode == .active && !selectedFileIDs.isEmpty {
            files = submittedFiles.filter { selectedFileIDs.contains($0.id) }
        } else {
            files = submittedFiles
        }
        return files.compactMap { $0.textFile }
    }
    
    /// Copy files to a destination project, placing them in the matching folder by name.
    private func copyFilesToProject(_ files: [TextFile], destination: Project) {
        guard !files.isEmpty else { return }

        let sourceFolderName = sourceFolderNameForCopy()

        guard let destFolder = findMatchingFolder(in: destination, named: sourceFolderName) else {
            copyResultMessage = String(format: NSLocalizedString("copyToProject.error.noFolder", comment: "No matching folder found"), sourceFolderName, destination.name ?? "")
            copyResultIsError = true
            showCopyResult = true
            return
        }

        var usedNames = existingFileNames(in: destFolder)
        var copiedCount = 0
        let maxSceneOrder = maxSceneOrderForCopy(in: destination)

        for file in files {
            guard let currentVersion = file.currentVersion else { continue }

            let uniqueName = generateUniqueName(for: file.name, usedNames: usedNames)
            usedNames.insert(uniqueName)

            let newFile = makeCopiedFile(
                from: file,
                version: currentVersion,
                named: uniqueName,
                in: destFolder,
                orderOffset: copiedCount
            )

            modelContext.insert(newFile)

            insertSceneIfNeeded(
                for: destination,
                file: newFile,
                name: uniqueName,
                sceneOrderBase: maxSceneOrder,
                orderOffset: copiedCount
            )

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

    private func sourceFolderNameForCopy() -> String {
        submission.project?.folders?
            .first(where: { FolderCapabilityService.canAddFile(to: $0) })?
            .name ?? "Files"
    }

    private func existingFileNames(in folder: Folder) -> Set<String> {
        Set((folder.textFiles ?? []).map(\.name))
    }

    private func maxSceneOrderForCopy(in destination: Project) -> Int {
        guard destination.type == .fiction || destination.type == .drama else { return 0 }
        let scenes = destination.scenes ?? []
        return scenes
            .filter { !$0.isTrashed }
            .compactMap(\.userOrder)
            .max() ?? -1
    }

    private func makeCopiedFile(
        from source: TextFile,
        version: Version,
        named uniqueName: String,
        in destinationFolder: Folder,
        orderOffset: Int
    ) -> TextFile {
        let newFile = TextFile(
            name: uniqueName,
            initialContent: version.content,
            parentFolder: destinationFolder,
            poetryFormId: source.poetryFormId,
            poetryFormName: source.poetryFormName
        )

        newFile.workflowStatusRaw = source.workflowStatusRaw
        newFile.contentTypeRaw = source.contentTypeRaw

        if let newVersion = newFile.currentVersion {
            newVersion.formattedContent = version.formattedContent
            newVersion.referenceMetadataData = version.referenceMetadataData
            newVersion.comment = version.comment
            newVersion.notes = version.notes
            newVersion.notesFormattedContent = version.notesFormattedContent
        }

        let maxOrder = (destinationFolder.textFiles ?? []).compactMap { $0.userOrder }.max() ?? -1
        newFile.userOrder = maxOrder + 1 + orderOffset

        return newFile
    }

    private func insertSceneIfNeeded(
        for destination: Project,
        file: TextFile,
        name: String,
        sceneOrderBase: Int,
        orderOffset: Int
    ) {
        guard destination.type == .fiction || destination.type == .drama else { return }
        let scene = StoryScene(name: name, userOrder: sceneOrderBase + 1 + orderOffset)
        scene.project = destination
        scene.textFile = file
        modelContext.insert(scene)
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
    
    // MARK: - Printing
    
    /// Handle print collection action
    private func printCollection() {
        #if DEBUG
        print("🖨️ Print Collection button tapped")
        #endif
        
        // Check entitlement for printing
        if let project = submission.project {
            if !EntitlementManager.shared.canPrint(projectType: project.type) {
                upgradePromptReason = .printBlocked(projectType: project.type)
                return
            }
        }
        
        // Get the view controller to present from
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let viewController = window.rootViewController else {
            #if DEBUG
            print("❌ Could not find view controller for print dialog")
            #endif
            printErrorMessage = "Unable to present print dialog"
            showPrintError = true
            return
        }
        
        PrintService.printCollection(
            submission,
            modelContext: modelContext,
            from: viewController
        ) { success, error in
            if let error = error {
                #if DEBUG
                print("❌ Print failed: \(error.localizedDescription)")
                #endif
                printErrorMessage = error.localizedDescription
                showPrintError = true
            } else if success {
                #if DEBUG
                print("✅ Print completed successfully")
                #endif
            } else {
                #if DEBUG
                print("⚠️ Print was cancelled")
                #endif
            }
        }
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let file = submittedFiles[index]
            submission.submittedFiles?.removeAll { $0.id == file.id }
            modelContext.delete(file)
        }
        
        do {
            try modelContext.save()
        } catch {
            // Handle error silently for now
        }
    }

    private func resolvedSubmissionName(from inputName: String) -> String {
        inputName.isEmpty ? (submission.name ?? "") : inputName
    }

    private func hasDuplicateSubmissionName(_ candidateName: String, in project: Project) -> Bool {
        let existingSubmissions = project.submissions ?? []
        return existingSubmissions.contains { existing in
            existing.isCollection == false && existing.name == candidateName
        }
    }

    private func buildPublicationSubmission(
        project: Project,
        publication: Publication,
        name: String,
        expectedResponseDate: Date?
    ) -> Submission {
        let pubSubmission = Submission(
            publication: publication,
            project: project
        )
        pubSubmission.name = name
        pubSubmission.collectionDescription = submission.collectionDescription
        pubSubmission.isCollection = false
        pubSubmission.returnExpectedBy = expectedResponseDate
        return pubSubmission
    }

    private func scheduleReminderIfNeeded(
        for pubSubmission: Submission,
        publicationName: String,
        submissionName: String,
        reminderDate: Date?
    ) {
        guard let reminderDate else { return }
        pubSubmission.reminderDate = reminderDate

        Task {
            let notifId = await NotificationReminderService.shared.scheduleSubmissionReminder(
                submissionId: UUID().uuidString,
                publicationName: publicationName,
                submissionName: submissionName,
                reminderDate: reminderDate
            )
            if let notifId {
                await MainActor.run {
                    pubSubmission.reminderNotificationId = notifId
                }
            }
        }
    }

    private func copiedSubmittedFiles(from source: [SubmittedFile], to destination: Submission) -> [SubmittedFile] {
        source.map { original in
            SubmittedFile(
                submission: destination,
                textFile: original.textFile,
                version: original.version,
                status: .pending
            )
        }
    }
    
    private func createSubmissionFromCollection(to publication: Publication, name: String, expectedResponseDate: Date? = nil, reminderDate: Date? = nil) {
        guard let project = submission.project else { return }

        let trimmedName = resolvedSubmissionName(from: name)
        if hasDuplicateSubmissionName(trimmedName, in: project) {
            duplicateSubmissionName = trimmedName
            showDuplicateSubmission = true
            return
        }

        let pubSubmission = buildPublicationSubmission(
            project: project,
            publication: publication,
            name: trimmedName,
            expectedResponseDate: expectedResponseDate
        )

        let sourceFiles = submission.submittedFiles ?? []
        pubSubmission.submittedFiles = copiedSubmittedFiles(from: sourceFiles, to: pubSubmission)

        scheduleReminderIfNeeded(
            for: pubSubmission,
            publicationName: publication.name,
            submissionName: trimmedName.isEmpty ? "Submission" : trimmedName,
            reminderDate: reminderDate
        )

        project.modifiedDate = Date()
        modelContext.insert(pubSubmission)

        do {
            try modelContext.save()
        } catch {
            // Handle error silently for now
        }
    }
}

// MARK: - Collection File Row View

struct CollectionFileRowView: View {
    let submittedFile: SubmittedFile
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .foregroundStyle(.blue)
                .font(.title3)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(submittedFile.textFile?.name ?? NSLocalizedString("collectionsView.untitledFile", comment: "Untitled File"))
                    .font(.body)
                
                if let version = submittedFile.textFile?.currentVersion {
                    Text(String(format: NSLocalizedString("collectionsView.version", comment: "Version number"), version.versionNumber))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("collectionsView.fileVersion.accessibility", comment: "File and version"), submittedFile.textFile?.name ?? NSLocalizedString("collectionsView.untitledFile", comment: "Untitled"), submittedFile.textFile?.currentVersion?.versionNumber ?? 0))
    }
}

// MARK: - Add Files to Collection Sheet

struct AddFilesToCollectionSheet: View {
    @Bindable var submission: Submission
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    let onCancel: () -> Void
    let onFilesAdded: () -> Void
    
    @State private var selectedFiles: Set<UUID> = []
    @State private var selectedVersions: [UUID: Version] = [:]  // fileId -> selected version
    @State private var availableFiles: [TextFile] = []
    @State private var expandedFileId: UUID?  // For version picker expansion
    
    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle(NSLocalizedString("collectionsView.addFiles.title", comment: ""))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(NSLocalizedString("button.cancel", comment: "Cancel button")) {
                            onCancel()
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(NSLocalizedString("button.save", comment: "Save button")) {
                            addSelectedFiles()
                            onFilesAdded()
                            dismiss()
                        }
                        .disabled(selectedFiles.isEmpty)
                    }
                }
        }
        .onAppear {
            loadAvailableFiles()
        }
    }
    
    private var contentView: some View {
        Group {
            if !availableFiles.isEmpty {
                filesList
            } else {
                emptyState
            }
        }
    }
    
    private var filesList: some View {
        List {
            ForEach(availableFiles, id: \.id) { file in
                fileRowView(for: file)
            }
        }
    }
    
    private func fileRowView(for file: TextFile) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: selectedFiles.contains(file.id) ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selectedFiles.contains(file.id) ? .blue : .gray)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name)
                        .font(.body)
                    
                    if selectedFiles.contains(file.id),
                       let selectedVersion = selectedVersions[file.id] {
                        Text(String(format: NSLocalizedString("collectionsView.versionSelected", comment: "Version selected"), selectedVersion.versionNumber))
                            .font(.caption)
                            .foregroundStyle(.blue)
                    } else {
                        let latestVersion = file.versions?.count ?? 0
                        Text(String(format: NSLocalizedString("collectionsView.latestVersion", comment: "Latest version"), latestVersion))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if selectedFiles.contains(file.id) {
                    Image(systemName: expandedFileId == file.id ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                toggleFile(file.id)
            }
            
            // Version picker - shown when file is selected and expanded
            if selectedFiles.contains(file.id) && expandedFileId == file.id {
                versionPickerView(for: file)
                    .padding(.top, 8)
            }
        }
    }
    
    private func versionPickerView(for file: TextFile) -> some View {
        let versions: [Version] = file.sortedVersions

        return VStack(alignment: .leading, spacing: 8) {
            Text("collectionsView.selectVersion")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 32)

            if !versions.isEmpty {
                ForEach(versions, id: \.id) { version in
                    versionRow(version, for: file.id)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func versionComment(_ comment: String?) -> some View {
        if let comment, !comment.isEmpty {
            Text(comment)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func versionRow(_ version: Version, for fileID: UUID) -> some View {
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: NSLocalizedString("collectionsView.version", comment: "Version number"), version.versionNumber))
                    .font(.body)
                versionComment(version.comment)
            }

            Spacer()

            if selectedVersions[fileID]?.id == version.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.leading, 32)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedVersions[fileID] = version
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("collectionsView.noFilesAvailable.title", systemImage: "doc.text")
        } description: {
            Text("collectionsView.noFilesAvailable.description")
        }
    }
    
    private func toggleFile(_ fileId: UUID) {
        if selectedFiles.contains(fileId) {
            selectedFiles.remove(fileId)
            expandedFileId = nil
        } else {
            selectedFiles.insert(fileId)
            // Auto-select current version if not already selected
            if let file = availableFiles.first(where: { $0.id == fileId }) {
                selectedVersions[fileId] = file.currentVersion
            }
            expandedFileId = fileId
        }
    }
    
    private func loadAvailableFiles() {
        guard let project = submission.project else {
            availableFiles = []
            return
        }
        
        // Gather files with "Ready" workflow status from all content folders
        let contentFolders = (project.folders ?? []).filter { FolderCapabilityService.isContentFolder($0) }
        let readyFiles = contentFolders.flatMap { folder in
            (folder.textFiles ?? []).filter { $0.workflowStatus == .ready }
        }
        
        // Filter out files already in this collection
        let alreadyAdded = Set((submission.submittedFiles ?? []).compactMap { $0.textFile?.id })
        availableFiles = readyFiles.filter { !alreadyAdded.contains($0.id) }
    }
    
    private func addSelectedFiles() {
        // For each selected file, create a SubmittedFile in this collection
        for fileId in selectedFiles {
            if let file = availableFiles.first(where: { $0.id == fileId }) {
                // Use selected version or default to current version
                let selectedVersion = selectedVersions[fileId] ?? file.currentVersion
                
                // Create a SubmittedFile with the selected version
                let submittedFile = SubmittedFile(
                    submission: submission,
                    textFile: file,
                    version: selectedVersion,
                    status: .pending
                )
                
                // Add to submission
                if submission.submittedFiles == nil {
                    submission.submittedFiles = []
                }
                submission.submittedFiles?.append(submittedFile)
                modelContext.insert(submittedFile)
            }
        }
        
        // Save changes
        try? modelContext.save()
    }
}

// MARK: - Edit Version Sheet

struct EditVersionSheet: View {
    @Bindable var submittedFile: SubmittedFile
    var textFile: TextFile
    @Environment(\.dismiss) var dismiss
    
    let onCancel: () -> Void
    let onSave: () -> Void

    private var versions: [Version] {
        textFile.sortedVersions
    }

    private var hasVersions: Bool {
        !versions.isEmpty
    }

    @ViewBuilder
    private var editVersionContent: some View {
        if hasVersions {
            versionsList
        } else {
            noVersionsView
        }
    }

    private var versionsList: some View {
        List {
            Section {
                Text(textFile.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
            } header: {
                Text("collectionsView.editVersion.fileHeader")
            }

            Section {
                ForEach(versions, id: \.id) { version in
                    versionSelectionRow(version)
                }
            } header: {
                Text("collectionsView.editVersion.versionsHeader")
            }
        }
    }

    private var noVersionsView: some View {
        ContentUnavailableView {
            Label("collectionsView.editVersion.noVersions.title", systemImage: "doc.text")
        } description: {
            Text("collectionsView.editVersion.noVersions.description")
        }
    }

    @ViewBuilder
    private func versionCommentLine(_ comment: String?) -> some View {
        if let comment, !comment.isEmpty {
            Text(comment)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func versionSelectionRow(_ version: Version) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: NSLocalizedString("collectionsView.version", comment: "Version number"), version.versionNumber))
                    .font(.body)

                versionCommentLine(version.comment)

                Text(String(format: NSLocalizedString("collectionsView.characterCount", comment: "Character count"), version.content.count))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if submittedFile.version?.id == version.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.body)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            submittedFile.version = version
        }
    }
    
    var body: some View {
        editVersionContent
        .navigationTitle("collectionsView.editVersion.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(NSLocalizedString("button.cancel", comment: "Cancel button")) {
                    onCancel()
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(NSLocalizedString("button.done", comment: "Done button")) {
                    onSave()
                    dismiss()
                }
            }
        }
    }
}
