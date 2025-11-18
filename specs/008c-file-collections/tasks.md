# File Collections - Implementation Tasks

**Status**: Ready for Development  
**Created**: 11 November 2025

## Quick Reference

- **Total Tasks**: ~80
- **Total Phases**: 8
- **Recommended Start**: Phase 1
- **Critical Path**: Phase 1 → Phase 2 → Phase 4 → Phase 5 → Phase 8

---

## Phase 1: Create Collections System Folder

### 1.1 Update Folder Model
- [ ] Add `folderType` enum property (system vs user)
- [ ] Or add `isSystemFolder` boolean flag
- [ ] Or add `specialType` property (ready, setAside, collections, none)
- [ ] Update documentation

### 1.2 Update Project Template
- [ ] Modify project initialization for Poetry projects
- [ ] Add Collections folder to template
- [ ] Position between Ready and Set Aside
- [ ] Repeat for Short Story projects
- [ ] Skip for Novel, Script, Blank projects

### 1.3 Folder Display
- [ ] Update ProjectBrowserView to handle Collections folder
- [ ] Ensure correct ordering in folder list
- [ ] Show Collections folder type consistently
- [ ] Handle styling/icons if needed

### 1.4 Restrict Collection Folder
- [ ] Prevent file drag-drop into Collections folder
- [ ] Disable "New File" option in Collections folder
- [ ] Disable file import into Collections folder
- [ ] Allow only Submissions/Collections

### 1.5 Tests
- [ ] `testCollectionsFolderCreatedInPoetryProject()`
- [ ] `testCollectionsFolderCreatedInShortStoryProject()`
- [ ] `testCollectionsFolderNotCreatedInNovelProject()`
- [ ] `testCollectionsFolderPositionBetweenReadyAndSetAside()`
- [ ] `testCollectionsFolderReadOnly()`

---

## Phase 2: Collections Folder UI

### 2.1 Collections List View
- [ ] Create `CollectionsView` SwiftUI view
- [ ] Display list of Collections folders
- [ ] Show Collection name
- [ ] Show file count (count of Submissions)
- [ ] Show creation date
- [ ] Show last modified date
- [ ] Handle empty state

### 2.2 Create Button
- [ ] Add "Create Collection" button
- [ ] Position at top of Collections list
- [ ] Style consistently with app
- [ ] Links to Phase 3 dialog

### 2.3 Collection Selection
- [ ] Tap Collection to view contents
- [ ] Navigate to Collection contents view
- [ ] Show files with versions
- [ ] Back button to Collections list
- [ ] Preserve selection state

### 2.4 Tests
- [ ] `testCollectionsListDisplaysEmpty()`
- [ ] `testCollectionsListDisplaysMultipleCollections()`
- [ ] `testTapCollectionOpensContents()`
- [ ] `testNavigationBackWorks()`

---

## Phase 3: Create New Collection

### 3.1 Dialog/Form
- [ ] Build `CreateCollectionDialog` view
- [ ] Text input for name
- [ ] Cancel button (dismiss)
- [ ] Create button (submit)
- [ ] Clear placeholder text

### 3.2 Validation
- [ ] `validateCollectionName(_ name: String) -> Bool`
- [ ] Check not empty
- [ ] Check unique in Collections folder
- [ ] Check no invalid filesystem characters
- [ ] Return error message

### 3.3 Folder Creation
- [ ] Create Folder with name
- [ ] Set to Collections directory
- [ ] Mark as Collection type
- [ ] Set project reference
- [ ] Initialize empty submissions array

### 3.4 Feedback
- [ ] Show success message
- [ ] Refresh Collections list
- [ ] New Collection visible immediately
- [ ] Handle errors gracefully

### 3.5 Tests
- [ ] `testCreateCollectionWithValidName()`
- [ ] `testRejectDuplicateCollectionName()`
- [ ] `testRejectEmptyCollectionName()`
- [ ] `testRejectInvalidCharacters()`
- [ ] `testFolderCreatedCorrectly()`

