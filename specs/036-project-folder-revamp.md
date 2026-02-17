# Feature 036: Project Folder Revamp

## Overview

<!-- Describe the reorganisation goals here -->
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

## Current Structure

### Poetry Project
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

### Prose Project
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

### Fiction (Novel) Project
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

### Fiction (Short Fiction) Project
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

### Fiction (Verse Novel) Project
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

### Drama Project
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

### Key Implementation Details
- **"All X" folders** are persisted empty `Folder` objects inside Manuscript (userOrder=1). They hold no files — `ManuscriptAssemblyService` dynamically assembles body content from the source folders.
- **Collections** are `Submission` model objects with `isCollection = true`. Files in a collection are `SubmittedFile` link records. The "Collections" root folder navigates to `CollectionsView`.
- **"Add to Collection" button** appears in the FileListView edit toolbar for files with `.ready` workflow status. It creates `SubmittedFile` records linking the file's current version to a chosen `Submission` (collection).

## Proposed Structure

### Poetry Project
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

### Prose Project
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

### Fiction (Novel) Project
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

### Fiction (Short Fiction) Project
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

### Fiction (Verse Novel) Project
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

### Drama Project
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

### Key Differences
- **Collections folder removed** from Prose, Fiction and Drama projects
- **Collections folder repurposed** in Poetry — now a first-class grouping mechanism (like Sections in Prose), positioned between Manuscript and Poems
- **"All X" manuscript subfolders replaced** with user-managed "Body Matter" folders across all project types
- **Manuscript assembly** changes from dynamic source-folder aggregation to explicit "assemble what's in Body Matter"
- **"Add to Collection" button removed** from FileListView toolbar; replaced by "Add to Submission"

## Changes Required

### 1. New Model: PoetryCollection
Create a new SwiftData `@Model` class for Poetry collections (do NOT reuse the `Submission` model which currently doubles as collections):
- `id: UUID = UUID()`
- `name: String?`
- `userOrder: Int?`
- `project: Project?` (inverse on Project)
- `textFiles: [TextFile]?` (nullify; inverse on TextFile — new `poetryCollection: PoetryCollection?` property)
- `bodyMatterOrder: Int?` — position within Body Matter (nil if not added to Body Matter)
- `isInBodyMatter: Bool = false`

> **Design note**: The `ProseSection` pattern is the closest precedent. `ProseSection` has `textFiles: [TextFile]?` and `userOrder`. The new `PoetryCollection` follows the same shape. The `bodyMatterOrder` and `isInBodyMatter` fields track whether the collection has been added to Body Matter and in what order.

### 2. Update Existing Models

**Project** — add relationship:
- `poetryCollections: [PoetryCollection]?` (cascade, inverse `\PoetryCollection.project`)

**TextFile** — add optional relationship:
- `poetryCollection: PoetryCollection?` (inverse `\PoetryCollection.textFiles`)

**Chapter, Act, ProseSection** — add Body Matter tracking fields:
- `bodyMatterOrder: Int?`
- `isInBodyMatter: Bool = false`

**Verse Novel: New Book Model** — The current codebase incorrectly reuses `Chapter` entities for Verse Novel Books. Create a new `@Model` class `Book`:
- `id: UUID = UUID()`
- `name: String?`
- `userOrder: Int?`
- `synopsis: String?`
- `bodyMatterOrder: Int?`
- `isInBodyMatter: Bool = false`
- `project: Project?` (inverse on Project)
- `scenes: [StoryScene]?` (nullify) — episodes within this book

**Project** — add relationship:
- `books: [Book]?` (cascade, inverse `\Book.project`)

**StoryScene** — add optional relationship:
- `book: Book?` (inverse `\Book.scenes`) — used only for Verse Novel; `chapter` is for Novel

> These fields let `ManuscriptAssemblyService` know which items are in Body Matter and in what order, without needing a separate join model.

### 3. ProjectTemplateService Changes

**Poetry projects:**
- Remove "Collections" from the old position (after Poems)
- Add new "Collections" folder at userOrder between Manuscript and Poems
- Update `createManuscriptSubfolders()`: rename body subfolder from "All Poems" to "Body Matter"

**Prose projects:**
- Remove "Collections" folder
- Update `createManuscriptSubfolders()`: rename body subfolder from "All Sections" to "Body Matter"
- Renumber `userOrder` for remaining folders

