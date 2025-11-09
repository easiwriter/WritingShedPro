# Feature 008b - Requirements Updates

**Date:** 9 November 2025  
**Status:** Requirements refinement based on user feedback  
**Document:** Changes to original spec.md

---

## Summary of Changes

Based on user review, the following requirements are being added/modified to the 008b Publication System specification:

1. ✅ **Version locking** - Submitted file versions are immutable while part of a submission
2. ✅ **Multiple submissions** - A file can belong to multiple submissions (already supported by data model)
3. ✅ **Submission history by file** - View all submissions for a specific file
4. ✅ **Publication deadline dates** - Publications can have optional submission deadlines
5. ✅ **Submission acceptance dates** - Track when acceptance notification was received
6. ✅ **Reminders integration** - Create iOS Reminders for submission follow-ups AND for publication deadline dates (both before and on the actual deadline)

---

## Requirement 1: Version Locking

### Current Spec
The spec already preserves version references:
```swift
let submittedFile = SubmittedFile(
    submission: submission,
    textFile: textFile,
    version: currentVersion,  // References specific version
    status: .pending
)
```

### Enhancement Required
**Add explicit version locking** - Prevent the submitted version from being edited or deleted while referenced by any submission.

### Updated Data Model

No model changes needed, but add business logic:

```swift
// In Version model or service
extension Version {
    /// Check if this version is locked (referenced by any submission)
    var isLocked: Bool {
        // Query SubmittedFile for any references to this version
        return !referencingSubmissions.isEmpty
    }
    
    /// All submissions that reference this version
    var referencingSubmissions: [SubmittedFile] {
        // Computed or stored relationship
    }
}
```

### Functional Requirements

- **FR-NEW-001**: Versions referenced by SubmittedFile MUST be marked as locked
- **FR-NEW-002**: Locked versions MUST prevent editing
- **FR-NEW-003**: Locked versions MUST prevent deletion
- **FR-NEW-004**: UI MUST show lock icon on locked versions
- **FR-NEW-005**: Attempting to edit locked version MUST show error: "This version is locked because it's part of a submission to [Publication Name]"
- **FR-NEW-006**: Version list MUST indicate locked status with icon and explanation

### UI Changes

**Version list view:**
```
┌─────────────────────────────────────┐
│ ← Versions: sunset-poem.txt         │
├─────────────────────────────────────┤
│ 📝 v3 (Current) Nov 9, 2025         │
│    Latest edits                     │
│                                     │
│ 🔒 v2 Nov 7, 2025                   │ ← Locked
│    Submitted to Poetry Magazine     │
│    ⚠️ Cannot edit (locked)          │
│                                     │
│ 📝 v1 Nov 1, 2025                   │
│    Initial draft                    │
└─────────────────────────────────────┘
```

**When tapping locked version:**
```
┌─────────────────────────────────────┐
│ Version Locked                      │
├─────────────────────────────────────┤
│ This version is locked because it   │
│ is part of an active submission:    │
│                                     │
│ • Poetry Magazine (Pending)         │
│   Submitted Nov 7, 2025             │
│                                     │
│ You cannot edit or delete this      │
│ version while it's part of a        │
│ submission.                         │
│                                     │
│ [View Submission]  [OK]             │
└─────────────────────────────────────┘
```

### User Stories

**US-NEW-001: Prevent Editing Locked Version**

**As a** writer  
**I want to** be prevented from editing a submitted version  
**So that** submission records remain accurate

**Acceptance Criteria:**
1. Given version v2 submitted to publication, When user tries to edit v2, Then error message appears
2. Given locked version, When viewing version list, Then lock icon appears next to v2
3. Given error message, When user taps "View Submission", Then opens submission detail showing which publication locked it

---

## Requirement 2: Multiple Submissions

### Current Spec Status
✅ **Already supported** - The data model inherently supports this:

```swift
// A TextFile can have multiple SubmittedFile records
TextFile ←→ [SubmittedFile] ←→ Submission
```

Example:
```
"sunset-poem.txt" can be submitted to:
- Poetry Magazine (v2, accepted)
- National Poetry Competition (v2, pending)  
- The Writer's Review (v1, rejected)
```

### Clarification Required

**Update Documentation** to explicitly state this capability:

