# Feature 036: Project Folder Revamp

**Status:** Planning  
**Branch:** TBD  
**Date:** 2026-02-17

## Overview

1. I want to remove the current Collections folder from all project types. This means that the button for creating new collections in the file list editor should be removed along with adding files to a collection. This button should be replaced by a button that adds selected files to the Submissions folder. This applies to all project types.

2. I want to add a new folder called Collections to Poetry projects

- it should be displayed between the Manuscript and Poems folders.
- named collection objects can be added to the folder
- poems can be selected with workflow status 'ready' and assigned to a collection in the same way that text files can be assigned to Sections in a Prose project
- in the Manuscript folder replace the All Poems folder with a folder called Body Matter.
- the Body Matter folder should let the user add selected Collections from the new Collections folder.
- The preview, export and print commands in the Manuscript toolbar should, in addition to front and back matter, include the text from all the collections in the Body Matter folder.
- A button should be added for adding a pdf preview to a new submission.

3. In the Manuscript folder of Prose projects replace the All Sections folder with a folder called Body Matter.

- the Body Matter folder should let the user add selected Sections from the Sections folder.
- The preview, export and print commands in the Manuscript toolbar should, in addition to front and back matter include the text from all the Sections in the Body Matter folder.
- A button should be added to the manuscript toolbar for adding a pdf to a new submission.

4. In the Manuscript folder of Novel projects replace the All Chapters folder with a folder called Body Matter.

- the Body Matter folder should let the user add selected Chapters from the Chapters folder.
- The preview, export and print commands in the Manuscript toolbar should, in addition to front and back matter include the text from all the Chapters in the Body Matter folder.
- A button should be added to the manuscript toolbar for adding a pdf to a new submission.

5. In the Manuscript folder of Short Fiction projects replace the All Stories folder with a folder called Body Matter.

- the Body Matter folder should let the user add selected Stories from the Stories folder.
- The preview, export and print commands in the Manuscript toolbar should, in addition to front and back matter include the text from all the Stories in the Body Matter folder.
- A button should be added to the manuscript toolbar for adding a pdf to a new submission.

6. In the Manuscript folder of Verse Novel projects replace the All Books folder with a folder called Body Matter.

- the Body Matter folder should let the user add selected Books from the Books folder.
- Each Book contains Episodes (scenes with a poetry form). Episodes are collected in Books and Books go into Body Matter.
- The preview, export and print commands in the Manuscript toolbar should, in addition to front and back matter include the text from all the Books in the Body Matter folder.
- A button should be added to the manuscript toolbar for adding a pdf to a new submission.
- **Note**: The current codebase incorrectly uses `Chapter` entities for Verse Novel Books. This needs to be corrected — Verse Novel should use a distinct Books/Episodes hierarchy, not Chapters/Scenes.

7. In the Manuscript folder of Drama projects replace the All Acts folder with a folder called Body Matter.

- the Body Matter folder should let the user add selected Acts from the Acts folder.
- The preview, export and print commands in the Manuscript toolbar should, in addition to front and back matter include the text from all the Acts in the Body Matter folder.
- A button should be added to the manuscript toolbar for adding a pdf to a new submission.

8. Ordering — the user can reorder Collections within Body Matter. The same applies to Sections/Chapters/Stories/Books/Acts in their respective Body Matter folders. This ordering persists in SwiftData.

9. Migration - on upgrade the poems in the current All Poems folder should be replaced by a Collection folder called Collection 1 containing the poems in All Poems. The existing auto-populated "All X" folders in other project types will be replaced with an initially-populated Body Matter folder containing all existing items, so users don't lose visibility of their content.

10. The content of the Body Matter folders can be edited - items added, moved and removed.

### Fiction Sub-Types Summary
The Fiction project type (`ProjectType.fiction`) has three sub-types via `FictionClass`:
| Sub-Type | Container | Content Unit | Manuscript Body Folder | Body Matter Contains |
|---|---|---|---|---|
| Novel | Chapters | Scenes | All Chapters → Body Matter | Chapters |
| Short Fiction | Stories | Scenes | All Stories → Body Matter | Stories |
| Verse Novel | Books | Episodes | All Books → Body Matter | Books |

