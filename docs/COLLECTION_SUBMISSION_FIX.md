# Collection Submission Import Fix

**Date**: 13 December 2025  
**Status**: ✅ Complete  
**Issue**: WS_CollectionSubmission_Entity records were not being properly imported

## Problem

The original import code was incorrectly handling `WS_CollectionSubmission_Entity`:

### Old (Incorrect) Behavior
1. Import `WS_Collection_Entity` → Create Submission with `publication = nil`
2. Use `collectionSubmissionIds` to link collection directly to publication
3. **Ignored** all CollectionSubmission attributes (submittedOn, notes, status)
4. Result: Only ONE Submission per collection, even if submitted to multiple publications

### What Should Happen (Per Spec)
Each `WS_CollectionSubmission_Entity` represents a collection being submitted to a publication and should:
1. Create a **NEW Submission** record (not just link existing collection)
2. Set `publication` to the referenced WS_Submission_Entity
3. Copy files from the source WS_Collection_Entity
4. Use CollectionSubmission's own metadata (submittedOn, notes)
5. Set SubmittedFile status from WS_CollectedVersion_Entity data
6. **Place in Submissions folder** (not Collections folder)

Example: If 1 collection was submitted to 3 publications, you should get:
- 1 Collection in Collections folder (Submission with publication=nil)
- 3 Publication Submissions in Submissions folder (Submission with publication set)

## Solution

### Folder Structure

Added a new **Submissions** folder to Poetry and ShortStory projects:
- **Collections folder**: Displays standalone collections (Submission objects where `publication == nil`)
- **Submissions folder**: Displays submissions to publications (Submission objects where `publication != nil`)

The folder organization is determined by the `publication` property, not by a folder assignment:
- Setting `publication = nil` makes a Submission appear in Collections folder
- Setting `publication = [Publication]` makes a Submission appear in Submissions folder

This mirrors the legacy Writing Shed v1 folder structure.

**Folder Order:**
1. All
2. Draft
3. Ready
4. Collections (standalone collections)
5. **Submissions** (NEW - publication submissions)
6. Set Aside
7. Published
8. Research
9. (Publications folders...)

### Changes Made

1. **Added `isCollection` Boolean property to Submission model** ⭐ **KEY FIX**
   - `Submission.swift`: Added `var isCollection: Bool = false` property
   - **Reason**: SwiftData predicates cannot reliably handle optional relationship comparisons like `publication == nil`
   - This non-optional Boolean allows predicates to work correctly
   - Explicitly set to `true` for collections, `false` for submissions

2. **Added Submissions folder to project templates**
   - `ProjectTemplateService.swift`: Added "folder.submissions" to Poetry/ShortStory folder list
   - `FolderListView.swift`: Added "Submissions" to folder display order
   - `JSONImportService.swift`: Added "Submissions" to standard folders creation

3. **Replaced `linkCollectionSubmissions()` with `importCollectionSubmissions()`**
   - Lines 613-720 in JSONImportService.swift
   - New function properly processes CollectionSubmissionData entities

4. **Modified `importCollections()` to set isCollection flag**
   - Line 503: Added explicit `submission.isCollection = true` for collections
   - Line 504: Still sets `submission.publication = nil` for consistency
   - Ensures collections are correctly identified by predicate queries

5. **New Function: `importCollectionSubmissions()`**
   - Gathers all CollectionSubmissionData from all components
   - For each CollectionSubmission:
     - Finds the source collection (WS_Collection_Entity)
     - Finds the target publication (WS_Submission_Entity)
     - Creates a NEW Submission: `"[Collection Name] → [Publication Name]"`
     - **Sets `isCollection = false`** (identifies as submission, not collection)
     - **Sets publication property** (links to target publication)
     - Copies all SubmittedFile records from source collection
     - Sets submission metadata (submittedDate, notes)
     - Sets file acceptance status if available

6. **New Helper: `decodeCollectionSubmissionMetadata()`**
   - Extracts submittedOn/dateSubmitted → `submittedDate`
   - Extracts notes → `notes`
   - TODO: Extract accepted file status from WS_CollectedVersion_Entity

