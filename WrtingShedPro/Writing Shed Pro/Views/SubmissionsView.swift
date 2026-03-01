//
//  SubmissionsView.swift
//  Writing Shed Pro
//
//  Feature: Submissions Folder
//  Displays Submission objects (where publication != nil) organized in the Submissions folder
//  These are collections that have been submitted to publications
//

import SwiftUI
import SwiftData

/// View for displaying Submissions in the Submissions folder
/// Submissions are Submission objects with a publication attached
struct SubmissionsView: View {
    let project: Project
    @Environment(\.modelContext) var modelContext
    
    // State for sorting
    @State private var sortOrder: SubmissionSortOrder = .bySubmittedDate
    
    // State for edit mode
    @State private var editMode: EditMode = .inactive
    @State private var selectedSubmissionIDs: Set<UUID> = []
    
    // State for delete confirmation
    @State private var submissionsToDelete: [Submission] = []
    @State private var showDeleteConfirmation = false
    
    // State for submitting to publication
    @State private var showPublicationPicker = false
    
    // State for creating a new submission
    @State private var showNewSubmissionSheet = false
    @State private var newSubmissionName = ""
    
    // Query all Submissions for this project where publication is not nil
    @Query private var allSubmissions: [Submission]
    
    init(project: Project) {
        self.project = project
        
        // Configure query to fetch only Submissions (isCollection = false)
        // Note: Using isCollection flag because SwiftData predicates cannot handle optional relationships
        // We filter by project in the sortedSubmissions computed property
        _allSubmissions = Query(
            filter: #Predicate<Submission> { submission in
                submission.isCollection == false
            },
            sort: [SortDescriptor(\Submission.name, order: .forward)]
        )
    }
    
    // Submissions sorted by name (case-insensitive)
    // Additional filtering to ensure ONLY submissions for THIS project appear
    private var sortedSubmissions: [Submission] {
        let projectID: UUID = project.id
        let submissionsForProject: [Submission] = allSubmissions.filter { (sub: Submission) -> Bool in
            !sub.isCollection && sub.project?.id == projectID
        }
        
        // Sort by case-insensitive name
        return submissionsForProject.sorted { (a: Submission, b: Submission) -> Bool in
            (a.name ?? "").localizedCaseInsensitiveCompare(b.name ?? "") == .orderedAscending
        }
    }
    
    var body: some View {
        Group {
            if !sortedSubmissions.isEmpty {
                // Show list of submissions
                List(selection: $selectedSubmissionIDs) {
                    ForEach(sortedSubmissions) { submission in
                        submissionRow(for: submission)
                            .tag(submission.id)
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, $editMode)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            // Edit button
                            Button {
                                withAnimation {
                                    if editMode == .active {
                                        editMode = .inactive
                                        selectedSubmissionIDs.removeAll()
                                    } else {
                                        editMode = .active
                                    }
                                }
                            } label: {
                                Text(editMode == .active ? "Done" : "Edit")
                            }
                            
                            // Sort menu
                            Menu {
                                Picker("Sort by", selection: $sortOrder) {
                                    ForEach(SubmissionSortOrder.allCases, id: \.self) { order in
                                        Text(order.displayName).tag(order)
                                    }
                                }
                            } label: {
                                Label("Sort", systemImage: "arrow.up.arrow.down")
                            }
                        }
                    }
                }
                // Bottom toolbar when in edit mode with selections
                .safeAreaInset(edge: .bottom) {
                    if editMode == .active && !selectedSubmissionIDs.isEmpty {
                        HStack {
                            // Submit to publication button
                            Button {
                                showPublicationPicker = true
                            } label: {
                                Image(systemName: "book.badge.plus")
                            }
                            .accessibilityLabel(NSLocalizedString("submissions.submit", comment: "Submit to publication"))
                            
                            Spacer()
                            
                            // Trash button
                            Button(role: .destructive) {
                                let selected = sortedSubmissions.filter { selectedSubmissionIDs.contains($0.id) }
                                submissionsToDelete = selected
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel(String(format: NSLocalizedString("submissions.deleteCount", comment: "Delete count"), selectedSubmissionIDs.count))
                        }
                        .padding()
                        .background(.bar)
                    }
                }
            } else {
                // Show empty state
                emptyStateView
            }
        }
        .navigationTitle("Submissions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newSubmissionName = ""
                    showNewSubmissionSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NSLocalizedString("submissions.create", comment: "Create submission"))
            }
        }
        .alert(submissionsToDelete.count == 1 ? "Delete Submission?" : "Delete \(submissionsToDelete.count) Submissions?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                submissionsToDelete = []
            }
            Button("Delete", role: .destructive) {
                deleteSubmissions(submissionsToDelete)
                submissionsToDelete = []
                selectedSubmissionIDs.removeAll()
            }
        } message: {
            if submissionsToDelete.count == 1, let submission = submissionsToDelete.first {
                Text("This will delete the submission record for \"\(submission.name ?? "Untitled")\". Your files will not be deleted.")
            } else {
                Text("This will delete \(submissionsToDelete.count) submission records. Your files will not be deleted.")
            }
        }
        .sheet(isPresented: $showPublicationPicker) {
            NavigationStack {
                SubmissionPickerView(
                    project: project,
                    filesToSubmit: nil,
                    collectionToSubmit: nil,
                    onPublicationSelected: { publication, name, expectedDate, reminderDate in
                        submitSelectedToPublication(publication, name: name, expectedResponseDate: expectedDate, reminderDate: reminderDate)
                        showPublicationPicker = false
                    },
                    onCancel: {
                        showPublicationPicker = false
                    }
                )
            }
        }
        .alert(NSLocalizedString("submissions.new.title", comment: "New Submission"), isPresented: $showNewSubmissionSheet) {
            TextField(NSLocalizedString("submissions.name.placeholder", comment: "Name"), text: $newSubmissionName)
            Button(NSLocalizedString("button.create", comment: "Create")) {
                createEmptySubmission()
            }
            .disabled(newSubmissionName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {}
        }
    }
    
    // MARK: - Create Empty Submission
    
    private func createEmptySubmission() {
        let name = newSubmissionName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        let submission = Submission(
            project: project,
            submittedDate: Date()
        )
        submission.name = name
        submission.isCollection = false
        modelContext.insert(submission)
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[SubmissionsView] Error creating submission: \(error)")
            #endif
        }
    }
    
    // MARK: - Submit to Publication
    
    private func submitSelectedToPublication(_ publication: Publication, name: String, expectedResponseDate: Date? = nil, reminderDate: Date? = nil) {
        let selectedSubmissions = sortedSubmissions.filter { selectedSubmissionIDs.contains($0.id) }
        
        for existingSubmission in selectedSubmissions {
            // Create a new submission for this publication
            let newSubmission = Submission(
                publication: publication,
                project: project,
                submittedDate: Date(),
                notes: nil
            )
            // Use the provided name, or fall back to existing submission name
            newSubmission.name = name.isEmpty ? existingSubmission.name : name
            newSubmission.isCollection = false
            newSubmission.returnExpectedBy = expectedResponseDate
            
            // Schedule reminder notification if requested
            if let reminderDate = reminderDate {
                newSubmission.reminderDate = reminderDate
                let pubName = publication.name
                let subName = name.isEmpty ? (existingSubmission.name ?? "Submission") : name
                Task {
                    let notifId = await NotificationReminderService.shared.scheduleSubmissionReminder(
                        submissionId: UUID().uuidString,
                        publicationName: pubName,
                        submissionName: subName,
                        reminderDate: reminderDate
                    )
                    if let notifId = notifId {
                        await MainActor.run {
                            newSubmission.reminderNotificationId = notifId
                        }
                    }
                }
            }
            
            modelContext.insert(newSubmission)
            
            // Copy all files from the existing submission
            if let submittedFiles = existingSubmission.submittedFiles {
                for submittedFile in submittedFiles {
                    if let textFile = submittedFile.textFile, let version = submittedFile.version {
                        let newSubmittedFile = SubmittedFile(
                            submission: newSubmission,
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
            selectedSubmissionIDs.removeAll()
            withAnimation {
                editMode = .inactive
            }
        } catch {
            #if DEBUG
            print("Error submitting to publication: \(error)")
            #endif
        }
    }
    
    // MARK: - Delete
    
    private func deleteSubmissions(_ submissions: [Submission]) {
        for submission in submissions {
            modelContext.delete(submission)
        }
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error deleting submissions: \(error)")
            #endif
        }
    }
    
    // MARK: - Submission Row
    
    @ViewBuilder
    private func submissionRow(for submission: Submission) -> some View {
        HStack {
            NavigationLink(destination: CollectionDetailView(submission: submission)) {
                VStack(alignment: .leading, spacing: 4) {
                    // Submission name
                    Text(submission.name ?? "Untitled Submission")
                        .font(.headline)
                    
                    // File count
                    let fileCount = submission.submittedFiles?.count ?? 0
                    Text("\(fileCount) \(fileCount == 1 ? "file" : "files")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            // Show submissions button if collection has publication submissions
            CollectionSubmissionsButton(collection: submission)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                submissionsToDelete = [submission]
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                submissionsToDelete = [submission]
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Submissions")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap + to create a submission, or add files from the file list")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sort Order

enum SubmissionSortOrder: String, CaseIterable {
    case bySubmittedDate = "submittedDate"
    case byName = "name"
    case byPublication = "publication"
    
    var displayName: String {
        switch self {
        case .bySubmittedDate:
            return "Submitted Date"
        case .byName:
            return "Name"
        case .byPublication:
            return "Publication"
        }
    }
}
