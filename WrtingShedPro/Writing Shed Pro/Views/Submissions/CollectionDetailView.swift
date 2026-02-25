//
//  CollectionDetailView.swift
//  Writing Shed Pro
//
//  Extracted from CollectionsView.swift during Feature 036 refactor.
//  These views are used by the Submissions system for collection-type submissions.
//

import SwiftUI
import SwiftData

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
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAddFilesSheet = false
    @State private var editingVersionItem: EditVersionItem?
    @State private var showSubmissionPicker = false
    @State private var showPrintError = false
    @State private var printErrorMessage = ""
    @State private var showSearchView = false
    
    private var submittedFiles: [SubmittedFile] {
        let files = submission.submittedFiles ?? []
        return files.sorted { file1, file2 in
            let name1 = file1.textFile?.name ?? ""
            let name2 = file2.textFile?.name ?? ""
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
    
    var body: some View {
        Group {
            if !submittedFiles.isEmpty {
                List {
                    ForEach(submittedFiles) { submittedFile in
                        if let file = submittedFile.textFile {
                            HStack {
                                NavigationLink(destination: FileEditView(file: file)) {
                                    CollectionFileRowView(submittedFile: submittedFile)
                                }
                                
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
                    }
                    .onDelete(perform: deleteFiles)
                }
                .listStyle(.plain)
            } else {
                ContentUnavailableView {
                    Label("collectionsView.detail.empty.title", systemImage: "doc.text")
                } description: {
                    Text("collectionsView.detail.empty.description")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("collectionsView.detail.empty.accessibility")
            }
        }
        .navigationTitle("collectionsView.detail.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onPopToRoot {
            dismiss()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PopToRootBackButton()
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(submission.name ?? NSLocalizedString("collectionsView.untitled", comment: "Untitled Collection"))
                        .font(.headline)
                        .lineLimit(1)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Search button
                    if !submittedFiles.isEmpty {
                        Button {
                            showSearchView = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .accessibilityLabel("Search files in collection")
                        .help("Search and replace across all files in this collection")
                    }
                    
                    // More menu
                    Menu {
                        Button(action: { showAddFilesSheet = true }) {
                            Label("Add Files", systemImage: "plus")
                        }
                        
                        if !submittedFiles.isEmpty {
                            Divider()
                            
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
            }
        }
        .sheet(isPresented: $showSearchView) {
            MultiFileSearchView(collection: submission)
        }
        .sheet(isPresented: $showAddFilesSheet) {
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
        .sheet(item: $editingVersionItem) { item in
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
        .sheet(isPresented: $showSubmissionPicker) {
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
        .onAppear {
            // Prefetch submittedFiles relationship to ensure it's loaded before first access
            let count = submission.submittedFiles?.count ?? 0
            _ = count
        }
        .alert("Print Error", isPresented: $showPrintError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(printErrorMessage)
        }
    }
    
    // MARK: - Printing
    
    /// Handle print collection action
    private func printCollection() {
        #if DEBUG
        print("🖨️ Print Collection button tapped")
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
    
    private func createSubmissionFromCollection(to publication: Publication, name: String, expectedResponseDate: Date? = nil, reminderDate: Date? = nil) {
        guard let project = submission.project else { return }
        
        // Create new Submission as Publication Submission
        let pubSubmission = Submission(
            publication: publication,
            project: project
        )
        // Use provided name, or fall back to collection name
        pubSubmission.name = name.isEmpty ? submission.name : name
        pubSubmission.collectionDescription = submission.collectionDescription
        pubSubmission.isCollection = false  // This is a submission to publication, not a collection
        pubSubmission.returnExpectedBy = expectedResponseDate
        
        // Schedule reminder notification if requested
        if let reminderDate = reminderDate {
            pubSubmission.reminderDate = reminderDate
            let pubName = publication.name
            let subName = name.isEmpty ? (submission.name ?? "Submission") : name
            Task {
                let notifId = await NotificationReminderService.shared.scheduleSubmissionReminder(
                    submissionId: UUID().uuidString,
                    publicationName: pubName,
                    submissionName: subName,
                    reminderDate: reminderDate
                )
                if let notifId = notifId {
                    await MainActor.run {
                        pubSubmission.reminderNotificationId = notifId
                    }
                }
            }
        }
        
        // Copy SubmittedFiles from Collection with preserved versions
        let copiedFiles = (submission.submittedFiles ?? []).map { original in
            SubmittedFile(
                submission: pubSubmission,
                textFile: original.textFile,
                version: original.version,  // Preserve version!
                status: .pending
            )
        }
        
        pubSubmission.submittedFiles = copiedFiles
        
        // Save to database
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
                
                if let version = submittedFile.version {
                    Text(String(format: NSLocalizedString("collectionsView.version", comment: "Version number"), version.versionNumber))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("collectionsView.fileVersion.accessibility", comment: "File and version"), submittedFile.textFile?.name ?? NSLocalizedString("collectionsView.untitledFile", comment: "Untitled"), submittedFile.version?.versionNumber ?? 0))
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
        VStack(alignment: .leading, spacing: 8) {
            Text("collectionsView.selectVersion")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 32)
            
            let versions: [Version] = file.sortedVersions
            if !versions.isEmpty {
                ForEach(versions, id: \.id) { version in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: NSLocalizedString("collectionsView.version", comment: "Version number"), version.versionNumber))
                                .font(.body)
                            
                            if let comment = version.comment, !comment.isEmpty {
                                Text(comment)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        if selectedVersions[file.id]?.id == version.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.leading, 32)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedVersions[file.id] = version
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal, 16)
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
        // Get the Ready folder from the project
        guard let project = submission.project else {
            availableFiles = []
            return
        }
        
        let readyFolder = project.folders?.first { $0.name == "Ready" }
        guard let readyFolder = readyFolder else {
            availableFiles = []
            return
        }
        
        // Get all text files in Ready folder
        let readyFiles = readyFolder.textFiles ?? []
        
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
    
    var body: some View {
        let versions: [Version] = textFile.sortedVersions
        
        return Group {
            if !versions.isEmpty {
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
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(format: NSLocalizedString("collectionsView.version", comment: "Version number"), version.versionNumber))
                                        .font(.body)
                                    
                                    if let comment = version.comment, !comment.isEmpty {
                                        Text(comment)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    
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
                    } header: {
                        Text("collectionsView.editVersion.versionsHeader")
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("collectionsView.editVersion.noVersions.title", systemImage: "doc.text")
                } description: {
                    Text("collectionsView.editVersion.noVersions.description")
                }
            }
        }
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
