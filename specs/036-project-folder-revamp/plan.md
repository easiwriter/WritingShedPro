# Feature 036: Project Folder Revamp - Implementation Plan

## Overview

This plan outlines the implementation of the Project Folder Revamp for Writing Shed Pro. The key changes are: removing the old Collections system, introducing Poetry-specific collections, replacing "All X" manuscript subfolders with user-managed Body Matter, and fixing the Verse Novel Book/Episode model.

**Estimated Duration:** 2-3 weeks  
**Dependencies:** None (builds on existing models and services)

---

## Implementation Phases

### Phase 1: New Models & Model Updates (Days 1-2)
**Goal:** Create new SwiftData models and update existing ones

#### Task 1.1: PoetryCollection Model
- [ ] Create `Models/PoetryCollection.swift`
- [ ] Define `@Model class PoetryCollection` with: `id`, `name`, `userOrder`, `bodyMatterOrder`, `isInBodyMatter`
- [ ] Add `textFiles: [TextFile]?` relationship (nullify)
- [ ] Add `project: Project?` relationship
- [ ] All attributes optional or with defaults (CloudKit requirement)
- [ ] Add unit tests

**File:** `WrtingShedPro/Writing Shed Pro/Models/PoetryCollection.swift`

#### Task 1.2: Book Model (Verse Novel)
- [ ] Create `Models/Book.swift`
- [ ] Define `@Model class Book` with: `id`, `name`, `userOrder`, `synopsis`, `bodyMatterOrder`, `isInBodyMatter`
- [ ] Add `scenes: [StoryScene]?` relationship (nullify) — episodes within this book
- [ ] Add `project: Project?` relationship
- [ ] All attributes optional or with defaults (CloudKit requirement)
- [ ] Add unit tests

**File:** `WrtingShedPro/Writing Shed Pro/Models/Book.swift`

#### Task 1.3: Update Project Model
- [ ] Add `poetryCollections: [PoetryCollection]?` relationship (cascade)
- [ ] Add `books: [Book]?` relationship (cascade)
- [ ] Verify model container includes new model types

**File to modify:** `WrtingShedPro/Writing Shed Pro/Models/BaseModels.swift`

#### Task 1.4: Update TextFile Model
- [ ] Add `poetryCollection: PoetryCollection?` optional relationship
- [ ] Verify inverse relationship with PoetryCollection.textFiles

**File to modify:** `WrtingShedPro/Writing Shed Pro/Models/BaseModels.swift`

#### Task 1.5: Update StoryScene Model
- [ ] Add `book: Book?` optional relationship (for Verse Novel)
- [ ] Verify inverse relationship with Book.scenes
- [ ] Existing `chapter: Chapter?` relationship unchanged (for Novel)

**File to modify:** `WrtingShedPro/Writing Shed Pro/Models/StoryModels.swift`

#### Task 1.6: Add Body Matter Fields
- [ ] Add `bodyMatterOrder: Int?` and `isInBodyMatter: Bool = false` to `Chapter`
- [ ] Add `bodyMatterOrder: Int?` and `isInBodyMatter: Bool = false` to `Act`
- [ ] Add `bodyMatterOrder: Int?` and `isInBodyMatter: Bool = false` to `ProseSection`
- [ ] Add `bodyMatterOrder: Int?` and `isInBodyMatter: Bool = false` to `StoryScene` (for Short Fiction)

**File to modify:** `WrtingShedPro/Writing Shed Pro/Models/StoryModels.swift`

#### Task 1.7: Register Models in Container
- [ ] Add `PoetryCollection.self` and `Book.self` to the SwiftData model container
- [ ] Verify app launches without schema errors

**File to modify:** `WrtingShedPro/Writing Shed Pro/Writing_Shed_ProApp.swift` (or wherever `ModelContainer` is configured)

---

### Phase 2: Remove Old Collections System (Days 3-4)
**Goal:** Remove the existing Collection functionality from all project types

#### Task 2.1: Remove FileListView Collection Button
- [ ] Remove `onAddToCollection` callback parameter from `FileListView`
- [ ] Remove "Add to Collection" button from edit mode toolbar
- [ ] Remove associated state variables and sheet presentations
- [ ] Verify existing `onSubmit` callback still works

**File to modify:** `WrtingShedPro/Writing Shed Pro/Views/Components/FileListView.swift`

