# Feature 042: Ensembles Sync Port

**Status**: Draft
**Priority**: Critical
**Estimated Effort**: 4-8 weeks for production migration; 3-5 days for proof of concept
**Dependencies**: Ensembles3 package integration, SwiftData model inventory, CloudKit container entitlement, existing WSP import/export safety paths
**Created**: 2026-07-03
**Implementation**: TBD

## Overview

Port Writing Shed Pro sync from SwiftData's `NSPersistentCloudKitContainer` mirroring to Ensembles3. The goal is to keep WSP's local SwiftData app model and user workflows, but replace Apple's opaque object-graph CloudKit mirroring layer with Ensembles event-based sync.

Ensembles3 does not use `NSPersistentCloudKitContainer`. Instead, it observes local store saves, records changes as sync events, stores those events in a cloud backend, and replays remote events into other local stores. For the first migration target, WSP should use the Ensembles CloudKit backend so CloudKit remains the user's storage account, but CloudKit is used as file/event transport rather than as a structured Core Data record graph.

This is a sync-layer replacement, not a wholesale app rewrite. Project, folder, text, style, publication, reference, comment, footnote, and manuscript behavior should remain user-visible compatible.

## Goals

1. Remove WSP's dependency on `NSPersistentCloudKitContainer` mirroring for production sync.
2. Preserve existing local SwiftData data and app workflows.
3. Use Ensembles3 with CloudKit backend as the initial replacement sync transport.
4. Provide a safe migration path from existing WSP local stores and current CloudKit-mirrored deployments.
5. Improve diagnosability by replacing opaque mirroring state with explicit Ensembles activity, event, error, attach, detach, and sync status.
6. Validate that create, edit, delete, trash/restore, relationship, style, and large-content changes converge reliably across devices.

## Non-Goals

- Do not redesign the entire WSP data model during this port.
- Do not switch to a custom server in this feature.
- Do not remove SwiftData as the local persistence layer.
- Do not depend on destructive sync recovery as normal operation.
- Do not migrate to paid non-CloudKit Ensembles backends in the initial implementation.
- Do not expose the Ensembles license key in support diagnostics, logs, screenshots, or exported reports.

## Requirements

### 1. Product Requirements

- WSP must sync user writing data across iPhone, iPad, and Mac/Catalyst without relying on `NSPersistentCloudKitContainer`.
- Existing users must not lose local data during migration.
- Users must be able to keep writing while sync is unavailable or catching up.
- Sync status must be understandable without showing raw implementation internals.
- Support diagnostics must include enough information to distinguish local store health, Ensembles attach state, pending local changes, sync activity, and last sync errors.

### 2. Functional Behavior

- The app must initialize an Ensembles-backed SwiftData container for the production sync path.
- The app must preserve the existing SwiftData schema unless a specific model change is required for Ensembles compatibility.
- The app must remove `cloudKitDatabase: .automatic` from the production synced store configuration when Ensembles is active.
- The app must not run `NSPersistentCloudKitContainer` event observers, reset handlers, or zone recovery operations when running under Ensembles sync.
- The app must continue to use existing write coalescing and flush behavior for local data integrity.
- The app must process pending Ensembles changes before background suspension where practical.
- The app must support explicit manual sync from Sync Troubleshooting/Diagnostics.
- The app must surface forced detach, attach failure, authentication/account failure, backend failure, and merge failure states.

### 3. Data Safety

- Migration must be backup-first. Before any destructive local store operation, WSP must create a restorable local backup of the SQLite store and companion files.
- The source-of-truth device must be explicitly identified before any cloud reset, detach, or reseed workflow.
- Resetting or detaching sync must not delete local user writing unless the user explicitly chooses a separate destructive local-data reset.
- WSP must preserve the ability to export `.wsp` backups before and after the migration.
- WSP must not automatically delete projects, folders, files, styles, join links, or references in response to incomplete relationships during sync.
- WSP must not recreate the previous CloudKit failure pattern through app-driven retry storms, save nudges, or automatic reset loops.

### 4. Migration Behavior

- Existing local stores should attach to a new Ensembles cloud dataset using a controlled seed policy.
- Fresh installs should be able to import/replay Ensembles cloud data without creating default records that conflict with imported data.
- Devices still running the old `NSPersistentCloudKitContainer` build must not be allowed to write concurrently into a sync universe that has already moved to Ensembles.
- Migration UX must explain that sync is being upgraded and may need time to rebuild cloud sync data.
- WSP must have an emergency fallback path to open the local store without network sync if Ensembles initialization fails.

### 5. Model Inventory and Compatibility

