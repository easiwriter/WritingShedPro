# File Collections - Implementation Plan

**Total Phases**: 8  
**Estimated Complexity**: Medium  
**Dependencies**: Feature 008b (Publications), Feature 008a (File Movement System)

## Phase Overview

| Phase | Title | Duration | Status |
|-------|-------|----------|--------|
| 1 | Create Collections System Folder | - | Not Started |
| 2 | Collections Folder UI | - | Not Started |
| 3 | Create New Collection | - | Not Started |
| 4 | Multi-Select in Ready Folder | - | Not Started |
| 5 | Add Files to Collection | - | Not Started |
| 6 | Edit Collection Contents | - | Not Started |
| 7 | View Collection Files | - | Not Started |
| 8 | Submit Collection to Publication | - | Not Started |

---

## Phase 1: Create Collections System Folder

### Overview
Add "Collections" as a system folder in the folder hierarchy, positioned between Ready and Set Aside.

### Tasks

#### 1.1 Update Folder Model
- [ ] Add flag to distinguish system folders (Collections, Ready, Set Aside) from user folders
- [ ] Or create separate handling for project template folders
- [ ] Document folder types and their ordering

#### 1.2 Update Project Initialization
- [ ] When creating Poetry or Short Story project, add Collections folder to template
- [ ] Position it between Ready and Set Aside in default order
- [ ] Mark as read-only/system folder

#### 1.3 Update Folder Display Logic
- [ ] Update ProjectBrowserView to show Collections folder
- [ ] Ensure Collections folder displays in correct position
- [ ] Handle read-only folder styling (if needed)

#### 1.4 Prevent Direct File Addition
- [ ] Collections folder should not allow drag-drop of files
- [ ] Hide file creation options in Collections folder
- [ ] Only Submissions can be added to Collections

#### 1.5 Unit Tests
- [ ] Test Collections folder creation in Poetry project
- [ ] Test Collections folder creation in Short Story project
- [ ] Test Collections folder NOT created in other project types
- [ ] Test Collections folder position in hierarchy

---

## Phase 2: Collections Folder UI

### Overview
Display list of user-created Collections in the Collections folder with ability to create new ones.

### Tasks

#### 2.1 Collections List View
- [ ] Create view to display Collections (similar to folder listing)
- [ ] Each Collection shows:
  - Name
  - File count (number of submissions)
  - Creation date
  - Last modified date
- [ ] Tap to open Collection

#### 2.2 Create Collection Button
- [ ] Add button/action to create new Collection
- [ ] Position prominently in Collections folder view
- [ ] Links to Phase 3 (Create New Collection)

#### 2.3 Collection Selection
- [ ] Tap Collection to view its contents
- [ ] Show list of files in Collection with their versions
- [ ] Display version number for each file
- [ ] Navigation back to Collections list

#### 2.4 Tests
- [ ] Collections list displays empty state
- [ ] Collections list displays multiple Collections
- [ ] Tap Collection opens its contents
- [ ] Navigation works correctly

---

## Phase 3: Create New Collection

### Overview
Allow users to create new named Collections with validation.

### Tasks

#### 3.1 Create Collection Dialog
- [ ] Build dialog/form to name new Collection
- [ ] Text input for Collection name
- [ ] Cancel and Create buttons
- [ ] Clear placeholder text

#### 3.2 Name Validation
- [ ] Check name is not empty
- [ ] Check name is unique within Collections folder
- [ ] Check for invalid filesystem characters
- [ ] Show error messages for validation failures

#### 3.3 Folder Creation
- [ ] Create new Folder with given name in Collections directory
- [ ] Set folder as read-only (mark as Collection type)
- [ ] Set project reference
- [ ] Initialize empty submissions list

#### 3.4 UI Feedback
- [ ] Show success feedback after creation
- [ ] Return to Collections list
- [ ] New Collection appears in list immediately
- [ ] Handle creation errors gracefully

#### 3.5 Unit Tests
- [ ] Create Collection with valid name
- [ ] Reject duplicate Collection name
- [ ] Reject empty name
- [ ] Reject name with invalid characters
- [ ] Verify folder structure created correctly

---

## Phase 4: Multi-Select in Ready Folder

### Overview
Enable users to select multiple files in Ready folder for bulk operations.

### Tasks

#### 4.1 Select Mode UI
- [ ] Add select mode toggle to Ready folder
- [ ] Show checkboxes next to files when in select mode
- [ ] Highlight selected files
- [ ] Counter showing "X files selected"

#### 4.2 Selection Actions
- [ ] Tap checkbox to select/deselect file
- [ ] "Select All" option
- [ ] "Deselect All" option
- [ ] Clear selection when exiting select mode

#### 4.3 Bulk Action Button
- [ ] Show "Add to Collection..." button when files selected
- [ ] Only enable when 1+ files selected
- [ ] Links to Phase 5 (Add Files to Collection)

#### 4.4 Tests
- [ ] Enter/exit select mode
- [ ] Select individual files
- [ ] Select all files
- [ ] Counter updates correctly
- [ ] Button state changes with selection

---

## Phase 5: Add Files to Collection

### Overview
Add selected files from Ready folder to a Collection with version selection.

### Tasks

#### 5.1 Collection Selection
- [ ] Show list of existing Collections
- [ ] Show "Create New Collection" option
- [ ] User selects target Collection
- [ ] Or creates new Collection

#### 5.2 Version Selection
- [ ] For each selected file, show available versions
- [ ] Default to "Current" (last worked-on version)
- [ ] Allow user to select different version for each file
- [ ] Display version number and date