#### Task 2.2: Remove supportsAddToCollection
- [ ] Remove `supportsAddToCollection` computed property
- [ ] Remove any references to it in `FolderFilesView`

**Files to modify:**
- `WrtingShedPro/Writing Shed Pro/Views/FolderFilesView+Helpers.swift`
- `WrtingShedPro/Writing Shed Pro/Views/FolderFilesView.swift`

#### Task 2.3: Remove Collection Pickers from List Views
- [ ] Remove collection picker from `ChapterListView`
- [ ] Remove collection picker from `ActListView`
- [ ] Remove collection picker from `SectionListView`
- [ ] Remove `CollectionPickerView` component

**Files to modify:**
- `WrtingShedPro/Writing Shed Pro/Views/Fiction/ChapterListView.swift`
- `WrtingShedPro/Writing Shed Pro/Views/Drama/ActListView.swift`
- `WrtingShedPro/Writing Shed Pro/Views/Prose/SectionListView.swift`

**File to remove:** `WrtingShedPro/Writing Shed Pro/Views/Components/CollectionPickerView.swift`

#### Task 2.4: Deprecate Old CollectionsView
- [ ] Remove or deprecate `CollectionsView` and `CollectionDetailView`
- [ ] Remove navigation to CollectionsView from FolderListView for non-Poetry projects
- [ ] Clean up `Submission.isCollection` usage

**File to modify/remove:** `WrtingShedPro/Writing Shed Pro/Views/CollectionsView.swift`

---

### Phase 3: ProjectTemplateService & FolderCapabilityService (Days 5-6)
**Goal:** Update project creation and folder capabilities

#### Task 3.1: Update Folder Creation — Poetry
- [ ] Remove "Collections" from old position (after Poems)
- [ ] Add "Collections" folder at userOrder between Manuscript and Poems
- [ ] Rename body subfolder from "All Poems" to "Body Matter" in `createManuscriptSubfolders()`
- [ ] Renumber folder userOrder values

**File to modify:** `WrtingShedPro/Writing Shed Pro/Services/ProjectTemplateService.swift`

#### Task 3.2: Update Folder Creation — Prose
- [ ] Remove "Collections" folder from template
- [ ] Rename body subfolder from "All Sections" to "Body Matter"
- [ ] Renumber folder userOrder values

**File to modify:** `WrtingShedPro/Writing Shed Pro/Services/ProjectTemplateService.swift`

#### Task 3.3: Update Folder Creation — Fiction (All Sub-Types)
- [ ] Novel: Remove "Collections", rename "All Chapters" → "Body Matter"
- [ ] Short Fiction: Remove "Collections", rename "All Stories" → "Body Matter"
- [ ] Verse Novel: Remove "Collections", rename "All Books" → "Body Matter", change "Chapters"→"Books" and "Scenes"→"Episodes"
- [ ] Renumber folder userOrder values for all

**File to modify:** `WrtingShedPro/Writing Shed Pro/Services/ProjectTemplateService.swift`

#### Task 3.4: Update Folder Creation — Drama
- [ ] Remove "Collections" folder from template
- [ ] Rename body subfolder from "All Acts" to "Body Matter"
- [ ] Renumber folder userOrder values

**File to modify:** `WrtingShedPro/Writing Shed Pro/Services/ProjectTemplateService.swift`

#### Task 3.5: Update FolderCapabilityService
- [ ] Remove "Collections" from `readOnlyFolders` for non-Poetry project types
- [ ] Add "Body Matter" as a new folder type (user-editable: add/remove/reorder, but not file creation)
- [ ] Update Poetry "Collections" folder to navigate to new `PoetryCollectionsView`
- [ ] Update FolderListView body folder name detection to include "Body Matter"

**Files to modify:**
- `WrtingShedPro/Writing Shed Pro/Services/FolderCapabilityService.swift`
- `WrtingShedPro/Writing Shed Pro/Views/FolderListView.swift`

---

### Phase 4: Body Matter View (Days 7-8)
**Goal:** Create the new Body Matter management view

#### Task 4.1: BodyMatterView
- [ ] Create `Views/Manuscript/BodyMatterView.swift`
- [ ] Accept project as parameter, determine items based on project type
- [ ] List display: show items currently in Body Matter, ordered by `bodyMatterOrder`
  - Poetry → PoetryCollection names
  - Prose → ProseSection names
  - Novel → Chapter names
  - Short Fiction → StoryScene names
  - Verse Novel → Book names
  - Drama → Act names
