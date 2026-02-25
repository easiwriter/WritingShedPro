//
//  FileSubmissionsView.swift
//  Writing Shed Pro
//
//  Feature 008b Phase 3: Show submission history for a file
//

import SwiftUI
import SwiftData

/// View showing all submissions for a specific file
struct FileSubmissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let file: TextFile
    
    // Query all SubmittedFiles to ensure fresh data
    @Query private var allSubmittedFiles: [SubmittedFile]
    
    // Query all Submissions to ensure relationships are loaded
    @Query private var allSubmissions: [Submission]
    
    // Query all Publications to ensure relationships are loaded
    @Query private var allPublications: [Publication]
    
    // Filter to only submitted files for this specific file
    private var fileSubmissions: [SubmittedFile] {
        let fileID: UUID = file.id
        return allSubmittedFiles
            .filter { (sf: SubmittedFile) -> Bool in sf.textFile?.id == fileID }
            .sorted { (a: SubmittedFile, b: SubmittedFile) -> Bool in (a.submission?.submittedDate ?? Date.distantPast) > (b.submission?.submittedDate ?? Date.distantPast) }
    }
    
    // Helper to find publication/collection name for a submittedFile
    private func publicationName(for submittedFile: SubmittedFile) -> String {
        guard let submission = submittedFile.submission else {
            return NSLocalizedString("submissions.unknownPublication", comment: "Unknown")
        }
        
        // Find the fully-loaded submission from our query
        let matchedSubmission = allSubmissions.first(where: { $0.id == submission.id }) ?? submission
        
        // If it's a collection (no publication), use the collection name
        if matchedSubmission.isCollection || matchedSubmission.publication == nil {
            if let name = matchedSubmission.name, !name.isEmpty {
                return name
            }
        }
        
        // It's a publication submission - get the publication name
        if let publication = matchedSubmission.publication {
            return publication.name
        }
        
        // Try to find publication from our publications query
        if let pubId = submission.publication?.id,
           let matchedPub = allPublications.first(where: { $0.id == pubId }) {
            return matchedPub.name
        }
        
        // Last resort: use submission name if available
        if let name = matchedSubmission.name, !name.isEmpty {
            return name
        }
        
        return NSLocalizedString("submissions.unknownPublication", comment: "Unknown")
    }
    
    // Helper to check if a submittedFile is in a collection (vs publication submission)
    private func isCollection(for submittedFile: SubmittedFile) -> Bool {
        guard let submission = submittedFile.submission else { return false }
        
        // Find the fully-loaded submission from our query
        let matchedSubmission = allSubmissions.first(where: { $0.id == submission.id }) ?? submission
        
        // Use only the explicit isCollection flag
        return matchedSubmission.isCollection
    }
    
    // Get the submission for a submittedFile (fully loaded from query)
    private func submission(for submittedFile: SubmittedFile) -> Submission? {
        guard let submission = submittedFile.submission else { return nil }
        return allSubmissions.first(where: { $0.id == submission.id }) ?? submission
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if fileSubmissions.isEmpty {
                    ContentUnavailableView {
                        Label("submissions.file.empty.title", systemImage: "tray")
                    } description: {
                        Text("submissions.file.empty.message")
                    }
                } else {
                    List {
                        ForEach(fileSubmissions) { submittedFile in
                            if let submission = submission(for: submittedFile) {
                                NavigationLink {
                                    SubmissionFilesView(
                                        submission: submission,
                                        submissionName: publicationName(for: submittedFile),
                                        isCollection: isCollection(for: submittedFile)
                                    )
                                } label: {
                                    SubmissionHistoryRow(
                                        submittedFile: submittedFile,
                                        publicationName: publicationName(for: submittedFile),
                                        isCollection: isCollection(for: submittedFile)
                                    )
                                }
                            } else {
                                SubmissionHistoryRow(
                                    submittedFile: submittedFile,
                                    publicationName: publicationName(for: submittedFile),
                                    isCollection: isCollection(for: submittedFile)
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("submissions.file.history.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// View showing all files in a submission
private struct SubmissionFilesView: View {
    let submission: Submission
    let submissionName: String
    let isCollection: Bool
    
    @Query private var allSubmittedFiles: [SubmittedFile]
    
    private var filesInSubmission: [SubmittedFile] {
        let submissionID: UUID = submission.id
        return allSubmittedFiles
            .filter { (sf: SubmittedFile) -> Bool in sf.submission?.id == submissionID }
            .sorted { (a: SubmittedFile, b: SubmittedFile) -> Bool in (a.textFile?.name ?? "") < (b.textFile?.name ?? "") }
    }
    
    var body: some View {
        List {
            ForEach(filesInSubmission) { submittedFile in
                if let textFile = submittedFile.textFile {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(textFile.name)
                                .font(.headline)
                            
                            if let folderName = textFile.parentFolder?.name {
                                Text(folderName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // For publication submissions, show status
                        if !isCollection, let status = submittedFile.status {
                            Text(status.displayName)
                                .font(.caption)
                                .foregroundStyle(status.color)
                        }
                    }
                }
            }
        }
        .navigationTitle(submissionName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Row showing a single submission entry for a file
private struct SubmissionHistoryRow: View {
    let submittedFile: SubmittedFile
    let publicationName: String
    let isCollection: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(publicationName)
                    .font(.headline)
                
                // Show submission date
                if let submission = submittedFile.submission {
                    Text(submission.submittedDate.formatted(date: .numeric, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Indicate collection vs publication
            if isCollection {
                Label("Collection", systemImage: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("Publication", systemImage: "newspaper")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
