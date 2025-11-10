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
    
    let file: TextFile
    
    @Query private var allSubmittedFiles: [SubmittedFile]
    
    // Filter to only submitted files for this specific file
    private var fileSubmissions: [SubmittedFile] {
        allSubmittedFiles
            .filter { $0.textFile?.id == file.id }
            .sorted { ($0.submission?.submittedDate ?? Date.distantPast) > ($1.submission?.submittedDate ?? Date.distantPast) }
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
                            SubmissionHistoryRow(submittedFile: submittedFile)
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

/// Row showing a single submission entry for a file
private struct SubmissionHistoryRow: View {
    let submittedFile: SubmittedFile
    
    private var statusColor: Color {
        submittedFile.status?.color ?? .secondary
    }
    
    private var statusIcon: String {
        switch submittedFile.status {
        case .pending:
            return "⏳"
        case .accepted:
            return "✓"
        case .rejected:
            return "✗"
        case .none:
            return "⏳"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Publication name and type
            HStack {
                if let publication = submittedFile.submission?.publication {
                    Text(publication.type?.icon ?? "📄")
                        .font(.title3)
                    
                    Text(publication.name ?? "")
                        .font(.headline)
                    
                    Spacer()
                    
                    // Status badge
                    HStack(spacing: 4) {
                        Text(statusIcon)
                        Text(submittedFile.status?.displayName ?? NSLocalizedString("submissions.status.pending", comment: "Pending"))
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
                }
            }
            
            // Submission date
            if let submission = submittedFile.submission {
                Text(String(format: NSLocalizedString("submissions.submitted.on", comment: "Submitted on"), 
                           submission.submittedDate.formatted(date: .abbreviated, time: .omitted)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Status date if different from submission date
            if let statusDate = submittedFile.statusDate,
               submittedFile.status != .pending {
                Text(String(format: NSLocalizedString("submissions.status.updated.on", comment: "Status updated on"),
                           statusDate.formatted(date: .abbreviated, time: .omitted)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Response time
            if submittedFile.status != .pending {
                Text(String(format: NSLocalizedString("submissions.response.time", comment: "Response time"),
                           submittedFile.responseTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Status notes if present
            if let notes = submittedFile.statusNotes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}