- [ ] Add button: picker showing available items NOT yet in Body Matter
- [ ] Remove: swipe-to-remove (sets `isInBodyMatter = false`)
- [ ] Reorder: drag to reorder (updates `bodyMatterOrder`)
- [ ] Tapping an item shows content preview (read-only)

**File:** `WrtingShedPro/Writing Shed Pro/Views/Manuscript/BodyMatterView.swift`

#### Task 4.2: FolderListView Navigation Update
- [ ] When user taps "Body Matter" subfolder, navigate to `BodyMatterView`
- [ ] Remove/refactor `ManuscriptBodyView` navigation for "All X" folders
- [ ] Update body folder name detection sets

**File to modify:** `WrtingShedPro/Writing Shed Pro/Views/FolderListView.swift`

#### Task 4.3: Body Matter Item Picker
- [ ] Create picker/sheet for adding items to Body Matter
- [ ] Show items from source folder that are NOT yet in Body Matter
- [ ] On selection, set `isInBodyMatter = true` and assign next `bodyMatterOrder`

**File:** `WrtingShedPro/Writing Shed Pro/Views/Manuscript/BodyMatterView.swift` (or separate component)

---

### Phase 5: Poetry Collections Views (Days 9-10)
**Goal:** Create Poetry-specific collections management

#### Task 5.1: PoetryCollectionsView
- [ ] Create `Views/PoetryCollectionsView.swift`
- [ ] List `PoetryCollection` objects for the project
- [ ] Create new collection (name input)
- [ ] Rename/delete collections
- [ ] Reorder collections
- [ ] Tap to navigate to `PoetryCollectionDetailView`

**File:** `WrtingShedPro/Writing Shed Pro/Views/PoetryCollectionsView.swift`

#### Task 5.2: PoetryCollectionDetailView
- [ ] Create `Views/PoetryCollectionDetailView.swift`
- [ ] List TextFile objects assigned to this collection, ordered by `userOrder`
- [ ] Add poems button: picker showing poems from Poems folder with `.ready` status
- [ ] Remove poems (removes assignment, does NOT delete the poem)
- [ ] Reorder poems within collection

**File:** `WrtingShedPro/Writing Shed Pro/Views/PoetryCollectionDetailView.swift`

#### Task 5.3: Poetry Folder "Add to Collection"
- [ ] In Poems folder edit mode, add "Add to Collection" button for `.ready` poems
- [ ] Present picker of `PoetryCollection` objects (follow `SectionPickerSheet` pattern)
- [ ] Create `poetryCollection` relationship on TextFile

**Files to modify:**
- `WrtingShedPro/Writing Shed Pro/Views/FolderFilesView.swift`
- `WrtingShedPro/Writing Shed Pro/Views/FolderFilesView+Helpers.swift`

#### Task 5.4: FolderListView Collections Navigation
- [ ] When navigating to "Collections" folder in Poetry project, show `PoetryCollectionsView`
- [ ] Ensure non-Poetry projects no longer have Collections folder

**File to modify:** `WrtingShedPro/Writing Shed Pro/Views/FolderListView.swift`

---

### Phase 6: ManuscriptAssemblyService (Days 11-12)
**Goal:** Update manuscript assembly to use Body Matter

#### Task 6.1: Update getBodySections
- [ ] Poetry: fetch `PoetryCollection` with `isInBodyMatter == true`, ordered by `bodyMatterOrder`, then textFiles by `userOrder`
- [ ] Prose: fetch `ProseSection` with `isInBodyMatter == true`, ordered by `bodyMatterOrder`, then textFiles by `userOrder`
- [ ] Novel: fetch `Chapter` with `isInBodyMatter == true`, ordered by `bodyMatterOrder`, then scenes → textFile
- [ ] Short Fiction: fetch `StoryScene` with `isInBodyMatter == true`, ordered by `bodyMatterOrder`
- [ ] Verse Novel: fetch `Book` with `isInBodyMatter == true`, ordered by `bodyMatterOrder`, then scenes (episodes) → textFile
- [ ] Drama: fetch `Act` with `isInBodyMatter == true`, ordered by `bodyMatterOrder`, then scenes → textFile

**File to modify:** `WrtingShedPro/Writing Shed Pro/Services/ManuscriptAssemblyService.swift`