---

## Phase 4: Multi-Select in Ready Folder

### 4.1 Select Mode
- [ ] Add select mode toggle to Ready folder view
- [ ] Show checkboxes when in select mode
- [ ] Highlight selected items
- [ ] Show "X files selected" counter

### 4.2 Selection
- [ ] Implement checkbox tap to toggle selection
- [ ] "Select All" option
- [ ] "Deselect All" option
- [ ] Exit select mode clears selection

### 4.3 Bulk Action Button
- [ ] Show "Add to Collection..." button
- [ ] Only enabled when files selected
- [ ] Tap opens Phase 5 (Collection selection)
- [ ] Pass selected files to next screen

### 4.4 Tests
- [ ] `testEnterSelectMode()`
- [ ] `testSelectIndividualFile()`
- [ ] `testSelectAllFiles()`
- [ ] `testCounterUpdates()`
- [ ] `testButtonStateChanges()`

---

## Phase 5: Add Files to Collection

### 5.1 Collection Picker
- [ ] Display list of existing Collections
- [ ] Show "Create New Collection" option
- [ ] User taps to select target Collection
- [ ] Or creates new Collection

### 5.2 Version Selection
- [ ] Show selected files
- [ ] For each file, show available versions
- [ ] Default to "Current" (selected/worked-on version)
- [ ] Allow version selection per file
- [ ] Show version number and date for each

### 5.3 Create Submissions
- [ ] For each file, create Submission record
- [ ] Link Submission to Collection folder
- [ ] Store selected Version reference
- [ ] Handle duplicate additions (strategy: ask user)

### 5.4 Feedback
- [ ] Show "X files added to Collection" message
- [ ] Return to Ready folder
- [ ] Exit select mode
- [ ] Show confirmation

### 5.5 Tests
- [ ] `testAddSingleFileToCollection()`
- [ ] `testAddMultipleFilesToCollection()`
- [ ] `testSelectSpecificVersion()`
- [ ] `testAddToExistingCollection()`
- [ ] `testHandleDuplicateAddition()`

---

## Phase 6: Edit Collection Contents

### 6.1 Edit View
- [ ] Create `EditCollectionView`
- [ ] Display Collection name
- [ ] List all files in Collection
- [ ] Show current version for each
- [ ] Show edit/delete buttons

### 6.2 Change Version
- [ ] Tap file to open version picker
- [ ] Show all available versions
- [ ] User selects new version
- [ ] Update Submission.version reference
- [ ] Save automatically