**FR-002-CLARIFY**: A single TextFile MAY be submitted to multiple Publications
**FR-002-CLARIFY-A**: Each submission MAY reference different versions of the same file
**FR-002-CLARIFY-B**: UI MUST clearly show all submissions when viewing file's submission history

### UI Enhancement

Show multiple submissions clearly in file detail:

```
┌─────────────────────────────────────┐
│ ← sunset-poem.txt                   │
├─────────────────────────────────────┤
│ Submissions (3):                    │
│                                     │
│ ✓ Poetry Magazine                   │
│   v2 • Accepted Nov 15, 2025        │
│                                     │
│ ⏳ National Competition             │
│   v2 • Pending (submitted Nov 7)    │
│                                     │
│ ✗ The Writer's Review               │
│   v1 • Rejected Oct 20, 2025        │
│                                     │
│ [View Full History]                 │
└─────────────────────────────────────┘
```

---

## Requirement 3: Submission History by File

### Current Spec Gap
The original spec shows submission history by **publication** but not by **file**.

### New Requirement
User should be able to select a file and see a table of all its submissions.

### Data Model Changes
None needed - relationships already support this query:

```swift
// Query all submissions for a file
let submissions = file.submittedFiles  // All SubmittedFile records
    .map { $0.submission }             // Get parent Submission
    .sorted { $0.submittedDate > $1.submittedDate }  // Newest first
```

### New UI: File Submission History View

```
┌─────────────────────────────────────┐
│ ← Submission History                │
│   sunset-poem.txt                   │
├─────────────────────────────────────┤
│                                     │
│ 📰 Poetry Magazine                  │
│ Status: Accepted                    │
│ Version: v2                         │
│ Submitted: Nov 7, 2025              │
│ Accepted: Nov 15, 2025              │
│ Response time: 8 days               │
│ ───────────────────────────────────│
│                                     │
│ 🏆 National Poetry Competition      │
│ Status: Pending                     │
│ Version: v2                         │
│ Submitted: Nov 7, 2025              │
│ Waiting: 2 days                     │
│ ───────────────────────────────────│
│                                     │
│ 📰 The Writer's Review              │
│ Status: Rejected                    │
│ Version: v1                         │
│ Submitted: Oct 1, 2025              │
│ Rejected: Oct 20, 2025              │
│ Response time: 19 days              │
│                                     │
└─────────────────────────────────────┘
```

### Access Points

**Option 1: File Context Menu**
```
Long-press on file → Context Menu:
- Open
- Rename
- Move
- Delete
- View Submission History  ← NEW
```

**Option 2: File Detail View**
```
File detail screen:
- [Info] tab
- [Versions] tab  
- [Submissions] tab  ← NEW
```

**Option 3: Dedicated Button**
```
File list row:
📄 sunset-poem.txt          [📊]  ← Tap for submission history
```

### Functional Requirements

- **FR-NEW-007**: Users MUST be able to view submission history for any file
- **FR-NEW-008**: Submission history MUST show publication, version, status, and dates
- **FR-NEW-009**: Submission history MUST sort by submitted date (newest first)
- **FR-NEW-010**: Submission history MUST calculate and display response times
- **FR-NEW-011**: Empty submission history MUST show "Not yet submitted" message
- **FR-NEW-012**: Tapping submission in history MUST open submission detail view

### User Stories

**US-NEW-002: View File Submission History**

**As a** poet  
**I want to** see everywhere I've submitted a specific poem  
**So that** I can track which publications have seen this work

**Acceptance Criteria:**
1. Given file with 3 submissions, When user opens submission history, Then all 3 submissions shown with status
2. Given submission history, When viewing, Then shows version number submitted for each
3. Given accepted submission, When viewing history, Then shows acceptance date and response time
4. Given file never submitted, When viewing history, Then shows "Not yet submitted" message

---

## Requirement 4: Publication Deadline Dates

### Current Spec Gap
Publication model has no deadline field.

### Updated Data Model

```swift
@Model
class Publication {
    var id: UUID
    var name: String
    var type: PublicationType
    var url: String?
    var notes: String?
    
    // NEW: Optional deadline for submissions
    var deadline: Date?              // NEW
    var hasDeadline: Bool {          // NEW - Computed
        deadline != nil
    }
    
    var project: Project
    var submissions: [Submission]
    
    var createdDate: Date
    var modifiedDate: Date
}
```

### UI Changes

