//
//  CollectionsView.swift
//  Writing Shed Pro
//
//  Feature 008c: Collections Management System
//  Collections are Submission objects (where publication == nil) organized in the Collections folder
//

import SwiftUI
import SwiftData

/// View for displaying Collections in the Collections folder
/// Collections are Submission objects with no publication attached
struct CollectionsView: View {
    let project: Project
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    // State for add collection sheet
    @State private var showAddCollectionSheet = false
    @State private var newCollectionName: String = ""
    @State private var newCollectionNameError: String?
    
    // State for navigation
    @State private var selectedCollection: Submission?
    @State private var navigateToCollection = false
    
    // Query all Submissions - we'll filter in memory
    @Query(sort: [SortDescriptor(\Submission.createdDate, order: .reverse)]) 
    private var allSubmissions: [Submission]
    
    init(project: Project) {
        self.project = project
    }
    
    // Filter submissions to get only Collections (where publication is nil and matches project)
    private var sortedCollections: [Submission] {
        return allSubmissions.filter { submission in
            submission.publication == nil && submission.project?.id == project.id
        }
    }
    
    var body: some View {
        Group {
            if !sortedCollections.isEmpty {
                // Show list of collections
                List {
                    ForEach(sortedCollections) { collection in
                        NavigationLink(destination: CollectionDetailView(submission: collection)) {
                            CollectionRowView(submission: collection)
                        }
                    }
                    .onDelete(perform: deleteCollections)
                }
                .listStyle(.plain)
            } else {
                // Empty state
                ContentUnavailableView {
                    Label("No Collections", systemImage: "tray.2")
                } description: {
                    Text("Create your first Collection to organize your submissions")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No Collections yet")
            }
        }
        .navigationTitle("Collections")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddCollectionSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Collection")
            }
        }
        .sheet(isPresented: $showAddCollectionSheet) {
            AddCollectionSheet(
                project: project,
                collectionName: $newCollectionName,
                error: $newCollectionNameError,
                onCancel: {
                    showAddCollectionSheet = false
                    newCollectionName = ""
                    newCollectionNameError = nil
                },
                onSave: { name in
                    addCollection(name: name)
                }
            )
        }
    }
    
    // MARK: - Actions
    
    private func addCollection(name: String) {
        // Validate collection name
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        // Check if name is empty
        if trimmedName.isEmpty {
            newCollectionNameError = NSLocalizedString(
                "collections.error.emptyName",
                comment: "Error message for empty collection name"
            )
            return
        }
        
        // Create new Submission (Collection)
        let newSubmission = Submission(
            publication: nil,
            project: project
        )
        newSubmission.name = trimmedName
        
        do {
            modelContext.insert(newSubmission)
            try modelContext.save()
            showAddCollectionSheet = false
            newCollectionName = ""
            newCollectionNameError = nil
        } catch {
            newCollectionNameError = NSLocalizedString(
                "collections.error.saveFailed",
                comment: "Error message when saving collection failed"
            )
        }
    }
    
    private func deleteCollections(at offsets: IndexSet) {
        for index in offsets {
            let collection = sortedCollections[index]
            modelContext.delete(collection)
        }
        
        do {
            try modelContext.save()
        } catch {
            // Handle error silently for now - user sees collection still in list
        }
    }
}

// MARK: - Collection Row View

struct CollectionRowView: View {
    let submission: Submission
    
    private var submissionCount: Int {
        return submission.submittedFiles?.count ?? 0
    }
    
    private var collectionName: String {
        return submission.name ?? "Untitled Collection"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.2.fill")
                .foregroundStyle(.blue)
                .font(.title3)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(collectionName)
                    .font(.body)
                
                Text("\(submissionCount) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(collectionName), \(submissionCount) files")
    }
}

// MARK: - Add Collection Sheet

struct AddCollectionSheet: View {
    let project: Project
    @Binding var collectionName: String
    @Binding var error: String?
    
