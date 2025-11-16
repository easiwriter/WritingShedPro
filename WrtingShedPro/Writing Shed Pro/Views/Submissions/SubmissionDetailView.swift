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
    @State private var editedName: String = ""
    @State private var editedSubmittedDate: Date = Date()
    @State private var editedResponseDate: Date?
    @State private var editedNotes: String = ""
    @State private var hasResponseDate: Bool = false
    
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
            
            // Editable submission details (moved below files)
            Section {
                // Optional name field
                TextField(NSLocalizedString("submissions.name.placeholder", comment: "Name placeholder"), 
                         text: $editedName)
                    .onChange(of: editedName) { _, newValue in
                        submission.name = newValue.isEmpty ? nil : newValue
                    }
                
                // Submitted date
                DatePicker(NSLocalizedString("submissions.submitted.label", comment: "Submitted"),
                          selection: $editedSubmittedDate,
                          displayedComponents: .date)
                    .onChange(of: editedSubmittedDate) { _, newValue in
                        submission.submittedDate = newValue
                    }
                
                // Response date toggle and picker
                Toggle(NSLocalizedString("submissions.response.received", comment: "Response received"), 
                       isOn: $hasResponseDate)
                    .onChange(of: hasResponseDate) { _, newValue in
                        if newValue {
                            if editedResponseDate == nil {
                                editedResponseDate = Date()
                            }
                            submission.responseDate = editedResponseDate
                        } else {
                            submission.responseDate = nil
                        }
                    }
                
                if hasResponseDate {
                    DatePicker(NSLocalizedString("submissions.response.date.label", comment: "Response date"),
                              selection: .init(
                                get: { editedResponseDate ?? Date() },
                                set: { newValue in
                                    editedResponseDate = newValue
                                    submission.responseDate = newValue
                                }
                              ),
                              displayedComponents: .date)
                }
                
                // Notes field - self-expanding
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("submissions.notes.label", comment: "Notes"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ZStack(alignment: .topLeading) {
                        // Invisible text that sets the height
                        Text(editedNotes.isEmpty ? " " : editedNotes)
                            .font(.body)
                            .padding(8)
                            .opacity(0)
                        
                        TextEditor(text: $editedNotes)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .onChange(of: editedNotes) { _, newValue in
                                submission.notes = newValue.isEmpty ? nil : newValue
                            }
                    }
                }
            } header: {
                Text(NSLocalizedString("submissions.details.label", comment: "Details"))
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
        .onAppear {
            // Initialize state from submission
            editedName = submission.name ?? ""
            editedSubmittedDate = submission.submittedDate
            editedResponseDate = submission.responseDate
            editedNotes = submission.notes ?? ""
            hasResponseDate = submission.responseDate != nil
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
    
    private func deleteSubmission() {
        modelContext.delete(submission)
        dismiss()
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