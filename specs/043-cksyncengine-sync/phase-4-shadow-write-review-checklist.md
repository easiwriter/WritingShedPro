# Phase 4: Shadow Write Review Checklist

**Status**: Draft
**Created**: 2026-07-09
**Depends on**:

- [phase-4-limited-shadow-sync-plan.md](phase-4-limited-shadow-sync-plan.md)
- [rollout-gates.md](rollout-gates.md)

## Purpose

Define the review checklist that must pass before adding any CloudKit write code for the CKSyncEngine shadow zone.

This checklist is intentionally stricter than the pure-value Phase 4 scaffolding. Passing unit tests for readiness, planning, diagnostics, stop conditions, and exposure policy is necessary evidence, but it is not permission to add a writer.

## Required Review Decisions

Before any future code creates `CKRecord`, creates `CKAsset`, creates a CloudKit zone, calls `CKSyncEngine`, or saves to CloudKit, explicitly review and record:

- approved shadow zone name: `WritingShedProSyncZone`
- approved first write record types
- whether zone creation is allowed, and under which manual/internal trigger
- exact feature flag location and default value
- exact local kill-switch location and default value
- exact remote kill-switch source and failure behavior
- whether the first write trigger is manual diagnostics-only or runtime-triggered
- whether writes may run on app launch, foreground resume, background task, or editor save
- maximum records allowed per first shadow write attempt
- maximum retry count and minimum retry delay if any retry mechanism exists
- diagnostic text shown before and after the write attempt

## First Write Scope

The default first write scope remains:

- `Project`
- `Folder`
- `TextFile` metadata without assets
- `Version` metadata without formatted-content assets

The first write scope still excludes:

- assets and asset temp files
- formatted content blobs
- comments and footnotes
- references and back matter
- styles and seed/default records
- join/link records unless separately reviewed
- deletes and tombstones unless separately reviewed
- imports into SwiftData
- mutation of local SwiftData models

## Mandatory Preflight Evidence

Before a write path is implemented or enabled, capture a redacted diagnostic report showing:

- `ShadowSyncReadinessReport.canAttemptShadowWrite == true`
- `ShadowSyncZonePreflightReport.confirmsZoneIsolation == true`
- `ShadowSyncOperationPlan.canExecute == true`
- `ShadowSyncStopConditionReport.mustDisableShadowSync == false`
- `ShadowSyncGateReviewReport.isReadyForHumanWriteReview == true`
- `ShadowSyncExposurePolicy.canExposeShadowWriteControls == true` only for debug/internal diagnostics
- `ShadowSyncEnvironmentPolicy.canReviewShadowWriteEnvironment == true`, with production and unknown CloudKit environments blocked by default
- `ShadowSyncAccountPolicy.canReviewShadowWriteAccount == true`, with any non-available CloudKit account status blocked by default
- `ShadowSyncTriggerPolicy.canStartShadowWriteAttempt == true` only for manual diagnostics
- `ShadowSyncRetryPolicy.allowsRetry == false` for the first attempt, or at most one retry with a minimum 300 second delay if retry is explicitly reviewed
- `ShadowSyncBatchPolicy.canAttemptFirstBatch == true` with no more than 10 planned operations for the first attempt
- `ShadowSyncWriteAttemptReviewReport.canReviewFirstWriteAttempt == true` after combining gate, exposure, environment, account, trigger, retry, batch, and side-effect reports
- `ShadowSyncWriteAttemptPreviewReport.redactedText()` is captured before the attempt and contains only zone name, trigger, retry limits, operation counts, record counts by type, and blockers
- `ShadowSyncPreflightEvidenceReport.hasRequiredEvidence == true`, proving read-only inspector, export dry-run, Gate 5 review, and blocker-free redacted preview evidence are captured
- `ShadowSyncManualApprovalReport.hasManualApproval == true`, proving checklist acceptance, reviewer identifier, checklist version, and approval timestamp are recorded
- `ShadowSyncFirstWritePreflightReport.isReadyForManualFirstWriteReview == true`, proving the aggregate review, required evidence, and manual approval all pass
- `ShadowSyncSideEffectReport.allowsSideEffects == true`, meaning the reviewed path declares no SwiftData mutation, no shadow import into SwiftData, no zone creation, no zone deletion, no Core Data zone touch, no asset creation, and no user-facing shadow data usage
- existing SwiftData/Core Data CloudKit sync is still active
- App Store and TestFlight exposure remains blocked

## Hard Blocks

Do not add or enable a write path if any of these are true:

- the target zone is `com.apple.coredata.cloudkit.zone`
- the proposed zone classification is foreign or ambiguous
- the write path can run without both kill switches being off
- the write path can run in App Store or TestFlight builds
- the CloudKit environment is production or unknown
- the CloudKit account status is not available
- the write path can delete CloudKit records without a reviewed tombstone design
- the write path can mutate SwiftData based on shadow import/read results
- the write path can run automatically on launch, foreground resume, editor save, or background task before that trigger is reviewed
- the first write attempt is not manually triggered from reviewed internal diagnostics
- the write path has an unbounded retry loop
- the write path retries more than once or retries sooner than 300 seconds without a new review
- the first write attempt contains more than 10 planned operations or has no executable operation plan
- the aggregate first write attempt review has any blocker, including a side-effect blocker
- the preflight preview exposes record names, content, asset bytes, CloudKit payload details, or private error details
- required preflight evidence is missing or the captured preview is blocked
- manual approval receipt is missing checklist acceptance, reviewer, checklist version, or approval timestamp
- the final first-write preflight report has any review or evidence blocker
- the reviewed path would mutate SwiftData, import shadow records locally, create zones, delete zones, touch the existing Core Data zone, create assets, or use shadow data in user-facing workflows
- the write path can block current app usage or existing sync

## First Manual Test Shape

The first manual test should be small and reversible:

1. Use one internal device and one internal iCloud account.
2. Confirm existing app sync is healthy before starting.
3. Run read-only inspector and local dry-run reports.
4. Generate the Gate 5 review summary and confirm no blockers.
5. Capture the first write attempt preview and confirm it is redacted and blocker-free.
6. Trigger one manual diagnostics-only shadow write attempt for the approved subset.
7. Read the shadow zone back without importing into SwiftData.
8. Compare local dry-run counts with shadow-zone counts.
9. Disable shadow controls and confirm no further shadow operations are planned.

## Explicit Non-Authorizations

This checklist does not authorize:

- replacing current production sync
- exposing shadow write controls to existing App Store or TestFlight users
- importing shadow records into SwiftData
- deleting local data
- deleting CloudKit zones
- migrating production records
- using shadow data in user-facing workflows
