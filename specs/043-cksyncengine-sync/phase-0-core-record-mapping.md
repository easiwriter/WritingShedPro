# Phase 0: Core Record Mapping Draft

**Status**: Draft
**Created**: 2026-07-09
**Depends on**: [phase-0-model-inventory.md](phase-0-model-inventory.md)

## Purpose

Define field-level CKRecord mappings for the first CKSyncEngine review subset. This is intentionally limited to the core project/file graph so the first implementation can be a dry-run mapper before any runtime sync or CloudKit writes exist.

## Shared Fields for All Syncable Records

| CK field | Type | Source | Notes |
| --- | --- | --- | --- |
| `schemaVersion` | `Int64` | mapper constant | Start at `1`; bump only with explicit migration plan |
| `entityID` | `String` | `model.id.uuidString` | Duplicate of record name id for query/debug readability |
| `entityType` | `String` | mapper constant | Useful in generic diagnostics |
| `modifiedDate` | `Date?` | model field when present | If model lacks it, use change-tracker metadata, not an ad hoc model mutation |
| `isDeleted` | `Int64`/Bool-compatible | tombstone state | Required before permanent purge |
| `deletedDate` | `Date?` | tombstone state | Do not use alone to delete local data |
| `sourceDeviceID` | `String?` | sync engine metadata | Diagnostics/conflict aid |

## Project -> CKRecord(`Project`)

Record name: `Project:<id>`

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `name` | `name` | User-editable, never identity |
| `typeRaw` | `typeRaw` | Preserve raw value for compatibility |
| `statusRaw` | `statusRaw` | Preserve raw value |
| `creationDate` | `creationDate` | Optional in model |
| `modifiedDate` | `modifiedDate` | Optional in model |
| `details` | `details` | String |
| `notes` | `notes` | String |
| `author` | `author` | String |
| `userOrder` | `userOrder` | Int64 when present |
| `isTrashed` | `isTrashed` | Presentation/trash state, not purge authority |
| `deletedDate` | `deletedDate` | Tombstone/trash metadata |
| `fictionClassRaw` | `fictionClassRaw` | Preserve raw value |
| `storyStructureRaw` | `storyStructureRaw` | Preserve raw value |
| `useMonomyth` | `useMonomyth` | Legacy compatibility |
| `dramaScriptTypeRaw` | `dramaScriptTypeRaw` | Preserve raw value |
| `manuscriptSettingsData` | `manuscriptSettingsData` | Inline bytes initially; monitor size |
| `tocSettingsData` | `tocSettingsData` | Inline bytes initially; monitor size |
| `styleSheetID` | `styleSheet?.id.uuidString` | Relationship field, not CKReference delete action |

Relationship rules:

- Child entities store `projectID`; `Project` does not need child arrays in CloudKit.
- `styleSheetID` may be nil during import; do not auto-create stylesheets until import settles.
- Project title collisions must not trigger deduplication deletes.

## Folder -> CKRecord(`Folder`)

Record name: `Folder:<id>`

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `name` | `name` | User-editable |
| `userOrder` | `userOrder` | Int64 when present |
| `projectID` | `project?.id` or resolved parent project | Relationship may be nil while importing; keep pending |
| `parentFolderID` | `parentFolder?.id` | Nil for root folders |
| `frontMatterSettingsData` | `frontMatterSettingsData` | Inline bytes initially |
| `backMatterSettingsData` | `backMatterSettingsData` | Inline bytes initially |
| `dramaFrontMatterSettingsData` | `dramaFrontMatterSettingsData` | Inline bytes initially |
| `dramaBackMatterSettingsData` | `dramaBackMatterSettingsData` | Inline bytes initially |

Relationship rules:

- Rebuild folder hierarchy from `parentFolderID` after all available folders are decoded.
- A folder with nil `projectID` and nil `parentFolderID` is not automatically orphaned; it may be waiting for a parent/project record.
- Folder deletes must be tombstoned and must not cascade-delete child records during import.

## TextFile -> CKRecord(`TextFile`)

