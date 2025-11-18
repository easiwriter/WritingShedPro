# Feature Specification: File Movement System

**Feature Branch**: `008a-file-movement`  
**Created**: 2025-11-07  
**Status**: Ready for Planning  
**Parent Feature**: 008-file-movement (split into 008a and 008b)

## Overview

Enable users to move text files between source folders within a Poetry or Short Story project, with smart Trash functionality that supports restoration.

## Scope

**This Feature (008a):**
- Move files between source folders (Draft, Ready, Set Aside)
- Move files to Trash
- Restore files from Trash ("Put Back")
- Multi-file selection and movement
- Movement validation and warnings

**Next Feature (008b - Publication System):**
- Publication and Submission tracking
- Status management (pending/accepted/rejected)
- Published folder auto-population
- Submission history

---

## Source Folders

Files can move freely between these folders within the same project:

**Poetry Projects:**
- **Draft** - Work in progress
- **Ready** - Ready for submission  
- **Set Aside** - Paused/archived work

**Short Story Projects:**
- **Draft** - Work in progress
- **Ready** - Ready for submission
- **Set Aside** - Paused/archived work

---

## File Movement Rules

### Between Source Folders

Files can move freely:

```
Draft ⟷ Ready ⟷ Set Aside
  ↓       ↓        ↓
         Trash
```

**Validation:**
- ✅ Within same project only
- ✅ From any source to any source
- ❌ Cannot move between projects
- ❌ Novel/Script projects deferred to Phase 2

### To Trash

**From Any Source Folder:**
- User can delete (move to Trash) from any source folder
- System creates TrashItem with original location
- File removed from source folder
- Multiple files can be deleted together

### From Trash (Put Back)

**Restoration:**
- User selects file(s) in Trash
- User chooses "Put Back"
- File returns to originalFolder (from TrashItem)
- TrashItem deleted

**Edge Cases:**
- If originalFolder deleted → File goes to Draft folder (with notification)
- If originalFolder exists → Restore to exact location
- Multiple files → All restored to their original folders

---

## Data Model

### TrashItem Model (New)

```swift
@Model
class TrashItem {
  var id: UUID
  var textFile: TextFile              // The trashed file
  var originalFolder: Folder          // Where it came from
  var deletedDate: Date
  var project: Project
}
```

### Folder Model (No Changes)

Existing Folder model works as-is. Source folder determination based on name matching.

### TextFile Model (No Changes)

Existing TextFile model with parentFolder relationship is sufficient.

---

## User Stories

### US1: Move Single File (Priority: P1)

**As a** poet  
**I want to** move a draft poem to the Ready folder  
**So that** I can track which poems are ready for submission

**Why this priority:** Core workflow for organizing work

**Independent Test:** Create file in Draft, move to Ready, verify location change

**Acceptance Scenarios:**

1. **Given** a file in Draft folder, **When** user swipes left and taps "Move", **Then** destination picker appears
2. **Given** destination picker showing Ready and Set Aside, **When** user selects Ready, **Then** file moves to Ready
3. **Given** file moved to Ready, **When** viewing Draft folder, **Then** file no longer appears
4. **Given** file moved to Ready, **When** viewing Ready folder, **Then** file appears there

---

### US2: Move Multiple Files (Priority: P1)

**As a** writer  
**I want to** move 5 finished poems from Draft to Ready together  
**So that** I don't have to move them one at a time

**Why this priority:** Essential for batch organization

**Independent Test:** Enter edit mode, select 5 files, move all to Ready

**Acceptance Scenarios:**

1. **Given** file list view, **When** user taps "Edit" button, **Then** selection circles appear on all files
2. **Given** edit mode active, **When** user taps 3 files, **Then** 3 files show as selected (filled circles)
3. **Given** 3 files selected, **When** user taps "Move To..." toolbar button, **Then** destination picker appears
4. **Given** destination picker, **When** user selects Ready, **Then** all 3 files move to Ready folder
5. **Given** files moved, **When** operation completes, **Then** edit mode exits automatically

---

### US3: Delete File to Trash (Priority: P1)

**As a** writer  
**I want to** delete unwanted files  
**So that** I can keep my project clean

**Why this priority:** Basic file management

