# Phase 0: Extended Record Mapping Draft

**Status**: Draft
**Created**: 2026-07-09
**Depends on**:

- [phase-0-model-inventory.md](phase-0-model-inventory.md)
- [phase-0-core-record-mapping.md](phase-0-core-record-mapping.md)
- [phase-0-delete-and-relationship-policy.md](phase-0-delete-and-relationship-policy.md)

## Purpose

Define first-pass CKRecord field mappings for syncable models outside the initial dry-run subset. These records should not be part of the first mapper unless explicitly pulled forward after review.

## Story Structure Records

All story structure records use deterministic record names and a `projectID` field. Relationship arrays are not serialized; memberships are represented by explicit link records.

### Shared Container Fields

Applies to `Chapter`, `Act`, `ProseSection`, `Book`, and `PoetryCollection`.

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `projectID` | `project?.id.uuidString` | May be pending during import |
| `name` | `name` | User-editable |
| `userOrder` | `userOrder` | Int64 when present |
| `synopsis` | `synopsis` | String |
| `createdDate` | `createdDate` | Date |
| `modifiedDate` | `modifiedDate` | Date |
| `bodyMatterOrder` | `bodyMatterOrder` | Int64 when present |
| `isInBodyMatter` | `isInBodyMatter` | Bool |

Membership fields:

- `Chapter` scenes use `SceneChapterLink`.
- `Act` scenes use `SceneActLink`.
- `ProseSection` files use `TextFileSectionLink`.
- `Book` scenes use `SceneBookLink`.
- `PoetryCollection` files use `TextFileCollectionLink`.

### StoryScene -> CKRecord(`StoryScene`)

Record name: `StoryScene:<id>`

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `projectID` | `project?.id.uuidString` | May be pending during import |
| `textFileID` | `textFile?.id.uuidString` | Scene content relationship |
| `legacyLocationID` | `location?.id.uuidString` | Backward-compatible single-location field only |
| `name` | `name` | User-editable |
| `userOrder` | `userOrder` | Int64 when present |
| `synopsis` | `synopsis` | String |
| `monomythStageRaw` | `monomythStageRaw` | Preserve raw value |
| `campbellStageRaw` | `campbellStageRaw` | Legacy raw value |
| `threeActStageRaw` | `threeActStageRaw` | Preserve raw value |
| `pearsonStageRaw` | `pearsonStageRaw` | Legacy raw value |
| `createdDate` | `createdDate` | Date |
| `modifiedDate` | `modifiedDate` | Date |
| `bodyMatterOrder` | `bodyMatterOrder` | Int64 when present |
| `isInBodyMatter` | `isInBodyMatter` | Bool |
| `isTrashed` | `isTrashed` | Soft-delete/presentation state |
| `trashedDate` | `trashedDate` | Soft-delete metadata |

Relationship rules:

- Chapters, acts, books, plot elements, characters, and locations use link records.
- `legacyLocationID` must not replace `SceneLocationLink`; it exists only for older data compatibility.
- `textFileID` must tolerate the text file arriving later.

### Character -> CKRecord(`Character`)

Record name: `Character:<id>`

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `projectID` | `project?.id.uuidString` | May be pending during import |
| `name` | `name` | User-editable |
| `role` | `role` | Single source of truth for role |
| `archetypeRaw` | `archetypeRaw` | Comma-separated Vogler values |
| `pearsonArchetypeRaw` | `pearsonArchetypeRaw` | Legacy raw value |
| `history` | `history` | String |
| `looks` | `looks` | String |
| `traits` | `traits` | String |
| `work` | `work` | String |
| `createdDate` | `createdDate` | Date |
| `modifiedDate` | `modifiedDate` | Date |

Relationship rules:

- Scene membership uses `SceneCharacterLink`.
- Plot membership uses `CharacterPlotElementLink`.
- Custom attributes are child records with `characterID`.

### Location -> CKRecord(`Location`)

Record name: `Location:<id>`

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `projectID` | `project?.id.uuidString` | May be pending during import |
| `name` | `name` | User-editable |
| `detail` | `detail` | String |
| `sights` | `sights` | String |
| `sounds` | `sounds` | String |
| `smells` | `smells` | String |
| `createdDate` | `createdDate` | Date |
| `modifiedDate` | `modifiedDate` | Date |

Relationship rules:

- Scene membership uses `SceneLocationLink`; do not depend on legacy `Location.scenes`.
- Plot membership uses `LocationPlotElementLink`.
- Custom attributes are child records with `locationID`.

### CustomAttribute -> CKRecord(`CustomAttribute`)

Record name: `CustomAttribute:<id>`

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `characterID` | `character?.id.uuidString` | Exactly one owner should normally be set |
| `locationID` | `location?.id.uuidString` | Exactly one owner should normally be set |
| `key` | `key` | String |
| `value` | `value` | String |
| `userOrder` | `userOrder` | Int64 when present |

