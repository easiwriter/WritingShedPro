//
//  AddToSubmissionSheet.swift
//  Writing Shed Pro
//
//  Sheet that lets the user add selected files to an existing submission
//  or create a new submission to hold them.
//

import SwiftUI
import SwiftData

struct AddToSubmissionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    let filesToAdd: [TextFile]
    
    @Query private var allSubmissions: [Submission]
    @State private var showNewSubmissionForm = false
    @State private var newSubmissionName: String = ""
    @State private var isProcessing = false
    
    /// Only non-collection submissions that belong to this project
    private var projectSubmissions: [Submission] {
        let pid = project.id
        return allSubmissions
            .filter { !$0.isCollection && $0.project?.id == pid }
            .sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
    }
    
    /// Default name for a new submission based on the files
    private var defaultName: String {
        if filesToAdd.count == 1 {
            return filesToAdd[0].name
        } else if filesToAdd.count > 1 {
            return "\(filesToAdd[0].name) + \(filesToAdd.count - 1) more"
        }
        return "Submission"
    }
    
    var body: some View {
        NavigationStack {
            List {
                // New submission option
                Section {
                    if showNewSubmissionForm {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(
                                NSLocalizedString("submissions.name.placeholder", comment: "Name"),
                                text: $newSubmissionName
                            )
                            .textInputAutocapitalization(.words)
                            
                            HStack {
                                Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                                    withAnimation {
                                        showNewSubmissionForm = false
                                        newSubmissionName = ""
                                    }
                                }
                                .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Button(NSLocalizedString("button.create", comment: "Create")) {
                                    createNewSubmission()
                                }
                                .disabled(newSubmissionName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            .font(.subheadline)
                        }
                    } else {
                        Button {
                            newSubmissionName = defaultName
                            withAnimation {
                                showNewSubmissionForm = true
                            }
                        } label: {
                            Label(
                                NSLocalizedString("submissions.new", comment: "New Submission"),
                                systemImage: "plus.circle.fill"
                            )
                            .foregroundStyle(.blue)
                        }
                    }
                }
                
                // Existing submissions
                if !projectSubmissions.isEmpty {
                    Section {
                        ForEach(projectSubmissions) { submission in
                            Button {
                                addFiles(to: submission)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(submission.name ?? NSLocalizedString("submission.untitled", comment: "Untitled"))
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        
                                        let count = submission.submittedFiles?.count ?? 0
                                        Text("\(count) \(count == 1 ? "file" : "files")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Show publication badge if submitted
                                    if let pub = submission.publication {
                                        Text(pub.name)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("submissions.existing", comment: "Existing Submissions"))
                    }
                }
                
                // Files being added (info section)
                Section {
                    ForEach(filesToAdd, id: \.id) { file in
                        Label(file.name, systemImage: "doc.text")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(String(format: NSLocalizedString("submissions.addingFiles", comment: "Adding %d files"), filesToAdd.count))
                }
            }
            .navigationTitle(NSLocalizedString("submissions.addTo", comment: "Add to Submission"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func createNewSubmission() {
        let name = newSubmissionName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !isProcessing else { return }
        isProcessing = true
        
        // Reset form state first
        showNewSubmissionForm = false
        newSubmissionName = ""
        
        let submission = Submission(
            project: project,
            submittedDate: Date()
        )
        submission.name = name
        submission.isCollection = false
        modelContext.insert(submission)
        
        insertFilesAndDismiss(submission)
    }
    
    private func addFiles(to submission: Submission) {
        guard !isProcessing else { return }
        isProcessing = true
        
        // Reset form state to prevent accidental double-creation
        showNewSubmissionForm = false
        newSubmissionName = ""
        
        insertFilesAndDismiss(submission)
    }
    
    private func insertFilesAndDismiss(_ submission: Submission) {
        for file in filesToAdd {
            // Skip if file is already in this submission
            let alreadyAdded = submission.submittedFiles?.contains(where: { $0.textFile?.id == file.id }) ?? false
            guard !alreadyAdded else { continue }
            
            if let currentVersion = file.currentVersion {
                let submittedFile = SubmittedFile(
                    submission: submission,
                    textFile: file,
                    version: currentVersion,
                    status: .pending,
                    statusDate: Date(),
                    project: project
                )
                modelContext.insert(submittedFile)
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[AddToSubmission] Save error: \(error)")
            #endif
        }
        
        dismiss()
    }
}
