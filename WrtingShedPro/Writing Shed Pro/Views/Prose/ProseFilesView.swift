//
//  ProseFilesView.swift
//  Writing Shed Pro
//
//  View for displaying and managing text files within a Prose Section
//

import SwiftUI
import SwiftData

/// View for displaying text files within a Prose section
struct ProseFilesView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    let section: ProseSection
    
    // MARK: - State
    
    @State private var selectedFile: TextFile?
    @State private var editMode: EditMode = .inactive
    @State private var selectedFileIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    
    /// Submission state
    @State private var showSubmissionPicker = false
    @State private var filesToSubmit: [TextFile] = []
    
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
        // Use native iOS back button - immune to SwiftUI render blocking
        .navigationBarBackButtonHidden(false)
        .onPopToRoot {
            dismiss()
        }
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
        .sheet(isPresented: $showSubmissionPicker) {
            NavigationStack {
                SubmissionPickerView(
                    project: project,
                    filesToSubmit: filesToSubmit,
                    collectionToSubmit: nil,
                    onPublicationSelected: { publication, name, expectedDate, reminderDate in
                        createSubmission(for: publication, name: name, expectedResponseDate: expectedDate, reminderDate: reminderDate)
                        showSubmissionPicker = false
                        withAnimation {
                            editMode = .inactive
                            selectedFileIDs.removeAll()
                        }
                    },
                    onCancel: {
                        showSubmissionPicker = false
                    }
                )
            }
        }
    }
    
    // MARK: - Bottom Toolbar
    
    @ViewBuilder
    private var bottomToolbarContent: some View {
        // Submit button — hidden when all selected files are still in draft
        if selectedFiles.contains(where: { $0.workflowStatus != .draft }) {
            Button {
                filesToSubmit = selectedFiles
                showSubmissionPicker = true
            } label: {
                Label(NSLocalizedString("submissions.button.submit", comment: "Submit"), systemImage: "paperplane")
            }
            .disabled(selectedFiles.isEmpty)
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
    
    // MARK: - Submission Actions
    
    private func createSubmission(for publication: Publication, name: String, expectedResponseDate: Date?, reminderDate: Date? = nil) {
        let submission = Submission(
            publication: publication,
            project: project,
            submittedDate: Date(),
            notes: nil
        )
        submission.name = name
        submission.isCollection = false
        submission.returnExpectedBy = expectedResponseDate
        
        // Schedule reminder notification if requested
        if let reminderDate = reminderDate {
            submission.reminderDate = reminderDate
            let pubName = publication.name
            let subName = name
            Task {
                let notifId = await NotificationReminderService.shared.scheduleSubmissionReminder(
                    submissionId: UUID().uuidString,
                    publicationName: pubName,
                    submissionName: subName,
                    reminderDate: reminderDate
                )
                if let notifId = notifId {
                    await MainActor.run {
                        submission.reminderNotificationId = notifId
                    }
                }
            }
        }
        
        modelContext.insert(submission)
        
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