- Every persisted `@Model` reachable from WSP's main app store must be explicitly listed in the synced schema or intentionally documented as local-only.
- `SceneLocationLink` must be verified and, if persisted, included in the main app schema and Ensembles model list.
- Analyst review models (`ManuscriptReview`, `ReviewSuggestion`) must be classified as one of: local-only transient/cache, persisted local-only, or synced. If synced, remove CloudKit-incompatible assumptions such as `@Attribute(.unique)` and add stable identity.
- All synced entities that can be independently created on multiple devices must define stable global identifiers for Ensembles deduplication.
- Existing `id: UUID` fields should be preferred as global identifiers where they are stable and assigned once.
- Singleton/reference/default objects such as system stylesheets, text styles, image styles, printer papers, page setups, and bundled poetry forms need explicit identity rules to avoid duplicates.
- Join/link models should normally use stable UUID identifiers and retain `.nullify` delete rules unless a tested Ensembles-specific alternative is chosen.

### 6. Conflict Behavior

- Attribute-level merge behavior must be validated for project metadata, file metadata, workflow status, style settings, and rich text content.
- Rich text content conflicts must be treated as high risk. The port must test simultaneous edits to the same `TextFile`/`Version` and document the resulting behavior.
- Delete-vs-edit conflicts must be tested for projects, folders, text files, versions, styles, comments, footnotes, references, and join links.
- Trash/restore semantics must remain deterministic. A restored item must not be silently re-deleted by stale tombstone or old sync events.
- Business-rule repair after merge should run as explicit post-merge validation rather than broad automatic cleanup.

### 7. Platform Scope

- iOS: Supported.
- iPadOS: Supported.
- Mac Catalyst: Supported.
- Simulator/local-file backend: Supported for development and automated proof-of-concept testing.

### 8. Performance

- Initial attach/replay must be acceptable for a realistic source-of-truth library: at least 15 projects, 100+ publications/submissions, rich text versions, footnotes, comments, references, and styles.
- Normal edits should sync without visible UI blocking.
- Backgrounding must flush local edits and give Ensembles a chance to process pending changes.
- Sync activity must not cause disruptive SwiftUI refreshes, sheet dismissal, menu dismissal, or editor focus loss.

### 9. Diagnostics and Support

- Replace CloudKit mirroring diagnostics with Ensembles diagnostics.
- Support reports must include: sync mode, Ensembles package version if available, attach state, current activity, activity progress, last successful sync time, last error, pending local changes if available, store URL, local entity counts, and recent sync events.
- Existing CloudKit-specific recovery controls must be hidden or disabled when Ensembles mode is active.
- Diagnostics must never include the Ensembles activation key.

## Technical Notes

### 1. Architecture

- Add a dedicated sync abstraction such as `SyncEngine` or `SyncCoordinator` so app views and services do not depend directly on either CloudKit mirroring or Ensembles implementation details.
- Introduce an `EnsemblesSyncCoordinator` responsible for activation, container creation or attachment, manual sync, activity status, errors, background flush/process, and diagnostics.
- Keep WSP's business logic writing to SwiftData through `ModelContext`; do not make feature code call Ensembles directly.
- Use the Ensembles local-file backend for repeatable development tests before using CloudKit backend.
- Use the Ensembles CloudKit backend as the first production backend.

### 2. Container Setup

- Current container setup lives in `Write_App.swift` and creates a `ModelContainer` with `cloudKitDatabase: .automatic`.
- Ensembles mode should create or wrap a SwiftData `ModelContainer` via Ensembles APIs and inject that container into SwiftUI.
- App startup must activate the Ensembles license before initializing Ensembles sync.
- The activation key must be stored centrally and kept out of logs and support exports.
- The existing fallback path that opens the local store without CloudKit should be adapted into an offline/local-only fallback if Ensembles initialization fails.

### 3. Existing CloudKit Code to Retire or Gate

- `NSPersistentCloudKitContainer.eventChangedNotification` observers.
- CloudKit mirroring reset observers.
- `CloudKitSyncThrottler` state that is specific to import/export mirroring events.
- Sync recovery actions that delete CloudKit zones or inspect Core Data CloudKit metadata tables.
- Forced re-export workflows based on touching records for persistent history.
- Foreign-zone cleanup workflows.
- CloudKit production schema deployment reminders for purely sync-related changes. These still apply if the app continues to ship any CloudKit-mirrored store, but should not apply to the Ensembles synced store.

### 4. Existing Code to Keep

