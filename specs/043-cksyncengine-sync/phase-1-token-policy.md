# Phase 1: Read-Only Token Policy

**Status**: Reviewed - in-memory tokens only for Phase 1
**Created**: 2026-07-09
**Depends on**:

- [phase-1-read-only-inspector-plan.md](phase-1-read-only-inspector-plan.md)
- [rollout-gates.md](rollout-gates.md)

## Purpose

Define how early CKSyncEngine diagnostics may use CloudKit change tokens without accidentally becoming a production sync participant. Phase 1 must remain read-only, repeatable, and safe to run while the current SwiftData/CloudKit stack remains the only shipping sync path.

## Policy

Phase 1 inspector code may read account status and zone names without storing tokens.

Phase 1 code must not persist CloudKit database, zone, or record change tokens to production app storage.

If a future diagnostic needs token-based reads, tokens must be either:

- In-memory only for a single diagnostic run, or
- Stored in a clearly test-only store that is unavailable in production builds.

Token-based reads must not be used to decide local resets, CloudKit zone deletes, record cleanup, relationship repair, or SwiftData mutations.

## Allowed in Phase 1

- `CKContainer.accountStatus`.
- Private database zone listing.
- One-shot metadata reads that do not require persisted tokens.
- Fake-client tests for repeated runs and error handling.

## Not Allowed in Phase 1

- Persisting production `CKServerChangeToken` values.
- Subscriptions.
- Long-lived polling loops.
- Any operation that saves or deletes records, zones, or subscriptions.
- Treating read errors as evidence that local or remote data should be changed.

## Decision Needed Before Token-Based Reads

Before adding `CKFetchDatabaseChangesOperation` or `CKFetchRecordZoneChangesOperation` as part of the inspector, choose one of these options:

1. Keep all tokens in memory and accept that every diagnostic run starts fresh.
2. Add a DEBUG/simulator-only token store for developer diagnostics.
3. Delay token-based reads until Phase 3/4 when the CKSyncEngine runtime storage design exists.

Reviewed decision: choose option 1 for Phase 1. Keep tokens in memory only, and accept that every diagnostic run starts fresh. This keeps diagnostics repeatable and prevents token state from becoming another hidden sync state.