**Publication Form:**
```
┌─────────────────────────────────────┐
│ ← New Publication                   │
├─────────────────────────────────────┤
│ Name                                │
│ [Poetry Magazine              ]     │
│                                     │
│ Type                                │
│ ⦿ Magazine  ○ Competition           │
│                                     │
│ Website (optional)                  │
│ [https://poetrymagazine.com   ]     │
│                                     │
│ Submission Deadline (optional)      │ ← NEW
│ [Nov 30, 2025                 ] 📅  │
│                                     │
│ Notes (optional)                    │
│ [                              ]    │
│                                     │
│ [Cancel]               [Save]       │
└─────────────────────────────────────┘
```

**Publications List (with deadlines):**
```
┌─────────────────────────────────────┐
│ ← Publications                  [+] │
├─────────────────────────────────────┤
│                                     │
│ 📰 Poetry Magazine                  │
│    Deadline: Nov 30, 2025 (21 days)│ ← NEW
│    12 submissions • 8 accepted      │
│                                     │
│ 🏆 National Poetry Competition      │
│    ⚠️ Deadline: Nov 15, 2025 (6 days)│ ← Warning for approaching
│    3 submissions • 1 accepted       │
│                                     │
│ 📰 The Writer's Review              │
│    No deadline set                  │ ← When null
│    5 submissions • 2 accepted       │
│                                     │
└─────────────────────────────────────┘
```

### Deadline Warnings

**Approaching deadline (< 7 days):**
```
┌─────────────────────────────────────┐
│ ⚠️ Deadline Approaching             │
├─────────────────────────────────────┤
│ National Poetry Competition has a   │
│ submission deadline in 6 days:      │
│                                     │
│ November 15, 2025                   │
│                                     │
│ [View Publication]  [Remind Me]     │
└─────────────────────────────────────┘
```

**Past deadline:**
```
Publication shown in red with:
🔴 Poetry Magazine
   Deadline passed: Nov 30, 2025
```

### Functional Requirements

- **FR-NEW-013**: Publications MAY have an optional deadline date
- **FR-NEW-014**: Deadline MUST be optional (not all publications have deadlines)
- **FR-NEW-015**: UI MUST show days remaining until deadline
- **FR-NEW-016**: Publications with deadline < 7 days MUST show warning indicator
- **FR-NEW-017**: Publications with past deadline MUST show in red/warning color
- **FR-NEW-018**: Publications list MUST sort by approaching deadline (optional filter)
- **FR-NEW-019**: Creating submission to past-deadline publication MUST show warning (but allow)

### User Stories

**US-NEW-003: Track Publication Deadlines**

**As a** writer  
**I want to** set a submission deadline for a competition  
**So that** I don't miss the closing date

**Acceptance Criteria:**
1. Given publication form, When entering deadline date, Then deadline saved with publication
2. Given publication with deadline in 5 days, When viewing list, Then warning indicator appears
3. Given publication with past deadline, When viewing list, Then shown in red
4. Given publication without deadline, When viewing, Then "No deadline set" message shown

---

## Requirement 5: Submission Acceptance Date

### Current Spec Status
SubmittedFile model has `statusDate` but it's not specifically labeled as acceptance date.

### Clarification & Enhancement

The existing `statusDate` serves this purpose, but we should:
1. Rename or clarify its meaning
2. Add acceptance-specific behavior

### Updated Data Model

```swift
@Model
class SubmittedFile {
    var id: UUID
    var submission: Submission
    var textFile: TextFile
    var version: Version
    
    var status: SubmissionStatus
    
    // Existing field - clarify purpose
    var statusDate: Date?            // When status last changed
    
    // NEW: Computed properties for clarity
    var acceptanceDate: Date? {      // NEW - When accepted
        status == .accepted ? statusDate : nil
    }
    
    var rejectionDate: Date? {       // NEW - When rejected
        status == .rejected ? statusDate : nil
    }
    
    var daysSinceSubmission: Int {   // NEW - Response time
        Calendar.current.dateComponents(
            [.day], 
            from: submission.submittedDate, 
            to: statusDate ?? Date()
        ).day ?? 0
    }
    
    var statusNotes: String?
    var project: Project
    
    var createdDate: Date
    var modifiedDate: Date
}
```

### UI Changes