Record name: `TextFile:<id>`

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `name` | `name` | User-editable |
| `createdDate` | `createdDate` | Date |
| `modifiedDate` | `modifiedDate` | Date |
| `currentVersionIndex` | `currentVersionIndex` | Int64 |
| `userOrder` | `userOrder` | Int64 when present |
| `workflowStatusRaw` | `workflowStatusRaw` | Optional raw value |
| `parentFolderID` | `parentFolder?.id.uuidString` | Relationship field |
| `projectID` | `project?.id.uuidString` | Denormalized from folder chain for diagnostics/recovery |
| `sceneID` | `scene?.id.uuidString` | Optional one-to-one content relationship |
| `poetryFormId` | `poetryFormId?.uuidString` | References built-in or user form |
| `poetryFormName` | `poetryFormName` | Denormalized display |
| `includedInManuscript` | `includedInManuscript` | Bool |
| `isTOCFile` | `isTOCFile` | Bool |
| `tocSettingsData` | `tocSettingsData` | Inline bytes initially |
| `isTableOfFiguresFile` | `isTableOfFiguresFile` | Bool |
| `tofSettingsData` | `tofSettingsData` | Inline bytes initially |
| `isCoverFile` | `isCoverFile` | Bool |
| `coverImageAsset` | `coverImageData` | CKAsset candidate; do not inline large image data |
| `contentTypeRaw` | `contentTypeRaw` | Raw value |
| `undoStackPolicy` | derived | Default should be `localOnly` unless cross-device undo is explicitly required |

Deferred/local-only fields:

- `undoStackData`
- `redoStackData`
- `lastUndoSaveDate`

Relationship rules:

- Versions are separate records with `textFileID`.
- Section/collection membership uses explicit link records.
- `sceneID` must tolerate the scene arriving later.

## Version -> CKRecord(`Version`)

Record name: `Version:<id>`

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `textFileID` | `textFile?.id.uuidString` | Required for normal import, but may be pending if TextFile arrives later |
| `content` | `content` | Plain text fallback/search text |
| `createdDate` | `createdDate` | Date |
| `versionNumber` | `versionNumber` | Int64 |
| `comment` | `comment` | String |
| `notes` | `notes` | String |
| `formattedContentAsset` | `formattedContent` | CKAsset; main rich-text payload |
| `notesFormattedContentAsset` | `notesFormattedContent` | CKAsset when non-empty/significant |
| `referenceMetadataData` | `referenceMetadataData` | Inline bytes initially; used to reconstruct reference attachments |

Relationship rules:

- Comments, footnotes, and submitted-file links are separate records with `versionID`.
- Deleting a version must export a `Version` tombstone and tombstones for dependent comments/footnotes only when explicitly deleted locally.
- Removing a version from a SwiftData relationship array is not enough; the change tracker must see an explicit delete intent.

## TrashItem -> CKRecord(`TrashItem`)

Record name: `TrashItem:<id>`

| CK field | SwiftData source | Notes |
| --- | --- | --- |
| `deletedDate` | `deletedDate` | Date |
| `textFileID` | `textFile?.id.uuidString` | Optional relationship field |
| `originalFolderID` | `originalFolder?.id.uuidString` | Optional relationship field |
| `projectID` | `project?.id.uuidString` | Optional relationship field |

Safety rule:

- `TrashItem` can sync presentation/recovery state, but must not be treated as permission to permanently purge the referenced `TextFile` on another device.

## First Dry-Run Mapper Scope

The first mapper should support these records only:

1. `Project`
2. `Folder`
3. `TextFile` metadata excluding undo/redo and content assets
4. `Version` metadata excluding formatted-content assets

The first dry-run should emit a report like:

```text
Would export:
- Project: 1 record
- Folder: 7 records
- TextFile: 12 records
- Version: 18 records
- CKAsset payloads skipped: 18 formatted versions, 1 cover image
- Pending relationship warnings: 0
```

## Required Tests Before Runtime Sync

- Deterministic record name generation for each mapped model.
- `Project` map round-trip preserves raw enum fields and settings data.
- `Folder` map round-trip preserves parent/project IDs without requiring relationships to be loaded.
- `TextFile` map round-trip excludes undo/redo data by default.
- `Version` map round-trip preserves plain text, version number, and reference metadata while reporting formatted content as an asset placeholder.
- Child-before-parent decode leaves records pending rather than deleting them.