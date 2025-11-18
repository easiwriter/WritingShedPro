# Legacy Database Structure: Collections & Submissions

**Date**: 14 November 2025  
**Purpose**: Document the legacy Writing Shed database structure for collections, submissions, and publications to guide the import implementation.

## Overview

The legacy database was designed ~10 years ago with a complex structure for managing collections and submissions. This document explains how these entities relate and how they should be imported into the new system.

## Legacy Entities

This section explains the functions of WS_Collection_Entity, WS_CollectionComponent_Entity, WS_CollectionSubmission_Entity, WS_Collection_Entity, WS_Submission_Entity, WS_TextCollection_Entity and WS_CollectedVersion_Entity.

The source of truth is the WS_Project_Entity which has a to-many relationship with WS_CollectionComponent_Entity.
- The WS_CollectionComponent_Entity is class parent to WS_Collection_Entity and WS_Collection_Entity
- The WS_Collection_Entity has a groupName = Collections to indicate that all these entities are dispayed in the legacy app in the Collections folder. They should be stored in the Collections folder in WritingShedPro. It has 3 relationships. 
    - texts, has a many-many relationship with WS_Text_Entity meaning a collection can have many text files each of which could belong to many collections. 
    - collectionSubmissions, is a to-many relationship to WS_CollectionSubmission_Entity. 
    - textCollection, is a to-one relationship to a WS_TextCollection_Entity
- The WS_CollectionSubmission_Entity has attributes that determine the status of a submission that has been sent to a publication. It has 2 relationships:
    - collection, is a to-one relationship with WS_Collection_Entity
    - submission, is a to-one relationship with WS_Submission_Entity
- The WS_Submission_Entity has a groupName that specifies the Publication folder it is displayed in (Magazines etc). It corresponds to the Publication model in WritingShedPro.
- The WS_TextCollection_Entity is an entry that joins the WS_CollectedVersion_Entity and the WS_Collection_Entity. It has no useful attributes.
- The WS_CollectedVersion_Entity has an attribute 'status' that is true if the text has been accepted for publication. It has 2 relationships:
    - textCollection, is a to-one relationship to WS_Text_Collection
    - version, is a to-one relationship to WS_Version_Entity
---

## Import Mapping Strategy

### Phase 1: Publications (WS_Submission_Entity → Publication)

**Mapping**: WS_Submission_Entity → `Publication`

- **groupName** → Determines PublicationType:
  - "Magazines" → `.magazine`
  - "Competitions" → `.competition`
  - "Commissions" → `.commission`
  - Other values → `.other`
- **name** → `Publication.name`
- **Project relationship** → `Publication.project`
- **Attributes to map**: TBD (need to check what other fields exist)

**Implementation**:
1. Create `fetchPublications(for project:)` in LegacyDatabaseService
2. Create `mapPublication(_:project:)` in DataMapper
3. Add `importPublications()` to LegacyImportEngine
4. Publications go into project's type-specific folders

---

### Phase 2: Collections (WS_Collection_Entity → Submission with publication=nil)

**Mapping**: WS_Collection_Entity → `Submission` (publication=nil)

- **name** (from WS_CollectionComponent_Entity) → `Submission.name`
- **groupName** = "Collections" → Stored in Collections folder
- **Project relationship** → `Submission.project`
- **publication** → `nil` (marks this as a collection, not a publication submission)
- **texts relationship** → Need to create `SubmittedFile` records for each text

**Implementation**:
1. Use existing `fetchCollections(for:)` in LegacyDatabaseService
2. Use existing `mapCollection(_:project:)` in DataMapper
3. Uncomment `importCollections()` in LegacyImportEngine (line 160)
4. For each text in collection.texts:
   - Get the text's current version (or use WS_CollectedVersion_Entity if available)
   - Create `SubmittedFile(submission: collection, textFile: text, version: version)`

---

### Phase 3: Publication Submissions (WS_CollectionSubmission_Entity → Submission with publication)

**Mapping**: WS_CollectionSubmission_Entity → `Submission` (publication != nil)

This is where a collection was submitted to a publication. Creates a NEW Submission object.

- **submission** (WS_Submission_Entity) → `Submission.publication` (the Publication)
- **collection** (WS_Collection_Entity) → Source for files to submit
- **submittedOn** → `Submission.submittedDate`
- **notes** → `Submission.notes`
- **Project** → `Submission.project`

**Create SubmittedFile records**:
- For each text in the collection:
  - Get the version from WS_CollectedVersion_Entity (if exists)
  - Create `SubmittedFile(submission: newSubmission, textFile: text, version: version)`
  - Map **accepted** attribute:
    - `WS_CollectedVersion_Entity.status == true` → `SubmittedFile.status = .accepted`
    - Otherwise → `SubmittedFile.status = .pending` (or could use accepted/returnedOn dates)

**Implementation**:
1. Use existing `fetchCollectionSubmissions(for:)` in LegacyDatabaseService
2. Add `fetchCollectedVersions(for:)` to get version info
3. Create `mapCollectionSubmission(_:)` in DataMapper
4. Add `importCollectionSubmissions()` to LegacyImportEngine

---

### Phase 4: Version Tracking (WS_CollectedVersion_Entity → SubmittedFile.status)

**Mapping**: WS_CollectedVersion_Entity → `SubmittedFile` metadata

- **version** relationship → Links to specific `Version` of a `TextFile`
- **status** (boolean) → `SubmissionStatus`:
  - `true` → `.accepted`
  - `false` → `.pending` or `.rejected` (may need additional logic)

This is handled during Phase 3 when creating SubmittedFile records.

---

### Import Order

1. **Publications** (Phase 1)
   - Must happen first so they exist when creating submission references
   
2. **Collections** (Phase 2)
   - Creates Submission objects with publication=nil
   - Creates SubmittedFile records for files in collections
   
3. **Publication Submissions** (Phase 3)
   - Creates Submission objects with publication != nil
   - Links to Publications created in Phase 1
   - Uses version info from WS_CollectedVersion_Entity

---

## Implementation Notes

### Current Status
- ❌ Collections import: Code exists but is commented out (line 160 in LegacyImportEngine.swift)
- ❌ Publications import: Not implemented
- ❌ Collection submissions: Not implemented

### Files Involved
- `LegacyImportEngine.swift` - Main import orchestration
- `DataMapper.swift` - Entity mapping logic
- `LegacyDatabaseService.swift` - Legacy database queries

### Available Legacy Fetch Methods
- `fetchCollections(for:)` - Get WS_Collection_Entity records
- `fetchCollectionComponents(for:)` - Get components of a collection
- `fetchCollectedVersions(for:)` - Get versions in a collection
- `fetchCollectionSubmissions(for:)` - Get submission records for a collection
