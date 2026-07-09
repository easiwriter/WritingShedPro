# Phase 1: Existing Core Data Zone Boundary

**Status**: Draft boundary
**Created**: 2026-07-09
**Depends on**:

- [phase-1-read-only-inspector-plan.md](phase-1-read-only-inspector-plan.md)
- [phase-5-migration-planning.md](phase-5-migration-planning.md)

## Purpose

Document how the CKSyncEngine replacement treats the existing `NSPersistentCloudKitContainer` zone during early development. This avoids accidental migration, repair, or deletion behavior while SwiftData/CloudKit mirroring remains the app's shipping sync path.

## Boundary Rule

The existing Core Data zone is read-only evidence in Phase 1. It is not a source to mutate, repair, normalize, delete, or migrate from automatically.

Known zone name:

- `com.apple.coredata.cloudkit.zone`

Proposed CKSyncEngine shadow zone:

- `WritingShedProSyncZone`

## Phase 1 Handling

The read-only inspector may report whether the existing Core Data zone exists.

The inspector may classify the zone separately from `_defaultZone`, `WritingShedProSyncZone`, and foreign zones.

The inspector must not decode Core Data private metadata as part of Phase 1 unless a separate read-only decoder plan is reviewed.

The inspector must not compare Core Data zone records to local SwiftData records and produce repair instructions in Phase 1.

## Migration Boundary

There is no automatic migration from the Core Data zone to the CKSyncEngine shadow zone in Phase 1.

Future migration must be a separate reviewed phase with:

- Source-of-truth selection per device/account.
- A dry-run report before any write.
- Rollback instructions.
- A clear decision about preserving, retiring, or ignoring the old Core Data zone.
- No automatic local SQLite deletion.
- No automatic CloudKit zone deletion.

## Safety Notes

- Missing relationships in existing CloudKit data are not deletion evidence.
- Foreign zones are warnings only.
- `CKErrorDomain` failures from the existing zone do not authorize the new inspector to reset or repair anything.
- Shadow-zone work must never share the existing Core Data zone.
