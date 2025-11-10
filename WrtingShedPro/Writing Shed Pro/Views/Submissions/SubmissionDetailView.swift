//
//  SubmissionDetailView.swift
//  Writing Shed Pro
//
//  Feature 008b Phase 3: Submissions UI
//

import SwiftUI
import SwiftData

struct SubmissionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var submission: Submission
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        List {
            // Publication info
            Section {
                if let publication = submission.publication {
                    NavigationLink(destination: PublicationDetailView(publication: publication)) {
                        HStack {
                            Text(publication.type?.icon ?? "")
                            Text(publication.name)
                        }
                    }
                    .accessibilityLabel(Text(String(format: NSLocalizedString("accessibility.view.publication", comment: "View publication"), publication.name)))
                }
            } header: {
                Text(NSLocalizedString("publications.form.name.label", comment: "Publication"))
            }
            
            // Submission info
            Section {
                LabeledContent(NSLocalizedString("submissions.submitted.label", comment: "Submitted")) {
                    Text(submission.submittedDate, style: .date)
                }
                
                if let notes = submission.notes {
                    LabeledContent(NSLocalizedString("submissions.notes.label", comment: "Notes")) {
                        Text(notes)
                    }
                }
            } header: {
                Text(NSLocalizedString("submissions.details.label", comment: "Details"))
            }
            
            // Submitted files
            Section {
                if let files = submission.submittedFiles, !files.isEmpty {
                    ForEach(files) { submittedFile in
                        SubmittedFileRow(submittedFile: submittedFile)
                    }
                } else {
                    Text(NSLocalizedString("submissions.no.files", comment: "No files"))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(String(format: NSLocalizedString("submissions.files.label", comment: "Files"), submission.fileCount))
            }
            
            // Status summary
            Section {
                LabeledContent(NSLocalizedString("submissions.status.overall", comment: "Overall status")) {
                    Text(overallStatusText)
                        .foregroundStyle(overallStatusColor)
                }
                
                LabeledContent(NSLocalizedString("submissions.status.pending.count", comment: "Pending")) {
                    Text("\(submission.pendingCount)")
                }
                
                LabeledContent(NSLocalizedString("submissions.status.accepted.count", comment: "Accepted")) {
                    Text("\(submission.acceptedCount)")
                        .foregroundStyle(.green)
                }
                
                LabeledContent(NSLocalizedString("submissions.status.rejected.count", comment: "Rejected")) {
                    Text("\(submission.rejectedCount)")
                        .foregroundStyle(.red)
                }
            } header: {
                Text(NSLocalizedString("submissions.status.label", comment: "Status"))
            }
            
            // Delete
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label(NSLocalizedString("submissions.delete.button", comment: "Delete submission"), systemImage: "trash")
                }
                .accessibilityLabel(Text(NSLocalizedString("accessibility.delete.submission", comment: "Delete submission")))
                .accessibilityHint(Text(NSLocalizedString("accessibility.delete.submission.hint", comment: "Delete submission hint")))
            }
        }
        .navigationTitle(Text(NSLocalizedString("submissions.detail.title", comment: "Submission details")))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            NSLocalizedString("submissions.delete.title", comment: "Delete submission"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                deleteSubmission()
            }
        } message: {
            Text(NSLocalizedString("submissions.delete.message", comment: "Delete message"))
        }
    }
    
    private var overallStatusText: String {
        switch submission.overallStatus {
        case .allAccepted:
            return NSLocalizedString("submissions.status.all.accepted", comment: "All accepted")
        case .allRejected:
            return NSLocalizedString("submissions.status.all.rejected", comment: "All rejected")
        case .partiallyAccepted:
            return NSLocalizedString("submissions.status.mixed", comment: "Mixed")
        case .pending:
            return NSLocalizedString("submissions.status.pending", comment: "Pending")
        }
    }
    
    private var overallStatusColor: Color {
        switch submission.overallStatus {
        case .allAccepted: return .green
        case .allRejected: return .red
        case .partiallyAccepted: return .orange
        case .pending: return .blue
        }
    }
    
    private func deleteSubmission() {
        modelContext.delete(submission)
        dismiss()
    }
}

struct SubmittedFileRow: View {
    @Bindable var submittedFile: SubmittedFile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let file = submittedFile.textFile {
                Text(file.name)
                    .font(.headline)
            }
            
            HStack {
                if let version = submittedFile.version {
                    Text(String(format: NSLocalizedString("submissions.version.label", comment: "Version"), version.versionNumber))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Status picker
                Menu {
                    Button {
                        submittedFile.status = .pending
                        submittedFile.statusDate = Date()
                    } label: {
                        Label(NSLocalizedString("submissions.status.pending", comment: "Pending"), 
                              systemImage: "clock")
                    }
                    
                    Button {
                        submittedFile.status = .accepted
                        submittedFile.statusDate = Date()
                    } label: {
                        Label(NSLocalizedString("submissions.status.accepted", comment: "Accepted"), 
                              systemImage: "checkmark.circle")
                    }
                    
                    Button {
                        submittedFile.status = .rejected
                        submittedFile.statusDate = Date()
                    } label: {
                        Label(NSLocalizedString("submissions.status.rejected", comment: "Rejected"), 
                              systemImage: "xmark.circle")
                    }
                } label: {
                    HStack {
                        Text(submittedFile.status?.icon ?? "")
                        Text(submittedFile.status?.displayName ?? NSLocalizedString("submissions.status.unknown", comment: "Unknown"))
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundStyle(statusColor)
                    .cornerRadius(8)
                }
                .accessibilityLabel(Text(String(format: NSLocalizedString("accessibility.change.status", comment: "Change status"), 
                                               submittedFile.status?.displayName ?? "")))
            }
            
            if let statusDate = submittedFile.statusDate {
                Text(String(format: NSLocalizedString("submissions.updated.on", comment: "Updated on"), 
                           statusDate.formatted(date: .abbreviated, time: .omitted)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
    
    private var statusColor: Color {
        guard let status = submittedFile.status else { return .gray }
        return status.color
    }
}

#Preview("With Files") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, Publication.self, Submission.self, SubmittedFile.self, TextFile.self, Version.self, configurations: config)
    let context = container.mainContext
    
    let project = Project(name: "Test Project", rootFolderURL: URL(fileURLWithPath: "/tmp/test"))
    let publication = Publication(name: "Test Magazine", type: .magazine, project: project)
    let submission = Submission(publication: publication, project: project, submittedDate: Date().addingTimeInterval(-86400 * 7), notes: "Test submission notes")
    
    let file1 = TextFile(name: "Story1.txt", folderURL: URL(fileURLWithPath: "/tmp/test"), project: project)
    let version1 = Version(textFile: file1, project: project)
    let submittedFile1 = SubmittedFile(submission: submission, textFile: file1, version: version1, status: .accepted, statusDate: Date(), project: project)
    
    let file2 = TextFile(name: "Story2.txt", folderURL: URL(fileURLWithPath: "/tmp/test"), project: project)
    let version2 = Version(textFile: file2, project: project)
    let submittedFile2 = SubmittedFile(submission: submission, textFile: file2, version: version2, status: .pending, statusDate: Date(), project: project)
    
    context.insert(project)
    context.insert(publication)
    context.insert(submission)
    context.insert(file1)
    context.insert(version1)
    context.insert(submittedFile1)
    context.insert(file2)
    context.insert(version2)
    context.insert(submittedFile2)
    
    NavigationStack {
        SubmissionDetailView(submission: submission)
    }
    .modelContainer(container)
}
