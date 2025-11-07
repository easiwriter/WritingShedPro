# Feature Specification: Publication Management System

**Feature Branch**: `008b-publication-system`  
**Created**: 2025-11-07  
**Status**: Specification Complete (Deferred to Phase 2)  
**Parent Feature**: 008-file-movement (split into 008a and 008b)  
**Depends On**: Feature 008a (File Movement)

## Overview

Professional publication management system for tracking submissions to magazines and poetry competitions. Maintains version history, submission status, and auto-populates a Published folder with accepted work.

## Scope

**This Feature (008b):**
- Publication entity (magazines, competitions)
- Submission tracking with version references
- Status tracking (pending/accepted/rejected)
- SubmittedFile join table with status and version
- Published folder (auto-populated computed view)
- Submission history by publication

**Previous Feature (008a - File Movement):**
- Moving files between source folders
- Trash with Put Back
- Multi-file selection

---

## Conceptual Model

```
Publication (Magazine/Competition)
    ↓
  Submission (Group of files + date)
    ↓
  SubmittedFile (File + Version + Status)
    ↓
  Published Folder (Auto-populated view of accepted work)
```

**Key Insight:** Publications and submissions are **tracking entities**, not folders. Files stay in their source folders (Draft/Ready/Set Aside) but have metadata references showing submission history.

---

## Data Model

### Publication Model (New)

```swift
@Model
class Publication {
  var id: UUID
  var name: String                    // "Poetry Magazine"
  var type: PublicationType           // .magazine or .competition
  var url: String?                    // Optional website
  var notes: String?                  // Optional notes
  var project: Project
  
  var submissions: [Submission]       // All submissions to this publication
  
  var createdDate: Date
  var modifiedDate: Date
}

enum PublicationType: String, Codable {
  case magazine
  case competition
}
```

### Submission Model (New)

```swift
@Model
class Submission {
  var id: UUID
  var publication: Publication        // Which magazine/competition
  var project: Project
  
  var submittedFiles: [SubmittedFile] // Join table to files
  
  var submittedDate: Date             // When submitted
  var notes: String?                  // Optional notes
  
  var createdDate: Date
  var modifiedDate: Date
}
```

### SubmittedFile Model (New - Join Table)

```swift
@Model
class SubmittedFile {
  var id: UUID
  var submission: Submission          // Which submission
  var textFile: TextFile              // Which file
  var version: Version                // Exact version submitted
  
  var status: SubmissionStatus        // pending/accepted/rejected
  var statusDate: Date?               // When status changed
  var statusNotes: String?            // Optional rejection/acceptance notes
  
  var project: Project
  
  var createdDate: Date
  var modifiedDate: Date
}

enum SubmissionStatus: String, Codable {
  case pending
  case accepted
  case rejected
}
```

---

## Source Folders vs Published Folder

### Source Folders (Physical Storage)

Files **live** in these folders:
- **Draft** - Work in progress
- **Ready** - Ready for submission
- **Set Aside** - Paused work

When a file is accepted, it **stays** in its source folder (e.g., Ready or Set Aside).

### Published Folder (Computed View)

The Published folder is **not a physical folder**. It's a **filtered view** showing all files where:

```
SubmittedFile.status == .accepted
```

**Characteristics:**
- ✅ Automatically populated (no manual moves)
- ✅ Shows all accepted work across all submissions
- ✅ Grouped by publication or date
- ✅ Shows version that was accepted
- ❌ Cannot manually add files
- ❌ Cannot move files into it
- ❌ Not a real Folder model

**Implementation:**
```swift
struct PublishedFolderView: View {
    let project: Project
    
    var publishedFiles: [SubmittedFile] {
        project.submissions
            .flatMap { $0.submittedFiles }
            .filter { $0.status == .accepted }
    }
}
```

---

## User Stories

### US1: Create Publication (Priority: P1)

**As a** poet  
**I want to** add Poetry Magazine to my list of publications  
**So that** I can track submissions to this magazine

**Why this priority:** Foundation for submission tracking

**Independent Test:** Create publication, verify persists, verify syncs

**Acceptance Scenarios:**

1. **Given** project view, **When** user taps "Publications", **Then** publications list appears
2. **Given** empty publications list, **When** user taps "+", **Then** new publication form appears
3. **Given** new publication form, **When** user enters "Poetry Magazine" and selects type "Magazine", **Then** publication is created
4. **Given** publication created, **When** viewing publications list, **Then** "Poetry Magazine" appears

