# Phase 4: Limited Shadow Sync Plan

**Status**: Draft
**Created**: 2026-07-09
**Depends on**:

- [phase-2-import-dry-run-plan.md](phase-2-import-dry-run-plan.md)
- [phase-3-export-dry-run-plan.md](phase-3-export-dry-run-plan.md)
- [phase-4-shadow-write-review-checklist.md](phase-4-shadow-write-review-checklist.md)
- [rollout-gates.md](rollout-gates.md)

## Purpose

Define the first phase that may write to a separate CKSyncEngine-owned CloudKit zone. Shadow sync must remain isolated from production user data and from the existing SwiftData/Core Data CloudKit zone.

## Explicit Non-Goals

- No replacement of existing sync.
- No writes to `com.apple.coredata.cloudkit.zone`.
- No deletes of existing CloudKit zones.
- No migration of production records.
- No user-visible reliance on shadow synced data.

## Shadow Zone

Tentative zone name: `WritingShedProSyncZone`.
Reviewed decision: use this as the separate CKSyncEngine shadow zone name.

Rules:

- Create only after Phase 1-3 gates pass.
- Use only for CKSyncEngine shadow records.
- Do not mix with existing Core Data records.
- Provide a kill switch before any write path is enabled.

## First Shadow Scope

Recommended first write subset:

1. `Project`
2. `Folder`
3. `TextFile` metadata without assets
4. `Version` metadata without formatted-content assets

Excluded from first shadow write:

- formatted content assets
- cover images
- comments and footnotes
- references and back matter
- styles and seed/default records
- join/link records unless review pulls them forward
- deletes/tombstones unless explicitly reviewed for the first shadow test

## Runtime Guardrails

- Feature flag defaults off.
- Build flag or internal diagnostics gate required.
- Per-device kill switch required.
- Remote kill switch preferred before TestFlight exposure.
- Shadow sync failure must not block current app usage or current sync.
- Shadow sync must never auto-reset local data or delete CloudKit zones.

Initial pure-value scaffold:

