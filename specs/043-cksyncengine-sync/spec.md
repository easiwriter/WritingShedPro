# Feature Specification: CKSyncEngine Sync Replacement

**Feature Branch**: `043-cksyncengine-sync`  
**Created**: 2026-07-09  
**Status**: Draft  
**Input**: Replace `NSPersistentCloudKitContainer` sync with an explicit `CKSyncEngine` implementation after Cloudflare sync was judged too risky.

## 1. Decision Summary

Writing Shed Pro should move away from `NSPersistentCloudKitContainer` as the automatic sync mechanism for the main SwiftData store. The app has hit repeated reliability issues with a complex schema, relationship timing, cascade behavior, schema drift, large payloads, and opaque CloudKit/Core Data state.

The Cloudflare sync replacement was explored as a proof of concept, but the production path introduces too much new infrastructure and product risk for this app at this stage: custom auth, custom server state, custom conflict handling, D1/R2 lifecycle, migration tooling, and a new operational burden.

The revised direction is to keep CloudKit as the sync transport, but own the sync logic explicitly with `CKSyncEngine`.

## 2. Goals

- Replace `NSPersistentCloudKitContainer` sync with an app-controlled `CKSyncEngine` pipeline.
- Preserve local-first behavior: users can always keep writing offline.
- Sync the existing SwiftData-backed writing model without introducing a separate third-party backend.
- Avoid automatic destructive cleanup or relationship-based deletion during sync.
- Make sync state visible and diagnosable in app-owned logs rather than opaque Core Data/CloudKit metadata.
- Support incremental rollout, starting with read-only/import-only diagnostics before any production export path is enabled.

## 3. Non-Goals

- Do not use Cloudflare, D1, or R2 for core user data sync.
- Do not build a custom account system.
- Do not replace SwiftData as the local persistence layer in this feature.
- Do not attempt a big-bang migration in one release.
- Do not delete user data automatically to resolve sync inconsistencies.
- Do not rely on missing relationships as proof that a record is orphaned.

## 4. Core Principles

- **Local data is the source of immediate truth**: user edits must be saved locally first.
- **CloudKit is a transport, not an authority**: server records mirror app-owned local state.
- **Relationships sync explicitly**: relationship changes must be represented in stable record fields or link records, not inferred from temporary SwiftData relationship state.
- **Deletes are tombstoned first**: local deletes should export tombstones before any permanent purge.
- **No implicit cascade echoes**: importing a remote delete must not generate a second wave of duplicate delete exports.
- **Every sync action is auditable**: imports, exports, conflicts, skipped records, and retries must be logged in app-owned diagnostics.

## 5. Proposed Architecture

### 5.1 Components

- `CKSyncEngineCoordinator`
  - Owns `CKSyncEngine` setup, event handling, state serialization, and scheduling.
  - Runs behind a feature flag while `NSPersistentCloudKitContainer` remains the production sync mechanism.

- `SyncRecordMapper`
  - Converts SwiftData models to and from `CKRecord` values.
  - Defines stable record type names, field names, version fields, tombstone fields, and relationship references.

- `SyncChangeTracker`
  - Tracks local changes that need export.
  - Starts with explicit dirty marking for a narrow model subset before expanding.

- `SyncConflictResolver`
  - Applies deterministic conflict rules per entity type.
  - Defaults to preserving local data and logging conflicts for diagnostics during early phases.

- `SyncDiagnosticsStore`
  - Stores recent sync events in app-owned local state.
  - Feeds Sync Diagnostics UI.

### 5.2 CloudKit Zones

- Use one private database custom zone for Writing Shed Pro data.
- The intended zone name should be explicit and app-owned, for example `WritingShedProSyncZone`.
- The app must detect and report unexpected zones, but must not delete them automatically.

### 5.3 Record Identity

- Each syncable model must have a stable UUID already stored locally.
- CloudKit record names should be deterministic from entity type and UUID.
- Record names must not depend on user-editable names such as project titles.

Example:

```text
Project:<uuid>
Folder:<uuid>
TextFile:<uuid>
Version:<uuid>
```

### 5.4 Relationship Representation

- Relationships must be represented by stable IDs or explicit link records.
- Do not infer deletes from missing relationships during import.
- Many-to-many relationships should continue to use explicit join/link records where possible.
- Relationship updates should be idempotent: applying the same remote relationship state twice must be harmless.

## 6. Rollout Phases

### Phase 0 - Model Inventory and Record Mapping

