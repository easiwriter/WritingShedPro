# File Collections - Phase 4+ Implementation Plan

**Current Status**: Phases 1-3 Complete ✅  
**Date**: 11 November 2025

## Completed Work (Phases 1-3)

### Phase 1: Collections System Folder ✅
- Collections folder positioned between Ready and Set Aside
- Marked as read-only system folder
- Proper folder capability handling

### Phase 2: Collections UI ✅
- CollectionsView displays list of Collections (Submissions where publication=nil)
- Shows Collection count (number of files in collection)
- Navigation between Collections list and detail view

### Phase 3: Collection Details & File Management ✅
- CollectionDetailView displays SubmittedFiles in Collection
- AddFilesToCollectionSheet with file picker from Ready folder
- Version selection UI for each file being added
- Empty state handling
- 20+ comprehensive unit tests

---

## Remaining Work (Phases 4-6)

### Phase 4: Edit Collection Contents

**Objective**: Allow users to modify existing Collections

#### 4.1 Edit Versions in Existing Collection
- [ ] Add "Edit" mode to CollectionDetailView
- [ ] Show version selector for each SubmittedFile
- [ ] Allow changing version reference (without modifying original file)
- [ ] Save version changes to database
- [ ] Show current version vs available versions

**Implementation Details**:
- Add state to track editing mode
- Create VersionPickerSheet for editing existing files
- Update SubmittedFile.version when user selects new version
- Preserve other SubmittedFile properties (status, notes)

**Tests**:
- testChangeVersionForExistingFile()
- testChangeMultipleVersionsInCollection()
- testVersionChangePreservesOtherMetadata()
- testEditModeToggle()

#### 4.2 Remove Files from Collection
- [ ] Add delete capability for SubmittedFiles in Collection
- [ ] Swipe-to-delete or delete button
- [ ] Confirmation dialog
- [ ] Remove SubmittedFile from submission.submittedFiles

**Tests**:
- testDeleteSingleFileFromCollection()
- testDeleteMultipleFilesSequentially()
- testDeleteConfirmationDialog()

#### 4.3 Rename Collection
- [ ] Edit collection name (Submission doesn't have name field currently)
- [ ] OR: Add name field to Submission model for collections
- [ ] Update after saving

**Decision**: Need to add optional `name` field to Submission model for collections

#### 4.4 Delete Entire Collection
- [ ] Delete collection button (trash icon)
- [ ] Confirmation dialog
- [ ] Cascade delete SubmittedFiles
- [ ] Return to Collections list

**Tests**:
- testDeleteCollection()
- testDeleteCollectionWithFiles()
- testNavigationAfterDelete()

---

### Phase 5: Collection Naming & Metadata

**Objective**: Add collection names and metadata tracking

#### 5.1 Update Submission Model
- [ ] Add optional `name: String?` field to Submission
- [ ] Add optional `description: String?` field
- [ ] Migration for existing submissions

#### 5.2 Collection Creation with Name
- [ ] Update AddCollectionSheet to capture name
- [ ] Store name in Submission.name when creating
- [ ] Display name in CollectionsView row

#### 5.3 Collection Editing
- [ ] Edit collection name/description
- [ ] Show in CollectionDetailView header
- [ ] Update via sheet/modal

**Tests**:
- testCreateCollectionWithName()
- testUpdateCollectionName()
- testCollectionNameDisplayed()

---

### Phase 6: Submit Collection to Publication

**Objective**: Allow submitting Collections to Publications

#### 6.1 Integration with Publication System
- [ ] Update SubmissionPickerView to show Collections as option
- [ ] Show Collections in "Select submission source" flow
- [ ] When Collection selected, show its SubmittedFiles

#### 6.2 Create Publication Submission from Collection
- [ ] When user selects Collection for publication
- [ ] Create new Publication Submission (with publication attached)
- [ ] Copy SubmittedFiles from Collection to Publication Submission
- [ ] Each SubmittedFile maintains its version reference

#### 6.3 Version Preservation
- [ ] Version selections from Collection are preserved in Publication Submission
- [ ] If Collection updated after submission, Publication Submission unchanged
- [ ] Collections and Publication Submissions are independent

#### 6.4 UI Flow
- [ ] Show Collections in Publication submission workflow
- [ ] Display Collection name and file list before confirming
- [ ] Confirm submission creates Publication Submission
- [ ] Return to collection after successful submission

**Tests**:
- testSubmitCollectionToPublication()
- testCollectionVersionsPreservedInSubmission()
- testMultipleSubmissionsFromSameCollection()
- testUpdateCollectionAfterSubmission()

---

## Implementation Priority

**High Priority (affects user workflow)**:
1. Phase 4.1: Edit versions in Collection
2. Phase 4.2: Remove files from Collection
3. Phase 6: Submit Collection to Publication

**Medium Priority (nice to have)**:
1. Phase 4.3: Rename Collection
2. Phase 4.4: Delete Collection
3. Phase 5: Collection metadata

---

## Testing Strategy

### Unit Tests (25+)
- Submission model updates (name, description)
- SubmittedFile version editing
- Collection querying and filtering
- Cascade delete behavior

### Integration Tests (15+)
- Create -> Edit -> Submit workflow
- Multiple collections with same files
- Version tracking across submission
- Deletion cascades

### UI Tests
- Version picker usability
- Edit mode toggle
- Delete confirmation dialogs
- Navigation after operations

---

## Known Issues & Considerations

1. **Submission Model**: Need to add `name` and `description` fields for Collections
2. **Version Locking**: Verify locked files can still be used in Collections
3. **File Deletion**: What happens if file in Ready is deleted while in Collection?
4. **Collection Copying**: Should user be able to duplicate a Collection?
5. **Batch Operations**: Should support multi-select in Collection for bulk updates?

---

## Success Criteria for Phase 4-6

✅ Users can edit version references for files in Collections  
✅ Users can remove files from Collections  
✅ Users can delete entire Collections  
✅ Users can name/rename Collections  
✅ Users can submit Collections to Publications  
✅ Collection versions preserved in Publication Submissions  
✅ All operations properly persisted to database  
✅ Comprehensive test coverage (50+ tests total)  

---

## Recommended Next Steps

1. **Start with Phase 4.1**: Edit version selection is core functionality
2. **Then Phase 4.2**: File removal capability
3. **Then Phase 6**: Publication integration (high user value)
4. **Finally Phase 5**: Naming/metadata (polish feature)

Estimated total effort: 3-4 development sessions