**Independent Test:** Delete file, verify in Trash, verify TrashItem created

**Important:** "Delete" in this feature ALWAYS means "Move to Trash" (not permanent deletion)

**Acceptance Scenarios:**

1. **Given** file in Draft, **When** user swipes left and taps "Delete", **Then** confirmation appears
2. **Given** delete confirmation, **When** user confirms, **Then** file moves to Trash folder (TrashItem created)
3. **Given** file in Trash, **When** viewing Trash, **Then** file appears with "From: Draft" label
4. **Given** file deleted, **When** viewing Draft, **Then** file no longer appears
5. **Given** file in Trash, **When** user wants to permanently delete, **Then** feature not available (deferred to future)

---

### US4: Put Back from Trash (Priority: P1)

**As a** writer  
**I want to** restore a deleted file  
**So that** I can recover accidentally deleted work

**Why this priority:** Safety net for deletions

**Independent Test:** Delete from Ready, Put Back, verify returns to Ready

**Acceptance Scenarios:**

1. **Given** file in Trash with originalFolder=Ready, **When** user taps "Put Back", **Then** file returns to Ready folder
2. **Given** file restored, **When** viewing Trash, **Then** file no longer appears in Trash
3. **Given** 3 files in Trash, **When** user selects 2 and taps "Put Back", **Then** both files restore to their original folders
4. **Given** file in Trash but originalFolder deleted, **When** Put Back, **Then** file goes to Draft with message "Restored to Draft (original folder not found)"

---

### US5: Edit Mode Selection (Priority: P1)

**As a** user  
**I want to** enter edit mode to select multiple files  
**So that** I can perform batch operations (move or delete to trash)

**Why this priority:** Enables multi-select workflow

**Independent Test:** Tap Edit, select files, verify selection state

**How Edit Mode Works:**
- **Normal Mode**: Tapping file opens it, swipe reveals actions
- **Edit Mode**: Tapping file toggles selection, toolbar shows batch actions
- Edit Mode serves BOTH selection AND actions (via toolbar buttons)

**Acceptance Scenarios:**

1. **Given** file list, **When** user taps "Edit" button, **Then** all file rows show selection circles (empty ⚪)
2. **Given** edit mode, **When** user taps file, **Then** file is selected (filled circle ⚫) and file does NOT open
3. **Given** file selected, **When** user taps again, **Then** file is deselected (empty circle ⚪)
4. **Given** edit mode, **When** user taps "Cancel", **Then** edit mode exits and selections clear
5. **Given** 5 files selected, **When** toolbar appears, **Then** shows "Move 5 items" and "Delete 5 items" buttons
6. **Given** 3 files selected, **When** user taps "Delete 3 items", **Then** confirmation appears then **files move to Trash**
7. **Given** action completed, **When** files moved or deleted, **Then** edit mode auto-exits

---

### US6: Swipe Actions (Priority: P2)

**As a** user  
**I want to** quickly move or delete a single file with swipe  
**So that** I don't need to enter edit mode for simple actions

**Why this priority:** Convenience feature but not critical

**Independent Test:** Swipe file, tap Move, verify works

**Acceptance Scenarios:**

1. **Given** file in list, **When** user swipes left, **Then** "Move" and "Delete" buttons appear
2. **Given** swipe revealed buttons, **When** user taps "Move", **Then** destination picker appears
3. **Given** swipe revealed buttons, **When** user taps "Delete", **Then** file moves to Trash
4. **Given** swipe revealed, **When** user swipes back or taps elsewhere, **Then** buttons hide

---

## Functional Requirements

### File Movement

- **FR-001**: Files MUST be moveable between source folders (Draft, Ready, Set Aside) within same project
- **FR-002**: Files MUST NOT be moveable between different projects
- **FR-003**: System MUST support moving single file via swipe action
- **FR-004**: System MUST support moving multiple files via edit mode selection
- **FR-005**: Move operation MUST update TextFile.parentFolder relationship
- **FR-006**: Moved files MUST sync via CloudKit within 5 seconds

### Selection Mode

- **FR-007**: Edit mode MUST show selection circles on all file rows
- **FR-008**: Tapping file in edit mode MUST toggle selection (not open file)
- **FR-009**: Tapping file in normal mode MUST open file (not select)
- **FR-010**: Toolbar MUST show "Move X items" when files selected
- **FR-011**: Edit mode MUST support "Select All" option (optional)
- **FR-012**: Completing action MUST exit edit mode automatically