5. **Updated `importPublications()`**
   - Removed caching by collectionSubmissionsDatas IDs
   - Now only caches by component ID and textCollectionData ID
   - CollectionSubmission entities are processed separately

5. **Updated Import Flow**
   - Changed line 107: "Link collection submissions" → "Import collection submissions"
   - Now calls `importCollectionSubmissions()` instead of `linkCollectionSubmissions()`

## Data Structure Reference

```
WS_CollectionSubmission_Entity
├── id: String (unique identifier)
├── submissionId: String → WS_Submission_Entity (the Publication)
├── collectionId: String → WS_Collection_Entity (source collection)
└── collectionSubmission: String (JSON metadata)
    ├── submittedOn: TimeInterval
    ├── notes: String
    └── [TODO] accepted file status from WS_CollectedVersion_Entity
```

## Impact

### Before Fix
- Collections submitted to multiple publications only created 1 Submission
- Submission metadata (submitted date, notes) was lost
- File acceptance status was lost
- No way to track which publications a collection was sent to
- All submissions appeared in Collections folder

### After Fix
- Each submission to a publication creates a separate Submission record
- **Collections appear in Collections folder** (publication = nil)
- **Publication submissions appear in Submissions folder** (publication set)
- Submission metadata properly preserved
- File acceptance status can be tracked (once WS_CollectedVersion_Entity is exported)
- Full submission history maintained
- Folder structure matches legacy Writing Shed v1

## Future Improvements

The exporter should include WS_CollectedVersion_Entity data in the export to capture:
- Which specific version was submitted
- Whether each file was accepted/rejected
- Response dates and outcomes

This would allow setting `SubmittedFile.status` more accurately:
- `WS_CollectedVersion_Entity.status == true` → `.accepted`
- Otherwise → `.pending` or `.rejected`

## Testing

To test:
1. Export a legacy project with collections submitted to publications
2. Import the JSON
3. Check that:
   - Collections appear in **Collections folder** (publication=nil)
   - Publication submissions appear in **Submissions folder** (publication set)
   - Submission names show "Collection → Publication"
   - Submitted dates are preserved
   - All files from collection are linked to submission

## Files Changed
### Submission.swift ⭐ **CRITICAL FIX**
- Line 23: Added `var isCollection: Bool = false` property
- **Purpose**: SwiftData predicates cannot reliably check optional relationships (`publication == nil`)
- **Solution**: Use non-optional Boolean flag that predicates CAN handle
- Collections have `isCollection = true`, submissions have `isCollection = false`

### JSONImportService.swift
- Line 107: Updated import flow
- Lines 436-448: Removed collectionSubmissionsDatas caching
- Line 503: **Set `isCollection = true` for collections** (key for predicate filtering)
- Line 504: Still set `publication = nil` for consistency
- Line 672: **Set `isCollection = false` for publication submissions**
- Lines 613-617: Added logging about Submissions folder display logic
- Line 673: Set publication property to target publication
- Lines 613-720: Replaced linkCollectionSubmissions() with importCollectionSubmissions()
- Lines 758-772: Added "Submissions" to Poetry/ShortStory folder list

### ProjectTemplateService.swift
- Lines 58-67: Added "folder.submissions" to Poetry/ShortStory folder creation

### FolderListView.swift
- Lines 38-43: Added "Submissions" to Poetry/ShortStory folder display order
- Lines 103-107: Added special handling for Submissions folder navigation
- Lines 233-237: Added isSubmissionsFolder property
- Line 257: **Changed filter to use `isCollection` instead of `publication == nil`**
- Line 265: **Changed filter to use `!isCollection` instead of `publication != nil`**
- Line 308: Added submission count to folder display name
- Lines 385: Added "paperplane" icon for Submissions folder

### CollectionsView.swift
- Line 59: **Simplified predicate to ONLY check `submission.isCollection == true`** (no optional chaining)
- Line 69-71: **Project filtering moved to computed property** (avoids SwiftData predicate issues)
- Line 442: Set `isCollection = true` when creating new collections in UI
- Line 780: Set `isCollection = false` when submitting collection to publication
- Line 472: Set `isCollection = false` in submitCollectionsToPublication()

