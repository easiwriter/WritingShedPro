# Feature 008c: File Collections

**Status**: Specification Phase  
**Date Created**: 11 November 2025  
**Owner**: User

## Overview

For Poetry and Short Story projects add a new Model type called Collection. A collection has a name and its contents are a list of the currently selected versions of files in the Ready folder. Collections are contained in a new top level folder called Collections positioned between Ready and Set Aside. The user can select files in the Ready folder and add them to a named Collection in the Collections folder. The named collection is actually a Submission. Single Collections can be submitted to a Publication.

## Requirements

### Scope
- **Applicable Projects**: Poetry and Short Story projects only
- **Not applicable to**: Novel, Script, Blank projects

### Collections Folder
- New top-level folder called "Collections" positioned between Ready and Set Aside folders
- Read-only container (cannot add files directly to Collections folder)
- Display list of named Collections
- Option to create new Collection

### Creating Collections
- User selects multiple files from Ready folder
- Selects "Add to Collection..." action
- Either selects existing Collection or creates new one with name
- Collection stores references to selected files (not copies)

### Collection Contents
- Each entry in a Collection is a **Submission** (linking file to collection)
- Stores the **currently selected version** of each file at time of addition
- User can later change which version is included by editing the Collection
- File can exist in multiple Collections simultaneously

### Version Management
- When user modifies original file (creates new version), Collection can reference new version
- User can change which version of a file is in Collection without modifying the file itself
- This provides flexibility: Collection might use version 2 of File A while File A is on version 5

### Submission Integration
- Collections entries are Submissions (existing model from Feature 008b)
- Collections can be submitted to Publications using existing Publication submission flow
- Each file in Collection becomes a submitted file in the Publication

### UI Requirements
- Collections folder displays all created Collections
- Selecting a Collection shows its contents (files and their versions)
- Multi-select capability in Ready folder
- "Add to Collection..." option in context menu or toolbar
- Rename/delete Collection capabilities

## Design

### Architecture
Collections leverage the existing Submission system (Feature 008b):
- A Collection IS a folder in the Collections directory
- Files added to a Collection are actually Submissions
- This reuses all Publication submission infrastructure

### Collection vs Publication Folders
- **Collections folder**: User-created collections of files for grouping/organization
- **Publication folders** (Magazines, Competitions, etc.): System folders for publication management
- Both use the same underlying folder structure but serve different purposes

### Version Selection Model
- Each Submission in a Collection can point to any version of its file
- User can change the version reference without creating a new Submission
- This allows "mix and match" versioning: use v2 of poem A, v5 of poem B

### Workflow
1. User has files in Ready folder with multiple versions
2. User creates new Collection named "Spring Contest"
3. User selects File A (v3), File B (v2), File C (v1)
4. Files added to "Spring Contest" Collection with those version references
5. User can later edit "Spring Contest" to:
   - Add more files
   - Remove files
   - Change version references
6. When ready, user submits "Spring Contest" Collection to a Publication
7. Publication receives all files with their specified versions

## Data Model

### Minimal Changes Required
Since Collections leverage the existing Submission system, minimal new models are needed:

### Collection (Folder)
A Collection is just a special Folder:
- Name: user-provided (e.g., "Spring Contest")
- Located in Collections directory (new system folder)
- Contains Submissions (existing model)
- Read-only (files not added directly)

### No New Models Needed
- Use existing **Submission** model to link files to collections
- Use existing **Folder** model to represent Collections
- Use existing **Version** references for version selection

### Folder Hierarchy
```
Project
├── Ready/
│   ├── poem1.txt (v1, v2, v3)
│   ├── poem2.txt (v1)
│   └── poem3.txt (v1, v2)
├── Collections/ (new system folder)
│   ├── Spring Contest/ (user-created Collection)
│   │   ├── Submission: poem1.txt → v3
│   │   ├── Submission: poem2.txt → v1
│   │   └── Submission: poem3.txt → v2
│   └── Summer Reading/ (another Collection)
│       ├── Submission: poem1.txt → v1
│       └── Submission: poem2.txt → v1
└── Set Aside/
```

### Submission Changes
- Already supports version selection
- No structural changes needed
- Existing submission flow works with Collections

## Implementation Plan

### Phase 1: Create Collections System Folder
- Add "Collections" as a system folder like "Ready", "Set Aside"
- Position between Ready and Set Aside in folder order
- Make it read-only (cannot add files directly)
- Update folder views to handle this special case

### Phase 2: Collections UI in Collections Folder
- Display list of user-created Collections
- Show button to create new Collection
- Each Collection shows count of files/submissions
- Tap to view Collection contents

### Phase 3: Create New Collection
- Dialog/form to name new Collection
- Creates new Folder with name in Collections directory
- Validates name for uniqueness
- Returns to Collections folder view

### Phase 4: Multi-Select in Ready Folder
- Add select mode to Ready folder file listing
- Checkboxes or tap-to-select UI
- "Add to Collection..." button when files selected
- Shows list of existing Collections and "Create New" option

### Phase 5: Add Files to Collection
- Display selected files
- Let user choose existing Collection or create new
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