---

## Requirements

### Functional Requirements

#### FR-1: Remove Old Collections System
- [ ] FR-1.1: Remove Collections folder from Prose, Fiction (all sub-types), and Drama projects
- [ ] FR-1.2: Remove "Add to Collection" button from FileListView edit toolbar
- [ ] FR-1.3: Remove `onAddToCollection` callback from FileListView
- [ ] FR-1.4: Remove `supportsAddToCollection` from FolderFilesView+Helpers
- [ ] FR-1.5: Remove CollectionPickerView component
- [ ] FR-1.6: Remove collection picker references from ChapterListView, ActListView, SectionListView
- [ ] FR-1.7: Remove or deprecate CollectionsView and CollectionDetailView

#### FR-2: Poetry Collections (New System)
- [ ] FR-2.1: Add Collections folder to Poetry projects, positioned between Manuscript and Poems
- [ ] FR-2.2: Allow creating named PoetryCollection objects in the Collections folder
- [ ] FR-2.3: Allow assigning poems (with `.ready` workflow status) to a collection
- [ ] FR-2.4: Display collections in PoetryCollectionsView with create/rename/delete/reorder
- [ ] FR-2.5: Display poems within a collection in PoetryCollectionDetailView with add/remove/reorder

#### FR-3: Body Matter (All Project Types)
- [ ] FR-3.1: Replace "All Poems" with "Body Matter" in Poetry Manuscript folder
- [ ] FR-3.2: Replace "All Sections" with "Body Matter" in Prose Manuscript folder
- [ ] FR-3.3: Replace "All Chapters" with "Body Matter" in Novel Manuscript folder
- [ ] FR-3.4: Replace "All Stories" with "Body Matter" in Short Fiction Manuscript folder
- [ ] FR-3.5: Replace "All Books" with "Body Matter" in Verse Novel Manuscript folder
- [ ] FR-3.6: Replace "All Acts" with "Body Matter" in Drama Manuscript folder
- [ ] FR-3.7: Allow user to add items to Body Matter from source folder
- [ ] FR-3.8: Allow user to remove items from Body Matter (reference only, source item preserved)
- [ ] FR-3.9: Allow user to reorder items within Body Matter
- [ ] FR-3.10: Persist Body Matter ordering in SwiftData

#### FR-4: Manuscript Assembly
- [ ] FR-4.1: ManuscriptAssemblyService pulls body from Body Matter items (not source folders)
- [ ] FR-4.2: Preview command includes Front Matter + Body Matter items + Back Matter
- [ ] FR-4.3: Export command includes Front Matter + Body Matter items + Back Matter
- [ ] FR-4.4: Print command includes Front Matter + Body Matter items + Back Matter
- [ ] FR-4.5: Body Matter order determines content order in manuscript output

#### FR-5: PDF to Submission
- [ ] FR-5.1: Add "PDF to Submission" button in Manuscript toolbar (all project types)
- [ ] FR-5.2: Generate PDF from assembled manuscript (Front + Body + Back matter)
- [ ] FR-5.3: Create new Submission with PDF attached
- [ ] FR-5.4: Navigate to submission detail for user to complete

#### FR-6: Verse Novel Correction
- [ ] FR-6.1: Create new Book model (replacing incorrect Chapter reuse)
- [ ] FR-6.2: Books contain Episodes (StoryScene with poetry form)
- [ ] FR-6.3: Books are the items added to Body Matter
- [ ] FR-6.4: Migrate existing Chapter entities to Book entities for Verse Novel projects

#### FR-7: Migration
- [ ] FR-7.1: Rename "All X" folders to "Body Matter" for all existing projects
- [ ] FR-7.2: Migrate old Collection data to PoetryCollection model for Poetry projects
- [ ] FR-7.3: Create "Collection 1" with all poems if no collections exist in Poetry project
- [ ] FR-7.4: Populate Body Matter with all existing items for non-Poetry projects
- [ ] FR-7.5: Remove Collections folder from non-Poetry projects
- [ ] FR-7.6: Reposition Collections folder in Poetry projects
- [ ] FR-7.7: Migrate Verse Novel Chapters to Books
- [ ] FR-7.8: Clean up old SubmittedFile collection records