**Fiction (Novel) projects:**
- Remove "Collections" folder
- Update `createManuscriptSubfolders()`: rename body subfolder from "All Chapters" to "Body Matter"
- Renumber `userOrder`

**Fiction (Short Fiction) projects:**
- Remove "Collections" folder
- Update `createManuscriptSubfolders()`: rename body subfolder from "All Stories" to "Body Matter"
- Renumber `userOrder`

**Fiction (Verse Novel) projects:**
- Remove "Collections" folder
- Update `createManuscriptSubfolders()`: rename body subfolder from "All Books" to "Body Matter"
- Change folder creation to use "Books" and "Episodes" instead of "Chapters" and "Scenes"
- Renumber `userOrder`

**Drama projects:**
- Remove "Collections" folder
- Update `createManuscriptSubfolders()`: rename body subfolder from "All Acts" to "Body Matter"
- Renumber `userOrder`

### 4. FolderCapabilityService Changes
- Remove "Collections" from `readOnlyFolders` for non-Poetry project types
- Add "Body Matter" as a new folder type — user-editable (add/remove/reorder items), but not a file-creation folder
- Update Poetry "Collections" folder capabilities to support creating/managing `PoetryCollection` objects

### 5. ManuscriptAssemblyService Changes
- **`getBodySections(for:)`**: Change from pulling dynamically from source folders to pulling items marked `isInBodyMatter == true`, ordered by `bodyMatterOrder`
  - Poetry: fetch `PoetryCollection` objects where `isInBodyMatter == true`, ordered by `bodyMatterOrder`, then for each collection fetch its `textFiles` ordered by `userOrder`
  - Prose: fetch `ProseSection` objects where `isInBodyMatter == true`, ordered by `bodyMatterOrder`, then each section's `textFiles` ordered by `userOrder`
  - Fiction (Novel): fetch `Chapter` objects where `isInBodyMatter == true`, ordered by `bodyMatterOrder`, then each chapter's `scenes` → `textFile`
  - Fiction (Short Fiction): flat scene list, scenes marked `isInBodyMatter` directly
  - Fiction (Verse Novel): fetch `Book` objects where `isInBodyMatter == true`, ordered by `bodyMatterOrder`, then each book's `scenes` (episodes) → `textFile`
  - Drama: fetch `Act` objects where `isInBodyMatter == true`, ordered by `bodyMatterOrder`, then each act's `scenes` → `textFile`
- **`assembleContent(for:)`**: No structural change — still concatenates sections in order

### 6. FolderListView Changes
- When user taps "Body Matter" subfolder, navigate to new **BodyMatterView** (replaces `ManuscriptBodyView` navigation)
- `ManuscriptBodyView` may be retired or refactored into `BodyMatterView`

### 7. New View: BodyMatterView
A view for managing the contents of the Body Matter folder:
- **List display**: Shows items currently in Body Matter, ordered by `bodyMatterOrder`
  - Poetry: list of `PoetryCollection` names
  - Prose: list of `ProseSection` names
  - Fiction (Novel): list of `Chapter` names
  - Fiction (Short Fiction): list of `StoryScene` names
  - Fiction (Verse Novel): list of `Book` names
  - Drama: list of `Act` names
- **Add button**: Presents a picker showing available items NOT yet in Body Matter
- **Remove**: Swipe-to-remove (sets `isInBodyMatter = false`, does NOT delete the source item)
- **Reorder**: Drag to reorder (updates `bodyMatterOrder`)
- **Preview**: Tapping an item shows its content (read-only aggregated view)

### 8. New View: PoetryCollectionsView
Replaces old `CollectionsView` for Poetry projects:
- List of `PoetryCollection` objects for the project
- Create new collection (name input)
- Tap to navigate to `PoetryCollectionDetailView`
- Reorder collections

### 9. New View: PoetryCollectionDetailView
Shows poems in a collection:
- List of `TextFile` objects assigned to this collection, ordered by `userOrder`
- Add poems (picker showing poems from the Poems folder with `.ready` status)
- Remove poems (removes assignment, does NOT delete the poem)
- Reorder poems within the collection

### 10. FileListView Toolbar Changes
- **Remove** "Add to Collection" button and `onAddToCollection` callback
- **Replace** with "Add to Submission" button functionality (the existing `onSubmit` callback)
- Remove `supportsAddToCollection` from `FolderFilesView+Helpers.swift`
- Update `ChapterListView`, `ActListView`, `SectionListView` to remove collection picker references
- Remove `CollectionPickerView` component

