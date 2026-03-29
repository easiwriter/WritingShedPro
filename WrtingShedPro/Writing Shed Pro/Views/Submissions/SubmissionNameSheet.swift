//
//  SubmissionNameSheet.swift
//  Writing Shed Pro
//
//  Replacement for the simple alert-based submission name prompt.
//  Shows a text field to create a new submission AND a list of
//  existing submissions to add files to.
//

import SwiftUI
import SwiftData

struct SubmissionNameSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    let filesToSubmit: [TextFile]
    let onCreateNew: (String) -> Void
    let onSelectExisting: (Submission) -> Void
    
    @State private var newSubmissionName: String = ""
    
    @Query private var allSubmissions: [Submission]
    
    /// Existing non-collection submissions for this project
    private var existingSubmissions: [Submission] {
        let projectID = project.id
        return allSubmissions
            .filter { $0.project?.id == projectID && !$0.isCollection }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // New submission section
                Section {
                    TextField(NSLocalizedString("submissions.name.placeholder", comment: "Name"), text: $newSubmissionName)
                        .textInputAutocapitalization(.words)
                    
                    Button(NSLocalizedString("button.create", comment: "Create")) {
                        onCreateNew(newSubmissionName)
                        dismiss()
                    }
                    .disabled(newSubmissionName.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text(NSLocalizedString("submissions.new.title", comment: "New Submission"))
                } footer: {
                    Text(String(format: NSLocalizedString("submissions.addingFiles", comment: "Adding files"), filesToSubmit.count))
                }
                
                // Existing submissions section
                if !existingSubmissions.isEmpty {
                    Section {
                        ForEach(existingSubmissions) { submission in
                            Button {
                                onSelectExisting(submission)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(submission.name ?? NSLocalizedString("submissions.untitled", comment: "Untitled"))
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        
                                        Text(String(format: NSLocalizedString("submissions.files.count.short", comment: "File count"), submission.fileCount))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("submissions.existing", comment: "Existing Submissions"))
                    }
                }
            }
            .navigationTitle(NSLocalizedString("submissions.name.title", comment: "Name Submission"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
