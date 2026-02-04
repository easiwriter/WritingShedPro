//
//  ActListView.swift
//  Writing Shed Pro
//
//  Drama Act management - Acts contain scenes
//

import SwiftUI
import SwiftData

/// List view showing all acts for a Drama project
struct ActListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var showAddAct = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedActIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var showRenameSheet = false
    @State private var actToRename: Act?
    @State private var newActName: String = ""
    @State private var showCollectionPicker = false
    @State private var showSubmissionPicker = false
    @State private var filesToAddToCollection: [TextFile] = []
    @State private var filesToSubmit: [TextFile] = []
    
    // MARK: - Computed
    
    private var sortedActs: [Act] {
        (project.acts ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
    }
    
    private var isEditMode: Bool {
        editMode == .active
    }
    
    private var selectedActs: [Act] {
        sortedActs.filter { selectedActIDs.contains($0.id) }
    }
    
    private var showToolbar: Bool {
        isEditMode && !selectedActIDs.isEmpty
    }
    
    /// Get all ready text files from selected acts' scenes
    private var selectedActFiles: [TextFile] {
        selectedActs.flatMap { act in
            (act.scenes ?? []).compactMap { scene in
                guard let textFile = scene.textFile,
                      textFile.workflowStatus == .ready else { return nil }
                return textFile
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if sortedActs.isEmpty {
                emptyState
            } else {
                actList
            }
        }
        .navigationTitle(NSLocalizedString("drama.acts.title", comment: "Acts"))
        .navigationBarTitleDisplayMode(.inline)
        // Use native iOS back button - immune to SwiftUI render blocking
        .navigationBarBackButtonHidden(false)
        .onPopToRoot {
            dismiss()
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showAddAct = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NSLocalizedString("drama.acts.add", comment: "Add act"))
                .disabled(isEditMode)
                
                // Edit/Done button
                if !sortedActs.isEmpty {
                    Button {
                        withAnimation {
                            if editMode == .active {
                                editMode = .inactive
                                selectedActIDs.removeAll()
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
        .sheet(isPresented: $showAddAct) {
            AddActSheet(project: project)
        }
        .alert(
            selectedActs.count == 1 
                ? NSLocalizedString("drama.acts.deleteConfirm.title", comment: "Delete act?")
                : String(format: NSLocalizedString("drama.acts.deleteMultiple.title", comment: "Delete acts?"), selectedActs.count),
            isPresented: $showDeleteConfirmation
        ) {
            Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                deleteSelectedActs()
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        } message: {
            if selectedActs.count == 1, let act = selectedActs.first {
                Text(String(format: NSLocalizedString("drama.acts.deleteConfirm.message", comment: "Delete message"), act.name ?? ""))
            } else {
                Text(NSLocalizedString("drama.acts.deleteMultiple.message", comment: "All scenes in these acts will also be deleted."))
            }
        }
        .alert(NSLocalizedString("drama.act.rename.title", comment: "Rename Act"), isPresented: $showRenameSheet) {
            TextField(NSLocalizedString("drama.act.title", comment: "Title"), text: $newActName)
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                actToRename = nil
                newActName = ""
            }
            Button(NSLocalizedString("button.rename", comment: "Rename")) {
                if let act = actToRename {
                    renameAct(act, to: newActName)
                }
                actToRename = nil
                newActName = ""
            }
            .disabled(newActName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .sheet(isPresented: $showCollectionPicker) {
            NavigationStack {
                CollectionPickerView(
                    project: project,
                    filesToAddToCollection: filesToAddToCollection,
                    collectionsToAddToPublication: nil,
                    mode: .addFilesToCollection,
                    onCollectionSelected: { collection in
                        addFilesToCollection(collection)
                        showCollectionPicker = false
                        exitEditMode()
                    },
                    onCancel: {
                        showCollectionPicker = false
                    }
                )
            }
        }
        .sheet(isPresented: $showSubmissionPicker) {
            NavigationStack {
                SubmissionPickerView(
                    project: project,
                    filesToSubmit: filesToSubmit,
                    collectionToSubmit: nil,
                    onPublicationSelected: { publication, name, expectedDate in
                        createSubmission(for: publication, name: name, expectedResponseDate: expectedDate)
                        showSubmissionPicker = false
                        exitEditMode()
                    },
                    onCancel: {
                        showSubmissionPicker = false
                    }
                )
            }
        }
        .onChange(of: editMode) { _, newValue in
            if newValue == .inactive {
                selectedActIDs.removeAll()
            }
        }
    }
    
    // MARK: - Bottom Toolbar
    
    @ViewBuilder
    private var bottomToolbarContent: some View {
        // Rename button (only for single selection)
        if selectedActs.count == 1 {
            Button {
                if let act = selectedActs.first {
                    actToRename = act
                    newActName = act.name ?? ""
                    showRenameSheet = true
                }
            } label: {
                Label(NSLocalizedString("button.rename", comment: "Rename"), systemImage: "pencil")
            }
        }
        
        // Add to Collection button
        if !selectedActFiles.isEmpty {
            Button {
                filesToAddToCollection = selectedActFiles
                showCollectionPicker = true
            } label: {
                Label(NSLocalizedString("button.addToCollection", comment: "Add to Collection"), systemImage: "folder.badge.plus")
            }
        }
        
        // Submit button
        if !selectedActFiles.isEmpty {
            Button {
                filesToSubmit = selectedActFiles
                showSubmissionPicker = true
            } label: {
                Label(NSLocalizedString("button.submit", comment: "Submit"), systemImage: "paperplane")
            }
        }
        
        Spacer()
        
        // Delete button
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label(
                String(format: NSLocalizedString("drama.acts.deleteCount", comment: "Delete count"), selectedActs.count),
                systemImage: "trash"
            )
        }
        .disabled(selectedActs.isEmpty)
    }
    
    // MARK: - Act List
    
    private var actList: some View {
        List(selection: $selectedActIDs) {
            ForEach(sortedActs) { act in
                Group {
                    if isEditMode {
                        ActRowView(act: act)
                    } else {
                        NavigationLink {
                            SceneListView(project: project, act: act)
                        } label: {
                            ActRowView(act: act)
                        }
                    }
                }
                // Enable drag-to-reorder without edit mode
                .onDrag {
                    return NSItemProvider(object: act.id.uuidString as NSString)
                }
            }
            .onMove(perform: moveActs)
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "theatermasks")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("drama.acts.empty.title", comment: "No acts"))
                .font(.headline)
            
            Text(NSLocalizedString("drama.acts.empty.message", comment: "Empty message"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showAddAct = true
            } label: {
                Label(NSLocalizedString("drama.acts.add", comment: "Add act"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func deleteSelectedActs() {
        for act in selectedActs {
            // Also delete all scenes in the act
            if let scenes = act.scenes {
                for scene in scenes {
                    modelContext.delete(scene)
                }
            }
            modelContext.delete(act)
        }
        
        try? modelContext.save()
        selectedActIDs.removeAll()
        renumberActs()
        exitEditMode()
    }
    
    private func renameAct(_ act: Act, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        act.name = trimmedName
        act.modifiedDate = Date()
        try? modelContext.save()
    }
    
    private func moveActs(from source: IndexSet, to destination: Int) {
        var acts = sortedActs
        acts.move(fromOffsets: source, toOffset: destination)
        
        // Update order indices
        for (index, act) in acts.enumerated() {
            act.userOrder = index
        }
        
        try? modelContext.save()
    }
    
    private func renumberActs() {
        for (index, act) in sortedActs.enumerated() {
            act.userOrder = index
        }
        try? modelContext.save()
    }
    
    private func exitEditMode() {
        withAnimation {
            editMode = .inactive
        }
    }
    
    // MARK: - Collection & Submission Actions
    
    private func addFilesToCollection(_ collection: Submission) {
        // Create SubmittedFile records for each file in the collection
        for file in filesToAddToCollection {
            // Check if file is already in collection
            let alreadyInCollection = collection.submittedFiles?.contains { $0.textFile?.id == file.id } ?? false
            guard !alreadyInCollection else { continue }
            
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
        
        try? modelContext.save()
        filesToAddToCollection = []
    }
    
    private func createSubmission(for publication: Publication, name: String, expectedResponseDate: Date?) {
        // Create submission
        let submission = Submission(
            publication: publication,
            project: project,
            submittedDate: Date(),
            notes: nil
        )
        submission.name = name
        submission.isCollection = false
        submission.returnExpectedBy = expectedResponseDate
        modelContext.insert(submission)
        
        // Create SubmittedFile records for each file
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
        
        try? modelContext.save()
        filesToSubmit = []
    }
}

// MARK: - Act Row View

struct ActRowView: View {
    let act: Act
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                // Act number
                if let userOrder = act.userOrder {
                    Text(String(format: NSLocalizedString("drama.act.number", comment: "Act X"), userOrder + 1))
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(act.name ?? NSLocalizedString("drama.untitled", comment: "Untitled"))
                .font(.body)
                .fontWeight(.semibold)
            
            // Synopsis preview
            if let synopsis = act.synopsis, !synopsis.isEmpty {
                Text(synopsis)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Scene count
            let sceneCount = act.scenes?.count ?? 0
            HStack(spacing: 4) {
                Image(systemName: "film")
                    .font(.footnote)
                Text(String(format: NSLocalizedString("drama.act.sceneCount", comment: "Scene count"), sceneCount))
                    .font(.footnote)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}
