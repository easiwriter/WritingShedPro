# Feature Specification: File Movement System (Draft for Review)

**Feature Branch**: `008-file-movement-system`  
**Created**: 2025-11-07  
**Status**: Draft - Review in Progress  

## Overview

Enable users to move text files between appropriate folders within a project, following the natural workflow of writing, editing, and publishing.

## Scope

**Phase 1 (This Feature):** Poetry and Short Story projects
**Phase 2 (Future):** Novel and Script projects (have special attributes)

## Folder Classification

### Source Folders

Source folders contain written work in various stages. Files can move between source folders within the same project.

**Poetry Projects:**
- Draft - Work in progress
- Ready - Ready for submission
- Set Aside - Paused/archived work

**Short Story Projects:**
- Draft - Work in progress  
- Ready - Ready for submission
- Set Aside - Paused/archived work

**Novel Projects (Future):**
- Scenes - Individual scene files
- Set Aside - Paused scenes

**Script Projects (Future):**
- Scenes - Individual scene files
- Set Aside - Paused scenes

### Publication Folders

Publication folders organize work that has been submitted or published. These are **container folders** that only hold user-created subfolders.

**All Project Types:**
- Magazines - Submissions to magazines/journals
- Competitions - Contest submissions
- Commissions - Commissioned work
- Other - Other publication venues

**Structure:**
```
Magazines/
  ├── [User-created folder: "Poetry Monthly"]/
  │   ├── poem1.txt
  │   └── poem2.txt
  └── [User-created folder: "Atlantic"]/
      └── submission.txt
```

### Special Folders

**Trash:**
- Accepts files from ANY folder
- Supports "Put Back" to restore files to original location
- Requires tracking original folder location

**All (Smart Folder):**
- Read-only aggregate view of all files in source folders
- Files cannot be moved here directly

