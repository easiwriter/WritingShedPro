# Phase 2: Import Dry-Run Plan

**Status**: Initial pure-value decoder implemented
**Created**: 2026-07-09
**Depends on**:

- [phase-1-read-only-inspector-plan.md](phase-1-read-only-inspector-plan.md)
- [phase-0-delete-and-relationship-policy.md](phase-0-delete-and-relationship-policy.md)
- [rollout-gates.md](rollout-gates.md)

## Purpose

Define how CKSyncEngine-shaped remote records will be decoded into proposed local operations without saving anything to SwiftData. This phase proves import semantics, relationship timing, tombstones, and conflict reporting before any real import mutation exists.

## Implementation Status

Initial pure-value import dry-run slice added:

- `ImportDryRunDecoder`
- `ImportDryRunReport`
- `ImportDryRunOperation`
- `PendingRelationship`

The decoder accepts fixture `SyncRecordEnvelope` and `SyncTombstoneEnvelope` values. Local state is represented by local envelope snapshots, not live SwiftData models. The decoder does not import CloudKit, write CloudKit, hold a `ModelContext`, save SwiftData, or mutate SwiftData relationships.

Current tests verify:

- Remote records with no local snapshot become `wouldInsert`.
- Matching records become `wouldSkipUnchanged`.
- Changed records become `wouldUpdate` with changed field names.
- Reviewed conflict policy: newer remote `modifiedDate` becomes `wouldUpdate`; older remote `modifiedDate` becomes `wouldSkipUnchanged`; equal modified dates with different fields become `conflict`.
- Child-before-parent records in the same batch do not become pending.
- Child records with missing parents become pending relationships.
- Link records with one missing endpoint become pending relationships, not orphan deletes.
- Link records whose endpoints are present in the same batch do not become pending.
- Missing required relationship IDs produce diagnostics, not deletes.
- Tombstones become explicit `wouldApplyTombstone` intents and do not cascade.
- Unsupported record types appear in the report.
- Redacted reports do not include manuscript content.

Remaining Phase 2 work:

- Add broader record-shape fixtures when extended model mappings are pulled into the implementation scope.

## Explicit Non-Goals

- No SwiftData inserts, updates, deletes, or saves.
- No CloudKit writes.
- No migration from the existing Core Data zone.
- No automatic relationship repair.
- No automatic cleanup of missing parents, children, or link endpoints.

## Proposed Components

| Component | Responsibility |
| --- | --- |
| `ImportRecordEnvelope` | CKRecord-shaped input from tests or read-only inspector samples |
| `ImportDryRunDecoder` | Converts envelopes into proposed local operations |
| `PendingRelationship` | Records unresolved source/target IDs without deleting anything |
| `ImportTombstoneIntent` | Represents remote delete intent without applying cascade behavior |
| `ImportDryRunReport` | Counts inserts, updates, deletes, conflicts, pending relationships, and unsupported records |

## Operation Types

| Operation | Meaning | Mutates local store? |
| --- | --- | --- |
| `wouldInsert` | Remote ID does not exist locally | No |
| `wouldUpdate` | Remote ID exists locally and fields differ | No |
| `wouldSkipUnchanged` | Remote ID exists and fields match | No |
| `wouldApplyTombstone` | Remote delete intent targets a local ID | No |
| `pendingRelationship` | Source decoded but target missing | No |
| `conflict` | Local and remote both changed in incompatible ways | No |
| `unsupported` | Record type not yet mapped | No |

## Child-Before-Parent Behavior

Import dry run must support records arriving in any order.

Example:

1. A `Version` envelope arrives with `textFileID = A`.
2. No local or remote `TextFile:A` is present in the current batch.
3. Decoder emits `wouldInsert Version` plus `pendingRelationship(Version.textFileID -> TextFile:A)`.
4. Decoder does not reject or delete the `Version`.

## Tombstone Behavior

Remote tombstones are proposed operations only.

Rules:

- A tombstone targets exactly one `entityType/entityID`.
- A parent tombstone does not imply child tombstones.
- A link tombstone deletes only the link.
- Cascade-like cleanup is delayed until explicit dependent tombstones or reviewed repair.

## Conflict Reporting

Conflicts should be reported before conflict resolution is implemented.

Initial conflict fields:

- entity type and ID
- local modified date
- remote modified date
- changed fields
- proposed default policy
- whether the field is safe for last-writer-wins

## Tests Before Mutation Import

- [x] Child record before parent becomes pending relationship.
- [x] Link record with one missing endpoint remains pending.
- [x] Parent tombstone does not produce child delete operations.
- [x] Unsupported record type appears in report.
- [x] Existing local record with identical fields is `wouldSkipUnchanged`.
- [x] Existing local record with changed fields is `wouldUpdate`.
- [x] Remote older than local is skipped according to reviewed policy.
- [x] Equal modified dates with different fields are reported as conflict.

## Acceptance Criteria

- [x] Import dry run can process fixture envelopes for the first subset.
- [x] Import dry run can process shuffled envelope order deterministically for child-before-parent cases.
- [x] Import dry run produces a redacted report without changing local data.
- [x] Missing relationship cases in the first subset become diagnostics/pending relationships, not deletes.
- [x] Tombstones remain explicit intents until a reviewed mutation phase.
- [x] Conflict policy is reviewed and covered by tests.
