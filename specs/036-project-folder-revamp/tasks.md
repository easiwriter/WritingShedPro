# Feature 036: Project Folder Revamp - Task List

**Status:** Not Started  
**Start Date:** TBD  
**Target Completion:** ~18 days

---

## Phase 1: New Models & Model Updates (Days 1-2)

### Task 1.1: PoetryCollection Model
- [ ] Create `Models/PoetryCollection.swift`
- [ ] Define `@Model class PoetryCollection`
- [ ] Properties: `id`, `name`, `userOrder`, `bodyMatterOrder`, `isInBodyMatter`
- [ ] Relationship: `textFiles: [TextFile]?` (nullify)
- [ ] Relationship: `project: Project?`
- [ ] Add unit tests

### Task 1.2: Book Model (Verse Novel)
- [ ] Create `Models/Book.swift`
- [ ] Define `@Model class Book`
- [ ] Properties: `id`, `name`, `userOrder`, `synopsis`, `bodyMatterOrder`, `isInBodyMatter`
- [ ] Relationship: `scenes: [StoryScene]?` (nullify)
- [ ] Relationship: `project: Project?`
- [ ] Add unit tests

### Task 1.3: Update Project Model
- [ ] Add `poetryCollections: [PoetryCollection]?` (cascade)
- [ ] Add `books: [Book]?` (cascade)
- [ ] Verify model container includes new types

### Task 1.4: Update TextFile Model
- [ ] Add `poetryCollection: PoetryCollection?` relationship

### Task 1.5: Update StoryScene Model
- [ ] Add `book: Book?` relationship (Verse Novel)

### Task 1.6: Add Body Matter Fields
- [ ] `Chapter`: add `bodyMatterOrder: Int?`, `isInBodyMatter: Bool = false`
- [ ] `Act`: add `bodyMatterOrder: Int?`, `isInBodyMatter: Bool = false`
- [ ] `ProseSection`: add `bodyMatterOrder: Int?`, `isInBodyMatter: Bool = false`
- [ ] `StoryScene`: add `bodyMatterOrder: Int?`, `isInBodyMatter: Bool = false`

### Task 1.7: Register Models in Container
- [ ] Add `PoetryCollection.self` to model container
- [ ] Add `Book.self` to model container
- [ ] Verify app launches without schema errors

---

## Phase 2: Remove Old Collections System (Days 3-4)

### Task 2.1: Remove FileListView Collection Button
- [ ] Remove `onAddToCollection` callback
- [ ] Remove "Add to Collection" button from toolbar
- [ ] Remove associated state/sheets
- [ ] Verify `onSubmit` still works

### Task 2.2: Remove supportsAddToCollection
- [ ] Remove from `FolderFilesView+Helpers.swift`
- [ ] Remove references from `FolderFilesView.swift`

### Task 2.3: Remove Collection Pickers from List Views
- [ ] Remove from `ChapterListView`
- [ ] Remove from `ActListView`
- [ ] Remove from `SectionListView`
- [ ] Delete `CollectionPickerView.swift`

### Task 2.4: Deprecate Old CollectionsView
- [ ] Remove/deprecate `CollectionsView`
- [ ] Remove/deprecate `CollectionDetailView`
- [ ] Remove Collections navigation for non-Poetry projects
- [ ] Clean up `Submission.isCollection` usage

---

## Phase 3: ProjectTemplateService & FolderCapabilityService (Days 5-6)

### Task 3.1: Update Folder Creation — Poetry
- [ ] Move "Collections" folder between Manuscript and Poems
- [ ] Rename body subfolder "All Poems" → "Body Matter"
- [ ] Renumber userOrder values

### Task 3.2: Update Folder Creation — Prose
- [ ] Remove "Collections" folder
- [ ] Rename body subfolder "All Sections" → "Body Matter"
- [ ] Renumber userOrder values