- `WriteCoalescer` local save coalescing, unless Ensembles testing proves a better boundary.
- Background/editor flush behavior.
- `.wsp` import/export backup paths.
- Conservative no-auto-delete sync safety rules.
- Tombstone safety rules, but they must be reviewed against Ensembles event replay.
- Fresh `ModelContext` diagnostics for local entity counts.

### 5. Data Model Impact

- Prefer no model changes in Phase 1 proof of concept.
- If model changes are required, isolate them and update migration/testing plans.
- If any `@Model` is added to the active schema, verify compatibility with existing local stores before shipping.
- If any identifier field is added for Ensembles `Syncable` conformance, it must be immutable after creation.

### 6. Backward Compatibility

- The migration must assume some users have local data that is more complete than CloudKit.
- The migration must not assume current CloudKit mirrored data is authoritative.
- The source-of-truth device workflow must support users whose other devices are stale, partially imported, or blocked.
- An old app version and new Ensembles version should not both be encouraged to write at the same time.

## Implementation Plan

### Phase 0: Inventory and Safety Baseline

1. Confirm current package integration and license activation build successfully.
2. Create a full synced model inventory from `Write_App.swift` and all `@Model` declarations.
3. Classify each model as synced, local-only, transient/cache, or unused.
4. Verify whether `SceneLocationLink` is missing from the active schema and fix before any sync spike if it is persisted.
5. Identify all `@Attribute(.unique)` usage and decide whether each model is outside the synced store or needs refactoring.
6. Capture baseline diagnostics from current CloudKit sync: entity counts, pending exports, last errors, and source-of-truth device state.
7. Add a migration safety checklist to the spec or implementation PR before touching production sync behavior.

### Phase 1: Local-File Ensembles Proof of Concept

1. Add an experimental build flag or runtime switch for Ensembles mode.
2. Create an Ensembles-backed SwiftData container using the local-file backend.
3. Use a separate development store/cloud directory so the proof of concept cannot damage production user data.
4. Add `Syncable` conformance for the minimal core model set needed to sync one project: `Project`, `Folder`, `TextFile`, `Version`, `StyleSheet`, `TextStyleModel`, `ImageStyle`, and required join/link models.
5. Sync one project between two local stores/processes.
6. Validate create project, rename project, create folder, create file, edit text, delete file, trash/restore project, style change, and version creation/deletion.
7. Document observed conflict behavior.

### Phase 2: CloudKit Backend Spike

1. Switch the proof-of-concept path from local-file backend to Ensembles CloudKit backend.
2. Use a development/test CloudKit container or isolated Ensembles dataset identifier.
3. Attach a source-of-truth device and seed data.
4. Attach a second device using cloud data and verify full replay.
5. Test offline edits on both devices, then reconnect and verify convergence.
6. Test app background/foreground, force quit after edits, and `processPendingChanges()` behavior.
7. Update diagnostics to show Ensembles activity and last errors.

### Phase 3: Full WSP Model Coverage

1. Expand `Syncable` coverage and identity decisions to all synced WSP models.
2. Validate relationships across projects, folders, files, versions, comments, footnotes, publications, submissions, references, glossary, citations, index entries, contributors, page setup, printer paper, poetry forms, fiction/drama/prose structures, and join links.
3. Validate large data fields and external-storage-like blob behavior under Ensembles.
4. Verify default stylesheet and seed/reference data do not duplicate on fresh install or second-device attach.
5. Replace CloudKit-specific diagnostic sections with Ensembles equivalents.
6. Gate old CloudKit recovery UI behind legacy sync mode only.

### Phase 4: Migration Workflow

1. Design a source-of-truth upgrade flow.
2. On first launch of the Ensembles build, back up the local store before attaching.
3. Attach the current local store to the Ensembles cloud dataset using the selected seed policy.
4. Mark migration state locally only after successful attach and first sync attempt.
5. Provide clear instructions for other devices: update app, confirm local backup/export, attach/rebuild from Ensembles cloud, and avoid using older builds concurrently.
6. Provide an offline fallback if attach fails.
7. Provide support recovery steps for forced detach or corrupted Ensembles sync metadata.

### Phase 5: Remove or Retire Legacy Mirroring Paths

1. Remove production dependency on `cloudKitDatabase: .automatic` for the main WSP store.
2. Remove or disable `NSPersistentCloudKitContainer` event monitoring in Ensembles mode.
3. Remove or disable zone delete, reset sync database, force re-export, foreign-zone cleanup, and Core Data CloudKit metadata inspection in Ensembles mode.
4. Rename user-facing sync copy from iCloud/CloudKit mirroring language to local-first sync language where appropriate.
5. Keep any legacy recovery documentation only for users still on old builds.

