# Import Fix v2 - Collections and Submissions Corrected

## Problem Analysis from Actual Export

After examining a real exported `.wsd` file, I discovered the actual data structure is different from what I initially understood:

### Data Structure (from Real Export)

```json
{
  "collectionComponentDatas": [
    // PUBLICATIONS (magazines, competitions, etc.)
    {
      "type": "WS_Submission_Entity",
      "id": "My Poems<>03/06/2016, 09:09PoetryNoble Dissent",
      "collectionComponent": "{...name, groupName, etc...}",
      "collectionSubmissionsDatas": [
        {
          "submissionId": "My Poems<>03/06/2016, 09:09PoetryNoble Dissent",  // SELF-REFERENTIAL!
          "collectionId": "...",
          ...
        }
      ],
      "notes": "...",
      // NO textCollectionData
    },
    
    // COLLECTIONS (groups of files submitted somewhere)
    {
      "type": "WS_Collection_Entity",
      "id": "2234BCAE-744F-4C19-BA73-CF41A40850AB",
      "collectionComponent": "{...name: 'National Comp 2018'...}",  // ← Collection name HERE
      "collectionSubmissionIds": "...base64...",  // ← Links to publications
      "textCollectionData": {
        "id": "B562E08B-B864-467A-B617-89DF85F90BC5",
        "textCollection": "{...name: 'Texts in National Comp 2018'...}",  // ← Internal name
        "collectedVersionIds": "...base64..."  // ← Files/versions in collection
      },
      "collectedTextIds": "...base64...",
      "notes": "..."
    }
  ]
}
```

### Key Discoveries

1. **Publications** (`WS_Submission_Entity`):
   - Have NO `textCollectionData`
   - Have `collectionSubmissionsDatas` that are SELF-REFERENTIAL (circular)
   - These represent magazines, competitions, etc. (places to submit TO)

2. **Collections** (`WS_Collection_Entity`):
   - Have `textCollectionData` with the actual files
   - Have `collectionSubmissionIds` linking TO publications
   - Collection NAME is in `collectionComponent`, not `textCollectionData`
   - `textCollectionData.textCollection.name` is "Texts in [CollectionName]" (internal entity)

3. **Relationship**:
   - Collection → (via `collectionSubmissionIds`) → Publication
   - NOT Publication → Collection

## The Bugs (Both Issues)

### Bug 1: Wrong Linking Logic

**Problem:** Import was trying to use `collectionSubmissionsDatas` from publications, which are self-referential

**Fix:** Only process `WS_Collection_Entity` items and use their `collectionSubmissionIds` to link to publications

### Bug 2: Wrong Collection Name Source

**Problem:** Import was reading collection name from `textCollectionData.textCollection.name` which contains "Texts in [name]"

**Fix:** Read collection name from `collectionComponent.name` which has the actual collection name

## Changes Made

### 1. `importCollections()` - Fixed Name Parsing

```swift
// BEFORE (Wrong):
if let textCollectionData = componentData.textCollectionData {
    if let textCollectionDict = try? JSONSerialization.jsonObject(
        with: textCollectionData.textCollection.data(using: .utf8)!
    ) as? [String: Any] {
        collectionName = textCollectionDict["name"] as? String ?? collectionName
    }
}
// Result: Collections named "Texts in National Comp 2018" ❌

// AFTER (Correct):
if let collectionDict = try? JSONSerialization.jsonObject(
    with: componentData.collectionComponent.data(using: .utf8)!
) as? [String: Any] {
    collectionName = collectionDict["name"] as? String ?? collectionName
}
// Result: Collections named "National Comp 2018" ✅
```

### 2. `linkCollectionSubmissions()` - Fixed Linking Logic

```swift
// BEFORE (Wrong):
for componentData in data.collectionComponentDatas {
    if let submissionDatas = componentData.collectionSubmissionsDatas {
        // Tried to process self-referential data from publications ❌
    }
}

// AFTER (Correct):
for componentData in data.collectionComponentDatas {
    // Only process WS_Collection_Entity (not publications)
    guard componentData.type == "WS_Collection_Entity" else { continue }
    
    // Use collectionSubmissionIds to link to publications
    if let submissionIds = componentData.collectionSubmissionIds,
       let links = try? PropertyListDecoder().decode([String].self, from: submissionIds) {
        for linkId in links {
            if let publication = publicationMap[linkId] {
                submission.publication = publication  // ✅
            }
        }
    }
}
```

## Testing

With these fixes, the import should now correctly:

1. **Show collection names** - "National Comp 2018" not "Texts in National Comp 2018"
2. **Show files in collections** - Files appear in the collection listings
3. **Link to publications** - Collections appear under their respective publications
4. **Show submissions under publications** - Publications show which collections were submitted to them

### Expected Console Output

```
[JSONImport] Processing collection/submission 1
[JSONImport]   Collection name: National Comp 2018
[JSONImport]   Component ID: 2234BCAE-744F-4C19-BA73-CF41A40850AB
[JSONImport]   TextCollection ID: B562E08B-B864-467A-B617-89DF85F90BC5
[JSONImport]   Cached submission with textCollection ID: B562E08B-B864-467A-B617-89DF85F90BC5
[JSONImport]   Cached submission with component ID: 2234BCAE-744F-4C19-BA73-CF41A40850AB
[JSONImport] ✅ Created 15 collections/submissions

[JSONImport] Starting submission-to-publication linking
[JSONImport]   Collection '2234BCAE-744F-4C19-BA73-CF41A40850AB' has 1 submission link(s)
[JSONImport]   ✅ Linked collection to publication: Bewilderbliss (ID: ...)
[JSONImport] ✅ Linked 10 submissions to publications
```

## Files Modified

- **JSONImportService.swift**
  - Lines 373-393: Fixed collection name parsing in `importCollections()`
  - Lines 494-536: Completely rewrote `linkCollectionSubmissions()`

## Summary

The root cause was misunderstanding the data model:
- **Publications** are destinations (magazines, competitions)
- **Collections** are groups of files
- **Collections link TO publications**, not the other way around
- Collection metadata is in `collectionComponent`, not `textCollectionData`
- `textCollectionData` is an internal entity for managing file/version relationships

With these fixes, the full submission workflow should now work correctly.
