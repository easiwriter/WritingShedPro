# Feature Specification: File Movement & Publication Management System

**Feature Branch**: `008-file-movement-system`  
**Created**: 2025-11-07  
**Status**: Draft  
**Input**: Enable file movement between folders and professional publication/submission tracking

## Overview

This feature enables two major capabilities:

1. **File Movement System**: Move files between appropriate folders within a project
2. **Publication Management**: Track submissions to publications with version control and acceptance status

## Scope

**Phase 1 (This Feature):** 
- File movement for Poetry and Short Story projects
- Publication and submission tracking system
- File status tracking (pending, accepted, rejected)

**Phase 2 (Future):** 
- Novel and Script projects (have special attributes requiring different workflows)

---

## Part 1: Folder Classification & File Movement

### Source Folders

Source folders contain written work in various stages. Files can be moved freely between source folders within the same project.

**Poetry Projects:**
- **Draft** - Work in progress
- **Ready** - Ready for submission (files must be here before creating submissions)
- **Set Aside** - Paused/archived work

**Short Story Projects:**
- **Draft** - Work in progress
- **Ready** - Ready for submission
- **Set Aside** - Paused/archived work

**Novel Projects (Phase 2):**
- **Scenes** - Individual scene files
- **Set Aside** - Paused scenes

**Script Projects (Phase 2):**
- **Scenes** - Individual scene files  
- **Set Aside** - Paused scenes

### System-Managed Folders

**Published:**
- Auto-populated when files are marked as "accepted"
- Shows all files that have been accepted by any publication
- Users cannot manually move files here
- Files are **copied** here (originals stay in source folders)

**Trash:**
- Accepts files from ANY source folder
- Supports "Put Back" command to restore to original location
- Requires TrashItem model to track original folder

### Publication Container Folders (Deprecated)

The following folders are **no longer used** as simple containers:
- ~~Magazines~~
- ~~Competitions~~
- ~~Commissions~~
- ~~Other~~

These are replaced by the **Publication Management System** (see Part 2).

---

## Part 2: Publication Management System

### Concept

Instead of manually organizing files in folders, users create **Publication** objects (magazines, competitions, etc.) and **Submission** objects that reference specific file versions.

### Data Model

#### Publication Model (New)

```
@Model
class Publication {
  var id: UUID
  var name: String                    // e.g., "Poetry Monthly"
  var type: PublicationType           // magazine, competition, commission, other
  var project: Project                // Parent project
  var submissions: [Submission]       // All submissions to this publication
  var createdDate: Date
  var notes: String?                  // Contact info, submission guidelines, etc.
}

enum PublicationType: String {
  case magazine
  case competition
  case commission
  case other
}
```

#### Submission Model (New)

```
@Model
class Submission {
  var id: UUID
  var publication: Publication        // Which publication
  var submittedFiles: [SubmittedFile] // Many-to-many through join model
  var submissionDate: Date
  var deadline: Date?
  var notes: String?                  // Cover letter, requirements met, etc.
  var project: Project                // Parent project
}
```

#### SubmittedFile Model (New - Join Table)

```
@Model
class SubmittedFile {
  var id: UUID
  var submission: Submission          // Parent submission
  var textFile: TextFile              // The actual file
  var fileVersion: Version            // Specific version submitted
  var status: SubmissionStatus        // Per-file status
  var statusDate: Date?               // When status changed
  var responseNotes: String?          // Feedback from publication
}

enum SubmissionStatus: String {
  case pending      // Awaiting response
  case accepted     // Accepted for publication
  case rejected     // Rejected
  case withdrawn    // User withdrew submission
}
```

#### TrashItem Model (New)

```
@Model
class TrashItem {
  var id: UUID
  var textFile: TextFile              // The trashed file
  var originalFolder: Folder          // Where it came from
  var originalParentFolder: Folder?   // If nested (for future)
  var deletedDate: Date
  var project: Project
}
```

### Workflow Example

**Submitting a Poem to a Magazine:**

1. User has poem file in **Ready** folder
2. User creates **Publication** "Poetry Monthly" (or selects existing)
3. User creates **Submission** for "Poetry Monthly"
4. User adds files to submission (can add multiple poems)
5. System creates **SubmittedFile** records linking:
   - Submission → File → Specific Version
   - Status: Pending (default)
6. File(s) remain in Ready folder

**When Publication Responds:**

7a. **If Accepted:**
   - User marks SubmittedFile status → Accepted
   - System automatically **copies** file to Published folder
   - Original stays in Ready folder

