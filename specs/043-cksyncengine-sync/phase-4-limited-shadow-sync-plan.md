# Phase 4: Limited Shadow Sync Plan

**Status**: Draft
**Created**: 2026-07-09
**Depends on**:

- [phase-2-import-dry-run-plan.md](phase-2-import-dry-run-plan.md)
- [phase-3-export-dry-run-plan.md](phase-3-export-dry-run-plan.md)
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

## Existing User Exposure Boundary

Existing users must remain on the current SwiftData/Core Data CloudKit sync path until a separate migration phase is reviewed.

Initial pure-value scaffold:

- `ShadowSyncExposurePolicy` always blocks shadow write controls in App Store and TestFlight channels.
- Debug/internal diagnostics exposure requires internal reviewer approval, remote kill switch off, local kill switch off, and a blocker-free Gate 5 review summary.
- This policy only controls whether future shadow write controls may be exposed; it does not create runtime UI, start sync, create zones, or upload records.

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
