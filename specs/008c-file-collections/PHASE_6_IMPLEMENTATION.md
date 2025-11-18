# Phase 6: Submit Collection to Publication - Implementation Guide

**Status**: Planned for future implementation  
**Date**: 11 November 2025  
**Estimated Effort**: 1-2 sessions

## Overview

Phase 6 integrates Collections (Feature 008c) with the Publication submission system (Feature 008b). This allows users to submit entire Collections to Publications while preserving version selections.

## Architecture

### Current Flow (Publications Only)
1. User selects files from Ready folder
2. User chooses "Submit" action
3. SubmissionPickerView shows available Publications
4. System creates Submission with selected files

### Desired Flow (with Collections)
1. User can submit from:
   - Ready folder (existing) → files directly
   - Collections folder (new) → Collection and its files
2. SubmissionPickerView shows available Publications
3. System creates Publication Submission (new model) with Collection data
4. Versions from Collection are preserved in Publication Submission

## Key Design Decisions

### 1. Submission Model Enhancement
- Submissions already differentiate via `publication` field:
  - If `publication == nil` → It's a Collection
  - If `publication != nil` → It's a Publication Submission
- No new models needed - leverage existing architecture

### 2. Version Preservation
- When submitting Collection to Publication:
  - Copy each SubmittedFile from Collection
  - Preserve its version reference
  - Create new Submission with publication set
  - Result: Publication Submission is independent of Collection

### 3. File Source Options
Two submission sources for SubmissionPickerView:
- **Direct Files**: Selected files from Ready folder (existing)
- **Collection**: Entire Collection with its files (new)

## Implementation Steps

### Step 1: Add "Submit Collection" Action
**Location**: CollectionDetailView  
**Changes**:
- Add toolbar button "Submit Collection"
- Navigate to modified SubmissionPickerView (or new CollectionSubmissionFlow)
- Pass Collection reference instead of TextFile array

**Code Pattern**:
```swift
ToolbarItem(placement: .navigationBarTrailing) {
    Menu {
        Button("Add files") {
            showAddFilesSheet = true
        }
        Button("Submit to Publication") {
            showSubmissionPicker = true
        }
    } label: {
        Image(systemName: "ellipsis.circle")
    }
}
```

### Step 2: Modify SubmissionPickerView
**Option A: Make it flexible**
- Accept either `filesToSubmit: [TextFile]?` or `collectionToSubmit: Submission?`
- Show different descriptions based on submission source
- On publication selection, create appropriate Submission

**Option B: Create CollectionSubmissionView**
- New view specifically for submitting Collections
- Similar structure to SubmissionPickerView
- Takes Collection, shows Publications
- Creates Publication Submission from Collection

**Recommendation**: Option A (minimal duplication)

### Step 3: Create Submission from Collection
**When Publication Selected**:
```swift
private func createSubmissionFromCollection(_ collection: Submission, to publication: Publication) {
    // Create new Submission as Publication Submission
    let pubSubmission = Submission(
        publication: publication,
        project: collection.project
    )
    
    // Copy SubmittedFiles from Collection
    let copiedFiles = (collection.submittedFiles ?? []).map { original in
        SubmittedFile(
            submission: pubSubmission,
            textFile: original.textFile,
            version: original.version,  // Preserve version!
            status: original.status
        )
    }
    
    pubSubmission.submittedFiles = copiedFiles
    
    // Save
    modelContext.insert(pubSubmission)
    try? modelContext.save()
}
```

### Step 4: Update Publication Submission Tracking
**Considerations**:
- Publication Submission should link back to source Collection (optional)
- OR: Just track it as independent Publication Submission
- Simpler: Don't track source Collection, treat as independent

**Recommendation**: Independent submissions (simpler, less coupling)

## UI Flow

### Submission from Collection
```
CollectionDetailView
  ↓
"Submit to Publication" button
  ↓
SubmissionPickerView (modified)
  • Shows: "Submit Collection: [Name]"
  • Shows available Publications
  ↓
User selects Publication
  ↓
System creates Publication Submission
  • Preserves versions from Collection
  • Links files to Publication
  ↓
Return to Collection
  (optional message: "Submitted to [Publication]")
```

## Testing Requirements

### Unit Tests
- [ ] `testSubmitCollectionToPublication()`
- [ ] `testVersionsPreservedInSubmission()`
- [ ] `testPublicationSubmissionCreatedWithCollectionFiles()`
- [ ] `testMultipleSubmissionsFromSameCollection()`
- [ ] `testModifyCollectionAfterSubmission()`

### Integration Tests
- [ ] Submit Collection, verify Publication Submission created
- [ ] Change Collection versions, submit again
- [ ] Submit same Collection to multiple Publications
- [ ] Delete Collection after submission (verify Publication unaffected)

### UI Tests
- [ ] "Submit Collection" button appears in CollectionDetailView
- [ ] Navigation to SubmissionPickerView works
- [ ] Can select Publication
- [ ] Confirmation message after submission
- [ ] Back navigation

## Known Issues & Edge Cases

1. **Collection Modified After Submission**
   - Collection and Publication Submission are independent
   - Changes to Collection don't affect previous submissions
   - This is desired behavior ✓

2. **Delete Collection With Pending Submissions**
   - Publication Submissions reference Collection's files/versions
   - But Collection itself is separate object
   - Deleting Collection is OK, submissions still work
   - Files stay in Ready folder

3. **File Deleted From Ready**
   - Collection references specific file/version
   - If file deleted, Collection becomes "broken"
   - Solution: Check file exists when displaying Collection

4. **Locked Versions**
   - Locked files can still be in Collections
   - Version locks are preserved in Publication Submission
   - Desired behavior ✓

## Success Criteria

✅ Users can submit Collections to Publications  
✅ Collection versions preserved in Publication Submissions  
✅ Collections remain independent after submission  
✅ Collection modifications don't affect submitted versions  
✅ Can submit same Collection to multiple Publications  
✅ All file/version combinations work correctly  
✅ Proper error handling for edge cases  
✅ Comprehensive test coverage  

## Recommended Next Session

1. Implement "Submit Collection" button in CollectionDetailView
2. Modify SubmissionPickerView to accept Collections
3. Implement createSubmissionFromCollection logic
4. Test full workflow (create collection → submit)
5. Add unit/integration tests
6. Handle edge cases

**Estimated Time**: 1-2 hours