### Task 3.3: Update Folder Creation — Fiction (All Sub-Types)
- [ ] Novel: remove "Collections", "All Chapters" → "Body Matter"
- [ ] Short Fiction: remove "Collections", "All Stories" → "Body Matter"
- [ ] Verse Novel: remove "Collections", "All Books" → "Body Matter", "Chapters"→"Books", "Scenes"→"Episodes"
- [ ] Renumber all userOrder values

### Task 3.4: Update Folder Creation — Drama
- [ ] Remove "Collections" folder
- [ ] Rename body subfolder "All Acts" → "Body Matter"
- [ ] Renumber userOrder values

### Task 3.5: Update FolderCapabilityService
- [ ] Remove "Collections" from readOnlyFolders (non-Poetry)
- [ ] Add "Body Matter" as editable folder type
- [ ] Update Poetry "Collections" to navigate to PoetryCollectionsView
- [ ] Update body folder name detection in FolderListView

---

## Phase 4: Body Matter View (Days 7-8)

### Task 4.1: BodyMatterView
- [ ] Create `Views/Manuscript/BodyMatterView.swift`
- [ ] List items in Body Matter ordered by `bodyMatterOrder`
- [ ] Handle all project types (Poetry/Prose/Novel/Short Fiction/Verse Novel/Drama)
- [ ] Add button with available items picker
- [ ] Swipe-to-remove (sets `isInBodyMatter = false`)
- [ ] Drag-to-reorder (updates `bodyMatterOrder`)
- [ ] Tap for content preview

### Task 4.2: FolderListView Navigation Update
- [ ] Navigate to BodyMatterView for "Body Matter" subfolder
- [ ] Remove/refactor ManuscriptBodyView navigation
- [ ] Update body folder detection sets

### Task 4.3: Body Matter Item Picker
- [ ] Create picker showing items NOT in Body Matter
- [ ] Set `isInBodyMatter = true` on selection
- [ ] Assign next sequential `bodyMatterOrder`

---

## Phase 5: Poetry Collections Views (Days 9-10)

### Task 5.1: PoetryCollectionsView
- [ ] Create `Views/PoetryCollectionsView.swift`
- [ ] List PoetryCollection objects
- [ ] Create new collection (name input)
- [ ] Rename/delete collections
- [ ] Reorder collections
- [ ] Navigate to PoetryCollectionDetailView on tap

### Task 5.2: PoetryCollectionDetailView
- [ ] Create `Views/PoetryCollectionDetailView.swift`
- [ ] List poems in collection ordered by userOrder
- [ ] Add poems (picker: Poems folder, `.ready` status)
- [ ] Remove poems (remove assignment only)
- [ ] Reorder poems

### Task 5.3: Poetry "Add to Collection" in Poems Folder
- [ ] Add "Add to Collection" button for `.ready` poems in edit mode
- [ ] Present PoetryCollection picker
- [ ] Set `poetryCollection` relationship on TextFile

### Task 5.4: FolderListView Collections Navigation
- [ ] Navigate to PoetryCollectionsView for Poetry "Collections" folder
- [ ] Verify non-Poetry projects have no Collections folder

---

## Phase 6: ManuscriptAssemblyService (Days 11-12)

### Task 6.1: Update getBodySections
- [ ] Poetry: PoetryCollection `isInBodyMatter == true` → textFiles
- [ ] Prose: ProseSection `isInBodyMatter == true` → textFiles
- [ ] Novel: Chapter `isInBodyMatter == true` → scenes → textFile
- [ ] Short Fiction: StoryScene `isInBodyMatter == true`
- [ ] Verse Novel: Book `isInBodyMatter == true` → scenes → textFile
- [ ] Drama: Act `isInBodyMatter == true` → scenes → textFile

### Task 6.2: Update/Remove getBodySourceFolderName
- [ ] Review if still needed
- [ ] Update or remove all callers

### Task 6.3: Manuscript Assembly Tests
- [ ] Test all 6 project types
- [ ] Test empty/partial/reordered Body Matter
- [ ] Test front/back matter unchanged