### Trash Operations

- **FR-013**: Deleting file MUST create TrashItem with originalFolder reference
- **FR-014**: TrashItem MUST record deletedDate
- **FR-015**: Trash view MUST show original folder name for each file
- **FR-016**: Put Back MUST restore file to originalFolder if it exists
- **FR-017**: Put Back MUST restore to Draft if originalFolder deleted
- **FR-018**: Put Back MUST show notification when using Draft fallback
- **FR-019**: Deleting file MUST remove it from source folder
- **FR-020**: Restoring file MUST remove TrashItem record

### Validation

- **FR-021**: System MUST prevent moves between different projects
- **FR-022**: System MUST show confirmation before deleting files
- **FR-023**: System MUST handle name conflicts gracefully (auto-rename or prompt)
- **FR-024**: System MUST preserve file content, formatting, and metadata during moves

### CloudKit Sync

- **FR-025**: TrashItem MUST sync across devices
- **FR-026**: File moves MUST sync parentFolder changes
- **FR-027**: Put Back operations MUST sync restoration

---

## Success Criteria

- **SC-001**: Users can move single file in under 3 taps (swipe → Move → destination)
- **SC-002**: Users can move 10 files together in under 10 seconds (Edit → select → Move)
- **SC-003**: Put Back succeeds for 95%+ of files (restored to original folder)
- **SC-004**: Edit mode clearly distinguishes selected vs unselected files
- **SC-005**: File moves sync across devices within 5 seconds
- **SC-006**: Zero data loss during move operations
- **SC-007**: Selection state is obvious (user never confused about what's selected)

---

## Multi-Selection UX Design

### Normal Mode (Default)

```
┌─────────────────────────────────────┐
│ Draft (3 items)           [Edit]    │
├─────────────────────────────────────┤
│ my-poem.txt                      📄 │ ← Tap opens file
│ another-poem.txt                 📄 │ ← Swipe left reveals [Move] [Delete]
│ draft-story.txt                  📄 │
└─────────────────────────────────────┘
```

**Interactions:**
- **Tap file** → Opens file for editing
- **Swipe left** → Reveals Move and Delete buttons (iOS standard)
- **Tap Edit** → Enters edit mode

### Edit Mode (Multi-Select)

```
┌─────────────────────────────────────┐
│ Draft (3 items)     [Cancel]        │
├─────────────────────────────────────┤
│ ⚪ my-poem.txt                   📄 │ ← Tap toggles selection
│ ⚫ another-poem.txt              📄 │ ← Selected (filled)
│ ⚪ draft-story.txt               📄 │ ← Not selected
└─────────────────────────────────────┘
  [Move 1 item]  [Delete]
```

**Interactions:**
- **Tap file** → Toggles selection (does NOT open file)
- **Tap Move** → Shows destination picker
- **Tap Delete** → Moves selected files to Trash (with confirmation)
- **Tap Cancel** → Exits edit mode, clears selections

### macOS Enhancements

```
┌─────────────────────────────────────┐
│ Draft (3 items)                     │
├─────────────────────────────────────┤
│ ⚫ my-poem.txt                   📄 │ ← Cmd+Click multi-select
│ ⚪ another-poem.txt              📄 │ ← Right-click context menu
│ ⚫ draft-story.txt               📄 │
└─────────────────────────────────────┘
```

**Additional macOS:**
- **Cmd+Click** → Multi-select without edit mode
- **Right-click** → Context menu (Open, Move To..., Delete)
- **Drag & Drop** → (Future) Drag to folder in sidebar

---

## Edge Cases

### Movement
- Moving file that doesn't exist → Error message
- Moving to current folder → No-op (or show "Already in {folder}")
- Moving file with unsaved changes → Warn or auto-save first
- Name conflict in destination → Auto-rename with (2), (3), etc.

### Selection
- Selecting file then it's deleted by another device → Handle gracefully
- Edit mode active when navigating away → Auto-exit edit mode
- All files deleted while in edit mode → Show empty state

### Trash
- Put Back when file with same name exists → Auto-rename or prompt
- Put Back multiple files to same deleted folder → All go to Draft
- Trash folder very full (1000+ files) → Performance considerations
- Permanent delete from Trash → (Future feature)

### Sync
- Move file while offline → Queue for sync when online
- Concurrent moves on different devices → Last-write-wins (SwiftData default)
- Restore file that was deleted on another device → Handle conflict

---

## Out of Scope (This Feature)

- ❌ Novel and Script project support (Phase 2)
- ❌ Publication/Submission tracking (Feature 008b)
- ❌ Copying files (only move)
- ❌ Cross-project moves
- ❌ Folder creation/deletion
- ❌ Automated organization rules
- ❌ Drag & drop on macOS (future enhancement)
- ❌ **Permanent deletion from Trash** (just Put Back - permanent delete is future feature)
- ❌ **Empty Trash action** (future feature)
- ❌ **Auto-delete from Trash after 30 days** (future feature)

---

## Dependencies

- **Feature 001**: Project model
- **Feature 002**: Folder structure
- **Feature 003**: TextFile model
- **Feature 004**: Undo/redo system (for move operations)
- **CloudKit**: Sync TrashItem and file moves
- **SwiftData**: Manage relationships

---

## Implementation Notes

### iOS Edit Mode Pattern

```swift
struct FileListView: View {
    @State private var editMode: EditMode = .inactive
    @State private var selectedFiles: Set<TextFile.ID> = []
    @State private var showMoveSheet = false
    
    var body: some View {
        List(selection: $selectedFiles) {
            ForEach(files) { file in
                FileRow(file: file)
                    .swipeActions(edge: .trailing) {
                        Button("Move") { /* show move sheet */ }
                        Button("Delete", role: .destructive) { /* delete */ }
                    }
            }
        }
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            
            if editMode == .active && !selectedFiles.isEmpty {
                ToolbarItem(placement: .bottomBar) {
                    Button("Move \(selectedFiles.count) items") {
                        showMoveSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showMoveSheet) {
            MoveTo DestinationPicker(files: selectedFiles)
        }
    }
}
```

---

## Testing Strategy

### Unit Tests (~15 tests)

1. **TrashItem Tests**:
   - Create TrashItem with original folder
   - Put Back to existing folder
   - Put Back when folder deleted → Draft fallback

2. **File Movement Tests**:
   - Move file between folders
   - Update parentFolder relationship
   - Prevent cross-project moves

3. **Selection Tests**:
   - Toggle selection in edit mode
   - Clear selections on cancel
   - Multiple file selection

### Integration Tests (~10 tests)

1. **Full Move Workflow**:
   - Select 3 files → Move to Ready → Verify all moved
   
2. **Trash Workflow**:
   - Delete from Draft → Verify in Trash → Put Back → Verify in Draft

3. **CloudKit Sync**:
   - Move file on device 1 → Verify sync to device 2
   - Delete file on device 1 → Verify TrashItem syncs

### UI Tests (~5 tests)

1. Edit mode activation
2. Swipe action reveals
3. Multi-select workflow
4. Destination picker flow
5. Put Back workflow

---

## Localization

```
"file.move" = "Move"
"file.moveTo" = "Move to {folder}"
"file.moved" = "Moved to {folder}"
"file.moveItems" = "Move {count} items"
"file.delete" = "Delete"
"file.deleteConfirm" = "Delete {count} files?"
"file.deleted" = "Moved to Trash"

"trash.putBack" = "Put Back"
"trash.putBackSuccess" = "Restored to {folder}"
"trash.putBackDraft" = "Restored to Draft (original folder not found)"
"trash.from" = "From: {folder}"
"trash.empty" = "Trash is empty"

"edit.mode" = "Edit"
"edit.cancel" = "Cancel"
"edit.selectAll" = "Select All"
"edit.deselectAll" = "Deselect All"

"folder.draft" = "Draft"
"folder.ready" = "Ready"
"folder.setAside" = "Set Aside"
"folder.trash" = "Trash"
```

---

**Status:** 📋 Ready for Planning (`/speckit.plan`)  
**Complexity:** Medium  
**Estimated Effort:** 2-3 weeks  
**Blocked By:** None (can start immediately)
