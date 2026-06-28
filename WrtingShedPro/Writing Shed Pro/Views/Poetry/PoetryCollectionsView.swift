//
//  PoetryCollectionsView.swift
//  Writing Shed Pro
//
//  Feature 036: Poetry-specific collections management
//  Lists and manages PoetryCollection objects for a Poetry project
//

import SwiftUI
import SwiftData

/// List view showing all poetry collections for a Poetry project
struct PoetryCollectionsView: View {
    private struct CollectionEditState: Identifiable {
        let id: UUID
        let name: String
        let synopsis: String
    }
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var showAddCollection = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedCollectionIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var collectionToEdit: CollectionEditState?
    @State private var refreshToken: Int = 0
    @State private var fileCountByCollectionID: [UUID: Int] = [:]
    
    /// Submission state
    @State private var showSubmissionNamePrompt = false
    @State private var newSubmissionName: String = ""
    @State private var showSubmissionCreated = false
    @State private var createdSubmissionName: String = ""
    @State private var showDuplicateSubmission = false
    
    // MARK: - Computed
    
    private var sortedCollections: [PoetryCollection] {
        (project.poetryCollections ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
    }
    
    private var isEditMode: Bool {
        editMode == .active
    }
    
    private var selectedCollections: [PoetryCollection] {
        sortedCollections.filter { selectedCollectionIDs.contains($0.id) }
    }
    
    private var showToolbar: Bool {
        isEditMode && !selectedCollectionIDs.isEmpty
    }

    /// Fast lookup of live counts computed from a single fetch.
    private func liveFileCount(for collection: PoetryCollection) -> Int {
        fileCountByCollectionID[collection.id] ?? 0
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if sortedCollections.isEmpty {
                emptyState
            } else {
                collectionList
            }
        }
        .id(refreshToken)
        .navigationTitle(NSLocalizedString("poetry.collections.title", comment: "Collections"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshToken += 1
            refreshLiveFileCounts()
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: .poetryCollectionMembershipDidChange)
                .receive(on: RunLoop.main)
        ) { notification in
            _ = notification
            refreshToken += 1
            refreshLiveFileCounts()
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: NSNotification.Name("NSPersistentStoreRemoteChangeNotification"))
                .receive(on: RunLoop.main)
        ) { _ in
            refreshToken += 1
            refreshLiveFileCounts()
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showAddCollection = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NSLocalizedString("poetry.collections.add", comment: "Add collection"))
                .disabled(isEditMode)
                