#### Task 6.2: Update getBodySourceFolderName
- [ ] This method may no longer be needed (Body Matter is explicit, not folder-based)
- [ ] Review all callers and update or remove

**File to modify:** `WrtingShedPro/Writing Shed Pro/Services/ManuscriptAssemblyService.swift`

#### Task 6.3: Manuscript Assembly Tests
- [ ] Test all project types with Body Matter assembly
- [ ] Test empty Body Matter (no content)
- [ ] Test partial Body Matter (some items excluded)
- [ ] Test reordered Body Matter
- [ ] Verify front/back matter still works correctly

---

### Phase 7: PDF to Submission (Day 13)
**Goal:** Add PDF-to-submission button in Manuscript toolbar

#### Task 7.1: Manuscript Toolbar Button
- [ ] Add "PDF to Submission" button to Manuscript toolbar (all project types)
- [ ] Wire to PDF generation from assembled manuscript
- [ ] Create new Submission record with PDF data
- [ ] Navigate to submission detail for user to complete

**File to modify:** `WrtingShedPro/Writing Shed Pro/Views/FolderListView.swift`

---

### Phase 8: Migration (Days 14-15)
**Goal:** Migrate existing projects to new structure

#### Task 8.1: Rename "All X" to "Body Matter"
- [ ] For all projects, find Manuscript body subfolder (userOrder=1)
- [ ] Rename: "All Poems" / "All Sections" / "All Chapters" / "All Stories" / "All Books" / "All Acts" → "Body Matter"

**File to modify:** `WrtingShedPro/Writing Shed Pro/Services/MigrationService.swift`

#### Task 8.2: Poetry Collection Migration
- [ ] Query `Submission` objects where `isCollection == true` per Poetry project
- [ ] Create `PoetryCollection` with same name for each
- [ ] Migrate `SubmittedFile` links to `textFile.poetryCollection`
- [ ] Delete old SubmittedFile and Submission (collection) records
- [ ] If no collections exist, create "Collection 1" with all poems from Poems folder
- [ ] Set all as `isInBodyMatter = true` with sequential `bodyMatterOrder`

**File to modify:** `WrtingShedPro/Writing Shed Pro/Services/MigrationService.swift`

#### Task 8.3: Poetry Collections Folder Repositioning
- [ ] Find "Collections" root folder in Poetry projects
- [ ] Set `userOrder` to place between Manuscript and Poems
- [ ] Renumber other folders

**File to modify:** `WrtingShedPro/Writing Shed Pro/Services/MigrationService.swift`

#### Task 8.4: Non-Poetry Collections Folder Removal
- [ ] Find "Collections" folder in Prose, Fiction, Drama projects
- [ ] Migrate any collection data to Submissions if needed
- [ ] Delete the Collections folder

**File to modify:** `WrtingShedPro/Writing Shed Pro/Services/MigrationService.swift`

#### Task 8.5: Populate Body Matter — Non-Poetry
- [ ] Prose: set all `ProseSection` → `isInBodyMatter = true`, `bodyMatterOrder = userOrder`
- [ ] Novel: set all `Chapter` → `isInBodyMatter = true`, `bodyMatterOrder = userOrder`
- [ ] Short Fiction: set all `StoryScene` → `isInBodyMatter = true`, `bodyMatterOrder = userOrder`
- [ ] Drama: set all `Act` → `isInBodyMatter = true`, `bodyMatterOrder = userOrder`

**File to modify:** `WrtingShedPro/Writing Shed Pro/Services/MigrationService.swift`

#### Task 8.6: Verse Novel Chapter → Book Migration
- [ ] For each Verse Novel project, fetch all `Chapter` entities
- [ ] Create `Book` entity with same name, userOrder, synopsis
- [ ] Move scene (episode) assignments from `chapter` to `book` relationship
- [ ] Set `isInBodyMatter = true`, `bodyMatterOrder = userOrder`
- [ ] Delete old Chapter entities (or leave orphaned if CloudKit concerns)

**File to modify:** `WrtingShedPro/Writing Shed Pro/Services/MigrationService.swift`

#### Task 8.7: Cleanup & Safety
- [ ] Delete remaining `SubmittedFile` records where `submission.isCollection == true`
- [ ] Add `hasRunFeature036Migration` UserDefaults flag
- [ ] Make migration idempotent
- [ ] Add logging for all migration actions
- [ ] Never delete based on missing relationships (CloudKit safety)

