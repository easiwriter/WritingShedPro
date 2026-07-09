# Phase 0: Delete, Tombstone, and Relationship Policy

**Status**: Draft
**Created**: 2026-07-09
**Depends on**: [phase-0-model-inventory.md](phase-0-model-inventory.md)

## Purpose

Define the safety rules CKSyncEngine must follow before any import/export implementation exists. The goal is to prevent the exact failure modes that made the current opaque sync stack risky: relationship timing deletes, cascade echoes, duplicate seed records, and unrecoverable CloudKit batch failures.

## Non-Negotiable Rules

- Never delete a local model because an imported relationship is nil.
- Never treat a missing parent as proof that a child is orphaned.
- Never cascade a remote parent delete by generating fresh local child deletes during import.
- Never use user-editable names as identity or deduplication authority.
- Never create default/seed records on an empty local store until initial import has had a chance to finish.
- Every destructive operation must be represented as explicit intent: tombstone, user delete, or reviewed repair.

## Tombstone Shape

Every syncable record type should have a parallel tombstone representation in the CKSyncEngine layer. The reviewed initial strategy is to use separate `Tombstone` records from the start, rather than delete fields on original records.

| Field | Type | Meaning |
| --- | --- | --- |
| `entityType` | `String` | SwiftData/CKRecord type |
| `entityID` | `String` | Stable UUID string |
| `deletedDate` | `Date` | Time delete intent was created locally |
| `deletedByDeviceID` | `String` | Diagnostics and conflict tracing |
| `deleteReason` | `String` | `userDelete`, `projectTrash`, `emptyTrash`, `repair`, `migration` |
| `parentEntityType` | `String?` | Optional diagnostic parent type |
| `parentEntityID` | `String?` | Optional diagnostic parent ID |

## Delete Lifecycle

1. Local user action marks delete intent.
2. Change tracker records a tombstone before or with the local SwiftData delete.
3. Export sends tombstone/delete intent to CloudKit.
4. Import applies remote tombstone only to the named entity ID.
5. Dependent child cleanup is delayed until all related remote changes for the batch/window have been processed.
6. Permanent purge occurs only after a retention window or explicit user action.

## Relationship Import Policy

Relationship fields are stored as UUID strings. Import should work in two passes:

1. Decode records into local entities by stable ID.
2. Resolve relationships by ID after all currently available records have been decoded.

If a relationship target is missing:

- Keep the source record.
- Store a pending relationship diagnostic.
- Retry resolution after later imports.
- Surface persistent unresolved links in diagnostics.
- Do not delete either side automatically.

## Link Record Policy

Join/link models are first-class records. A link with one temporarily missing endpoint is not an orphan during import.

Cleanup is allowed only when one of these is true:

- The link itself has a tombstone.
- Both endpoints have explicit tombstones and the tombstone retention window has passed.
- A user runs a reviewed repair action that lists the exact link IDs to delete.

## Cascade Echo Prevention

Remote import must distinguish between applying a remote delete and creating a new local delete.

When a remote parent tombstone arrives:

- Apply the parent state by ID.
- Do not call local delete paths that traverse SwiftData cascade relationships.
- Mark child records as pending-parent-deleted if needed for UI filtering.
- Export no child deletes unless local user intent explicitly deleted those child IDs.

## Seed and Default Record Policy

Seed/default records are high-risk because an empty local store can mean import has not run yet.

Applies to:

- `StyleSheet`, `TextStyleModel`, `ImageStyle`
- predefined `PoetryFormModel`
- default `PageSetup` or `PrinterPaper` if those remain SwiftData-owned

Rules:

- Do not create seeds during CKSyncEngine startup until initial import state is known.
- Prefer deterministic local regeneration for built-in data instead of syncing built-in records.
- Sync only user-created/custom variants when practical.
- If seed creation is necessary, it must be gated by an import-settled signal and idempotent stable IDs.

## Diagnostics Requirements

Before runtime sync, diagnostics should be able to report:

- Pending relationship count by entity type.
- Tombstone count by entity type and age.
- Link records with one missing endpoint.
- Seed records that would be created but are blocked by import-not-settled state.
- Deletes suppressed because they would have been cascade echoes.

## Open Questions

- What retention window is long enough for mobile devices that are offline for days or weeks?
- Should project trash and permanent delete use separate tombstone reasons and UI recovery paths?
- Which local SwiftData delete paths can be reused safely, and which need import-specific non-cascading application paths?