**Published (Poetry/Short Story only):**
- [NEEDS CLARIFICATION: See Question #3 below]

## File Movement Rules

### Between Source Folders

Files can move freely between source folders within the same project:

```
Draft ⟷ Ready ⟷ Set Aside
  ↓       ↓        ↓
         Trash
```

### To Publication Folders

**Rule:** Only files from **Ready** folder can be moved to publication folders

**Workflow:**
1. User moves file from Draft → Ready (when ready to submit)
2. User creates subfolder in publication folder (e.g., "Magazines/Poetry Monthly")
3. User moves file from Ready → Magazines/Poetry Monthly
4. [NEEDS CLARIFICATION: Does file stay in Ready or move completely?]

### To/From Trash

**To Trash:**
- Any file from any folder can be moved to Trash
- System remembers original folder location

**From Trash (Put Back):**
- File returns to its original folder
- If original folder was deleted, [NEEDS CLARIFICATION: go to Draft? Show error?]

## Data Model Changes

### TrashItem Model (New)

```
TrashItem {
  - file: TextFile (reference to actual file)
  - originalFolder: Folder (where it came from)
  - originalParentFolder: Folder? (if it was in a subfolder)
  - deletedDate: Date
  - project: Project
}
```

### Folder Model Updates

Add new attributes to Folder:

```
Folder {
  // Existing attributes...
  
  // New attributes for movement:
  - folderType: FolderType (source, publication, trash, smart, other)
  - canReceiveFiles: Bool (computed from folderType)
  - canReceiveSubfolders: Bool (computed from folderType)
  - acceptsFilesFrom: [String] (folder names that can send files here)
}

enum FolderType {
  case source
  case publication  
  case trash
  case smart
  case other
}
```

### TextFile Model Updates

```
TextFile {
  // Existing attributes...
  
  // Movement tracking:
  - previousFolder: Folder? (for undo support)
  - moveHistory: [MoveRecord]? (optional audit trail)
}
```

## User Stories

### US1: Move Between Source Folders (P1)

**As a** poet  
**I want to** move a draft poem to the Ready folder  
**So that** I can track which poems are ready for submission

**Acceptance:**
- Can select file in Draft
- Can choose "Move to..." 
- Can see list of valid destinations (Ready, Set Aside, Trash)
- File moves and appears in destination folder
- File no longer in source folder

### US2: Move to Publication Folder (P1)

**As a** poet  
**I want to** move a ready poem into a magazine submission folder  
**So that** I can track where I've submitted my work

**Acceptance:**
- Can select file in Ready folder
- Can choose "Move to..."
- Can see publication folder subfolders (e.g., "Magazines/Poetry Monthly")
- [NEEDS CLARIFICATION: Move or copy?]
- File appears in publication folder

### US3: Move to Trash (P1)

**As a** writer  
**I want to** delete a file by moving it to Trash  
**So that** I can clean up unwanted work without permanent deletion

**Acceptance:**
- Can select file in any folder
- Can choose "Move to Trash" or "Delete"
- File moves to Trash folder
- System remembers original location

### US4: Restore from Trash (P1)

**As a** writer  
**I want to** restore a deleted file to its original location  
**So that** I can recover work I deleted by mistake

**Acceptance:**
- Can select file in Trash
- Can choose "Put Back"
- File returns to original folder
- File removed from Trash
- If original folder gone, [NEEDS CLARIFICATION: behavior?]

### US5: Create Publication Subfolder (P2)

**As a** poet  
**I want to** create a subfolder in Magazines for a specific publication  
**So that** I can organize submissions by venue

**Acceptance:**
- Can select Magazines folder
- Can create new subfolder (e.g., "Poetry Monthly")
- Can move files from Ready into this subfolder
- Cannot create files directly in Magazines (must be in subfolder)

## Movement Validation Rules

### FR-001: Source Folder Movement
Files MUST be able to move between any source folders within the same project

### FR-002: Publication Folder Restrictions  
Files MUST only move to publication folders from Ready folder

### FR-003: Trash Universality
Trash MUST accept files from any folder

### FR-004: Publication Folder Structure
Publication folders (Magazines, Competitions, etc.) MUST only contain user-created subfolders, not files directly

### FR-005: Original Location Tracking
When moving to Trash, system MUST record original folder location

### FR-006: Put Back Restoration
Trash files MUST support "Put Back" command to return to original location

### FR-007: Cross-Project Prevention
Files MUST NOT be moveable between different projects

### FR-008: Smart Folder Protection
"All" folder MUST be read-only (files cannot be moved there)

## Open Questions for Clarification

### Q1: Publication Folder Workflow

When moving a file from Ready to a publication folder, should the file:

| Option | Behavior | Implications |
| ------ | -------- | ------------ |
| A | Copy to publication, original stays in Ready | Can submit same file to multiple venues |
| B | Move to publication, removed from Ready | Clear separation, file in one place |
| C | Create reference/link in publication | Original stays in Ready, link tracks submission |

**Your choice:** ___

### Q2: Published Folder Purpose

The "Published" folder currently exists. Should it:

| Option | Behavior | Implications |
| ------ | -------- | ------------ |
| A | Receive files when accepted from publications | Manual workflow: user moves accepted work here |
| B | Smart folder showing accepted submissions | Automatic: shows files marked as "accepted" |
| C | Deprecated/unused | Remove from future designs |

**Your choice:** ___

### Q3: Put Back Edge Cases

When "Put Back" is used but original folder no longer exists:

| Option | Behavior | Implications |
| ------ | -------- | ------------ |
| A | Move to Draft (default source folder) | File isn't lost, user can re-organize |
| B | Show error, require user to choose destination | Explicit, but more clicks |
| C | Recreate original folder | Could create clutter |

**Your choice:** ___

### Q4: Publication Folder File Movement

Can files move between publication subfolders?

| Option | Behavior | Implications |
| ------ | -------- | ------------ |
| A | Yes, freely | User can reorganize submissions |
| B | No, must go back to Ready first | Cleaner workflow |
| C | Yes, but warn user | Flexible with safety net |

**Your choice:** ___

## Success Criteria

- SC-001: Users can move files between source folders in under 3 taps
- SC-002: 100% of invalid moves are prevented with helpful error messages
- SC-003: Trash "Put Back" succeeds 95%+ of the time
- SC-004: File moves sync across devices within 5 seconds
- SC-005: Zero data loss during move operations

## Out of Scope (This Phase)

- ❌ Novel and Script project file movement (special attributes needed)
- ❌ Copying files (only move/cut operations)
- ❌ Cross-project file movement
- ❌ Automated file movement based on rules
- ❌ File versioning during moves (covered by Feature 004)
- ❌ Submission tracking/status (future feature)

## Next Steps

1. **You provide answers to Q1-Q4 above**
2. I'll complete the spec with your decisions
3. Create comprehensive user stories
4. Define complete data model
5. Ready for `/speckit.plan`

---

**Status:** ⏸️ Awaiting clarification on 4 questions