**File to modify:** `WrtingShedPro/Writing Shed Pro/Services/MigrationService.swift`

---

### Phase 9: Testing (Days 16-18)
**Goal:** Comprehensive testing of all changes

#### Task 9.1: Unit Tests — Models
- [ ] Test PoetryCollection CRUD and relationships
- [ ] Test Book CRUD and relationships
- [ ] Test bodyMatterOrder / isInBodyMatter on Chapter, Act, ProseSection
- [ ] Test cascade delete behaviours

#### Task 9.2: Unit Tests — ManuscriptAssemblyService
- [ ] Test Body Matter assembly for all 6 project types
- [ ] Test empty/partial/reordered Body Matter
- [ ] Test front/back matter unchanged

#### Task 9.3: Unit Tests — Migration
- [ ] Test Poetry migration with collections
- [ ] Test Poetry migration without collections
- [ ] Test all non-Poetry project type migrations
- [ ] Test Verse Novel Chapter → Book migration
- [ ] Test idempotency
- [ ] Test "All X" → "Body Matter" rename

#### Task 9.4: Manual UI Tests
- [ ] Poetry collections end-to-end
- [ ] Body Matter add/remove/reorder for each project type
- [ ] Manuscript preview/export/print with Body Matter
- [ ] Toolbar changes (no "Add to Collection", new "PDF to Submission")
- [ ] Upgrade migration from old app version

#### Task 9.5: CloudKit Sync Tests
- [ ] Migration syncs Device A → Device B
- [ ] Body Matter content syncs across devices
- [ ] Concurrent Body Matter edits

---

## File Structure

```
WrtingShedPro/Writing Shed Pro/
├── Models/
│   ├── BaseModels.swift              # Updated: Project, TextFile
│   ├── StoryModels.swift             # Updated: Chapter, Act, ProseSection, StoryScene
│   ├── PoetryCollection.swift        # NEW
│   └── Book.swift                    # NEW
├── Services/
│   ├── ProjectTemplateService.swift  # Updated: folder creation
│   ├── FolderCapabilityService.swift # Updated: Body Matter capabilities
│   ├── ManuscriptAssemblyService.swift # Updated: Body Matter assembly
│   └── MigrationService.swift        # Updated: Feature 036 migration
├── Views/
│   ├── FolderListView.swift          # Updated: Body Matter navigation
│   ├── FolderFilesView.swift         # Updated: collection references removed
│   ├── FolderFilesView+Helpers.swift # Updated: supportsAddToCollection removed
│   ├── PoetryCollectionsView.swift   # NEW
│   ├── PoetryCollectionDetailView.swift # NEW
│   ├── CollectionsView.swift         # REMOVED/deprecated
│   ├── Components/
│   │   ├── FileListView.swift        # Updated: collection button removed
│   │   └── CollectionPickerView.swift # REMOVED
│   ├── Manuscript/
│   │   ├── BodyMatterView.swift      # NEW
│   │   └── ManuscriptBodyView.swift  # REMOVED/refactored
│   ├── Fiction/
│   │   └── ChapterListView.swift     # Updated: collection picker removed
│   ├── Drama/
│   │   └── ActListView.swift         # Updated: collection picker removed
│   └── Prose/
│       └── SectionListView.swift     # Updated: collection picker removed
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| CloudKit migration data loss | Low | High | Idempotent migration, never delete on missing relationships, UserDefaults flag |
| Verse Novel Chapter→Book breaks existing data | Medium | High | Careful migration with logging, preserve all scene assignments |
| Body Matter empty after migration | Low | Medium | Auto-populate all existing items into Body Matter |
| Manuscript assembly regression | Medium | Medium | Comprehensive tests comparing old vs new output |
| Collections data in non-Poetry orphaned | Low | Low | Migrate to Submissions before deleting |

---

## Success Criteria

- [ ] Old Collections folder removed from all non-Poetry projects
- [ ] Poetry Collections work end-to-end (create, assign poems, add to Body Matter)
- [ ] Body Matter replaces "All X" in all project types
- [ ] Manuscript preview/export/print uses Body Matter contents
- [ ] Body Matter items can be added, removed, and reordered
- [ ] PDF-to-Submission button works in Manuscript toolbar
- [ ] Verse Novel uses Book model (not Chapter)
- [ ] Migration preserves all existing data
- [ ] CloudKit sync works correctly
- [ ] All tests pass
