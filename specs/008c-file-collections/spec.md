# Feature 008c: File Collections

**Status**: Specification Phase  
**Date Created**: 11 November 2025  
**Owner**: User

## Overview

For Poetry and Short Story projects add a Collections feature for organizing files. A Collection is actually a Submission object that groups selected file versions together. Collections are accessed through a new top-level folder called "Collections" positioned between Ready and Set Aside. The user can select files from the Ready folder and add them to a named Collection. Collections can later be submitted to Publications using the existing submission system.

## Requirements

### Scope
- **Applicable Projects**: Poetry and Short Story projects only
- **Not applicable to**: Novel, Script, Blank projects

### Collections Folder
- New top-level folder called "Collections" positioned between Ready and Set Aside folders
- Read-only system folder (cannot add files directly to Collections folder itself)
- Displays list of user-created Collections (which are Submission objects)
- Option to create new Collection

### What Is a Collection?
- **A Collection IS a Submission object** (from Feature 008b)
- Each Collection groups multiple files with specific version selections
- Collections are independent; files can exist in multiple Collections
- Collections can be submitted to Publications

### Creating Collections
- User selects multiple files from Ready folder
- Selects "Add to Collection..." action
- Either selects existing Collection or creates new one with name
- Creates new Submission object representing the Collection
- Submission contains SubmittedFile entries for each selected file

### Collection Contents (SubmittedFiles)
- Each file in a Collection is represented as a **SubmittedFile** object
- Each SubmittedFile stores:
  - Reference to the TextFile
  - Reference to a specific Version of that file
  - Status tracking (pending, accepted, rejected)
- User can change which version of a file is referenced without modifying the original file
- Same file can be in multiple Collections with different versions in each

## Design

### Architecture
Collections are implemented using the existing Submission system (Feature 008b):
- **A Collection IS a Submission object** (no new model needed)
- Collections are queried/displayed in the Collections folder context
- The Submission system already has SubmittedFile for version selection
- This reuses all existing submission infrastructure

### Collections vs Publications Submissions
- **Collections**: User-created Submissions for organizing/grouping files (no publication attached)
- **Publication Submissions**: Submissions created when submitting to a Publication (publication attached)
- Both use the same Submission/SubmittedFile models
- Differentiated by whether `submission.publication` is null (Collection) or set (Publication)

### Version Selection Model
- Each SubmittedFile in a Collection points to a specific Version of a TextFile
- User can change the Version reference without modifying the original TextFile
- This allows "mix and match" versioning: use v2 of poem A, v5 of poem B
- Collections remain independent; changing one doesn't affect others

### Workflow
1. User has files in Ready folder with multiple versions
2. User selects File A (v3), File B (v2), File C (v1) from Ready
3. User creates new Collection named "Spring Contest"
4. System creates Submission with SubmittedFiles for each selected file/version combo
5. User can later edit "Spring Contest" Collection to:
   - Add more files (create new SubmittedFiles)
   - Remove files (delete SubmittedFiles)
   - Change version references (update Version reference in SubmittedFile)
6. When ready, user submits "Spring Contest" Collection to a Publication
7. System creates Publication Submission (different from the Collection Submission)

## Data Model

### Minimal Changes Required
Collections are implemented using existing models - no new data structures needed:

### What Is a Collection?
- **A Collection IS a Submission object** where `publication` is null
- The Submission groups related SubmittedFiles together
- Example: Submission(name: "Spring Contest", publication: nil, submittedFiles: [...])

### Collection Contents
- Collection contains multiple **SubmittedFile** objects (existing model)
- Each SubmittedFile has:
  - `textFile`: Reference to the original TextFile
  - `version`: Reference to specific Version of that TextFile
  - `status`: Submission status (pending, accepted, rejected)
  - `statusNotes`: Optional feedback from publication

### No New Models Needed
- **Submission**: Already exists, used as Collection container
- **SubmittedFile**: Already exists, represents file+version pair in Collection
- **Version**: Already exists, stores specific file versions
- **Folder**: Collections folder is just a system folder like Ready/Set Aside

### Data Structure Example
```
Project.submissions:
├── Submission(id: UUID1, name: "Spring Contest", publication: nil)
│   └── submittedFiles:
│       ├── SubmittedFile(textFile: poem1, version: v3, status: pending)
│       ├── SubmittedFile(textFile: poem2, version: v1, status: pending)
│       └── SubmittedFile(textFile: poem3, version: v2, status: pending)
│
└── Submission(id: UUID2, name: "Summer Reading", publication: nil)
    └── submittedFiles:
        ├── SubmittedFile(textFile: poem1, version: v1, status: pending)
        └── SubmittedFile(textFile: poem2, version: v1, status: pending)
```

### Querying Collections
- Query all Submissions where `publication == nil` in the project
- These are the user's Collections
- Display them in the Collections folder context
- When user selects a Collection, show its SubmittedFiles

