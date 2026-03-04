//
//  AddSubmissionView.swift
//  Writing Shed Pro
//
//  Feature 008b Phase 3: Submissions UI
//

import SwiftUI
import SwiftData

struct AddSubmissionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let publication: Publication
    let project: Project
    
    @Query private var allFiles: [TextFile]
    @State private var selectedFiles: Set<TextFile> = []
    @State private var submissionDate: Date = Date()
    @State private var returnExpectedBy: Date?
    @State private var showExpectedDate: Bool = false
    @State private var notes: String = ""
    
    // Filter files for this project and exclude already submitted versions
    private var projectFiles: [TextFile] {
        let filtered = allFiles.filter { file in
            isFileEligibleForSubmission(file)
        }
        return filtered.sorted { $0.name < $1.name }
    }
    
    private func isFileEligibleForSubmission(_ file: TextFile) -> Bool {
        // Exclude trashed files
        guard file.trashItem == nil else { return false }
        
        // Exclude files without a parent folder (orphaned)
        guard file.parentFolder != nil else { return false }
        
        // Check if file belongs to project
        guard belongsToProject(file) else { return false }
        
        // Check if this file/version has already been submitted
        return !isAlreadySubmitted(file)
    }
    
    private func belongsToProject(_ file: TextFile) -> Bool {
        var currentFolder = file.parentFolder
        while let folder = currentFolder {
            if folder.project?.id == project.id {
                return true
            }
            currentFolder = folder.parentFolder
        }
        return false
    }
    
    private func isAlreadySubmitted(_ file: TextFile) -> Bool {
        guard let submissions = publication.submissions else { return false }
        guard let currentVersion = file.currentVersion else { return false }
        let fileID: UUID = file.id
        let versionNumber: Int = currentVersion.versionNumber
        
        return submissions.contains { (submission: Submission) -> Bool in
            guard let submittedFiles = submission.submittedFiles else { return false }
            return submittedFiles.contains { (submittedFile: SubmittedFile) -> Bool in
                submittedFile.textFile?.id == fileID && 
                submittedFile.version?.versionNumber == versionNumber
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Publication info (read-only)
                Section {
                    LabeledContent(NSLocalizedString("publications.form.name.label", comment: "Publication")) {
                        HStack {
                            Text(publication.type?.icon ?? "")
                            Text(publication.name)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("submissions.submitting.to", comment: "Submitting to"))
                }
                
                // File selection
                Section {
                    if projectFiles.isEmpty {
                        Text(NSLocalizedString("submissions.no.files.project", comment: "No files in project"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(projectFiles) { file in
                            FileSelectionRow(
                                file: file,
                                isSelected: selectedFiles.contains(file)
                            ) {
                                toggleFileSelection(file)
                            }
                        }
                    }
                } header: {
                    Text(NSLocalizedString("submissions.select.files", comment: "Select files"))
                } footer: {
                    Text(String(format: NSLocalizedString("submissions.files.selected", comment: "Files selected"), selectedFiles.count))
                }
                
                // Submission date
                Section {
                    DatePicker(
                        NSLocalizedString("submissions.date.label", comment: "Submission date"),
                        selection: $submissionDate,
                        displayedComponents: .date
                    )
                    
                    Toggle(NSLocalizedString("submissions.setExpectedDate", comment: "Set expected response date"), isOn: $showExpectedDate)
                    
                    if showExpectedDate {
                        DatePicker(
                            NSLocalizedString("submissions.expectedBy.label", comment: "Response Expected"),
                            selection: Binding(
                                get: { returnExpectedBy ?? Date().addingTimeInterval(90 * 24 * 60 * 60) },
                                set: { returnExpectedBy = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                } header: {
                    Text(NSLocalizedString("submissions.date.label", comment: "Date"))
                }
                
                // Notes
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .accessibilityLabel(Text(NSLocalizedString("submissions.notes.label", comment: "Notes")))
                } header: {
                    Text(NSLocalizedString("submissions.notes.label", comment: "Notes"))
                }
            }
            .navigationTitle(Text(NSLocalizedString("submissions.new.title", comment: "New submission")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                    .accessibilityLabel(Text(NSLocalizedString("accessibility.cancel", comment: "Cancel")))
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("submissions.button.submit", comment: "Submit")) {
                        createSubmission()
                    }
                    .disabled(selectedFiles.isEmpty)
                    .accessibilityLabel(Text(NSLocalizedString("submissions.button.submit", comment: "Submit")))
                    .accessibilityHint(Text(selectedFiles.isEmpty ? 
                        NSLocalizedString("accessibility.submit.disabled", comment: "Submit disabled") :
                        NSLocalizedString("accessibility.submit.enabled", comment: "Submit enabled")))
                }
            }
        }
        .onAppear {
            // Auto-populate expected response date from publication's typical response time
            if let days = publication.typicalResponseDays {
                showExpectedDate = true
                returnExpectedBy = Calendar.current.date(byAdding: .day, value: days, to: Date())
            }
        }
    }
    
    private func toggleFileSelection(_ file: TextFile) {
        if selectedFiles.contains(file) {
            selectedFiles.remove(file)
        } else {
            selectedFiles.insert(file)
        }
    }
    
    private func createSubmission() {
        // Create submission
        let submission = Submission(
            publication: publication,
            project: project,
            submittedDate: submissionDate,
            notes: notes.isEmpty ? nil : notes
        )
        
        // Set expected response date if enabled
        if showExpectedDate {
            submission.returnExpectedBy = returnExpectedBy
        }
        
        // Copy expected response time from publication
        submission.typicalResponseDays = publication.typicalResponseDays
        
        modelContext.insert(submission)
        
        // Create submitted file records for each selected file
        for file in selectedFiles {
            if let currentVersion = file.currentVersion {
                let submittedFile = SubmittedFile(
                    submission: submission,
                    textFile: file,
                    version: currentVersion,
                    status: .pending,
                    statusDate: submissionDate,
                    project: project
                )
                modelContext.insert(submittedFile)
            }
        }
        
        dismiss()
    }
}

struct FileSelectionRow: View {
    let file: TextFile
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    if let version = file.currentVersion {
                        Text(String(format: NSLocalizedString("submissions.version.label", comment: "Version"), version.versionNumber))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(format: NSLocalizedString("accessibility.file.selection", comment: "File selection"), file.name)))
        .accessibilityHint(Text(isSelected ? 
            NSLocalizedString("accessibility.file.selected", comment: "Selected") : 
            NSLocalizedString("accessibility.file.not.selected", comment: "Not selected")))
    }
}