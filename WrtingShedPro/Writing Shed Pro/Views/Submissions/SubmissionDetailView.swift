//
//  SubmissionDetailView.swift
//  Writing Shed Pro
//
//  Feature 008b Phase 3: Submissions UI
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SubmissionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var submission: Submission
    
    @State private var showingDeleteConfirmation = false
    @State private var showPrintError = false
    @State private var printErrorMessage = ""
    @State private var showingRecordResponse = false
    @State private var responseDate: Date = Date()
    @State private var hasResponseTime: Bool = false
    @State private var responseTimeDays: Int = 90
    
    // Export state
    @State private var showExportMenu = false
    @State private var showExportSaveDialog = false
    @State private var exportFormat: ExportFormat = .rtf
    @State private var exportData: Data?
    @State private var exportFilename: String = ""
    @State private var showExportImageWarning = false
    @State private var pendingExportAction: (() -> Void)?
    
    // Copy to Project state
    @State private var showCopyToProject = false
    @State private var showCopyResult = false
    @State private var copyResultMessage = ""
    @State private var copyResultIsError = false

    private var submissionFiles: [SubmittedFile] {
        submission.submittedFiles ?? []
    }

    private var hasSubmissionFiles: Bool {
        !submissionFiles.isEmpty
    }
    
    var body: some View {
        baseSubmissionView
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
                    print("✅ Export saved successfully")
                    #endif
                case .failure(let error):
                    #if DEBUG
                    print("❌ Export save failed: \(error)")
                    #endif
                }
            }
        )
        .alert("Print Error", isPresented: $showPrintError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(printErrorMessage)
        }
        .sheet(isPresented: $showCopyToProject) {
            copyToProjectSheet
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
        .onAppear {
            hasResponseTime = submission.typicalResponseDays != nil
            responseTimeDays = submission.typicalResponseDays ?? 90
        }
        .confirmationDialog(
            NSLocalizedString("submissions.delete.title", comment: "Delete submission"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                deleteSubmission()
            }
        } message: {
            Text(NSLocalizedString("submissions.delete.message", comment: "Delete message"))
        }
    }

    private var baseSubmissionView: some View {
        List {
            publicationSection
            detailsSection
            submittedFilesSection
            responseSection
            deleteSection
        }
        .navigationTitle(Text(NSLocalizedString("submissions.detail.title", comment: "Submission details")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    actionsMenu
                }
            }
        }
    }

    @ViewBuilder
    private var publicationSection: some View {
        Section {
            if let publication = submission.publication {
                NavigationLink(destination: PublicationDetailView(publication: publication)) {
                    HStack {
                        Text(publication.type?.icon ?? "")
                        Text(publication.name)
                    }
                }
                .accessibilityLabel(Text(String(format: NSLocalizedString("accessibility.view.publication", comment: "View publication"), publication.name)))
            }
        } header: {
            Text(NSLocalizedString("publications.form.name.label", comment: "Publication"))
        }
    }

    private var detailsSection: some View {
        Section {
            LabeledContent(NSLocalizedString("submissions.submitted.label", comment: "Submitted")) {
                Text(submission.submittedDate, style: .date)
            }

            if let expectedDate = submission.returnExpectedBy {
                LabeledContent(NSLocalizedString("submissions.expectedBy.label", comment: "Response Expected")) {
                    Text(expectedDate, style: .date)
                }
            }

            Toggle(isOn: $hasResponseTime) {
                Text(NSLocalizedString("publications.form.responseTime.label", comment: "Expected Response Time"))
            }
            .onChange(of: hasResponseTime) { _, newValue in
                submission.typicalResponseDays = newValue ? responseTimeDays : nil
                submission.modifiedDate = Date()
            }

            if hasResponseTime {
                Stepper(
                    value: $responseTimeDays,
                    in: 1...365,
                    step: responseTimeDays < 14 ? 1 : (responseTimeDays < 60 ? 7 : 30)
                ) {
                    Text(String(format: NSLocalizedString("publications.responseTime.days", comment: "N days"), responseTimeDays))
                }
                .onChange(of: responseTimeDays) { _, newValue in
                    submission.typicalResponseDays = newValue
                    submission.modifiedDate = Date()
                }
            }

            if let returnedDate = submission.returnedOn {
                LabeledContent(NSLocalizedString("submissions.returnedOn.label", comment: "Response Received")) {
                    Text(returnedDate, style: .date)
                }
            }

            if let notes = submission.notes {
                LabeledContent(NSLocalizedString("submissions.notes.label", comment: "Notes")) {
                    Text(notes)
                }
            }
        } header: {
            Text(NSLocalizedString("submissions.details.label", comment: "Details"))
        }
    }

    private var submittedFilesSection: some View {
        Section {
            if hasSubmissionFiles {
                ForEach(submissionFiles) { submittedFile in
                    SubmittedFileRow(
                        submittedFile: submittedFile,
                        onStatusChange: { status in
                            updateStatus(submittedFile, to: status)
                        }
                    )
                }
            } else {
                Text(NSLocalizedString("submissions.no.files", comment: "No files"))
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(String(format: NSLocalizedString("submissions.files.label", comment: "Files"), submission.fileCount))
        }
    }

    @ViewBuilder
    private var responseSection: some View {
        if submission.returnedOn == nil {
            Section {
                if showingRecordResponse {
                    DatePicker(
                        NSLocalizedString("submissions.returnedOn.label", comment: "Response Received"),
                        selection: $responseDate,
                        displayedComponents: .date
                    )

                    Button(NSLocalizedString("submissions.saveResponse", comment: "Save Response Date")) {
                        submission.returnedOn = responseDate
                        submission.modifiedDate = Date()
                        showingRecordResponse = false
                    }
                } else {
                    Button {
                        showingRecordResponse = true
                    } label: {
                        Label(NSLocalizedString("submissions.recordResponse", comment: "Record Response"), systemImage: "calendar.badge.checkmark")
                    }
                }
            } header: {
                Text(NSLocalizedString("submissions.response.section", comment: "Response"))
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label(NSLocalizedString("submissions.delete.button", comment: "Delete submission"), systemImage: "trash")
            }
            .accessibilityLabel(Text(NSLocalizedString("accessibility.delete.submission", comment: "Delete submission")))
            .accessibilityHint(Text(NSLocalizedString("accessibility.delete.submission.hint", comment: "Delete submission hint")))
        }
    }

    private var actionsMenu: some View {
        Menu {
            Button(action: { prepareExport() }) {
                Label(NSLocalizedString("button.export", comment: "Export"), systemImage: "square.and.arrow.up")
            }
            .disabled(!hasSubmissionFiles)

            Button(action: { printSubmission() }) {
                Label(NSLocalizedString("button.print", comment: "Print"), systemImage: "printer")
            }
            .disabled(!hasSubmissionFiles)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Actions")
    }

    @ViewBuilder
    private var copyToProjectSheet: some View {
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

    @ViewBuilder
    private var exportImageWarningButtons: some View {
        Button(NSLocalizedString("export.imageWarning.continue", comment: "Continue")) {
            pendingExportAction?()
            pendingExportAction = nil
        }
        Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
            pendingExportAction = nil
        }
    }

    private var exportImageWarningMessage: some View {
        Text(NSLocalizedString("export.imageWarning.message", comment: "Images will not be included"))
    }
    
    private func deleteSubmission() {
        modelContext.delete(submission)
        dismiss()
    }
    
    // MARK: - Printing
    
    /// Handle print submission action
    private func printSubmission() {
        #if DEBUG
        print("🖨️ Print Submission button tapped")
        #endif
        
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
        
        PrintService.printSubmission(
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
    
    // MARK: - Export
    
    private func prepareExport() {
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
            exportSubmissionFiles(format: .pdf)
        }
        Button(ExportFormat.rtf.localizedName) {
            pendingExportAction = { exportSubmissionFiles(format: .rtf) }
            showImageWarningAfterDelay()
        }
        Button(ExportFormat.html.localizedName) {
            exportSubmissionFiles(format: .html)
        }
        Button(ExportFormat.word.localizedName) {
            exportSubmissionFiles(format: .word)
        }
        Button(ExportFormat.markdown.localizedName) {
            pendingExportAction = { exportSubmissionFiles(format: .markdown) }
            showImageWarningAfterDelay()
        }
        Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
    }
    
    private func showImageWarningAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showExportImageWarning = true
        }
    }
    
    private func exportSubmissionFiles(format: ExportFormat) {
        self.exportFormat = format
        
        let files = (submission.submittedFiles ?? [])
            .compactMap { $0.version ?? $0.textFile?.currentVersion }
        
        guard !files.isEmpty else { return }
        
        var attributedStrings: [NSAttributedString] = []
        let combinedContent = NSMutableAttributedString()
        
        for version in files {
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
            combinedContent.append(content)
            combinedContent.append(NSAttributedString(string: "\u{000C}"))
        }
        
        guard !attributedStrings.isEmpty else { return }
        
        let filename = submission.name ?? "Submission"
        
        Task {
            do {
                let data: Data
                switch format {
                case .pdf:
                    let textFiles = (submission.submittedFiles ?? [])
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
                    exportData = data
                    exportFilename = "\(filename).\(format.fileExtension)"
                    showExportSaveDialog = true
                }
            } catch {
                #if DEBUG
                print("❌ Export failed: \(error)")
                #endif
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
    
    /// TextFiles from all submitted files.
    private var filesToCopyToProject: [TextFile] {
        (submission.submittedFiles ?? []).compactMap { $0.textFile }
    }
    
    /// Copy files to a destination project, placing them in the matching folder by name.
    private func copyFilesToProject(_ files: [TextFile], destination: Project) {
        guard !files.isEmpty else { return }
        
        let sourceFolderName = submission.project?.folders?.first(where: { FolderCapabilityService.canAddFile(to: $0) })?.name ?? "Files"
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
    
    private func updateStatus(_ submittedFile: SubmittedFile, to status: SubmissionStatus) {
        submittedFile.status = status
        submittedFile.statusDate = Date()
        
        // If accepted, update file's workflow status to published
        if status == .accepted, let file = submittedFile.textFile {
            file.workflowStatus = .published
            file.modifiedDate = Date()
        }
    }
}

struct SubmittedFileRow: View {
    @Bindable var submittedFile: SubmittedFile
    let onStatusChange: (SubmissionStatus) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let file = submittedFile.textFile {
                Text(file.name)
                    .font(.headline)
            }
            
            HStack {
                if let version = submittedFile.textFile?.currentVersion {
                    Text(String(format: NSLocalizedString("submissions.version.label", comment: "Version"), version.versionNumber))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Status picker
                Menu {
                    Button {
                        onStatusChange(.pending)
                    } label: {
                        Label(NSLocalizedString("submissions.status.pending", comment: "Pending"), 
                              systemImage: "clock")
                    }
                    
                    Button {
                        onStatusChange(.accepted)
                    } label: {
                        Label(NSLocalizedString("submissions.status.accepted", comment: "Accepted"), 
                              systemImage: "checkmark.circle")
                    }
                    
                    Button {
                        onStatusChange(.rejected)
                    } label: {
                        Label(NSLocalizedString("submissions.status.rejected", comment: "Rejected"), 
                              systemImage: "xmark.circle")
                    }
                } label: {
                    HStack {
                        Text(submittedFile.status?.icon ?? "")
                        Text(submittedFile.status?.displayName ?? NSLocalizedString("submissions.status.unknown", comment: "Unknown"))
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundStyle(statusColor)
                    .cornerRadius(8)
                }
                .accessibilityLabel(Text(String(format: NSLocalizedString("accessibility.change.status", comment: "Change status"), 
                                               submittedFile.status?.displayName ?? "")))
            }
            
            if let statusDate = submittedFile.statusDate {
                Text(String(format: NSLocalizedString("submissions.updated.on", comment: "Updated on"), 
                           statusDate.formatted(date: .abbreviated, time: .omitted)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
    
    private var statusColor: Color {
        guard let status = submittedFile.status else { return .gray }
        return status.color
    }
}