### 11. Poetry Poems Folder: Add to Collection
In the Poems folder for Poetry projects, add ability to assign poems to collections:
- In edit mode, show "Add to Collection" button for poems with `.ready` status
- Present a picker of `PoetryCollection` objects (similar to `SectionPickerSheet` pattern)
- Creates the `poetryCollection` relationship on the `TextFile`

### 12. Manuscript Toolbar: PDF to Submission Button
Add a button to the Manuscript toolbar (all project types):
- Generates PDF from current manuscript (Front Matter + Body Matter + Back Matter)
- Creates a new `Submission` with the PDF attached
- Navigates to submission detail for the user to complete (select publication, etc.)

### 13. Old Collections Cleanup
- Remove or deprecate `CollectionsView` and `CollectionDetailView` (the old `Submission`-based collections)
- Remove `CollectionPickerView`
- Clean up `Submission.isCollection` usage — all `Submission` objects should now be actual submissions (`isCollection = false`)
- Old `SubmittedFile` records that were collection assignments need migration handling

## Migration

### MigrationService Additions

Add new static method `migrateToFeature036(context:)` called from `runMigrations()`:

#### Step 1: Rename "All X" to "Body Matter"
For all projects, find the Manuscript folder's body subfolder (userOrder=1) and rename:
- "All Poems" → "Body Matter"
- "All Sections" → "Body Matter"
- "All Chapters" → "Body Matter"
- "All Stories" → "Body Matter"
- "All Acts" → "Body Matter"
- "All Books" → "Body Matter"

#### Step 2: Poetry — Migrate Collection Data
For each Poetry project:
1. Query all `Submission` objects where `isCollection == true` and `project == thisProject`
2. For each old collection:
   - Create a `PoetryCollection` with the same name and project
   - For each `SubmittedFile` in the old collection, set `textFile.poetryCollection = newCollection`
   - Delete the old `SubmittedFile` records
   - Delete the old `Submission` (collection) record
3. If no old collections exist but there are poems, create "Collection 1" containing all poems from the Poems folder
4. Mark all migrated `PoetryCollection` objects as `isInBodyMatter = true` with sequential `bodyMatterOrder`

#### Step 3: Poetry — Reposition Collections Folder
For Poetry projects:
- Find the "Collections" root folder
- Set its `userOrder` to place it between Manuscript and Poems
- Renumber other folders as needed

#### Step 4: Non-Poetry — Remove Collections Folder
For Prose, Fiction, and Drama projects:
- Find the "Collections" root folder
- If it has no associated data (no `Submission` objects with `isCollection == true`), delete the folder
- If it has data, migrate the collection data to the Submissions folder first, then delete

#### Step 5: Non-Poetry — Populate Body Matter
For each non-Poetry project:
- **Prose**: Set all `ProseSection` objects to `isInBodyMatter = true`, `bodyMatterOrder = userOrder`
- **Fiction (Novel)**: Set all `Chapter` objects to `isInBodyMatter = true`, `bodyMatterOrder = userOrder`
- **Fiction (Short Fiction)**: Set all `StoryScene` objects to `isInBodyMatter = true`, `bodyMatterOrder = userOrder` (may need `StoryScene.isInBodyMatter` and `StoryScene.bodyMatterOrder` fields)
- **Fiction (Verse Novel)**: Migrate existing `Chapter` entities to new `Book` entities, preserving scene (episode) assignments. Set all `Book` objects to `isInBodyMatter = true`, `bodyMatterOrder = userOrder`. Update `StoryScene.book` relationship (replacing `StoryScene.chapter`).
- **Drama**: Set all `Act` objects to `isInBodyMatter = true`, `bodyMatterOrder = userOrder`

#### Step 6: Clean Up Old Collection SubmittedFiles
For all projects, delete any remaining `SubmittedFile` records where `submission.isCollection == true` and `submission.publication == nil`.

### Migration Safety (CloudKit)
- Migration must be **idempotent** — safe to run multiple times
- Never delete based on missing relationships (CloudKit sync lag)
- Use a `UserDefaults` flag (`hasRunFeature036Migration`) to skip already-migrated devices, but keep the migration code safe to re-run
- Log all migration actions for debugging

