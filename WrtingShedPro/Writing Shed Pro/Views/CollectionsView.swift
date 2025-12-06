//
//  CollectionsView.swift
//  Writing Shed Pro
//
//  Feature 008c: Collections Management System
//  Collections are Submission objects (where publication == nil) organized in the Collections folder
//

import SwiftUI
import SwiftData

// MARK: - Edit Version Item (for sheet presentation)

struct EditVersionItem: Identifiable {
    let submittedFile: SubmittedFile
    let textFile: TextFile
    
    var id: UUID { submittedFile.id }
}

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
    
    // State for sorting
    @State private var sortOrder: CollectionSortOrder = .byCreationDate
    
    // State for edit mode (multi-select)
    @State private var editMode: EditMode = .inactive
    @State private var selectedCollectionIDs: Set<UUID> = []
    @State private var showPublicationPicker = false
    
    // State for delete confirmation
    @State private var showDeleteConfirmation = false
    @State private var collectionsToDelete: [Submission] = []
    
    // State for rename
    @State private var showRenameSheet = false
    @State private var collectionToRename: Submission?
    
    // Query all Submissions for this project
    @Query private var allSubmissions: [Submission]
    
    init(project: Project) {
        self.project = project
        
        // Configure query to fetch only Submissions for this project where publication is nil (Collections)
        let projectID = project.id
        _allSubmissions = Query(
            filter: #Predicate<Submission> { submission in
                submission.publication == nil && submission.project?.id == projectID
            },
            sort: [SortDescriptor(\Submission.createdDate, order: .reverse)]
        )
    }
    
    // Collections are the filtered submissions, sorted by user preference
    private var sortedCollections: [Submission] {
        return CollectionSortService.sort(allSubmissions, by: sortOrder)
    }
    
    // Get selected collections based on selectedCollectionIDs
    private var selectedCollections: [Submission] {
        sortedCollections.filter { selectedCollectionIDs.contains($0.id) }
    }
    
    // Whether edit mode is currently active
    private var isEditMode: Bool {
        editMode == .active
    }
    
    // Whether to show the bottom toolbar (edit mode + items selected)
    private var showToolbar: Bool {
        isEditMode && !selectedCollectionIDs.isEmpty
    }
    
    var body: some View {
        Group {
            if !sortedCollections.isEmpty {
                // Show list of collections
                List {
                    ForEach(sortedCollections) { collection in
                        collectionRow(for: collection)
                    }
                    .onDelete(perform: isEditMode ? nil : deleteCollections)
                    .onMove(perform: isEditMode ? moveCollections : nil)
                }
                .listStyle(.plain)
                .toolbar {
                    // Bottom toolbar for multi-select actions (only in edit mode)
                    ToolbarItemGroup(placement: .bottomBar) {
                        if showToolbar {
                            bottomToolbarContent
                        }
                    }
                }
            } else {
                // Empty state
                ContentUnavailableView {
                    Label("collectionsView.empty.title", systemImage: "tray.2")
                } description: {
                    Text("collectionsView.empty.description")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("collectionsView.empty.accessibility")
            }
        }
        .navigationTitle("collectionsView.title")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Sort menu
                    if !sortedCollections.isEmpty {
                        Menu {
                            ForEach(CollectionSortService.sortOptions(), id: \.order) { option in
                                Button(action: {
                                    sortOrder = option.order
                                }) {
                                    HStack {
                                        Text(option.title)
                                        if sortOrder == option.order {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .accessibilityLabel("collections.sort.accessibility")
                        .disabled(editMode == .active)
                    }
                    
                    // Add collection button
                    Button {
                        showAddCollectionSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("collectionsView.addCollection.accessibility")
                    
                    // Edit/Done button
                    if !sortedCollections.isEmpty {
                        Button {
                            withAnimation {
                                editMode = editMode == .inactive ? .active : .inactive
                                if editMode == .inactive {
                                    selectedCollectionIDs.removeAll()
                                }
                            }
                        } label: {
                            Text(editMode == .inactive ? "collectionsView.edit" : "collectionsView.done")
                        }
                    }
                }
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
        .sheet(isPresented: $showPublicationPicker) {
            if !selectedCollections.isEmpty {
                NavigationStack {
                    SubmissionPickerView(
                        project: project,
                        filesToSubmit: nil,
                        collectionToSubmit: selectedCollections.first,
                        onPublicationSelected: { publication in
                            // Handle submission to publication
                            submitCollectionsToPublication(publication)
                            showPublicationPicker = false
                        },
                        onCancel: {
                            showPublicationPicker = false
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            if let collection = collectionToRename {
                RenameCollectionModal(
                    collection: collection,
                    collectionsInProject: sortedCollections,
                    onRename: { _ in
                        selectedCollectionIDs.removeAll()
                        withAnimation {
                            editMode = .inactive
                        }
                    }
                )
            }
        }
        .confirmationDialog(
            String(format: NSLocalizedString("collectionsView.deleteConfirmation.title", comment: "Delete confirmation"), 
                   collectionsToDelete.count,
                   collectionsToDelete.count == 1 ? NSLocalizedString("collectionsView.collection.singular", comment: "collection") : NSLocalizedString("collectionsView.collection.plural", comment: "collections")),
            isPresented: $showDeleteConfirmation
        ) {
            Button("button.cancel", role: .cancel) {
                collectionsToDelete = []
            }
            Button("collections.button.delete", role: .destructive) {
                confirmDelete()
            }
        } message: {
            Text("collections.delete.confirmation.message")
        }
    }
    
    // MARK: - View Builders
    
    @ViewBuilder
    private func collectionRow(for collection: Submission) -> some View {
        if isEditMode {
            // In edit mode, use tap gesture for selection
            HStack {
                Image(systemName: selectedCollectionIDs.contains(collection.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedCollectionIDs.contains(collection.id) ? .blue : .gray)
                    .imageScale(.large)
                
                Image(systemName: "tray.2.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(collection.name ?? NSLocalizedString("collectionsView.untitled", comment: "Untitled Collection"))
                        .font(.body)
                    
                    // Show count of files in this collection
                    let fileCount = collection.submittedFiles?.count ?? 0
                    Text(String(format: NSLocalizedString("collections.files.count", comment: "Files in collection"), fileCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                toggleSelection(for: collection)
            }
        } else {
            // In normal mode, use NavigationLink
            NavigationLink(destination: CollectionDetailView(submission: collection)) {
                HStack {
                    Image(systemName: "tray.2.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(collection.name ?? NSLocalizedString("collectionsView.untitled", comment: "Untitled Collection"))
                            .font(.body)
                        
                        // Show count of files in this collection
                        let fileCount = collection.submittedFiles?.count ?? 0
                        Text(String(format: NSLocalizedString("collections.files.count", comment: "Files in collection"), fileCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    @ViewBuilder
    private var bottomToolbarContent: some View {
        Button(role: .destructive) {
            deleteSelectedCollections()
        } label: {
            Label(
                String(format: NSLocalizedString("collectionsView.deleteCount", comment: "Delete count"), selectedCollections.count),
                systemImage: "trash"
            )
        }
        .disabled(selectedCollections.isEmpty)
        .accessibilityLabel("collectionsView.deleteSelected.accessibility")
        
        Spacer()
        
        Button {
            renameSelectedCollection()
        } label: {
            Label(
                "collectionsView.rename",
                systemImage: "pencil"
            )
        }
        .disabled(selectedCollections.count != 1)
        .accessibilityLabel("collectionsView.rename.accessibility")
        
        Spacer()
        
        Button {
            showPublicationPicker = true
        } label: {
            Label(
                "collectionsView.addToPublication",
                systemImage: "book.badge.plus"
            )
        }
        .disabled(selectedCollections.isEmpty)
        .accessibilityLabel("collectionsView.addToPublication.accessibility")
        
        Spacer()
    }
    
    // MARK: - Actions
    
    private func toggleSelection(for collection: Submission) {
        if selectedCollectionIDs.contains(collection.id) {
            selectedCollectionIDs.remove(collection.id)
        } else {
            selectedCollectionIDs.insert(collection.id)
        }
    }
    
    private func renameSelectedCollection() {
        guard let collection = selectedCollections.first else { return }
        collectionToRename = collection
        showRenameSheet = true
    }
    
    private func deleteSelectedCollections() {
        prepareDelete(selectedCollections)
    }
    
    private func deleteCollections(at offsets: IndexSet) {
        let collections = offsets.map { sortedCollections[$0] }
        prepareDelete(collections)
    }
    
    private func prepareDelete(_ collections: [Submission]) {
        collectionsToDelete = collections
        showDeleteConfirmation = true
    }
    
    private func confirmDelete() {
        for collection in collectionsToDelete {
            modelContext.delete(collection)
        }
        
        do {
            try modelContext.save()
            collectionsToDelete = []
            selectedCollectionIDs.removeAll()
            withAnimation {
                editMode = .inactive
            }
        } catch {
            // Handle error silently for now
        }
    }
    
    // MARK: - Reordering
    
    private func moveCollections(from source: IndexSet, to destination: Int) {
        // Switch to user order sort when user manually reorders
        if sortOrder != .byUserOrder {
            sortOrder = .byUserOrder
        }
        
        guard let sourceIndex = source.first else { return }
        
        // If dropping in same position, do nothing
        if destination == sourceIndex || destination == sourceIndex + 1 {
            return
        }
        
        let currentCollections = sortedCollections
        
        if sourceIndex < destination {
            // Moving item down the list - shift items up to fill gap
            for i in sourceIndex + 1..<destination {
                guard i < currentCollections.count else { continue }
                let currentOrder = currentCollections[i].userOrder ?? i
                currentCollections[i].userOrder = currentOrder - 1
            }
            currentCollections[sourceIndex].userOrder = destination - 1
        } else {
            // Moving item up the list - shift items down to make room
            let baseOrder = currentCollections[destination].userOrder ?? destination
            for i in destination..<sourceIndex {
                guard i < currentCollections.count else { continue }
                let currentOrder = currentCollections[i].userOrder ?? i
                currentCollections[i].userOrder = currentOrder + 1
            }
            currentCollections[sourceIndex].userOrder = baseOrder
        }
        
        // Save the changes
        try? modelContext.save()
    }
    
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
    
    private func submitCollectionsToPublication(_ publication: Publication) {
        // For each selected collection, create submitted file records for all its files to the publication
        for collection in selectedCollections {
            if let submittedFiles = collection.submittedFiles {
                for submittedFile in submittedFiles {
                    // Create a new submission for this publication
                    let submission = Submission(
                        publication: publication,
                        project: project,
                        submittedDate: Date(),
                        notes: nil
                    )
                    modelContext.insert(submission)
                    
                    // Create submitted file record for the text file
                    if let textFile = submittedFile.textFile, let version = submittedFile.version {
                        let newSubmittedFile = SubmittedFile(
                            submission: submission,
                            textFile: textFile,
                            version: version,
                            status: .pending,
                            statusDate: Date(),
                            project: project
                        )
                        modelContext.insert(newSubmittedFile)
                    }
                }
            }
        }
        
        do {
            try modelContext.save()
            selectedCollectionIDs.removeAll()
            withAnimation {
                editMode = .inactive
            }
        } catch {
            print("Error submitting collections to publication: \(error)")
            // TODO: Show error alert
        }
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
                    .accessibilityLabel("collectionsView.form.name.accessibility")
                    
                    if let errorMessage = error {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                } header: {
                    Text(NSLocalizedString("collections.form.name.label", comment: "Collection name label"))
                }
            }
            .navigationTitle("collectionsView.form.title")
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
    @State private var editingVersionItem: EditVersionItem?
    @State private var showSubmissionPicker = false
    @State private var showPrintError = false
    @State private var printErrorMessage = ""
    
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
                                    Image(systemName: "square.and.pencil.circle")
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(submission.name ?? NSLocalizedString("collectionsView.untitled", comment: "Untitled Collection"))
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
        print("🖨️ Print Collection button tapped")
        
        // Get the view controller to present from
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let viewController = window.rootViewController else {
            print("❌ Could not find view controller for print dialog")
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
                print("❌ Print failed: \(error.localizedDescription)")
                printErrorMessage = error.localizedDescription
                showPrintError = true
            } else if success {
                print("✅ Print completed successfully")
            } else {
                print("⚠️ Print was cancelled")
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
            
            let versions = file.sortedVersions
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
        let versions = textFile.sortedVersions
        
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