## Implementation Plan

### Phase 1: Create Collections System Folder (✅ COMPLETE)
- Add "Collections" as a read-only system folder like "Ready", "Set Aside"
- Position between Ready and Set Aside in folder order
- Update folder capability checks to mark as read-only
- Add tray.2 icon for Collections folder

### Phase 2: Collections Folder UI (✅ COMPLETE)
- Create CollectionsView to display list of Collections (Submissions where publication=nil)
- Show button to create new Collection (creates new Submission)
- Each Collection shows count of files/submissions in it
- Form to name new Collection with validation
- Delete Collections capability

### Phase 3: Collection Details View (🔄 IN PROGRESS)
- Display CollectionDetailView showing SubmittedFiles in a Collection
- Show each file with its selected version
- Add button to add more files to Collection
- Delete files from Collection
- Empty state when Collection has no files

### Phase 4: Add Files to Collection (✅ COMPLETE)
- Show dialog with files from Ready folder
- Multi-select capability
- Version selector for each file
- Add to existing Collection or create new
- Handle adding files to existing Collections
- **NEW**: Bulk operations from Ready folder with "Add to Collection" button
- **NEW**: Collections view edit mode with selection circles
- **NEW**: "Add to Publication" button to submit collections to publications
- **NEW**: Collections folder count display fixed
- **NEW**: Collection detail navigation fixed

### Phase 5: Version Management in Collection
- Allow changing version reference for existing SubmittedFiles
- Show available versions for each file
- Update SubmittedFile.version when user changes selection
- Verify version locking doesn't interfere (locked versions stay locked)

### Phase 6: Collection Submission to Publications (✅ COMPLETE)
- Collections appear as submission source in Publication submission flow
- Allow submitting entire Collection to a Publication
- Creates Publication Submission with Collection's SubmittedFiles
- Version selection from Collection is preserved
- **Implemented in Phase 4**: Collections can be submitted to publications

### Testing Strategy

### Unit Tests
- Submission creation/deletion (Collections)
- SubmittedFile creation with version selection
- Collection querying (publication=nil)
- Version reference updates
- Empty Collection handling
- Multi-project independence

### Integration Tests
- Create Collection with multiple files
- Submit Collection to Publication
- Verify submitted files match Collection contents
- Change version in Collection, verify submission shows new version
- Add file to existing Collection that's already been submitted
- Delete file from Collection

### Edge Cases
- Add same file multiple times (reject)
- Add file that's in another Collection (allow)
- Create Collection with no files (allow, show empty state)
- Delete Collection with files (allow, cascade delete SubmittedFiles)
- Change version for locked file (verify lock status preserved)
- Submit Collection to multiple Publications

### Acceptance Criteria
✅ User can create named Collections in Collections folder
✅ User can add selected files to Collections with version choice
✅ User can modify Collection contents
✅ User can change version for each file in Collection
✅ Collections appear in Publications submission source
✅ Collections can be submitted to Publications
✅ Collections work for Poetry and Short Story projects only
✅ No new models needed - leverages existing Submission/SubmittedFile

- Create Submissions linking each file to Collection
- Each Submission captures currently selected version
- Handle duplicate file additions (already in Collection?)

### Phase 6: Edit Collection
- Open Collection to view contents
- Show files and their versions
- Option to change version for each file
- Add more files to Collection
- Remove files from Collection
- Delete Collection itself

### Phase 7: View Collection Contents
- Display files in Collection
- Show version for each file
- Similar to Publication folder view
- Can preview/edit individual files

### Phase 8: Submit Collection to Publication
- Integrate with existing Publication submission flow
- Select Collection as source
- Files in Collection become submitted files
- Use existing Submission model

### Testing at Each Phase
- Verify Collections folder appears correctly
- Test Collection creation and naming
- Test multi-select and adding files
- Test version selection
- Test Collection editing
- Test submission to Publications

## Testing

### Unit Tests
- Collection creation with valid/invalid names
- Collection name uniqueness within Collections folder
- Version selection accuracy
- File addition to Collections
- File removal from Collections
- Collection deletion

### Integration Tests
- Create Collection with multiple files
- Submit Collection to Publication
- Verify submitted files match Collection contents
- Change version in Collection, verify submission uses new version
- Add file to existing Collection that's already been submitted
- Delete file from Collection

### Edge Cases
- Add same file multiple times - reject
- Add file that's in another Collection (should allow)
- Create Collection with no files (should allow)
- Delete Collection with submitted files (should allow)
- Rename file in Ready folder (Collection reference should follow)
- Delete file from Ready folder (Collection reference invalidates?)

### Acceptance Criteria
✅ User can create named Collections in Collections folder
✅ User can add selected files to Collections with version choice
✅ User can modify Collection contents
✅ User can change version for each file in Collection
✅ Collections appear in Publications submission source
✅ Collections can be submitted to Publications
✅ Collections work for Poetry and Short Story projects only