**Submission Detail (Enhanced):**
```
┌─────────────────────────────────────┐
│ ← National Poetry Competition       │
├─────────────────────────────────────┤
│ Submitted: Nov 7, 2025              │
│                                     │
│ sunset-poem.txt (v2)                │
│ Status: ✓ Accepted                  │
│ Acceptance Date: Nov 15, 2025       │ ← NEW (explicit label)
│ Response Time: 8 days               │ ← NEW (computed)
│                                     │
│ morning-haiku.txt (v1)              │
│ Status: ✗ Rejected                  │
│ Rejection Date: Nov 12, 2025        │ ← NEW
│ Response Time: 5 days               │ ← NEW
│                                     │
│ love-sonnet.txt (v1)                │
│ Status: ⏳ Pending                  │
│ Waiting: 2 days                     │ ← NEW (days since submission)
│                                     │
└─────────────────────────────────────┘
```

**Status Change Dialog:**
```
┌─────────────────────────────────────┐
│ Update Submission Status            │
├─────────────────────────────────────┤
│ sunset-poem.txt                     │
│                                     │
│ Status:                             │
│ ○ Pending                           │
│ ⦿ Accepted                          │ ← Selected
│ ○ Rejected                          │
│                                     │
│ Acceptance Date:                    │ ← NEW (when accepted selected)
│ [Nov 15, 2025               ] 📅    │
│ (defaults to today)                 │
│                                     │
│ Notes (optional):                   │
│ [They loved it!              ]      │
│                                     │
│ [Cancel]               [Save]       │
└─────────────────────────────────────┘
```

### Functional Requirements

- **FR-NEW-020**: Status change to "accepted" MUST record acceptance date (defaults to today)
- **FR-NEW-021**: Status change to "rejected" MUST record rejection date (defaults to today)
- **FR-NEW-022**: Acceptance date MUST be editable (in case user enters late)
- **FR-NEW-023**: UI MUST calculate and display response time (submission to acceptance)
- **FR-NEW-024**: Acceptance date MUST be included in Published folder view
- **FR-NEW-025**: Submission history MUST prominently show acceptance dates

### User Stories

**US-NEW-004: Record Acceptance Date**

**As a** writer  
**I want to** record when a publication accepted my work  
**So that** I can track response times and celebrate

**Acceptance Criteria:**
1. Given pending submission, When marking as accepted, Then prompted for acceptance date (defaults to today)
2. Given accepted submission, When viewing detail, Then acceptance date shown clearly
3. Given accepted submission, When viewing, Then response time calculated and displayed
4. Given acceptance date, When viewing Published folder, Then acceptance date shown with file

---

## Requirement 6: Reminders Integration

### New Feature
Create iOS Reminders for following up on acceptance dates.

### Use Cases

1. **Follow-up reminder** - "Check if Poetry Magazine has responded" (e.g., 30 days after submission)
2. **Deadline reminder (before)** - "Submit to National Poetry Competition" (e.g., 7 days before deadline)
3. **Deadline reminder (on date)** - "Deadline today: National Poetry Competition" (on the actual deadline date)
4. **Response reminder** - "Expected response from The Writer's Review" (e.g., based on average response time)

### Implementation Approach

Use EventKit framework for Reminders integration:

```swift
import EventKit

class ReminderService {
    let eventStore = EKEventStore()
    
    /// Request permission to access Reminders
    func requestAccess() async throws -> Bool {
        return try await eventStore.requestAccess(to: .reminder)
    }
    
    /// Create reminder for submission follow-up
    func createSubmissionReminder(
        for submission: Submission,
        daysAfterSubmission: Int,
        notes: String? = nil
    ) async throws -> EKReminder {
        guard try await requestAccess() else {
            throw ReminderError.permissionDenied
        }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = "Follow up: \(submission.publication.name)"
        reminder.notes = notes ?? "Check on submission status"
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        let dueDate = Calendar.current.date(
            byAdding: .day,
            value: daysAfterSubmission,
            to: submission.submittedDate
        )
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate ?? Date()
        )
        
        try eventStore.save(reminder, commit: true)
        return reminder
    }
    
    /// Create reminder for publication deadline
    func createDeadlineReminder(
        for publication: Publication,
        daysBefore: Int
    ) async throws -> EKReminder {
        guard let deadline = publication.deadline else {
            throw ReminderError.noDeadline
        }
        
        guard try await requestAccess() else {
            throw ReminderError.permissionDenied
        }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = "Deadline: \(publication.name)"
        reminder.notes = "Submission deadline approaching"
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -daysBefore,
            to: deadline
        )
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate ?? Date()
        )
        
        try eventStore.save(reminder, commit: true)
        return reminder
    }
}

enum ReminderError: Error {
    case permissionDenied
    case noDeadline
}
```

