# Phase 3: Submissions Management UI - Detailed Tasks

**Start Date:** 9 November 2025  
**Dependencies:** Phase 2 Complete ✅

## Overview

Phase 3 implements the user interface for creating and managing submissions - linking files to publications and tracking submission status.

## User Workflow

1. User taps "Magazines" in PUBLICATIONS section
2. Sees list of Magazine publications (filtered by type)
3. Taps on a publication (e.g., "Envoi")
4. Sees list of submissions to that publication
5. Can add new submission (select file + version to submit)
6. Can view/edit submission details (status, dates, notes)

---

## Task 1: Update PublicationsListView with Type Filter

### 1.1 Add Type Filter Parameter

**File:** `Views/Publications/PublicationsListView.swift`

```swift
struct PublicationsListView: View {
    @Environment(\.modelContext) private var modelContext
    
    let project: Project
    let publicationType: PublicationType? // nil = show all, non-nil = filter by type
    
    @State private var showingAddSheet = false
    @State private var selectedPublication: Publication?
    
    // Filter publications by type
    private var filteredPublications: [Publication] {
        if let type = publicationType {
            return publications.filter { $0.type == type && $0.project?.id == project.id }
        } else {
            return publications.filter { $0.project?.id == project.id }
        }
    }
    
    var body: some View {
        List {
            if filteredPublications.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredPublications) { publication in
                    PublicationRowView(publication: publication)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPublication = publication
                        }
                }
                .onDelete(perform: deletePublications)
            }
        }
        .navigationTitle(Text(navigationTitle))
        // ... rest of view
    }
    
    private var navigationTitle: String {
        if let type = publicationType {
            switch type {
            case .magazine:
                return NSLocalizedString("publications.magazines.title", comment: "Magazines title")
            case .competition:
                return NSLocalizedString("publications.competitions.title", comment: "Competitions title")
            case .commission:
                return NSLocalizedString("publications.commissions.title", comment: "Commissions title")
            case .other:
                return NSLocalizedString("publications.other.title", comment: "Other title")
            }
        }
        return NSLocalizedString("publications.title", comment: "Publications title")
    }
}
```

### 1.2 Update Localizable.strings

Add:
```strings
"publications.magazines.title" = "Magazines";
"publications.competitions.title" = "Competitions";
"publications.commissions.title" = "Commissions";
"publications.other.title" = "Other";
```

**Acceptance Criteria:**
- ✅ Can show all publications
- ✅ Can filter by specific type
- ✅ Title changes based on type
- ✅ Only shows publications for current project

---

## Task 2: Update PublicationDetailView to Show Submissions

### 2.1 Replace Placeholder with Real Submissions List

**File:** `Views/Publications/PublicationDetailView.swift`

```swift
// Replace placeholder section with:
Section {
    if let submissions = publication.submissions?.sorted(by: { $0.submittedDate > $1.submittedDate }), !submissions.isEmpty {
        ForEach(submissions) { submission in
            NavigationLink(destination: SubmissionDetailView(submission: submission)) {
                SubmissionRowView(submission: submission)
            }
        }
    } else {
        Text(NSLocalizedString("publications.submissions.none", comment: "No submissions"))
            .foregroundStyle(.secondary)
    }
} header: {
    HStack {
        Text(NSLocalizedString("publications.submissions.title", comment: "Submissions title"))
        Spacer()
        Button(action: { showingAddSubmissionSheet = true }) {
            Image(systemName: "plus.circle.fill")
        }
        .accessibilityLabel(Text(NSLocalizedString("accessibility.add.submission", comment: "Add submission")))
    }
}

// Add state:
@State private var showingAddSubmissionSheet = false

// Add sheet:
.sheet(isPresented: $showingAddSubmissionSheet) {
    if let project = publication.project {
        AddSubmissionView(publication: publication, project: project)
    }
}
```

**Acceptance Criteria:**
- ✅ Shows list of submissions sorted by date (newest first)
- ✅ Shows "No submissions" if empty
- ✅ Add button in section header
- ✅ Tapping submission opens detail view

