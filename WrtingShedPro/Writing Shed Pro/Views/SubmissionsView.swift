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
    
    @State private var isCheckingForSubmissions = true
    @State private var fetchedSubmissions: [Submission] = []
    
    // Query all Submissions for this project where publication is not nil
    @Query private var allSubmissions: [Submission]
    @Query private var allSubmittedFiles: [SubmittedFile]
    
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
        var submissionsByID: [UUID: Submission] = [:]

        for sub in fetchedSubmissions where !sub.isCollection && (sub.projectId == projectID || sub.project?.id == projectID) {
            submissionsByID[sub.id] = sub
        }

        for sub in allSubmissions where !sub.isCollection && (sub.projectId == projectID || sub.project?.id == projectID) {
            submissionsByID[sub.id] = sub
        }

        for submittedFile in allSubmittedFiles {
            guard let submission = submittedFile.submission,
                  !submission.isCollection,
                  submission.projectId == projectID || submission.project?.id == projectID || submittedFile.project?.id == projectID else {
                continue
            }
            submissionsByID[submission.id] = submission
        }

        let submissionsForProject: [Submission] = Array(submissionsByID.values)
        
        // Sort by case-insensitive name
        return submissionsForProject.sorted { (a: Submission, b: Submission) -> Bool in
            (a.name ?? "").localizedCaseInsensitiveCompare(b.name ?? "") == .orderedAscending
        }
    }
    
    /// Precomputed publication submission counts per submission ID.
    /// Avoids O(N²) @Query in each CollectionSubmissionsButton row.
    private var publicationSubmissionCounts: [UUID: Int] {
        // Build a map of fileID → set of non-collection submission IDs that contain it
        var fileToSubmissionIDs: [UUID: Set<UUID>] = [:]
        for sub in allSubmissions where !sub.isCollection && sub.publication != nil {
            for sf in sub.submittedFiles ?? [] {
                if let fid = sf.textFile?.id {
                    fileToSubmissionIDs[fid, default: []].insert(sub.id)
                }
            }
        }
        
        // For each submission in our list, count how many publication submissions share files
        var counts: [UUID: Int] = [:]
        for sub in sortedSubmissions {
            let fileIDs = Set((sub.submittedFiles ?? []).compactMap { $0.textFile?.id })
            var matchedIDs = Set<UUID>()
            for fid in fileIDs {
                if let sids = fileToSubmissionIDs[fid] {
                    matchedIDs.formUnion(sids)
                }
            }
            matchedIDs.remove(sub.id) // Exclude self
            counts[sub.id] = matchedIDs.count
        }
        return counts
    }
    
    @ViewBuilder
    private var submissionListView: some View {
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
        .safeAreaInset(edge: .bottom) {
            if editMode == .active && !selectedSubmissionIDs.isEmpty {
                HStack {
                    Button {
                        showPublicationPicker = true
                    } label: {
                        Image(systemName: "book.badge.plus")
                    }
                    .accessibilityLabel(NSLocalizedString("submissions.submit", comment: "Submit to publication"))

                    Spacer()

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
    }

    var body: some View {
        Group {
            if !sortedSubmissions.isEmpty {
                submissionListView
            } else if isCheckingForSubmissions {
                checkingSubmissionsView
            } else {
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
                // Pass the first selected submission so the picker defaults to its name
                let selectedSubmission = sortedSubmissions.first { selectedSubmissionIDs.contains($0.id) }
                SubmissionPickerView(
                    project: project,
                    filesToSubmit: nil,
                    collectionToSubmit: selectedSubmission,
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
        .onAppear {
            startSubmissionCheckWindow()
            refreshFetchedSubmissions()
            scheduleFetchedSubmissionRefreshes()
        }
        .onReceive(NotificationCenter.default.publisher(for: .projectContentCountsDidChange)) { _ in
            startSubmissionCheckWindow()
            refreshFetchedSubmissions()
            scheduleFetchedSubmissionRefreshes()
        }
    }

    private func refreshFetchedSubmissions() {
        do {
            fetchedSubmissions = try modelContext.fetch(FetchDescriptor<Submission>(
                sortBy: [SortDescriptor(\Submission.name, order: .forward)]
            ))
        } catch {
            #if DEBUG
            print("[SubmissionsView] Error fetching submissions: \(error)")
            #endif
        }
    }

    private func scheduleFetchedSubmissionRefreshes() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            refreshFetchedSubmissions()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            refreshFetchedSubmissions()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            refreshFetchedSubmissions()
        }
    }

    private func startSubmissionCheckWindow() {
        isCheckingForSubmissions = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            isCheckingForSubmissions = false
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
            refreshFetchedSubmissions()
            NotificationCenter.default.post(name: .projectContentCountsDidChange, object: nil)
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
            // Link the existing submission to the publication (don't create a new one)
            existingSubmission.publication = publication
            existingSubmission.projectId = project.id
            existingSubmission.submittedDate = Date()
            existingSubmission.modifiedDate = Date()
            
            // Update the name if one was provided, otherwise keep existing
            if !name.isEmpty {
                existingSubmission.name = name
            }
            
            existingSubmission.returnExpectedBy = expectedResponseDate
            
            // Schedule reminder notification if requested
            if let reminderDate = reminderDate {
                existingSubmission.reminderDate = reminderDate
                let pubName = publication.name
                let subName = name.isEmpty ? (existingSubmission.name ?? "Submission") : name
                Task {
                    let notifId = await NotificationReminderService.shared.scheduleSubmissionReminder(
                        submissionId: existingSubmission.id.uuidString,
                        publicationName: pubName,
                        submissionName: subName,
                        reminderDate: reminderDate
                    )
                    if let notifId = notifId {
                        await MainActor.run {
                            existingSubmission.reminderNotificationId = notifId
                        }
                    }
                }
            }
            
            // Update status of existing submitted files to pending with current date
            if let submittedFiles = existingSubmission.submittedFiles {
                for submittedFile in submittedFiles {
                    submittedFile.status = .pending
                    submittedFile.statusDate = Date()
                }
            }
        }
        
        do {
            try modelContext.save()
            refreshFetchedSubmissions()
            selectedSubmissionIDs.removeAll()
            withAnimation {
                editMode = .inactive
            }
            NotificationCenter.default.post(name: .projectContentCountsDidChange, object: nil)
        } catch {
            #if DEBUG
            print("Error submitting to publication: \(error)")
            #endif
        }
    }
    
    // MARK: - Delete
    
    private func deleteSubmissions(_ submissions: [Submission]) {
        let submissionIDs = submissions.map(\.id)
        let descriptor = FetchDescriptor<Submission>()
        let ownedSubmissions = ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { submissionIDs.contains($0.id) }

        for submission in ownedSubmissions {
            modelContext.delete(submission)
        }
        do {
            try modelContext.save()
            fetchedSubmissions.removeAll { submissionIDs.contains($0.id) }
            NotificationCenter.default.post(name: .projectContentCountsDidChange, object: nil)
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
            NavigationLink(destination: SubmissionDetailView(submission: submission)) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Show submissions button if collection has publication submissions
            CollectionSubmissionsButton(collection: submission, submissionCount: publicationSubmissionCounts[submission.id] ?? 0)
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

    private var checkingSubmissionsView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
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