- Inventory all SwiftData `@Model` types that currently sync.
- Define CloudKit record type, record name, fields, relationship strategy, tombstone behavior, and conflict policy for each entity.
- Produce a mapping table before writing export code.
- Identify large blob fields that must become `CKAsset` values.

Exit criteria:

- Mapping document covers Project, Folder, TextFile, Version, Publication, collections, references, comments, footnotes, styles, and join models.
- No runtime sync behavior is changed.

### Phase 1 - Read-Only CloudKit Inspector

- Add a diagnostics-only CloudKit inspector using direct CloudKit APIs or `CKSyncEngine` state where appropriate.
- List zone existence, record counts by type, and recent server change metadata.
- No local SwiftData mutation.
- No server writes.

Exit criteria:

- Diagnostics can report CloudKit state without affecting data.

### Phase 2 - Import Dry Run

- Fetch remote records into an in-memory or scratch representation.
- Validate record decoding and relationship resolution without writing to SwiftData.
- Report conflicts, missing parents, dangling links, and unsupported schema versions.

Exit criteria:

- A real user zone can be decoded into a dry-run graph report.
- No local SwiftData mutation.

### Phase 3 - Export Dry Run

- Detect local dirty records and produce intended `CKRecord` mutations without uploading them.
- Compare generated records to existing server records where safe.
- Estimate operation counts and asset sizes.

Exit criteria:

- The app can explain what it would upload for a selected project.
- No server writes.

### Phase 4 - Limited Shadow Sync

- Enable CKSyncEngine for a small, low-risk model subset or a test-only zone.
- Keep `NSPersistentCloudKitContainer` production sync active for user data.
- Verify event handling, state persistence, retry behavior, and diagnostics.

Exit criteria:

- Shadow sync completes repeatedly without data mutation risk.

### Phase 5 - Migration Planning

- Design how to disable `NSPersistentCloudKitContainer` sync safely.
- Define whether existing CloudKit records are reused, transformed, or re-exported into a new zone.
- Provide an explicit user-visible migration/recovery plan.

Exit criteria:

- Migration is documented, reversible where possible, and manually testable on multiple devices.

## 7. Functional Requirements

- **FR-001**: The app MUST keep all user edits saved locally before sync is attempted.
- **FR-002**: The app MUST use deterministic CloudKit record names based on stable local IDs.
- **FR-003**: The app MUST represent relationships explicitly and must not delete records solely because a relationship is missing during import.
- **FR-004**: The app MUST tombstone deletes before permanent purge.
- **FR-005**: The app MUST log every import, export, conflict, retry, and skipped record in app-owned diagnostics.
- **FR-006**: The app MUST support dry-run import and dry-run export before any production write path is enabled.
- **FR-007**: The app MUST gate all CKSyncEngine write/export behavior behind an explicit feature flag.
- **FR-008**: The app MUST avoid writing to CloudKit from app launch initialization code.
- **FR-009**: The app MUST preserve existing user data if CKSyncEngine setup fails.
- **FR-010**: The app MUST provide a way to disable CKSyncEngine sync without deleting local data.

## 8. Data Safety Requirements

- Never auto-delete the local SQLite store as a sync recovery action.
- Never delete CloudKit zones automatically.
- Never combine zone deletion with local store reset in one automatic flow.
- Never purge records based only on missing relationships.
- Preserve tombstones across launches until export is confirmed or the user explicitly clears diagnostics/recovery state.
- Prefer duplicate presentation collapse over destructive deduplication until records are proven to be clones.

## 9. Open Questions

- Should CKSyncEngine use the existing Core Data/SwiftData CloudKit zone or a new custom zone?
- How should existing NSPersistentCloudKitContainer records be migrated or retired?
- Which entity subset is safest for the first shadow-sync experiment?
- Should style/template records be local-only defaults, user-syncable records, or both?
- What is the conflict policy for simultaneous edits to formatted text content?
- How should large attributed-content blobs be chunked or represented as `CKAsset` values?

## 10. Initial Validation Plan

- Unit test record-name generation for every syncable entity.
- Unit test model-to-record and record-to-model mapping for required fields.
- Unit test relationship link decoding when parents arrive after children.
- Unit test tombstone export/import behavior.
- Manual test dry-run import against a real development CloudKit zone.
- Manual test dry-run export for one project with folders, files, versions, comments, references, and styles.

## 11. Immediate Next Step

Start Phase 0 with a model inventory and mapping table. No CKSyncEngine runtime code should be added until the mapping is reviewed.