---

## Task 3: Create SubmissionRowView

### 3.1 Row Component

**File:** `Views/Submissions/SubmissionRowView.swift`

```swift
import SwiftUI

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
                Text("Submitted: \(submission.submittedDate, style: .date)")
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
            return "\(files.count) files"
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
        label = label + Text(", submitted \(submission.submittedDate, style: .date)")
        label = label + Text(", status: \(statusText)")
        return label
    }
}
```

### 3.2 Add Localizable Strings

```strings
/* Submissions */
"submissions.no.files" = "No files";
"submissions.status.pending" = "Pending";
"submissions.status.accepted" = "Accepted";
"submissions.status.rejected" = "Rejected";
"submissions.status.mixed" = "Mixed";
"submissions.submitted.on" = "Submitted: %@";

/* Accessibility */
"accessibility.add.submission" = "Add submission";
"accessibility.add.submission.hint" = "Create a new submission for this publication";
"accessibility.submission.row" = "Submission: %@";
```

**Acceptance Criteria:**
- ✅ Shows file name(s) or count
- ✅ Shows submission date
- ✅ Shows status badge with color
- ✅ All strings localized
- ✅ Full accessibility support

---

## Task 4: Create AddSubmissionView

### 4.1 File Selection View

**File:** `Views/Submissions/AddSubmissionView.swift`

