# Feature 008b Implementation Plan

**Feature**: Publication Management System  
**Created**: 9 November 2025  
**Status**: Planning Complete - Ready for Implementation  
**Estimated Duration**: 2-3 weeks  
**Dependencies**: Feature 008a (File Movement) - ✅ Complete

---

## Overview

Implementation plan for Feature 008b based on the original specification and the 6 requirements updates:

1. ✅ **Version locking** - Submitted versions become immutable
2. ✅ **Multiple submissions** - A file can be submitted to multiple publications
3. ✅ **Submission history by file** - View all submissions for a specific file
4. ✅ **Publication deadline dates** - Track submission deadlines
5. ✅ **Submission acceptance dates** - Record when acceptance received
6. ✅ **Reminders integration** - iOS Reminders for follow-ups and deadlines

---

## Implementation Phases

### Phase 1: Data Model & Core Infrastructure
**Duration**: 2 days  
**Status**: Not Started

#### Tasks
- [ ] Create `Publication` model with SwiftData
  - Properties: id, name, type, url, notes, deadline, project
  - Computed: hasDeadline, daysUntilDeadline, isDeadlinePassed
- [ ] Create `Submission` model
  - Properties: id, publication, project, submittedDate, notes
  - Relationship: submittedFiles array
- [ ] Create `SubmittedFile` model (join table)
  - Properties: id, submission, textFile, version, status, statusDate, statusNotes, project
  - Computed: acceptanceDate, rejectionDate, daysSinceSubmission
- [ ] Create `SubmissionStatus` enum (pending/accepted/rejected)
- [ ] Create `PublicationType` enum (magazine/competition)
- [ ] Add `deadline: Date?` to Publication model
- [ ] Add version locking support to `Version` model
  - Computed property: `isLocked` (checks if any SubmittedFile references this version)
  - Computed property: `referencingSubmissions` (array of SubmittedFile)
- [ ] Add EventKit framework to project
- [ ] Update model container to include new models

#### Deliverables
- 3 new SwiftData models
- 2 new enums
- Version model enhancements
- EventKit framework added

---

### Phase 2: Publications Management UI
**Duration**: 2-3 days  
**Status**: Not Started

#### Tasks
- [ ] Create `PublicationsListView`
  - Display all publications with name, type, deadline
  - Show deadline countdown (X days remaining)
  - Warning indicator for deadlines < 7 days
  - Red indicator for past deadlines
  - Submission count per publication
  - Add [+] button to create new publication
- [ ] Create `PublicationFormView`
  - Name field (required)
  - Type picker (Magazine/Competition)
  - URL field (optional)
  - Deadline date picker (optional)
  - Notes field (optional)
  - Save/Cancel buttons
  - Validation (name required)
- [ ] Create `PublicationDetailView`
  - Show publication info (name, type, URL, deadline)
  - List all submissions to this publication
  - Show submission dates and statuses
  - Add [+] button to create new submission
  - Add "Remind Me" button for deadline reminders (Phase 9)
  - Edit button to modify publication
- [ ] Add Publications section to main navigation/sidebar
- [ ] Implement deadline indicators
  - Green: > 7 days away
  - Orange/Yellow: < 7 days away
  - Red: Past deadline

#### Deliverables
- 3 new views for publication management
- Navigation integration
- Deadline visual indicators

---

### Phase 3: Submission Creation & Tracking
**Duration**: 3-4 days  
**Status**: Not Started

#### Tasks
- [ ] Create `SubmissionFormView`
  - Select publication (picker or search)
  - Select files from Ready folder (multi-select)
  - Show version picker per file (select which version to submit)
  - Submission date picker (defaults to today)
  - Notes field (optional)
  - File list with version numbers
  - Save/Cancel buttons
- [ ] Implement multi-file selection
  - Checkbox selection UI
  - Select All / Deselect All
  - Show selected count
- [ ] Create `Submission` creation logic
  - Save Submission record
  - Create SubmittedFile for each selected file
  - Link to selected version
  - Set initial status to .pending
- [ ] Create submission success view
  - Confirmation message
  - Show submitted files
  - Option to set reminder (Phase 9)
  - Close button
