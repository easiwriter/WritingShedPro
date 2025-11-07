# Feature 008a: File Movement System - Tasks

**Feature**: File Movement System  
**Branch**: `008a-file-movement`  
**Status**: Ready for Implementation  
**Generated**: 2025-11-07

---

## Task Organization

Tasks are organized by implementation phase from [plan.md](./plan.md). Each task includes:
- **ID**: Unique identifier
- **Phase**: Which implementation phase
- **Type**: Model / Service / View / Test / Doc
- **Priority**: P0 (blocking) / P1 (high) / P2 (medium) / P3 (low)
- **Estimate**: Story points or hours
- **Dependencies**: What must be done first
- **Acceptance**: How to verify completion

---

## Phase 0: Research & Planning (1 day)

### R-001: Research iOS Edit Mode Patterns
- **Type**: Research
- **Priority**: P0 (blocking Phase 1)
- **Estimate**: 4 hours
- **Dependencies**: None
- **Owner**: Developer

**Description**: Study SwiftUI List selection modes and iOS edit mode best practices.

**Tasks**:
- [ ] Review SwiftUI List documentation for EditMode (.inactive, .active, .transient)
- [ ] Study Apple HIG for edit mode patterns
- [ ] Examine Mail.app edit mode behavior (selection, toolbar, auto-exit)
- [ ] Examine Files.app edit mode behavior
- [ ] Test swipe actions + edit mode interaction (verify no conflicts)
- [ ] Document platform differences (iOS vs macOS)

**Acceptance**:
- ✅ research.md created with findings
- ✅ EditMode state management approach documented
- ✅ Selection binding strategy chosen
- ✅ Toolbar placement strategy defined
- ✅ Swipe action conflict resolution documented

**Deliverable**: `specs/008a-file-movement/research.md`

---

### R-002: Validate CloudKit Sync Strategy
- **Type**: Research
- **Priority**: P0 (blocking Phase 1)
- **Estimate**: 2 hours
- **Dependencies**: None
- **Owner**: Developer

**Description**: Confirm SwiftData relationship sync works for TrashItem and file moves.

**Tasks**:
- [ ] Review SwiftData + CloudKit relationship sync documentation
- [ ] Verify parentFolder relationship changes sync correctly
- [ ] Test TrashItem creation syncs across devices
- [ ] Document offline queue handling strategy
- [ ] Plan conflict resolution (last-write-wins acceptable?)

**Acceptance**:
- ✅ CloudKit sync strategy documented
- ✅ Offline handling plan defined
- ✅ Conflict resolution approach chosen
- ✅ Testing strategy for sync verification planned

**Deliverable**: CloudKit sync section in `research.md`

---

### R-003: Create Data Model Documentation
- **Type**: Documentation
- **Priority**: P1
- **Estimate**: 2 hours
- **Dependencies**: R-001, R-002
- **Owner**: Developer

**Description**: Document TrashItem model design and relationships.

**Tasks**:
- [ ] Create data-model.md with TrashItem schema
- [ ] Document relationships (textFile, originalFolder, project)
- [ ] Create relationship diagram
- [ ] Define cascade delete rules
- [ ] Document CloudKit sync behavior

**Acceptance**:
- ✅ data-model.md created
- ✅ TrashItem properties documented
- ✅ Relationships clearly defined
- ✅ Sync behavior explained

**Deliverable**: `specs/008a-file-movement/data-model.md`

---

## Phase 1: Data Model & Service Foundation (2 days)

### M-001: Add TrashItem Model to BaseModels.swift
- **Type**: Model
- **Priority**: P0 (blocking all other work)
- **Estimate**: 3 hours
- **Dependencies**: R-003
- **Owner**: Developer

**Description**: Add TrashItem @Model to BaseModels.swift with CloudKit sync.

**Tasks**:
- [ ] Add TrashItem class to `Models/BaseModels.swift`
- [ ] Define properties: id, textFile, originalFolder, deletedDate, project
- [ ] Add SwiftData @Model macro
- [ ] Configure CloudKit sync
- [ ] Define relationships (many-to-one with Folder, TextFile, Project)
- [ ] Add cascade delete rule (TrashItem deleted when TextFile deleted)
- [ ] Add computed properties if needed (e.g., displayName)

**Acceptance**:
- ✅ TrashItem model compiles
- ✅ Can create TrashItem instance
- ✅ Relationships work (can access textFile, originalFolder, project)
- ✅ CloudKit sync configuration present
- ✅ No SwiftData warnings/errors

