# CKSyncEngine Rollout Gates

**Status**: Draft
**Created**: 2026-07-09

## Purpose

Define hard gates for replacing the current SwiftData/CloudKit sync stack with CKSyncEngine. Each gate must be satisfied before moving to the next phase. The default answer at every gate is "stop and review" rather than "keep shipping sync behavior."

## Gate 0: Phase 0 Mapping Review

Proceed only when:

- [ ] [phase-0-review-checklist.md](phase-0-review-checklist.md) is accepted or updated.
- [ ] First dry-run mapper scope is confirmed.
- [ ] Local-only/deferred model categories are confirmed.
- [ ] Tombstone representation is selected.
- [ ] Asset strategy is accepted for formatted text, notes, and cover images.
- [ ] No `@Model` schema changes are required for the dry-run mapper.

Stop if:

- Any user data model lacks a stable identity or relationship strategy.
- Any model still relies on relationship nil as delete/orphan evidence.
- Any default/seed record creation path would race initial import.

## Gate 1: Dry-Run Mapper

Proceed only when:

- [x] Mapper can produce deterministic envelopes for the first subset.
- [x] Mapper tests cover record identity, skipped local-only fields, asset placeholders, and pending relationships.
- [x] Dry-run reports are redacted by default.
- [x] Dry-run execution makes no CloudKit calls.
- [x] Dry-run execution makes no SwiftData mutations.

Stop if:

- Mapper output depends on relationship array ordering.
- Mapper silently drops unsupported records.
- Mapper includes manuscript rich text or private body content in reports by default.

## Gate 2: Read-Only CloudKit Inspector

Proceed only when:

- [x] Inspector reads account/database/zone state without writes.
- [x] Inspector classifies existing Core Data zone, default zone, proposed CKSyncEngine zone, and foreign zones.
- [x] Inspector can be run twice with a fake client without changing CloudKit or SwiftData state.
- [x] Missing proposed CKSyncEngine zone is informational only.
- [x] Foreign zone findings are warnings only; no delete actions exist in Phase 1.
- [x] Skipped-by-default system-client read-only test is manually verified against a real account/device.
- [x] Token policy is reviewed before any database/zone change-token reads are added: [phase-1-token-policy.md](phase-1-token-policy.md).
- [x] Existing Core Data zone migration boundary is documented: [phase-1-existing-coredata-zone-boundary.md](phase-1-existing-coredata-zone-boundary.md).

Manual verification completed on 2026-07-09: `CloudKitReadOnlyInspectorTests/testSystemClientReadOnlyInspectorCanRunTwiceWhenExplicitlyEnabled` ran with `WSP_RUN_REAL_CLOUDKIT_INSPECTOR=1`, did not skip, and the environment variable was removed afterward.

Stop if:

- Inspector persists production change tokens before token policy is reviewed.
- Inspector suggests reset/delete/repair actions based on read errors.
- Inspector fetches asset body data by default.

## Gate 3: Import Dry Run

Proceed only when:

- [x] Import decoder can parse CKRecord-shaped envelopes into pending local operations without saving them.
- [x] Child-before-parent imports are held as pending relationships.
- [x] Tombstones are decoded as explicit delete intents, not immediate cascades.
- [x] Import dry-run report lists inserts, updates, deletes, pending relationships, conflicts, and unsupported records.
- [x] Existing local data remains unchanged after every import dry-run.
- [x] Conflict policy is reviewed and tested.
- [x] Link records with missing endpoints remain pending rather than orphaned/deleted.

Stop if:

- Any missing parent causes local delete/cleanup behavior.
- Any remote tombstone would call a SwiftData cascade path directly.
- Any conflict cannot be represented without mutating local models.

## Gate 4: Export Dry Run

Proceed only when:

- [x] Local change tracker can identify changed records without relying on opaque Core Data export state: [phase-3-change-tracker-policy.md](phase-3-change-tracker-policy.md).
- [x] Export dry-run builds CKRecord-shaped envelopes and tombstones without saving to CloudKit.
- [x] Asset placeholders are counted and reported.
- [x] Local-only fields remain excluded.
- [x] Report includes records skipped because they are deferred/local-only.
- [x] Asset size policy is reviewed before any temp-file or CKAsset preparation exists: [phase-3-asset-size-policy.md](phase-3-asset-size-policy.md).

Stop if:

- Change detection misses rich-text/content edits.
- Delete intent cannot be distinguished from relationship detachment.
- Default/seed records would be exported before import-settled state.

## Gate 5: Limited Shadow Sync

Readiness scaffolding exists in `ShadowSyncReadinessChecker`, `ShadowSyncZonePreflightChecker`, `ShadowSyncOperationPlanner`, `ShadowSyncStopConditionChecker`, `ShadowSyncAttemptSnapshot`, `ShadowSyncDiagnosticsReport`, `ShadowSyncGateReviewReport`, `ShadowSyncExposurePolicy`, and `ShadowSyncComparisonReport`. This is necessary evidence for Gate 5, but it does not complete the gate because no CloudKit write path has been reviewed or enabled.

Proceed only when:

- [ ] A separate CKSyncEngine zone is confirmed by read-only preflight or a reviewed creation path.
- [ ] Shadow sync writes only a tiny, reversible subset agreed at review.
- [ ] Existing app sync remains the source of truth.
- [ ] Shadow sync has a kill switch.
- [ ] Stop conditions force shadow sync disabled before runtime writes can continue.
- [ ] Diagnostics can compare local data, existing sync state, and shadow zone state.
- [ ] Gate 5 review summary has no blockers and is explicitly reviewed.
- [ ] App Store and TestFlight exposure remain blocked unless a later release gate explicitly changes that policy.

Stop if:

- Shadow writes can mutate or delete production user data.
- Shadow sync shares a zone with existing Core Data records.
- Shadow sync cannot be disabled remotely or by build flag.

## Gate 6: Migration Planning

Proceed only when:

- [ ] Source-of-truth selection is explicit per device/account.
- [ ] Rollback strategy is documented and tested.
- [ ] Existing Core Data zone handling is documented: preserve, ignore, or retire later.
- [ ] Legacy mirroring tests have an explicit keep/replace/remove decision.
- [ ] User-visible recovery path is documented.
- [ ] TestFlight and App Store CloudKit schema/deployment steps are documented.

Stop if:

- Migration requires deleting local SQLite automatically.
- Migration requires deleting CloudKit zones automatically.
- Migration has no source-of-truth verification step.
- Migration cannot tolerate devices being offline during rollout.

## Release Principle

The CKSyncEngine replacement should not become user-facing until diagnostics can explain what it will do before it does it. For this app, an unexplained sync action is a product risk, not just a technical debt item.
