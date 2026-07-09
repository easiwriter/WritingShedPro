# Phase 3: Change Tracker Policy

**Status**: Reviewed - envelope snapshots with in-memory/test baselines
**Created**: 2026-07-09
**Depends on**:

- [phase-3-export-dry-run-plan.md](phase-3-export-dry-run-plan.md)
- [phase-0-core-record-mapping.md](phase-0-core-record-mapping.md)
- [phase-0-delete-and-relationship-policy.md](phase-0-delete-and-relationship-policy.md)

## Purpose

Define how Phase 3 may identify local records that would be exported by CKSyncEngine, without relying on opaque Core Data/`NSPersistentCloudKitContainer` export state and without mutating SwiftData.

## Policy

Phase 3 change tracking should be based on explicit CKSyncEngine dry-run baselines, not Core Data mirroring metadata.

The first implementation should compare deterministic `SyncRecordEnvelope` snapshots:

- Baseline envelope set: last reviewed dry-run snapshot.
- Current envelope set: newly mapped local records.
- Added records: current record name not present in baseline.
- Updated records: same record name but different fields/assets/diagnostics.
- Unchanged records: same record name and same mapped payload.
- Delete intents: explicit `SyncTombstoneEnvelope` values only.
- Deferred records: categories deliberately outside the current export scope.

## Rules

- Do not read `ANSCK*` metadata tables for change detection.
- Do not rely on `NSPersistentCloudKitContainer` export pending state.
- Do not treat relationship detachment as delete intent.
- Do not infer deletes from a missing local record unless an explicit tombstone exists.
- Do not mutate `modifiedDate` to force a dry-run export.
- Do not create seed/default records as part of tracking.

## Live SwiftData Boundary

Before a tracker reads live SwiftData records, review how it obtains the current envelope set.

Allowed first live-read shape after review:

1. Fetch approved model types from a fresh `ModelContext`.
2. Map them through `CoreRecordMapper`.
3. Compare to an in-memory or test fixture baseline.
4. Produce `ExportDryRunReport` only.

Not allowed in Phase 3:

- Persisting production baselines.
- Saving SwiftData after mapping.
- Writing CloudKit records or assets.
- Running automatically on app launch.

## Recommended Decision

Reviewed decision: use envelope-snapshot comparison for Phase 3. Keep baselines in memory or test fixtures only until shadow sync storage is reviewed.