                // Edit/Done button
                if !sortedCollections.isEmpty {
                    Button {
                        withAnimation {
                            if editMode == .active {
                                editMode = .inactive
                                selectedCollectionIDs.removeAll()
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
        .sheet(isPresented: $showAddCollection) {
            AddPoetryCollectionSheet(project: project)
        }
        .alert(
            selectedCollections.count == 1
                ? NSLocalizedString("poetry.collections.deleteConfirm.title", comment: "Delete collection?")
                : String(format: NSLocalizedString("poetry.collections.deleteMultiple.title", comment: "Delete collections?"), selectedCollections.count),
            isPresented: $showDeleteConfirmation
        ) {
            Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                deleteSelectedCollections()
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        } message: {
            if selectedCollections.count == 1, let collection = selectedCollections.first {
                Text(String(format: NSLocalizedString("poetry.collections.deleteConfirm.message", comment: "Delete message"), collection.name ?? ""))
            } else {
                Text(NSLocalizedString("poetry.collections.deleteMultiple.message", comment: "Poems in these collections will be unassigned but not deleted."))
            }
        }
        .sheet(item: $collectionToEdit) { collection in
            EditContainerSheet(
                navigationTitle: NSLocalizedString("poetry.collection.rename.title", comment: "Rename Collection"),
                nameLabel: NSLocalizedString("poetry.collection.name", comment: "Name"),
                synopsisLabel: NSLocalizedString("poetry.collection.synopsis", comment: "Synopsis"),
                synopsisFooter: NSLocalizedString("poetry.collection.synopsis.footer", comment: "Brief description of this collection"),
                initialName: collection.name,
                initialSynopsis: collection.synopsis
            ) { updatedName, updatedSynopsis in
                updateCollection(id: collection.id, name: updatedName, synopsis: updatedSynopsis)
            }
        }
        .alert(NSLocalizedString("submissions.name.title", comment: "Name Submission"), isPresented: $showSubmissionNamePrompt) {
            TextField(NSLocalizedString("submissions.name.placeholder", comment: "Name"), text: $newSubmissionName)
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                newSubmissionName = ""
            }
            Button(NSLocalizedString("button.create", comment: "Create")) {
                createSubmissionFromCollections(name: newSubmissionName)
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
        .onChange(of: editMode) { _, newValue in
            if newValue == .inactive {
                selectedCollectionIDs.removeAll()
            }
        }
    }
    
    // MARK: - Bottom Toolbar
    
    @ViewBuilder
    private var bottomToolbarContent: some View {
        // Add to submission button
        Button {
            showSubmissionNamePrompt = true
        } label: {
            Label(NSLocalizedString("fileList.addToSubmission", comment: "Add to submission"), systemImage: "tray.and.arrow.down")
        }
        
        Spacer()
        
        // Delete button
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label(
                String(format: NSLocalizedString("poetry.collections.deleteCount", comment: "Delete count"), selectedCollections.count),
                systemImage: "trash"
            )
        }
        .disabled(selectedCollections.isEmpty)
    }
    
    // MARK: - Collection List
    
    private var collectionList: some View {
        List(selection: $selectedCollectionIDs) {
            ForEach(sortedCollections) { collection in
                let currentFileCount = liveFileCount(for: collection)
                HStack {
                    if isEditMode {
                        CollectionRowView(collection: collection, fileCount: currentFileCount)
                    } else {
                        NavigationLink {
                            PoetryCollectionPoemsView(project: project, collection: collection)
                        } label: {
                            CollectionRowView(collection: collection, fileCount: currentFileCount)
                        }
                    }
                    
                    if !isEditMode {
                        Button {
                            collectionToEdit = CollectionEditState(
                                id: collection.id,
                                name: collection.name ?? "",
                                synopsis: collection.synopsis ?? ""
                            )
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .imageScale(.large)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onDrag {
                    return NSItemProvider(object: collection.id.uuidString as NSString)
                }
            }
            .onMove(perform: moveCollections)
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("poetry.collections.empty.title", comment: "No Collections"))
                .font(.headline)
            
            Text(NSLocalizedString("poetry.collections.empty.message", comment: "Create collections to group your poems for manuscript assembly."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showAddCollection = true
            } label: {
                Label(NSLocalizedString("poetry.collections.add", comment: "Add Collection"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Actions

    private func refreshLiveFileCounts() {
        let freshContext = ModelContext(modelContext.container)
        var counts: [UUID: Int] = [:]

        for collection in sortedCollections {
            let collectionID = collection.id
            let descriptor = FetchDescriptor<TextFileCollectionLink>(
                predicate: #Predicate { link in
                    link.poetryCollection?.id == collectionID
                }
            )

            if let links = try? freshContext.fetch(descriptor) {
                let liveCount = links.reduce(into: 0) { total, link in
                    guard link.textFile?.trashItem == nil else { return }
                    total += 1
                }
                counts[collectionID] = liveCount
            } else {
                // Fallback keeps UI usable even if the fetch fails transiently.
                let fallback = (collection.textFiles ?? []).filter { $0.trashItem == nil }.count
                counts[collectionID] = fallback
            }
        }

        fileCountByCollectionID = counts
    }
    
    private func deleteSelectedCollections() {
        let deletedIDs = Set(selectedCollections.map { $0.id })

        for collection in selectedCollections {
            // Remove only this collection link from poems; do not touch folders/files.
            for file in collection.textFiles ?? [] {
                file.removeFromPoetryCollection(collection)
            }
            // Remove from Body Matter if included
            collection.isInBodyMatter = false
            collection.bodyMatterOrder = nil
            
            modelContext.delete(collection)
        }

        if let editID = collectionToEdit?.id, deletedIDs.contains(editID) {
            collectionToEdit = nil
        }
        
        try? modelContext.save()
        refreshLiveFileCounts()
        selectedCollectionIDs.removeAll()
        editMode = .inactive
    }
    
    private func updateCollection(id: UUID, name: String, synopsis: String) {
        guard !name.isEmpty else { return }
        guard let collection = sortedCollections.first(where: { $0.id == id }) else { return }
        collection.name = name
        collection.synopsis = synopsis.isEmpty ? nil : synopsis
        collection.modifiedDate = Date()
        try? modelContext.save()
        refreshLiveFileCounts()
    }
    
    private func moveCollections(from source: IndexSet, to destination: Int) {
        var collections = sortedCollections
        collections.move(fromOffsets: source, toOffset: destination)
        for (index, collection) in collections.enumerated() {
            collection.userOrder = index
        }
        try? modelContext.save()
        refreshLiveFileCounts()
    }
    
    private func createSubmissionFromCollections(name: String) {
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
        
        // Link files from all selected poetry collections
        for collection in selectedCollections {
            let files = (collection.textFiles ?? []).filter { $0.trashItem == nil }
            for file in files {
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
        }
        
        try? modelContext.save()
        createdSubmissionName = trimmedName
        showSubmissionCreated = true
        selectedCollectionIDs.removeAll()
        exitEditMode()
    }

    private func hasDuplicateSubmissionNamed(_ name: String) -> Bool {
        let submissions = project.submissions ?? []
        return submissions.contains { submission in
            submission.isCollection == false && submission.name == name
        }
    }
    
    private func exitEditMode() {
        withAnimation {
            editMode = .inactive
        }
    }
}

// MARK: - Collection Row View

struct CollectionRowView: View {
    let collection: PoetryCollection
    let fileCount: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name ?? NSLocalizedString("poetry.collection.untitled", comment: "Untitled"))
                    .font(.body)
                
                HStack(spacing: 8) {
                    Text(String(format: NSLocalizedString("poetry.collection.poemCount", comment: "%d poems"), fileCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if collection.isInBodyMatter {
                        Text(NSLocalizedString("poetry.collection.inBodyMatter", comment: "In Body Matter"))
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}