7b. **If Rejected:**
   - User marks SubmittedFile status → Rejected
   - File stays in Ready (can submit elsewhere)

**Partial Acceptance:**
- Submission has 3 poems
- Publication accepts 2, rejects 1
- Only the 2 accepted files appear in Published folder

---

## File Movement Rules

### Between Source Folders

Files can move freely between source folders:

```
Draft ⟷ Ready ⟷ Set Aside
  ↓       ↓        ↓
         Trash
```

**Validation:**
- ✅ Within same project only
- ✅ From any source to any source
- ✅ File can be in submission and still moveable
- ⚠️ Warning if file is in pending submission

### To Published Folder

**Automatic Only:**
- User cannot manually move files to Published
- System copies file when SubmittedFile status → Accepted
- Published folder is read-only (except system)

### To Trash

**From Any Source Folder:**
- User can delete (move to Trash) from any source folder
- System creates TrashItem with original location
- File removed from source folder

**Validation:**
- ⚠️ Warning if file is in pending submission
- ❌ Cannot trash if file is accepted (in Published)

### From Trash (Put Back)

**Restoration:**
- User selects file in Trash
- User chooses "Put Back"
- File returns to originalFolder (from TrashItem)
- TrashItem deleted

**Edge Cases:**
- If originalFolder deleted → File goes to Draft folder
- If originalFolder exists → Restore to exact location

---

## User Stories

### US1: Move File Between Source Folders (Priority: P1)

**As a** poet  
**I want to** move a draft poem to the Ready folder  
**So that** I can track which poems are ready for submission

**Why this priority:** Core workflow for organizing work progression

**Independent Test:** Create file in Draft, move to Ready, verify it appears in Ready and not in Draft

**Acceptance Scenarios:**

1. **Given** a file exists in Draft folder, **When** user selects "Move to Ready", **Then** file appears in Ready folder and is removed from Draft
2. **Given** a file is in Ready folder, **When** user moves it to Set Aside, **Then** file appears in Set Aside and is removed from Ready
3. **Given** a file has pending submissions, **When** user attempts to move it, **Then** system shows warning but allows move
4. **Given** a file is accepted (in Published), **When** user attempts to move source file, **Then** system allows move (Published copy is separate)

---

### US2: Create Publication (Priority: P1)

**As a** poet  
**I want to** create a publication record for "Poetry Monthly"  
**So that** I can track all my submissions to that magazine

**Why this priority:** Foundation for submission tracking system

**Independent Test:** Create publication, verify it appears in publications list with correct name and type

**Acceptance Scenarios:**

1. **Given** no publications exist, **When** user creates "Poetry Monthly" of type Magazine, **Then** publication appears in publications list
2. **Given** publication exists, **When** user edits name to "Poetry Monthly Review", **Then** name updates everywhere
3. **Given** publication has submissions, **When** user views publication detail, **Then** all submissions are listed
4. **Given** multiple publications, **When** user sorts by name, **Then** publications appear alphabetically

---

### US3: Create Submission (Priority: P1)

**As a** poet  
**I want to** create a submission to "Poetry Monthly" with 3 poems from Ready folder  
**So that** I can track what I've submitted and to where

**Why this priority:** Core submission workflow

**Independent Test:** Create submission with multiple files, verify all files are linked with correct version references

**Acceptance Scenarios:**

1. **Given** files exist in Ready folder, **When** user creates submission and adds 3 files, **Then** submission contains 3 SubmittedFile records
2. **Given** file has multiple versions, **When** adding to submission, **Then** system uses current (latest) version
3. **Given** submission exists, **When** user adds another file, **Then** new SubmittedFile is added to existing submission
4. **Given** submission created, **When** user views submission, **Then** all submitted files shown with their status (default: Pending)

---

### US4: Update Submission Status (Priority: P1)

**As a** poet  
**I want to** mark individual poems in a submission as accepted or rejected  
**So that** I can track which works were published

**Why this priority:** Critical for tracking publication success and managing published work

**Independent Test:** Mark file as accepted, verify it appears in Published folder; mark file as rejected, verify it stays in Ready only

**Acceptance Scenarios:**