```swift
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
                    LabeledContent("Publication") {
                        HStack {
                            Text(publication.type?.icon ?? "")
                            Text(publication.name)
                        }
                    }
                } header: {
                    Text("Submitting To")
                }
                
                // File selection
                Section {
                    if projectFiles.isEmpty {
                        Text("No files in this project")
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
                    Text("Select Files")
                } footer: {
                    Text("\(selectedFiles.count) file(s) selected")
                }
                
                // Submission date
                Section {
                    DatePicker(
                        "Submission Date",
                        selection: $submissionDate,
                        displayedComponents: .date
                    )
                } header: {
                    Text("Date")
                }
                
                // Notes
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                } header: {
                    Text("Notes (optional)")
                }
            }
            .navigationTitle("New Submission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        createSubmission()
                    }
                    .disabled(selectedFiles.isEmpty)
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
                        Text("Version \(version.versionNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

**Acceptance Criteria:**
- ✅ Shows all files in project
- ✅ Multi-select files to submit
- ✅ Shows current version for each file
- ✅ Set submission date (defaults to today)
- ✅ Optional notes field
- ✅ Creates Submission + SubmittedFile records
- ✅ Submit button disabled if no files selected

---

## Task 5: Create SubmissionDetailView

### 5.1 Detail View

**File:** `Views/Submissions/SubmissionDetailView.swift`

```swift
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
                }
            } header: {
                Text("Publication")
            }
            
            // Submission info
            Section {
                LabeledContent("Submitted") {
                    Text(submission.submittedDate, style: .date)
                }
                
                if let notes = submission.notes {
                    LabeledContent("Notes") {
                        Text(notes)
                    }
                }
            } header: {
                Text("Details")
            }
            
            // Submitted files
            Section {
                if let files = submission.submittedFiles, !files.isEmpty {
                    ForEach(files) { submittedFile in
                        SubmittedFileRow(submittedFile: submittedFile)
                    }
                } else {
                    Text("No files")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Files (\(submission.fileCount))")
            }
            
            // Status summary
            Section {
                LabeledContent("Overall Status") {
                    Text(overallStatusText)
                        .foregroundStyle(overallStatusColor)
                }
                
                LabeledContent("Pending") {
                    Text("\(submission.pendingCount)")
                }
                
                LabeledContent("Accepted") {
                    Text("\(submission.acceptedCount)")
                        .foregroundStyle(.green)
                }
                
                LabeledContent("Rejected") {
                    Text("\(submission.rejectedCount)")
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Status")
            }
            
            // Delete
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Submission", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Submission Details")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete Submission?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteSubmission()
            }
        } message: {
            Text("This will delete the submission record but not the files.")
        }
    }
    
    private var overallStatusText: String {
        switch submission.overallStatus {
        case .allAccepted: return "All Accepted"
        case .allRejected: return "All Rejected"
        case .partiallyAccepted: return "Mixed"
        case .pending: return "Pending"
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
                    Text("Version \(version.versionNumber)")
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
                        Label("Pending", systemImage: "clock")
                    }
                    
                    Button {
                        submittedFile.status = .accepted
                        submittedFile.statusDate = Date()
                    } label: {
                        Label("Accepted", systemImage: "checkmark.circle")
                    }
                    
                    Button {
                        submittedFile.status = .rejected
                        submittedFile.statusDate = Date()
                    } label: {
                        Label("Rejected", systemImage: "xmark.circle")
                    }
                } label: {
                    HStack {
                        Text(submittedFile.status?.icon ?? "")
                        Text(submittedFile.status?.displayName ?? "Unknown")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundStyle(statusColor)
                    .cornerRadius(8)
                }
            }
            
            if let statusDate = submittedFile.statusDate {
                Text("Updated: \(statusDate, style: .date)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var statusColor: Color {
        guard let status = submittedFile.status else { return .gray }
        return status.color
    }
}
```

**Acceptance Criteria:**
- ✅ Shows publication (tappable link)
- ✅ Shows submission date and notes
- ✅ Lists all submitted files with versions
- ✅ Shows status summary counts
- ✅ Can change status of individual files
- ✅ Delete confirmation
- ✅ All localized and accessible

---

## Task 6: Add to Navigation

Update `PublicationDetailView` to navigate to submission detail:

```swift
NavigationLink(destination: SubmissionDetailView(submission: submission)) {
    SubmissionRowView(submission: submission)
}
```

**Acceptance Criteria:**
- ✅ Tapping submission row opens detail view
- ✅ Back navigation works

---

## Task 7: Testing

### Manual Testing Checklist

**Create Submission:**
- [ ] Can select multiple files
- [ ] Can set submission date
- [ ] Can add notes
- [ ] Creates submission successfully
- [ ] Submission appears in publication's list

**View Submission:**
- [ ] Shows all submission details
- [ ] Shows correct file count
- [ ] Shows correct status summary
- [ ] Can navigate to publication

**Update Status:**
- [ ] Can change file status (pending/accepted/rejected)
- [ ] Status date updates automatically
- [ ] Overall status recalculates correctly

**Delete Submission:**
- [ ] Shows confirmation
- [ ] Deletes submission and SubmittedFile records
- [ ] Files remain intact

**Accessibility:**
- [ ] VoiceOver announces all elements
- [ ] Status changes announced
- [ ] File selection accessible

---

## Completion Criteria

Phase 3 is complete when:

✅ All 7 tasks implemented  
✅ Can filter publications by type  
✅ Can view submissions for a publication  
✅ Can create new submissions  
✅ Can view submission details  
✅ Can update file status  
✅ All localized and accessible  
✅ Manual testing passed  

---

## Files to Create

1. `Views/Submissions/SubmissionRowView.swift`
2. `Views/Submissions/AddSubmissionView.swift`
3. `Views/Submissions/SubmissionDetailView.swift`

## Files to Update

1. `Views/Publications/PublicationsListView.swift` - Add type filter
2. `Views/Publications/PublicationDetailView.swift` - Show real submissions
3. `Resources/en.lproj/Localizable.strings` - Add submission strings

## Estimated Time

- Task 1 (Filter): 20 minutes
- Task 2 (Update Detail): 15 minutes
- Task 3 (Row View): 30 minutes
- Task 4 (Add Submission): 1 hour
- Task 5 (Detail View): 45 minutes
- Task 6 (Navigation): 10 minutes
- Task 7 (Testing): 30 minutes

**Total: ~3 hours**

---

**Next Phase:** Phase 4 - Version Locking Implementation
