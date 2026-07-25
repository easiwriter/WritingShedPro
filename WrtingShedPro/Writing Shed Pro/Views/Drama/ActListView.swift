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
    @State private var actToEdit: Act?
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
        .sheet(item: $actToEdit) { act in
            EditContainerSheet(
                navigationTitle: NSLocalizedString("drama.act.rename.title", comment: "Rename Act"),
                nameLabel: NSLocalizedString("drama.act.title", comment: "Title"),
                synopsisLabel: NSLocalizedString("drama.act.synopsis", comment: "Synopsis"),
                synopsisFooter: NSLocalizedString("drama.act.synopsis.footer", comment: "Brief overview of the act"),
                initialName: act.name ?? "",
                initialSynopsis: act.synopsis ?? ""
            ) { updatedName, updatedSynopsis in
                updateAct(act, name: updatedName, synopsis: updatedSynopsis)
            }
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
                HStack {
                    if isEditMode {
                        ActRowView(act: act)
                    } else {
                        NavigationLink {
                            SceneListView(project: project, act: act)
                        } label: {
                            ActRowView(act: act)
                        }
                    }
                    
                    if !isEditMode {
                        Button {
                            actToEdit = act
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
        
        project.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "act-list-delete")
        WriteCoalescer.shared?.flush()
        selectedActIDs.removeAll()
        renumberActs()
        exitEditMode()
    }
    
    private func updateAct(_ act: Act, name: String, synopsis: String) {
        guard !name.isEmpty else { return }

        act.name = name
        act.synopsis = synopsis.isEmpty ? nil : synopsis
        act.modifiedDate = Date()
        project.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "act-list-update")
        WriteCoalescer.shared?.flush()
    }
    
    private func moveActs(from source: IndexSet, to destination: Int) {
        var acts = sortedActs
        acts.move(fromOffsets: source, toOffset: destination)
        
        // Update order indices
        for (index, act) in acts.enumerated() {
            act.userOrder = index
            act.modifiedDate = Date()
        }
        
        project.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "act-list-move")
        WriteCoalescer.shared?.flush()
    }
    
    private func renumberActs() {
        for (index, act) in sortedActs.enumerated() {
            act.userOrder = index
            act.modifiedDate = Date()
        }
        project.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "act-list-renumber")
        WriteCoalescer.shared?.flush()
    }
    
    private func createSubmissionFromActs(name: String) {
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
        
        WriteCoalescer.shared?.requestSave(reason: "act-list-create-submission")
        WriteCoalescer.shared?.flush()
        createdSubmissionName = trimmedName
        showSubmissionCreated = true
        selectedActIDs.removeAll()
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

// MARK: - Act Row View

struct ActRowView: View {
    let act: Act
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Image(systemName: "theatermasks")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(width: 22, alignment: .leading)

                Text(act.name ?? NSLocalizedString("drama.untitled", comment: "Untitled"))
                    .font(.body)
                    .fontWeight(.semibold)
            }
            
            // Synopsis preview
            if let synopsis = act.synopsis, !synopsis.isEmpty {
                Text(synopsis)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Scene count
            let sceneCount = (act.scenes ?? []).filter(isLiveScene).count
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

    private func isLiveScene(_ scene: StoryScene) -> Bool {
        !scene.isTrashed && scene.textFile?.parentFolder != nil
    }
}