    let onCancel: () -> Void
    let onSave: (String) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        NSLocalizedString("collections.form.name.placeholder", comment: "Placeholder for collection name"),
                        text: $collectionName
                    )
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel("Collection name")
                    
                    if let errorMessage = error {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                } header: {
                    Text(NSLocalizedString("collections.form.name.label", comment: "Collection name label"))
                }
            }
            .navigationTitle("New Collection")
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
                        onSave(collectionName)
                        dismiss()
                    }
                    .disabled(collectionName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Collection Detail View

struct CollectionDetailView: View {
    @Bindable var submission: Submission
    @Environment(\.modelContext) var modelContext
    
    @State private var showAddFilesSheet = false
    @State private var editingSubmittedFile: SubmittedFile?
    @State private var showVersionPicker = false
    @State private var showSubmissionPicker = false
    
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
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    NavigationLink(destination: FileEditView(file: file)) {
                                        CollectionFileRowView(submittedFile: submittedFile)
                                    }
                                    
                                    Button {
                                        editingSubmittedFile = submittedFile
                                        showVersionPicker = true
                                    } label: {
                                        Image(systemName: "pencil.circle")
                                            .foregroundStyle(.blue)
                                            .font(.body)
                                    }
                                    .accessibilityLabel("Edit version")
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteFiles)
                }
                .listStyle(.plain)
            } else {
                ContentUnavailableView {
                    Label("No Files in Collection", systemImage: "doc.text")
                } description: {
                    Text("Add files from your Ready folder to this collection")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No files in collection yet")
            }
        }
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(submission.name ?? "Untitled Collection")
                        .font(.headline)
                        .lineLimit(1)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showAddFilesSheet = true }) {
                        Label("Add Files", systemImage: "plus")
                    }
                    
                    if !submittedFiles.isEmpty {
                        Divider()
                        
                        Button(action: { showSubmissionPicker = true }) {
                            Label("Submit to Publication", systemImage: "paperplane")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Collection actions")
            }
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
        .sheet(isPresented: $showVersionPicker) {
            if let submittedFile = editingSubmittedFile {
                NavigationStack {
                    EditVersionSheet(
                        submittedFile: submittedFile,
                        onCancel: {
                            showVersionPicker = false
                            editingSubmittedFile = nil
                        },
                        onSave: {
                            showVersionPicker = false
                            editingSubmittedFile = nil
                            try? modelContext.save()
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showSubmissionPicker) {
            if let project = submission.project {
                NavigationStack {
                    SubmissionPickerView(
                        project: project,
                        filesToSubmit: nil,
                        collectionToSubmit: submission,
                        onPublicationSelected: { publication in
                            createSubmissionFromCollection(to: publication)
                            showSubmissionPicker = false
                        },
                        onCancel: {
                            showSubmissionPicker = false
                        }
                    )
                }
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
    
    private func createSubmissionFromCollection(to publication: Publication) {
        guard let project = submission.project else { return }
        
        // Create new Submission as Publication Submission
        let pubSubmission = Submission(
            publication: publication,
            project: project
        )
        pubSubmission.name = submission.name  // Preserve collection name in submission
        pubSubmission.collectionDescription = submission.collectionDescription
        
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
                Text(submittedFile.textFile?.name ?? "Untitled File")
                    .font(.body)
                
                if let version = submittedFile.version {
                    Text("Version \(version.versionNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(submittedFile.textFile?.name ?? "Untitled"), Version \(submittedFile.version?.versionNumber ?? 0)")
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
                .navigationTitle("Add Files to Collection")
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
                        Text("Version \(selectedVersion.versionNumber) selected")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    } else {
                        let latestVersion = file.versions?.count ?? 0
                        Text("Latest version: \(latestVersion)")
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
            Text("Select Version")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 32)
            
            let versions = file.sortedVersions
            if !versions.isEmpty {
                ForEach(versions, id: \.id) { version in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Version \(version.versionNumber)")
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
            Label("No Files Available", systemImage: "doc.text")
        } description: {
            Text("All files from Ready folder are already in this collection or there are no Ready files")
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
    @Environment(\.dismiss) var dismiss
    
    let onCancel: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        Group {
                if let file = submittedFile.textFile {
                    let versions = file.sortedVersions
                    if !versions.isEmpty {
                        List {
                            Section {
                                Text(file.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            } header: {
                                Text("File")
                            }
                            
                            Section {
                                ForEach(versions, id: \.id) { version in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Version \(version.versionNumber)")
                                                .font(.body)
                                            
                                            if let comment = version.comment, !comment.isEmpty {
                                                Text(comment)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                            
                                            Text("\(version.content.count) characters")
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
                                Text("Available Versions")
                            }
                        }
                    } else {
                        ContentUnavailableView {
                            Label("No Versions", systemImage: "doc.text")
                        } description: {
                            Text("This file has no versions")
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label("File Not Found", systemImage: "doc.text.xmark")
                    } description: {
                        Text("The file associated with this submission could not be found")
                    }
                }
        }
        .navigationTitle("Select Version")
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