**Files Modified**: `WrtingShedPro/Writing Shed Pro/Models/BaseModels.swift`

---

### M-002: Define FileMoveError Enum
- **Type**: Model
- **Priority**: P0
- **Estimate**: 1 hour
- **Dependencies**: None
- **Owner**: Developer

**Description**: Create error enum for file movement validation.

**Tasks**:
- [ ] Create FileMoveError enum
- [ ] Add cases: crossProjectMove, invalidSourceFolder, invalidDestinationFolder, fileNotFound, folderNotFound, nameConflict(suggestedName: String)
- [ ] Implement LocalizedError protocol
- [ ] Write localized error descriptions
- [ ] Add error recovery suggestions

**Acceptance**:
- ✅ FileMoveError enum defined
- ✅ All error cases covered
- ✅ Localized descriptions provided
- ✅ User-friendly error messages

**Files Created**: `WrtingShedPro/Writing Shed Pro/Services/FileMoveError.swift`

---

### S-001: Create FileMoveService
- **Type**: Service
- **Priority**: P0 (blocking Phase 2+)
- **Estimate**: 8 hours
- **Dependencies**: M-001, M-002
- **Owner**: Developer

**Description**: Implement core file movement logic.

**Tasks**:
- [ ] Create `FileMoveService.swift`
- [ ] Inject ModelContext dependency
- [ ] Implement `moveFile(_:to:) throws`
- [ ] Implement `moveFiles(_:to:) throws`
- [ ] Implement `deleteFile(_:) throws` (creates TrashItem)
- [ ] Implement `deleteFiles(_:) throws`
- [ ] Implement `putBack(_:) throws`
- [ ] Implement `putBackMultiple(_:) throws`
- [ ] Implement `validateMove(_:to:) throws`
- [ ] Add name conflict detection
- [ ] Add Trash folder detection (by name)
- [ ] Handle Draft fallback when originalFolder deleted

**Acceptance**:
- ✅ All methods implemented
- ✅ Validation logic works (throws appropriate errors)
- ✅ TrashItem created on delete
- ✅ Put Back restores to original folder
- ✅ Put Back falls back to Draft when needed
- ✅ Name conflicts handled (auto-rename)

**Files Created**: `WrtingShedPro/Writing Shed Pro/Services/FileMoveService.swift`

---

### T-001: Write TrashItem Model Tests
- **Type**: Test
- **Priority**: P1
- **Estimate**: 3 hours
- **Dependencies**: M-001
- **Owner**: Developer

**Description**: Unit tests for TrashItem model.

**Tasks**:
- [ ] Test TrashItem creation
- [ ] Test relationships (textFile, originalFolder, project)
- [ ] Test cascade delete (TrashItem deleted when TextFile deleted)
- [ ] Test CloudKit sync (if testable in unit tests)
- [ ] Test computed properties

**Acceptance**:
- ✅ 8+ tests written
- ✅ All tests pass
- ✅ Relationships verified
- ✅ Cascade delete verified

**Files Created**: `WritingShedProTests/TrashItemTests.swift`

---

### T-002: Write FileMoveService Tests
- **Type**: Test
- **Priority**: P1
- **Estimate**: 6 hours
- **Dependencies**: S-001
- **Owner**: Developer

**Description**: Unit tests for FileMoveService logic.

**Tasks**:
- [ ] Test moveFile updates parentFolder
- [ ] Test moveFile throws on cross-project move
- [ ] Test moveFiles handles multiple files
- [ ] Test deleteFile creates TrashItem
- [ ] Test deleteFiles creates multiple TrashItems
- [ ] Test putBack restores to originalFolder
- [ ] Test putBack uses Draft fallback when originalFolder deleted
- [ ] Test validateMove catches all error cases
- [ ] Test name conflict detection
- [ ] Test name conflict auto-rename
- [ ] Test Trash folder identification
- [ ] Test atomic batch operations (all succeed or all fail)

**Acceptance**:
- ✅ 15+ tests written
- ✅ All tests pass
- ✅ Edge cases covered
- ✅ Error handling verified
- ✅ 90%+ code coverage for FileMoveService

**Files Created**: `WritingShedProTests/FileMoveServiceTests.swift`

---

## Phase 2: File List Component (2 days)

### V-001: Create FileListView Component
- **Type**: View
- **Priority**: P0 (blocking Phase 3-5)
- **Estimate**: 8 hours
- **Dependencies**: S-001
- **Owner**: Developer

**Description**: Build reusable file list with edit mode support.

