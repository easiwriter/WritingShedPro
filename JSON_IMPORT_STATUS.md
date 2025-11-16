# JSON Import Status - Current Issues

## What's Working ✅
1. **Project creation** - Name cleaned up, dates removed
2. **Folder structure** - All 12 standard folders created
3. **Text files** - All 574 files imported with proper names
4. **Folder mapping** - "Accepted" → "Published" works
5. **Publications created** - Magazines, Competitions shown in logs

## What's NOT Working ❌

### 1. Collections Have No Names or Files
**Issue**: Collections folder shows unnamed entries with 0 files

**Root Cause**: 
- Collection name comes from `textCollectionData.textCollection` JSON
- Files linked via `collectedVersionData` on versions
- Current code tries to decode JSON correctly but may have issues

**What Should Happen**:
- Collections are Submissions with `publication=nil`
- Each collection should have a name like "Texts in National Comp 2019"
- Each collection should show count of SubmittedFile records

### 2. Publications Have No Files
**Issue**: Magazines/Competitions folders show publications but they're empty

**Root Cause - ARCHITECTURAL**:
Publications DON'T directly contain files. They contain SUBMISSIONS, which contain files.

**Correct Structure**:
```
Publication ("Poetry Magazine")
  ↓
Submission ("November 2025 submission")
  ↓
SubmittedFile links (3 poems with specific versions)
```

**What's Missing**:
- Need to create Submissions that link Collections to Publications
- This happens via `collectionSubmissionIds` or `collectionSubmissionsDatas`
- The JSON export may have WS_CollectionSubmission_Entity data we're not processing

### 3. Submission Linking
**Issue**: Collections aren't being linked to publications

**What Should Happen**:
- User creates a Collection (Submission with publication=nil)
- User submits that Collection to a Publication
- System creates a NEW Submission with:
  - `publication` = the target publication
  - `submittedFiles` = copies of all files from the collection
  - Same version references as the collection

**Current Status**:
- We create collections
- We DON'T create publication submissions
- `linkCollectionSubmissions()` tries to link directly, which is wrong

## Next Steps

### Option 1: Simpler Approach (Recommended)
For now, just get collections working with names and files. Forget about publication submissions for the initial import. User can manually submit collections to publications later.

### Option 2: Complete Approach
Properly implement the WS_CollectionSubmission_Entity import:
1. Create collections (done)
2. Link files to collections (partially done)
3. Process collectionSubmissionsDatas OR collectionSubmissionIds
4. For each link, create a NEW Submission with publication set
5. Copy all SubmittedFiles from collection to new submission

## Data Structure Reference

### WS_Collection_Entity
```json
{
  "type": "WS_Collection_Entity",
  "id": "collection-uuid",
  "collectionComponent": "{...}",  // Has position, dateCreated
  "textCollectionData": {
    "id": "textcollection-uuid",
    "textCollection": "{\"name\":\"Texts in National Comp 2019\",...}"
  },
  "collectionSubmissionIds": "base64-plist-of-submission-ids"
}
```

### Version with Files in Collection
```json
{
  "id": "version-id",
  "collectedVersionData": [
    {
      "collectedVersion": "{\"uniqueIdentifier\":\"textcollection-uuid\",...}"
    }
  ]
}
```