### Non-Functional Requirements

#### NFR-1: CloudKit Compatibility
- [ ] NFR-1.1: All new model attributes must be optional or have defaults
- [ ] NFR-1.2: No @Attribute(.unique) on new models
- [ ] NFR-1.3: Migration must be idempotent (safe to run multiple times)
- [ ] NFR-1.4: Never delete records based on missing relationships
- [ ] NFR-1.5: Migration data syncs correctly across devices

#### NFR-2: Performance
- [ ] NFR-2.1: Body Matter assembly should be no slower than current dynamic assembly
- [ ] NFR-2.2: Reordering should update immediately in UI

---

## Technical Design

### Current Structure

#### Poetry Project
```
Manuscript/
  Front Matter/
  All Poems/          ← empty folder; ManuscriptBodyView pulls from Poems/ dynamically
  Back Matter/
Poems/                ← user's poem files live here
Collections/          ← navigates to CollectionsView (Submission objects with isCollection=true)
Submissions/
Research/
Magazines/
Competitions/
Other/
Trash/
```

#### Prose Project
```
Manuscript/
  Front Matter/
  All Sections/       ← empty folder; ManuscriptBodyView pulls from Prose/ grouped by ProseSection
  Back Matter/
Sections/             ← ProseSection list; each section references TextFiles
Prose/                ← user's prose files live here
Collections/
Submissions/
Research/
Publishers/
Agents/
Other/
Trash/
```

#### Fiction (Novel) Project
```
Manuscript/
  Front Matter/
  All Chapters/       ← empty folder; ManuscriptBodyView pulls from Chapter → Scene → TextFile
  Back Matter/
Chapters/             ← Chapter entities
Scenes/               ← StoryScene entities → TextFiles
Characters/
Locations/
Plot/
Collections/
Submissions/
Research/
Publishers/
Agents/
Other/
Trash/
```

#### Fiction (Short Fiction) Project
```
Manuscript/
  Front Matter/
  All Stories/        ← empty folder; ManuscriptBodyView pulls Scenes directly
  Back Matter/
Stories/
Scenes/
Characters/
Locations/
Plot/
Collections/
Submissions/
Research/
Magazines/
Competitions/
Other/
Trash/
```

#### Fiction (Verse Novel) Project
```
Manuscript/
  Front Matter/
  All Books/          ← empty folder; ManuscriptBodyView pulls from Chapter (Books) → Scene (Episodes)
  Back Matter/
Books/                ← currently uses Chapter entities (INCORRECT — should be distinct Book model)
Episodes/             ← StoryScene entities with poetry form → TextFiles
Characters/
Locations/
Plot/
Collections/
Submissions/
Research/
Publishers/
Agents/
Other/
Trash/
```

#### Drama Project
```
Manuscript/
  Front Matter/
  All Acts/           ← empty folder; ManuscriptBodyView pulls from Act → Scene → TextFile
  Back Matter/
Acts/                 ← Act entities
Scenes/
Characters/
Locations/
Plot/
Collections/
Submissions/
Research/
Publishers/
Agents/
Other/
Trash/
```

#### Key Implementation Details
- **"All X" folders** are persisted empty `Folder` objects inside Manuscript (userOrder=1). They hold no files — `ManuscriptAssemblyService` dynamically assembles body content from the source folders.
- **Collections** are `Submission` model objects with `isCollection = true`. Files in a collection are `SubmittedFile` link records. The "Collections" root folder navigates to `CollectionsView`.
- **"Add to Collection" button** appears in the FileListView edit toolbar for files with `.ready` workflow status. It creates `SubmittedFile` records linking the file's current version to a chosen `Submission` (collection).

### Proposed Structure

#### Poetry Project
```
Manuscript/
  Front Matter/
  Body Matter/        ← NEW: user adds Collections from the Collections folder
  Back Matter/
Collections/          ← NEW: Poetry-specific, between Manuscript and Poems
  [Collection 1]/     ← named collection; poems assigned to it
  [Collection 2]/
Poems/
Submissions/
Research/
Magazines/
Competitions/
Other/
Trash/
```