**Tasks**:
- [ ] Create `FileListView.swift` in Views/Components/
- [ ] Define props (files, folder, callbacks)
- [ ] Add @State for editMode (.inactive / .active)
- [ ] Add @State for selectedFiles (Set<TextFile.ID>)
- [ ] Implement List with selection binding
- [ ] Implement Edit button (switches to .active)
- [ ] Implement Cancel button (switches to .inactive, clears selection)
- [ ] Handle tap in normal mode (calls onFileSelected)
- [ ] Handle tap in edit mode (toggles selection)
- [ ] Style selection circles (⚪ empty / ⚫ filled)
- [ ] Disable file opening when in edit mode

**Acceptance**:
- ✅ Component compiles and displays
- ✅ Edit button enters edit mode
- ✅ Cancel button exits edit mode
- ✅ Tapping file in normal mode calls onFileSelected
- ✅ Tapping file in edit mode toggles selection
- ✅ Selection circles display correctly

**Files Created**: `WrtingShedPro/Writing Shed Pro/Views/Components/FileListView.swift`

---

### V-002: Implement Swipe Actions
- **Type**: View
- **Priority**: P1
- **Estimate**: 3 hours
- **Dependencies**: V-001
- **Owner**: Developer

**Description**: Add swipe actions for quick single-file operations.

**Tasks**:
- [ ] Add .swipeActions(edge: .trailing) to FileRow
- [ ] Add "Move" button (shows move sheet)
- [ ] Add "Delete" button with .destructive role
- [ ] Disable swipe when editMode == .active
- [ ] Test swipe gestures on device (not just simulator)
- [ ] Verify no conflict with edit mode

**Acceptance**:
- ✅ Swipe left reveals Move and Delete buttons
- ✅ Swipe actions disabled in edit mode
- ✅ Tapping Move shows move sheet
- ✅ Tapping Delete shows confirmation
- ✅ Swipe gestures feel responsive

**Files Modified**: `FileListView.swift`

---

### V-003: Implement Edit Mode Toolbar
- **Type**: View
- **Priority**: P0
- **Estimate**: 4 hours
- **Dependencies**: V-001
- **Owner**: Developer

**Description**: Add toolbar with Move/Delete actions for selected files.

**Tasks**:
- [ ] Add ToolbarItemGroup(placement: .bottomBar)
- [ ] Show only when editMode == .active && !selectedFiles.isEmpty
- [ ] Add "Move X items" button
- [ ] Add "Delete X items" button
- [ ] Update counts dynamically as selection changes
- [ ] Trigger onMoveRequested callback
- [ ] Trigger onDeleteRequested callback
- [ ] Test on iOS (bottom bar) and macOS (context toolbar)

**Acceptance**:
- ✅ Toolbar appears when files selected in edit mode
- ✅ Toolbar hidden when no files selected
- ✅ Counts update correctly
- ✅ Move button triggers callback
- ✅ Delete button triggers callback
- ✅ Toolbar positioned correctly on iOS and macOS

**Files Modified**: `FileListView.swift`

---

### V-004: Implement Auto-Exit Edit Mode
- **Type**: View
- **Priority**: P1
- **Estimate**: 2 hours
- **Dependencies**: V-003
- **Owner**: Developer

**Description**: Exit edit mode automatically after action completes.

**Tasks**:
- [ ] Set editMode = .inactive after move completes
- [ ] Set editMode = .inactive after delete completes
- [ ] Clear selectedFiles after action
- [ ] Test auto-exit behavior
- [ ] Verify no flickering or animation issues

**Acceptance**:
- ✅ Edit mode exits after move
- ✅ Edit mode exits after delete
- ✅ Selections cleared
- ✅ Smooth transition back to normal mode

**Files Modified**: `FileListView.swift`

---

### T-003: Write FileListView UI Tests
- **Type**: Test
- **Priority**: P1
- **Estimate**: 5 hours
- **Dependencies**: V-001, V-002, V-003, V-004
- **Owner**: Developer

**Description**: UI tests for edit mode functionality.

**Tasks**:
- [ ] Test Edit button appears
- [ ] Test tapping Edit enters edit mode
- [ ] Test tapping Cancel exits edit mode
- [ ] Test tap file in normal mode (verify callback called)
- [ ] Test tap file in edit mode (verify selection toggled)
- [ ] Test swipe actions appear in normal mode
- [ ] Test swipe actions hidden in edit mode
- [ ] Test toolbar appears when files selected
- [ ] Test Move button triggers callback
- [ ] Test selection clears after action
- [ ] Test auto-exit edit mode

