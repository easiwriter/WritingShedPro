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
    @State private var showPrintError = false
    @State private var printErrorMessage = ""
    
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
                        SubmittedFileRow(
                            submittedFile: submittedFile,
                            onStatusChange: { status in
                                updateStatus(submittedFile, to: status)
                            }
                        )
                    }
                } else {
                    Text(NSLocalizedString("submissions.no.files", comment: "No files"))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(String(format: NSLocalizedString("submissions.files.label", comment: "Files"), submission.fileCount))
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { printSubmission() }) {
                    Image(systemName: "printer")
                }
                .accessibilityLabel("Print Submission")
                .disabled(submission.submittedFiles?.isEmpty ?? true)
            }
        }
        .alert("Print Error", isPresented: $showPrintError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(printErrorMessage)
        }
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
    
    private func deleteSubmission() {
        modelContext.delete(submission)
        dismiss()
    }
    
    // MARK: - Printing
    
    /// Handle print submission action
    private func printSubmission() {
        print("🖨️ Print Submission button tapped")
        
        // Get the view controller to present from
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let viewController = window.rootViewController else {
            print("❌ Could not find view controller for print dialog")
            printErrorMessage = "Unable to present print dialog"
            showPrintError = true
            return
        }
        
        PrintService.printSubmission(
            submission,
            modelContext: modelContext,
            from: viewController
        ) { success, error in
            if let error = error {
                print("❌ Print failed: \(error.localizedDescription)")
                printErrorMessage = error.localizedDescription
                showPrintError = true
            } else if success {
                print("✅ Print completed successfully")
            } else {
                print("⚠️ Print was cancelled")
            }
        }
    }
    
    private func updateStatus(_ submittedFile: SubmittedFile, to status: SubmissionStatus) {
        submittedFile.status = status
        submittedFile.statusDate = Date()
        
        // If accepted, move file to Published folder
        if status == .accepted, let file = submittedFile.textFile {
            moveToPublishedFolder(file)
        }
    }
    
    private func moveToPublishedFolder(_ file: TextFile) {
        // Get the project
        guard let project = file.project else { return }
        
        // Find or create Published folder
        let publishedFolder = findOrCreatePublishedFolder(in: project)
        
        // Move file to Published folder
        file.parentFolder = publishedFolder
        file.modifiedDate = Date()
        
        // Save context
        do {
            try modelContext.save()
        } catch {
            print("Error moving file to Published folder: \(error)")
        }
    }
    
    private func findOrCreatePublishedFolder(in project: Project) -> Folder {
        // Try to find existing Published folder
        if let folders = project.folders {
            if let published = folders.first(where: { $0.name == "Published" }) {
                return published
            }
        }
        
        // Create new Published folder if it doesn't exist
        let publishedFolder = Folder(
            name: "Published",
            project: project,
            parentFolder: nil
        )
        modelContext.insert(publishedFolder)
        
        return publishedFolder
    }
}

struct SubmittedFileRow: View {
    @Bindable var submittedFile: SubmittedFile
    let onStatusChange: (SubmissionStatus) -> Void
    
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
                        onStatusChange(.pending)
                    } label: {
                        Label(NSLocalizedString("submissions.status.pending", comment: "Pending"), 
                              systemImage: "clock")
                    }
                    
                    Button {
                        onStatusChange(.accepted)
                    } label: {
                        Label(NSLocalizedString("submissions.status.accepted", comment: "Accepted"), 
                              systemImage: "checkmark.circle")
                    }
                    
                    Button {
                        onStatusChange(.rejected)
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