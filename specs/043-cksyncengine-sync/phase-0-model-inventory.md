# Phase 0: SwiftData Model Inventory and CKRecord Mapping

**Status**: Draft
**Created**: 2026-07-09
**Parent spec**: `specs/043-cksyncengine-sync/spec.md`

## Purpose

This document starts Phase 0 of the CKSyncEngine replacement. It inventories the SwiftData models that currently participate in the app's data graph and defines the first-pass CloudKit record mapping rules.

No runtime CKSyncEngine code should be added until this mapping is reviewed.

Field-level draft for the first subset: [phase-0-core-record-mapping.md](phase-0-core-record-mapping.md).
Extended field-level draft for later syncable records: [phase-0-extended-record-mapping.md](phase-0-extended-record-mapping.md).

## Global Mapping Rules

- Use a single app-owned private database zone, tentatively `WritingShedProSyncZone`.
- Use deterministic record names: `<EntityName>:<uuid>`.
- Keep user-editable names out of record identity.
- Include a `schemaVersion` integer on every record type.
- Include `modifiedDate` when the local model has it; otherwise add sync metadata in the change tracker rather than inventing per-model fields during mapping.
- Represent relationships by stable foreign-key UUID fields or explicit link records.
- Do not infer deletion from a missing relationship.
- Tombstone first, purge later.
- Preserve import order independence: child records may arrive before parents and must remain pending/resolvable rather than deleted.

## Record Name Convention

| SwiftData model | CKRecord type | Record name |
| --- | --- | --- |
| `Project` | `Project` | `Project:<project.id>` |
| `Folder` | `Folder` | `Folder:<folder.id>` |
| `TextFile` | `TextFile` | `TextFile:<textFile.id>` |
| `Version` | `Version` | `Version:<version.id>` |
| Any join model | same as model name | `<JoinModel>:<link.id>` |

## Entity Groups

### Core Project Graph

| Model | Role | Parent/link strategy | Payload notes | Phase 0 decision |
| --- | --- | --- | --- | --- |
| `Project` | Root user project | Root record; child records store `projectID` | `manuscriptSettingsData`, `tocSettingsData` are JSON blobs; keep as bytes unless size proves large | Syncable |
| `Folder` | Project tree and manuscript folders | Store `projectID` and `parentFolderID`; do not depend on SwiftData relationship timing | Front/back matter settings data are JSON blobs | Syncable |
| `TextFile` | User writing file | Store `projectID`, `parentFolderID`, and optional collection/container link records | `undoStackData`, `redoStackData`, `coverImageData` are external-storage candidates; cover images should be `CKAsset` | Syncable |
| `Version` | Versioned text content | Store `textFileID` | `formattedContent`, `notesFormattedContent` are external-storage candidates and should map to `CKAsset`; `referenceMetadataData` is metadata bytes | Syncable |
| `TrashItem` | Trash metadata/recovery | Store `projectID`, original parent IDs, target entity ID/type | Must not drive automatic permanent deletion | Syncable after delete/tombstone policy is defined |

### Project Structure Models

| Model | Role | Parent/link strategy | Phase 0 decision |
| --- | --- | --- | --- |
| `StoryScene` | Fiction/drama scene or episode | Store `projectID`; use link records for chapters/acts/books/characters/locations/plot elements | Syncable |
| `Chapter` | Fiction chapter/story container | Store `projectID`; scene membership via `SceneChapterLink` | Syncable |
| `Act` | Drama act container | Store `projectID`; scene membership via `SceneActLink` | Syncable |
| `ProseSection` | Prose section container | Store `projectID`; file membership via `TextFileSectionLink` | Syncable |
| `Book` | Verse novel book container | Store `projectID`; scene membership via `SceneBookLink` | Syncable |
| `PoetryCollection` | Poetry collection container | Store `projectID`; file membership via `TextFileCollectionLink` | Syncable |
| `Character` | Story character | Store `projectID`; scene/plot links via join models | Syncable |
| `Location` | Story location | Store `projectID`; scene/plot links via join models | Syncable |
| `PlotElement` | Plot item/stage | Store `projectID`; scene/character/location links via join models | Syncable |
| `CustomAttribute` | Character custom metadata | Store owning `characterID` | Syncable with `Character` |

### Explicit Link Records

These already exist to avoid many-to-many SwiftData/CloudKit relationship problems. CKSyncEngine should keep them as first-class records and export nullable side references safely.

| Model | Link fields | Delete/import rule |
| --- | --- | --- |
| `TextFileSectionLink` | `textFileID`, `sectionID`, `userOrder` | Keep if one side is temporarily missing; clean only by explicit tombstone or reviewed orphan repair |
| `TextFileCollectionLink` | `textFileID`, `poetryCollectionID`, `userOrder` | Same |
| `SceneChapterLink` | `sceneID`, `chapterID` | Same |
| `SceneActLink` | `sceneID`, `actID` | Same |
| `SceneBookLink` | `sceneID`, `bookID` | Same |
| `ScenePlotElementLink` | `sceneID`, `plotElementID` | Same |
| `SceneCharacterLink` | `sceneID`, `characterID` | Same |
| `CharacterPlotElementLink` | `characterID`, `plotElementID` | Same |
| `LocationPlotElementLink` | `locationID`, `plotElementID` | Same |
| `SceneLocationLink` | `sceneID`, `locationID` | Same |

