# Phase 0: Dry-Run Mapper Plan

**Status**: Draft
**Created**: 2026-07-09
**Depends on**:

- [phase-0-model-inventory.md](phase-0-model-inventory.md)
- [phase-0-core-record-mapping.md](phase-0-core-record-mapping.md)
- [phase-0-delete-and-relationship-policy.md](phase-0-delete-and-relationship-policy.md)

## Purpose

Define the first implementation boundary for spec 043 without introducing runtime sync behavior. The dry-run mapper should prove that local SwiftData records can be converted into deterministic CKRecord-shaped values and diagnostics before any CKSyncEngine session, CloudKit write, migration, or import path exists.

## Explicit Non-Goals

- No CKSyncEngine startup.
- No CloudKit writes.
- No local SwiftData mutations.
- No replacement of `NSPersistentCloudKitContainer` yet.
- No model schema changes.
- No automatic deletion, cleanup, seed creation, or migration.

## Proposed Test-Only Components

Names are tentative and should be adjusted to match the app's final structure.

| Component | Responsibility | Runtime enabled? |
| --- | --- | --- |
| `SyncRecordEnvelope` | Plain Swift value representing record type, record name, fields, asset placeholders, and relationship IDs | No |
| `SyncAssetPlaceholder` | Describes a payload that would become a `CKAsset` later without creating files or uploading data | No |
| `SyncMappingDiagnostic` | Warning/error emitted by mapping, such as missing parent IDs or skipped local-only fields | No |
| `CoreRecordMapper` | Maps `Project`, `Folder`, `TextFile`, and `Version` into envelopes | No |
| `DryRunSyncReport` | Aggregates counts, skipped assets, pending relationships, and unsupported records | No |

The first implementation can live in test/support code or a clearly disabled diagnostics-only namespace. It should not be wired into app launch.

## First Supported Models

| Model | Scope | Notes |
| --- | --- | --- |
| `Project` | Full metadata, settings bytes, `styleSheetID` | No child arrays |
| `Folder` | Full metadata and parent/project IDs | Relationship nil becomes diagnostic, not delete |
| `TextFile` | Metadata and relationship IDs | Skip undo/redo data; report cover image as asset placeholder |
| `Version` | Metadata and plain text | Report formatted content assets as placeholders |

## Dry-Run Output Shape

The dry run should produce deterministic, reviewable output without exposing full manuscript content by default.

Example:

```text
CKSyncEngine dry-run export report
Zone: WritingShedProSyncZone

Records:
- Project: 1
- Folder: 7
- TextFile: 12
- Version: 18

Assets skipped/placeheld:
- Version.formattedContent: 18
- TextFile.coverImageData: 1

Local-only fields skipped:
- TextFile.undoStackData: 12
- TextFile.redoStackData: 12

Relationship warnings:
- none
```

## Determinism Requirements

- Record names are derived only from entity type and UUID.
- Field names are stable and documented.
- Relationship fields use UUID strings, not object identity or array position.
- Output ordering is sorted by record type then record name.
- Diagnostics are sorted by severity, entity type, then record name.

## Suggested Unit Tests

| Test | Expected result |
| --- | --- |
| `Project` envelope uses `Project:<uuid>` | Record identity is deterministic |
| `Project` mapping does not include child arrays | Child relationships are represented by child records |
| `Folder` mapping stores `parentFolderID` | Folder tree does not require relationship arrays to sync first |
| Root `Folder` with nil parent does not warn when `projectID` exists | Root folders are valid |
| `Folder` with missing project and parent warns but maps | No relationship-timing delete behavior |
| `TextFile` mapping skips undo/redo | Device-local editor history does not sync by accident |
| `TextFile` mapping reports cover image placeholder | Large image payload is not inlined |
| `Version` mapping reports formatted content placeholder | Rich text payload becomes later CKAsset work |
| `Version` mapping preserves `referenceMetadataData` | Reference attachments remain reconstructable |
| Dry-run report sorts records deterministically | Reports are diffable across runs |

## Acceptance Criteria for Phase 0 Implementation

- A test or diagnostics command can map an in-memory sample project graph without touching CloudKit.
- The dry-run report lists record counts, asset placeholders, skipped local-only fields, and relationship warnings.
- The mapper has tests for deterministic record names and child-before-parent tolerance.
- The mapper refuses unsupported models by diagnostic rather than silently dropping them.
- The implementation has no launch-time side effects and cannot be triggered accidentally in production.

## Gate Before Phase 1

Phase 1 should not begin until Phase 0 answers these review questions:

- Are the first syncable/local-only/deferred model categories accepted?
- Is `TextFile.undoStackData`/`redoStackData` local-only?
- Are predefined poetry forms regenerated locally while custom forms sync?
- Are manuscript analyst reviews local-only?
- Is project page setup still SwiftData-owned enough to sync?
- Are tombstones fields-on-record for the first pass, or separate records from the start?