### UI Integration

**Option 1: After Creating Submission**
```
┌─────────────────────────────────────┐
│ ✓ Submitted                         │
├─────────────────────────────────────┤
│ 3 poems submitted to                │
│ National Poetry Competition         │
│                                     │
│ Status: Pending                     │
│                                     │
│ ⏰ Set Reminder                     │ ← NEW
│ [Remind me to check status in:]     │
│ ○ 2 weeks                           │
│ ⦿ 30 days                           │ ← Selected
│ ○ 60 days                           │
│ ○ Custom                            │
│                                     │
│ [Skip]  [Create Reminder]           │
└─────────────────────────────────────┘
```

**Option 2: Submission Detail View**
```
┌─────────────────────────────────────┐
│ ← National Poetry Competition       │
├─────────────────────────────────────┤
│ Submitted: Nov 7, 2025              │
│ Status: Pending                     │
│                                     │
│ [⏰ Set Reminder]                   │ ← NEW button
│                                     │
│ Files (3):                          │
│ ⏳ sunset-poem.txt (v2) - Pending   │
│ ⏳ morning-haiku.txt (v1) - Pending │
│ ⏳ love-sonnet.txt (v1) - Pending   │
└─────────────────────────────────────┘
```

**Option 3: Publication Detail View**
```
┌─────────────────────────────────────┐
│ ← Poetry Magazine                   │
├─────────────────────────────────────┤
│ Type: Magazine                      │
│ Deadline: Nov 30, 2025              │
│                                     │
│ [⏰ Remind Me]                      │ ← NEW - Creates deadline reminder
│                                     │
│ Submissions (12):                   │
│ ...                                 │
└─────────────────────────────────────┘
```

### Reminder Creation Dialog (Submission Follow-up)

```
┌─────────────────────────────────────┐
│ Create Reminder                     │
├─────────────────────────────────────┤
│ National Poetry Competition         │
│ Submitted: Nov 7, 2025              │
│                                     │
│ Remind me:                          │
│ ○ In 2 weeks (Nov 21)               │
│ ⦿ In 30 days (Dec 7)                │
│ ○ In 60 days (Jan 6)                │
│ ○ Custom date...                    │
│                                     │
│ Reminder text (optional):           │
│ [Check on submission status   ]     │
│                                     │
│ This will create a reminder in      │
│ your iOS Reminders app.             │
│                                     │
│ [Cancel]     [Create Reminder]      │
└─────────────────────────────────────┘
```

### Reminder Creation Dialog (Deadline)

```
┌─────────────────────────────────────┐
│ Create Deadline Reminder            │
├─────────────────────────────────────┤
│ National Poetry Competition         │
│ Deadline: Nov 30, 2025              │
│                                     │
│ Remind me:                          │
│ ○ 1 week before (Nov 23)            │
│ ⦿ 3 days before (Nov 27)            │
│ ○ On deadline date (Nov 30)         │ ← NEW
│ ○ Custom date...                    │
│                                     │
│ Reminder text (optional):           │
│ [Submission deadline for National...│
│                                     │
│ This will create a reminder in      │
│ your iOS Reminders app.             │
│                                     │
│ [Cancel]     [Create Reminder]      │
└─────────────────────────────────────┘
```

### Permission Handling

```
┌─────────────────────────────────────┐
│ Reminders Access Required           │
├─────────────────────────────────────┤
│ Writing Shed Pro needs access to    │
│ your Reminders to create follow-up  │
│ reminders for submissions.          │
│                                     │
│ [Not Now]  [Allow Access]           │
└─────────────────────────────────────┘
```

### Functional Requirements