#### Prose Project
```
Manuscript/
  Front Matter/
  Body Matter/        ← RENAMED: user adds Sections from Sections folder
  Back Matter/
Sections/
Prose/
Submissions/          ← Collections folder REMOVED
Research/
Publishers/
Agents/
Other/
Trash/
```

#### Fiction (Novel) Project
```
Manuscript/
  Front Matter/
  Body Matter/        ← RENAMED: user adds Chapters from Chapters folder
  Back Matter/
Chapters/
Scenes/
Characters/
Locations/
Plot/
Submissions/          ← Collections folder REMOVED
Research/
Publishers/
Agents/
Other/
Trash/
```

#### Fiction (Short Fiction) Project
```
Manuscript/
  Front Matter/
  Body Matter/        ← RENAMED: user adds Stories
  Back Matter/
Stories/
Scenes/
Characters/
Locations/
Plot/
Submissions/          ← Collections folder REMOVED
Research/
Magazines/
Competitions/
Other/
Trash/
```

#### Fiction (Verse Novel) Project
```
Manuscript/
  Front Matter/
  Body Matter/        ← RENAMED: user adds Books from Books folder
  Back Matter/
Books/                ← Book entities (Episodes grouped into Books)
Episodes/             ← Episode files (scenes with poetry form)
Characters/
Locations/
Plot/
Submissions/          ← Collections folder REMOVED
Research/
Publishers/
Agents/
Other/
Trash/
```

#### Drama Project
```
Manuscript/
  Front Matter/
  Body Matter/        ← RENAMED: user adds Acts from Acts folder
  Back Matter/
Acts/
Scenes/
Characters/
Locations/
Plot/
Submissions/          ← Collections folder REMOVED
Research/
Publishers/
Agents/
Other/
Trash/
```

### New Models

#### PoetryCollection
```swift
@Model final class PoetryCollection {
    var id: UUID = UUID()
    var name: String?
    var userOrder: Int?
    var bodyMatterOrder: Int?
    var isInBodyMatter: Bool = false
    
    @Relationship(deleteRule: .nullify, inverse: \TextFile.poetryCollection)
    var textFiles: [TextFile]?
    
    @Relationship(inverse: \PoetryCollection.project)
    var project: Project?
}
```

#### Book (Verse Novel)
```swift
@Model final class Book {
    var id: UUID = UUID()
    var name: String?
    var userOrder: Int?
    var synopsis: String?
    var bodyMatterOrder: Int?
    var isInBodyMatter: Bool = false
    
    @Relationship(deleteRule: .nullify, inverse: \StoryScene.book)
    var scenes: [StoryScene]?
    
    var project: Project?
}
```

### Model Updates

**Project** — add relationships:
- `poetryCollections: [PoetryCollection]?` (cascade)
- `books: [Book]?` (cascade)

**TextFile** — add:
- `poetryCollection: PoetryCollection?`

**StoryScene** — add:
- `book: Book?` (for Verse Novel; `chapter` remains for Novel)

**Chapter, Act, ProseSection** — add:
- `bodyMatterOrder: Int?`
- `isInBodyMatter: Bool = false`

### ManuscriptAssemblyService Changes

`getBodySections(for:)` changes from pulling dynamically from source folders to pulling items marked `isInBodyMatter == true`, ordered by `bodyMatterOrder`:

| Project Type | Source | Query |
|---|---|---|
| Poetry | `PoetryCollection` | `isInBodyMatter == true`, ordered by `bodyMatterOrder`, then each collection's `textFiles` by `userOrder` |
| Prose | `ProseSection` | `isInBodyMatter == true`, ordered by `bodyMatterOrder`, then each section's `textFiles` by `userOrder` |
| Novel | `Chapter` | `isInBodyMatter == true`, ordered by `bodyMatterOrder`, then each chapter's `scenes` → `textFile` |
| Short Fiction | `StoryScene` | `isInBodyMatter == true`, ordered by `bodyMatterOrder` directly |
| Verse Novel | `Book` | `isInBodyMatter == true`, ordered by `bodyMatterOrder`, then each book's `scenes` (episodes) → `textFile` |
| Drama | `Act` | `isInBodyMatter == true`, ordered by `bodyMatterOrder`, then each act's `scenes` → `textFile` |