1. **Given** SubmittedFile with status Pending, **When** user marks as Accepted, **Then** file is copied to Published folder
2. **Given** SubmittedFile with status Pending, **When** user marks as Rejected, **Then** file stays in original folder only
3. **Given** submission with 3 files, **When** user accepts 2 and rejects 1, **Then** only 2 files appear in Published
4. **Given** file marked as Accepted, **When** user changes to Rejected, **Then** file is removed from Published folder
5. **Given** multiple submissions for same file, **When** one accepts and one rejects, **Then** file appears in Published (any acceptance counts)

---

### US5: Move File to Trash (Priority: P1)

**As a** writer  
**I want to** delete unwanted files by moving them to Trash  
**So that** I can clean up my project without permanent loss

**Why this priority:** Essential file management capability

**Independent Test:** Move file to Trash, verify TrashItem created with correct original location

**Acceptance Scenarios:**

1. **Given** file in Draft folder, **When** user deletes file, **Then** file moves to Trash and TrashItem records originalFolder=Draft
2. **Given** file in Ready with pending submission, **When** user deletes file, **Then** warning shown but deletion allowed
3. **Given** file is accepted (copy in Published), **When** user tries to delete source, **Then** deletion allowed (Published copy separate)
4. **Given** file in Trash, **When** viewed, **Then** original folder location is visible

---

### US6: Put Back from Trash (Priority: P1)

**As a** writer  
**I want to** restore a deleted file to its original location  
**So that** I can recover accidentally deleted work

**Why this priority:** Safety net for deletion operations

**Independent Test:** Delete file from Ready, Put Back, verify it returns to Ready folder

**Acceptance Scenarios:**

1. **Given** file in Trash with originalFolder=Ready, **When** user selects Put Back, **Then** file returns to Ready and TrashItem deleted
2. **Given** file in Trash with originalFolder=Draft, **When** Put Back, **Then** file returns to Draft
3. **Given** file in Trash but originalFolder deleted, **When** Put Back, **Then** file goes to Draft folder with info message
4. **Given** multiple files in Trash, **When** Put Back selected ones, **Then** each returns to its original folder

---

### US7: View Published Works (Priority: P2)

**As a** poet  
**I want to** see all my accepted/published works in one place  
**So that** I can review my publication history

**Why this priority:** Valuable for portfolio review but not critical for core workflow

**Independent Test:** Accept files from different submissions, verify all appear in Published folder

**Acceptance Scenarios:**

1. **Given** 5 files marked as Accepted, **When** viewing Published folder, **Then** all 5 files appear
2. **Given** file accepted by multiple publications, **When** viewing Published, **Then** file appears once (not duplicated)
3. **Given** file status changed from Accepted to Rejected, **When** viewing Published, **Then** file no longer appears
4. **Given** Published folder, **When** user tries to delete file, **Then** operation prevented (must change submission status)

---

### US8: Track Submission History (Priority: P2)

**As a** poet  
**I want to** see where I've submitted each file and the outcomes  
**So that** I can track my submission strategy and success rate

**Why this priority:** Helpful for professional tracking but not required for basic workflow

**Independent Test:** View file details, see list of all submissions it's been in with status

**Acceptance Scenarios:**

1. **Given** file in 3 different submissions, **When** viewing file details, **Then** all 3 submissions shown with dates and status
2. **Given** submission history, **When** viewing, **Then** shows publication name, submission date, status, response notes
3. **Given** file never submitted, **When** viewing file details, **Then** shows "No submissions"
4. **Given** file with mixed results (1 accept, 2 rejects), **When** viewing, **Then** all statuses visible

---

## Functional Requirements

### File Movement

- **FR-001**: Files MUST be moveable between source folders (Draft, Ready, Set Aside) within same project
- **FR-002**: Files MUST NOT be moveable between different projects
- **FR-003**: Files MUST NOT be manually moveable to Published folder (system-managed only)
- **FR-004**: Files MUST be moveable to Trash from any source folder
- **FR-005**: System MUST show warning when moving file with pending submissions
- **FR-006**: System MUST prevent deletion of files if that would orphan accepted submissions (or auto-update status)

### Trash & Restoration

- **FR-007**: TrashItem MUST be created when file deleted, recording originalFolder
- **FR-008**: Put Back MUST restore file to originalFolder if it exists
- **FR-009**: Put Back MUST restore to Draft folder if originalFolder deleted
- **FR-010**: Trash MUST show original folder name for each file

### Publication Management

- **FR-011**: Users MUST be able to create Publication records with name and type
- **FR-012**: Publications MUST support types: Magazine, Competition, Commission, Other
- **FR-013**: Publications MUST be editable (name, type, notes)
- **FR-014**: Publications MUST be deletable if no submissions exist
- **FR-015**: Publications with submissions MUST show warning before deletion