- **FR-NEW-026**: Users MAY create iOS Reminders for submission follow-ups
- **FR-NEW-027**: Users MAY create iOS Reminders for publication deadlines (before or on deadline date)
- **FR-NEW-028**: Reminder creation MUST request EventKit permission on first use
- **FR-NEW-029**: Default reminder times for follow-ups MUST be: 2 weeks, 30 days, 60 days, or custom
- **FR-NEW-029a**: Default reminder times for deadlines MUST be: 1 week before, 3 days before, on deadline date, or custom
- **FR-NEW-030**: Reminder text MUST include publication name and relevant context (submission date or deadline)
- **FR-NEW-031**: Users MUST be able to customize reminder text
- **FR-NEW-032**: Reminder MUST appear in iOS Reminders app (not just Writing Shed Pro)
- **FR-NEW-033**: Creating reminder MUST show success confirmation
- **FR-NEW-034**: Permission denial MUST gracefully fallback (show error, allow skip)

### User Stories

**US-NEW-005: Create Submission Reminder**

**As a** writer  
**I want to** set a reminder to check on my submission  
**So that** I remember to follow up if I don't hear back

**Acceptance Criteria:**
1. Given completed submission, When tapping "Set Reminder", Then reminder dialog appears
2. Given reminder dialog, When selecting "30 days" and creating, Then reminder appears in iOS Reminders app
3. Given reminder created, When due date arrives, Then iOS notification appears
4. Given permission denied, When attempting to create reminder, Then error message shown with option to open Settings

**US-NEW-006: Create Deadline Reminder**

**As a** writer  
**I want to** set a reminder for a publication deadline  
**So that** I don't miss the submission window

**Acceptance Criteria:**
1. Given publication with deadline Nov 30, When tapping "Remind Me", Then deadline reminder dialog appears
2. Given reminder dialog, When selecting "1 week before", Then reminder set for Nov 23
3. Given reminder dialog, When selecting "On deadline date", Then reminder set for Nov 30
4. Given deadline reminder, When due date arrives, Then iOS notification appears
5. Given "on deadline date" reminder, When Nov 30 arrives, Then notification shows "Deadline today: [Publication Name]"

---

## Updated Data Model Summary

### Publication (Modified)

```swift
@Model
class Publication {
    var id: UUID
    var name: String
    var type: PublicationType
    var url: String?
    var notes: String?
    var deadline: Date?              // NEW - Optional submission deadline
    var project: Project
    var submissions: [Submission]
    var createdDate: Date
    var modifiedDate: Date
    
    // NEW - Computed properties
    var hasDeadline: Bool { deadline != nil }
    var daysUntilDeadline: Int? {
        guard let deadline = deadline else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: deadline).day
    }
    var isDeadlinePassed: Bool {
        guard let deadline = deadline else { return false }
        return deadline < Date()
    }
}
```

### SubmittedFile (Enhanced)

```swift
@Model
class SubmittedFile {
    var id: UUID
    var submission: Submission
    var textFile: TextFile
    var version: Version
    var status: SubmissionStatus
    var statusDate: Date?            // When status changed (acceptance/rejection date)
    var statusNotes: String?
    var project: Project
    var createdDate: Date
    var modifiedDate: Date
    
    // NEW - Computed properties
    var acceptanceDate: Date? {
        status == .accepted ? statusDate : nil
    }
    var rejectionDate: Date? {
        status == .rejected ? statusDate : nil
    }
    var daysSinceSubmission: Int {
        Calendar.current.dateComponents(
            [.day],
            from: submission.submittedDate,
            to: statusDate ?? Date()
        ).day ?? 0
    }
}
```

### Version (Enhanced)

```swift
@Model
class Version {
    // ... existing properties ...
    
    // NEW - Computed property for locking
    var isLocked: Bool {
        // Returns true if any SubmittedFile references this version
        !referencingSubmissions.isEmpty
    }
    
    // NEW - Relationship (may need @Relationship annotation)
    var referencingSubmissions: [SubmittedFile] {
        // Query or relationship to SubmittedFile records
    }
}
```

### New Service: ReminderService

```swift
class ReminderService {
    func createSubmissionReminder(
        for submission: Submission,
        daysAfterSubmission: Int,
        notes: String?
    ) async throws -> EKReminder
    
    func createDeadlineReminder(
        for publication: Publication,
        daysBefore: Int
    ) async throws -> EKReminder
    
    func requestAccess() async throws -> Bool
}
```

---

## Updated Functional Requirements Summary

### Version Locking (Requirement 1)
- FR-NEW-001 through FR-NEW-006

### Multiple Submissions (Requirement 2)
- FR-002-CLARIFY through FR-002-CLARIFY-B (clarifications only)