---

## Testing

### Test Cases - Models
- [ ] TC-1: Create PoetryCollection, assign poems, verify relationships
- [ ] TC-2: Verify bodyMatterOrder persistence and ordering
- [ ] TC-3: Verify isInBodyMatter flag behaviour
- [ ] TC-4: Deleting collection nullifies textFile relationships (does NOT delete poems)
- [ ] TC-5: Create Book, assign episodes, verify relationships
- [ ] TC-6: Book cascade delete behaviour correct

### Test Cases - Manuscript Assembly
- [ ] TC-7: Poetry: 2 collections in Body Matter → correct assembled content and order
- [ ] TC-8: Poetry: Collection NOT in Body Matter excluded from assembly
- [ ] TC-9: Prose: 2 sections in Body Matter → correct assembly order
- [ ] TC-10: Novel: Chapters in Body Matter in non-sequential order → correct output
- [ ] TC-11: Short Fiction: Stories in Body Matter → correct output
- [ ] TC-12: Verse Novel: Books in Body Matter → episodes in correct order
- [ ] TC-13: Drama: Acts in Body Matter → correct output
- [ ] TC-14: Front/back matter still correct alongside Body Matter

### Test Cases - Migration
- [ ] TC-15: Poetry project with old collections → PoetryCollection objects created
- [ ] TC-16: Poetry project with no collections → "Collection 1" created with all poems
- [ ] TC-17: Prose project → all sections get isInBodyMatter = true
- [ ] TC-18: Novel project → all chapters get isInBodyMatter = true
- [ ] TC-19: Short Fiction → all stories/scenes get isInBodyMatter = true
- [ ] TC-20: Verse Novel → Chapter entities migrated to Book entities
- [ ] TC-21: Drama → all acts get isInBodyMatter = true
- [ ] TC-22: "All X" folders renamed to "Body Matter"
- [ ] TC-23: Collections folder removed from non-Poetry projects
- [ ] TC-24: Migration idempotent — run twice, no duplicates

### Test Cases - UI
- [ ] TC-25: Poetry: Collections folder between Manuscript and Poems
- [ ] TC-26: Body Matter: add/remove/reorder items
- [ ] TC-27: "Add to Collection" button removed from FileListView toolbar
- [ ] TC-28: "PDF to Submission" button in Manuscript toolbar
- [ ] TC-29: Verse Novel: Books folder shows Book entities (not Chapters)

### Test Cases - CloudKit
- [ ] TC-30: Migration syncs correctly Device A → Device B
- [ ] TC-31: Body Matter content syncs across devices
- [ ] TC-32: Concurrent Body Matter edits on two devices

---

## Files Affected

### New Files
- `Models/PoetryCollection.swift` — PoetryCollection model
- `Models/Book.swift` — Book model (Verse Novel)
- `Views/Manuscript/BodyMatterView.swift` — Body Matter management view
- `Views/PoetryCollectionsView.swift` — Poetry collections list
- `Views/PoetryCollectionDetailView.swift` — Poems within a collection

### Modified Files
- `Models/BaseModels.swift` — Project, TextFile model updates
- `Models/StoryModels.swift` — Chapter, Act, ProseSection, StoryScene updates
- `Services/ProjectTemplateService.swift` — folder creation changes
- `Services/FolderCapabilityService.swift` — Body Matter capabilities
- `Services/ManuscriptAssemblyService.swift` — Body Matter-driven assembly
- `Services/MigrationService.swift` — Feature 036 migration
- `Views/FolderListView.swift` — Body Matter navigation
- `Views/Components/FileListView.swift` — remove Add to Collection button
- `Views/FolderFilesView+Helpers.swift` — remove supportsAddToCollection
- `Views/Fiction/ChapterListView.swift` — remove collection picker
- `Views/Drama/ActListView.swift` — remove collection picker
- `Views/Prose/SectionListView.swift` — remove collection picker

### Removed Files
- `Views/Components/CollectionPickerView.swift`
- `Views/CollectionsView.swift` (or deprecated)