- [ ] Add "Submit Files" action to Ready folder
- [ ] Handle validation
  - Must select at least one file
  - Must select publication
  - Show appropriate errors

#### Deliverables
- Submission creation workflow
- Multi-file selection
- Submission records persisted to database

---

### Phase 4: Version Locking System
**Duration**: 2 days  
**Status**: Not Started

#### Tasks
- [ ] Implement `Version.isLocked` computed property
  - Query all SubmittedFile records
  - Return true if any reference this version
  - Cache result for performance
- [ ] Implement `Version.referencingSubmissions`
  - Query SubmittedFile where version == self
  - Return array of SubmittedFile records
- [ ] Update version list UI
  - Add 🔒 lock icon to locked versions
  - Show "Submitted to [Publication]" subtitle
  - Add warning text "Cannot edit (locked)"
- [ ] Prevent editing locked versions
  - Check `isLocked` before allowing edit
  - Show error dialog if locked
  - Include publication name in error
  - Add "View Submission" button in error dialog
- [ ] Prevent deleting locked versions
  - Check `isLocked` before allowing delete
  - Show error dialog if locked
  - Explain why version is locked
- [ ] Add version unlock logic
  - When submission status changes to rejected/accepted
  - Check if other submissions still reference version
  - Only unlock if no active references

#### Deliverables
- Version locking enforcement
- Lock status indicators in UI
- Error dialogs with navigation to submission

---

### Phase 5: Submission Status Management
**Duration**: 2 days  
**Status**: Not Started

#### Tasks
- [ ] Create status update dialog
  - Radio buttons: Pending / Accepted / Rejected
  - Date picker for acceptance/rejection date (defaults to today)
  - Allow editing past dates
  - Notes field (optional)
  - Save/Cancel buttons
- [ ] Implement status change logic
  - Update `SubmittedFile.status`
  - Set `SubmittedFile.statusDate` to selected date
  - Save notes if provided
  - Calculate response time (submission date to status date)
- [ ] Add response time calculation
  - `daysSinceSubmission` computed property
  - Show in submission detail views
  - Format nicely (e.g., "8 days", "3 weeks")
- [ ] Update submission detail views
  - Show current status with icon
  - Show acceptance/rejection date when applicable
  - Show response time
  - Add "Update Status" button
- [ ] Handle status transitions
  - Pending → Accepted (record acceptance date)
  - Pending → Rejected (record rejection date)
  - Accepted → Rejected (update date, unlock version if last reference)
  - Rejected → Accepted (update date, lock version again)

#### Deliverables
- Status update UI
- Response time tracking
- Status change logic

---

### Phase 6: File Submission History View
**Duration**: 2-3 days  
**Status**: Not Started

#### Tasks
- [ ] Create `FileSubmissionHistoryView`
  - Show file name in header
  - List all submissions for this file
  - Display per submission:
    - Publication name and icon
    - Status (Pending/Accepted/Rejected) with icon
    - Version number submitted
    - Submission date
    - Acceptance/rejection date (if applicable)
    - Response time
  - Sort by submission date (newest first)
  - Tap submission to view detail
- [ ] Handle empty state
  - Show "Not yet submitted" message
  - Show illustration/icon
  - Add "Submit This File" button
- [ ] Add access points
  - File context menu: "View Submission History"
  - File detail view: Add "Submissions" tab
  - Optional: File list row button [📊]
- [ ] Query submissions for file
  - Get all SubmittedFile records for TextFile
  - Map to parent Submission records
  - Include publication info
  - Sort by date
- [ ] Format display
  - Use section separators
  - Color-code by status (green/red/yellow)
  - Show relative dates ("2 days ago")

#### Deliverables
- File submission history view
- Context menu integration
- Empty state handling

---

### Phase 7: Published Folder (Computed View)
**Duration**: 2 days  
**Status**: Not Started

#### Tasks
- [ ] Create `PublishedFolderView`
  - Query all SubmittedFile where status == .accepted
  - Display as file list
  - Show publication name with each file
  - Show version that was accepted
  - Show acceptance date
  - Group by publication or date (toggle)
- [ ] Implement filtering logic
  - Filter by publication
  - Filter by date range
  - Search by file name