---

### US2: Submit Files to Publication (Priority: P1)

**As a** poet  
**I want to** submit 3 poems to Poetry Magazine  
**So that** I can track which poems I've sent there

**Why this priority:** Core submission workflow

**Independent Test:** Select 3 files, create submission, verify SubmittedFile records created

**Acceptance Scenarios:**

1. **Given** file list in Ready folder, **When** user selects 3 files (edit mode), **Then** "Submit..." button appears in toolbar
2. **Given** 3 files selected, **When** user taps "Submit...", **Then** publication picker appears
3. **Given** publication picker, **When** user selects "Poetry Magazine", **Then** submission created with 3 SubmittedFile records
4. **Given** submission created, **When** viewing file details, **Then** submission history shows "Submitted to Poetry Magazine on {date}"
5. **Given** submission created, **When** user edits file, **Then** version reference in SubmittedFile remains unchanged (points to submitted version)

---

### US3: Track Submission Status (Priority: P1)

**As a** poet  
**I want to** mark a submission as accepted or rejected  
**So that** I know the outcome

**Why this priority:** Essential tracking

**Independent Test:** Create submission, change status to accepted, verify status change

**Acceptance Scenarios:**

1. **Given** submission with status "pending", **When** user taps submission, **Then** detail view shows status options
2. **Given** status options, **When** user selects "Accepted", **Then** status changes to "accepted" and statusDate set to today
3. **Given** submission marked accepted, **When** viewing submissions list, **Then** submission shows "✓ Accepted" badge
4. **Given** file accepted, **When** viewing Published folder, **Then** file appears in Published folder view

---

### US4: View Published Folder (Priority: P1)

**As a** writer  
**I want to** see all my accepted work in one place  
**So that** I can celebrate my successes

**Why this priority:** Key deliverable of feature

**Independent Test:** Accept 3 files from different submissions, verify all appear in Published folder

**Acceptance Scenarios:**

1. **Given** folder sidebar, **When** viewing project, **Then** "Published" folder appears (distinct icon)
2. **Given** 2 files accepted, **When** user taps Published folder, **Then** both files appear
3. **Given** Published folder view, **When** viewing file, **Then** shows publication name and acceptance date
4. **Given** file in Published folder, **When** user taps file, **Then** opens to the accepted version (not current version)

---

### US5: View Submission History (Priority: P2)

**As a** poet  
**I want to** see all submissions to Poetry Magazine  
**So that** I can track my relationship with this publication

**Why this priority:** Useful analytics but not critical

**Independent Test:** Create 3 submissions to one publication, verify history list

**Acceptance Scenarios:**

1. **Given** publication detail view, **When** user taps "Poetry Magazine", **Then** submission history appears
2. **Given** 3 submissions to this publication, **When** viewing history, **Then** all 3 submissions listed with dates
3. **Given** submission in history, **When** user taps submission, **Then** shows submitted files and statuses
4. **Given** submission detail, **When** viewing, **Then** shows which version of each file was submitted

---

### US6: Prevent Duplicate Submissions (Priority: P2)

**As a** writer  
**I want to** be warned if I'm resubmitting a file to the same publication  
**So that** I don't accidentally submit the same poem twice

**Why this priority:** Quality of life, not blocking

**Independent Test:** Submit file to publication, try to submit again, verify warning

**Acceptance Scenarios:**

1. **Given** file already submitted to "Poetry Magazine" with status "pending", **When** user tries to submit same file again, **Then** warning appears
2. **Given** warning about duplicate, **When** user confirms, **Then** new submission proceeds (allows intentional resubmission)
3. **Given** file previously rejected by "Poetry Magazine", **When** user submits again, **Then** NO warning (rejection allows resubmission)
4. **Given** file accepted by "Poetry Magazine", **When** user tries to submit again, **Then** stronger warning "Already accepted by this publication"

---

## Functional Requirements

### Publications

- **FR-001**: Users MUST be able to create publications with name and type
- **FR-002**: Publication types MUST be magazine or competition
- **FR-003**: Publications MUST be project-scoped (not global)
- **FR-004**: Publications MUST support optional URL and notes fields
- **FR-005**: Publications MUST list all submissions to that publication

### Submissions

- **FR-006**: Submissions MUST reference a Publication
- **FR-007**: Submissions MUST contain 1+ SubmittedFile records
- **FR-008**: Submissions MUST record submittedDate
- **FR-009**: Users MUST be able to add notes to submissions
- **FR-010**: Submissions MUST support bulk file selection (same as 008a edit mode)