**Acceptance**:
- ✅ 10+ UI tests written
- ✅ All tests pass
- ✅ Edit mode behavior verified
- ✅ Swipe actions verified
- ✅ Toolbar behavior verified

**Files Created**: `WritingShedProTests/FileListEditModeTests.swift`

---

## Phase 3: Move Destination Picker (1 day)

### V-005: Create MoveDestinationPicker Component
- **Type**: View
- **Priority**: P0
- **Estimate**: 4 hours
- **Dependencies**: V-001
- **Owner**: Developer

**Description**: Build folder selection sheet for move operation.

**Tasks**:
- [ ] Create `MoveDestinationPicker.swift` in Views/Components/
- [ ] Define props (project, currentFolder, filesToMove, callback)
- [ ] Fetch valid destination folders (Draft, Ready, Set Aside)
- [ ] Filter out currentFolder
- [ ] Filter out Trash (can't manually move to Trash)
- [ ] Display folder list with icons
- [ ] Implement tap to select → call callback
- [ ] Add Cancel button
- [ ] Test sheet presentation and dismissal

**Acceptance**:
- ✅ Sheet displays correct folders
- ✅ Current folder excluded
- ✅ Trash excluded
- ✅ Tapping folder calls callback
- ✅ Cancel dismisses sheet

**Files Created**: `WrtingShedPro/Writing Shed Pro/Views/Components/MoveDestinationPicker.swift`

---

### V-006: Integrate MoveDestinationPicker with FileListView
- **Type**: View
- **Priority**: P0
- **Estimate**: 3 hours
- **Dependencies**: V-005
- **Owner**: Developer

**Description**: Wire up move sheet to FileListView.

**Tasks**:
- [ ] Add @State showMoveSheet to FileListView
- [ ] Present MoveDestinationPicker when showMoveSheet = true
- [ ] Pass selected files to picker
- [ ] Call FileMoveService.moveFiles on destination selected
- [ ] Dismiss sheet after move
- [ ] Exit edit mode after move
- [ ] Show success message/toast
- [ ] Handle errors from FileMoveService
- [ ] Show error alert if move fails

**Acceptance**:
- ✅ Tapping "Move X items" shows picker
- ✅ Selecting folder moves files
- ✅ Sheet dismisses after move
- ✅ Edit mode exits after move
- ✅ Success feedback shown
- ✅ Errors handled gracefully

**Files Modified**: `FileListView.swift`

---

### V-007: Add Delete Confirmation Dialog
- **Type**: View
- **Priority**: P1
- **Estimate**: 2 hours
- **Dependencies**: V-001
- **Owner**: Developer

**Description**: Add confirmation before deleting files.

**Tasks**:
- [ ] Add @State showDeleteConfirm to FileListView
- [ ] Use .confirmationDialog modifier
- [ ] Show count in message: "Delete X files?"
- [ ] Add message: "This will move them to Trash. You can restore them later."
- [ ] Add "Delete" button (destructive role)
- [ ] Add "Cancel" button
- [ ] Call FileMoveService.deleteFiles on confirm
- [ ] Exit edit mode after delete
- [ ] Show success feedback

**Acceptance**:
- ✅ Confirmation appears before delete
- ✅ Message clearly states "move to Trash"
- ✅ Delete button has destructive styling
- ✅ Cancel button cancels operation
- ✅ Files deleted on confirm
- ✅ Edit mode exits after delete

**Files Modified**: `FileListView.swift`

---

## Phase 4: Trash View & Put Back (1 day)

### V-008: Create TrashView
- **Type**: View
- **Priority**: P0
- **Estimate**: 5 hours
- **Dependencies**: M-001, S-001
- **Owner**: Developer

**Description**: Build Trash folder view with Put Back functionality.

**Tasks**:
- [ ] Create `TrashView.swift` in Views/Trash/
- [ ] Add @Query for TrashItems filtered by project
- [ ] Sort by deletedDate (newest first)
- [ ] Display list of trashed files
- [ ] Show "From: {folder name}" label for each
- [ ] Show deleted date
- [ ] Add Edit mode support (reuse FileListView pattern)
- [ ] Add Put Back button/action
- [ ] Handle single file Put Back (swipe action)
- [ ] Handle multiple file Put Back (edit mode)

**Acceptance**:
- ✅ Trash view displays trashed files
- ✅ Original folder shown for each file
- ✅ Deleted date shown
- ✅ Edit mode works
- ✅ Put Back available

**Files Created**: `WrtingShedPro/Writing Shed Pro/Views/Trash/TrashView.swift`

---

### V-009: Implement Put Back Logic
- **Type**: View
- **Priority**: P0
- **Estimate**: 4 hours
- **Dependencies**: V-008
- **Owner**: Developer

**Description**: Implement file restoration from Trash.

**Tasks**:
- [ ] Call FileMoveService.putBack for single file
- [ ] Call FileMoveService.putBackMultiple for multiple files
- [ ] Handle Draft fallback case
- [ ] Show notification: "Restored to {folder}"
- [ ] Show notification: "Restored to Draft (original folder not found)" when fallback
- [ ] Remove TrashItem after successful restoration
- [ ] Refresh view after Put Back
- [ ] Handle errors gracefully

**Acceptance**:
- ✅ Single file Put Back works
- ✅ Multiple file Put Back works
- ✅ Files return to original folder
- ✅ Draft fallback works when originalFolder deleted
- ✅ Appropriate notification shown
- ✅ TrashItem removed after restore
- ✅ View refreshes correctly

**Files Modified**: `TrashView.swift`

---

### V-010: Integrate Trash in Folder Sidebar
- **Type**: View
- **Priority**: P1
- **Estimate**: 2 hours
- **Dependencies**: V-008
- **Owner**: Developer

**Description**: Add Trash folder to sidebar navigation.

**Tasks**:
- [ ] Add "Trash" folder to sidebar
- [ ] Use distinct trash icon (SF Symbol: trash)
- [ ] Show count badge (optional)
- [ ] Navigate to TrashView on tap
- [ ] Position after Set Aside, before Published (future)
- [ ] Test navigation flow

**Acceptance**:
- ✅ Trash appears in sidebar
- ✅ Icon is distinct and recognizable
- ✅ Tapping navigates to TrashView
- ✅ Proper positioning in folder list

**Files Modified**: Folder sidebar view (likely `FolderListView.swift` or similar)

---

## Phase 5: Integration & Polish (1 day)

### V-011: Update FolderDetailView to Use FileListView
- **Type**: View
- **Priority**: P0
- **Estimate**: 4 hours
- **Dependencies**: V-001, V-006, V-007
- **Owner**: Developer

**Description**: Replace existing file list with new FileListView component.

**Tasks**:
- [ ] Replace existing file list code in FolderDetailView
- [ ] Pass files array to FileListView
- [ ] Implement onFileSelected callback (navigate to FileEditView)
- [ ] Implement onMoveRequested callback (use FileMoveService)
- [ ] Implement onDeleteRequested callback (use FileMoveService)
- [ ] Handle errors from FileMoveService
- [ ] Show error alerts for invalid operations
- [ ] Test all workflows (open, move, delete)

**Acceptance**:
- ✅ FolderDetailView uses FileListView
- ✅ Opening files works
- ✅ Moving files works
- ✅ Deleting files works
- ✅ Errors handled gracefully
- ✅ No regressions in existing functionality

**Files Modified**: `WrtingShedPro/Writing Shed Pro/Views/FolderDetailView.swift`

---

### V-012: Add Success/Error Feedback
- **Type**: View
- **Priority**: P2
- **Estimate**: 2 hours
- **Dependencies**: V-011
- **Owner**: Developer

**Description**: Provide user feedback for operations.

**Tasks**:
- [ ] Add toast/banner for successful move
- [ ] Add toast/banner for successful delete
- [ ] Add toast/banner for successful Put Back
- [ ] Add alert for errors
- [ ] Keep messages brief and clear
- [ ] Test on iOS and macOS
- [ ] Consider using native alerts vs custom toasts

**Acceptance**:
- ✅ Success feedback shown for all operations
- ✅ Error feedback shown for failures
- ✅ Messages are clear and helpful
- ✅ Feedback doesn't block user workflow

**Files Modified**: `FileListView.swift`, `TrashView.swift`, `FolderDetailView.swift`

---

### T-004: Write Integration Tests
- **Type**: Test
- **Priority**: P1
- **Estimate**: 5 hours
- **Dependencies**: V-011, V-009
- **Owner**: Developer

**Description**: End-to-end integration tests for complete workflows.

**Tasks**:
- [ ] Test full move workflow: Select → Move → Verify in destination
- [ ] Test full delete workflow: Select → Delete → Verify in Trash
- [ ] Test full Put Back workflow: Select in Trash → Put Back → Verify in original folder
- [ ] Test Draft fallback: Delete from folder → Delete folder → Put Back → Verify in Draft
- [ ] Test name conflict handling
- [ ] Test concurrent operations (if applicable)

**Acceptance**:
- ✅ 5+ integration tests written
- ✅ All tests pass
- ✅ Complete workflows verified
- ✅ Edge cases tested

**Files Created**: `WritingShedProTests/MovePutBackIntegrationTests.swift`

---

### T-005: CloudKit Sync Testing
- **Type**: Test
- **Priority**: P0
- **Estimate**: 4 hours
- **Dependencies**: V-011, V-009
- **Owner**: Developer

**Description**: Verify CloudKit sync works correctly.

**Tasks**:
- [ ] Test file movement syncs across devices
- [ ] Test TrashItem creation syncs
- [ ] Test Put Back syncs
- [ ] Test offline queue (moves queued until online)
- [ ] Test conflict resolution (last-write-wins)
- [ ] Document sync issues if found
- [ ] Verify sync within 5 seconds (success criteria)

**Acceptance**:
- ✅ File moves sync across devices
- ✅ TrashItems sync across devices
- ✅ Put Back syncs across devices
- ✅ Offline operations queue and sync when online
- ✅ Conflicts resolved gracefully
- ✅ Sync performance meets requirements (<5s)

**Test Approach**: Manual testing with two devices (iPhone + Mac or iPhone + iPhone)

---

## Phase 6: Mac Catalyst Enhancements (2 days)

### V-013: Implement Cmd+Click Multi-Select (macOS)
- **Type**: View
- **Priority**: P2
- **Estimate**: 4 hours
- **Dependencies**: V-001
- **Owner**: Developer

**Description**: Enable macOS-native multi-select without edit mode.

**Tasks**:
- [ ] Detect platform with `#if targetEnvironment(macCatalyst)`
- [ ] Enable Cmd+Click for multi-select
- [ ] Maintain Edit button as alternative
- [ ] Test modifier key detection
- [ ] Verify no conflicts with edit mode
- [ ] Test on macOS Catalyst

**Acceptance**:
- ✅ Cmd+Click selects multiple files on macOS
- ✅ Edit mode still works as fallback
- ✅ No conflicts between approaches
- ✅ Modifier keys detected correctly

**Files Modified**: `FileListView.swift`

---

### V-014: Implement Right-Click Context Menu (macOS)
- **Type**: View
- **Priority**: P2
- **Estimate**: 4 hours
- **Dependencies**: V-001
- **Owner**: Developer

**Description**: Add macOS-native context menus.

**Tasks**:
- [ ] Add .contextMenu to file rows (macOS only)
- [ ] Add "Open" menu item
- [ ] Add "Move To..." submenu with folders
- [ ] Add "Delete" menu item (destructive)
- [ ] Work on single file or selection
- [ ] Test on macOS Catalyst
- [ ] Verify consistent with macOS conventions

**Acceptance**:
- ✅ Right-click shows context menu on macOS
- ✅ Menu items functional
- ✅ Move To submenu shows folders
- ✅ Delete moves to Trash
- ✅ Works with selections

**Files Modified**: `FileListView.swift`

---

### V-015: Mac Catalyst Polish
- **Type**: View
- **Priority**: P3
- **Estimate**: 4 hours
- **Dependencies**: V-013, V-014
- **Owner**: Developer

**Description**: General macOS UX improvements.

**Tasks**:
- [ ] Test toolbar placement on macOS
- [ ] Verify keyboard shortcuts work
- [ ] Test window resizing behavior
- [ ] Verify all controls are keyboard-accessible
- [ ] Check for any iOS-specific UI that looks wrong on macOS
- [ ] Polish animations and transitions

**Acceptance**:
- ✅ UI looks native on macOS
- ✅ Keyboard navigation works
- ✅ Toolbars positioned correctly
- ✅ No iOS-specific quirks visible

**Files Modified**: Various view files as needed

---

## Phase 7: Testing & Documentation (2 days)

### T-006: Achieve 90%+ Unit Test Coverage
- **Type**: Test
- **Priority**: P1
- **Estimate**: 6 hours
- **Dependencies**: All implementation tasks
- **Owner**: Developer

**Description**: Fill gaps in test coverage.

**Tasks**:
- [ ] Run code coverage report
- [ ] Identify untested code paths
- [ ] Write additional tests for:
  - FileMoveService edge cases
  - TrashItem model edge cases
  - FileListView logic branches
- [ ] Test name conflict scenarios
- [ ] Test very large selections (100+ files)
- [ ] Test concurrent operations
- [ ] Achieve 90%+ coverage for FileMoveService
- [ ] Achieve 80%+ coverage overall

**Acceptance**:
- ✅ 90%+ coverage for FileMoveService
- ✅ 80%+ coverage for overall feature
- ✅ All critical paths tested
- ✅ Edge cases covered

**Tools**: Xcode Code Coverage, XCTest

---

### T-007: Comprehensive Manual Testing
- **Type**: Test
- **Priority**: P0
- **Estimate**: 6 hours
- **Dependencies**: All implementation tasks
- **Owner**: Developer + QA

**Description**: Manual testing of all user stories and edge cases.

**Tasks**:
- [ ] Test all 6 user stories from spec.md
- [ ] Verify all acceptance criteria met
- [ ] Test edge cases from spec:
  - Move file that doesn't exist
  - Move to current folder
  - Name conflicts
  - Very full Trash (1000+ items)
  - Offline operations
  - Concurrent edits on multiple devices
- [ ] Performance testing with large projects
- [ ] Test on iOS device (not just simulator)
- [ ] Test on macOS Catalyst
- [ ] Document any issues found

**Acceptance**:
- ✅ All user stories pass
- ✅ All acceptance criteria met
- ✅ Edge cases handled correctly
- ✅ Performance acceptable
- ✅ No critical bugs found

**Deliverable**: Manual testing checklist (completed)

---

### T-008: Create Manual Testing Checklist
- **Type**: Documentation
- **Priority**: P1
- **Estimate**: 2 hours
- **Dependencies**: Spec complete
- **Owner**: Developer

**Description**: Create comprehensive manual testing checklist.

**Tasks**:
- [ ] Extract all acceptance scenarios from spec
- [ ] Add edge case scenarios
- [ ] Add performance benchmarks
- [ ] Add platform-specific tests (iOS vs macOS)
- [ ] Create checklist format
- [ ] Include pass/fail columns
- [ ] Include notes column

**Acceptance**:
- ✅ Checklist covers all user stories
- ✅ Edge cases included
- ✅ Easy to follow format
- ✅ Ready for manual testing

**Deliverable**: `specs/008a-file-movement/checklists/manual-testing.md`

---

### D-001: Create User-Facing Documentation
- **Type**: Documentation
- **Priority**: P2
- **Estimate**: 4 hours
- **Dependencies**: Implementation complete
- **Owner**: Developer/Tech Writer

**Description**: Write user guide for file movement features.

**Tasks**:
- [ ] Create quickstart.md
- [ ] Document how to move files (both swipe and edit mode)
- [ ] Document how to use edit mode
- [ ] Document how to delete to Trash
- [ ] Document how to Put Back from Trash
- [ ] Add screenshots or GIFs (if possible)
- [ ] Add tips and tricks
- [ ] Add troubleshooting section

**Acceptance**:
- ✅ quickstart.md created
- ✅ All features documented
- ✅ Clear step-by-step instructions
- ✅ Visual aids included (if possible)
- ✅ Easy for users to understand

**Deliverable**: `specs/008a-file-movement/quickstart.md`

---

### D-002: Update Project Documentation
- **Type**: Documentation
- **Priority**: P3
- **Estimate**: 2 hours
- **Dependencies**: Implementation complete
- **Owner**: Developer

**Description**: Update main project documentation.

**Tasks**:
- [ ] Update main README.md with feature completion
- [ ] Update CHANGELOG.md with feature details
- [ ] Update feature list in project docs
- [ ] Document any API changes
- [ ] Update architecture docs if needed

**Acceptance**:
- ✅ README updated
- ✅ CHANGELOG updated
- ✅ Feature properly documented
- ✅ Breaking changes noted (if any)

**Files Modified**: Project root README.md, CHANGELOG.md

---

### D-003: Create API Contracts Documentation
- **Type**: Documentation
- **Priority**: P2
- **Estimate**: 3 hours
- **Dependencies**: S-001
- **Owner**: Developer

**Description**: Document FileMoveService API contracts.

**Tasks**:
- [ ] Document each FileMoveService method
- [ ] Include parameters, return types, throws
- [ ] Document preconditions and postconditions
- [ ] Add usage examples
- [ ] Document error cases
- [ ] Add to contracts/ folder

**Acceptance**:
- ✅ All methods documented
- ✅ Contracts clearly defined
- ✅ Examples provided
- ✅ Error cases explained

**Deliverable**: `specs/008a-file-movement/contracts/FileMoveService.md`

---

## Task Summary by Type

### Models (2 tasks)
- M-001: Add TrashItem Model
- M-002: Define FileMoveError Enum

### Services (1 task)
- S-001: Create FileMoveService

### Views (15 tasks)
- V-001: Create FileListView Component
- V-002: Implement Swipe Actions
- V-003: Implement Edit Mode Toolbar
- V-004: Implement Auto-Exit Edit Mode
- V-005: Create MoveDestinationPicker Component
- V-006: Integrate MoveDestinationPicker
- V-007: Add Delete Confirmation Dialog
- V-008: Create TrashView
- V-009: Implement Put Back Logic
- V-010: Integrate Trash in Sidebar
- V-011: Update FolderDetailView
- V-012: Add Success/Error Feedback
- V-013: Cmd+Click Multi-Select (macOS)
- V-014: Right-Click Context Menu (macOS)
- V-015: Mac Catalyst Polish

### Tests (8 tasks)
- T-001: TrashItem Model Tests
- T-002: FileMoveService Tests
- T-003: FileListView UI Tests
- T-004: Integration Tests
- T-005: CloudKit Sync Testing
- T-006: Achieve 90%+ Coverage
- T-007: Comprehensive Manual Testing
- T-008: Create Manual Testing Checklist

### Documentation (6 tasks)
- D-001: User-Facing Documentation
- D-002: Update Project Documentation
- D-003: API Contracts Documentation
- R-001: Research iOS Edit Mode
- R-002: Validate CloudKit Sync
- R-003: Create Data Model Docs

### Research (3 tasks)
- R-001: Research iOS Edit Mode Patterns
- R-002: Validate CloudKit Sync Strategy
- R-003: Create Data Model Documentation

---

## Effort Summary

| Phase | Tasks | Estimated Hours |
|-------|-------|-----------------|
| Phase 0: Research | 3 | 8 hours |
| Phase 1: Data Model & Service | 5 | 21 hours |
| Phase 2: File List Component | 5 | 22 hours |
| Phase 3: Move Destination Picker | 3 | 9 hours |
| Phase 4: Trash View & Put Back | 3 | 11 hours |
| Phase 5: Integration & Polish | 3 | 11 hours |
| Phase 6: Mac Catalyst | 3 | 12 hours |
| Phase 7: Testing & Docs | 5 | 17 hours |
| **TOTAL** | **30 tasks** | **~111 hours** |

**Timeline**: ~14 working days (8 hours/day) = **~3 weeks**

*Note: Original estimate was 12 days (2.5 weeks). Adding comprehensive testing and documentation brings it to 3 weeks.*

---

## Critical Path

The following tasks MUST be completed in order (blocking dependencies):

1. **R-001, R-002, R-003** (Research) → **M-001** (TrashItem Model) → **S-001** (FileMoveService)
2. **S-001** → **V-001** (FileListView) → **V-006** (Integration) → **V-011** (FolderDetailView)
3. **V-001** → **V-008** (TrashView) → **V-009** (Put Back)
4. **V-011, V-009** → **T-004** (Integration Tests) → **T-007** (Manual Testing)

All other tasks can be parallelized or reordered as needed.

---

## Definition of Done

A task is considered "done" when:

- ✅ Code written and compiles without warnings
- ✅ Unit tests written and passing (where applicable)
- ✅ Code reviewed (if team workflow requires)
- ✅ Manually tested on device (iOS and macOS where applicable)
- ✅ Documentation updated (inline comments, API docs)
- ✅ No regressions in existing features
- ✅ Acceptance criteria met
- ✅ Ready for merge to main branch

---

## Risk Mitigation

### High-Risk Tasks
- **S-001** (FileMoveService): Core logic - extensive testing required
- **T-005** (CloudKit Sync): May uncover sync issues - allocate buffer time
- **V-001** (FileListView): Edit mode complexity - follow iOS patterns carefully

### Mitigation Strategies
- Start high-risk tasks early
- Allocate extra testing time
- Have fallback plans (documented in plan.md)
- Regular manual testing throughout development

---

## Next Steps

1. **Begin Phase 0**: Start with R-001 (Research iOS Edit Mode Patterns)
2. **Create research.md**: Document findings from Phase 0
3. **Review findings**: Validate approach before starting Phase 1
4. **Start Phase 1**: Begin with M-001 (Add TrashItem Model)

**Ready to start?** Begin with task **R-001**: Research iOS Edit Mode Patterns

---

**Last Updated**: 2025-11-07  
**Total Tasks**: 30  
**Estimated Effort**: ~3 weeks (111 hours)  
**Status**: Ready for Implementation
