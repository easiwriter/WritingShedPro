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
    @State private var showingRecordResponse = false
    @State private var responseDate: Date = Date()
    
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
                
                if let expectedDate = submission.returnExpectedBy {
                    LabeledContent(NSLocalizedString("submissions.expectedBy.label", comment: "Response Expected")) {
                        Text(expectedDate, style: .date)
                    }
                }
                
                if let returnedDate = submission.returnedOn {
                    LabeledContent(NSLocalizedString("submissions.returnedOn.label", comment: "Response Received")) {
                        Text(returnedDate, style: .date)
                    }
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
            
            // Record response (only show if not already received)
            if submission.returnedOn == nil {
                Section {
                    if showingRecordResponse {
                        DatePicker(
                            NSLocalizedString("submissions.returnedOn.label", comment: "Response Received"),
                            selection: $responseDate,
                            displayedComponents: .date
                        )
                        
                        Button(NSLocalizedString("submissions.saveResponse", comment: "Save Response Date")) {
                            submission.returnedOn = responseDate
                            submission.modifiedDate = Date()
                            showingRecordResponse = false
                        }
                    } else {
                        Button {
                            showingRecordResponse = true
                        } label: {
                            Label(NSLocalizedString("submissions.recordResponse", comment: "Record Response"), systemImage: "calendar.badge.checkmark")
                        }
                    }
                } header: {
                    Text(NSLocalizedString("submissions.response.section", comment: "Response"))
                }
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
        .navigationBarBackButtonHidden(true)
        .onPopToRoot {
            dismiss()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PopToRootBackButton()
            }
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
        #if DEBUG
        print("🖨️ Print Submission button tapped")
        #endif
        
        // Get the view controller to present from
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let viewController = window.rootViewController else {
            #if DEBUG
            print("❌ Could not find view controller for print dialog")
            #endif
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
                #if DEBUG
                print("❌ Print failed: \(error.localizedDescription)")
                #endif
                printErrorMessage = error.localizedDescription
                showPrintError = true
            } else if success {
                #if DEBUG
                print("✅ Print completed successfully")
                #endif
            } else {
                #if DEBUG
                print("⚠️ Print was cancelled")
                #endif
            }
        }
    }
    
    private func updateStatus(_ submittedFile: SubmittedFile, to status: SubmissionStatus) {
        submittedFile.status = status
        submittedFile.statusDate = Date()
        
        // If accepted, update file's workflow status to published
        if status == .accepted, let file = submittedFile.textFile {
            file.workflowStatus = .published
            file.modifiedDate = Date()
        }
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