- `ShadowSyncReadinessChecker` validates the reviewed zone name, feature flag state, local kill switch, remote kill switch, first shadow record scope, asset exclusion, and tombstone exclusion before any future write path can be attempted.
- `ShadowSyncConfiguration` defaults to feature disabled and both kill switches enabled.
- `ShadowSyncReadinessReport.canAttemptShadowWrite` is false unless the feature is enabled, both kill switches are disabled, and no readiness errors are present.
- `ShadowSyncOperationPlanner` consumes the Phase 3 export dry-run report and readiness report, then produces a pure-value operation plan only for allowed record saves.
- The planner blocks assets, tombstones, unsupported record types, and any readiness failure before a future writer could see an operation.
- `ShadowSyncAttemptSnapshot` carries last export attempt state, last import/read attempt state, and pending operation count as pure diagnostic values.
- `ShadowSyncDiagnosticsReport` summarizes enabled state, shadow zone, zone preflight status/issues, kill-switch state, existing sync status, readiness, attempt state, operation counts, blockers, stop conditions, comparison mismatches, and a redacted last-error code.
- `ShadowSyncGateReviewReport` summarizes whether the current diagnostics are ready for human review of a future write path, and lists blockers if they are not.
- `ShadowSyncExposurePolicy` blocks App Store and TestFlight exposure by default, even when Gate 5 review diagnostics are clean.
- `ShadowSyncEnvironmentPolicy` requires a development CloudKit environment for review by default, and blocks production or unknown environments.
- `ShadowSyncAccountPolicy` requires an available CloudKit account for review by default, and blocks missing, restricted, unavailable, undetermined, or unknown account states.
- `ShadowSyncTriggerPolicy` allows only a reviewed manual diagnostics trigger; app launch, foreground resume, editor save, and background task triggers remain blocked before any future writer can start.
- `ShadowSyncRetryPolicy` defaults to no retry and permits at most one reviewed delayed retry, with a minimum 300 second delay, only after the manual trigger policy already allows the attempt.
- `ShadowSyncFirstAttemptScopePolicy` limits the first shadow write review to one recorded internal device and one recorded internal iCloud account, with multi-device, multi-account, non-internal-device, and user-facing rollout blocked.
- `ShadowSyncBatchPolicy` requires an executable operation plan and caps the first shadow write attempt at 10 planned operations.
- `ShadowSyncRecordNamespacePolicy` requires every planned record name to use the reviewed `wsp-shadow:` prefix before a future writer can see operations.
- `ShadowSyncWriteAttemptReviewReport` aggregates Gate 5 readiness, exposure, environment, account, trigger, retry, batch, namespace, and side-effect reports into a single final pure-value review summary for a future first write attempt.
- `ShadowSyncWriteAttemptPreviewReport` produces redacted preflight evidence for a future first write attempt, including zone name, trigger, retry settings, operation counts, record counts by type, and blockers, without record names or content.
- `ShadowSyncPreflightEvidencePolicy` requires captured read-only inspector evidence, export dry-run evidence, Gate 5 review evidence, and a blocker-free redacted write attempt preview.
- `ShadowSyncManualApprovalPolicy` requires a recorded approval receipt with checklist acceptance, reviewer identifier, checklist version, approval timestamp, and the exact approved preview identifier.
- `ShadowSyncFirstWritePreflightReport` combines the aggregate write attempt review, required evidence, manual approval, and exact preview binding into a final manual-review readiness summary; it still does not authorize or start a write.
- `ShadowSyncWriterContractPolicy` defines the pure-value boundary a future writer must satisfy: ready final preflight, matching executable operation plan, no automatic start, no scheduler, no unreviewed retry, no SwiftData mutation/import, no zone creation, and no Core Data zone touch.
- `ShadowSyncWriterAttemptResult` defines the redacted result shape a future writer may return: status, operation counts, record counts by type, and redacted error-code presence only, with invalid count combinations and blocked-contract starts rejected.
- `ShadowSyncReadBackValidationPolicy` requires a successful writer attempt and a mismatch-free read-only comparison against the expected operation counts; it blocks SwiftData import/mutation and user-facing shadow data use.
- `ShadowSyncEngineImplementationReadinessPolicy` aggregates final preflight, writer contract, reviewed result/read-back shapes, and implementation-only acknowledgement into a single value that permits beginning implementation work but still does not authorize runtime writes.
- `ShadowSyncSideEffectPolicy` blocks any path that would mutate SwiftData, import shadow records into SwiftData, create CloudKit zones, delete CloudKit zones, touch the existing Core Data zone, create assets, or use shadow data in user-facing workflows.
- `ShadowSyncZonePreflightChecker` combines the readiness report with the Phase 1 read-only inspector report to classify the proposed shadow zone as available, missing, Core Data-targeted, or unexpectedly classified.
- A missing proposed zone is informational only at this stage; any future zone creation still requires a separate reviewed write path.
- `ShadowSyncStopConditionChecker` evaluates production-data risk, unreviewed delete risk, repeated error loops, and latency-impact signals as pure values that require shadow sync to be disabled.
- This scaffold creates no `CKRecord`, no `CKSyncEngine`, no zone, no asset files, and no SwiftData mutations.

## Diagnostics Requirements

Shadow diagnostics should report:

- enabled/disabled state
- current shadow zone ID
- zone preflight status
- last shadow export attempt
- last shadow import/read attempt
- readiness blockers
- stop conditions that require disabling shadow sync
- planned operation count by kind
- record counts by mapped type
- pending operation count
- last error code, redacted
- kill-switch state
- whether existing sync remains active

Attempt-state diagnostics are value snapshots only. They do not imply a scheduler, timer, background task, CloudKit operation, retry loop, or automatic recovery action.

## Gate Review Summary

`ShadowSyncGateReviewReport` is a pre-write review aid. It can say that the current value-level diagnostics are ready for human write-path review only when:

- readiness allows a shadow write attempt
- zone preflight confirms isolation
- the operation plan is executable
- stop conditions do not require disabling shadow sync
- existing app sync is still active

This report does not authorize runtime writes, create a CloudKit zone, bypass kill switches, or mark Gate 5 complete by itself.

Before adding any future CloudKit write code, use [phase-4-shadow-write-review-checklist.md](phase-4-shadow-write-review-checklist.md).

## Existing User Exposure Boundary

Existing users must remain on the current SwiftData/Core Data CloudKit sync path until a separate migration phase is reviewed.

Initial pure-value scaffold:

- `ShadowSyncExposurePolicy` always blocks shadow write controls in App Store and TestFlight channels.
- Debug/internal diagnostics exposure requires internal reviewer approval, remote kill switch off, local kill switch off, and a blocker-free Gate 5 review summary.
- This policy only controls whether future shadow write controls may be exposed; it does not create runtime UI, start sync, create zones, or upload records.
- Environment policy additionally blocks production or unknown CloudKit environments before the aggregate first-write review can pass.
- Account policy additionally blocks any non-available CloudKit account status before the aggregate first-write review can pass.
- Trigger policy additionally requires the future first attempt to be manually started from reviewed internal diagnostics; automatic runtime triggers remain blocked even when exposure is otherwise allowed.
- Retry policy additionally defaults to zero retries and blocks immediate or repeated retry loops; a retry can only be represented after the same manual trigger and exposure gates pass.
- First-attempt scope policy additionally blocks multi-device, multi-account, non-internal-device, or user-facing rollout before a future writer can see operations.
- Batch policy additionally blocks empty, non-executable, or oversized first attempts before a future writer can see operations.
- Namespace policy additionally blocks production-style record names; planned records must use the reviewed `wsp-shadow:` prefix.
- The aggregate write attempt review must be blocker-free, including namespace and side-effect blockers, before any future CloudKit writer is implemented or invoked.
- The preflight preview must be captured before any future write attempt and must remain redacted.
- Preflight evidence policy must confirm the read-only inspector, export dry-run, Gate 5 review, and blocker-free preview have all been captured.
- Manual approval policy must record checklist acceptance, reviewer identifier, checklist version, approval timestamp, and the exact approved preview identifier.
- Final first-write preflight must be blocker-free, including approval and preview-mismatch blockers, but remains manual-review evidence only and does not start sync or create CloudKit records.
- Writer contract policy must remain blocker-free before any future CKSyncEngine writer can accept inputs; it blocks mismatched plans, automation, scheduler/retry behavior, SwiftData side effects, zone creation, and Core Data zone interaction.
- Writer attempt result must remain redacted; it may report status, counts, and redacted error-code presence, but not record names, payload content, CloudKit payload details, or private error details.
- Read-back validation must use read-only comparison evidence only; it cannot import shadow records into SwiftData, mutate local models, or expose shadow data in user-facing workflows.
- Implementation readiness may only permit coding the first writer; it still blocks runtime CloudKit writes, production environment use, schedulers, SwiftData mutation, and any unreviewed behavior.
- Side-effect policy must remain blocker-free; shadow write review does not authorize local mutation, zone creation/deletion, production-zone interaction, assets, or user-facing shadow data.

## Comparison Report

Shadow sync should produce a comparison report rather than a user-facing result.

Initial pure-value scaffold:

- `ShadowSyncComparisonReport` compares local dry-run record counts to shadow-zone record counts.
- Mismatches are reported by record type only.
- Excluded asset counts are summarized without body content or asset bytes.
- This report is diagnostics evidence only; no user-facing feature can depend on shadow records.

Example:

```text
Shadow sync comparison
Existing local data:
- Project: 11
- Folder: 64
- TextFile: 143
- Version: 151

Shadow zone:
- Project: 11
- Folder: 64
- TextFile: 143
- Version: 151

Mismatches:
- none

Excluded:
- Version.formattedContent assets: 151
- TextFile.coverImageData assets: 3
```

## Stop Conditions

Disable shadow sync immediately if:

- any operation targets the existing Core Data zone
- any local SwiftData delete is triggered by shadow import
- any CloudKit delete is generated without an explicit reviewed tombstone
- shadow sync errors repeat in a tight loop
- shadow sync increases app launch time or editor save latency noticeably

Initial pure-value scaffold:

- `ShadowSyncStopConditionChecker` converts stop-condition signals into a `ShadowSyncStopConditionReport`.
- `ShadowSyncStopConditionReport.mustDisableShadowSync` is true whenever any stop condition is present.
- Reviewed tombstone-backed delete signals can pass through the checker; unreviewed CloudKit delete signals cannot.
- Latency-impact detection is an input signal for this phase, not a runtime measurement implementation.

## Acceptance Criteria

- Shadow sync can be enabled for a small internal dataset.
- Existing app sync remains the source of truth.
- Disabling the flag stops all shadow operations.
- Shadow zone records match local dry-run counts for the first subset.
- No user-facing feature depends on shadow records.
- No existing CloudKit zone or local SQLite store is modified by recovery actions.
