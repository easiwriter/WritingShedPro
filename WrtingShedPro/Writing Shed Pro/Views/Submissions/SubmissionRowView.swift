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

#Preview("Single File - Pending") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, Publication.self, Submission.self, SubmittedFile.self, configurations: config)
    let context = container.mainContext
    
    let project = Project(name: "Test Project", rootFolderURL: URL(fileURLWithPath: "/tmp/test"))
    let publication = Publication(name: "Test Magazine", project: project)
    let submission = Submission(publication: publication, project: project, submittedDate: Date())
    
    let textFile = TextFile(name: "Story.txt", folderURL: URL(fileURLWithPath: "/tmp/test"), project: project)
    let version = Version(textFile: textFile, project: project)
    let submittedFile = SubmittedFile(submission: submission, textFile: textFile, version: version, status: .pending, project: project)
    
    context.insert(project)
    context.insert(publication)
    context.insert(submission)
    context.insert(textFile)
    context.insert(version)
    context.insert(submittedFile)
    
    SubmissionRowView(submission: submission)
        .modelContainer(container)
        .padding()
}

#Preview("Multiple Files - Mixed Status") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, Publication.self, Submission.self, SubmittedFile.self, configurations: config)
    let context = container.mainContext
    
    let project = Project(name: "Test Project", rootFolderURL: URL(fileURLWithPath: "/tmp/test"))
    let publication = Publication(name: "Test Competition", project: project)
    let submission = Submission(publication: publication, project: project, submittedDate: Date().addingTimeInterval(-86400 * 7))
    
    let textFile1 = TextFile(name: "Story1.txt", folderURL: URL(fileURLWithPath: "/tmp/test"), project: project)
    let version1 = Version(textFile: textFile1, project: project)
    let submittedFile1 = SubmittedFile(submission: submission, textFile: textFile1, version: version1, status: .accepted, project: project)
    
    let textFile2 = TextFile(name: "Story2.txt", folderURL: URL(fileURLWithPath: "/tmp/test"), project: project)
    let version2 = Version(textFile: textFile2, project: project)
    let submittedFile2 = SubmittedFile(submission: submission, textFile: textFile2, version: version2, status: .rejected, project: project)
    
    context.insert(project)
    context.insert(publication)
    context.insert(submission)
    context.insert(textFile1)
    context.insert(version1)
    context.insert(submittedFile1)
    context.insert(textFile2)
    context.insert(version2)
    context.insert(submittedFile2)
    
    SubmissionRowView(submission: submission)
        .modelContainer(container)
        .padding()
}