---

## Phase 7: PDF to Submission (Day 13)

### Task 7.1: Manuscript Toolbar Button
- [ ] Add "PDF to Submission" button to Manuscript toolbar
- [ ] Generate PDF from assembled manuscript
- [ ] Create new Submission with PDF
- [ ] Navigate to submission detail

---

## Phase 8: Migration (Days 14-15)

### Task 8.1: Rename "All X" to "Body Matter"
- [ ] Find body subfolder (userOrder=1) in each Manuscript
- [ ] Rename all variants → "Body Matter"

### Task 8.2: Poetry Collection Migration
- [ ] Convert `Submission` (isCollection=true) → `PoetryCollection`
- [ ] Migrate SubmittedFile links → poetryCollection relationship
- [ ] Delete old collection records
- [ ] Create "Collection 1" if no collections exist
- [ ] Set all as `isInBodyMatter = true`

### Task 8.3: Poetry Collections Folder Repositioning
- [ ] Set userOrder between Manuscript and Poems
- [ ] Renumber other folders

### Task 8.4: Non-Poetry Collections Folder Removal
- [ ] Migrate collection data to Submissions if needed
- [ ] Delete Collections folder

### Task 8.5: Populate Body Matter — Non-Poetry
- [ ] Prose: all ProseSection → `isInBodyMatter = true`
- [ ] Novel: all Chapter → `isInBodyMatter = true`
- [ ] Short Fiction: all StoryScene → `isInBodyMatter = true`
- [ ] Drama: all Act → `isInBodyMatter = true`

### Task 8.6: Verse Novel Chapter → Book Migration
- [ ] Create Book from each Chapter (name, userOrder, synopsis)
- [ ] Move scene assignments from chapter → book
- [ ] Set `isInBodyMatter = true`
- [ ] Handle old Chapter cleanup (CloudKit safe)

### Task 8.7: Cleanup & Safety
- [ ] Delete old collection SubmittedFiles
- [ ] Add UserDefaults migration flag
- [ ] Verify idempotency
- [ ] Add migration logging
- [ ] CloudKit-safe: never delete on missing relationships

---

## Phase 9: Testing (Days 16-18)

### Task 9.1: Unit Tests — Models
- [ ] PoetryCollection CRUD and relationships
- [ ] Book CRUD and relationships
- [ ] bodyMatterOrder / isInBodyMatter fields
- [ ] Cascade delete behaviours

### Task 9.2: Unit Tests — ManuscriptAssemblyService
- [ ] Body Matter assembly for all 6 project types
- [ ] Empty/partial/reordered Body Matter
- [ ] Front/back matter unchanged

### Task 9.3: Unit Tests — Migration
- [ ] Poetry with collections
- [ ] Poetry without collections
- [ ] All non-Poetry project types
- [ ] Verse Novel Chapter → Book
- [ ] Idempotency
- [ ] "All X" → "Body Matter" rename

### Task 9.4: Manual UI Tests
- [ ] Poetry collections end-to-end
- [ ] Body Matter add/remove/reorder (each project type)
- [ ] Manuscript preview/export/print
- [ ] Toolbar changes
- [ ] Upgrade migration

### Task 9.5: CloudKit Sync Tests
- [ ] Migration sync Device A → Device B
- [ ] Body Matter content sync
- [ ] Concurrent edits

---

## Final Checklist

- [ ] Old Collections removed from non-Poetry projects
- [ ] Poetry Collections work end-to-end
- [ ] Body Matter replaces "All X" in all project types
- [ ] Manuscript preview/export/print uses Body Matter
- [ ] Body Matter add/remove/reorder works
- [ ] PDF-to-Submission button works
- [ ] Verse Novel uses Book model
- [ ] Migration preserves all data
- [ ] CloudKit sync works
- [ ] All tests pass
- [ ] Code reviewed
