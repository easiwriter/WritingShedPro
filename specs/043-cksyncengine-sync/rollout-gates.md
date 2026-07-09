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

Readiness scaffolding exists in `ShadowSyncReadinessChecker`, `ShadowSyncZonePreflightChecker`, `ShadowSyncOperationPlanner`, `ShadowSyncBatchPolicy`, `ShadowSyncStopConditionChecker`, `ShadowSyncAttemptSnapshot`, `ShadowSyncDiagnosticsReport`, `ShadowSyncGateReviewReport`, `ShadowSyncExposurePolicy`, `ShadowSyncEnvironmentPolicy`, `ShadowSyncAccountPolicy`, `ShadowSyncTriggerPolicy`, `ShadowSyncRetryPolicy`, `ShadowSyncWriteAttemptReviewReport`, `ShadowSyncWriteAttemptPreviewReport`, `ShadowSyncPreflightEvidencePolicy`, `ShadowSyncManualApprovalPolicy`, `ShadowSyncFirstWritePreflightReport`, `ShadowSyncSideEffectPolicy`, and `ShadowSyncComparisonReport`. This is necessary evidence for Gate 5, but it does not complete the gate because no CloudKit write path has been reviewed or enabled.

Proceed only when:

- [ ] A separate CKSyncEngine zone is confirmed by read-only preflight or a reviewed creation path.
- [ ] Shadow sync writes only a tiny, reversible subset agreed at review.
- [ ] Existing app sync remains the source of truth.
- [ ] Shadow sync has a kill switch.
- [ ] Stop conditions force shadow sync disabled before runtime writes can continue.
- [ ] Diagnostics can compare local data, existing sync state, and shadow zone state.
- [ ] Gate 5 review summary has no blockers and is explicitly reviewed.
- [ ] CloudKit environment is confirmed as development; production and unknown environments remain blocked.
- [ ] CloudKit account status is confirmed as available; non-available account states remain blocked.
- [ ] The first write trigger is manual diagnostics-only; automatic launch, foreground, editor-save, and background-task triggers remain blocked.
- [ ] Retry behavior defaults to none; any reviewed retry is capped at one attempt with a minimum 300 second delay.
- [ ] First write scope is limited to one recorded internal device and one recorded internal iCloud account.
- [ ] The first manual write attempt has an executable plan and contains no more than 10 planned operations.
- [ ] Planned record names use the reviewed `wsp-shadow:` namespace and do not reuse production-style names.
- [ ] The aggregate first write attempt review combines all pure-value gates, including namespace and side-effect policy, and has no blockers.
- [ ] The preflight preview report is captured and redacted before any future write attempt.
- [ ] Preflight evidence confirms read-only inspector, export dry-run, Gate 5 review, and blocker-free preview are all captured.
- [ ] Manual approval receipt records checklist acceptance, reviewer identifier, checklist version, approval timestamp, and the exact approved preview identifier.
- [ ] Final first-write preflight combines aggregate review, required evidence, manual approval, and exact preview binding with no blockers.
- [ ] Future writer boundary accepts only a ready final preflight and matching executable operation plan, with automation, scheduler/retry behavior, SwiftData side effects, zone creation, and Core Data zone touch blocked.
- [ ] Future writer attempt result is redacted to status, counts, redacted error-code presence, and blockers only.
- [ ] Future read-back validation uses a successful writer attempt and mismatch-free read-only comparison, with SwiftData import/mutation and user-facing shadow data blocked.
- [ ] Implementation readiness explicitly permits coding the first writer only, while runtime writes, production use, schedulers, and SwiftData mutation remain blocked until a separate implementation review.
- [ ] Side-effect policy confirms no SwiftData mutation, shadow import, zone creation, zone deletion, Core Data zone touch, asset creation, or user-facing shadow data usage.
- [ ] App Store and TestFlight exposure remain blocked unless a later release gate explicitly changes that policy.
- [ ] [phase-4-shadow-write-review-checklist.md](phase-4-shadow-write-review-checklist.md) is accepted or updated before any write code is added.

Stop if:

- Shadow writes can mutate or delete production user data.
- Shadow sync shares a zone with existing Core Data records.
- Shadow sync targets production or an unknown CloudKit environment.
- Shadow sync does not have an available CloudKit account.
- Shadow sync first write scope is not limited to one internal device and one internal iCloud account.
- Shadow sync cannot be disabled remotely or by build flag.
- Shadow sync retries in a tight or unbounded loop.
- Shadow sync starts with an empty, non-executable, or oversized first batch.
- Shadow sync plans record names outside the reviewed shadow namespace.
- Shadow sync has any aggregate first write attempt review blocker.
- Shadow sync cannot show a redacted preflight preview before the first write attempt.
- Shadow sync cannot prove required preflight evidence has been captured.
- Shadow sync cannot prove manual checklist approval has been recorded.
- Shadow sync cannot prove manual approval matches the exact captured write attempt preview.
- Shadow sync has any final first-write preflight blocker.
- Shadow sync has any writer boundary blocker.
- Shadow sync cannot produce a redacted and count-consistent writer attempt result.
- Shadow sync cannot produce a mismatch-free read-only validation without local mutation or user-facing shadow data use.
- Shadow sync treats implementation readiness as runtime write approval.
- Shadow sync has any side-effect blocker.

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