Import rule: if both owners are missing, keep pending and report a diagnostic; do not delete.

### PlotElement -> CKRecord(`PlotElement`)

Record name: `PlotElement:<id>`

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `projectID` | `project?.id.uuidString` | May be pending during import |
| `name` | `name` | String |
| `notes` | `notes` | String |
| `userOrder` | `userOrder` | Int64 when present |
| `monomythStageRaw` | `monomythStageRaw` | Preserve raw value |
| `campbellStageRaw` | `campbellStageRaw` | Legacy raw value |
| `threeActStageRaw` | `threeActStageRaw` | Preserve raw value |
| `pearsonStageRaw` | `pearsonStageRaw` | Legacy raw value |
| `createdDate` | `createdDate` | Date |
| `modifiedDate` | `modifiedDate` | Date |

Relationship rules:

- Scene links use `ScenePlotElementLink`.
- Character links use `CharacterPlotElementLink`.
- Location links use `LocationPlotElementLink`.
- Computed union fields must be rebuilt from links after import; do not serialize computed arrays.

## Explicit Link Records

All link records use the same shape: `id`, endpoint UUID fields, optional `userOrder`, and tombstone metadata.

| Model | CK fields |
| --- | --- |
| `TextFileSectionLink` | `textFileID`, `sectionID`, `userOrder` |
| `TextFileCollectionLink` | `textFileID`, `poetryCollectionID`, `userOrder` |
| `SceneChapterLink` | `sceneID`, `chapterID` |
| `SceneActLink` | `sceneID`, `actID` |
| `SceneBookLink` | `sceneID`, `bookID` |
| `ScenePlotElementLink` | `sceneID`, `plotElementID` |
| `SceneCharacterLink` | `sceneID`, `characterID` |
| `CharacterPlotElementLink` | `characterID`, `plotElementID` |
| `LocationPlotElementLink` | `locationID`, `plotElementID` |
| `SceneLocationLink` | `sceneID`, `locationID` |

Link import rule: a link with one missing endpoint is pending, not orphaned.

## Publication and Submission Records

### Publication -> CKRecord(`Publication`)

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `projectID` | `project?.id.uuidString` or `projectId?.uuidString` | Prefer relationship, fall back to stored ID |
| `name` | `name` | String |
| `type` | `type` raw value | Verify enum storage shape before implementation |
| `url` | `url` | String |
| `notes` | `notes` | String |
| `deadline` | `deadline` | Date |
| `typicalResponseDays` | `typicalResponseDays` | Int64 when present |
| `reminderDate` | `reminderDate` | Date |
| `reminderNotificationId` | `reminderNotificationId` | Device-local notification IDs may need local-only review |
| `createdDate` | `createdDate` | Date |
| `modifiedDate` | `modifiedDate` | Date |

### Submission -> CKRecord(`Submission`)

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `projectID` | `project?.id.uuidString` or `projectId?.uuidString` | Prefer relationship, fall back to stored ID |
| `publicationID` | `publication?.id.uuidString` | Nil is valid for collections |
| `name` | `name` | Collection name |
| `collectionDescription` | `collectionDescription` | Collection description |
| `isCollection` | `isCollection` | Bool; do not infer solely from nil publication |
| `submittedDate` | `submittedDate` | Date |
| `returnExpectedBy` | `returnExpectedBy` | Date |
| `returnedOn` | `returnedOn` | Date |
| `notes` | `notes` | String |
| `typicalResponseDays` | `typicalResponseDays` | Int64 when present |
| `reminderDate` | `reminderDate` | Date |
| `reminderNotificationId` | `reminderNotificationId` | Device-local notification IDs may need local-only review |
| `createdDate` | `createdDate` | Date |
| `modifiedDate` | `modifiedDate` | Date |
| `userOrder` | `userOrder` | Collection sort order |

### SubmittedFile -> CKRecord(`SubmittedFile`)

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `projectID` | `project?.id.uuidString` | May be pending during import |
| `submissionID` | `submission?.id.uuidString` | May be pending during import |
| `textFileID` | `textFile?.id.uuidString` | May be pending or deleted |
| `versionID` | `version?.id.uuidString` | May be pending or deleted |
| `status` | `status` raw value | Verify enum storage shape before implementation |
| `statusDate` | `statusDate` | Date |
| `statusNotes` | `statusNotes` | String |
| `createdDate` | `createdDate` | Date |
| `modifiedDate` | `modifiedDate` | Date |

Import rule: keep submitted-file records if their linked file/version has not arrived yet; surface stale links in diagnostics after the import window.

## Comment and Footnote Records

