//
//  CollectionSubmissionsView.swift
//  Writing Shed Pro
//
//  Shows publications that a collection's files have been submitted to
//

import SwiftUI
import SwiftData

/// View showing all publication submissions for files in a collection
struct CollectionSubmissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let collection: Submission
    
    // Query all submissions (to find publication submissions)
    @Query private var allSubmissions: [Submission]
    
    // Query all submitted files
    @Query private var allSubmittedFiles: [SubmittedFile]
    
    // Get the file IDs in this collection
    private var collectionFileIDs: Set<UUID> {
        Set(collection.submittedFiles?.compactMap { $0.textFile?.id } ?? [])
    }
    
    // Find publication submissions that contain files from this collection
    // Excludes the current submission itself to avoid self-referencing duplicates
    private var publicationSubmissions: [Submission] {
        let selfID = collection.id
        // Filter to only actual submissions (not collections) that contain files from this collection
        return allSubmissions
            .filter { submission in
                // Exclude the current submission
                guard submission.id != selfID else { return false }
                
                // Must be a publication submission, not a collection
                guard !submission.isCollection && submission.publication != nil else { return false }
                
                // Check if any files in this submission are also in our collection
                guard let submittedFiles = submission.submittedFiles else { return false }
                
                return submittedFiles.contains { submittedFile in
                    guard let fileID = submittedFile.textFile?.id else { return false }
                    return collectionFileIDs.contains(fileID)
                }
            }
            .sorted { ($0.submittedDate) > ($1.submittedDate) }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if publicationSubmissions.isEmpty {
                    ContentUnavailableView {
                        Label(NSLocalizedString("collections.submissions.empty.title", comment: "No Submissions"), systemImage: "tray")
                    } description: {
                        Text(NSLocalizedString("collections.submissions.empty.message", comment: "Files in this collection have not been submitted to any publications yet."))
                    }
                } else {
                    List {
                        ForEach(publicationSubmissions) { submission in
                            NavigationLink {
                                CollectionDetailView(submission: submission)
                            } label: {
                                PublicationSubmissionRow(
                                    submission: submission,
                                    collectionFileIDs: collectionFileIDs
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("collections.submissions.title", comment: "Submissions"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Row showing a publication submission
private struct PublicationSubmissionRow: View {
    let submission: Submission
    let collectionFileIDs: Set<UUID>
    
    // Count how many files from the collection are in this submission
    private var matchingFileCount: Int {
        submission.submittedFiles?.filter { submittedFile in
            guard let fileID = submittedFile.textFile?.id else { return false }
            return collectionFileIDs.contains(fileID)
        }.count ?? 0
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Publication name
                Text(submission.publication?.name ?? NSLocalizedString("submissions.unknownPublication", comment: "Unknown Publication"))
                    .font(.headline)
                
                // Submission date
                Text(submission.submittedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // File count
                Text(String(format: NSLocalizedString("collections.submissions.fileCount", comment: "%d file(s) from collection"), matchingFileCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Overall status indicator
            statusIndicator
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        let status = submission.overallStatus
        switch status {
        case .pending:
            Image(systemName: "hourglass")
                .foregroundStyle(.orange)
        case .allAccepted:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .allRejected:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .partiallyAccepted:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.blue)
        }
    }
}

// MARK: - Collection Submissions Button

/// Button that shows submission icon and opens submission history for a collection
/// Only displayed if the collection's files have been submitted to publications
struct CollectionSubmissionsButton: View {
    @State private var showSubmissions = false
    
    let collection: Submission
    
    // Query all submissions to find publication submissions containing these files
    @Query private var allSubmissions: [Submission]
    
    // Get the file IDs in this collection
    private var collectionFileIDs: Set<UUID> {
        Set(collection.submittedFiles?.compactMap { $0.textFile?.id } ?? [])
    }
    
    // Count publication submissions that contain files from this collection
    // Excludes the current submission itself to avoid self-referencing duplicates
    private var submissionCount: Int {
        let selfID = collection.id
        return allSubmissions
            .filter { submission in
                // Exclude the current submission
                guard submission.id != selfID else { return false }
                
                // Must be a publication submission, not a collection
                guard !submission.isCollection && submission.publication != nil else { return false }
                
                // Check if any files in this submission are also in our collection
                guard let submittedFiles = submission.submittedFiles else { return false }
                
                return submittedFiles.contains { submittedFile in
                    guard let fileID = submittedFile.textFile?.id else { return false }
                    return collectionFileIDs.contains(fileID)
                }
            }
            .count
    }
    
    var body: some View {
        // Only show button if collection has publication submissions
        if submissionCount > 0 {
            Button {
                showSubmissions = true
            } label: {
                Image(systemName: "book.badge.plus")
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(String(format: NSLocalizedString("accessibility.collection.submissions", comment: "Collection submissions"), submissionCount)))
            .sheet(isPresented: $showSubmissions) {
                CollectionSubmissionsView(collection: collection)
            }
        }
    }
}
