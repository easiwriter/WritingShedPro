# Phase 3: Export Dry-Run Plan

**Status**: Initial pure-value builder implemented
**Created**: 2026-07-09
**Depends on**:

- [phase-0-core-record-mapping.md](phase-0-core-record-mapping.md)
- [phase-0-extended-record-mapping.md](phase-0-extended-record-mapping.md)
- [phase-0-delete-and-relationship-policy.md](phase-0-delete-and-relationship-policy.md)
- [phase-3-change-tracker-policy.md](phase-3-change-tracker-policy.md)
- [phase-3-asset-size-policy.md](phase-3-asset-size-policy.md)
- [rollout-gates.md](rollout-gates.md)

## Purpose

Define how local changes will be detected and converted into CKRecord-shaped export operations without saving anything to CloudKit. This phase proves change tracking, tombstone capture, asset handling, and skipped local-only fields before any CloudKit write path exists.

## Implementation Status

Initial pure-value export dry-run slice added:

- `ExportDryRunBuilder`
- `ExportDryRunReport`
- `ExportDryRunOperation`

The builder accepts already-mapped `SyncRecordEnvelope` values, `SyncTombstoneEnvelope` values, and explicitly deferred envelopes. It does not hold a `ModelContext`, inspect Core Data export state, create CKRecords, write CloudKit, or mutate SwiftData.

Current tests verify:

- Changed records become `wouldSaveRecord` operations.
- Asset placeholders become `wouldSaveAsset` operations and remain redacted.
- Local-only diagnostics become `wouldSkipLocalOnly` operations.
- Link inserts save only the link record.
- Link deletes save only link tombstones, not endpoint deletes.
- Parent delete tombstones do not create child delete exports.
- Deferred seed/default records are visible as `wouldDefer`.
- Warning diagnostics are visible in the report.
- Envelope-snapshot change tracking finds added/updated records without inferring deletes from missing current records.
- Large and oversized asset placeholders produce dry-run diagnostics without temp files or `CKAsset` creation.

Remaining Phase 3 work:

- Keep live SwiftData reads behind the reviewed envelope-snapshot boundary: see [phase-3-change-tracker-policy.md](phase-3-change-tracker-policy.md).
- Keep asset handling to placeholder diagnostics and reviewed size bands: see [phase-3-asset-size-policy.md](phase-3-asset-size-policy.md).
- Add broader deferred-model classification once extended model export is pulled into scope.

## Explicit Non-Goals

- No CloudKit saves or deletes.
- No CKSyncEngine event loop.
- No zone creation or subscription setup.
- No mutation of existing `NSPersistentCloudKitContainer` state.
- No automatic seed/default export.

## Proposed Components

| Component | Responsibility |
| --- | --- |
| `SyncChangeTracker` | Identifies local records changed since a dry-run baseline |
| `ExportDryRunBuilder` | Converts changed models into record envelopes or tombstones |
| `ExportAssetInventory` | Counts/identifies payloads that will require CKAsset handling |
| `ExportDryRunReport` | Summarizes would-save, would-delete, skipped, deferred, and asset records |

## Change Sources to Prove

| Change source | Requirement |
| --- | --- |
| Model `modifiedDate` | Detect normal metadata/content edits where models already maintain timestamps |
| Explicit delete intent | Detect local deletes through tombstone/change-tracker state, not relationship detachment |
| Relationship/link changes | Detect link record insert/delete/update as first-class changes |
| Asset payload changes | Detect formatted content and cover image changes without uploading assets |
| Local-only fields | Report skipped undo/redo data rather than exporting it |

## Export Operation Types

| Operation | Meaning | Writes CloudKit? |
| --- | --- | --- |
| `wouldSaveRecord` | Local change would create/update a remote record | No |
| `wouldSaveAsset` | Local payload would become a CKAsset | No |
| `wouldSaveTombstone` | Local delete intent would be exported | No |
| `wouldSkipLocalOnly` | Field/model intentionally excluded | No |
| `wouldDefer` | Model category not approved for current phase | No |
| `warning` | Mapping or relationship issue requiring review | No |

## Delete Intent Requirements

Export dry run must distinguish:

- relationship detachment
- soft trash state
- user permanent delete intent
- repair/migration delete intent
- remote-import cascade echoes that must not be re-exported

If delete intent cannot be proven, export dry run should warn and skip the delete.

## Asset Requirements

Asset dry run should report:

- entity type and ID
- field name
- byte count
- suggested asset file extension when known
- whether the asset is required for user data fidelity

It must not write asset temp files unless a later reviewed implementation needs that for size checks.

## Tests Before CloudKit Export

- [x] Text edit on `Version.formattedContent` creates asset placeholder and record save operation.
- [x] Metadata edit on `TextFile.name` creates record save operation.
- [x] Undo/redo changes are skipped as local-only.
- [x] Link insert creates link record save operation.
- [x] Link delete creates link tombstone operation, not endpoint delete operations.
- [x] Parent delete intent does not create child delete exports unless child tombstones exist.
- [x] Seed/default styles are deferred until import-settled policy allows them.

## Acceptance Criteria

- [x] Export dry run can summarize mapped local changes without CloudKit writes.
- [x] Delete exports require explicit tombstone intent.
- [x] Asset placeholders are counted and reported.
- [x] Local-only and deferred fields/models are visible in the report.
- [x] The report is deterministic and redacted.
- [x] Live SwiftData change tracking design is reviewed before implementation: see [phase-3-change-tracker-policy.md](phase-3-change-tracker-policy.md).