#### 5.3 Create Submissions
- [ ] For each selected file, create Submission
- [ ] Link Submission to Collection folder
- [ ] Store selected version reference
- [ ] Handle duplicate file additions (already in Collection?)

#### 5.4 Feedback and Return
- [ ] Show success message with file count added
- [ ] Return to Ready folder (exit select mode)
- [ ] Show Collections folder with newly updated Collection

#### 5.5 Unit Tests
- [ ] Add single file to Collection
- [ ] Add multiple files to Collection
- [ ] Add file with specific version
- [ ] Add file to existing Collection (different versions)
- [ ] Handle adding same file twice (reject? replace?)

---

## Phase 6: Edit Collection Contents

### Overview
Allow users to modify Collection contents, change versions, and remove files.

### Tasks

#### 6.1 Open Collection for Editing
- [ ] Display Collection contents in editable view
- [ ] Show all files with their current versions
- [ ] Show edit/delete buttons per file

#### 6.2 Change Version for File
- [ ] Tap file to show version picker
- [ ] Display all available versions
- [ ] Select new version
- [ ] Update Submission to point to new version
- [ ] Save automatically

#### 6.3 Add More Files
- [ ] "Add Files..." button in Collection view
- [ ] Re-use Phase 4/5 multi-select and add logic
- [ ] Add to existing Collection (not create new)
- [ ] Prevent duplicate files (already in Collection)

#### 6.4 Remove Files
- [ ] Swipe or tap delete button on file
- [ ] Confirm deletion
- [ ] Remove Submission from Collection
- [ ] Update file count

#### 6.5 Delete Collection
- [ ] Option to delete entire Collection
- [ ] Warn if Collection has submissions to Publications
- [ ] Confirm deletion
- [ ] Remove folder from Collections directory

#### 6.6 Tests
- [ ] Change file version in Collection
- [ ] Add files to existing Collection
- [ ] Remove file from Collection
- [ ] Delete Collection
- [ ] Delete Collection with pending submissions

---

## Phase 7: View Collection Files

### Overview
Display Collections contents for review before submission.

### Tasks

#### 7.1 Collection Contents View
- [ ] List all files in Collection
- [ ] Show filename and version number
- [ ] Show file info (word count if available)
- [ ] Tap file to preview (optional for Phase 1)

#### 7.2 Collection Metadata
- [ ] Show Collection name
- [ ] Show created date
- [ ] Show last modified date
- [ ] Show total file count
- [ ] Show total word count (sum of all files)

#### 7.3 Back Navigation
- [ ] Back button returns to Collections list
- [ ] Or option to edit Collection
- [ ] Clean navigation state

#### 7.4 Tests
- [ ] Display empty Collection
- [ ] Display Collection with single file
- [ ] Display Collection with multiple files
- [ ] Show correct versions
- [ ] Metadata displays correctly

---

## Phase 8: Submit Collection to Publication

### Overview
Integrate Collections with existing Publication submission flow.

### Tasks

#### 8.1 Update Publication Form
- [ ] Add Collections as submission source option
- [ ] Alongside "Create New Submission" option
- [ ] Display list of available Collections in project

#### 8.2 Select Collection to Submit
- [ ] User selects Collection
- [ ] Shows files that will be submitted
- [ ] Shows versions that will be used
- [ ] Confirm before submission

#### 8.3 Create Publication Submission
- [ ] For each file in Collection, create SubmittedFile
- [ ] Link to Publication
- [ ] Use file's version from Collection
- [ ] Create submission metadata

#### 8.4 Handle Version Changes
- [ ] If Collection version changes after selection, handle gracefully
- [ ] Use version at submission time (not creation time)
- [ ] Document behavior for user

#### 8.5 Feedback
- [ ] Show submission success
- [ ] Display submitted files count
- [ ] Show Publication reference

#### 8.6 Tests
- [ ] Submit empty Collection (should reject)
- [ ] Submit Collection with single file
- [ ] Submit Collection with multiple files
- [ ] Verify submitted files appear in Publication
- [ ] Verify correct versions submitted
- [ ] Submit same Collection to different Publications

---

## Cross-Phase Considerations

### Error Handling
- Invalid Collection names
- Duplicate files
- Deleted files while Collection exists
- Concurrent modifications
- Storage/persistence issues

### Performance
- Loading Collections list with many items
- Displaying Collections with many files
- Querying Submissions efficiently

### Data Integrity
- Ensure Submissions reference valid files
- Handle file deletion (Collection reference invalidates)
- Version consistency

### Localization
- All UI strings must be localized
- Button labels, dialogs, error messages
- Add to Localizable.strings

---

## Dependencies Between Phases

```
Phase 1 ─── Phase 2 ─┬─── Phase 3
                     └─── Phase 4 ─── Phase 5 ─── Phase 6
                                           │
                                           └─── Phase 7
                                           
Phase 8 (depends on all others for submission)
```

- Phase 1 must complete before others
- Phase 2 depends on Phase 1
- Phase 3 somewhat independent but better after Phase 2
- Phase 4-5 can proceed in parallel with Phase 2-3
- Phase 6 depends on Phase 5
- Phase 7 independent, good for review
- Phase 8 depends on Phases 1-7 and existing Publication system

---

## Summary

- **Total Tasks**: ~80 individual tasks
- **Phases**: 8 sequential phases
- **Key Deliverables**: Collections folder, UI views, Submission integration
- **Testing**: Unit and integration tests at each phase
- **Success Criteria**: All acceptance criteria from spec met