### SubmittedFile (Join Table)

- **FR-011**: SubmittedFile MUST reference exact Version submitted (not just TextFile)
- **FR-012**: Version reference MUST be immutable after creation
- **FR-013**: SubmittedFile MUST track status (pending/accepted/rejected)
- **FR-014**: Status changes MUST record statusDate
- **FR-015**: Status MUST support optional notes field
- **FR-016**: Editing file after submission MUST NOT affect submitted version reference

### Published Folder

- **FR-017**: Published folder MUST show all files with status=accepted
- **FR-018**: Published folder MUST be auto-populated (no manual adds)
- **FR-019**: Opening file from Published folder MUST show accepted version (not latest)
- **FR-020**: Published folder MUST group by publication or date (user preference)
- **FR-021**: Published folder icon MUST be visually distinct from source folders
- **FR-022**: Deleting accepted file from source folder MUST still show in Published folder (soft reference)

### Version Integrity

- **FR-023**: SubmittedFile.version MUST remain valid even if Version deleted
- **FR-024**: System MUST preserve submitted version content (no orphan versions)
- **FR-025**: Version snapshots MUST be immutable
- **FR-026**: Viewing submitted version MUST show exact content at submission time

### CloudKit Sync

- **FR-027**: Publication, Submission, SubmittedFile MUST sync across devices
- **FR-028**: Status changes MUST sync within 5 seconds
- **FR-029**: Version references MUST sync correctly

---

## Success Criteria

- **SC-001**: Users can create submission in under 30 seconds (select files → choose publication → done)
- **SC-002**: Published folder accurately shows all accepted work (100% accuracy)
- **SC-003**: Submission history clearly shows version submitted vs current version
- **SC-004**: Zero data loss for accepted work (version preservation)
- **SC-005**: Status changes sync across devices within 5 seconds
- **SC-006**: Published folder performs well with 100+ accepted files
- **SC-007**: Duplicate submission warnings catch 95%+ of accidental resubmissions

---

## UI Mockups

### Publications List

```
┌─────────────────────────────────────┐
│ ← Publications                  [+] │
├─────────────────────────────────────┤
│                                     │
│ 📰 Poetry Magazine                  │
│    12 submissions • 8 accepted      │
│                                     │
│ 🏆 National Poetry Competition      │
│    3 submissions • 1 accepted       │
│                                     │
│ 📰 The Writer's Review              │
│    5 submissions • 2 accepted       │
│                                     │
└─────────────────────────────────────┘
```

### Create Submission Flow

```
Step 1: Select Files (reuse 008a edit mode)
┌─────────────────────────────────────┐
│ Ready (8 items)         [Cancel]    │
├─────────────────────────────────────┤
│ ⚫ sunset-poem.txt              📄  │
│ ⚫ morning-haiku.txt            📄  │
│ ⚫ love-sonnet.txt              📄  │
│ ⚪ another-poem.txt             📄  │
└─────────────────────────────────────┘
  [Submit 3 items...]

Step 2: Choose Publication
┌─────────────────────────────────────┐
│ Submit to Publication    [Cancel]   │
├─────────────────────────────────────┤
│ ⚪ Poetry Magazine                  │
│ ⚫ National Poetry Competition      │ ← Selected
│ ⚪ The Writer's Review              │
│                                     │
│ [+ Create New Publication]          │
└─────────────────────────────────────┘
  [Submit]

Step 3: Confirmation
┌─────────────────────────────────────┐
│ ✓ Submitted                         │
├─────────────────────────────────────┤
│ 3 poems submitted to                │
│ National Poetry Competition         │
│                                     │
│ Status: Pending                     │
│                                     │
│ [View Submission]  [Done]           │
└─────────────────────────────────────┘
```

### Submission Detail

```
┌─────────────────────────────────────┐
│ ← National Poetry Competition       │
├─────────────────────────────────────┤
│ Submitted: Nov 7, 2025              │
│                                     │
│ Files (3):                          │
│ ✓ sunset-poem.txt (v2) - Accepted   │
│ ✗ morning-haiku.txt (v1) - Rejected │
│ ⏳ love-sonnet.txt (v1) - Pending   │
│                                     │
│ Notes:                              │
│ [Add notes about this submission]   │
│                                     │
└─────────────────────────────────────┘
```

