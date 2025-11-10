//
//  SubmissionRowView.swift
//  Writing Shed Pro
//
//  Feature 008b Phase 3: Submissions UI
//

import SwiftUI
import SwiftData

struct SubmissionRowView: View {
    let submission: Submission
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // File names
            Text(fileNames)
                .font(.headline)
            
            // Submission date
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption)
                Text(String(format: NSLocalizedString("submissions.submitted.on", comment: "Submitted on"), submission.submittedDate.formatted(date: .abbreviated, time: .omitted)))
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            
            // Status summary
            if submission.fileCount > 0 {
                HStack(spacing: 8) {
                    statusBadge
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    private var fileNames: String {
        let files = submission.submittedFiles?.compactMap { $0.textFile?.name } ?? []
        if files.isEmpty {
            return NSLocalizedString("submissions.no.files", comment: "No files")
        } else if files.count == 1 {
            return files[0]
        } else {
            return String(format: NSLocalizedString("submissions.files.count", comment: "Files count"), files.count)
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            statusIcon
            Text(statusText)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .foregroundStyle(statusColor)
        .cornerRadius(8)
    }
    
    private var statusIcon: some View {
        switch submission.overallStatus {
        case .allAccepted:
            return Image(systemName: "checkmark.circle.fill")
        case .allRejected:
            return Image(systemName: "xmark.circle.fill")
        case .partiallyAccepted:
            return Image(systemName: "checkmark.circle.badge.xmark")
        case .pending:
            return Image(systemName: "clock")
        }
    }
    
    private var statusText: String {
        switch submission.overallStatus {
        case .allAccepted:
            return NSLocalizedString("submissions.status.accepted", comment: "Accepted")
        case .allRejected:
            return NSLocalizedString("submissions.status.rejected", comment: "Rejected")
        case .partiallyAccepted:
            return NSLocalizedString("submissions.status.mixed", comment: "Mixed")
        case .pending:
            return NSLocalizedString("submissions.status.pending", comment: "Pending")
        }
    }
    
    private var statusColor: Color {
        switch submission.overallStatus {
        case .allAccepted: return .green
        case .allRejected: return .red
        case .partiallyAccepted: return .orange
        case .pending: return .blue
        }
    }
    
    private var accessibilityLabel: Text {
        var label = Text(fileNames)
        label = label + Text(", ")
        label = label + Text(String(format: NSLocalizedString("submissions.submitted.on", comment: "Submitted on"), submission.submittedDate.formatted(date: .abbreviated, time: .omitted)))
        label = label + Text(", ")
        label = label + Text(NSLocalizedString("submissions.status.label", comment: "Status label"))
        label = label + Text(": ")
        label = label + Text(statusText)
        return label
    }
}