## Testing

### Unit Tests

#### PoetryCollection Model Tests
- Create a `PoetryCollection`, assign poems, verify relationships
- Verify `bodyMatterOrder` persistence and ordering
- Verify `isInBodyMatter` flag behaviour
- Test cascade delete behaviour (deleting collection should nullify textFile relationships, not delete poems)

#### ManuscriptAssemblyService Tests
- Poetry: Add 2 collections to Body Matter, verify assembled content includes poems from both in correct order
- Poetry: Collection not in Body Matter should be excluded from assembly
- Prose: Add 2 sections to Body Matter, verify assembly order matches `bodyMatterOrder`
- Fiction (Novel): Add chapters to Body Matter in non-sequential order, verify correct output
- Fiction (Short Fiction): Add stories to Body Matter, verify correct output
- Fiction (Verse Novel): Add books to Body Matter, verify books contain episodes in correct order
- Drama: Add acts to Body Matter, verify correct output
- Verify front/back matter still included correctly alongside new Body Matter

#### Migration Tests
- Migrate a Poetry project with old-style collections → verify `PoetryCollection` objects created
- Migrate a Poetry project with no collections → verify "Collection 1" created with all poems
- Migrate a Prose project → verify all sections get `isInBodyMatter = true`
- Migrate a Novel project → verify all chapters get `isInBodyMatter = true`
- Migrate a Short Fiction project → verify all stories/scenes get `isInBodyMatter = true`
- Migrate a Verse Novel project → verify `Chapter` entities migrated to `Book` entities with episode assignments preserved
- Migrate a Drama project → verify all acts get `isInBodyMatter = true`
- Verify "All X" folders renamed to "Body Matter"
- Verify Collections folder removed from non-Poetry projects
- Verify idempotency — run migration twice, no duplicates or errors

### Manual / UI Tests

#### Poetry: Collections Management
- Create a new Poetry project → verify Collections folder appears between Manuscript and Poems
- Create a new collection, name it
- Add poems with `.ready` status to the collection
- Navigate to Body Matter → add the collection
- Preview/Export manuscript → verify poems from the collection appear in body
- Reorder collections in Body Matter → verify preview order changes
- Remove a collection from Body Matter → verify it's excluded from preview but still exists in Collections folder

#### Prose: Body Matter Management
- Create a Prose project → verify Body Matter replaces All Sections in Manuscript
- Add sections to Body Matter → verify preview includes them
- Remove a section from Body Matter → verify it's excluded from preview
- Reorder sections → verify export order

#### Fiction (Novel): Body Matter Management
- Create a Novel project → verify Body Matter replaces All Chapters
- Add/remove/reorder chapters in Body Matter
- Verify manuscript preview reflects Body Matter contents and order

#### Fiction (Short Fiction): Body Matter Management
- Create a Short Fiction project → verify Body Matter replaces All Stories
- Add/remove/reorder stories in Body Matter
- Verify manuscript preview reflects Body Matter contents and order

#### Fiction (Verse Novel): Body Matter Management
- Create a Verse Novel project → verify Body Matter replaces All Books
- Verify Books folder shows Book entities (not Chapter entities)
- Verify Episodes folder shows episodes (scenes with poetry form)
- Add episodes to a Book, add Books to Body Matter
- Reorder Books in Body Matter → verify preview order changes
- Verify manuscript preview includes episode content from Books in correct order

#### Drama: Body Matter Management
- Create a Drama project → verify Body Matter replaces All Acts
- Add/remove/reorder acts in Body Matter
- Verify manuscript preview reflects Body Matter contents and order

#### Toolbar Changes
- Open any content folder in edit mode → verify "Add to Collection" button is gone
- Select files with `.ready` status → verify "Add to Submission" / submit button works
- Open Manuscript → verify "PDF to Submission" button present and functional

#### Migration (Upgrade Testing)
- Create projects of each type with the OLD app version (with Collections data)
- Upgrade to new version → verify migration runs cleanly
- Verify no data loss — all poems, sections, chapters, acts preserved
- Verify Body Matter pre-populated with all existing items
- Verify old Collections data migrated correctly for Poetry projects

#### CloudKit Sync
- Migrate on Device A → verify Device B receives migrated data correctly
- Create Body Matter content on Device A → verify it syncs to Device B
- Test concurrent edits to Body Matter on two devices