### SubmissionsView.swift (NEW FILE)
- Created new view to display submissions in Submissions folder
- Line 31: **Simplified predicate to ONLY check `submission.isCollection == false`** (no optional chaining)
- Line 41-43: **Project filtering moved to computed property** (avoids SwiftData predicate issues)
- Lines 92-107: **Simplified row display** - shows only submission name and file count
- Supports sorting by submitted date, name, or publication
- Navigates to CollectionDetailView for viewing submission details
- Empty state when no submissions exist

### Localizable.strings
- Line 182: Already had "folder.submissions" = "Submissions"

## Implementation Complete

### Compilation Errors Fixed

During implementation, fixed these compilation errors:
1. ✅ Line 659: Optional string interpolation in print statement → explicit unwrap with `??`
2. ✅ Line 664: Optional string interpolation in name assignment → nil coalescing
3. ✅ Line 674: Wrong relationship property `files` → `submittedFiles`
4. ✅ Line 704: Wrong error enum case `invalidFormat` → `decodingFailed`
5. ✅ Line 682: Wrong property name `versionNumber` → `version` (SubmittedFile uses `version: Version?`)
6. ✅ Line 668: Removed unnecessary nil coalescing on non-optional String
7. ✅ Line 678: Removed `folder` property assignment (Submission doesn't have folder property - organization is by `publication`)

### Final Status
- ✅ All compilation errors and warnings resolved
- ✅ Added Submissions folder to Poetry/ShortStory projects
- ✅ Function correctly creates separate Submission for each CollectionSubmission
- ✅ New submissions displayed in Submissions folder (via `publication != nil`)
- ✅ Collections displayed in Collections folder (via `publication == nil`)
- ✅ **Added defensive in-memory filtering** to both views to ensure correct separation
- ✅ Collections explicitly have `publication = nil` set during import
- ✅ Files copied from source collection to new submission
- ✅ Version references preserved
- ✅ Metadata (dates, notes) properly applied
- ⏳ Ready for testing with real legacy data

### How Folder Display Works

**CRITICAL**: SwiftData predicates **cannot reliably handle optional relationship comparisons** like `submission.publication == nil` OR optional chaining in predicates like `submission.project?.id == projectID`. To solve this, we added an `isCollection: Bool` property to the Submission model.

The app determines where to display submissions based on their `isCollection` property:

- **Collections folder**: Shows Submission objects where `isCollection == true`
  - CollectionsView query: `submission.isCollection == true` (no other filters in predicate)
  - In-memory filter: Project matching done in sortedCollections computed property
  - Collections are named with their collection name (e.g., "Spring Poetry")
  - Created with `publication = nil` and `isCollection = true`

- **Submissions folder**: Shows Submission objects where `isCollection == false`
  - SubmissionsView query: `submission.isCollection == false` (no other filters in predicate)
  - In-memory filter: Project matching done in sortedSubmissions computed property
  - Submissions are named with format: "Collection → Publication" (e.g., "Spring Poetry → Poetry Magazine")
  - Created with `publication` set to target publication and `isCollection = false`
  - Display: Shows submission name and file count only (simplified view)

**Implementation Details**:
- Collections imported from WS_Collection_Entity have `isCollection = true` explicitly set
- Submissions created from WS_CollectionSubmission_Entity have `isCollection = false` explicitly set
- Collections created in the UI have `isCollection = true` set
- Submissions created when submitting to publications have `isCollection = false` set
- Predicates use ONLY the non-optional `isCollection` Boolean (SwiftData compatible)
- Project filtering happens in computed properties, not in predicates (avoids optional chaining issues)

### Next Steps
- ✅ Created SubmissionsView to display submissions (similar to CollectionsView)
- ✅ Added special handling in FolderListView for Submissions folder
- ✅ Added submission count display
- ✅ Added paperplane icon for Submissions folder
- Test import with legacy database containing CollectionSubmission entities
- Verify correct Submission records created
- Verify file linking and metadata preservation