### Published Folder

```
┌─────────────────────────────────────┐
│ ← Published (12 items)              │
├─────────────────────────────────────┤
│ Group by: Publication ▼             │
│                                     │
│ 📰 Poetry Magazine (8)              │
│   sunset-poem.txt (v2)              │
│   accepted Nov 7, 2025              │
│                                     │
│   winter-haiku.txt (v1)             │
│   accepted Oct 15, 2025             │
│                                     │
│ 🏆 National Poetry Competition (4)  │
│   love-sonnet.txt (v1)              │
│   accepted Sep 1, 2025              │
│                                     │
└─────────────────────────────────────┘
```

---

## Edge Cases

### Publications
- Deleting publication with submissions → Warn user, cascade delete or block
- Renaming publication → Update all submissions
- Publication with 100+ submissions → Performance considerations

### Submissions
- Submitting file with no saved version → Warn or auto-create version
- Submitting same 3 files twice to different publications → Allow
- Deleting submitted file → Keep SubmittedFile reference, mark file as deleted
- Editing file after submission → Version reference unchanged

### Status
- Changing status from accepted to rejected → Remove from Published folder
- Multiple status changes → Track history (future)
- Concurrent status changes on different devices → Last-write-wins

### Published Folder
- File accepted then source file deleted → Still appears in Published (with warning icon)
- File accepted multiple times by different publications → Shows multiple entries
- Opening deleted file from Published → Show archived version or error
- 1000+ published files → Pagination or virtualization

### Version Integrity
- Deleting Version that's referenced by SubmittedFile → Prevent deletion or soft delete
- Editing file creates new Version → SubmittedFile reference unchanged
- Version content corrupted → Show error, attempt recovery

---

## Out of Scope (This Feature)

- ❌ Submission deadlines/reminders
- ❌ Automated submission emails
- ❌ Payment tracking
- ❌ Contract management
- ❌ Rights management
- ❌ Multi-author submissions
- ❌ Publication acceptance rates / statistics
- ❌ Export submission history to CSV
- ❌ Archiving old submissions
- ❌ Global publication database (shared across projects)

---

## Dependencies

- **Feature 001**: Project model
- **Feature 002**: Folder structure
- **Feature 003**: TextFile and Version models (CRITICAL - version references)
- **Feature 004**: Undo/redo system
- **Feature 008a**: File movement and multi-selection UI
- **CloudKit**: Sync Publication, Submission, SubmittedFile
- **SwiftData**: Complex many-to-many relationships

---

## Implementation Notes

### Version Reference Integrity

**Critical Design Decision:** SubmittedFile references Version (not TextFile) to preserve exact content submitted.

```swift
// When creating submission:
let currentVersion = textFile.currentVersion ?? textFile.createVersion()
let submittedFile = SubmittedFile(
    submission: submission,
    textFile: textFile,
    version: currentVersion,  // ← Locks to this specific version
    status: .pending
)

// Later edits create new versions but don't affect submitted version:
textFile.edit("New content")  // Creates v2
// submittedFile.version still points to v1
```

**Version Deletion Prevention:**
```swift
// Before deleting version:
let isReferenced = context.fetch(
    FetchDescriptor<SubmittedFile>(
        predicate: #Predicate { $0.version.id == versionToDelete.id }
    )
).isEmpty == false

if isReferenced {
    throw DeletionError.versionReferencedBySubmission
}
```

### Published Folder Implementation

```swift
struct PublishedFolderView: View {
    let project: Project
    @State private var grouping: Grouping = .byPublication
    
    enum Grouping { case byPublication, byDate }
    
    var publishedFiles: [SubmittedFile] {
        project.submissions
            .flatMap { $0.submittedFiles }
            .filter { $0.status == .accepted }
            .sorted { $0.statusDate ?? Date.distantPast > $1.statusDate ?? Date.distantPast }
    }
    
    var groupedFiles: [String: [SubmittedFile]] {
        Dictionary(grouping: publishedFiles) { submittedFile in
            switch grouping {
            case .byPublication:
                return submittedFile.submission.publication.name
            case .byDate:
                return submittedFile.statusDate?.formatted(.dateTime.year().month()) ?? "Unknown"
            }
        }
    }
}
```

### Duplicate Submission Detection

