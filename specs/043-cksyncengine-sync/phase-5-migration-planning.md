# Phase 5: Migration Planning

**Status**: Draft
**Created**: 2026-07-09
**Depends on**:

- [phase-4-limited-shadow-sync-plan.md](phase-4-limited-shadow-sync-plan.md)
- [rollout-gates.md](rollout-gates.md)

## Purpose

Define the planning requirements before replacing the existing SwiftData/Core Data CloudKit sync behavior with CKSyncEngine-managed sync.

Migration is not a code task until shadow sync has proven correctness, diagnostics, rollback, and source-of-truth handling.

## Migration Principles

- Local data is the first source of truth unless explicitly proven otherwise.
- Never delete local SQLite automatically as part of migration.
- Never delete CloudKit zones automatically as part of migration.
- Never require all devices to be online at the same time.
- Never rely on relationship nil to infer missing data.
- Migration must be observable before, during, and after it runs.

## Source-of-Truth Selection

Before migration, diagnostics must identify:

- project count
- folder count
- text file count
- version count
- publication/submission count
- reference/comment/footnote count when those are in scope
- latest local edit timestamp
- current sync health and pending operations
- device/account identity

The user should be able to tell which device has the most complete data before any irreversible step.

## Existing Zone Strategy

The existing `com.apple.coredata.cloudkit.zone` must be handled explicitly.

Possible strategies:

| Strategy | Meaning | Risk |
| --- | --- | --- |
| Preserve | Leave old zone untouched; new CKSyncEngine zone becomes active for future sync | Safest rollback, more storage/complexity |
| Ignore | App stops reading old zone after migration but does not delete it | Safe but leaves legacy data behind |
| Retire later | Delete old zone only after long confidence window and explicit user/admin action | Requires support process |

Default recommendation: preserve or ignore first, retire later only after proven rollout.

## Rollback Requirements

Rollback must be possible if:

- CKSyncEngine imports incomplete data
- CKSyncEngine exports unexpected records
- CloudKit account state changes mid-rollout
- a device remains offline through migration
- TestFlight reveals production-schema or entitlement issues

Rollback plan should include:

- feature flag disable path
- preserving old local data until successful verification
- preserving old CloudKit zone initially
- support diagnostics export
- clear instructions for source-of-truth device recovery

## Legacy Mirroring Test Retirement

The existing test suite does not appear to contain tests that directly instantiate `NSPersistentCloudKitContainer`, but it does contain tests for the current SwiftData/Core Data CloudKit mirroring support layer.

Known legacy-sync test files:

- `CloudKitSyncThrottlerTests.swift`
- `SyncHealthMonitorTests.swift`

Keep these tests while the app still ships with `cloudKitDatabase: .automatic` or while any production code still observes `NSPersistentCloudKitContainer` mirroring events.

Do not delete them during Phase 0-4 dry-run or shadow-zone work. They still protect the shipping sync path.

Retire or replace them only when:

- CKSyncEngine is the active production sync path.
- The old `NSPersistentCloudKitContainer` observer/recovery code is removed or fully disabled behind a retired path.
- Equivalent CKSyncEngine tests cover account/zone state, event throttling if still needed, health reporting, failure classification, and non-destructive recovery behavior.

The retirement should be a deliberate migration cleanup commit, not incidental churn during mapper/import/export development.

## User-Facing Recovery Requirements

Any migration UI must avoid vague or destructive actions.

Required wording principles:

- Say whether an action reads, writes, deletes, or only diagnoses.
- Say whether local data will be deleted.
- Say whether CloudKit data will be deleted.
- Say which device is source of truth.
- Require explicit confirmation for destructive operations.

## Production CloudKit Checklist

Before TestFlight/App Store rollout:

- [ ] Confirm entitlements point to the intended iCloud container.
- [ ] Confirm the CKSyncEngine zone name.
- [ ] Confirm development vs production CloudKit environment behavior.
- [ ] Deploy schema changes if any `@Model` changes are made in future phases.
- [ ] Verify TestFlight reads/writes the production environment as expected.
- [ ] Verify diagnostics can distinguish development and production data.

## Migration Acceptance Criteria

- A source-of-truth device can export a complete shadow dataset.
- A second device can import/read the shadow dataset without data loss.
- Diagnostics show matching counts and no unresolved required relationships.
- Rollback has been tested.
- Existing Core Data zone remains available until a later explicit retirement decision.
- Legacy mirroring tests are either still valid for an enabled compatibility path or replaced by CKSyncEngine runtime tests.
- No automatic reset/delete recovery exists for failed migration.

## Stop Point

Do not schedule migration implementation until the user has reviewed the Phase 0-5 documents and accepted the risk model. This is the point where product decision-making matters more than more autonomous specification detail.