### References, Notes, and Back Matter

| Model | Parent/link strategy | Payload notes | Phase 0 decision |
| --- | --- | --- | --- |
| `NoteEntry` | Store `projectID`; referenced from `Version.referenceMetadataData` and marker metadata | `formattedContentData` should map to `CKAsset` | Syncable |
| `GlossaryEntry` | Store `projectID`; optional `citationID` | Plain text fields | Syncable |
| `ReferenceEntry` | Store `projectID` | Plain text fields | Syncable |
| `CitationEntry` | Store `projectID`; author data stored in `authorsData` | JSON/data payload; likely inline unless size proves large | Syncable |
| `IndexEntry` | Store `projectID`; `seeAlsoEntryIDsData`, `referencingFileIDsData`, page-number data | JSON/data payloads; inline unless size proves large | Syncable |
| `ContributorEntry` | Store `projectID` | Plain text/order fields | Syncable |

### Comments and Footnotes

| Model | Parent/link strategy | Safety note | Phase 0 decision |
| --- | --- | --- | --- |
| `CommentModel` | Store `versionID` and any attachment/selection identifiers | Must support fallback lookup by attachment ID if version relationship arrives late | Syncable |
| `FootnoteModel` | Store `versionID` and attachment ID | Must preserve attachment-ID lookup to avoid relationship-timing misses | Syncable |

### Publications and Submissions

| Model | Parent/link strategy | Phase 0 decision |
| --- | --- | --- |
| `Publication` | Store `projectID` | Syncable |
| `Submission` | Store `projectID`, optional `publicationID` | Syncable; `publicationID == nil` can mean a collection, not an orphan |
| `SubmittedFile` | Store `projectID`, `submissionID`, `textFileID`, `versionID` as available | Syncable; tolerate missing file/version during import |

### Styles and Page Setup

| Model | Parent/link strategy | Safety note | Phase 0 decision |
| --- | --- | --- | --- |
| `StyleSheet` | Referenced by `Project.styleSheetID`; owns text/image styles | Default/system styles are high-risk for duplicate creation during import timing | Syncable, but seed/default creation must wait for import |
| `TextStyleModel` | Store `styleSheetID` | Style names are not unique identities; use UUID record name | Syncable |
| `ImageStyle` | Store `styleSheetID` | Style names are not unique identities | Syncable |
| `PageSetup` | Project-level page settings | Verify whether project page setup is still active or legacy/global before syncing | Deferred until ownership is confirmed |
| `PrinterPaper` | Paper preset child of page setup | Likely generated/default data unless user-created custom papers exist | Deferred until ownership is confirmed |

### Poetry Forms and Analysis Cache

| Model | Parent/link strategy | Phase 0 decision |
| --- | --- | --- |
| `PoetryFormModel` | Project-independent form definition | Sync only `isCustom == true` by default; regenerate predefined forms locally |
| `ManuscriptReview` | Analyst result cache keyed by `reviewId` | Default to local-only cache; existing `@Attribute(.unique)` makes it unsuitable for CloudKit-backed SwiftData assumptions |
| `ReviewSuggestion` | Child of review cache | Default to local-only with `ManuscriptReview` |

## Large Payload and CKAsset Candidates

| Model.field | Current storage | CKSyncEngine mapping recommendation |
| --- | --- | --- |
| `Version.formattedContent` | `@Attribute(.externalStorage) Data?` | `CKAsset` |
| `Version.notesFormattedContent` | `@Attribute(.externalStorage) Data?` | `CKAsset` if non-empty/significant |
| `TextFile.coverImageData` | `@Attribute(.externalStorage) Data?` | `CKAsset` |
| `TextFile.undoStackData` | `@Attribute(.externalStorage) Data?` | Local-only; do not sync by default |
| `TextFile.redoStackData` | `@Attribute(.externalStorage) Data?` | Local-only; do not sync by default |
| `NoteEntry.formattedContentData` | `@Attribute(.externalStorage) Data?` | `CKAsset` |
| `Project.manuscriptSettingsData` | `Data?` JSON | Inline bytes unless size requires asset |
| `Folder.*MatterSettingsData` | `Data?` JSON | Inline bytes unless size requires asset |
| `Reference/Index metadata Data` | `Data?` JSON | Inline bytes unless size requires asset |

## Approved First Dry-Run Mapper Subset

Start with records that are structurally important but lower payload risk:

1. `Project`
2. `Folder`
3. `TextFile` metadata only, excluding content/assets/undo stacks
4. `Version` metadata only, excluding formatted-content assets

Do not start shadow sync with `Version.formattedContent`, comments, footnotes, references, or join records. Those should wait until relationship and asset mapping tests exist.

## Phase 0 Tasks

- [x] Review this inventory against the current SwiftData schema.
- [x] Decide initial syncable, local-only, or deferred categories.
- [x] Define exact field-level mappings for `Project`, `Folder`, `TextFile`, and `Version`.
- [x] Define tombstone fields common to all syncable records.
- [x] Define pending-relationship handling for child-before-parent imports.
- [x] Choose the first shadow-sync subset.
- [x] Decide initial treatment for `PageSetup`, `PrinterPaper`, `PoetryFormModel`, and manuscript analysis review caches.

## Open Mapping Questions

- Which record types need per-field merge rules rather than last-writer-wins?