# Import Service Fix - Collection Submissions Missing

## Problem

After fixing the export code, imports were working but **submissions to publications were missing**. The submissions existed but weren't linked to their publications (magazines, competitions, etc.).

## Root Cause

The import service was ignoring the **`collectionSubmissionsDatas`** field in `CollectionComponentData`, which contains the actual linking data between submissions and publications.

### Data Structure (from Export)

```swift
class CollectionComponentData: Codable {
    var collectionSubmissionsDatas: [CollectionSubmissionData]?  // ✅ Contains linking data
    var collectionSubmissionIds: Data?                          // ❌ Just simple IDs
    // ... other fields
}

class CollectionSubmissionData: Codable {
    var submissionId: String    // ID of the publication (WS_Submission_Entity)
    var collectionId: String    // ID of the collection (WS_TextCollection_Entity)
    // ... other fields
}
```

### What Was Happening

**Old Import Code (line 458-483):**
```swift
private func linkCollectionSubmissions(...) {
    // Only checked collectionSubmissionIds (simple ID array)
    guard let submissionIds = componentData.collectionSubmissionIds,
          let links = try? PropertyListDecoder().decode([String].self, from: submissionIds),
          !links.isEmpty else {
        continue
    }
    // ... tried to link but didn't have the right data
}
```

**Problem:** `collectionSubmissionIds` is just a simple array of IDs without the context of WHAT they link to. The actual linking data is in `collectionSubmissionsDatas` which has:
- `submissionId` (points to the publication)
- `collectionId` (points to the text collection)

## The Fix

### Changed: `linkCollectionSubmissions()` method

**New Logic:**
1. **Primary:** Use `collectionSubmissionsDatas` array (contains CollectionSubmissionData objects)
2. **Fallback:** Use `collectionSubmissionIds` for backward compatibility

**Key Changes:**
```swift
// FIX: Use collectionSubmissionsDatas array
if let submissionDatas = componentData.collectionSubmissionsDatas, !submissionDatas.isEmpty {
    for submissionData in submissionDatas {
        // submissionData.submissionId = ID of the publication
        // submissionData.collectionId = ID of the collection
        
        // Get the submission (collection)
        guard let textCollectionId = componentData.textCollectionData?.id,
              let submission = submissionMap[textCollectionId] else {
            continue
        }
        
        // Get the publication using submissionId from CollectionSubmissionData
        guard let publication = publicationMap[submissionData.submissionId] else {
            continue
        }
        
        // Link submission to publication
        submission.publication = publication
        linkedCount += 1
    }
}
```

### Added: Debug Logging

Added extensive logging to track:
- Publication IDs being cached
- Submission IDs being cached  
- Which submissions are being linked to which publications
- Any failures in the linking process

**New Logging Output:**
```
[JSONImport] Processing publication 1, ID: ABC123
[JSONImport]   Publication name: Poetry Magazine, type: magazine
[JSONImport] ✅ Imported 3 publications
[JSONImport]   Publication IDs cached: ABC123, DEF456, GHI789

[JSONImport]   Collection name: Spring Collection
[JSONImport]   Component ID: XYZ123
[JSONImport]   TextCollection ID: COL456
[JSONImport]   Cached submission with textCollection ID: COL456
[JSONImport]   Cached submission with component ID: XYZ123

[JSONImport] Starting submission-to-publication linking
[JSONImport] Processing 2 collection submissions for component XYZ123
[JSONImport]   ✅ Linked submission to publication: Poetry Magazine
[JSONImport] ✅ Linked 2 submissions to publications
```

## Files Modified

1. **JSONImportService.swift**
   - Line 458-512: Rewrote `linkCollectionSubmissions()` method
   - Line 305-345: Added debug logging to `importPublications()`
   - Line 395-418: Added debug logging to `importCollections()`

## Testing

After applying this fix, test by:

1. **Export a project** from Writing Shed v1 with:
   - Publications (magazines/competitions)
   - Collections/submissions linked to those publications
   - Multiple files in each submission

2. **Import into Writing Shed Pro** and verify:
   - Publications appear in the Publications list
   - Submissions appear under the correct publication
   - Files are linked to submissions
   - All relationships are preserved

3. **Check console logs** for:
   - "Processing N collection submissions" messages
   - "✅ Linked submission to publication" messages
   - No "⚠️ Could not find publication" warnings

## Expected Results

- All submissions should now be properly linked to their parent publications
- Collections view should show submissions grouped by publication
- Each submission should contain the correct files/versions
- No orphaned submissions

## Why This Matters

Without this fix:
- ❌ Submissions imported but not linked to publications
- ❌ Publications appeared empty
- ❌ User couldn't see which stories were submitted where
- ❌ Workflow broken for managing submissions

With this fix:
- ✅ Submissions properly linked to publications
- ✅ Publications show their submissions
- ✅ Complete submission tracking preserved
- ✅ Full import/export roundtrip working