### CommentModel -> CKRecord(`CommentModel`)

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `versionID` | `version?.id.uuidString` | Relationship may arrive late |
| `characterPosition` | `characterPosition` | Int64 |
| `attachmentID` | `attachmentID.uuidString` | Required fallback lookup key |
| `text` | `text` | String |
| `author` | `author` | String |
| `createdAt` | `createdAt` | Date |
| `resolvedAt` | `resolvedAt` | Date |

### FootnoteModel -> CKRecord(`FootnoteModel`)

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `versionID` | `version?.id.uuidString` | Relationship may arrive late |
| `characterPosition` | `characterPosition` | Int64 |
| `attachmentID` | `attachmentID.uuidString` | Required fallback lookup key |
| `text` | `text` | String |
| `number` | `number` | Int64 |
| `createdAt` | `createdAt` | Date |
| `modifiedAt` | `modifiedAt` | Date |

Import rule: attachment-ID lookup remains required; never rely only on `versionID` relationship timing.

## Reference and Back Matter Records

All reference records store `projectID` and should keep JSON/data fields inline unless diagnostics show they regularly exceed comfortable CKRecord field sizes.

| Model | Key fields | Relationship fields |
| --- | --- | --- |
| `NoteEntry` | `content`, `formattedContentAsset`, `isEndnote`, `displayNumber`, `referenceCount`, `referencingFileIDs`, `createdAt`, `modifiedAt`, `title`, `tag` | `projectID` |
| `GlossaryEntry` | `term`, `definition`, `referenceCount`, `createdAt`, `modifiedAt` | `projectID`, `citationID` |
| `ReferenceEntry` | `author`, `publicationDate`, `details`, `referenceCount`, `createdAt`, `modifiedAt` | `projectID` |
| `CitationEntry` | `authorsData`, `year`, `title`, `source`, `url`, `doi`, `volume`, `issue`, `pages`, `edition`, `city`, `accessDate`, `sourceTypeRaw`, `referenceCount`, `createdAt`, `modifiedAt` | `projectID` |
| `IndexEntry` | `keyword`, `seeEntryID`, `seeAlsoEntryIDsData`, `referenceCount`, `referencingFileIDsData`, `pageNumbersData`, `primaryPageNumbersData`, `createdAt`, `modifiedAt` | `projectID`, `parentEntryID` |
| `ContributorEntry` | `firstName`, `surname`, `name`, `biography`, `userOrder`, `createdAt`, `modifiedAt` | `projectID` |

Special cases:

- `NoteEntry.formattedContentData` should be a `CKAsset` candidate like version formatted content.
- `IndexEntry.parentEntryID` may point to another `IndexEntry` that arrives later; keep pending.
- `IndexEntry.seeEntryID` and `seeAlsoEntryIDsData` are UUID references, not ownership relationships.

## Styles and User Defaults Adjacent Records

### StyleSheet -> CKRecord(`StyleSheet`)

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `name` | `name` | String |
| `isSystemStyleSheet` | `isSystemStyleSheet` | Built-in/system data risk flag |
| `createdDate` | `createdDate` | Date |
| `modifiedDate` | `modifiedDate` | Date |
| `footnoteMarkerStyleRaw` | `footnoteMarkerStyleRaw` | Raw value |

Rules:

- Do not identify stylesheets by name.
- Default/system stylesheet creation must wait for import-settled state.
- Project links use `Project.styleSheetID`; `StyleSheet.projects` is not serialized.

### TextStyleModel -> CKRecord(`TextStyleModel`)

Use `styleSheetID` plus the persisted style fields: names, display order, font attributes, paragraph attributes, line-height fields, numbering fields, follow-on style name, parent style name, category flags, TOC flags, first-paragraph flag, and metadata dates.

Rules:

- `name` is a lookup/display key, not identity.
- `parentStyleName` and `followOnStyleName` are name references within the stylesheet; they need diagnostics for missing targets but not deletes.
- Only one `isFirstParagraphStyle` should be true per stylesheet; conflicts need deterministic conflict resolution.

### ImageStyle -> CKRecord(`ImageStyle`)

Use `styleSheetID`, `name`, `displayName`, `displayOrder`, default image fields, metadata dates, and `isSystemStyle`.

Rule: image styles are templates for new images; changing them must not rewrite existing image attachments.

## Deferred or Local-Only Records

| Model | Default treatment | Reason |
| --- | --- | --- |
| `PageSetup` | Deferred | Needs ownership review because code comments say page setup became global/UserDefaults in some flows while model still has project relationship |
| `PrinterPaper` | Deferred | Likely generated paper preset data unless user-created paper support exists |
| `PoetryFormModel` predefined rows | Local regeneration | Built-in data should not race import or duplicate across devices |
| `PoetryFormModel` custom rows | Syncable later | User-created forms are user data |
| `ManuscriptReview` | Local-only by default | Analysis/cache data, uses `@Attribute(.unique) reviewId`, and may be large/ephemeral |
| `ReviewSuggestion` | Local-only by default | Child cache data with review |