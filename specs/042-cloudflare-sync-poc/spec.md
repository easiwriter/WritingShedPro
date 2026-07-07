# Feature Specification: Cloudflare Sync Proof of Concept

**Feature Branch**: `042-cloudflare-sync-poc`  
**Created**: 2026-07-03  
**Status**: Draft  
**Input**: User request: replace the abandoned Ensembles port with a Cloudflare-backed sync proof of concept after repeated SwiftData/CloudKit blocking failures.

## Overview

Writing Shed Pro currently relies on SwiftData with CloudKit mirroring for cross-device sync. That stack has produced repeated user-visible sync failures: blocked exports, `CKErrorDomain code=2`, resurrection of older server state, opaque retry queues, inconsistent relationship timing, and recovery flows that are hard to reason about safely.

Ensembles3 was evaluated as a potential replacement, but its binary artifacts do not include Mac Catalyst slices. Since WSP ships as a Catalyst app, Ensembles3 is not viable unless the vendor ships Catalyst-compatible artifacts or source.

This feature defines a small Cloudflare-backed sync proof of concept. The goal is not to port all WSP data immediately. The goal is to prove that WSP can synchronize one project through an explicit, inspectable server authority where changes are visible as operations or deterministic snapshots.

The existing SwiftData store remains the local app database. The Cloudflare service acts as the sync authority and audit trail, not as the live editor store.

## Goals

- Prove deterministic sync for one project between two app instances/devices.
- Replace opaque graph mirroring with explicit sync records that can be inspected and repaired.
- Prevent deleted or trashed state from being silently resurrected by stale clients.
- Keep production CloudKit mirroring untouched during the POC.
- Produce enough cost, performance, and operational evidence to decide whether to proceed to a full migration.

## Non-Goals

- Do not replace production CloudKit sync in this phase.
- Do not sync every WSP entity type.
- Do not build account management, web dashboards, or admin tooling beyond basic D1/R2 inspection.
- Do not sync keystroke-by-keystroke edits.
- Do not migrate existing users or disable CloudKit.
- Do not store app secrets in the app binary.

## Cloudflare Stack

### Worker API

The Worker receives sync requests from the app, authenticates them, validates payloads, writes operation records to D1, stores larger payloads in R2, and returns changes since the client's last cursor.

Initial endpoints:

- `POST /api/sync/v1/bootstrap`
- `POST /api/sync/v1/head`
- `POST /api/sync/v1/push`
- `POST /api/sync/v1/peek`
- `POST /api/sync/v1/pull`
- `POST /api/sync/v1/snapshot`
- `GET /api/sync/v1/health`

### D1

D1 stores inspectable sync metadata and operation history:

- users or anonymous install identities for the POC
- devices
- projects
- project membership/device cursors
- operation log
- tombstones
- conflict records
- snapshot metadata

D1 is the first place to inspect server truth when debugging. Tables must be indexed by project id, operation sequence, device id, and logical entity id.

### R2

R2 stores larger immutable blobs:

- compressed project snapshots
- large attributed-content payloads if they exceed operation-log thresholds
- future backup bundles or media blobs

R2 should not be used for small metadata rows that D1 can handle directly.

### Local App Store

SwiftData remains the local store. A new sync layer reads local changes and applies remote changes explicitly. The POC must be isolated behind a development flag and must not alter the default CloudKit model configuration.

## Pricing Estimate

Cloudflare pricing at the time of this spec:

- Workers Paid plan: about `$5/month`, `$60/year`
- Workers Standard includes about `10M` requests/month, then about `$0.30/M`
- D1 Paid includes about `25B` rows read/month, `50M` rows written/month, and `5GB` storage
- R2 includes about `10GB-month` free storage, then about `$0.015/GB-month`; egress is free

Expected cost for the POC is `$0-$5/month` depending on whether it stays on the free tier or uses Workers Paid features.

Expected cost for an early production sync service is approximately `$5/month` (`$60/year`) for WSP's likely near-term usage. Text-heavy sync should fit comfortably inside D1 included limits. The main cost driver is large blob volume: images, repeated full-project snapshots, backups, and any future media.

This is financially acceptable compared with Ensembles at `$99/year`, especially because Cloudflare also provides inspectability, logs, server-side validation, and repair options.

## POC Sync Model

### Identity

Each app install participating in the POC gets a stable device id. For the first POC, user identity may be a developer/test token rather than production account login.

Each synced entity needs a stable logical id independent of SwiftData object identity. Existing UUID fields should be reused where they already exist.

### Operation Log

Each local mutation is represented as an operation with:

- operation id
- project id
- device id
- client timestamp
- server sequence
- entity type
- entity id
- operation type
- base version or base cursor
- payload
- payload hash

The server assigns the canonical sequence. Clients pull operations after their last acknowledged sequence.

### Change Detection

Clients should use a cheap authenticated head check before doing a full pull. The app sends its project id, device id, and last known sequence. The Worker returns the latest project sequence, the server-side device cursor, and whether changes are available. This is the reliable fallback under future silent push notifications: missed pushes are harmless because the app can always ask whether the server sequence has advanced.

