# CloudKit Sync Safety Checklist

Use this checklist before merging any change that touches data models, migrations, save flows, or sync diagnostics.

## Goal
Prevent WSP-driven sync regressions such as export storms, queue wedges, duplicate creation, and destructive cleanup during in-flight imports.

## Hard Rules
- Do not add app-driven CloudKit nudges (no forced import/export kicks, no timer-based save pokes).
- Do not schedule automatic local DB reset as a sync recovery action.
- Do not run destructive cleanup based on missing relationships alone.
- Do not mutate large sets of records during reconcile/startup/watchdog paths.
- Do not write `modifiedDate` unless the underlying record meaningfully changed.

## PR Risk Gate (must all be true)
- [ ] No new code path writes during passive reconcile/watchdog loops.
- [ ] No `modelContext.save()` used as a sync "nudge".
- [ ] No auto-reset trigger introduced for sync stalls/rate limits.
- [ ] No bulk-touch/re-export path is automatic (must be explicit user action only).
- [ ] Any cleanup logic treats nil relationships as potentially temporary CloudKit state.
- [ ] New migration steps are safe if CloudKit import is still in progress.
- [ ] New @Model schema changes include CloudKit schema deployment reminder before TestFlight/Release.

## Required Validation
- [ ] Multi-device test (at least 2 devices): create/edit/delete records and verify convergence.
- [ ] Fresh install test on one secondary device: verify import completes without duplicate seed/default records.
- [ ] Diagnostics check: pending exports decreases to 0 after activity settles.
- [ ] Diagnostics check: no repeating code=2/reset loop after normal usage.
- [ ] Verify project/file/version counts converge across devices for at least one active project.

## Diagnostics Red Flags
Treat these as release blockers until explained:
- Pending exports grows continually while app is mostly idle.
- Repeated `CKErrorDomain code=2` followed by reset loops.
- Identical timestamp "waves" across many projects without user edits.
- Reconcile/startup path causes deletions or mass updates.

## Safe Patterns
- Keep sync handling observation-only where possible.
- Use explicit user-triggered recovery actions for destructive operations.
- Prefer fresh `ModelContext(modelContext.container)` reads for diagnostics and verification.
- Debounce UI refreshes, not data mutations.

## Incident Response (Non-Destructive First)
1. Identify source-of-truth device with complete local data.
2. Avoid local DB reset on source-of-truth.
3. Capture diagnostics snapshots on all devices.
4. Confirm whether issue is transport, local queue, or data mutation.
5. Use destructive actions only as explicit, documented operator steps.

## Ownership
Any PR touching sync-sensitive files should reference this checklist in the PR description and state how each gate was satisfied.