```swift
func checkDuplicate(file: TextFile, publication: Publication) -> DuplicateStatus {
    let existingSubmissions = publication.submissions
        .flatMap { $0.submittedFiles }
        .filter { $0.textFile.id == file.id }
    
    if existingSubmissions.isEmpty {
        return .none
    }
    
    let hasAccepted = existingSubmissions.contains { $0.status == .accepted }
    if hasAccepted {
        return .strongWarning("Already accepted by this publication")
    }
    
    let hasPending = existingSubmissions.contains { $0.status == .pending }
    if hasPending {
        return .warning("Already submitted (pending)")
    }
    
    return .info("Previously rejected - OK to resubmit")
}
```

---

## Testing Strategy

### Unit Tests (~20 tests)

1. **Publication Tests**:
   - Create publication
   - List submissions for publication
   - Delete publication handling

2. **Submission Tests**:
   - Create submission with multiple files
   - Version reference immutability
   - Status transitions

3. **SubmittedFile Tests**:
   - Create with version reference
   - Status change updates statusDate
   - Version reference integrity

4. **Published Folder Logic**:
   - Filter only accepted files
   - Grouping by publication
   - Grouping by date

### Integration Tests (~15 tests)

1. **Full Submission Workflow**:
   - Select 3 files → Create submission → Verify SubmittedFile records → Change status → Verify Published folder

2. **Version Integrity**:
   - Submit file v1 → Edit file (creates v2) → Verify submission still references v1

3. **CloudKit Sync**:
   - Create submission on device 1 → Verify syncs to device 2
   - Change status on device 2 → Verify syncs to device 1

4. **Edge Cases**:
   - Delete file with pending submission
   - Delete version referenced by submission
   - Concurrent status changes

### UI Tests (~8 tests)

1. Create publication workflow
2. Select files and submit workflow
3. View submission detail
4. Change submission status
5. View Published folder
6. Group Published folder by publication/date
7. Duplicate submission warning
8. Open file from Published folder (correct version)

---

## Localization

```
"publication.create" = "New Publication"
"publication.name" = "Publication Name"
"publication.type.magazine" = "Magazine"
"publication.type.competition" = "Competition"
"publication.url" = "Website"
"publication.notes" = "Notes"
"publication.empty" = "No publications yet"

"submission.create" = "Submit..."
"submission.submitTo" = "Submit to {publication}"
"submission.submitted" = "Submitted {count} files to {publication}"
"submission.pending" = "Pending"
"submission.accepted" = "Accepted"
"submission.rejected" = "Rejected"
"submission.changeStatus" = "Change Status"
"submission.history" = "Submission History"
"submission.empty" = "No submissions yet"

"published.title" = "Published"
"published.groupBy" = "Group by"
"published.byPublication" = "Publication"
"published.byDate" = "Date"
"published.accepted" = "Accepted {date}"
"published.empty" = "No published work yet"
"published.version" = "Version {number}"

"duplicate.warning" = "Already submitted"
"duplicate.strongWarning" = "Already accepted by this publication"
"duplicate.info" = "Previously rejected - OK to resubmit"
"duplicate.continue" = "Submit Anyway"

"version.submitted" = "Submitted version {number}"
"version.current" = "Current version {number}"
"version.viewing" = "Viewing submitted version"
```

---

## Migration from Feature 008a

**Data Migration:** None required - this is a new feature with new models.

**UI Changes:**
- Add Publications section to project sidebar
- Add Published folder to folder list (after Trash)
- Add "Submit..." button to file selection toolbar (reuse edit mode from 008a)
- Add publication/submission views

**Service Extensions:**
- None - this is a new SubmissionService

---

**Status:** 📋 Specification Complete (Deferred to Phase 2)  
**Complexity:** High  
**Estimated Effort:** 3-4 weeks  
**Depends On:** Feature 008a (File Movement)  
**Blocked By:** None (but should complete 008a first)

---

## Notes for Future Implementation

**When starting this feature:**
1. Implement Publication model first (simplest, no dependencies)
2. Then Submission model
3. Then SubmittedFile (most complex due to version references)
4. Test version integrity thoroughly before moving to UI
5. Implement Published folder as computed view last
6. Consider performance optimizations for large submission histories

**Key Risks:**
- Version reference integrity (test thoroughly)
- CloudKit sync with complex relationships
- Performance with hundreds of submissions
- Concurrent editing and status changes

**Success Metrics:**
- Zero data loss for submitted versions
- Published folder always accurate
- Submission workflow takes < 30 seconds
- Duplicate detection catches 95%+ of cases
