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
    @State private var notes: String = ""
    
    // Filter files for this project
    private var projectFiles: [TextFile] {
        allFiles.filter { file in
            // Navigate up through folders to find project
            var currentFolder = file.parentFolder
            while let folder = currentFolder {
                if folder.project?.id == project.id {
                    return true
                }
                currentFolder = folder.parentFolder
            }
            return false
        }.sorted { $0.name < $1.name }
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

#Preview("With Files") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, Publication.self, TextFile.self, Folder.self, configurations: config)
    let context = container.mainContext
    
    let project = Project(name: "Test Project")
    let publication = Publication(name: "Test Magazine", type: .magazine, project: project)
    
    let rootFolder = Folder(name: "Test Project", fileURL: URL(fileURLWithPath: "/tmp/test"), isRoot: true, project: project)
    
    let file1 = TextFile(name: "Story1.txt", folderURL: URL(fileURLWithPath: "/tmp/test"), project: project)
    file1.parentFolder = rootFolder
    let version1 = Version(textFile: file1, project: project)
    file1.currentVersion = version1
    
    let file2 = TextFile(name: "Story2.txt", folderURL: URL(fileURLWithPath: "/tmp/test"), project: project)
    file2.parentFolder = rootFolder
    let version2 = Version(textFile: file2, project: project)
    file2.currentVersion = version2
    
    context.insert(project)
    context.insert(publication)
    context.insert(rootFolder)
    context.insert(file1)
    context.insert(version1)
    context.insert(file2)
    context.insert(version2)
    
    AddSubmissionView(publication: publication, project: project)
        .modelContainer(container)
}

#Preview("No Files") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, Publication.self, configurations: config)
    let context = container.mainContext
    
    let project = Project(name: "Empty Project")
    let publication = Publication(name: "Test Competition", type: .competition, project: project)
    
    context.insert(project)
    context.insert(publication)
    
    AddSubmissionView(publication: publication, project: project)
        .modelContainer(container)
}