- [ ] Add to folder list
  - Show as special folder (different icon)
  - Place after Set Aside folder
  - Show count badge (number of published files)
  - Mark as read-only (no drag/drop into it)
- [ ] Handle tap behavior
  - Open accepted version (read-only)
  - Show submission detail
  - Show publication info
- [ ] Add empty state
  - "No published work yet"
  - Encourage user to submit files
- [ ] Prevent manual modifications
  - No "Add File" button
  - No drag/drop into folder
  - Files auto-populate when status changes to accepted

#### Deliverables
- Published folder computed view
- Integration with folder navigation
- Auto-population logic

---

### Phase 8: Reminders Integration (EventKit)
**Duration**: 2-3 days  
**Status**: Not Started

#### Tasks
- [ ] Create `ReminderService` class
  - Import EventKit
  - Initialize EKEventStore
  - Add requestAccess() method
  - Add createSubmissionReminder() method
  - Add createDeadlineReminder() method
  - Handle errors gracefully
- [ ] Implement permission request
  - Request EKEntityType.reminder access
  - Handle user approval/denial
  - Store permission status
  - Show settings link if denied
- [ ] Implement submission reminder creation
  - Accept parameters: submission, daysAfterSubmission, notes
  - Calculate due date
  - Create EKReminder
  - Set title: "Follow up: [Publication Name]"
  - Set notes with submission details
  - Set due date components
  - Save to default reminders list
  - Return reminder ID
- [ ] Implement deadline reminder creation
  - Accept parameters: publication, daysBefore or onDate
  - Calculate reminder date
  - Create EKReminder
  - Set title: "Deadline: [Publication Name]" or "Deadline Today: [Publication Name]"
  - Set notes with deadline details
  - Set due date components
  - Save to default reminders list
  - Return reminder ID
- [ ] Add permission prompt to Info.plist
  - NSRemindersUsageDescription key
  - Clear explanation of why reminders are needed
- [ ] Handle edge cases
  - Permission denied → Show error, allow skip
  - EventKit unavailable → Graceful fallback
  - Invalid dates → Validation

#### Deliverables
- ReminderService with EventKit integration
- Permission handling
- Reminder creation logic

---

### Phase 9: Reminders UI Integration
**Duration**: 2 days  
**Status**: Not Started

#### Tasks
- [ ] Create `ReminderCreationDialog` view
  - Show submission or publication details
  - Preset reminder options:
    - For submissions: 2 weeks, 30 days, 60 days, custom
    - For deadlines: 1 week before, 3 days before, on deadline date, custom
  - Custom date picker
  - Notes field (pre-filled, editable)
  - Create/Cancel buttons
- [ ] Add "Set Reminder" to submission success view
  - Show after successful submission
  - Optional step
  - Skip button
- [ ] Add "Set Reminder" to submission detail view
  - Button in toolbar or action sheet
  - Can create multiple reminders
- [ ] Add "Remind Me" to publication detail view
  - Only shown if publication has deadline
  - Creates deadline reminder
- [ ] Implement reminder creation flow
  - Show dialog
  - Call ReminderService
  - Show success confirmation
  - Show iOS Reminders app link
- [ ] Handle permission flow
  - Request permission on first use
  - Show explanation dialog
  - Handle approval
  - Handle denial (show settings link)
  - Remember permission status
- [ ] Add success confirmation
  - "Reminder created" message
  - Show when reminder will trigger
  - Option to view in Reminders app

#### Deliverables
- Reminder creation UI
- Integration points in multiple views
- Permission flow UI

---

### Phase 10: Submission Detail & History Views
**Duration**: 2-3 days  
**Status**: Not Started

#### Tasks
- [ ] Create `SubmissionDetailView`
  - Show publication name and type
  - Show submission date
  - List all submitted files
  - Show version per file
  - Show status per file (pending/accepted/rejected)
  - Show acceptance/rejection dates
  - Show response times
  - Add "Update Status" button per file
  - Add "Set Reminder" button
  - Add notes section
  - Add edit button
- [ ] Create publication submission history view
  - Show all submissions to one publication
  - Sort by date (newest first)
  - Show file counts per submission
  - Show overall status (all accepted, partial, all rejected)
  - Tap to view submission detail