### Submission Management

- **FR-016**: Users MUST be able to create Submissions linked to Publications
- **FR-017**: Submissions MUST support multiple files (many-to-many relationship)
- **FR-018**: Each SubmittedFile MUST reference specific file Version
- **FR-019**: System MUST default to current (latest) version when adding file to submission
- **FR-020**: Users MUST be able to specify different version if needed

### Status Tracking

- **FR-021**: SubmittedFile MUST support statuses: Pending, Accepted, Rejected, Withdrawn
- **FR-022**: Default status MUST be Pending
- **FR-023**: When status changes to Accepted, file MUST be copied to Published folder
- **FR-024**: When status changes from Accepted to other status, file MUST be removed from Published
- **FR-025**: If file accepted in any submission, file MUST appear in Published
- **FR-026**: Status changes MUST record statusDate

### Published Folder

- **FR-027**: Published folder MUST be read-only for users (no manual adds/removes)
- **FR-028**: Published folder MUST show all files with at least one Accepted status
- **FR-029**: Published folder MUST update automatically when submission statuses change
- **FR-030**: Files in Published MUST be copies (originals remain in source folders)

### Data Integrity

- **FR-031**: Deleting a file MUST delete all associated SubmittedFile records (or archive them)
- **FR-032**: Deleting a Submission MUST delete all SubmittedFile records
- **FR-033**: Deleting a Publication MUST delete all associated Submissions
- **FR-034**: All relationships MUST sync via CloudKit
- **FR-035**: Version references in SubmittedFile MUST remain valid even if new versions created

---

## Data Model Summary

### New Models

1. **Publication**: Tracks magazines, competitions, etc.
2. **Submission**: Groups files submitted together
3. **SubmittedFile**: Join table with status tracking
4. **TrashItem**: Tracks deleted files for restoration

### Updated Models

**Folder** (no changes needed - existing model works):
- Published folder behavior handled by UI logic
- Trash folder uses TrashItem model

**TextFile** (no changes needed):
- Relationships handled through SubmittedFile
- Versions already exist (Feature 003)

**Project** (minor addition):
- Add relationship: `publications: [Publication]`

---

## Success Criteria

- **SC-001**: Users can move files between source folders in under 3 taps
- **SC-002**: Users can create submission with 5 files in under 30 seconds
- **SC-003**: Marking file as Accepted appears in Published folder within 1 second
- **SC-004**: Put Back restores 95%+ of files to original location
- **SC-005**: System prevents 100% of invalid moves with helpful messages
- **SC-006**: All publication/submission data syncs across devices within 5 seconds
- **SC-007**: Users can track submission history for any file in under 5 seconds
- **SC-008**: Zero data loss during file moves or status changes

---

## Edge Cases

### File Movement
- Moving file that's in multiple pending submissions → Warning shown
- Moving file after it's been accepted → Allowed (Published copy separate)
- Moving file between projects → Blocked
- Moving to Published manually → Blocked

### Trash Operations
- Put Back when original folder deleted → Goes to Draft
- Put Back when file with same name exists in original → Name conflict resolution
- Deleting file with accepted status → Source deletable, Published copy remains
- Trash full of files → No automatic cleanup (user manages)

### Submission Management
- Same file in multiple submissions → Supported (common use case)
- File accepted by one pub, rejected by another → File in Published (any acceptance)
- Changing submission status to/from Accepted → Published folder updates automatically
- Deleting Publication with submissions → Cascade delete or prevent?
- Version tracking when file has 10+ versions → Display current + allow selection

### Published Folder
- File accepted → rejected → accepted again → Appears/disappears/reappears correctly
- Multiple submissions accept same file → File appears once in Published
- User tries to edit file in Published → Blocked (read-only) or opens source?
- Syncing Published folder state → Must sync SubmittedFile statuses

---

## Out of Scope (This Phase)