### 6.3 Add More Files
- [ ] "Add Files..." button in Collection view
- [ ] Reuse multi-select from Phase 4
- [ ] Add to existing Collection (don't create new)
- [ ] Prevent adding duplicate files

### 6.4 Remove Files
- [ ] Swipe-to-delete on file
- [ ] Or delete button
- [ ] Confirm deletion
- [ ] Remove Submission from Collection

### 6.5 Delete Collection
- [ ] Option to delete entire Collection
- [ ] Warn if has pending Publication submissions
- [ ] Confirm deletion
- [ ] Remove folder from Collections

### 6.6 Tests
- [ ] `testChangeFileVersion()`
- [ ] `testAddMoreFiles()`
- [ ] `testRemoveFileFromCollection()`
- [ ] `testDeleteCollection()`
- [ ] `testWarnOnDeleteWithSubmissions()`

---

## Phase 7: View Collection Files

### 7.1 Contents View
- [ ] Create `CollectionContentsView`
- [ ] List all files in Collection
- [ ] Show filename and version number
- [ ] Optional: word count per file
- [ ] Tap to preview file (optional)

### 7.2 Metadata
- [ ] Show Collection name as header
- [ ] Show creation date
- [ ] Show last modified date
- [ ] Show total file count
- [ ] Show total word count (if available)

### 7.3 Navigation
- [ ] Back button to Collections list
- [ ] Edit button to Phase 6
- [ ] Clean state management

### 7.4 Tests
- [ ] `testDisplayEmptyCollection()`
- [ ] `testDisplaySingleFile()`
- [ ] `testDisplayMultipleFiles()`
- [ ] `testShowCorrectVersions()`
- [ ] `testMetadataDisplaysCorrectly()`

---

## Phase 8: Submit Collection to Publication

### 8.1 Publication Form
- [ ] Update `PublicationFormView` or submission flow
- [ ] Add Collections as source option
- [ ] Show alongside "Create New Submission"
- [ ] Dropdown/picker for available Collections

### 8.2 Select Collection
- [ ] User selects Collection to submit
- [ ] Preview files and versions
- [ ] Confirm before submission

### 8.3 Create Submissions
- [ ] For each file in Collection, create SubmittedFile
- [ ] Link to Publication
- [ ] Use Collection's version reference
- [ ] Create proper Submission records

### 8.4 Version Handling
- [ ] Document behavior if Collection changes after selection
- [ ] Use version at submission time
- [ ] Handle edge cases

### 8.5 Feedback
- [ ] Show submission success
- [ ] Display file count submitted
- [ ] Show Publication reference
- [ ] Return to appropriate view

### 8.6 Tests
- [ ] `testSubmitEmptyCollection()` - should reject
- [ ] `testSubmitSingleFileCollection()`
- [ ] `testSubmitMultiFileCollection()`
- [ ] `testSubmittedFilesAppearInPublication()`
- [ ] `testCorrectVersionsSubmitted()`
- [ ] `testSubmitSameCollectionToDifferentPublications()`

---

## Cross-Phase Tasks

### Error Handling
- [ ] Handle invalid Collection names
- [ ] Handle duplicate files
- [ ] Handle deleted files reference
- [ ] Handle concurrent modifications
- [ ] Handle storage/persistence errors
- [ ] Show user-friendly error messages

### Localization
- [ ] "Create Collection" button
- [ ] "Add to Collection..." action
- [ ] Collection dialog title/messages
- [ ] Version selector labels
- [ ] Error messages
- [ ] Empty states
- [ ] Accessibility labels
- [ ] Add all strings to Localizable.strings

### Accessibility
- [ ] Collections view has accessibility labels
- [ ] Checkboxes in select mode accessible
- [ ] Buttons have accessibility hints
- [ ] Version picker accessible
- [ ] Test with VoiceOver

### Testing Summary
- [ ] Unit tests: ~35 tests covering all logic
- [ ] Integration tests: ~15 tests covering workflows
- [ ] Edge case tests: ~10 tests for robustness
- [ ] Total: ~60 tests

---

## Implementation Checklist

### Before Starting
- [ ] Review spec.md thoroughly
- [ ] Understand Feature 008b (Publications) implementation
- [ ] Understand Feature 008a (File Movement) implementation
- [ ] Set up test environment
- [ ] Create feature branch

### During Development
- [ ] Commit frequently with clear messages
- [ ] Write tests as you go
- [ ] Follow localization guidelines
- [ ] Keep accessibility in mind
- [ ] Update documentation

### After Each Phase
- [ ] Run all tests
- [ ] Manual testing on device/simulator
- [ ] Verify edge cases
- [ ] Code review

### Final Review
- [ ] All 60+ tests passing
- [ ] All acceptance criteria met
- [ ] No hard-coded strings (localized)
- [ ] Accessibility verified
- [ ] Documentation complete
- [ ] Code quality reviewed

---

## Success Criteria

✅ User can create Collections in Poetry/Short Story projects only  
✅ User can add multiple files to Collections with version selection  
✅ User can modify Collection contents and change versions  
✅ Collections appear as submission source in Publications  
✅ Collections can be submitted to Publications  
✅ All localized strings  
✅ Accessible UI  
✅ 60+ tests passing  
✅ Edge cases handled gracefully