- [ ] Add submission history to PublicationDetailView
  - Show recent submissions
  - Show statistics (total submitted, accepted, rejected)
  - Calculate acceptance rate
  - Show average response time
- [ ] Implement sorting/filtering
  - Sort by date, status, file count
  - Filter by status
  - Search by file name
- [ ] Add edit functionality
  - Edit submission notes
  - Edit submission date
  - Cannot change files after creation (clarify in UI)

#### Deliverables
- Submission detail view
- Publication history view
- Statistics calculations

---

### Phase 11: Deadline Warnings & Notifications
**Duration**: 1-2 days  
**Status**: Not Started

#### Tasks
- [ ] Add deadline warning banners
  - Show in publications list
  - Show in submission form (if submitting to past-deadline pub)
  - Warning levels:
    - > 7 days: No warning
    - 1-7 days: Yellow/orange warning
    - Past: Red warning
- [ ] Implement deadline countdown
  - Show "X days remaining" in publications list
  - Update daily
  - Show "Deadline passed" for past deadlines
- [ ] Add submission form warnings
  - Check deadline when selecting publication
  - Show warning if deadline passed
  - Allow submission anyway (some have rolling deadlines)
  - Confirm with user
- [ ] Add deadline sorting to publications list
  - Sort by approaching deadline
  - Show nearest deadlines first
  - Toggle between date sort and name sort
- [ ] Add visual indicators
  - Color coding (green/yellow/red)
  - Icons (⏰ warning, 🔴 past)
  - Bold text for urgent deadlines

#### Deliverables
- Deadline warning system
- Visual indicators
- Sorting options

---

### Phase 12: Navigation & Integration
**Duration**: 2 days  
**Status**: Not Started

#### Tasks
- [ ] Add Publications to sidebar
  - New section below Folders
  - Show publications list
  - Show publication count badge
  - Expandable/collapsible section
- [ ] Integrate Published folder into folder list
  - Add after Set Aside folder
  - Special icon (e.g., 🏆 or ✓)
  - Show count badge
  - Read-only indicator
- [ ] Add submission context menu to files
  - "Submit to Publication..."
  - "View Submission History"
  - Show in file list long-press menu
- [ ] Link from version lock error to submission
  - "View Submission" button in error dialog
  - Navigate directly to submission detail
  - Highlight the submission that locked the version
- [ ] Update project detail statistics
  - Show publication count
  - Show submission count
  - Show published file count
  - Show acceptance rate
- [ ] Add quick actions
  - File detail → "Submit" button
  - Publications list → Swipe actions
  - Submission detail → Edit/Delete

#### Deliverables
- Complete navigation integration
- Context menus
- Quick actions
- Statistics display

---

### Phase 13: Unit Tests
**Duration**: 2-3 days  
**Status**: Not Started

#### Test Coverage

**Version Locking Tests**
- [ ] Test: Version with SubmittedFile reference → isLocked = true
- [ ] Test: Version without references → isLocked = false
- [ ] Test: Multiple submissions reference same version → remains locked
- [ ] Test: Last submission removed → version unlocks
- [ ] Test: Edit attempt on locked version → throws error
- [ ] Test: Delete attempt on locked version → throws error

**Submission Tests**
- [ ] Test: Create submission with 3 files → all SubmittedFile records created
- [ ] Test: Create submission → default status is pending
- [ ] Test: Update status to accepted → statusDate set
- [ ] Test: Update status to rejected → statusDate set
- [ ] Test: Multiple submissions for same file → all tracked

**Status Management Tests**
- [ ] Test: Calculate response time → correct day count
- [ ] Test: Status change to accepted → acceptanceDate set
- [ ] Test: Status change to rejected → rejectionDate set
- [ ] Test: Status date defaults to today
- [ ] Test: Custom status date → saved correctly

**Deadline Tests**
- [ ] Test: Publication with future deadline → daysUntilDeadline correct
- [ ] Test: Publication with past deadline → isDeadlinePassed = true
- [ ] Test: Publication without deadline → hasDeadline = false
- [ ] Test: Deadline in 5 days → warning level correct