- ❌ Novel and Script file movement (Phase 2 - special attributes)
- ❌ Automatic submission tracking (email parsing, API integration)
- ❌ Submission deadline reminders/notifications
- ❌ Publication database/search (user creates all manually)
- ❌ Response letter storage (just notes field)
- ❌ Payment/royalty tracking
- ❌ Multiple author/collaborator support
- ❌ Submission fee tracking
- ❌ Cover letter generation
- ❌ Formatting rules per publication
- ❌ Simultaneous submission tracking (who allows/doesn't)

---

## Dependencies

### Existing Features
- **Feature 001**: Project Management - provides Project model
- **Feature 002**: Folder/file structure - provides Folder model and templates
- **Feature 003**: TextFile and Version models - required for version tracking
- **Feature 004**: Undo/redo system - needed for move operations

### External Services
- **CloudKit**: Sync all new models (Publication, Submission, SubmittedFile, TrashItem)
- **SwiftData**: Manage relationships and cascade deletes

---

## Technical Constraints

1. **Relationship Complexity**: Many-to-many between Submission and TextFile requires join model (SubmittedFile)
2. **Version References**: SubmittedFile must reference specific Version, not just TextFile
3. **Published Folder Logic**: No Folder changes needed - Published state managed by SubmittedFile status
4. **Cascade Deletes**: Must carefully handle when Publication/Submission/File deleted
5. **CloudKit Sync**: All 4 new models must sync, including version references

---

## Implementation Notes

### Published Folder Behavior

The Published folder is **not a real folder** - it's a smart view showing:
```
Files WHERE SubmittedFile.status == .accepted AND SubmittedFile.textFile == file
```

This avoids data duplication and keeps single source of truth (SubmittedFile status).

**Alternative (if you prefer):** Create actual copies in Published folder
- Pros: Simpler query, clearer to user
- Cons: Data duplication, sync complexity

**Recommendation:** Start with smart view, can add actual copies later if needed.

### Trash Restoration Strategy

```swift
func putBack(trashItem: TrashItem) {
    if trashItem.originalFolder.exists {
        move(trashItem.textFile, to: trashItem.originalFolder)
    } else {
        // Original folder deleted - use fallback
        let draftFolder = project.folders.first { $0.name == "Draft" }
        move(trashItem.textFile, to: draftFolder)
        // Show user: "Original folder deleted, restored to Draft"
    }
    delete(trashItem)
}
```

### Version Reference Integrity

When user creates new version of file that's in a submission:
- SubmittedFile still references old version (the one actually submitted)
- This is correct behavior - submitted version doesn't change
- User can manually update SubmittedFile to reference new version if they resubmit

---

## Localization Requirements

### File Movement
- "file.move" = "Move"
- "file.moveTo" = "Move to {folder}"
- "file.moveWarning" = "This file has pending submissions. Move anyway?"
- "file.moveToPublished" = "Cannot move to Published - system managed"
- "file.moved" = "Moved to {folder}"

### Trash
- "trash.putBack" = "Put Back"
- "trash.putBackSuccess" = "Restored to {folder}"
- "trash.putBackDraft" = "Original folder deleted, restored to Draft"
- "trash.originalFolder" = "Original location: {folder}"
- "trash.delete" = "Delete"
- "trash.deleteConfirm" = "Move to Trash?"

### Publications
- "publication.new" = "New Publication"
- "publication.name" = "Publication Name"
- "publication.type" = "Type"
- "publication.type.magazine" = "Magazine"
- "publication.type.competition" = "Competition"
- "publication.type.commission" = "Commission"
- "publication.type.other" = "Other"
- "publication.edit" = "Edit Publication"
- "publication.delete" = "Delete Publication"
- "publication.deleteWarning" = "This publication has {count} submissions. Delete anyway?"

### Submissions
- "submission.new" = "New Submission"
- "submission.to" = "Submission to {publication}"
- "submission.date" = "Submitted"
- "submission.addFiles" = "Add Files"
- "submission.files" = "{count} files"
- "submission.deadline" = "Deadline"
- "submission.notes" = "Notes"

### Status
- "status.pending" = "Pending"
- "status.accepted" = "Accepted"
- "status.rejected" = "Rejected"
- "status.withdrawn" = "Withdrawn"
- "status.change" = "Change Status"
- "status.changeDate" = "Status changed {date}"
- "status.responseNotes" = "Response Notes"

### Folders
- "folder.published" = "Published"
- "folder.published.empty" = "No accepted works yet"
- "folder.published.readOnly" = "To add files here, mark submissions as Accepted"

---

## UI Considerations

### File Context Menu
```
File in Ready folder:
├─ Open
├─ Move to...
│  ├─ Draft
│  ├─ Set Aside
│  └─ Trash
├─ Add to Submission...
├─ View Submission History
└─ Delete
```

### Submission Detail View
```
Submission to Poetry Monthly
Submitted: Nov 7, 2025

Files:
┌────────────────────────────────────────┐
│ my-poem.txt (v3)           [Pending ▼] │
│ another-poem.txt (v1)      [Accepted ▼]│
│ third-poem.txt (v2)        [Rejected ▼]│
└────────────────────────────────────────┘

[Add Files] [Edit Notes]
```

### Published Folder View
```
Published (5 items)
├─ my-poem.txt          ← Accepted by Poetry Monthly
├─ another-poem.txt     ← Accepted by Atlantic
├─ ...
```

### Trash View with Put Back
```
Trash (3 items)
┌────────────────────────────────────────┐
│ draft-poem.txt                         │
│ From: Ready                   [Put Back]│
├────────────────────────────────────────│
│ old-story.txt                          │
│ From: Set Aside               [Put Back]│
└────────────────────────────────────────┘
```

---

## Database Schema

```sql
-- Publications
CREATE TABLE Publication (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,  -- magazine, competition, commission, other
  projectId UUID REFERENCES Project(id),
  createdDate TIMESTAMP,
  notes TEXT
);

-- Submissions
CREATE TABLE Submission (
  id UUID PRIMARY KEY,
  publicationId UUID REFERENCES Publication(id) ON DELETE CASCADE,
  submissionDate TIMESTAMP,
  deadline TIMESTAMP,
  notes TEXT,
  projectId UUID REFERENCES Project(id)
);

-- SubmittedFiles (Join table with extra data)
CREATE TABLE SubmittedFile (
  id UUID PRIMARY KEY,
  submissionId UUID REFERENCES Submission(id) ON DELETE CASCADE,
  textFileId UUID REFERENCES TextFile(id),
  versionId UUID REFERENCES Version(id),
  status TEXT NOT NULL,  -- pending, accepted, rejected, withdrawn
  statusDate TIMESTAMP,
  responseNotes TEXT
);

-- TrashItems
CREATE TABLE TrashItem (
  id UUID PRIMARY KEY,
  textFileId UUID REFERENCES TextFile(id),
  originalFolderId UUID REFERENCES Folder(id),
  originalParentFolderId UUID REFERENCES Folder(id),
  deletedDate TIMESTAMP,
  projectId UUID REFERENCES Project(id)
);

-- Indexes for performance
CREATE INDEX idx_submittedfile_status ON SubmittedFile(status);
CREATE INDEX idx_submittedfile_textfile ON SubmittedFile(textFileId);
CREATE INDEX idx_publication_project ON Publication(projectId);
CREATE INDEX idx_submission_publication ON Submission(publicationId);
```

---

## Testing Strategy

### Unit Tests

1. **TrashItem Tests**:
   - Create TrashItem with originalFolder
   - Put Back to existing folder
   - Put Back when folder deleted (falls back to Draft)

2. **Publication Tests**:
   - Create, read, update, delete operations
   - Cascade delete with submissions

3. **Submission Tests**:
   - Add multiple files
   - Track versions correctly
   - Cascade delete SubmittedFiles

4. **SubmittedFile Tests**:
   - Status changes (Pending → Accepted → Rejected)
   - Published folder updates on status change
   - Multiple submissions for same file

5. **File Movement Tests**:
   - Move between source folders
   - Prevent move to Published
   - Warning when file has pending submissions

### Integration Tests

1. **Full Submission Workflow**:
   - Create publication
   - Create submission with 3 files
   - Accept 2, reject 1
   - Verify Published folder shows 2 files

2. **Trash Workflow**:
   - Delete file from Ready
   - Put Back to Ready
   - Delete file when folder deleted
   - Put Back defaults to Draft

3. **CloudKit Sync**:
   - Create publication on device 1
   - Verify appears on device 2
   - Update submission status on device 2
   - Verify Published folder updates on device 1

---

## Questions Resolved

✅ **Q1: Copy vs Move to publications** → Use Publication/Submission models, files stay in source  
✅ **Q2: Published folder purpose** → Auto-populated when SubmittedFile.status = Accepted  
✅ **Q3: Put Back edge cases** → Default to Draft if original folder deleted  
✅ **Q4: "All" folder** → Removed from design  

---

## Next Steps

1. ✅ Review this complete specification
2. Create data model implementations (Publication, Submission, SubmittedFile, TrashItem)
3. Implement file movement service
4. Implement submission tracking UI
5. Write comprehensive tests
6. Update folder templates (remove old publication folders)

---

**Status:** 📋 **Ready for Review** - Comprehensive spec complete with your clarifications