### Snapshot Support

The POC should support periodic project snapshots so a device can recover without replaying an unbounded operation log. A snapshot is immutable and references an R2 object plus D1 metadata.

Snapshots are not the only sync mechanism. They are recovery and compaction checkpoints.

### Conflict Rule for POC

The first POC should use deterministic last-server-sequence-wins for simple scalar fields, plus explicit tombstone priority for deletes/trash:

- If an entity has a server tombstone at sequence `S`, older updates with sequence `< S` must not resurrect it.
- Restore must be an explicit operation after the tombstone sequence.
- Conflicts must be logged, not silently hidden.

This is intentionally conservative. Richer merge policy can come later.

## POC Scope

The POC syncs one project and the minimal graph needed to prove core behavior:

- `Project`
- top-level `Folder`
- `TextFile`
- text content for plain or serialized attributed content
- workflow status
- trash/delete state

Optional only if cheap:

- one version record
- one comment
- one footnote

Out of POC scope:

- publications/submissions
- poetry collections/books/acts/scenes links
- style sheets
- references/index/glossary/citations
- image blobs beyond one tiny sample
- CloudKit migration

## User Stories & Tests

### User Story 1 - Project Rename Sync (P1)

A writer renames a project on Device A. Device B pulls changes and shows the same project name without creating a duplicate.

**Acceptance Scenarios**:

1. Given Device A renames a synced project, when Device A pushes and Device B pulls, then Device B shows the new name.
2. Given Device B was offline during the rename, when it reconnects and pulls, then it applies the server sequence without duplicating the project.
3. Given Device B has an older local name, when it pushes after pulling, then it must not overwrite the newer server name unless it creates a newer explicit rename operation.

### User Story 2 - Trash and Restore Without Resurrection (P1)

A writer moves a project or file to Trash on Device A. Device B must not resurrect it with older local state.

**Acceptance Scenarios**:

1. Given Device A trashes a file, when Device B pulls, then the file is trashed on Device B.
2. Given Device B has an older edit for that file, when it pushes after the tombstone sequence, then the server rejects or records the stale update as a conflict instead of resurrecting the file.
3. Given Device A restores the file later, when Device B pulls, then the file is restored because restore is a newer explicit operation.

### User Story 3 - Text Edit Sync (P1)

A writer edits one text file on Device A. Device B receives the edited content after pull.

**Acceptance Scenarios**:

1. Given Device A edits text content and pushes, when Device B pulls, then Device B displays the updated text.
2. Given the text payload exceeds the inline threshold, when Device A pushes, then D1 stores metadata and R2 stores the payload object.
3. Given Device B pulls a payload stored in R2, then it validates the content hash before applying.

### User Story 4 - Inspectable Server Truth (P1)

The developer can inspect D1/R2 and explain the current state of a project without reading client device logs.

**Acceptance Scenarios**:

1. Given a project has been renamed and edited, when the developer queries D1, then the operation sequence shows those operations in order.
2. Given a file was trashed, when the developer queries tombstones, then the tombstone row identifies entity id, operation id, and server sequence.
3. Given a snapshot exists, when the developer inspects D1 metadata, then the matching R2 object key and hash are visible.

### User Story 5 - POC Isolation (P1)

The POC can be enabled and disabled without affecting production CloudKit sync.

**Acceptance Scenarios**:

1. Given the POC flag is disabled, when WSP launches, then the existing CloudKit-backed `ModelContainer` path is used.
2. Given the POC flag is enabled in a debug build, when WSP launches, then only the test sync service is active.
3. Given the POC is disabled after testing, when WSP relaunches, then normal user data and CloudKit sync are unchanged.

## Functional Requirements

### Server

- **FR-001**: Worker MUST validate all request payloads and reject malformed operations.
- **FR-002**: Worker MUST authenticate POC clients with a server-side secret or signed test token. No production-grade auth is required in Phase 1, but unauthenticated writes are forbidden.
- **FR-003**: Worker MUST assign monotonically increasing server sequence numbers per project.
- **FR-004**: Worker MUST persist every accepted operation in D1 before acknowledging success.
- **FR-005**: Worker MUST store large payloads in R2 and persist hash/object metadata in D1.
- **FR-006**: Worker MUST reject or quarantine stale operations that attempt to update an entity after a newer tombstone.
- **FR-007**: Worker MUST expose a pull endpoint that returns operations after a client cursor.
- **FR-008**: Worker MUST record conflict/quarantine rows for rejected stale writes.
- **FR-009**: Worker MUST return structured error responses suitable for app diagnostics.
- **FR-010**: Worker MUST set conservative CPU/request limits to avoid runaway cost.

### App

- **FR-011**: App MUST keep CloudKit mirroring as the default path during the POC.
- **FR-012**: App MUST gate Cloudflare POC code behind a debug/developer flag.
- **FR-013**: App MUST not send every keystroke; it must batch or debounce text edits.
- **FR-014**: App MUST serialize supported POC entities into stable DTOs independent of SwiftData object references.
- **FR-015**: App MUST apply pulled operations idempotently.
- **FR-016**: App MUST persist its last acknowledged server cursor locally.
- **FR-017**: App MUST log sync request ids and server sequences for diagnostics.
- **FR-018**: App MUST provide a debug-only status view or log output showing last push, last pull, cursor, and last error.