**Published Folder Tests**
- [ ] Test: Query accepted submissions → returns all accepted files
- [ ] Test: Group by publication → correct grouping
- [ ] Test: Status changes to accepted → appears in published folder
- [ ] Test: Status changes to rejected → removed from published folder
- [ ] Test: Multiple versions accepted → shows correct versions

**Reminders Tests (Mocked)**
- [ ] Test: Create submission reminder → correct date calculated
- [ ] Test: Create deadline reminder (before) → correct date calculated
- [ ] Test: Create deadline reminder (on date) → set to deadline date
- [ ] Test: Permission denied → error handled gracefully
- [ ] Test: Invalid date → validation error

**File Submission History Tests**
- [ ] Test: File with 3 submissions → history shows all 3
- [ ] Test: File with no submissions → empty state
- [ ] Test: Submission history sorted by date → newest first
- [ ] Test: Response time calculation → correct for each submission

#### Deliverables
- Comprehensive test suite
- 95%+ code coverage for new models
- All edge cases covered

---

### Phase 14: Manual Testing & Bug Fixes
**Duration**: 2-3 days  
**Status**: Not Started

#### Test Scenarios

**Complete Workflow Test**
1. Create new publication with deadline
2. Create submission with multiple files
3. Check versions are locked
4. Update submission status to accepted
5. Verify appears in Published folder
6. View file submission history
7. Create reminder for follow-up
8. Verify reminder in iOS Reminders app

**Version Locking Test**
1. Create submission with v2 of a file
2. Attempt to edit v2 → should show error
3. Attempt to delete v2 → should show error
4. Create v3 (should work)
5. Submit same file to another publication
6. Change first submission to rejected
7. Verify v2 still locked (second submission pending)
8. Change second submission to rejected
9. Verify v2 now unlocked

**Deadline Reminder Test**
1. Create publication with deadline in 5 days
2. Tap "Remind Me"
3. Select "3 days before"
4. Verify reminder created in iOS Reminders
5. Check reminder date is correct (2 days from now)
6. Select "On deadline date"
7. Verify second reminder created for deadline date

**File Submission History Test**
1. Create 3 publications
2. Submit same file to all 3
3. Set different statuses (pending, accepted, rejected)
4. Open file submission history
5. Verify all 3 submissions shown
6. Verify versions, dates, response times correct
7. Tap submission → opens detail

**Edge Cases**
- [ ] Submit to publication with past deadline → warning shown but allowed
- [ ] Delete publication with submissions → handle cascade
- [ ] Delete file with submissions → handle cascade or prevent
- [ ] Permission denied for reminders → graceful error
- [ ] No internet for EventKit sync → handle gracefully
- [ ] Very old submissions → response time formatted correctly
- [ ] File submitted 10 times → history performant

#### Bug Fixes
- [ ] Track and fix all bugs found during testing
- [ ] Performance optimization if needed
- [ ] UI polish and refinements
- [ ] Edge case handling

#### Deliverables
- All workflows tested and working
- Bug fixes implemented
- Performance validated
- Edge cases handled

---

### Phase 15: Documentation & Completion
**Duration**: 1-2 days  
**Status**: Not Started

#### Tasks
- [ ] Update `spec.md` with final implementation details
  - Document any deviations from plan
  - Add screenshots or mockups
  - Update data model with final schema
- [ ] Document EventKit usage
  - Add NSRemindersUsageDescription to Info.plist
  - Document permission handling
  - Add troubleshooting guide
- [ ] Create user guide
  - How to create publications
  - How to submit files
  - How to track submissions
  - How to use reminders
  - How to view published work
- [ ] Update README
  - Add Feature 008b to completed features
  - Update feature list
  - Add screenshots
- [ ] Create completion summary
  - Similar to Feature 008a completion summary
  - Document challenges and solutions
  - List all components created
  - Test coverage summary
  - Known issues or future enhancements
- [ ] Update Copilot instructions
  - Add publication management commands
  - Add data model reference
  - Add common workflows

#### Deliverables
- Complete documentation
- User guide
- Completion summary
- Updated README

---

## Implementation Order

### Week 1
- ✅ Days 1-2: Phase 1 (Data Models)
- ✅ Days 3-5: Phase 2 (Publications UI)