### Phase 6: Validation and Release Hardening

1. Run multi-device sync soak tests for at least several days.
2. Test large existing projects imported from `.wsp` backups.
3. Test upgrade from a current CloudKit-mirrored build with complete local data.
4. Test upgrade from a stale/partial device.
5. Test no-network, poor-network, iCloud signed out, iCloud account switch, low storage, and app reinstall scenarios.
6. Test simultaneous edit/delete conflicts.
7. Verify support reports contain useful Ensembles state and no secrets.
8. Prepare user-facing release/support notes for the sync migration.

## Acceptance Criteria

- WSP can run with an Ensembles-backed SwiftData container and no `NSPersistentCloudKitContainer` mirroring for the main store.
- A source-of-truth device can attach and upload/replay a realistic WSP library through Ensembles CloudKit backend.
- A second fresh device can attach and reconstruct the same project/file/version/style/publication/reference counts.
- Core workflows converge across two devices: create project, rename project, create file, edit text, apply style, create version, delete version, trash/restore project, delete file, add comment, add footnote, add publication, add reference.
- No automatic destructive recovery runs in response to sync errors.
- Diagnostics clearly show Ensembles activity and last error without exposing the license key.
- Existing `.wsp` export remains available before and after migration.
- Users can open their local data in offline/local-only fallback if sync initialization fails.

## Testing

### Unit Tests

- Model inventory helper, if automated.
- Global identifier generation and immutability assumptions.
- Sync mode selection and fallback behavior.
- Migration state transitions.
- Diagnostics redaction for license/secret material.
- Post-merge invariant checks for tombstones, trash state, default styles, and orphaned join links.

### Integration Tests

- Local-file backend two-store sync for a minimal project.
- Local-file backend sync for a realistic multi-project fixture.
- CloudKit backend two-device sync for the same fixture.
- Attach, detach, reattach, forced detach recovery, and manual sync.
- Background flush/process pending changes.

### Manual Test Cases

- Upgrade source-of-truth device with complete local data.
- Upgrade stale second device after source-of-truth device has completed Ensembles sync.
- Fresh install on iPhone imports/replays existing Ensembles data.
- Fresh install on iPad imports/replays existing Ensembles data.
- Mac/Catalyst imports/replays existing Ensembles data.
- Offline editing on two devices followed by reconnection.
- Simultaneous edit to same text file.
- Delete on one device while editing same object on another device.
- App force quit immediately after editing.
- iCloud signed out / signed back in.

## Risks and Mitigations

- Risk: Existing CloudKit mirrored data is incomplete or corrupted.
- Mitigation: Treat local source-of-truth device as authoritative for migration; require backup/export before attach.

- Risk: Ensembles conflict behavior does not match WSP semantics for rich text or deletes.
- Mitigation: Run proof-of-concept conflict tests before broad integration; add post-merge validation only where deterministic.

- Risk: Default/reference data duplicates on second-device attach.
- Mitigation: Use stable global identifiers for singleton/reference data and delay seed creation until after initial sync state is known.

- Risk: Users run old and new sync engines at the same time.
- Mitigation: Add clear migration messaging and avoid sharing the same active sync metadata path between old mirroring and new Ensembles sync.

- Risk: Third-party framework dependency becomes critical path.
- Mitigation: Keep `.wsp` export/import robust, keep offline fallback, and document recovery/backup procedures.

- Risk: Migration requires model changes that trigger SwiftData store migration issues.
- Mitigation: Keep Phase 1 model changes minimal; add identifiers through existing stable fields where possible.

## Open Questions

1. Should the first production Ensembles dataset use the existing iCloud container or a new/separate iCloud container identifier?
2. Should WSP expose local-first sync as still simply "iCloud Sync" to users, or introduce wording such as "WSP Sync via iCloud"?
3. What exact seed policy should be used for source-of-truth attach and second-device attach?
4. Should the app block editing during the initial source-of-truth attach, or allow editing after local backup completes?
5. How should WSP handle devices that upgrade while their local store is known stale compared with another device?
6. Should analyst review models remain transient/cache-only, or become persisted local-only/synced records later?
7. Is a runtime sync-mode switch needed during development only, or should legacy mode remain in production for a release window?

## Release Notes Draft

- Changed: Rebuilt WSP sync on Ensembles local-first sync instead of Apple's automatic CloudKit mirroring.
- Added: Improved sync diagnostics and safer sync recovery paths.
- Fixed: Reduced exposure to CloudKit schema drift, opaque export queue blockage, and relationship-sync timing failures.