### Data Safety

- **FR-019**: POC MUST NOT delete or mutate production CloudKit data as part of setup, testing, or rollback.
- **FR-020**: POC MUST NOT auto-migrate existing CloudKit users.
- **FR-021**: POC MUST support clearing local POC metadata without clearing production SwiftData stores.
- **FR-022**: POC MUST fail closed: if the server cannot validate an operation, it rejects it rather than guessing.

## Proposed D1 Tables

```sql
CREATE TABLE devices (
  id TEXT PRIMARY KEY,
  display_name TEXT,
  created_at TEXT NOT NULL,
  last_seen_at TEXT
);

CREATE TABLE projects (
  id TEXT PRIMARY KEY,
  canonical_name TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  latest_sequence INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE operations (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  server_sequence INTEGER NOT NULL,
  client_timestamp TEXT,
  received_at TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation_type TEXT NOT NULL,
  base_sequence INTEGER,
  payload_json TEXT,
  payload_r2_key TEXT,
  payload_hash TEXT,
  FOREIGN KEY(project_id) REFERENCES projects(id)
);

CREATE UNIQUE INDEX operations_project_sequence_idx
ON operations(project_id, server_sequence);

CREATE INDEX operations_entity_idx
ON operations(project_id, entity_type, entity_id);

CREATE TABLE tombstones (
  project_id TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation_id TEXT NOT NULL,
  server_sequence INTEGER NOT NULL,
  deleted_at TEXT NOT NULL,
  PRIMARY KEY(project_id, entity_type, entity_id)
);

CREATE TABLE device_cursors (
  project_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  last_pulled_sequence INTEGER NOT NULL DEFAULT 0,
  last_pushed_sequence INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  PRIMARY KEY(project_id, device_id)
);

CREATE TABLE snapshots (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  server_sequence INTEGER NOT NULL,
  r2_key TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE conflicts (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  operation_id TEXT,
  device_id TEXT,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  reason TEXT NOT NULL,
  payload_json TEXT,
  created_at TEXT NOT NULL
);
```

## Implementation Phases

### Phase 0 - Design and Skeleton

- Create Cloudflare worker project or reuse the existing `cloudflare-worker` structure if appropriate.
- Add D1 migration for POC tables.
- Add local documentation for environment variables and test tokens.
- No WSP app sync behavior changes yet.

### Phase 1 - Server POC

- Implement `/health`, `/push`, and `/pull`.
- Implement D1 operation append with server sequence assignment.
- Implement tombstone rejection/quarantine.
- Add local Worker tests for rename, trash, stale update, and pull cursor.

### Phase 2 - App POC Client

- Add a debug-only `CloudflareSyncPOCService`.
- Serialize one project, one folder, and one text file into DTOs.
- Push changes manually from a debug action.
- Pull changes manually and apply them idempotently.
- Keep the default CloudKit path unchanged.

### Phase 3 - Two-Device Proof

- Run Device A and Device B against the same test project.
- Prove rename, trash/restore, text edit, offline catch-up, and stale-write quarantine.
- Capture D1/R2 inspection evidence.

### Phase 4 - Decision Gate

Proceed only if:

- Two-device POC passes.
- Server truth is understandable by querying D1/R2.
- Costs remain near the `$5/month` floor under realistic test traffic.
- The implementation complexity is lower than continuing to patch SwiftData/CloudKit failure modes.

## Rollback Boundary

Cloudflare POC work must be reversible:

- Keep all app integration behind debug/developer flags.
- Do not modify production CloudKit container configuration.
- Do not alter the main SwiftData schema unless a later migration phase explicitly requires it.
- Keep POC server code in isolated files, migrations, and endpoints.
- Use commits as checkpoints before app integration begins.

Rollback for Phase 0/1 should mean removing the Worker POC endpoints/migrations and deleting the debug app service without touching user data.

## Open Questions

- Should production auth use Apple Sign In, App Store receipt/subscription identity, iCloud account identity, or app-generated sync accounts?
- Should each project sync independently, or should a user-level operation log span all projects?
- What is the right snapshot cadence: every N operations, every N KB, manual checkpoint, or idle-time compaction?
- How much attributed text should be inline JSON versus R2 blob?
- Should conflict resolution remain server-authoritative, or should some entity types allow field-level merges?
- How long should operation history be retained after snapshots?

## Success Criteria

The POC is successful when:

- Two app instances/devices sync one project through Cloudflare.
- A project rename, text edit, trash, restore, and stale update are handled deterministically.
- D1 clearly explains the current server state and operation history.
- A stale client cannot resurrect a trashed/deleted entity.
- R2 stores and validates at least one snapshot or large payload.
- Production CloudKit behavior remains unchanged when the POC flag is off.