### Week 2
- ✅ Days 1-2: Phase 3 (Submission Creation)
- ✅ Days 3-4: Phase 4 (Version Locking)
- ✅ Day 5: Phase 5 (Status Management)

### Week 3
- ✅ Days 1-2: Phase 6 (File History)
- ✅ Days 3-4: Phase 7 (Published Folder)
- ✅ Day 5: Phase 8 (Reminders Service)

### Week 4 (Optional)
- ✅ Days 1-2: Phase 9 (Reminders UI)
- ✅ Days 3-4: Phase 10 (Detail Views)
- ✅ Day 5: Phase 11 (Deadline Warnings)

### Week 5 (Optional)
- ✅ Day 1: Phase 12 (Navigation)
- ✅ Days 2-3: Phase 13 (Unit Tests)
- ✅ Days 4-5: Phase 14 (Manual Testing)

### Week 6 (Optional)
- ✅ Day 1: Phase 15 (Documentation)
- ✅ Day 2: Final review and polish

**Total Estimated Duration**: 2-3 weeks for core features, 4-6 weeks for complete implementation with all polish and testing.

---

## Success Criteria

### Functional Requirements Met
- [ ] All 34 functional requirements (FR-NEW-001 through FR-NEW-034) implemented
- [ ] Version locking prevents editing submitted versions
- [ ] Multiple submissions per file supported
- [ ] File submission history accessible
- [ ] Publication deadlines tracked with warnings
- [ ] Acceptance/rejection dates recorded
- [ ] iOS Reminders integration working
- [ ] Published folder auto-populates

### Quality Requirements
- [ ] 95%+ test coverage for new code
- [ ] All manual test scenarios pass
- [ ] No critical bugs
- [ ] Performance acceptable (< 1s for all operations)
- [ ] UI polish complete
- [ ] Documentation complete

### User Experience
- [ ] Intuitive navigation
- [ ] Clear error messages
- [ ] Helpful empty states
- [ ] Smooth animations
- [ ] Consistent with existing UI
- [ ] Accessible (VoiceOver support)

---

## Risk Mitigation

### Technical Risks
1. **EventKit permissions** - User may deny access
   - Mitigation: Graceful fallback, clear explanation, allow skip
2. **Version locking complexity** - Multiple submissions complicate unlocking logic
   - Mitigation: Comprehensive unit tests, clear business rules
3. **Query performance** - Published folder may have many records
   - Mitigation: Optimize queries, add pagination if needed

### Schedule Risks
1. **Scope creep** - Feature is already large
   - Mitigation: Stick to requirements, defer nice-to-haves
2. **Testing time** - Many integration points to test
   - Mitigation: Test continuously, not just at end

### User Experience Risks
1. **Complexity** - Many concepts (publications, submissions, versions)
   - Mitigation: Clear UI, good empty states, helpful onboarding
2. **Discovery** - Users may not find publication features
   - Mitigation: Prominent placement in navigation, tooltips

---

## Dependencies

### Must Be Complete
- ✅ Feature 008a (File Movement) - Complete
- ✅ Version management system - Exists
- ✅ SwiftData infrastructure - Exists

### Framework Requirements
- EventKit for reminders
- SwiftUI for all views
- SwiftData for persistence

### Testing Requirements
- XCTest framework
- Mock EventKit for testing
- Test project with sample data

---

## Notes

### Design Decisions
1. **Published folder is computed, not physical** - Files stay in source folders
2. **Version locking is soft** - UI prevents edits, not database constraints
3. **Reminders are optional** - Not all users will want them
4. **Deadlines are optional** - Not all publications have deadlines
5. **Multiple submissions encouraged** - Writers often submit same work to multiple places

### Future Enhancements (Out of Scope)
- Email integration for submission tracking
- Calendar events (in addition to reminders)
- Export submission history to CSV
- Publication market database integration
- Automatic follow-up reminders (recurring)
- Response rate predictions
- Cover letter templates
- Simultaneous submission tracking

---

**Status**: 📋 Plan Complete - Ready to Begin Implementation  
**Next Step**: Start Phase 1 (Data Models & Infrastructure)  
**Created By**: GitHub Copilot  
**Last Updated**: 9 November 2025
