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
    @State private var showSubmissionNamePrompt = false
    @State private var newSubmissionName: String = ""
    @State private var showSubmissionCreated = false
    @State private var createdSubmissionName: String = ""
    @State private var showDuplicateSubmission = false
    
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
        .alert(NSLocalizedString("submissions.name.title", comment: "Name Submission"), isPresented: $showSubmissionNamePrompt) {
            TextField(NSLocalizedString("submissions.name.placeholder", comment: "Name"), text: $newSubmissionName)
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                newSubmissionName = ""
            }
            Button(NSLocalizedString("button.create", comment: "Create")) {
                createSubmissionFromActs(name: newSubmissionName)
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
    
    private func createSubmissionFromActs(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        // Check for duplicate
        let projectID = project.id
        var descriptor = FetchDescriptor<Submission>(predicate: #Predicate<Submission> { sub in
            sub.name == trimmedName && sub.project?.id == projectID && sub.isCollection == false
        })
        descriptor.fetchLimit = 1
        if let count = try? modelContext.fetchCount(descriptor), count > 0 {
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
        
        // Link files from all selected acts' scenes
        for act in selectedActs {
            let files = (act.scenes ?? []).compactMap { $0.textFile }.filter { $0.trashItem == nil }
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
        selectedActIDs.removeAll()
        exitEditMode()
    }
    
    private func exitEditMode() {
        withAnimation {
            editMode = .inactive
        }
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