### Submission History by File (Requirement 3)
- FR-NEW-007 through FR-NEW-012

### Publication Deadlines (Requirement 4)
- FR-NEW-013 through FR-NEW-019

### Acceptance Dates (Requirement 5)
- FR-NEW-020 through FR-NEW-025

### Reminders Integration (Requirement 6)
- FR-NEW-026 through FR-NEW-034

---

## Implementation Priority

### Phase 1 (Core Requirements)
1. ✅ Multiple submissions support (already exists, document only)
2. 🔨 Version locking (critical for data integrity)
3. 🔨 Acceptance date tracking (already mostly implemented, clarify UI)
4. 🔨 Submission history by file (new view)

### Phase 2 (Enhanced Features)
5. 🔨 Publication deadline dates (new field + UI)
6. 🔨 Reminders integration (requires EventKit)

---

## Testing Considerations

### New Test Cases

**Version Locking:**
- Test: Create submission with v2, attempt to edit v2 → Should fail
- Test: Create submission with v2, attempt to delete v2 → Should fail
- Test: Mark submission as rejected, attempt to edit v2 → Should succeed (unlocked)
- Test: Multiple submissions reference same version → Lock should persist until all resolved

**Submission History by File:**
- Test: File with 3 submissions → All 3 shown in history
- Test: File with no submissions → "Not yet submitted" message
- Test: Response time calculation → Correct for accepted/rejected

**Deadlines:**
- Test: Publication with deadline in 5 days → Warning shown
- Test: Publication with past deadline → Red indicator shown
- Test: Creating submission to past-deadline publication → Warning shown but allowed

**Acceptance Dates:**
- Test: Mark as accepted → Acceptance date defaults to today
- Test: Edit acceptance date → Date saved correctly
- Test: Response time calculation → Correct day count

**Reminders:**
- Test: Create reminder without permission → Permission dialog shown
- Test: Create reminder with permission → Appears in iOS Reminders
- Test: Create custom reminder date → Correct date set
- Test: Permission denied → Graceful error handling

---

## Migration Impact

### Database Migration
- Add `deadline: Date?` to Publication model
- No other schema changes needed (existing fields sufficient)

### UI Migration
- Add deadline picker to Publication form
- Add "Set Reminder" buttons to various views
- Add "Submission History" menu item to file context menu
- Add lock icons to version lists
- Enhance submission detail view with acceptance dates

### Code Migration
- Implement ReminderService
- Add version locking validation
- Create FileSubmissionHistoryView
- Add computed properties to models

---

## Open Questions

1. **Version Locking Scope**
   - Should locked versions prevent deletion from database, or just hide edit UI?
   - What happens if user force-deletes a TextFile that has locked versions?
   - Answer: Soft lock UI only, but preserve data integrity with cascade rules

2. **Reminder Frequency**
   - Should app suggest reminder based on publication's average response time?
   - Should there be recurring reminders (e.g., every 2 weeks until resolved)?
   - Answer: Keep simple - single reminder with preset options

3. **Multiple Reminders**
   - Can user create multiple reminders for same submission?
   - Should app track which reminders have been created?
   - Answer: Allow multiple, but don't track (user manages in Reminders app)

4. **Deadline Behavior**
   - Should past-deadline publications be hidden/archived automatically?
   - Should app prevent submissions to past-deadline publications?
   - Answer: Show warning but allow (some publications have rolling deadlines)

---

## Summary

These 6 requirements enhance Feature 008b with:
1. ✅ **Data integrity** (version locking)
2. ✅ **Flexible workflow** (multiple submissions per file)
3. ✅ **Better analytics** (file submission history)
4. ✅ **Deadline tracking** (publication deadlines)
5. ✅ **Detailed records** (acceptance dates with response times)
6. ✅ **iOS integration** (Reminders for follow-ups)

All requirements can be implemented without breaking changes to existing data model. Most are additive (new fields, new views, new services) rather than modifications to existing functionality.

**Next Steps:**
1. Review and approve these requirements
2. Update main spec.md with these changes
3. Create implementation tasks
4. Prioritize Phase 1 vs Phase 2 features
5. Begin development after Feature 008a merge

---

**Status:** ✅ Requirements documented and ready for approval  
**Estimated Complexity:** Medium (2-3 weeks development + testing)  
**Dependencies:** Feature 008a completion, EventKit framework
