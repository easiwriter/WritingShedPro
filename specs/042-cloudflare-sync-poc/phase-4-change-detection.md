# Phase 4: Change Detection and Sync Wakeups

**Date**: 2026-07-04  
**Status**: Phase 5 scratch-only apply coverage verified for create/restore-missing, update-existing, and existing-local delete/restore guardrails  
**Scope**: Cheap remote change detection before production notification plumbing

## Purpose

Define how the completed Cloudflare sync path knows there is data to pull.

Silent push notifications can make sync feel immediate, but Apple does not guarantee delivery. The durable mechanism must be cursor-based: every device remembers the latest applied server sequence and can ask the Worker whether the project sequence has advanced.

## Production Readiness Matrix

This matrix maps the verified diagnostic gates back to the remaining production work. The POC is policy-complete only when every category has a verified contract; production implementation can begin from these contracts, but production release still requires real server/client implementation and end-to-end tests.

| Production area | Verified gates | Production meaning |
| --- | --- | --- |
| Server-side identity and account model | `Show Production User Counting`, `Show Production User Lifecycle`, `Show Production User Consent`, `Show Production Apply Authorization Scope` | The backend must identify users/accounts/devices safely, count enrolled and active users, handle revocation and opt-out, and reject stale or cross-project authorization before mutation. |
| CloudKit-to-Cloudflare migration plan | `Show Production Apply Migration Cutover`, `Show Production Apply Migration Progress`, `Show Production Apply Migration Preflight`, `Show Production User Consent`, `Show Production Backup And Export Readiness` | Migration must have source-of-truth rules, visible progress, preflight checks, consent/opt-out behavior, and a recovery export path before sync authority changes. |
| Production SwiftData applier | `Show Production Apply Readiness`, `Show Production Apply Operation Coverage`, `Show Production Apply Transaction Safety`, `Show Production Apply Model Family Coverage`, `Show Production Apply Conflict Policy`, `Show Production Apply Idempotency`, `Show Production Apply Integrity`, `Show Production Apply Destructive Operations`, `Show Production Apply Recovery Drill` | Real production apply must be atomic, idempotent, complete across model families, conflict-aware, integrity-checked, rollback-capable, and never destructive based only on missing relationships. |
| Backend operation and storage coverage | `Show Production Server Schema Readiness`, `Show Production Asset Storage Readiness`, `Show Production Apply Operation Coverage`, `Show Production Apply Model Family Coverage` | Worker, D1, and asset storage must represent all needed records, operations, cursors, tombstones, assets, audits, migration state, and versioned payload formats. |
| Security, rollout, and environment control | `Show Production Apply Rollout Control`, `Show Production Apply Authorization Scope`, `Show Production Environment Separation`, `Show Production Quota And Cost Controls`, `Show Production Apply Compatibility` | Production mutation must be feature-flagged, kill-switchable, environment-isolated, quota-aware, compatible with app/schema versions, and fail closed when configuration is missing or mixed. |
| End-to-end test harness | `Show Production Test Harness Readiness` | Repeatable tests must cover migration, one-device sync, two-device convergence, offline retry, rate limits, conflicts, revocation, asset transfer, large projects, recovery, cursor rollback, and no automatic local-store deletion. |
| Operations, support, and governance | `Show Production Operations Monitoring`, `Show Production Data Retention`, `Show Production Support Runbook`, `Show Production Backup And Export Readiness`, `Show Production Apply Audit Trail`, `Show Production Apply Visible State`, `Show Production Apply Privacy Redaction`, `Show Production Apply Backpressure` | Production must have redacted observability, support runbooks, retention/deletion rules, auditability, visible state, privacy-safe diagnostics, pause/resume behavior, and recovery paths that do not delete local data. |

## Remaining Implementation Work

The verified gates above are production contracts, not production implementation. Before Cloudflare sync can mutate real SwiftData or replace CloudKit authority, the next implementation phase must build and test these concrete pieces:

- Worker/D1 production schema and migrations for users, devices, projects, operations, cursors, tombstones, assets, audit records, rollout state, and migration state.
- Privacy-safe authentication, authorization, user counting, user lifecycle, token revocation, and account opt-out behavior.
- CloudKit-to-Cloudflare migration flow with preflight checks, durable user consent, visible progress, resume/retry state, backup/export guidance, and fail-closed behavior.
- Disabled-by-default production SwiftData applier that validates full operation windows, applies atomically, commits before cursor advancement, and rolls back without destructive cleanup.
- Asset storage path for large payloads with checksums, resumable transfer, deduplication, deletion semantics, cache behavior, and cursor blocking on asset failure.
- End-to-end test harness covering migration, multi-device convergence, offline retry, conflicts, rate limits, token revocation, large payloads, asset transfer, recovery drills, and quota/cost controls.
- Operations layer for metrics, alerts, environment separation, support runbooks, redacted diagnostics, retention/deletion, rollout throttles, budget monitoring, and kill-switch behavior.

## Verification Workflow

As of 2026-07-08, static production-readiness summaries are self-validated with focused editor diagnostics and `git diff --check`; the user does not need to run and paste every fixed-string policy summary. Manual user verification is reserved for diagnostics that exercise real behavior, including Worker requests, scratch materialization, selected-project probes, migration dry-runs, asset transfer checks, failure injection, recovery drills, or any path that reads or writes local or remote state.

Static summaries may still be exposed in Sync Diagnostics so the production contract is visible inside the app, but they remain contract/spec checkpoints rather than production sync implementation. Production code begins only when the next phase implements disabled-by-default Worker/D1 schema, auth, migration, asset, applier, rollout, and recovery components behind explicit flags and focused executable tests.

## Production Implementation Sequence

The next phase should start from the verified contracts above and build production capability in disabled-by-default slices. Each slice must include a focused validation command or manual behavior test before the next slice is wired to lifecycle triggers.

1. **Server foundation, no app mutation**: add versioned Worker/D1 production schema for users, devices, projects, operations, cursors, tombstones, assets, audit records, rollout state, and migration state. Production routes must be environment-separated, feature-flagged, schema-versioned, and rejected by default when configuration is missing or mixed.
2. **Identity and entitlement boundary**: add privacy-safe auth, user counting, account/device registration, project ownership checks, token revocation, and opt-out state. No SwiftData records should be mutated from Cloudflare data in this slice.
3. **Migration planner, no apply**: add CloudKit-to-Cloudflare migration preflight, consent recording, project inventory, progress state, resumable batch planning, backup/export guidance, and fail-closed errors. This slice may read local metadata for planning only; it must not change sync authority or apply remote operations to production SwiftData.
4. **Asset storage path, no cursor advance on failure**: add large-payload upload/download contracts, checksums, resumable transfer, deduplication, deletion semantics, cache behavior, and privacy-safe diagnostics. Asset failure must block migration or apply cursor advancement.
5. **Production applier behind hard flags**: add the real SwiftData applier disabled by default. It must validate complete operation windows, apply atomically, commit before cursor advancement, preserve existing local data on failure, reject missing dependencies, avoid relationship-nil cleanup, and emit redacted audit events.
6. **Orchestrator wiring after applier tests**: wire launch, foreground, network recovery, silent push, and background refresh only after the applier, migration planner, assets, auth, and rollback tests pass. Lifecycle triggers must remain head-first, idempotent, debounce noisy paths, and obey kill switches.
7. **Release and rollback rehearsal**: run production-like end-to-end tests for migration, multi-device convergence, offline retry, conflicts, rate limits, revocation, asset transfer, large projects, support disablement, rollback, and recovery without deleting the local store. Production writes remain disabled until these drills pass.

The first production code should therefore be server schema and environment separation, not SwiftData mutation. Real production SwiftData apply is intentionally delayed until identity, migration planning, assets, rollout controls, and focused tests exist.

## Phase 4a Implementation

Worker:

- Adds authenticated `POST /api/sync/v1/head`.
- Accepts `projectId`, `deviceId`, optional `deviceName`, and `lastKnownSequence`.
- Returns `latestSequence`, server cursor sequence, last pushed sequence, `hasChanges`, and `changeCount`.
- Does not return operation payloads.
- Adds authenticated `POST /api/sync/v1/peek` for non-acknowledging operation reads.

App debug client:

- Adds `CloudflareSyncPOCService.checkRemoteChanges(projects:)`.
- Adds a `Check Remote Changes` button to Sync Diagnostics.
- Adds `CloudflareSyncPOCService.runRemoteChangeProbe(projects:)`.
- Adds a `Run Remote Change Probe` button that simulates a second device pushing a harmless same-value `Project` upsert, then verifies this device sees `hasChanges` from `/head`.
- Adds `CloudflareSyncPOCService.runExistingTextFileUpdateProbe(projects:)`.
- Adds a `Run Existing Text File Update Probe` button that simulates a second device pushing an upsert for a visible local `TextFile`, then verifies scratch-only `TextFile:updateExisting` materialization.
- Adds `CloudflareSyncPOCService.runRemoteDeleteProbe(projects:)`.
- Adds a `Run Remote Delete Probe` button that simulates a second device pushing a synthetic `TextFile` upsert followed by a `delete`, then verifies this device sees `hasChanges` from `/head`.
- Adds `CloudflareSyncPOCService.runExistingProjectDeleteGuardrailProbe(projects:)`.
- Adds a `Run Existing Project Delete Guardrail Probe` button that simulates a second device pushing a `Project` delete for the selected local project, then verifies the dry-run materializer fails closed for existing-local delete plans.
- Adds `CloudflareSyncPOCService.runExistingFolderDeleteGuardrailProbe(projects:)`.
- Adds a `Run Existing Folder Delete Guardrail Probe` button that simulates a second device pushing a `Folder` delete for an existing local folder, then verifies the dry-run materializer fails closed for existing-local folder delete plans.
- Adds `CloudflareSyncPOCService.runExistingTextFileDeleteGuardrailProbe(projects:)`.
- Adds a `Run Existing Text File Delete Guardrail Probe` button that simulates a second device pushing a `TextFile` delete for an existing local text file, then verifies the dry-run materializer fails closed for existing-local content delete plans.
- Adds `CloudflareSyncPOCService.runExistingVersionDeleteGuardrailProbe(projects:)`.
- Adds a `Run Existing Version Delete Guardrail Probe` button that simulates a second device pushing a `Version` delete for an existing local version, then verifies the dry-run materializer fails closed for existing-local version-history delete plans.
- Adds `CloudflareSyncPOCService.runExistingCommentDeleteGuardrailProbe(projects:)`.
- Adds a `Run Existing Comment Delete Guardrail Probe` button that simulates a second device pushing a `CommentModel` delete for an existing local comment, then verifies the dry-run materializer fails closed for existing-local annotation delete plans.
- Adds `CloudflareSyncPOCService.runExistingFootnoteDeleteGuardrailProbe(projects:)`.
- Adds a `Run Existing Footnote Delete Guardrail Probe` button that simulates a second device pushing a `FootnoteModel` delete for an existing local footnote, then verifies the dry-run materializer fails closed for existing-local annotation delete plans.
- Adds `CloudflareSyncPOCService.runRemoteRestoreProbe(projects:)`.
- Adds a `Run Remote Restore Probe` button that simulates a second device pushing a synthetic `TextFile` upsert, `delete`, and `restore`, then verifies this device sees `hasChanges` from `/head`.
- Adds `CloudflareSyncPOCService.runExistingProjectRestoreGuardrailProbe(projects:)`.
- Adds a `Run Existing Project Restore Guardrail Probe` button that simulates a second device pushing a `Project` restore for the selected local project, then verifies the dry-run materializer fails closed for existing-local restore plans.
- Adds `CloudflareSyncPOCService.runExistingFolderRestoreGuardrailProbe(projects:)`.
- Adds a `Run Existing Folder Restore Guardrail Probe` button that simulates a second device pushing a `Folder` restore for an existing local folder, then verifies the dry-run materializer fails closed for existing-local folder restore plans.
- Adds `CloudflareSyncPOCService.runExistingTextFileRestoreGuardrailProbe(projects:)`.
- Adds a `Run Existing Text File Restore Guardrail Probe` button that simulates a second device pushing a `TextFile` restore for an existing local text file, then verifies the dry-run materializer fails closed for existing-local content restore plans.
- Adds `CloudflareSyncPOCService.runExistingVersionRestoreGuardrailProbe(projects:)`.
- Adds a `Run Existing Version Restore Guardrail Probe` button that simulates a second device pushing a `Version` restore for an existing local version, then verifies the dry-run materializer fails closed for existing-local version-history restore plans.
- Adds `CloudflareSyncPOCService.runExistingCommentRestoreGuardrailProbe(projects:)`.
- Adds a `Run Existing Comment Restore Guardrail Probe` button that simulates a second device pushing a `CommentModel` restore for an existing local comment, then verifies the dry-run materializer fails closed for existing-local annotation restore plans.
- Adds `CloudflareSyncPOCService.runExistingFootnoteRestoreGuardrailProbe(projects:)`.
- Adds a `Run Existing Footnote Restore Guardrail Probe` button that simulates a second device pushing a `FootnoteModel` restore for an existing local footnote, then verifies the dry-run materializer fails closed for existing-local annotation restore plans.
- Adds `CloudflareSyncPOCService.runExistingRelationshipLinkRestoreGuardrailProbe(projects:)`.
- Adds a `Run Existing Relationship Link Restore Guardrail Probe` button that simulates a second device pushing a restore for an existing local join/link row, then verifies the dry-run materializer fails closed for existing-local relationship-link restore plans.
- Adds `CloudflareSyncPOCService.runExistingNoteEntryDeleteGuardrailProbe(projects:)`.
- Adds a `Run Existing Note Entry Delete Guardrail Probe` button that simulates a second device pushing a `NoteEntry` delete for an existing local note, then verifies the dry-run materializer fails closed for existing-local standalone reference-note delete plans.
- Adds `CloudflareSyncPOCService.runExistingNoteEntryRestoreGuardrailProbe(projects:)`.
- Adds a `Run Existing Note Entry Restore Guardrail Probe` button that simulates a second device pushing a `NoteEntry` restore for an existing local note, then verifies the dry-run materializer fails closed for existing-local standalone reference-note restore plans.
- Adds `CloudflareSyncPOCService.runExistingContributorDeleteGuardrailProbe(projects:)`.
- Adds a `Run Existing Contributor Delete Guardrail Probe` button that simulates a second device pushing a `ContributorEntry` delete for an existing local contributor, then verifies the dry-run materializer fails closed for existing-local contributor delete plans.
- Adds `CloudflareSyncPOCService.runExistingContributorRestoreGuardrailProbe(projects:)`.
- Adds a `Run Existing Contributor Restore Guardrail Probe` button that simulates a second device pushing a `ContributorEntry` restore for an existing local contributor, then verifies the dry-run materializer fails closed for existing-local contributor restore plans.
- Adds `CloudflareSyncPOCService.runExistingReferenceEntryDeleteGuardrailProbe(projects:)`.
- Adds a `Run Existing Reference Entry Delete Guardrail Probe` button that simulates a second device pushing a `ReferenceEntry` delete for an existing local reference entry, then verifies the dry-run materializer fails closed for existing-local reference-entry delete plans.
- Adds `CloudflareSyncPOCService.runExistingReferenceEntryRestoreGuardrailProbe(projects:)`.
- Adds a `Run Existing Reference Entry Restore Guardrail Probe` button that simulates a second device pushing a `ReferenceEntry` restore for an existing local reference entry, then verifies the dry-run materializer fails closed for existing-local reference-entry restore plans.
- Adds `CloudflareSyncPOCService.runExistingGlossaryEntryDeleteGuardrailProbe(projects:)`.
- Adds a `Run Existing Glossary Entry Delete Guardrail Probe` button that simulates a second device pushing a `GlossaryEntry` delete for an existing local glossary entry, then verifies the dry-run materializer fails closed for existing-local glossary-entry delete plans.
- Adds `CloudflareSyncPOCService.runExistingGlossaryEntryRestoreGuardrailProbe(projects:)`.
- Adds a `Run Existing Glossary Entry Restore Guardrail Probe` button that simulates a second device pushing a `GlossaryEntry` restore for an existing local glossary entry, then verifies the dry-run materializer fails closed for existing-local glossary-entry restore plans.
- Adds `CloudflareSyncPOCService.runExistingIndexEntryDeleteGuardrailProbe(projects:)`.
- Adds a `Run Existing Index Entry Delete Guardrail Probe` button that simulates a second device pushing an `IndexEntry` delete for an existing local index entry, then verifies the dry-run materializer fails closed for existing-local index-entry delete plans.
- Adds `CloudflareSyncPOCService.runRemoteMissingDependencyProbe(projects:)`.
- Adds a `Run Missing Dependency Probe` button that simulates a second device pushing a synthetic `Version` upsert whose `textFileId` does not exist locally or in the pending operation batch.
- Adds `CloudflareSyncPOCService.runRemoteSatisfiedDependencyProbe(projects:)`.
- Adds a `Run Satisfied Dependency Probe` button that simulates a second device pushing a synthetic parent `TextFile` and child `Version` in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteFolderDependencyProbe(projects:)`.
- Adds a `Run Folder Dependency Probe` button that simulates a second device pushing a synthetic `Folder`, child `TextFile`, and child `Version` in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteAnnotationDependencyProbe(projects:)`.
- Adds a `Run Annotation Dependency Probe` button that simulates a second device pushing a synthetic `Folder`, `TextFile`, `Version`, `CommentModel`, and `FootnoteModel` in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteStyleDependencyProbe(projects:)`.
- Adds a `Run Style Dependency Probe` button that simulates a second device pushing a synthetic `StyleSheet`, `TextStyleModel`, and `ImageStyle` in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteSubmissionDependencyProbe(projects:)`.
- Adds a `Run Submission Dependency Probe` button that simulates a second device pushing a synthetic `Publication`, `Folder`, `TextFile`, `Version`, `Submission`, and `SubmittedFile` in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemotePoetryCollectionDependencyProbe(projects:)`.
- Adds a `Run Poetry Collection Dependency Probe` button that simulates a second device pushing a synthetic `PoetryCollection`, `TextFile`, and `TextFileCollectionLink` in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteProseSectionDependencyProbe(projects:)`.
- Adds a `Run Prose Section Dependency Probe` button that simulates a second device pushing a synthetic `ProseSection`, `TextFile`, and `TextFileSectionLink` in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteNoteEntryDependencyProbe(projects:)`.
- Adds a `Run Note Entry Dependency Probe` button that simulates a second device pushing a synthetic `NoteEntry` in the pending batch.
- Adds `CloudflareSyncPOCService.runRemoteGlossaryCitationDependencyProbe(projects:)`.
- Adds a `Run Glossary Citation Dependency Probe` button that simulates a second device pushing a synthetic `CitationEntry` and `GlossaryEntry` in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteReferenceEntryDependencyProbe(projects:)`.
- Adds a `Run Reference Entry Dependency Probe` button that simulates a second device pushing a synthetic `ReferenceEntry` in the pending batch.
- Adds `CloudflareSyncPOCService.runRemoteIndexEntryDependencyProbe(projects:)`.
- Adds a `Run Index Entry Dependency Probe` button that simulates a second device pushing synthetic parent and child `IndexEntry` records in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteContributorEntryDependencyProbe(projects:)`.
- Adds a `Run Contributor Entry Dependency Probe` button that simulates a second device pushing a synthetic `ContributorEntry` in the pending batch.
- Adds `CloudflareSyncPOCService.runRemotePageSetupDependencyProbe(projects:)`.
- Adds a `Run Page Setup Dependency Probe` button that simulates a second device pushing synthetic `PageSetup` and `PrinterPaper` records in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteCustomAttributeDependencyProbe(projects:)`.
- Adds a `Run Custom Attribute Dependency Probe` button that simulates a second device pushing synthetic `Character` and `CustomAttribute` records in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteTrashItemDependencyProbe(projects:)`.
- Adds a `Run Trash Item Dependency Probe` button that simulates a second device pushing synthetic `Folder`, `TextFile`, and `TrashItem` records in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteManuscriptReviewDependencyProbe(projects:)`.
- Adds a `Run Manuscript Review Dependency Probe` button that simulates a second device pushing synthetic `ManuscriptReview` and `ReviewSuggestion` records in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemotePoetryFormDependencyProbe(projects:)`.
- Adds a `Run Poetry Form Dependency Probe` button that simulates a second device pushing a synthetic `PoetryFormModel` record in the pending batch.
- Adds `CloudflareSyncPOCService.runRemoteStoryLinkDependencyProbe(projects:)`.
- Adds a `Run Story Link Dependency Probe` button that simulates a second device pushing a synthetic `Character`, `PlotElement`, and `CharacterPlotElementLink` in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteLocationLinkDependencyProbe(projects:)`.
- Adds a `Run Location Link Dependency Probe` button that simulates a second device pushing a synthetic `Location`, `PlotElement`, and `LocationPlotElementLink` in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteSceneCharacterDependencyProbe(projects:)`.
- Adds a `Run Scene Character Dependency Probe` button that simulates a second device pushing a synthetic `StoryScene`, `Character`, and `SceneCharacterLink` in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteSceneLocationDependencyProbe(projects:)`.
- Adds a `Run Scene Location Dependency Probe` button that simulates a second device pushing a synthetic `StoryScene`, `Location`, and `SceneLocationLink` in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteSceneChapterDependencyProbe(projects:)`.
- Adds a `Run Scene Chapter Dependency Probe` button that simulates a second device pushing a synthetic `Chapter`, `StoryScene`, and `SceneChapterLink` in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteSceneActDependencyProbe(projects:)`.
- Adds a `Run Scene Act Dependency Probe` button that simulates a second device pushing a synthetic `Act`, `StoryScene`, and `SceneActLink` in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteSceneBookDependencyProbe(projects:)`.
- Adds a `Run Scene Book Dependency Probe` button that simulates a second device pushing a synthetic `Book`, `StoryScene`, and `SceneBookLink` in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteScenePlotDependencyProbe(projects:)`.
- Adds a `Run Scene Plot Dependency Probe` button that simulates a second device pushing a synthetic `StoryScene`, `PlotElement`, and `ScenePlotElementLink` in the same pending batch.
- Adds `CloudflareSyncPOCService.runRemoteUnsupportedOperationProbe(projects:)`.
- Adds a `Run Unsupported Operation Probe` button that simulates a second device pushing a supported entity type with an unsupported operation type.
- Adds `CloudflareSyncPOCService.runRemoteNoPayloadProbe(projects:)`.
- Adds a `Run No-Payload Probe` button that simulates a second device pushing a supported upsert with an empty payload.
- Adds `CloudflareSyncPOCService.pullPendingChanges(projects:)`.
- Adds a `Pull Pending Changes` button that pulls only operations after the remembered sequence, advances the POC cursor, and does not write local SwiftData records.
- Adds `CloudflareSyncPOCService.previewPendingApply(projects:)`.
- Adds a `Preview Pending Apply` button that peeks pending operations, classifies supported upserts/deletes/restores versus ignored operations, builds a dry-run apply plan from final actions per entity, reports dry-run apply readiness and apply order, and does not advance the cursor.
- Adds a `Materialize Pending Apply Preview` button that peeks pending operations, refuses blocked plans, and materializes only ready `TextFile` + `Version` create-missing actions into a separate CloudKit-disabled scratch store.
- Adds an `Inspect Pending Apply Scratch Store` button that reopens the CloudKit-disabled scratch store and reports saved project/folder/text-file/version counts and relationship linkage.
- Uses a POC-local per-project `cloudflareSyncPOCLastSequence.<projectId>` UserDefaults key as the stand-in for the future durable sync cursor.
- Updates that remembered cursor after full pull-style diagnostics complete.

The remote change probe does not write local SwiftData records. It only adds a same-value `Project` upsert operation to the Worker operation log for the selected project, so apply preview can exercise a supported entity path.

The existing text file update probe also does not write local SwiftData records. It adds an upsert for a visible local `TextFile`, so the scratch materializer can seed a copy of that local file into the CloudKit-disabled scratch store and apply a remote update to the copy only.

The remote delete probe also does not write local SwiftData records. It adds a synthetic `TextFile` operation pair to the Worker operation log so apply preview can exercise supported delete/tombstone classification without touching a real file.

The existing project delete guardrail probe pushes a remote `Project` delete for the selected local project only to the Worker operation log. Because that project exists locally, preview should propose `markDeleted`; scratch materialization must fail closed until existing-local delete semantics are explicitly implemented.

The remote restore probe adds a synthetic `TextFile` upsert/delete/restore sequence so apply preview can exercise restore classification without touching a real file.

The existing project restore guardrail probe pushes a remote `Project` restore for the selected local project only to the Worker operation log. Because that project exists locally, preview should propose `restoreExisting`; scratch materialization must fail closed until existing-local restore semantics are explicitly implemented.

The missing dependency probe adds a synthetic `Version` upsert that points at a nonexistent `TextFile`, so apply preview can exercise blocked dependency classification without touching a real file.

The satisfied dependency probe adds a synthetic `TextFile` upsert and a synthetic `Version` upsert that points at that text file, so apply preview can exercise dependency satisfaction from records included in the same pending batch.

The folder dependency probe adds a synthetic `Folder` upsert, a synthetic `TextFile` upsert whose `folderId` points at that folder, and a synthetic `Version` upsert whose `textFileId` points at that text file. This exercises the first realistic folder/file/version parent chain.

The annotation dependency probe extends that chain with a synthetic `CommentModel` and `FootnoteModel` whose `versionId` points at the pending version. This exercises version annotation dependencies and scratch materialization.

The style dependency probe adds a synthetic `StyleSheet` upsert plus `TextStyleModel` and `ImageStyle` upserts whose `styleSheetId` points at that stylesheet. This exercises the stylesheet parent chain used by formatted text and images.

The submission dependency probe adds a synthetic `Publication`, a folder/file/version source chain, a `Submission` that points at the publication, and a `SubmittedFile` that points at the submission, text file, and version. This exercises the publication/submission workflow parent chain.

The poetry collection dependency probe adds a synthetic `PoetryCollection`, `TextFile`, and `TextFileCollectionLink` in one pending batch. This exercises poetry body-matter assignment without touching production data.

The prose section dependency probe adds a synthetic `ProseSection`, `TextFile`, and `TextFileSectionLink` in one pending batch. This exercises prose body-matter assignment without touching production data.

The note entry dependency probe adds a synthetic `NoteEntry` in one pending batch. This exercises standalone reference-note materialization without touching production data.

The glossary citation dependency probe adds a synthetic `CitationEntry` and `GlossaryEntry` in one pending batch, with the glossary entry pointing at the citation. This exercises a reference-record dependency without touching production data.

The reference entry dependency probe adds a synthetic `ReferenceEntry` in one pending batch. This exercises standalone bibliography/reference materialization without touching production data.

The index entry dependency probe adds synthetic parent and child `IndexEntry` records in one pending batch. This exercises index hierarchy dependency readiness and scratch materialization without touching production data.

The contributor entry dependency probe adds a synthetic `ContributorEntry` in one pending batch. This exercises standalone contributor materialization without touching production data.

The page setup dependency probe adds synthetic `PageSetup` and `PrinterPaper` records in one pending batch. This exercises project page layout dependency readiness and scratch materialization without touching production data.

The custom attribute dependency probe adds synthetic `Character` and `CustomAttribute` records in one pending batch. This exercises character/location attribute dependency readiness and scratch materialization without touching production data.

The trash item dependency probe adds synthetic `Folder`, `TextFile`, and `TrashItem` records in one pending batch. This exercises trash metadata dependency readiness and scratch materialization without touching production data or production trash state.

The manuscript review dependency probe adds synthetic `ManuscriptReview` and `ReviewSuggestion` records in one pending batch. This exercises Manuscript Analyst review dependency readiness and scratch materialization without touching production data.

`ManuscriptReview` and `ReviewSuggestion` are not in the production `WritingShedModelSchema` yet. The pending-apply scratch store uses a Cloudflare POC-only expanded schema for these records so dry-run materialization can be inspected without changing the production SwiftData/CloudKit model schema.

If there are no pending operations, `Materialize Pending Apply Preview` clears the pending-apply scratch store before returning. This prevents a later scratch inspection from showing stale records from an older probe sequence.

The poetry form dependency probe adds a synthetic `PoetryFormModel` record in one pending batch. This exercises the remaining standalone production SwiftData model in dry-run planning and scratch materialization without touching production data.

The story link dependency probe adds a synthetic `Character`, a synthetic `PlotElement`, and a `CharacterPlotElementLink` that points at both. This exercises the first story metadata many-to-many join table without requiring the larger scene/chapter/book graph.

The location link dependency probe adds a synthetic `Location`, a synthetic `PlotElement`, and a `LocationPlotElementLink` that points at both. This exercises the sibling story metadata many-to-many join table for plot-element locations.

The scene character dependency probe adds a synthetic `StoryScene`, a synthetic `Character`, and a `SceneCharacterLink` that points at both. This starts exercising real scene records plus a scene many-to-many join table without requiring chapter, act, or book placement.

The scene location dependency probe adds a synthetic `StoryScene`, a synthetic `Location`, and a `SceneLocationLink` that points at both. This exercises the sibling scene many-to-many join table for scene locations.

The scene chapter dependency probe adds a synthetic `Chapter`, a synthetic `StoryScene`, and a `SceneChapterLink` that points at both. This starts exercising structural scene placement for novel-style projects.

The scene act dependency probe adds a synthetic `Act`, a synthetic `StoryScene`, and a `SceneActLink` that points at both. This exercises structural scene placement for drama/three-act-style projects.

The scene book dependency probe adds a synthetic `Book`, a synthetic `StoryScene`, and a `SceneBookLink` that points at both. This exercises structural scene placement for verse-novel/book-style projects.

The scene plot dependency probe adds a synthetic `StoryScene`, a synthetic `PlotElement`, and a `ScenePlotElementLink` that points at both. This completes the scene-to-planning metadata join path.

Join/link entity update semantics: join rows primarily represent relationship existence. For Phase 5, the relationship-only join entities are treated as create/delete-only product semantics: `SceneChapterLink`, `SceneActLink`, `SceneBookLink`, `ScenePlotElementLink`, `SceneCharacterLink`, `SceneLocationLink`, `CharacterPlotElementLink`, and `LocationPlotElementLink`. A repeated remote upsert for the same link should be idempotent, but `updateExisting` is not user-meaningful because there are no editable scalar fields on those models. `TextFileSectionLink` and `TextFileCollectionLink` additionally carry `userOrder`, so ordered assignment changes have explicit ordered-link update coverage. Other link table coverage remains createMissing dependency materialization plus delete/remove-link guardrail behavior, not general `updateExisting` probes.

The unsupported operation probe adds a synthetic `TextFile` operation with operation type `merge`, so apply preview can exercise blocked readiness for ignored final actions.

The no-payload probe adds a synthetic `TextFile` upsert with an empty payload, so apply preview can exercise blocked readiness for create/update operations that do not include enough data to write locally.

Expected diagnostic sequence:

1. Run `Run Remote Change Probe`; `/head` should report one pending change.
2. Run `Preview Pending Apply`; it should classify the pending operation as one supported upsert without advancing the cursor.
3. Run `Materialize Pending Apply Preview`; because the probe targets the selected local `Project`, the plan should propose `updateExisting` and the scratch materializer should apply that update only to the CloudKit-disabled scratch project copy. Production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one scratch project and one updated existing record in the materialization result.
5. Run `Pull Pending Changes`; it should pull that operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05 before Phase 5 scratch-update support: the remote change sequence produced `Project:upsert->updateExisting@1437(local-exists,payload,deps-ok)` with readiness `ready for dry-run applier`, then scratch materialization failed closed with the supported-action message. Production local data was not changed.

Delete diagnostic sequence:

1. Run `Run Remote Delete Probe`; `/head` should report two pending changes.
2. Run `Preview Pending Apply`; it should classify one supported upsert and one delete/trash/tombstone operation without advancing the cursor.
3. Run `Materialize Pending Apply Preview`; it should coalesce the final action to a missing-local delete and report one delete no-op in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report no synthetic text file or version records for the deleted remote file.
5. Run `Pull Pending Changes`; it should pull both operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the remote delete sequence produced a final coalesced delete with `Dependencies: 0 ok, 0 blocked, 1 not required`, apply order `TextFile:deleteNoopMissing@1433`, and plan sample `TextFile:delete->deleteNoopMissing@1433(local-missing,payload,deps-not-required)`. Scratch materialization reported `1 delete no-ops`, and scratch inspection reported no text files or versions for the deleted remote file.

Existing project delete guardrail diagnostic sequence:

1. Run `Run Existing Project Delete Guardrail Probe`; `/head` should report one pending change.
2. Run `Preview Pending Apply`; it should classify one delete/trash/tombstone operation. The plan should show `Project:delete->markDeleted` because the selected project exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the existing project delete guardrail sequence produced `Project:delete->markDeleted@1438(local-exists,payload,deps-not-required)` with readiness `ready for dry-run applier`, then scratch materialization failed closed with the supported-action message. Production local data was not changed.

Existing folder delete guardrail diagnostic sequence:

1. Run `Run Existing Folder Delete Guardrail Probe`; it selects the first sampled local `Folder` from the selected projects and pushes a simulated remote `delete` for the same folder id.
2. Run `Preview Pending Apply`; it should classify one delete/trash/tombstone operation. The plan should show `Folder:delete->markDeleted` because the folder exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local folder delete materialization semantics, including child containment handling, are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-06: the existing folder delete guardrail sequence selected Folder `Submissions` in project `Poems 2026`, pushed simulated delete sequence 29 after baseline 28, and previewed `Folder:delete->markDeleted@29(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one delete/trash/tombstone operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local folder delete materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing text file delete guardrail diagnostic sequence:

1. Run `Run Existing Text File Delete Guardrail Probe`; it selects the first sampled local `TextFile` from the selected projects and pushes a simulated remote `delete` for the same text file id.
2. Run `Preview Pending Apply`; it should classify one delete/trash/tombstone operation. The plan should show `TextFile:delete->markDeleted` because the text file exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local content delete materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-06: the existing text file delete guardrail sequence selected TextFile `Endnotes` in project `Poems 2026`, pushed simulated delete sequence 25 after baseline 24, and previewed `TextFile:delete->markDeleted@25(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one delete/trash/tombstone operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local content delete materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing version delete guardrail diagnostic sequence:

1. Run `Run Existing Version Delete Guardrail Probe`; it selects the first sampled local `Version` under a sampled local `TextFile` from the selected projects and pushes a simulated remote `delete` for the same version id.
2. Run `Preview Pending Apply`; it should classify one delete/trash/tombstone operation. The plan should show `Version:delete->markDeleted` because the version exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local version-history delete materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-06: the existing version delete guardrail sequence selected Version 1 of TextFile `Endnotes` in project `Poems 2026`, pushed simulated delete sequence 27 after baseline 26, and previewed `Version:delete->markDeleted@27(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one delete/trash/tombstone operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local version-history delete materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing comment delete guardrail diagnostic sequence:

1. Run `Run Existing Comment Delete Guardrail Probe`; it selects the first sampled local `CommentModel` under a sampled local `Version` from the selected projects and pushes a simulated remote `delete` for the same comment id.
2. Run `Preview Pending Apply`; it should classify one delete/trash/tombstone operation. The plan should show `CommentModel:delete->markDeleted` because the comment exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local annotation delete materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-06: the existing comment delete guardrail sequence selected CommentModel `20C23A1A-CEB1-415E-991B-51F80A29A0E8` in project `Poems 2026`, pushed simulated delete sequence 31 after baseline 30, and previewed `CommentModel:delete->markDeleted@31(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one delete/trash/tombstone operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local annotation delete materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing footnote delete guardrail diagnostic sequence:

1. Run `Run Existing Footnote Delete Guardrail Probe`; it selects the first sampled local `FootnoteModel` under a sampled local `Version` from the selected projects and pushes a simulated remote `delete` for the same footnote id.
2. Run `Preview Pending Apply`; it should classify one delete/trash/tombstone operation. The plan should show `FootnoteModel:delete->markDeleted` because the footnote exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local annotation delete materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-06: after the selector fix, the existing footnote delete guardrail sequence selected FootnoteModel `3EAA5826-C2E1-4CE9-8C18-0A231DAD8013` in project `Poems 2026`, pushed simulated delete sequence 33 after baseline 32, and previewed `FootnoteModel:delete->markDeleted@33(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one delete/trash/tombstone operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local annotation delete materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Observed 2026-07-06: the first footnote delete guardrail run on a project known to contain footnotes failed before push with `No project content is available for the Cloudflare sync POC.` Root cause was selector fragility: `sampleFootnotes(in:)` only read `Version.footnotes`, but footnote relationships can be stale/incomplete in the in-memory relationship cache. The sampler now unions relationship values with a direct SwiftData `FootnoteModel` fetch by `footnote.version?.persistentModelID`, matching the robust lookup pattern in `FootnoteManager.getActiveFootnotes(forVersion:context:)`.

Existing relationship link delete guardrail diagnostic sequence:

1. Run `Run Existing Relationship Link Delete Guardrail Probe`; it selects the first sampled local join/link row and pushes a simulated remote `delete` for the same link id.
2. Run `Preview Pending Apply`; it should classify one delete/trash/tombstone operation. The plan sample should show `<LinkEntity>:delete->markDeleted` because the selected relationship link exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until scratch remove-link materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-06: the existing relationship link delete guardrail sequence selected a local `CharacterPlotElementLink` in project `The Republic of Heaven`, pushed simulated delete sequence 1450 after baseline 1449, and previewed `CharacterPlotElementLink:delete->markDeleted@1450(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one delete/trash/tombstone operation and dependencies not required. Materialization failed closed with the supported-action message because scratch remove-link materialization is not implemented yet; no scratch store remained to inspect, the cursor was not advanced, and production local data was not read or changed.

Existing relationship link restore guardrail diagnostic sequence:

1. Run `Run Existing Relationship Link Restore Guardrail Probe`; it selects the first sampled local join/link row and pushes a simulated remote `restore` for the same link id.
2. Run `Preview Pending Apply`; it should classify one restore operation. The plan sample should show `<LinkEntity>:restore->restoreExisting` because the selected relationship link exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until scratch restore-link materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-06: the existing relationship link restore guardrail sequence selected a local `CharacterPlotElementLink` in project `The Republic of Heaven`, pushed simulated restore sequence 1451 after baseline 1450, and previewed `CharacterPlotElementLink:restore->restoreExisting@1451(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one restore operation and dependencies not required. Materialization failed closed with the supported-action message because scratch restore-link materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing note entry delete guardrail diagnostic sequence:

1. Run `Run Existing Note Entry Delete Guardrail Probe`; it selects a sampled local `NoteEntry` from the selected projects and pushes a simulated remote `delete` for the same note id.
2. Run `Preview Pending Apply`; it should classify one delete/trash/tombstone operation. The plan should show `NoteEntry:delete->markDeleted` because the note exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local standalone note delete materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-07: the existing note entry delete guardrail sequence selected NoteEntry tag `KL` in project `The Republic of Heaven`, pushed simulated delete sequence 1452 after baseline 1451, and previewed `NoteEntry:delete->markDeleted@1452(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one delete/trash/tombstone operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local standalone note delete materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing note entry restore guardrail diagnostic sequence:

1. Run `Run Existing Note Entry Restore Guardrail Probe`; it selects a sampled local `NoteEntry` from the selected projects and pushes a simulated remote `restore` for the same note id.
2. Run `Preview Pending Apply`; it should classify one restore operation. The plan should show `NoteEntry:restore->restoreExisting` because the note exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local standalone note restore materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-07: the existing note entry restore guardrail sequence selected NoteEntry tag `KL` in project `The Republic of Heaven`, pushed simulated restore sequence 1453 after baseline 1452, and previewed `NoteEntry:restore->restoreExisting@1453(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one restore operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local standalone note restore materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing contributor delete guardrail diagnostic sequence:

1. Run `Run Existing Contributor Delete Guardrail Probe`; it selects the first sampled local `ContributorEntry` from the selected projects and pushes a simulated remote `delete` for the same contributor id.
2. Run `Preview Pending Apply`; it should classify one delete/trash/tombstone operation. The plan should show `ContributorEntry:delete->markDeleted` because the contributor exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local contributor delete materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-07: the existing contributor delete guardrail sequence selected ContributorEntry `Lander, Keith` in project `Poems 2026`, pushed simulated delete sequence 35 after baseline 34, and previewed `ContributorEntry:delete->markDeleted@35(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one delete/trash/tombstone operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local contributor delete materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing contributor restore guardrail diagnostic sequence:

1. Run `Run Existing Contributor Restore Guardrail Probe`; it selects the first sampled local `ContributorEntry` from the selected projects and pushes a simulated remote `restore` for the same contributor id.
2. Run `Preview Pending Apply`; it should classify one restore operation. The plan should show `ContributorEntry:restore->restoreExisting` because the contributor exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local contributor restore materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-07: the existing contributor restore guardrail sequence selected ContributorEntry `Lander, Keith` in project `Poems 2026`, pushed simulated restore sequence 36 after baseline 35, and previewed `ContributorEntry:restore->restoreExisting@36(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one restore operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local contributor restore materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing reference entry delete guardrail diagnostic sequence:

1. Run `Run Existing Reference Entry Delete Guardrail Probe`; it selects the first sampled local `ReferenceEntry` from the selected projects and pushes a simulated remote `delete` for the same reference entry id.
2. Run `Preview Pending Apply`; it should classify one delete/trash/tombstone operation. The plan should show `ReferenceEntry:delete->markDeleted` because the reference entry exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local reference-entry delete materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-07: the existing reference entry delete guardrail sequence selected ReferenceEntry `KGL, Last Year` in project `Poems 2026`, pushed simulated delete sequence 37 after baseline 36, and previewed `ReferenceEntry:delete->markDeleted@37(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one delete/trash/tombstone operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local reference-entry delete materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing reference entry restore guardrail diagnostic sequence:

1. Run `Run Existing Reference Entry Restore Guardrail Probe`; it selects the first sampled local `ReferenceEntry` from the selected projects and pushes a simulated remote `restore` for the same reference entry id.
2. Run `Preview Pending Apply`; it should classify one restore operation. The plan should show `ReferenceEntry:restore->restoreExisting` because the reference entry exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local reference-entry restore materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-07: the existing reference entry restore guardrail sequence selected ReferenceEntry `KGL, Last Year` in project `Poems 2026`, pushed simulated restore sequence 38 after baseline 37, and previewed `ReferenceEntry:restore->restoreExisting@38(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one restore operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local reference-entry restore materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing glossary entry delete guardrail diagnostic sequence:

1. Run `Run Existing Glossary Entry Delete Guardrail Probe`; it selects the first sampled local `GlossaryEntry` from the selected projects and pushes a simulated remote `delete` for the same glossary entry id.
2. Run `Preview Pending Apply`; it should classify one delete/trash/tombstone operation. The plan should show `GlossaryEntry:delete->markDeleted` because the glossary entry exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local glossary-entry delete materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-07: the existing glossary entry delete guardrail sequence selected GlossaryEntry `Pain` in project `Poems 2026`, pushed simulated delete sequence 39 after baseline 38, and previewed `GlossaryEntry:delete->markDeleted@39(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one delete/trash/tombstone operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local glossary-entry delete materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing glossary entry restore guardrail diagnostic sequence:

1. Run `Run Existing Glossary Entry Restore Guardrail Probe`; it selects the first sampled local `GlossaryEntry` from the selected projects and pushes a simulated remote `restore` for the same glossary entry id.
2. Run `Preview Pending Apply`; it should classify one restore operation. The plan should show `GlossaryEntry:restore->restoreExisting` because the glossary entry exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local glossary-entry restore materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-07: the existing glossary entry restore guardrail sequence selected GlossaryEntry `Pain` in project `Poems 2026`. The probe status reported simulated restore sequence 40 after baseline 39, and the verified preview captured `GlossaryEntry:restore->restoreExisting@44(local-exists,payload,deps-not-required)` after sequence 43. Apply readiness was ready for dry-run planning, with one restore operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local glossary-entry restore materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing index entry delete guardrail diagnostic sequence:

1. Run `Run Existing Index Entry Delete Guardrail Probe`; it selects the first sampled local root `IndexEntry` from the selected projects and pushes a simulated remote `delete` for the same index entry id.
2. Run `Preview Pending Apply`; it should classify one delete/trash/tombstone operation. The plan should show `IndexEntry:delete->markDeleted` because the index entry exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local index-entry delete materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-07: the existing index entry delete guardrail sequence selected IndexEntry `gun` in project `Poems 2026`, pushed simulated delete sequence 45 after baseline 44, and previewed `IndexEntry:delete->markDeleted@45(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one delete/trash/tombstone operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local index-entry delete materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing index entry restore guardrail diagnostic sequence:

1. Run `Run Existing Index Entry Restore Guardrail Probe`; it selects the first sampled local root `IndexEntry` from the selected projects and pushes a simulated remote `restore` for the same index entry id.
2. Run `Preview Pending Apply`; it should classify one restore operation. The plan should show `IndexEntry:restore->restoreExisting` because the index entry exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local index-entry restore materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-07: the existing index entry restore guardrail sequence selected IndexEntry `gun` in project `Poems 2026`, pushed simulated restore sequence 46 after baseline 45, and previewed `IndexEntry:restore->restoreExisting@46(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one restore operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local index-entry restore materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing publication delete guardrail diagnostic sequence:

1. Run `Run Existing Publication Delete Guardrail Probe`; it selects the first sampled local `Publication` from the selected projects and pushes a simulated remote `delete` for the same publication id.
2. Run `Preview Pending Apply`; it should classify one delete/trash/tombstone operation. The plan should show `Publication:delete->markDeleted` because the publication exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local publication delete materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-07: the existing publication delete guardrail sequence selected Publication `Winchester poetry prize` in project `Poems 2026`, pushed simulated delete sequence 47 after baseline 46, and previewed `Publication:delete->markDeleted@47(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one delete/trash/tombstone operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local publication delete materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing publication restore guardrail diagnostic sequence:

1. Run `Run Existing Publication Restore Guardrail Probe`; it selects the first sampled local `Publication` from the selected projects and pushes a simulated remote `restore` for the same publication id.
2. Run `Preview Pending Apply`; it should classify one restore operation. The plan should show `Publication:restore->restoreExisting` because the publication exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local publication restore materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-07: the existing publication restore guardrail sequence selected Publication `Winchester poetry prize` in project `Poems 2026`, pushed simulated restore sequence 48 after baseline 47, and previewed `Publication:restore->restoreExisting@48(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one restore operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local publication restore materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing submission delete guardrail diagnostic sequence:

1. Run `Run Existing Submission Delete Guardrail Probe`; it selects the first sampled local `Submission` that is linked to a `Publication` and pushes a simulated remote `delete` for the same submission id.
2. Run `Preview Pending Apply`; it should classify one delete/trash/tombstone operation. The plan should show `Submission:delete->markDeleted` because the submission exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local submission delete materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-07: the existing submission delete guardrail sequence selected Submission `The Review` in project `Poems 2026`, pushed simulated delete sequence 49 after baseline 48, and previewed `Submission:delete->markDeleted@49(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one delete operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local submission delete materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing submission restore guardrail diagnostic sequence:

1. Run `Run Existing Submission Restore Guardrail Probe`; it selects the first sampled local `Submission` that is linked to a `Publication` and pushes a simulated remote `restore` for the same submission id.
2. Run `Preview Pending Apply`; it should classify one restore operation. The plan should show `Submission:restore->restoreExisting` because the submission exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local submission restore materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-07: the existing submission restore guardrail sequence selected Submission `The Review` in project `Poems 2026`, pushed simulated restore sequence 50 after baseline 49, and previewed `Submission:restore->restoreExisting@50(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one restore operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local submission restore materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing submitted file delete guardrail diagnostic sequence:

1. Run `Run Existing Submitted File Delete Guardrail Probe`; it selects the first sampled local `SubmittedFile` whose submission has a publication and whose text file and version dependencies are present, then pushes a simulated remote `delete` for the same submitted file id.
2. Run `Preview Pending Apply`; it should classify one delete/trash/tombstone operation. The plan should show `SubmittedFile:delete->markDeleted` because the submitted file exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local submitted file delete materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-07: the existing submitted file delete guardrail sequence selected SubmittedFile `Conspiracy Theories` in project `Poems 2026`, pushed simulated delete sequence 51 after baseline 50, and previewed `SubmittedFile:delete->markDeleted@51(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one delete operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local submitted file delete materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing submitted file restore guardrail diagnostic sequence:

1. Run `Run Existing Submitted File Restore Guardrail Probe`; it selects the first sampled local `SubmittedFile` whose submission has a publication and whose text file and version dependencies are present, then pushes a simulated remote `restore` for the same submitted file id.
2. Run `Preview Pending Apply`; it should classify one restore operation. The plan should show `SubmittedFile:restore->restoreExisting` because the submitted file exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local submitted file restore materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-07: the existing submitted file restore guardrail sequence selected SubmittedFile `Conspiracy Theories` in project `Poems 2026`, pushed simulated restore sequence 52 after baseline 51, and previewed `SubmittedFile:restore->restoreExisting@52(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one restore operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local submitted file restore materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Phase 5 existing-local guardrail checkpoint:

Verified 2026-07-07: existing-local destructive/restorative planning has now been exercised for content, annotation, relationship-link, reference/back-matter, and workflow entities. Remote `delete`/`trash`/`tombstone` operations against existing local records consistently preview as `markDeleted`; remote `restore` operations against existing local records consistently preview as `restoreExisting`; scratch materialization refuses both classes until real production semantics are explicitly designed. This preserves the POC invariant that preview/materialization never mutates production SwiftData data and never advances the cursor.

Restore diagnostic sequence:

1. Run `Run Remote Restore Probe`; `/head` should report three pending changes.
2. Run `Preview Pending Apply`; it should classify one supported upsert, one delete/trash/tombstone operation, and one restore operation without advancing the cursor. The dry-run apply plan should show one final restore action for the synthetic file.
3. Run `Materialize Pending Apply Preview`; it should coalesce the final action to a missing-local restore, create one text file in `cloudflare-sync-poc-pending-apply.sqlite`, and report one restored missing record. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one synthetic text file for the restored remote file.
5. Run `Pull Pending Changes`; it should pull all three operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the remote restore sequence produced a final coalesced restore with `Dependencies: 0 ok, 0 blocked, 1 not required`, apply order `TextFile:restoreMissing@1436`, and plan sample `TextFile:restore->restoreMissing@1436(local-missing,payload,deps-not-required)`. Scratch materialization created one text file, reported `1 restored missing records`, and scratch inspection reported one text file in the CloudKit-disabled scratch store.

Existing project restore guardrail diagnostic sequence:

1. Run `Run Existing Project Restore Guardrail Probe`; `/head` should report one pending change.
2. Run `Preview Pending Apply`; it should classify one restore operation. The plan should show `Project:restore->restoreExisting` because the selected project exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the existing project restore guardrail sequence produced `Project:restore->restoreExisting@1439(local-exists,payload,deps-not-required)` with readiness `ready for dry-run applier`, then scratch materialization failed closed with the supported-action message. Production local data was not changed.

Existing folder restore guardrail diagnostic sequence:

1. Run `Run Existing Folder Restore Guardrail Probe`; it selects the first sampled local `Folder` from the selected projects and pushes a simulated remote `restore` for the same folder id.
2. Run `Preview Pending Apply`; it should classify one restore operation. The plan should show `Folder:restore->restoreExisting` because the folder exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local folder restore materialization semantics, including child containment handling, are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-06: the existing folder restore guardrail sequence selected Folder `Submissions` in project `Poems 2026`, pushed simulated restore sequence 30 after baseline 29, and previewed `Folder:restore->restoreExisting@30(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one restore operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local folder restore materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing text file restore guardrail diagnostic sequence:

1. Run `Run Existing Text File Restore Guardrail Probe`; it selects the first sampled local `TextFile` from the selected projects and pushes a simulated remote `restore` for the same text file id.
2. Run `Preview Pending Apply`; it should classify one restore operation. The plan should show `TextFile:restore->restoreExisting` because the text file exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local content restore materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-06: the existing text file restore guardrail sequence selected TextFile `Endnotes` in project `Poems 2026`, pushed simulated restore sequence 26 after baseline 25, and previewed `TextFile:restore->restoreExisting@26(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one restore operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local content restore materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing version restore guardrail diagnostic sequence:

1. Run `Run Existing Version Restore Guardrail Probe`; it selects the first sampled local `Version` under a sampled local `TextFile` from the selected projects and pushes a simulated remote `restore` for the same version id.
2. Run `Preview Pending Apply`; it should classify one restore operation. The plan should show `Version:restore->restoreExisting` because the version exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local version-history restore materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-06: the existing version restore guardrail sequence selected Version 1 of TextFile `Endnotes` in project `Poems 2026`, pushed simulated restore sequence 28 after baseline 27, and previewed `Version:restore->restoreExisting@28(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one restore operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local version-history restore materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing comment restore guardrail diagnostic sequence:

1. Run `Run Existing Comment Restore Guardrail Probe`; it selects the first sampled local `CommentModel` under a sampled local `Version` from the selected projects and pushes a simulated remote `restore` for the same comment id.
2. Run `Preview Pending Apply`; it should classify one restore operation. The plan should show `CommentModel:restore->restoreExisting` because the comment exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local annotation restore materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-06: the existing comment restore guardrail sequence selected CommentModel `20C23A1A-CEB1-415E-991B-51F80A29A0E8` in project `Poems 2026`, pushed simulated restore sequence 32 after baseline 31, and previewed `CommentModel:restore->restoreExisting@32(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one restore operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local annotation restore materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Existing footnote restore guardrail diagnostic sequence:

1. Run `Run Existing Footnote Restore Guardrail Probe`; it selects the first sampled local `FootnoteModel` under a sampled local `Version` from the selected projects and pushes a simulated remote `restore` for the same footnote id.
2. Run `Preview Pending Apply`; it should classify one restore operation. The plan should show `FootnoteModel:restore->restoreExisting` because the footnote exists locally.
3. Run `Materialize Pending Apply Preview`; it should fail closed with the supported-action message and must not change production local data. This is intentional until existing-local annotation restore materialization semantics are explicitly implemented.
4. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
5. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-06: the existing footnote restore guardrail sequence selected FootnoteModel `3EAA5826-C2E1-4CE9-8C18-0A231DAD8013` in project `Poems 2026`, pushed simulated restore sequence 34 after baseline 33, and previewed `FootnoteModel:restore->restoreExisting@34(local-exists,payload,deps-not-required)`. Apply readiness was ready for dry-run planning, with one restore operation and dependencies not required. Materialization failed closed with the supported-action message because existing-local annotation restore materialization is not implemented yet; the cursor was not advanced, and production local data was not read or changed.

Missing dependency diagnostic sequence:

1. Run `Run Missing Dependency Probe`; `/head` should report one pending change.
2. Run `Preview Pending Apply`; it should classify one supported upsert with one blocked dependency. The readiness line should report blocked with one dependency blocker, and the dry-run apply plan should show `Version:upsert->createMissing@...(...,missing-deps:TextFile)`.
3. Run `Pull Pending Changes`; it should pull the operation and advance the remembered sequence.
4. Run `Check Remote Changes`; it should report the selected project as up to date.

Satisfied dependency diagnostic sequence:

1. Run `Run Satisfied Dependency Probe`; `/head` should report two pending changes.
2. Run `Preview Pending Apply`; it should classify two supported upserts with no blocked dependencies. The readiness line should report `ready for dry-run applier`, the apply order should place `TextFile:createMissing` before `Version:createMissing`, and the dry-run apply plan should include both `TextFile:upsert->createMissing` and `Version:upsert->createMissing` with `deps-ok`.
3. Run `Pull Pending Changes`; it should pull both operations and advance the remembered sequence.
4. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-04: the satisfied dependency sequence produced `Dependencies: 2 ok, 0 blocked`, `Apply readiness: ready for dry-run applier`, and `Apply order: TextFile:createMissing@... -> Version:createMissing@...`; follow-up pull and head check were also OK.

Folder dependency diagnostic sequence:

1. Run `Run Folder Dependency Probe`; `/head` should report three pending changes.
2. Run `Preview Pending Apply`; it should classify three supported upserts with no blocked dependencies. The readiness line should report `ready for dry-run applier`, and the apply order should place `Folder:createMissing` before `TextFile:createMissing` before `Version:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one remote folder, one text file, and one version in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one scratch project, two scratch folders (wrapper + remote), one text file, one version, one linked version, and one text file with versions.
5. Run `Pull Pending Changes`; it should pull three operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the folder dependency sequence produced `Apply order: Folder:createMissing@... -> TextFile:createMissing@... -> Version:createMissing@...`, materialized `Created 1 folders, 1 text files, and 1 versions`, and scratch inspection reported `1 projects, 2 folders, 1 text files, 1 versions, 1 versions linked to text files, 1 text files with versions`.

Annotation dependency diagnostic sequence:

1. Run `Run Annotation Dependency Probe`; `/head` should report five pending changes.
2. Run `Preview Pending Apply`; it should classify five supported upserts with no blocked dependencies. The apply order should place `Folder:createMissing`, `TextFile:createMissing`, and `Version:createMissing` before `CommentModel:createMissing` and `FootnoteModel:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one remote folder, one text file, one version, one comment, and one footnote in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one scratch project, two scratch folders, one text file, one version, one comment, one footnote, and one linked record for each relationship count.
5. Run `Pull Pending Changes`; it should pull five operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the annotation dependency sequence produced five supported upserts with `Dependencies: 5 ok, 0 blocked`, `Apply readiness: ready for dry-run applier`, and apply order `Folder:createMissing@... -> TextFile:createMissing@... -> Version:createMissing@... -> CommentModel:createMissing@... -> FootnoteModel:createMissing@...`. Scratch materialization created one folder, one text file, one version, one comment, and one footnote. Scratch inspection reported all records and relationships linked correctly.

Style dependency diagnostic sequence:

1. Run `Run Style Dependency Probe`; `/head` should report three pending changes.
2. Run `Preview Pending Apply`; it should classify three supported upserts with no blocked dependencies. The apply order should place `StyleSheet:createMissing` before `TextStyleModel:createMissing` and `ImageStyle:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one stylesheet, one text style, and one image style in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one scratch project, one wrapper folder, one stylesheet, one text style, one image style, one text style linked to a stylesheet, and one image style linked to a stylesheet.
5. Run `Pull Pending Changes`; it should pull three operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the style dependency sequence produced three supported upserts with `Dependencies: 3 ok, 0 blocked`, `Apply readiness: ready for dry-run applier`, and apply order `StyleSheet:createMissing@... -> TextStyleModel:createMissing@... -> ImageStyle:createMissing@...`. Scratch materialization created one stylesheet, one text style, and one image style. Scratch inspection reported one scratch project, one wrapper folder, one stylesheet, one text style, one image style, and both style records linked to the stylesheet.

Submission dependency diagnostic sequence:

1. Run `Run Submission Dependency Probe`; `/head` should report six pending changes.
2. Run `Preview Pending Apply`; it should classify six supported upserts with no blocked dependencies. The apply order should place parent records before `SubmittedFile:createMissing`: `Publication`, `Folder`, `TextFile`, `Version`, `Submission`, then `SubmittedFile`.
3. Run `Materialize Pending Apply Preview`; it should create one publication, one remote folder, one text file, one version, one submission, and one submitted file in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one scratch project, two folders (wrapper + remote), one text file, one version, one publication, one submission, one submitted file, one submission linked to publication, and one submitted file linked to submission/text file/version.
5. Run `Pull Pending Changes`; it should pull six operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the submission dependency sequence produced six supported upserts with `Dependencies: 6 ok, 0 blocked` and materialized one publication, one folder, one text file, one version, one submission, and one submitted file. Scratch inspection reported `1 submissions linked to publications` and `1 submitted files linked to submissions/text files/versions`. Initial preview order put `Submission` before `Version`; materialization still succeeded because `SubmittedFile` was last, but the rank was adjusted so future previews order `Version` before `Submission`.

Poetry collection dependency diagnostic sequence:

1. Run `Run Poetry Collection Dependency Probe`; `/head` should report three pending changes.
2. Run `Preview Pending Apply`; it should classify three supported upserts with no blocked dependencies. The apply order should place `PoetryCollection:createMissing` and `TextFile:createMissing` before `TextFileCollectionLink:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one poetry collection, one text file, and one text-file-collection link in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one poetry collection, one text file, one text-file-collection link, and one text-file-collection link linked to both sides.
5. Run `Pull Pending Changes`; it should pull three operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the poetry collection dependency sequence produced three supported upserts with `Dependencies: 3 ok, 0 blocked`, apply order `PoetryCollection:createMissing@... -> TextFile:createMissing@... -> TextFileCollectionLink:createMissing@...`, and scratch materialization created one text file, one poetry collection, and one join link. Scratch inspection reported one poetry collection, one text-file-collection link, and `1 text-file-collection links linked to both sides`.

Prose section dependency diagnostic sequence:

1. Run `Run Prose Section Dependency Probe`; `/head` should report three pending changes.
2. Run `Preview Pending Apply`; it should classify three supported upserts with no blocked dependencies. The apply order should place `ProseSection:createMissing` and `TextFile:createMissing` before `TextFileSectionLink:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one prose section, one text file, and one text-file-section link in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one prose section, one text file, one text-file-section link, and one text-file-section link linked to both sides.
5. Run `Pull Pending Changes`; it should pull three operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the prose section dependency sequence produced three supported upserts with `Dependencies: 3 ok, 0 blocked`, apply order `ProseSection:createMissing@... -> TextFile:createMissing@... -> TextFileSectionLink:createMissing@...`, and scratch materialization created one text file, one prose section, and one join link. Scratch inspection reported one prose section, one text-file-section link, and `1 text-file-section links linked to both sides`.

Note entry dependency diagnostic sequence:

1. Run `Run Note Entry Dependency Probe`; `/head` should report one pending change.
2. Run `Preview Pending Apply`; it should classify one supported upsert with no blocked dependencies. The apply order should show `NoteEntry:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one note in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one note.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the note entry dependency sequence produced one supported upsert with `Dependencies: 1 ok, 0 blocked`, apply order `NoteEntry:createMissing@...`, and scratch materialization created one note. Scratch inspection reported `1 notes`.

Glossary citation dependency diagnostic sequence:

1. Run `Run Glossary Citation Dependency Probe`; `/head` should report two pending changes.
2. Run `Preview Pending Apply`; it should classify two supported upserts with no blocked dependencies. The apply order should place `CitationEntry:createMissing` before `GlossaryEntry:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one citation and one glossary entry in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one citation, one glossary entry, and one glossary entry linked to a citation.
5. Run `Pull Pending Changes`; it should pull two operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the glossary citation dependency sequence produced two supported upserts with `Dependencies: 2 ok, 0 blocked`, apply order `CitationEntry:createMissing@... -> GlossaryEntry:createMissing@...`, and scratch materialization created one citation plus one glossary entry. Scratch inspection reported one citation, one glossary entry, and `1 glossary entries linked to citations`.

Reference entry dependency diagnostic sequence:

1. Run `Run Reference Entry Dependency Probe`; `/head` should report one pending change.
2. Run `Preview Pending Apply`; it should classify one supported upsert with no blocked dependencies. The apply order should show `ReferenceEntry:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one reference entry in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one reference entry.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the reference entry dependency sequence produced one supported upsert with `Dependencies: 1 ok, 0 blocked`, apply order `ReferenceEntry:createMissing@...`, and scratch materialization created one reference entry. Scratch inspection reported `1 reference entries`.

Index entry dependency diagnostic sequence:

1. Run `Run Index Entry Dependency Probe`; `/head` should report two pending changes.
2. Run `Preview Pending Apply`; it should classify two supported upserts with no blocked dependencies. The apply order should place the parent `IndexEntry:createMissing` before the child `IndexEntry:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create two index entries in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report two index entries and one child index entry linked to a parent.
5. Run `Pull Pending Changes`; it should pull two operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the index entry dependency sequence produced two supported upserts with `Dependencies: 2 ok, 0 blocked`, apply order `IndexEntry:createMissing@... -> IndexEntry:createMissing@...`, and scratch materialization created two index entries. Scratch inspection reported two index entries and `1 child index entries linked to parents`.

Re-verified 2026-07-06: the remote index entry dependency sequence produced parent/child `IndexEntry` upserts at seq 20-21, previewed as `IndexEntry:createMissing@20 -> IndexEntry:createMissing@21` with `Dependencies: 2 ok, 0 blocked`, materialized two index entries, and scratch inspection reported `1 child index entries linked to parents`. Production local data was not read or changed.

Contributor entry dependency diagnostic sequence:

1. Run `Run Contributor Entry Dependency Probe`; `/head` should report one pending change.
2. Run `Preview Pending Apply`; it should classify one supported upsert with no blocked dependencies. The apply order should show `ContributorEntry:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one contributor in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one contributor.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the contributor entry dependency sequence produced one supported upsert with `Dependencies: 1 ok, 0 blocked`, apply order `ContributorEntry:createMissing@...`, and scratch materialization created one contributor. Scratch inspection reported one contributor in the CloudKit-disabled scratch store.

Page setup dependency diagnostic sequence:

1. Run `Run Page Setup Dependency Probe`; `/head` should report two pending changes.
2. Run `Preview Pending Apply`; it should classify two supported upserts with no blocked dependencies. The apply order should show `PageSetup:createMissing -> PrinterPaper:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one page setup and one printer paper in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one page setup, one printer paper, and one printer paper linked to a page setup.
5. Run `Pull Pending Changes`; it should pull two operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the page setup dependency sequence produced two supported upserts with `Dependencies: 2 ok, 0 blocked`, apply order `PageSetup:createMissing@... -> PrinterPaper:createMissing@...`, and scratch materialization created one page setup and one printer paper. Scratch inspection reported one page setup, one printer paper, and `1 printer papers linked to page setups` in the CloudKit-disabled scratch store.

Custom attribute dependency diagnostic sequence:

1. Run `Run Custom Attribute Dependency Probe`; `/head` should report two pending changes.
2. Run `Preview Pending Apply`; it should classify two supported upserts with no blocked dependencies. The apply order should show `Character:createMissing -> CustomAttribute:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one character and one custom attribute in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one custom attribute and one custom attribute linked to a character/location.
5. Run `Pull Pending Changes`; it should pull two operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the custom attribute dependency sequence produced two supported upserts with `Dependencies: 2 ok, 0 blocked`, apply order `Character:createMissing@... -> CustomAttribute:createMissing@...`, and scratch materialization created one story record and one custom attribute. Scratch inspection reported one character, one custom attribute, and `1 custom attributes linked to characters/locations` in the CloudKit-disabled scratch store.

Trash item dependency diagnostic sequence:

1. Run `Run Trash Item Dependency Probe`; `/head` should report three pending changes.
2. Run `Preview Pending Apply`; it should classify three supported upserts with no blocked dependencies. The apply order should show `Folder:createMissing -> TextFile:createMissing -> TrashItem:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one folder, one text file, and one trash item in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one trash item and one trash item linked to a text file/project.
5. Run `Pull Pending Changes`; it should pull three operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the trash item dependency sequence produced three supported upserts with `Dependencies: 3 ok, 0 blocked`, apply order `Folder:createMissing@... -> TextFile:createMissing@... -> TrashItem:createMissing@...`, and scratch materialization created one folder, one text file, and one trash item. Scratch inspection reported one trash item and `1 trash items linked to text files/projects` in the CloudKit-disabled scratch store.

Manuscript review dependency diagnostic sequence:

1. Run `Run Manuscript Review Dependency Probe`; `/head` should report two pending changes.
2. Run `Preview Pending Apply`; it should classify two supported upserts with no blocked dependencies. The apply order should show `ManuscriptReview:createMissing -> ReviewSuggestion:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one manuscript review and one review suggestion in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one manuscript review, one review suggestion, and one review suggestion linked to a manuscript review.
5. Run `Pull Pending Changes`; it should pull two operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the manuscript review dependency sequence produced two supported upserts with `Dependencies: 2 ok, 0 blocked`, apply order `ManuscriptReview:createMissing@1429 -> ReviewSuggestion:createMissing@1430`, and scratch materialization created one manuscript review and one review suggestion. Scratch inspection reported one manuscript review, one review suggestion, and `1 review suggestions linked to manuscript reviews` in the CloudKit-disabled scratch store.

Poetry form dependency diagnostic sequence:

1. Run `Run Poetry Form Dependency Probe`; `/head` should report one pending change.
2. Run `Preview Pending Apply`; it should classify one supported upsert with no blocked dependencies. The apply order should show `PoetryFormModel:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one poetry form in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one poetry form.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the poetry form dependency sequence produced one supported upsert with `Dependencies: 1 ok, 0 blocked`, apply order `PoetryFormModel:createMissing@1431`, and scratch materialization created one poetry form. Scratch inspection reported one poetry form in the CloudKit-disabled scratch store.

Story link dependency diagnostic sequence:

1. Run `Run Story Link Dependency Probe`; `/head` should report three pending changes.
2. Run `Preview Pending Apply`; it should classify three supported upserts with no blocked dependencies. The apply order should place `Character:createMissing` and `PlotElement:createMissing` before `CharacterPlotElementLink:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one character, one plot element, and one character-plot link in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one character, one plot element, one character-plot link, and one character-plot link linked to both sides.
5. Run `Pull Pending Changes`; it should pull three operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the story link dependency sequence produced three supported upserts with `Dependencies: 3 ok, 0 blocked`, apply order `Character:createMissing@... -> PlotElement:createMissing@... -> CharacterPlotElementLink:createMissing@...`, and scratch materialization created two story records plus one join link. Scratch inspection reported one character, one plot element, one character-plot link, and `1 character-plot links linked to both sides`.

Location link dependency diagnostic sequence:

1. Run `Run Location Link Dependency Probe`; `/head` should report three pending changes.
2. Run `Preview Pending Apply`; it should classify three supported upserts with no blocked dependencies. The apply order should place `Location:createMissing` and `PlotElement:createMissing` before `LocationPlotElementLink:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one location, one plot element, and one location-plot link in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one location, one plot element, one location-plot link, and one location-plot link linked to both sides.
5. Run `Pull Pending Changes`; it should pull three operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the location link dependency sequence produced three supported upserts with `Dependencies: 3 ok, 0 blocked`, apply order `Location:createMissing@... -> PlotElement:createMissing@... -> LocationPlotElementLink:createMissing@...`, and scratch materialization created two story records plus one join link. Scratch inspection reported one location, one plot element, one location-plot link, and `1 location-plot links linked to both sides`.

Scene character dependency diagnostic sequence:

1. Run `Run Scene Character Dependency Probe`; `/head` should report three pending changes.
2. Run `Preview Pending Apply`; it should classify three supported upserts with no blocked dependencies. The apply order should place both `StoryScene:createMissing` and `Character:createMissing` before `SceneCharacterLink:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one scene, one character, and one scene-character link in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one scene, one character, one scene-character link, and one scene-character link linked to both sides.
5. Run `Pull Pending Changes`; it should pull three operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the scene character dependency sequence produced three supported upserts with `Dependencies: 3 ok, 0 blocked`, apply order `Character:createMissing@... -> StoryScene:createMissing@... -> SceneCharacterLink:createMissing@...`, and scratch materialization created two story records plus one join link. Scratch inspection reported one scene, one character, one scene-character link, and `1 scene-character links linked to both sides`.

Scene location dependency diagnostic sequence:

1. Run `Run Scene Location Dependency Probe`; `/head` should report three pending changes.
2. Run `Preview Pending Apply`; it should classify three supported upserts with no blocked dependencies. The apply order should place both `StoryScene:createMissing` and `Location:createMissing` before `SceneLocationLink:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one scene, one location, and one scene-location link in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one scene, one location, one scene-location link, and one scene-location link linked to both sides.
5. Run `Pull Pending Changes`; it should pull three operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the scene location dependency sequence produced three supported upserts with `Dependencies: 3 ok, 0 blocked`, apply order `Location:createMissing@... -> StoryScene:createMissing@... -> SceneLocationLink:createMissing@...`, and scratch materialization created two story records plus one join link. Scratch inspection reported one scene, one location, one scene-location link, and `1 scene-location links linked to both sides`.

Scene chapter dependency diagnostic sequence:

1. Run `Run Scene Chapter Dependency Probe`; `/head` should report three pending changes.
2. Run `Preview Pending Apply`; it should classify three supported upserts with no blocked dependencies. The apply order should place `Chapter:createMissing` and `StoryScene:createMissing` before `SceneChapterLink:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one chapter, one scene, and one scene-chapter link in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one chapter, one scene, one scene-chapter link, and one scene-chapter link linked to both sides.
5. Run `Pull Pending Changes`; it should pull three operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the scene chapter dependency sequence produced three supported upserts with `Dependencies: 3 ok, 0 blocked`, apply order `Chapter:createMissing@... -> StoryScene:createMissing@... -> SceneChapterLink:createMissing@...`, and scratch materialization created two story records plus one join link. Scratch inspection reported one chapter, one scene, one scene-chapter link, and `1 scene-chapter links linked to both sides`.

Scene act dependency diagnostic sequence:

1. Run `Run Scene Act Dependency Probe`; `/head` should report three pending changes.
2. Run `Preview Pending Apply`; it should classify three supported upserts with no blocked dependencies. The apply order should place `Act:createMissing` and `StoryScene:createMissing` before `SceneActLink:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one act, one scene, and one scene-act link in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one act, one scene, one scene-act link, and one scene-act link linked to both sides.
5. Run `Pull Pending Changes`; it should pull three operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the scene act dependency sequence produced three supported upserts with `Dependencies: 3 ok, 0 blocked`, apply order `Act:createMissing@... -> StoryScene:createMissing@... -> SceneActLink:createMissing@...`, and scratch materialization created two story records plus one join link. Scratch inspection reported one act, one scene, one scene-act link, and `1 scene-act links linked to both sides`.

Scene book dependency diagnostic sequence:

1. Run `Run Scene Book Dependency Probe`; `/head` should report three pending changes.
2. Run `Preview Pending Apply`; it should classify three supported upserts with no blocked dependencies. The apply order should place `Book:createMissing` and `StoryScene:createMissing` before `SceneBookLink:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one book, one scene, and one scene-book link in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one book, one scene, one scene-book link, and one scene-book link linked to both sides.
5. Run `Pull Pending Changes`; it should pull three operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the scene book dependency sequence produced three supported upserts with `Dependencies: 3 ok, 0 blocked`, apply order `Book:createMissing@... -> StoryScene:createMissing@... -> SceneBookLink:createMissing@...`, and scratch materialization created two story records plus one join link. Scratch inspection reported one book, one scene, one scene-book link, and `1 scene-book links linked to both sides`.

Scene plot dependency diagnostic sequence:

1. Run `Run Scene Plot Dependency Probe`; `/head` should report three pending changes.
2. Run `Preview Pending Apply`; it should classify three supported upserts with no blocked dependencies. The apply order should place `StoryScene:createMissing` and `PlotElement:createMissing` before `ScenePlotElementLink:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one scene, one plot element, and one scene-plot link in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one scene, one plot element, one scene-plot link, and one scene-plot link linked to both sides.
5. Run `Pull Pending Changes`; it should pull three operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the scene plot dependency sequence produced three supported upserts with `Dependencies: 3 ok, 0 blocked`, apply order `PlotElement:createMissing@... -> StoryScene:createMissing@... -> ScenePlotElementLink:createMissing@...`, and scratch materialization created two story records plus one join link. Scratch inspection reported one scene, one plot element, one scene-plot link, and `1 scene-plot links linked to both sides`.

Unsupported operation diagnostic sequence:

1. Run `Run Unsupported Operation Probe`; `/head` should report one pending change.
2. Run `Preview Pending Apply`; it should classify zero supported upserts, zero delete/trash/tombstone operations, zero restore operations, and one ignored/unsupported operation. The readiness line should report blocked with one ignored final action.
3. Run `Pull Pending Changes`; it should pull the operation and advance the remembered sequence.
4. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-04: the unsupported operation sequence produced `1 ignored/unsupported ops`, `Coalesced final actions: ... 1 ignored`, `Apply readiness: blocked (0 dependency blockers, 1 ignored final actions, 0 payload blockers)`, and a plan sample of `TextFile:ignore->ignoreUnsupported@...`.

No-payload diagnostic sequence:

1. Run `Run No-Payload Probe`; `/head` should report one pending change.
2. Run `Preview Pending Apply`; it should classify one supported upsert. The readiness line should report blocked with one payload blocker, and the plan sample should show `TextFile:upsert->createMissing@...(...,no-payload,deps-ok)`.
3. Run `Pull Pending Changes`; it should pull the operation and advance the remembered sequence.
4. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-04: the no-payload sequence produced `1 supported upserts`, `Dependencies: 1 ok, 0 blocked`, `Apply readiness: blocked (0 dependency blockers, 0 ignored final actions, 1 payload blockers)`, and a plan sample of `TextFile:upsert->createMissing@...(local-missing,no-payload,deps-ok)`.

Scratch materialization diagnostic sequence:

1. Run `Run Satisfied Dependency Probe`; `/head` should report two pending changes.
2. Run `Preview Pending Apply`; it should report readiness as `ready for dry-run applier` and order `TextFile:createMissing` before `Version:createMissing`.
3. Run `Materialize Pending Apply Preview`; it should create one synthetic `TextFile` and one synthetic `Version` in `cloudflare-sync-poc-pending-apply.sqlite`, with CloudKit disabled. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one scratch project, one scratch folder, one text file, one version, one linked version, and one text file with versions.
5. Run `Pull Pending Changes`; it should pull both operations and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the scratch materialization sequence produced `Created 1 text files and 1 versions in scratch store cloudflare-sync-poc-pending-apply.sqlite`, preserved `Apply readiness: ready for dry-run applier`, preserved apply order `TextFile:createMissing@... -> Version:createMissing@...`, did not advance the cursor, and did not change production local data.

Verified 2026-07-05: scratch materialization failed closed for all blocker probes. Missing dependency refused with the dependency blocker path, unsupported operation refused with the ignored final action path, and no-payload refused with the payload blocker path.

The scratch materializer is intentionally narrow. It refuses any blocked plan and currently supports `createMissing` and `restoreMissing` actions for `StyleSheet`, `TextStyleModel`, `ImageStyle`, `PageSetup`, `PrinterPaper`, `PoetryFormModel`, `ManuscriptReview`, `ReviewSuggestion`, `Folder`, `TextFile`, `Version`, `TrashItem`, `CommentModel`, `FootnoteModel`, `Chapter`, `Act`, `Book`, `ProseSection`, `PoetryCollection`, `StoryScene`, `Character`, `Location`, `CustomAttribute`, `PlotElement`, `TextFileSectionLink`, `TextFileCollectionLink`, `SceneChapterLink`, `SceneActLink`, `SceneBookLink`, `ScenePlotElementLink`, `SceneCharacterLink`, `SceneLocationLink`, `CharacterPlotElementLink`, `LocationPlotElementLink`, `NoteEntry`, `CitationEntry`, `GlossaryEntry`, `ReferenceEntry`, `IndexEntry`, `ContributorEntry`, `Publication`, `Submission`, and `SubmittedFile`, plus scratch-only `Project` `updateExisting` and explicit `deleteNoopMissing` no-ops for remote deletes whose target record does not exist locally. Missing dependency, unsupported operation, no-payload, non-Project update, existing-local restore, existing-local delete, and broader entity plans must fail closed until explicitly implemented.

## Phase 5 Scratch Update Start

Phase 5 begins with scratch-only update semantics. The first supported update path is intentionally limited to `Project:updateExisting` from the `Run Remote Change Probe` sequence. The materializer seeds the CloudKit-disabled scratch store with a copy of the selected local project using the same project ID, applies the remote project payload to that scratch copy, reports `updated existing records`, and still never writes to the production SwiftData store.

Verified 2026-07-05: the Phase 5 Project scratch update sequence produced `Project:upsert->updateExisting@1441(local-exists,payload,deps-ok)`, materialized `1 updated existing records`, and scratch inspection reported one fresh project with no stale text file from the previous restore probe. Production local data was not changed.

The second scratch-only update path is `TextFile:updateExisting`. The materializer uses the same bounded project graph as dry-run planning to seed a local `TextFile` copy and its parent folder into the CloudKit-disabled scratch store, applies the remote payload to that scratch copy, reports one seeded existing record and one updated existing record, and still never writes to the production SwiftData store.

Existing text file update diagnostic sequence:

1. Run `Run Existing Text File Update Probe`; `/head` should report one pending change.
2. Run `Preview Pending Apply`; it should classify one supported upsert. The plan should show `TextFile:upsert->updateExisting` because the selected project has that file locally.
3. Run `Materialize Pending Apply Preview`; it should seed one existing text file into `cloudflare-sync-poc-pending-apply.sqlite`, apply the update to the scratch copy, and report one updated existing record. Cursor must not advance and production local data must not change.
4. Run `Inspect Pending Apply Scratch Store`; it should report one text file and no versions unless the update batch includes versions.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Verified 2026-07-05: the existing text file update sequence produced `TextFile:upsert->updateExisting@1442(local-exists,payload,deps-ok)`, materialized `1 updated existing records (1 seeded)`, and scratch inspection reported one text file plus its seeded parent folder in the CloudKit-disabled scratch store. Production local data was not changed.

Existing stylesheet update diagnostic sequence:

1. Run `Run Existing StyleSheet Update Probe`; it selects the current project's local `StyleSheet`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `StyleSheet` upsert using the same stylesheet id.
2. Run `Preview Pending Apply`; expected summary includes `StyleSheet:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch stylesheet.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one stylesheet in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `StyleSheet:updateExisting` remains scratch-only. The materializer seeds a bounded local stylesheet copy into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-05: the existing stylesheet update sequence produced `StyleSheet:upsert->updateExisting@1445(local-exists,payload,deps-ok)`, materialized `1 updated existing records (1 seeded)`, and scratch inspection reported one stylesheet in the CloudKit-disabled scratch store. Production local data was not read or changed.

Existing text style update diagnostic sequence:

1. Run `Run Existing Text Style Update Probe`; it selects the current project's first sorted local `TextStyleModel`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `TextStyleModel` upsert using the same text style id and parent stylesheet id.
2. Run `Preview Pending Apply`; expected summary includes `TextStyleModel:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with seeded scratch copies of the parent stylesheet and text style.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one stylesheet, one text style, and one text style linked to a stylesheet in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `TextStyleModel:updateExisting` remains scratch-only. The materializer seeds bounded local style copies into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-05: the existing text style update sequence produced `TextStyleModel:upsert->updateExisting@1446(local-exists,payload,deps-ok)`, materialized `1 updated existing records (2 seeded)`, and scratch inspection reported one stylesheet, one text style, and one text style linked to a stylesheet in the CloudKit-disabled scratch store. Production local data was not read or changed.

Existing image style update diagnostic sequence:

1. Run `Run Existing Image Style Update Probe`; it selects the current project's first sorted local `ImageStyle`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `ImageStyle` upsert using the same image style id and parent stylesheet id.
2. Run `Preview Pending Apply`; expected summary includes `ImageStyle:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with seeded scratch copies of the parent stylesheet and image style.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one stylesheet, one image style, and one image style linked to a stylesheet in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `ImageStyle:updateExisting` remains scratch-only. The materializer seeds bounded local style copies into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-05: the existing image style update sequence produced `ImageStyle:upsert->updateExisting@1447(local-exists,payload,deps-ok)`, materialized `1 updated existing records (2 seeded)`, and scratch inspection reported one stylesheet, one image style, and one image style linked to a stylesheet in the CloudKit-disabled scratch store. Production local data was not read or changed.

Existing page setup update diagnostic sequence:

1. Run `Run Existing Page Setup Update Probe`; it selects the first non-trashed selected project with an existing local `PageSetup`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `PageSetup` upsert using the same page setup id and project id. If no selected project has a `PageSetup`, the probe fails closed with a specific no-page-setup message.
2. Run `Preview Pending Apply`; expected summary includes `PageSetup:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch page setup.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one page setup in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `PageSetup:updateExisting` remains scratch-only. The materializer seeds a bounded local page setup copy into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Observed 2026-07-05: the existing page setup update probe failed closed with `No selected project has an existing page setup for the Cloudflare sync POC update probe.` No operation was pushed; preview returned zero operations after sequence 1447; materialize cleared the pending apply scratch store; inspection reported no scratch store. This dataset cannot verify `PageSetup:updateExisting` until a selected project has an existing `PageSetup`.

Observed 2026-07-05 with a different selected project: the existing page setup update probe successfully pushed `PageSetup` upsert sequence 1 after baseline 0. Scratch materialization was not verified in that run because the publication probe was run next and remembered baseline sequence 1, leaving only the later publication operation pending. To verify `PageSetup:updateExisting`, rerun the page setup probe by itself, then immediately run preview/materialize/inspect before any other probe.

Observed 2026-07-05: rerunning the page setup probe returned Worker HTTP 502 `Sync push failed`. Likely cause was a duplicate operation id from rerunning the same existing-update probe against the same entity; the app now appends a UUID to existing-update probe operation ids while preserving the entity id, so repeat probes should not collide with D1 primary keys.

Verified 2026-07-05: after unique existing-update operation ids were added, the existing page setup update sequence produced `PageSetup:upsert->updateExisting@4(local-exists,payload,deps-ok)`, materialized `1 updated existing records (1 seeded)`, and scratch inspection reported one page setup in the CloudKit-disabled scratch store. Production local data was not read or changed.

Existing printer paper update diagnostic sequence:

1. Run `Run Existing Printer Paper Update Probe`; it selects the first non-trashed selected project with an existing local `PrinterPaper` under a `PageSetup`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `PrinterPaper` upsert using the same printer paper id and parent page setup id. If no selected project has a printer paper, the probe fails closed with a specific no-printer-paper message.
2. Run `Preview Pending Apply`; expected summary includes `PrinterPaper:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch printer paper and its seeded parent page setup.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one page setup, one printer paper, and one printer paper linked to a page setup in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `PrinterPaper:updateExisting` remains scratch-only. The materializer seeds a bounded local page setup and printer paper copy into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Dataset-blocked 2026-07-06: the existing printer paper update probe failed closed with `No selected project has an existing printer paper for the Cloudflare sync POC update probe.` No operation was pushed. The user-facing default paper such as A4 is `PageSetup.paperName`, not a separate `PrinterPaper` row; `PrinterPaper:updateExisting` can only be verified if a selected project has a real local `PrinterPaper` under its `PageSetup`. Do not create production test data just to satisfy this probe.

Existing publication update diagnostic sequence:

1. Run `Run Existing Publication Update Probe`; it selects the first non-trashed selected project with at least one sampled local `Publication`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `Publication` upsert using the same publication id and project id.
2. Run `Preview Pending Apply`; expected summary includes `Publication:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch publication.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one publication in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `Publication:updateExisting` remains scratch-only. The materializer seeds a bounded local publication copy into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-05: the existing publication update sequence produced `Publication:upsert->updateExisting@2(local-exists,payload,deps-ok)`, materialized `1 updated existing records (1 seeded)`, and scratch inspection reported one publication in the CloudKit-disabled scratch store. Production local data was not read or changed.

Existing submission update diagnostic sequence:

1. Run `Run Existing Submission Update Probe`; it scans non-trashed selected projects for the first sampled local `Submission` linked to a `Publication`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `Submission` upsert using the same submission id and parent publication id. Collection-style submissions with no publication are skipped for this probe.
2. Run `Preview Pending Apply`; expected summary includes `Submission:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with seeded scratch copies of the parent publication and submission.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one publication, one submission, and one submission linked to a publication in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `Submission:updateExisting` remains scratch-only. The materializer seeds bounded local publication/submission copies into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-05: after the probe was changed to skip collection-style submissions without publications, the existing submission update sequence produced `Submission:upsert->updateExisting@5(local-exists,payload,deps-ok)`, materialized `1 updated existing records (2 seeded)`, and scratch inspection reported one publication, one submission, and one submission linked to a publication in the CloudKit-disabled scratch store. Production local data was not read or changed.

Existing submitted file update diagnostic sequence:

1. Run `Run Existing Submitted File Update Probe`; it scans non-trashed selected projects for the first sampled local `SubmittedFile` linked to a `Submission`, `Publication`, `TextFile`, and `Version`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `SubmittedFile` upsert using the same submitted file id and dependency ids.
2. Run `Preview Pending Apply`; expected summary includes `SubmittedFile:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with seeded scratch copies of the parent publication, submission, text file, version, and submitted file.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one publication, one submission, one submitted file, and one submitted file linked to its submission/text file/version in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `SubmittedFile:updateExisting` remains scratch-only. The materializer seeds bounded local publication/submission/text-file/version/submitted-file copies into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Implementation detail added 2026-07-05: the existing submitted file update probe skips submitted files missing any required parent link and uses UUID-suffixed operation ids to avoid D1 duplicate-key rerun collisions.

Observed 2026-07-06: the existing submitted file update probe and preview succeeded with `SubmittedFile:upsert->updateExisting@6(local-exists,payload,deps-ok)`, but materialization failed closed with `missing local SubmittedFile seed for updateExisting`. The seed path was looking back through sampled submissions and missed the target submitted file even though preview had found it locally. The materializer now seeds `SubmittedFile:updateExisting` from `Project.submittedFiles` first, falling back to sampled submissions, and verifies the remote dependency ids match the local submitted file relationships before creating the scratch copy.

Verified 2026-07-06: after the submitted-file seed path was fixed, the existing submitted file update sequence produced `SubmittedFile:upsert->updateExisting@7(local-exists,payload,deps-ok)`, materialized `1 updated existing records (5 seeded)`, and scratch inspection reported one publication, one submission, one text file, one version, one submitted file, one version linked to a text file, one text file with versions, one submission linked to a publication, and one submitted file linked to submission/text file/version. Production local data was not read or changed.

Existing folder update diagnostic sequence:

1. Run `Run Existing Folder Update Probe`; it selects a sampled local `Folder`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `Folder` upsert using the same folder id.
2. Run `Preview Pending Apply`; expected summary includes `Folder:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with a seeded scratch copy of the folder and any sampled parent folder needed for hierarchy.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes the seeded folder in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `Folder:updateExisting` remains scratch-only. The materializer seeds bounded local folder copies into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-05: the existing folder update sequence produced `Folder:upsert->updateExisting@1444(local-exists,payload,deps-ok)`, materialized `1 updated existing records (1 seeded)`, and scratch inspection reported the seeded folder in the CloudKit-disabled scratch store. Production local data was not read or changed.

Existing version update diagnostic sequence:

1. Run `Run Existing Version Update Probe`; it selects a sampled local `Version`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `Version` upsert using the same version id and parent `TextFile` id.
2. Run `Preview Pending Apply`; expected summary includes `Version:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with seeded scratch copies of the parent `TextFile` chain and `Version`.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one text file, one version, one version linked to a text file, one text file with versions, and CloudKit disabled.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `Version:updateExisting` remains scratch-only. The materializer seeds bounded local copies into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-05: the existing version update sequence produced `Version:upsert->updateExisting@1443(local-exists,payload,deps-ok)`, materialized `1 updated existing records (2 seeded)`, and scratch inspection reported one text file, one version, one version linked to a text file, and one text file with versions in the CloudKit-disabled scratch store. Production local data was not read or changed.

Existing comment update diagnostic sequence:

1. Run `Run Existing Comment Update Probe`; it selects a sampled local `CommentModel` attached to a sampled `Version`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `CommentModel` upsert using the same comment id and parent version id.
2. Run `Preview Pending Apply`; expected summary includes `CommentModel:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with seeded scratch copies of the parent text-file/version chain and comment.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one text file, one version, one comment, one version linked to a text file, one text file with versions, and one comment linked to a version in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `CommentModel:updateExisting` remains scratch-only. The materializer seeds bounded local text-file/version/comment copies into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-06: the existing comment update sequence produced `CommentModel:upsert->updateExisting@8(local-exists,payload,deps-ok)`, materialized `1 updated existing records (3 seeded)`, and scratch inspection reported one text file, one version, one comment, one version linked to a text file, one text file with versions, and one comment linked to a version in the CloudKit-disabled scratch store. Production local data was not read or changed.

Existing footnote update diagnostic sequence:

1. Run `Run Existing Footnote Update Probe`; it selects a sampled local `FootnoteModel` attached to a sampled `Version`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `FootnoteModel` upsert using the same footnote id and parent version id.
2. Run `Preview Pending Apply`; expected summary includes `FootnoteModel:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with seeded scratch copies of the parent text-file/version chain and footnote.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one text file, one version, one footnote, one version linked to a text file, one text file with versions, and one footnote linked to a version in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `FootnoteModel:updateExisting` remains scratch-only. The materializer seeds bounded local text-file/version/footnote copies into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-06: the existing footnote update sequence produced `FootnoteModel:upsert->updateExisting@9(local-exists,payload,deps-ok)`, materialized `1 updated existing records (3 seeded)`, and scratch inspection reported one text file, one version, one footnote, one version linked to a text file, one text file with versions, and one footnote linked to a version in the CloudKit-disabled scratch store. Production local data was not read or changed.

Existing note entry update diagnostic sequence:

1. Run `Run Existing Note Entry Update Probe`; it selects a sampled local `NoteEntry`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `NoteEntry` upsert using the same note id and project id.
2. Run `Preview Pending Apply`; expected summary includes `NoteEntry:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch note attached to the scratch project.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one note in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `NoteEntry:updateExisting` remains scratch-only. The materializer seeds one bounded local note copy into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Implementation note: file-editor notes can be visible through reference markers before `Project.noteEntries` is reliable in the diagnostics selection. The existing note update probe remembers the exact pending `NoteEntry:<id>` key it selected so preview/materialization can classify the same entity as `updateExisting` while still applying only to the CloudKit-disabled scratch store.

Verified 2026-07-06: the existing note entry update sequence produced `NoteEntry:upsert->updateExisting@14(local-exists,payload,deps-ok)`, materialized `1 updated existing records (1 seeded)`, and scratch inspection reported one note in the CloudKit-disabled scratch store. Production local data was not read or changed.

Existing contributor update diagnostic sequence:

1. Run `Run Existing Contributor Update Probe`; it selects a sampled local `ContributorEntry`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `ContributorEntry` upsert using the same contributor id and project id.
2. Run `Preview Pending Apply`; expected summary includes `ContributorEntry:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch contributor attached to the scratch project.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one contributor in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `ContributorEntry:updateExisting` remains scratch-only. The materializer seeds one bounded local contributor copy into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-06: the existing contributor update sequence produced `ContributorEntry:upsert->updateExisting@15(local-exists,payload,deps-ok)`, materialized `1 updated existing records (1 seeded)`, and scratch inspection reported one contributor in the CloudKit-disabled scratch store. Production local data was not read or changed.

Existing reference entry update diagnostic sequence:

1. Run `Run Existing Reference Entry Update Probe`; it selects a sampled local `ReferenceEntry`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `ReferenceEntry` upsert using the same reference entry id and project id.
2. Run `Preview Pending Apply`; expected summary includes `ReferenceEntry:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch reference entry attached to the scratch project.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one reference entry in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `ReferenceEntry:updateExisting` remains scratch-only. The materializer seeds one bounded local reference entry copy into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-06: the existing reference entry update sequence produced `ReferenceEntry:upsert->updateExisting@17(local-exists,payload,deps-ok)`, materialized `1 updated existing records (1 seeded)`, and scratch inspection reported one reference entry in the CloudKit-disabled scratch store. Production local data was not read or changed.

Re-verified 2026-07-06 after removing the dormant `CitationEntry:updateExisting` diagnostic path: `ReferenceEntry:upsert->updateExisting@19(local-exists,payload,deps-ok)` materialized `1 updated existing records (1 seeded)`, scratch inspection reported one reference entry, and production local data was not read or changed.

Existing glossary entry update diagnostic sequence:

1. Run `Run Existing Glossary Entry Update Probe`; it selects a sampled local `GlossaryEntry`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `GlossaryEntry` upsert using the same glossary entry id and project id.
2. Run `Preview Pending Apply`; expected summary includes `GlossaryEntry:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch glossary entry attached to the scratch project.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one glossary entry in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `GlossaryEntry:updateExisting` remains scratch-only. The materializer seeds one bounded local glossary entry copy into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-06: the existing glossary entry update sequence produced `GlossaryEntry:upsert->updateExisting@18(local-exists,payload,deps-ok)`, materialized `1 updated existing records (1 seeded)`, and scratch inspection reported one glossary entry in the CloudKit-disabled scratch store. Production local data was not read or changed.

Existing index entry update diagnostic sequence:

1. Run `Run Existing Index Entry Update Probe`; it selects a sampled local top-level `IndexEntry`, bootstraps/remembers the baseline sequence, then pushes a simulated remote `IndexEntry` upsert using the same index entry id and project id.
2. Run `Preview Pending Apply`; expected summary includes `IndexEntry:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch index entry attached to the scratch project.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one index entry in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `IndexEntry:updateExisting` remains scratch-only. The initial probe targets a top-level index entry so the preview does not require a parent-entry dependency operation. The materializer can seed an existing parent chain if a future probe targets a child entry.

Verified 2026-07-06: the existing index entry update sequence selected IndexEntry `gun` in project `Poems 2026`, pushed simulated upsert sequence 22 after baseline 21, and previewed `IndexEntry:upsert->updateExisting@22(local-exists,payload,deps-ok)`. Materialization created one scratch index entry and reported `1 updated existing records (1 seeded)` in `cloudflare-sync-poc-pending-apply.sqlite`; scratch inspection reported one project, one folder, and one index entry with CloudKit disabled. The cursor was not advanced, and production local data was not read or changed.

Existing poetry form update diagnostic sequence:

1. Run `Run Existing Poetry Form Update Probe`; it selects the first local `PoetryFormModel`, bootstraps/remembers the selected project baseline sequence, then pushes a simulated remote `PoetryFormModel` upsert using the same poetry form id.
2. Run `Preview Pending Apply`; expected summary includes `PoetryFormModel:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch poetry form.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one poetry form in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `PoetryFormModel:updateExisting` remains scratch-only. The materializer seeds one bounded local poetry form copy into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-06: the existing poetry form update sequence selected PoetryFormModel `Ballad`, pushed simulated upsert sequence 23 after baseline 22, and previewed `PoetryFormModel:upsert->updateExisting@23(local-exists,payload,deps-ok)`. Materialization created one scratch poetry form and reported `1 updated existing records (1 seeded)` in `cloudflare-sync-poc-pending-apply.sqlite`; scratch inspection reported one project, one folder, and one poetry form with CloudKit disabled. The cursor was not advanced, and production local data was not read or changed.

Existing poetry collection update diagnostic sequence:

1. Run `Run Existing Poetry Collection Update Probe`; it selects the first sampled local `PoetryCollection`, bootstraps/remembers the selected project baseline sequence, then pushes a simulated remote `PoetryCollection` upsert using the same collection id and project id.
2. Run `Preview Pending Apply`; expected summary includes `PoetryCollection:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch poetry collection.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one poetry collection in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `PoetryCollection:updateExisting` remains scratch-only. The materializer seeds one bounded local poetry collection copy into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-06: the existing poetry collection update sequence selected PoetryCollection `Collection 1` in project `Poems 2026`, pushed simulated upsert sequence 24 after baseline 23, and previewed `PoetryCollection:upsert->updateExisting@24(local-exists,payload,deps-ok)`. Materialization created one scratch poetry collection and reported `1 updated existing records (1 seeded)` in `cloudflare-sync-poc-pending-apply.sqlite`; scratch inspection reported one project, one folder, and one poetry collection with CloudKit disabled. The cursor was not advanced, and production local data was not read or changed.

Existing chapter update diagnostic sequence:

1. Run `Run Existing Chapter Update Probe`; it selects the first sampled local `Chapter`, bootstraps/remembers the selected project baseline sequence, then pushes a simulated remote `Chapter` upsert using the same chapter id and project id.
2. Run `Preview Pending Apply`; expected summary includes `Chapter:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch chapter.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one story record in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `Chapter:updateExisting` remains scratch-only. The materializer seeds one bounded local chapter copy into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-06: the existing chapter update sequence selected Chapter `Chapter 1` in project `The Devil's Triangle`, pushed simulated upsert sequence 1 after baseline 0, and previewed `Chapter:upsert->updateExisting@1(local-exists,payload,deps-ok)`. Materialization created one scratch chapter and reported `1 updated existing records (1 seeded)` in `cloudflare-sync-poc-pending-apply.sqlite`; scratch inspection reported one project, one folder, and one chapter with CloudKit disabled. The cursor was not advanced, and production local data was not read or changed.

Existing act update diagnostic sequence:

1. Run `Run Existing Act Update Probe`; it selects the first sampled local `Act`, bootstraps/remembers the selected project baseline sequence, then pushes a simulated remote `Act` upsert using the same act id and project id.
2. Run `Preview Pending Apply`; expected summary includes `Act:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch act.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one story record in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `Act:updateExisting` remains scratch-only. The materializer seeds one bounded local act copy into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-06: the existing act update sequence selected Act `Act 1` in project `A Play for Today`, pushed simulated upsert sequence 1 after baseline 0, and previewed `Act:upsert->updateExisting@1(local-exists,payload,deps-ok)`. Materialization created one scratch act and reported `1 updated existing records (1 seeded)` in `cloudflare-sync-poc-pending-apply.sqlite`; scratch inspection reported one project, one folder, and one act with CloudKit disabled. The cursor was not advanced, and production local data was not read or changed.

Existing book update diagnostic sequence:

1. Run `Run Existing Book Update Probe`; it selects the first sampled local `Book`, bootstraps/remembers the selected project baseline sequence, then pushes a simulated remote `Book` upsert using the same book id and project id.
2. Run `Preview Pending Apply`; expected summary includes `Book:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch book.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one story record in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `Book:updateExisting` remains scratch-only. The materializer seeds one bounded local book copy into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-06: the existing book update sequence selected Book `Departure (The Setup)` in project `The Republic of Heaven`, pushed simulated upsert sequence 1448 after baseline 1447, and previewed `Book:upsert->updateExisting@1448(local-exists,payload,deps-ok)`. Materialization created one scratch book and reported `1 updated existing records (1 seeded)` in `cloudflare-sync-poc-pending-apply.sqlite`; scratch inspection reported one project, one folder, and one book with CloudKit disabled. The cursor was not advanced, and production local data was not read or changed.

Existing prose section update diagnostic sequence:

1. Run `Run Existing Prose Section Update Probe`; it selects the first sampled local `ProseSection`, bootstraps/remembers the selected project baseline sequence, then pushes a simulated remote `ProseSection` upsert using the same section id and project id.
2. Run `Preview Pending Apply`; expected summary includes `ProseSection:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch prose section.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one story record in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `ProseSection:updateExisting` remains scratch-only. The materializer seeds one bounded local prose section copy into `cloudflare-sync-poc-pending-apply.sqlite` and does not mutate the production SwiftData store.

Verified 2026-07-06: the existing prose section update sequence selected ProseSection `Section 1` in project `Final Test`, pushed simulated upsert sequence 1 after baseline 0, and previewed `ProseSection:upsert->updateExisting@1(local-exists,payload,deps-ok)`. Materialization created one scratch prose section and reported `1 updated existing records (1 seeded)` in `cloudflare-sync-poc-pending-apply.sqlite`; scratch inspection reported one project, one folder, and one prose section with CloudKit disabled. The cursor was not advanced, and production local data was not read or changed.

Existing story scene update diagnostic sequence:

1. Run `Run Existing Story Scene Update Probe`; it selects the first sampled local `StoryScene`, bootstraps/remembers the selected project baseline sequence, then pushes a simulated remote `StoryScene` upsert using the same scene id and project id.
2. Run `Preview Pending Apply`; expected summary includes `StoryScene:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch story scene.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one story record in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `StoryScene:updateExisting` remains scratch-only. Scenes created through the normal Add Scene flow receive a linked `TextFile` immediately, even if the user has not opened the scene for editing. The materializer seeds the linked scratch `TextFile` when present, then updates the scratch `StoryScene`; it does not mutate the production SwiftData store.

Verified 2026-07-06: the existing story scene update sequence selected StoryScene `Dummy` in project `Test`, pushed simulated upsert sequence 1 after baseline 0, and previewed `StoryScene:upsert->updateExisting@1(local-exists,payload,deps-ok)`. Materialization created one scratch story scene plus its linked scratch text file and folder dependency, reporting `1 updated existing records (2 seeded)` in `cloudflare-sync-poc-pending-apply.sqlite`; scratch inspection reported one project, two folders, one text file, and one scene with CloudKit disabled. The cursor was not advanced, and production local data was not read or changed.

Observed 2026-07-06: a newly created Drama scene that had not been opened for editing was visible in the app but the probe failed closed with `No project content is available for the Cloudflare sync POC.` The first fix handled potentially stale `project.scenes` by using a fresh `ModelContext(modelContext.container)` fetch of `StoryScene` rows by `project.id`, but the Add Scene flow also creates and links a `TextFile` immediately. The probe no longer filters out scenes with linked text files, and the materializer now seeds the linked scratch text file before updating the scratch scene.

Existing character update diagnostic sequence:

1. Run `Run Existing Character Update Probe`; it selects the first sampled local `Character`, bootstraps/remembers the selected project baseline sequence, then pushes a simulated remote `Character` upsert using the same character id and project id.
2. Run `Preview Pending Apply`; expected summary includes `Character:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch character.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one story record/character in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `Character:updateExisting` remains scratch-only. The materializer seeds one bounded local character copy into `cloudflare-sync-poc-pending-apply.sqlite`, updates scalar character fields only, and does not mutate the production SwiftData store. Custom attributes and scene/plot links remain covered by their dependency probes.

Verified 2026-07-06: the existing character update sequence selected Character `Herald` in project `A Play for Today`, pushed simulated upsert sequence 2 after baseline 1, and previewed `Character:upsert->updateExisting@2(local-exists,payload,deps-ok)`. Materialization created one scratch character/story record, reporting `1 updated existing records (1 seeded)` in `cloudflare-sync-poc-pending-apply.sqlite`; scratch inspection reported one project, one folder, and one character with CloudKit disabled. The cursor was not advanced, and production local data was not read or changed.

Existing location update diagnostic sequence:

1. Run `Run Existing Location Update Probe`; it selects the first sampled local `Location`, bootstraps/remembers the selected project baseline sequence, then pushes a simulated remote `Location` upsert using the same location id and project id.
2. Run `Preview Pending Apply`; expected summary includes `Location:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch location.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one story record/location in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `Location:updateExisting` remains scratch-only. The materializer seeds one bounded local location copy into `cloudflare-sync-poc-pending-apply.sqlite`, updates scalar location fields only, and does not mutate the production SwiftData store. Custom attributes and scene/plot links remain covered by their dependency probes.

Verified 2026-07-06: the existing location update sequence selected Location `The Ancient Grove` in project `A Play for Today`, pushed simulated upsert sequence 3 after baseline 2, and previewed `Location:upsert->updateExisting@3(local-exists,payload,deps-ok)`. Materialization created one scratch location/story record, reporting `1 updated existing records (1 seeded)` in `cloudflare-sync-poc-pending-apply.sqlite`; scratch inspection reported one project, one folder, and one location with CloudKit disabled. The cursor was not advanced, and production local data was not read or changed.

Existing plot element update diagnostic sequence:

1. Run `Run Existing Plot Element Update Probe`; it selects the first sampled local `PlotElement`, bootstraps/remembers the selected project baseline sequence, then pushes a simulated remote `PlotElement` upsert using the same plot element id and project id.
2. Run `Preview Pending Apply`; expected summary includes `PlotElement:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with one seeded scratch plot element.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one story record/plot element in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: `PlotElement:updateExisting` remains scratch-only. The materializer seeds one bounded local plot element copy into `cloudflare-sync-poc-pending-apply.sqlite`, updates scalar plot element fields only, and does not mutate the production SwiftData store. Scene, character, and location links remain covered by their dependency probes.

Verified 2026-07-06: the existing plot element update sequence selected PlotElement `Ordinary World` in project `The Republic of Heaven`, pushed simulated upsert sequence 1449 after baseline 1448, and previewed `PlotElement:upsert->updateExisting@1449(local-exists,payload,deps-ok)`. Materialization created one scratch plot element/story record, reporting `1 updated existing records (1 seeded)` in `cloudflare-sync-poc-pending-apply.sqlite`; scratch inspection reported one project, one folder, and one plot element with CloudKit disabled. The cursor was not advanced, and production local data was not read or changed.

Existing ordered text-file link update diagnostic sequence:

1. Run `Run Existing Ordered Text File Link Update Probe`; it selects the first sampled local `TextFileSectionLink` or `TextFileCollectionLink`, bootstraps/remembers the selected project baseline sequence, then pushes a simulated remote upsert using the same link id and incremented `userOrder`.
2. Run `Preview Pending Apply`; expected summary includes either `TextFileSectionLink:upsert->updateExisting` or `TextFileCollectionLink:upsert->updateExisting` with `local-exists`, `payload`, and `deps-ok`.
3. Run `Materialize Pending Apply Preview`; expected result is one updated existing record, with seeded scratch copies of the text file, section/collection, and ordered link.
4. Run `Inspect Pending Apply Scratch Store`; expected result includes one text-file-section or text-file-collection link linked to both sides in the CloudKit-disabled scratch store. Production local data must not be read or changed.
5. Run `Pull Pending Changes`; it should pull one operation and advance the remembered sequence.
6. Run `Check Remote Changes`; it should report the selected project as up to date.

Implementation note: ordered text-file link `updateExisting` remains scratch-only. The materializer seeds bounded local parent records and the ordered link into `cloudflare-sync-poc-pending-apply.sqlite`, updates `userOrder` only, and does not mutate the production SwiftData store.

Verified 2026-07-06: the existing ordered text-file link update sequence selected `TextFileCollectionLink` in project `NaPoWriMo 2026`, pushed simulated upsert sequence 1 after baseline 0, and previewed `TextFileCollectionLink:upsert->updateExisting@1(local-exists,payload,deps-ok)`. Materialization created one scratch folder, one text file, one poetry collection/story record, and one linked `TextFileCollectionLink`, reporting `1 updated existing records (3 seeded)` in `cloudflare-sync-poc-pending-apply.sqlite`; scratch inspection reported one text-file-collection link linked to both sides with CloudKit disabled. The cursor was not advanced, and production local data was not read or changed.

Observed 2026-07-06: the current Character/Location detail UI does not expose a user-facing custom attribute editor. Editing Character Details updates scalar fields on the `Character` record (`history`, `looks`, `traits`, or `work`) and is covered by `Character:updateExisting`; editing Location Details updates scalar fields on the `Location` record (`detail`, `sights`, `sounds`, or `smells`) and is covered by `Location:updateExisting`. `CustomAttribute` appears to be legacy/internal model surface from the original smart-fiction design. `CustomAttribute:createMissing` remains covered by the dependency probe, but `CustomAttribute:updateExisting` manual diagnostics were removed as dataset-blocked and not currently user-facing.

If the remembered cursor is already current, `Materialize Pending Apply Preview` reports an informational no-op: there are no pending apply operations, the cursor is not advanced, and production local data is not changed. This commonly happens after `Pull Pending Changes` has already cleared the pending operation page.

`Materialize Pending Apply Preview` clears the pending-apply scratch store before attempting a materialization. If readiness or action support checks fail, a later scratch inspection cannot accidentally show records from an older successful probe.

Verified 2026-07-05: after the remembered cursor had already advanced to sequence 1440, `Materialize Pending Apply Preview` reported no pending operations, cleared the pending-apply scratch store, and `Inspect Pending Apply Scratch Store` reported that no scratch store was available instead of showing stale records from the previous restore probe.

Dry-run apply plan output includes a small sample of final actions in the form `EntityType:remoteAction->localAction@sequence(local-exists/local-missing,payload/no-payload,dependency-status)`. `payload` means the operation includes a non-empty payload value dictionary. This is diagnostic only; no local SwiftData mutation is performed.

Dry-run apply readiness is reported as:

- `ready for dry-run applier` when there are no ignored final actions, missing dependencies, or payload blockers
- `blocked` when any final action is ignored/unsupported, any required dependency is missing, or an upsert/restore-create operation has no payload

Dry-run apply order is reported as a compact sample of the future execution order. Upserts and restores are listed before deletes; parent-like entities such as projects, folders, stylesheets, text files, story records, publications, and submissions are ordered before child records such as versions, annotations, submitted files, and join links.

Initial proposed local action mapping:

- remote `upsert` + local exists -> local `updateExisting`
- remote `upsert` + local missing -> local `createMissing`
- remote `delete`/`trash`/`tombstone` + local exists -> local `markDeleted`
- remote `delete`/`trash`/`tombstone` + local missing -> local `deleteNoopMissing`
- remote `restore`/`untrash` + local exists -> local `restoreExisting`
- remote `restore`/`untrash` + local missing -> local `restoreMissing`
- unsupported final action -> local `ignoreUnsupported`

Local existence is resolved from the same bounded project graph used by the POC exporter rather than by performing a broad database scan.

Dependency status is also computed in dry-run mode:

- `deps-ok`: required parent/link targets are locally present or included in the pending plan
- `missing-deps:<type>`: at least one required parent/link target is missing from both local state and the pending plan
- `deps-not-required`: final action does not require parent/link dependency validation

Dependency checks currently cover common parent/link fields such as text-file folder, version text file, annotations version, styles stylesheet, join-link endpoints, glossary citation, index parent, submission publication, and submitted-file references.

## Phase 5 Scratch Pull Bridge

The debug-only `Pull Pending Changes Into Scratch Store` command combines the previously separate dry-run steps into one end-to-end bridge toward a future production pull loop:

1. Select the same pending-apply project used by preview/materialization.
2. Bootstrap the device and read the remembered local sequence.
3. Use `/peek` to read pending operations without advancing the cursor.
4. Build and validate the same dry-run apply plan used by `Preview Pending Apply` and `Materialize Pending Apply Preview`.
5. Materialize the supported plan into `cloudflare-sync-poc-pending-apply.sqlite` with CloudKit disabled.
6. Use `/pull` only after scratch materialization succeeds, then verify the pulled operation window matches the peeked/materialized operation window before advancing the remembered local cursor.

If the plan is blocked, unsupported, missing payloads, or the operation window changes between peek and pull, the command fails closed and does not advance the remembered cursor. Production local SwiftData data is still not mutated.

Verified 2026-07-07: after `Run Satisfied Dependency Probe` on `Poems 2026`, `Pull Pending Changes Into Scratch Store` processed TextFile upsert sequence 53 and Version upsert sequence 54 after baseline 52, materialized one text file and one version in `cloudflare-sync-poc-pending-apply.sqlite`, and advanced the remembered sequence to 54 only after the scratch apply succeeded. The plan preview was `TextFile:upsert->createMissing@53(local-missing,payload,deps-ok), Version:upsert->createMissing@54(local-missing,payload,deps-ok)`, with readiness ready for dry-run applier. Scratch inspection reported one project, one folder, one text file, one version, one version linked to a text file, and one text file with versions. `Check Remote Changes` then reported latest sequence 54, local remembered 54, change count 0. Production local data was not read or changed.

Verified 2026-07-07: after `Run Existing Text File Delete Guardrail Probe` on `Poems 2026`, the bridge command failed closed before cursor advancement with the scratch materializer supported-action message. A follow-up `Preview Pending Apply` still read after sequence 54 and showed the same pending delete sequence 55 as `TextFile:delete->markDeleted@55(local-exists,payload,deps-not-required)`. Production local data was not changed.

Verified 2026-07-07: after `Run Existing Text File Restore Guardrail Probe` on `Poems 2026`, the probe pushed restore sequence 56 after baseline 55. The bridge command failed closed before cursor advancement with the scratch materializer supported-action message. A follow-up `Preview Pending Apply` still read after sequence 55 and showed the same pending restore sequence 56 as `TextFile:restore->restoreExisting@56(local-exists,payload,deps-not-required)`. Production local data was not changed.

The debug-only `Check And Pull Into Scratch Store` command adds the production-loop gate in front of the scratch pull bridge. It calls `/head` using the remembered local sequence. If the remote head is up to date, it returns a no-op result without clearing or changing the scratch store. If changes are available, it delegates to `Pull Pending Changes Into Scratch Store`, so cursor advancement still happens only after scratch materialization succeeds and the pulled operation window matches the peeked/materialized operation window.

Verified 2026-07-07: after the previous pending restore remained visible at sequence 56, `Run Satisfied Dependency Probe` bootstrapped from baseline 56 and pushed TextFile upsert sequence 57 plus Version upsert sequence 58. `Check And Pull Into Scratch Store` reported that `/head` had 2 pending changes at latest sequence 58, materialized one text file and one version into `cloudflare-sync-poc-pending-apply.sqlite`, and advanced the remembered sequence to 58 only after scratch apply succeeded. The plan sample was `TextFile:upsert->createMissing@57(local-missing,payload,deps-ok), Version:upsert->createMissing@58(local-missing,payload,deps-ok)`. Production local data was not changed.

Verified 2026-07-07: with `Poems 2026` already remembered at sequence 58, `Check And Pull Into Scratch Store` returned the head no-op path: latest sequence 58, local remembered 58, server cursor 58, change count 0. The scratch store was not changed, the cursor was not changed, and production local data was not changed.

The debug-only `Sync Now Dry Run` command is the production-shaped manual entry point for the POC. It delegates to `Check And Pull Into Scratch Store` and reports the same result with Sync Now wording. This keeps one implementation path for head gating, scratch materialization, operation-window validation, and cursor advancement while exposing the shape of the eventual user/manual sync action.

Verified 2026-07-07: with `Poems 2026` already remembered at sequence 58, `Sync Now Dry Run` returned the no-op path: latest sequence 58, local remembered 58, server cursor 58, change count 0. The scratch store was not changed, the cursor was not changed, and production local data was not changed.

Verified 2026-07-07: after `Run Satisfied Dependency Probe` pushed TextFile upsert sequence 59 and Version upsert sequence 60 after baseline 58, `Sync Now Dry Run` reported that `/head` had 2 pending changes at latest sequence 60, materialized one text file and one version into `cloudflare-sync-poc-pending-apply.sqlite`, and advanced the remembered sequence to 60 only after scratch apply succeeded. The plan sample was `TextFile:upsert->createMissing@59(local-missing,payload,deps-ok), Version:upsert->createMissing@60(local-missing,payload,deps-ok)`. Production local data was not changed.

The debug-only `Show Sync State Summary` command reports the selected pending-apply project id/name, remembered local sequence, `/head` latest sequence, server cursor, pending change count, last pushed sequence, Worker version, and whether the pending-apply scratch SQLite exists. It does not materialize, pull, advance the cursor, clear scratch data, or mutate production local data.

Verified 2026-07-07: with `Poems 2026` already remembered at sequence 60, `Show Sync State Summary` reported project `A7E9E22C-032F-4628-BDB1-53E1FFBFE010` as up to date: remembered sequence 60, remote latest 60, server cursor 60, change count 0, last pushed 0, and scratch store present at `cloudflare-sync-poc-pending-apply.sqlite`. Production local data was not changed.

Observed 2026-07-07: after `Run Satisfied Dependency Probe` pushed TextFile upsert sequence 61 and Version upsert sequence 62 after baseline 60, a later `Show Sync State Summary` reported remembered sequence 62, remote latest 62, and change count 0. This means the intended pending-state summary window had already been consumed before the standalone summary ran, so it did not verify the pending state.

The debug-only `Run Satisfied Dependency State Summary Probe` command removes that manual timing gap. It pushes the same synthetic TextFile/Version satisfied-dependency batch, remembers only the baseline sequence, then immediately reports `/head` state plus scratch-store presence without pulling, materializing, clearing scratch, or advancing the cursor past the baseline.

Verified 2026-07-07: `Run Satisfied Dependency State Summary Probe` on `Poems 2026` pushed TextFile sequence 63 and Version sequence 64 after baseline 62. The immediate state summary reported remembered sequence 62, remote latest 64, server cursor 62, change count 2, and scratch store present at `cloudflare-sync-poc-pending-apply.sqlite`. The cursor was not advanced beyond the baseline, the scratch store was not changed, and production local data was not changed.

Verified 2026-07-07: running `Sync Now Dry Run` after that pending-state summary consumed the same sequence 63-64 batch. It reported `/head` had 2 pending changes at latest sequence 64, materialized one text file and one version into `cloudflare-sync-poc-pending-apply.sqlite`, and advanced the remembered sequence from 62 to 64 only after scratch apply succeeded. The plan sample was `TextFile:upsert->createMissing@63(local-missing,payload,deps-ok), Version:upsert->createMissing@64(local-missing,payload,deps-ok)`. Production local data was not changed.

The debug-only triggered dry-run wrapper routes manual and foreground-style sync attempts through the same head-gated scratch bridge. `Sync Now Dry Run` is now the `manual` trigger, and `Foreground Trigger Dry Run` is the `foreground` trigger. Both keep production local data untouched and share the same cursor advancement rule: remembered sequence advances only after scratch materialization succeeds and the pulled operation window matches the peeked/materialized window.

Verified 2026-07-07: with `Poems 2026` already remembered at sequence 64, `Foreground Trigger Dry Run` returned the trigger-labeled no-op path: latest sequence 64, local remembered 64, server cursor 64, change count 0. The scratch store was not changed, the cursor was not changed, and production local data was not changed.

Verified 2026-07-07: after `Run Satisfied Dependency State Summary Probe` pushed TextFile sequence 65 and Version sequence 66 after baseline 64, `Foreground Trigger Dry Run` consumed the same pending batch. It reported `/head` had 2 pending changes at latest sequence 66, materialized one text file and one version into `cloudflare-sync-poc-pending-apply.sqlite`, and advanced the remembered sequence from 64 to 66 only after scratch apply succeeded. The plan sample was `TextFile:upsert->createMissing@65(local-missing,payload,deps-ok), Version:upsert->createMissing@66(local-missing,payload,deps-ok)`. Production local data was not changed.

The same debug-only triggered dry-run wrapper now exposes `Launch Trigger Dry Run` and `Background Refresh Trigger Dry Run`. These are still manual diagnostics rather than real lifecycle hooks, but they exercise the production trigger labels through the same head-gated scratch bridge and cursor advancement rules.

Verified 2026-07-07: with `Poems 2026` already remembered at sequence 66, `Launch Trigger Dry Run` returned the trigger-labeled no-op path: latest sequence 66, local remembered 66, server cursor 66, change count 0. The scratch store was not changed, the cursor was not changed, and production local data was not changed.

Verified 2026-07-07: after `Run Satisfied Dependency State Summary Probe` pushed TextFile sequence 67 and Version sequence 68 after baseline 66, `Launch Trigger Dry Run` consumed the same pending batch. It reported `/head` had 2 pending changes at latest sequence 68, materialized one text file and one version into `cloudflare-sync-poc-pending-apply.sqlite`, and advanced the remembered sequence from 66 to 68 only after scratch apply succeeded. The plan sample was `TextFile:upsert->createMissing@67(local-missing,payload,deps-ok), Version:upsert->createMissing@68(local-missing,payload,deps-ok)`. Production local data was not changed.

Verified 2026-07-07: with `Poems 2026` already remembered at sequence 68, `Background Refresh Trigger Dry Run` returned the trigger-labeled no-op path: latest sequence 68, local remembered 68, server cursor 68, change count 0. The scratch store was not changed, the cursor was not changed, and production local data was not changed.

Verified 2026-07-07: after `Run Satisfied Dependency State Summary Probe` pushed TextFile sequence 69 and Version sequence 70 after baseline 68, `Background Refresh Trigger Dry Run` consumed the same pending batch. It reported `/head` had 2 pending changes at latest sequence 70, materialized one text file and one version into `cloudflare-sync-poc-pending-apply.sqlite`, and advanced the remembered sequence from 68 to 70 only after scratch apply succeeded. The plan sample was `TextFile:upsert->createMissing@69(local-missing,payload,deps-ok), Version:upsert->createMissing@70(local-missing,payload,deps-ok)`. Production local data was not changed.

The debug-only trigger status layer records the last trigger dry run in memory for the current app session: trigger name, success/failure outcome, timestamp, and a short detail string. `Show Trigger Status` reports that state without contacting the Worker, touching the scratch store, advancing a cursor, or reading/writing production local data. Trigger status is diagnostic-only and is intentionally not durable yet.

Verified 2026-07-07: before any trigger dry run had been recorded in the app session, `Show Trigger Status` reported that no Cloudflare sync POC trigger dry run had been recorded in this app session.

Verified 2026-07-07: after `Foreground Trigger Dry Run` completed the no-op path at sequence 70, `Show Trigger Status` reported trigger `foreground`, outcome `success`, recorded timestamp `2026-07-07T09:58:14Z`, and the same up-to-date detail from the trigger dry run: latest sequence 70, local remembered 70, server cursor 70, change count 0, and no scratch or production local data changes.

Verified 2026-07-07: after `Run Existing Text File Delete Guardrail Probe` simulated TextFile `Endnotes` delete sequence 71 after baseline 70, `Sync Now Dry Run` failed closed with the apply-plan-not-ready message because existing-local `markDeleted` is unsupported by the scratch materializer. `Show Trigger Status` then reported trigger `manual`, outcome `failure`, recorded timestamp `2026-07-07T10:01:14Z`, and the same apply-plan-not-ready detail. This confirms failure outcomes are recorded without applying the unsupported operation or advancing the cursor.

Verified 2026-07-07: `Lifecycle Sequence Dry Run` runs the production-shaped wakeup order `launch`, `foreground`, then `background-refresh` through the same scratch-only trigger wrapper and stops on the first failure. With the unsupported existing-local TextFile delete still pending at sequence 71, the lifecycle sequence stopped on `launch` and failed closed with the same `apply-plan-not-ready` detail as the manual dry run. `Show Trigger Status` reported trigger `launch`, outcome `failure`, recorded timestamp `2026-07-07T10:13:51Z`, and the same detail. The cursor was not advanced and production local data was not changed.

Verified 2026-07-07: after `Run Satisfied Dependency State Summary Probe` re-baselined at sequence 73 and pushed TextFile sequence 74 plus Version sequence 75, `Lifecycle Sequence Dry Run` consumed the pending batch on `launch`. It materialized one text file and one version into `cloudflare-sync-poc-pending-apply.sqlite`, advanced remembered/server cursor to sequence 75 only after scratch apply succeeded, then `foreground` and `background-refresh` reported up-to-date no-op results at sequence 75. `Show Trigger Status` reported the final trigger `background-refresh`, outcome `success`, recorded timestamp `2026-07-07T10:17:51Z`, and the up-to-date detail. Production local data was not changed.

## Production Direction

The production sync loop should use layered wakeups:

- local edits enqueue outbound operations and push to the Worker
- the Worker stores operations with canonical sequence numbers
- future silent pushes wake other registered devices when possible
- launch, foreground resume, background refresh, network recovery, and manual Sync Now call the head endpoint
- only when `hasChanges` is true does the app perform a full pull

Missed silent pushes are harmless because the Worker operation log remains authoritative and the device cursor determines what still needs to be pulled.

## Next Design Slice: Lifecycle Orchestrator

The next production-shaped slice should introduce a single lifecycle orchestrator around the already-verified head-gated flow. This slice should still be debug-only and scratch-only: it may wire real app lifecycle events to the dry-run bridge, but it must not write pulled records into the production SwiftData store.

Orchestrator responsibilities:

- expose one entry point, for example `requestSync(trigger:)`, for launch, foreground resume, background refresh, network recovery, silent push, and manual Sync Now
- serialize work with a single-flight guard so overlapping lifecycle events cannot run concurrent pulls for the same project/device cursor
- debounce noisy triggers, especially foreground/network recovery, while allowing manual Sync Now to request an immediate run when no sync is active
- call `/head` first and exit cheaply when `hasChanges == false`
- call pull/materialization only when `/head` reports pending changes
- advance the local remembered cursor only after the intended operation window has been pulled and scratch-applied successfully
- preserve the fail-closed behavior: unsupported actions, dependency blockers, missing payloads, and existing-local destructive/restorative operations must leave the cursor unchanged
- record last trigger status in a small diagnostic state object so Sync Diagnostics can show trigger, outcome, timestamp, latest sequence, cursor, change count, and failure reason

Initial trigger policy:

- `launch`: run once after the model container is available and the debug token/project selection are available
- `foreground`: run when returning active, but debounce short background/foreground churn
- `background-refresh`: run only through the system background task path and keep the existing head-first cheap exit
- `manual`: run from Sync Diagnostics and bypass debounce if no other orchestrator run is active
- `silent-push`: design only for now; the Worker can later send a wake signal, but correctness must not depend on delivery
- `network-recovery`: design only for now; run after connectivity returns if the previous attempt failed for transport reasons

Non-goals for this slice:

- no production SwiftData remote applier
- no CloudKit migration/removal
- no automatic local edit capture beyond the existing POC probes
- no durable background scheduler beyond documenting the entry points and proving the debug lifecycle wrapper can call them safely

Acceptance checks:

- already-caught-up lifecycle events perform `/head` and exit without changing scratch or production data
- a ready pending operation window is scratch-applied exactly once and advances the remembered cursor once
- foreground/background-refresh after that cursor advance are no-ops
- a blocked pending operation records failure and leaves the remembered cursor unchanged
- trigger status reports the last attempted trigger and outcome without contacting the Worker

Implemented 2026-07-07: the existing debug trigger methods now route through a single `requestSyncDryRun(projects:trigger:bypassDebounce:)` service-level orchestrator. The wrapper provides a single-flight guard, records skipped in-flight attempts in trigger status, debounces noisy foreground-style triggers, keeps manual Sync Now immediate when no run is active, and preserves the same head-gated scratch apply/cursor advancement behavior. This still does not wire automatic lifecycle events or write pulled data into the production SwiftData store.

Verified 2026-07-07: in a fresh app session, `Show Trigger Status` reported no recorded trigger dry run. A rapid `Foreground Trigger Dry Run` repeat was skipped by lifecycle orchestrator debounce with 28 seconds remaining and did not change the scratch store or production local data. `Sync Now Dry Run` still ran immediately through the orchestrator and reported the no-op path at sequence 75. `Lifecycle Sequence Dry Run` then ran `launch`, `foreground`, and `background-refresh` through the orchestrator; all three reported up-to-date at sequence 75, with scratch and production local data unchanged.

Verified 2026-07-07: `Run Single-Flight Guard Probe` starts one manual orchestrator dry run with a short diagnostic-only delay, then immediately attempts a foreground trigger. The first trigger completed normally through the orchestrator. The second trigger was rejected by the single-flight guard. Remote head remained up to date at sequence 75, the scratch store was not changed, and production local data was not changed. If the second trigger runs instead of being skipped, the probe fails rather than reporting success.

Verified 2026-07-07: successful orchestrator trigger runs now store structured head metadata in trigger status: latest sequence, cursor sequence, change count, last pushed sequence, and Worker version. After a manual no-op trigger at sequence 75, `Show Trigger Status` displayed trigger `manual`, outcome `success`, latest sequence 75, cursor 75, change count 0, last pushed 73, and Worker version `2026-07-04-phase-4b` before the original detail string. Skipped and failed attempts still record trigger/outcome/timestamp/detail without sequence fields when no `/head` response is available.

Verified 2026-07-07: `Network Recovery Trigger Dry Run` and `Silent Push Trigger Dry Run` exercise the remaining production-shaped trigger labels through the same debug-only orchestrator. Both triggers completed the no-op path at sequence 75, reported structured trigger status with latest/cursor 75, change count 0, last pushed 73, and Worker version `2026-07-04-phase-4b`, and left scratch and production local data unchanged. These buttons do not register real network observers, remote-notification handlers, background tasks, or production appliers; they only prove that the labels route through the head-gated scratch-only path and structured trigger status.

Verified 2026-07-07: `Show Orchestrator Policy` reports the debug orchestrator configuration without contacting the Worker. It reported status `idle`, supported triggers `[manual, launch, foreground, background-refresh, network-recovery, silent-push]`, debounced triggers `[foreground, network-recovery]` at 30 seconds, manual debounce bypass when idle, and the explicit guarantees that automatic lifecycle wiring and production SwiftData apply are disabled while scratch-only head-gated dry runs remain the active path.

Verified 2026-07-07: `Show Local Cursor Summary` reports the selected project's local POC cursor state without contacting the Worker. For `Poems 2026` (`A7E9E22C-032F-4628-BDB1-53E1FFBFE010`), it reported remembered sequence 75, pending apply project `A7E9E22C-032F-4628-BDB1-53E1FFBFE010`, and scratch store present at `cloudflare-sync-poc-pending-apply.sqlite`. It did not contact the Worker and did not read or write production local data.

Verified 2026-07-07: `Show Debounce State` reports the in-memory lifecycle orchestrator debounce state without contacting the Worker. In a fresh idle state it reported status `idle`, interval 30 seconds, `foreground` ready with no run recorded, `network-recovery` ready with no run recorded, and the reminder that `manual`, `launch`, `background-refresh`, and `silent-push` are not debounced. It did not contact the Worker and did not read or write production local data.

Verified 2026-07-07: transport failures are classified separately in trigger status. `Run Transport Failure Classification Probe` recorded trigger `network-recovery` with outcome `transport-failure` and the synthetic `NSURLErrorDomain` `-1009` detail without contacting the Worker and without reading or writing scratch or production local data. `Show Trigger Status` then reported trigger `network-recovery`, outcome `transport-failure`, recorded timestamp `2026-07-07T11:55:00Z`, and the same synthetic transport failure detail. Real orchestrator failures caused by `URLError` now record outcome `transport-failure`; other thrown errors continue to record outcome `failure`.

Verified 2026-07-07: `Show Network Recovery Eligibility` reports whether a network-recovery wakeup is currently eligible based on in-memory orchestrator state: last trigger outcome must be `transport-failure`, no dry run can be in flight, and the `network-recovery` debounce window must be clear. In a fresh app session with no remembered trigger status, it reported `not eligible` because last trigger outcome was `none`, not `transport-failure`; last trigger `none`, last outcome `none`. It did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-07: `Run Network Recovery Eligibility Probe` records a synthetic `network-recovery` transport failure in trigger status, then immediately evaluates `Show Network Recovery Eligibility` so the positive `eligible` path can be verified without a real network outage. It reported `eligible` because the last trigger outcome was `transport-failure`; last trigger `network-recovery`, last outcome `transport-failure`. It did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-07: `Run Network Recovery Debounce Eligibility Probe` records a synthetic `network-recovery` transport failure and an immediate in-memory `network-recovery` trigger timestamp, then evaluates eligibility so the debounce-blocked `not eligible` path can be verified. It reported `not eligible` because `network-recovery` was debounced for 30 seconds more; last trigger `network-recovery`, last outcome `transport-failure`. It did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-07: `Network Recovery If Eligible Dry Run` gates the network-recovery trigger through the in-memory eligibility state. In the skip path, with no remembered trigger status in the app session, it reported `not eligible` because last trigger outcome was `none`, not `transport-failure`; last trigger `none`, last outcome `none`. It skipped without contacting the Worker and without reading or writing scratch or production local data. In the eligible path, after `Run Network Recovery Eligibility Probe` recorded synthetic `network-recovery`/`transport-failure`, the gated dry run ran through the scratch-only orchestrator and completed the normal no-op head-gated result at sequence 75: local remembered 75, server cursor 75, last pushed 73, change count 0, Worker version `2026-07-04-phase-4b`. Scratch store and production local data were unchanged.

Verified 2026-07-07: `Run Silent Push Payload Guardrail Probe` simulates receiving a silent-push wake payload for a mismatched project id and verifies the local debug path ignores it. For selected project `Poems 2026` (`A7E9E22C-032F-4628-BDB1-53E1FFBFE010`), it ignored synthetic mismatched project `44634657-3BA5-43DA-B3E5-CCAA1F2375B5`, left remembered sequence at 75, did not contact the Worker, did not trust any payload sequence, and did not read or write scratch or production local data. Silent pushes remain wake signals only; correctness still comes from the head endpoint and the local cursor.

Verified 2026-07-07: `Silent Push Matching Payload Dry Run` simulates receiving a silent-push wake payload for the selected project id, ignores the synthetic payload sequence, and routes through the existing scratch-only `silent-push` orchestrator using the local remembered cursor and `/head`. For `Poems 2026` (`A7E9E22C-032F-4628-BDB1-53E1FFBFE010`), it ignored synthetic payload sequence 76 and used local remembered sequence 75. The head-gated `silent-push` dry run reported up to date at latest/local/server cursor sequence 75, last pushed 73, change count 0, Worker version `2026-07-04-phase-4b`; scratch store and production local data were unchanged. A matching payload is only a wake signal; it must not directly advance a cursor or apply production local data.

Verified 2026-07-07: `Run Background Refresh Expired Budget Probe` simulates a background refresh wake where no useful execution budget remains. It records trigger `background-refresh` with outcome `skipped` and exits before starting the orchestrator, contacting the Worker, or reading/writing scratch or production local data. `Show Trigger Status` confirmed trigger `background-refresh`, outcome `skipped`, recorded `2026-07-07T12:36:23Z`, with no Worker, scratch, or production local data access.

Verified 2026-07-07: `Show Background Refresh Policy` reports that `background-refresh` is supported and not debounced, but production use must enter only through the system background task path. The POC does not register or schedule a durable background task; the diagnostics button is manual only. Background refresh remains head-first with a cheap up-to-date exit, scratch-only materialization, no production SwiftData apply, and no Worker contact for the policy summary.

Verified 2026-07-07: `Run Foreground Debounce Skip Probe` records an immediate in-memory `foreground` trigger timestamp, then requests a foreground sync through the orchestrator. It skipped by lifecycle orchestrator debounce with 30 seconds remaining before `/head`, Worker contact, scratch changes, cursor advancement, or production local data access. `Show Trigger Status` confirmed trigger `foreground`, outcome `skipped`, recorded `2026-07-07T12:44:30Z`, and the same debounce detail.

Verified 2026-07-07: `Run Network Recovery In-Flight Eligibility Probe` records a synthetic `network-recovery` transport failure, temporarily marks the orchestrator in flight, then evaluates network recovery eligibility. It reported `not eligible` because another orchestrator dry run was in flight; last trigger `network-recovery`, last outcome `transport-failure`. It did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-07: `Show Launch Policy` reports that `launch` is supported and not debounced, and that production use should run once after the model container, debug token, and project selection are available. The POC does not wire automatic launch sync; the diagnostics button is manual only. Launch remains head-first with a cheap up-to-date exit, scratch-only materialization, no production SwiftData apply, and no Worker contact for the policy summary.

Verified 2026-07-07: `Show Foreground Policy` reports that `foreground` is supported and debounced for 30 seconds to avoid short background/foreground churn, and that production use should run when the app returns active after required sync credentials and project context are available. The POC does not wire automatic foreground sync; the diagnostics button is manual only. Foreground remains head-first with a cheap up-to-date exit, scratch-only materialization, no production SwiftData apply, and no Worker contact for the policy summary.

Verified 2026-07-07: `Show Network Recovery Policy` reports that `network-recovery` is supported and debounced for 30 seconds, and that production use should run after connectivity returns only when the previous sync attempt failed for a transport reason, no orchestrator run is in flight, and the debounce window is clear. The POC does not wire automatic network reachability observers; the diagnostics buttons are manual only. Network recovery remains head-first with a cheap up-to-date exit, scratch-only materialization, no production SwiftData apply, and no Worker contact for the policy summary.

Verified 2026-07-07: `Show Silent Push Policy` reports that `silent-push` is supported and not debounced, and that production use should treat push payloads as wake signals only. Payload project ids may select a target, but payload sequences must not advance cursors or authorize local apply; correctness comes from the local remembered cursor and the Worker `/head` response. The POC does not wire a remote-notification handler; the diagnostics buttons are manual only. Silent push remains head-first with a cheap up-to-date exit, scratch-only materialization, no production SwiftData apply, and no Worker contact for the policy summary.

Verified 2026-07-07: `Show Manual Sync Policy` reports that `manual` is supported and bypasses debounce when no orchestrator run is in flight. Manual Sync Now must still respect the single-flight guard and must not run concurrently with another lifecycle dry run. Manual sync remains head-first with a cheap up-to-date exit, scratch-only materialization, no production SwiftData apply, and no Worker contact for the policy summary.

Verified 2026-07-07: `Show Production Apply Readiness` reports that production SwiftData apply is disabled, scratch materialization remains the only remote apply path, and cursor advancement is proven only after scratch apply succeeds. It also records the graduation criteria before production apply can be enabled: create, update, delete, restore, dependency ordering, relationship repair, and transaction rollback must be verified across the model families, and CloudKit coexistence or migration must be decided. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-07: `Show Production Apply Operation Coverage` reports that scratch-only planning has exercised create-missing, update-existing, restore-missing, unsupported-operation fail-closed, missing-dependency fail-closed, satisfied-dependency ordering, and existing-local delete/restore guardrails. It also records that production apply is not ready until those same operation classes are verified against real SwiftData transactions across model families, including rollback without cursor advancement on any failure. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-07: `Show Production Apply Transaction Safety` reports that remote operation windows must apply atomically to the production SwiftData store. A production applier must validate the full plan before mutation, apply the whole window in one transaction, save successfully, then advance the local cursor only after commit succeeds. Any validation, dependency, decode, relationship, save, or conflict failure must roll back or leave production data unchanged and leave the cursor unchanged. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-07: `Show Production Apply Model Family Coverage` reports that production apply must be verified across project hierarchy, text content and versions, styles and page setup, annotations and footnotes, publications and submissions, collections and join links, story planning records, reference/index/glossary records, review records, custom attributes, and trash metadata. Each family must prove create, update, delete, restore, dependency ordering, relationship repair, and rollback behavior before production SwiftData apply can be enabled. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-07: `Show Production Apply CloudKit Coexistence` reports that Cloudflare production apply must not be enabled until CloudKit coexistence or migration is explicitly decided. The production plan must define whether Cloudflare and CloudKit can run side by side, whether one sync path is disabled during migration, how duplicate remote changes are prevented, and how recovery works if either backend has newer data. Until that decision is made, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-07: `Show Production Apply Migration Cutover` reports that Cloudflare production apply must not be enabled until the migration plan defines the source of truth, backfill direction, cutover trigger, CloudKit disablement or coexistence behavior, rollback path, and user-visible recovery instructions. The cutover plan must prove that local SwiftData, CloudKit, and Cloudflare cannot each accept independent writes for the same project during migration. Until that plan is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-07: `Show Production Apply Conflict Policy` reports that Cloudflare production apply must not be enabled until conflict detection and resolution are defined for concurrent local, CloudKit, and Cloudflare edits. The production plan must compare local revision state with the incoming operation window before mutation, fail closed on stale or ambiguous ancestry, preserve both sides for user-visible recovery when automatic merge is unsafe, and advance the cursor only after the resolved production transaction commits. Until that policy is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-07: `Show Production Apply Idempotency` reports that Cloudflare production apply must not be enabled until duplicate, retried, and overlapping operation windows are proven safe. A production applier must use stable remote ids and operation sequence bounds to make create, update, delete, and restore operations repeatable without duplicate rows, zombie resurrection, skipped dependencies, or cursor drift. Cursor advancement must remain tied to the committed production transaction, not to receiving or decoding a repeated window. Until idempotency is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-07: `Show Production Apply Audit Trail` reports that Cloudflare production apply must not be enabled until each committed operation window leaves a durable local audit record. The audit record must include project id, previous cursor, committed cursor, operation count, affected model families, conflict or merge outcome, transaction result, and enough error context to support diagnostics without exposing document content. Cursor advancement must be explainable from the audit trail after crash, relaunch, or support export. Until auditability is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-07: `Show Production Apply Rollout Control` reports that Cloudflare production apply must not be enabled without an explicit local feature flag, remote kill switch, and staged rollout plan. The production path must be able to disable SwiftData mutation immediately without disabling read-only head checks, scratch diagnostics, support export, or manual recovery. Rollout state must be visible in diagnostics, default to disabled for unknown builds or unsupported migrations, and fail closed before any production transaction starts. Until rollout control is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-07: `Show Production Apply Compatibility` reports that Cloudflare production apply must not be enabled until app build, local SwiftData schema, remote operation format, and migration version are explicitly compatible. The production path must fail closed before mutation when it sees unknown model families, unsupported operation versions, missing required fields, newer remote schema revisions, or local stores that still require migration. Compatibility state must be visible in diagnostics and must block cursor advancement on mismatch. Until compatibility is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-07: `Show Production Apply Destructive Operations` reports that Cloudflare production apply must not be enabled until delete, trash, restore, and permanent purge semantics are explicitly verified. A production applier must never delete local records just because relationships are missing, must distinguish tombstones from temporary sync gaps, must preserve dependency order for cascades and joins, and must leave recoverable evidence before cursor advancement. Destructive operation failures must roll back or leave production data unchanged. Until destructive safety is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-07: `Show Production Apply Integrity` reports that Cloudflare production apply must not be enabled until incoming operation windows prove identity, ordering, and payload integrity before mutation. A production applier must validate project id, remote record id, operation sequence bounds, dependency references, required checksums or revision tokens, and attachment/blob completeness before any SwiftData transaction starts. Integrity failures must fail closed without cursor advancement and without partial production writes. Until integrity verification is complete, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Apply Recovery Drill` reports that Cloudflare production apply must not be enabled until crash, relaunch, rollback, restore-from-audit, and support-guided recovery drills are verified. The production plan must prove recovery after failure before transaction, during transaction, after save but before cursor advancement, and after cursor advancement with a later detected inconsistency. Recovery must preserve user data, explain the last committed cursor, and provide a manual path that does not require deleting the local store. Until recovery drills pass, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Apply Visible State` reports that Cloudflare production apply must not be enabled until sync mode, authoritative data path, rollout state, last committed cursor, and recovery status are visible in diagnostics and support export. Users and support must be able to distinguish scratch-only POC checks, CloudKit-backed sync, Cloudflare read-only checks, and Cloudflare production mutation without inspecting logs. Any unknown, mixed, or migrating state must fail closed before production SwiftData mutation. Until visible state is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Apply Backpressure` reports that Cloudflare production apply must not be enabled until large operation windows, rate limits, repeated failures, low disk space, and long-running imports can pause safely before mutation. A production applier must bound batch size, preserve the current cursor while paused, expose retry-after and blocked reason in diagnostics, and resume from the same remote window without duplicate writes or cursor drift. Backpressure must never trigger local store deletion or automatic destructive recovery. Until backpressure is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Apply Privacy Redaction` reports that Cloudflare production apply must not be enabled until logs, audit records, diagnostics, and support exports prove they do not expose document content, private notes, manuscript text, or attachment payloads. Production diagnostics must prefer ids, counts, cursors, model-family names, error codes, and redacted summaries, with explicit review before any sample payload or merge conflict detail is surfaced. Privacy failures must fail closed before mutation and before export. Until privacy redaction is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Apply Authorization Scope` reports that Cloudflare production apply must not be enabled until credentials, project ownership, token revocation, and least-privilege access are verified before mutation. A production applier must prove that the current user and device may read the remote window and mutate the target local project, reject cross-project or stale-token operations, handle revoked credentials without cursor advancement, and keep authorization failures visible in diagnostics without exposing secrets. Until authorization scope is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Apply Migration Progress` reports that Cloudflare production apply must not be enabled until first-launch CloudKit-to-Cloudflare migration has a user-visible progress experience. The app must tell the user that existing CloudKit data is being prepared for the new sync system, show bounded progress such as scanning, uploading, verifying, and finishing stages, keep writing disabled or clearly guarded while authority is changing, and provide a safe retry or support path if migration pauses or fails. Progress must be recoverable after relaunch and must not require deleting the local store. Until migration progress is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Apply Migration Preflight` reports that Cloudflare production apply must not be enabled until first-launch CloudKit-to-Cloudflare migration proves prerequisites before upload or local mutation. The migration path must verify CloudKit account availability, local store readability, schema compatibility, sufficient disk and network conditions, remote workspace ownership, feature-flag eligibility, and a durable rollback or resume marker before changing sync authority. Any failed preflight must leave CloudKit as the active sync path, keep the Cloudflare cursor unchanged, and show a recoverable user/support status. Until migration preflight is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Added 2026-07-08: Production Cloudflare sync must provide a means to count the number of users of the system. The backend must record a stable, privacy-safe user or account identity when a user enrolls in Cloudflare sync, along with minimal operational metadata such as creation time, last-seen time, sync eligibility state, and optional device count. User counting must not depend on document records, manuscript text, project names, attachment payloads, or support logs. The count should distinguish total enrolled users from active users, and diagnostics/admin reporting should make this visible without exposing secrets or private writing content.

Verified 2026-07-08: `Show Production User Counting` reports that Cloudflare production sync must not be enabled until the backend records a privacy-safe stable user or account identity when a user enrolls in the sync system. The production plan must distinguish total enrolled users from active users using minimal operational metadata such as creation time, last-seen time, sync eligibility state, and optional device count, without depending on document records, manuscript text, project names, attachment payloads, or support logs. User-count reporting must be available to diagnostics or admin tooling without exposing secrets or private writing content. Until user counting is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production User Lifecycle` reports that Cloudflare production sync must not be enabled until user/account records have explicit lifecycle rules. The production plan must define enrollment, active and inactive status, device association and replacement, token revocation, account deletion or sync opt-out, and how merged or duplicate device identities affect user counts. Lifecycle transitions must preserve auditability, avoid exposing private writing content, and stop future sync access for revoked or deleted users without deleting local data automatically. Until user lifecycle is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Server Schema Readiness` reports that Cloudflare production sync must not begin until the Worker and D1 schema can represent the full production sync contract. The backend schema must cover users, devices, projects, operation logs, cursors, tombstones, attachments or asset references, audit records, rollout state, and migration state with stable ids, versioned payload formats, dependency ordering, and privacy-safe indexes for diagnostics. Schema migrations must be forward-compatible, reversible or safely pausable, and deployed before any app build can write production sync data. Until server schema readiness is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Test Harness Readiness` reports that Cloudflare production sync must not begin until repeatable end-to-end tests cover the migration and sync paths that can mutate real data. The production test plan must exercise first-launch CloudKit migration, single-device sync, two-device convergence, offline retry, rate limiting, conflict handling, token revocation, failed migration recovery, large project payloads, attachment or asset transfer, and cursor rollback after failures. Tests must prove that no failure path deletes the local store automatically or advances a cursor before durable commit. Until test harness readiness is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Asset Storage Readiness` reports that Cloudflare production sync must not begin until attachment and large payload storage is explicitly designed and tested. The production plan must define how cover images, formatted content blobs, undo/redo data, reference attachments, and other large assets move between SwiftData, Cloudflare storage, and local cache using stable asset ids, checksums, content length validation, resumable transfer, retry limits, deduplication, deletion semantics, and privacy-safe diagnostics. Asset failures must block cursor advancement without deleting local data or orphaning metadata. Until asset storage readiness is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Operations Monitoring` reports that Cloudflare production sync must not begin until operational metrics, alerts, and support visibility are defined. The production plan must track Worker errors, D1 and asset-store failures, rate limits, migration success and failure counts, active users, operation backlog, cursor lag, retry volume, storage growth, and cost-sensitive usage without logging private writing content. Alerts must identify stuck migrations, repeated cursor failures, elevated error rates, quota pressure, and disabled rollout states with enough redacted context for support to respond. Until operations monitoring is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Data Retention` reports that Cloudflare production sync must not begin until retention and deletion rules are defined for user records, devices, operation logs, cursors, audit records, tombstones, migration state, diagnostics, and stored assets. The production plan must specify what is kept for sync correctness, what expires, what is removed on account deletion or sync opt-out, how tombstones age out without resurrecting deleted data, and how support exports avoid private writing content. Retention failures must fail closed before production writes and must not delete local data automatically. Until data retention is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Environment Separation` reports that Cloudflare production sync must not begin until development, staging, and production environments are isolated and visibly identifiable. The production plan must use separate Worker routes, D1 databases, asset buckets, secrets, debug tokens, rollout flags, and diagnostics labels so test traffic, scratch POC data, and manual probes cannot write to production sync storage. App builds must fail closed when environment configuration is missing, mixed, or unsupported, and support exports must show the active environment without exposing secrets. Until environment separation is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production User Consent` reports that Cloudflare production sync must not begin until user-facing consent, disclosure, and opt-out behavior are defined for the CloudKit-to-Cloudflare transition. The production plan must explain what data will be prepared for the new sync system, what backend will store sync metadata and assets, how privacy-sensitive writing content is protected, whether migration is required or optional, how a user can pause or decline migration, and what happens to existing CloudKit sync. Consent state must be durable, support-visible, and fail closed before migration or production writes when missing or revoked. Until user consent is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Support Runbook` reports that Cloudflare production sync must not begin until support and incident-response procedures are documented and tested. The production plan must define how support diagnoses stuck migrations, cursor lag, repeated Worker or D1 failures, asset transfer failures, token revocation, consent withdrawal, environment misconfiguration, and user-reported missing data using redacted diagnostics. Runbooks must include escalation steps, kill-switch use, safe retry, rollback or pause actions, and clear prohibitions against deleting local stores or private writing content as a recovery shortcut. Until support runbooks are verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Quota And Cost Controls` reports that Cloudflare production sync must not begin until per-user, per-device, per-project, and per-account limits are defined and enforced. The production plan must bound operation volume, asset storage, request rate, migration batch size, retry behavior, background activity, and diagnostic export size with clear user/support messaging when limits are reached. Cost guardrails must include budget monitoring, abuse prevention, rate-limit backoff, rollout throttles, and a kill switch that pauses production writes without deleting local data or advancing cursors. Until quota and cost controls are verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Backup And Export Readiness` reports that Cloudflare production sync must not begin until users and support have a verified recovery export path before migration or production authority changes. The production plan must define when a local WSP or support bundle is recommended or required, how export integrity is checked, how private writing content is protected during support handoff, how failed migrations preserve the pre-migration data set, and how restore guidance avoids overwriting newer local work. Backup and export failures must fail closed before production writes and must not delete local data automatically. Until backup and export readiness is verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Implementation Entry` reports that Cloudflare production implementation must not begin until the scratch-only POC contracts are mapped to an ordered implementation plan with owners, feature flags, validation commands, rollback criteria, and release gates. The production plan must start with disabled-by-default server schema, auth, migration, asset, and applier components, prove each component through focused tests before wiring lifecycle triggers, and keep production SwiftData mutation behind rollout controls until end-to-end recovery drills pass. Until implementation entry criteria are verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Release Gate` reports that Cloudflare production sync must not ship to users until implementation, migration, operations, and recovery gates have passed in a production-like environment. The release plan must prove schema deployment, auth and ownership checks, user consent, migration preflight and progress, production applier rollback, asset transfer, quota controls, support runbooks, monitoring alerts, data retention, environment separation, and end-to-end multi-device convergence under feature flags. Release must remain staged, kill-switchable, and reversible without local store deletion or cursor drift. Until release gates are verified, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Verified 2026-07-08: `Show Production Rollback Drill` reports that Cloudflare production sync must not be enabled for users until rollback has been rehearsed from realistic failure points, including failed migration, partial asset upload, applier transaction failure, cursor mismatch, rate-limit pause, bad server deployment, and support-requested disablement. The drill must prove that feature flags and kill switches stop new production writes, existing local data remains intact, cursors are not advanced on failed apply, backup/export recovery guidance is available, and affected users can return to the last known-good local state without deleting the SwiftData store. Until rollback drills pass, the POC remains scratch-only with no production SwiftData apply. The summary did not contact the Worker and did not read or write scratch or production local data.

Added 2026-07-08, self-validated: `Production Implementation Sequence` maps the verified production contracts into the next implementation order. Production work should begin with disabled-by-default Worker/D1 schema and environment separation, then identity and entitlement checks, migration planning without apply, asset transfer, production SwiftData applier behind hard flags, lifecycle orchestrator wiring after applier tests, and final release/rollback rehearsal. The first production code should be server schema and environment separation, not SwiftData mutation.

Added 2026-07-08, self-validated: production server foundation schema added in `cloudflare-worker/sql/sync_production_schema.sql`, with separate npm scripts for `wsp_sync_production` D1 and `wsp-sync-production` R2 resources. The schema is separate from the scratch POC database and covers schema versions, environments, rollout flags, users, devices, projects, entitlements, migration runs, assets, operations, cursors, tombstones, audit events, and support actions. No app-side SwiftData mutation or production sync route wiring was added in this slice.

Added 2026-07-08, self-validated: production sync foundation routes added under `/api/sync/production/v1`. `GET /health` reports separate production binding/token configuration and confirms writes/app mutation are disabled. `POST /identity/check` requires `SYNC_PRODUCTION_TOKEN` and performs read-only checks against existing user, device, and project entitlement rows. The route can report authorization state, consent/lifecycle failures, and entitlement failures, but it never creates users/devices/projects, never enables writes, and does not touch app SwiftData.

Added 2026-07-08, self-validated: `POST /api/sync/production/v1/migration/preflight` added as the first migration-planner route. It requires `SYNC_PRODUCTION_TOKEN`, reads existing production user/device/project/entitlement rows, accepts caller-supplied CloudKit inventory and backup/consent/source-state signals, and returns fail-closed blockers plus estimated operation/asset batches. It performs no writes, creates no migration run, never applies operations, always reports `readyToApplyMigration: false`, and does not touch app SwiftData.

Added 2026-07-08, self-validated: `POST /api/sync/production/v1/assets/preflight` added as the first asset-storage route. It requires `SYNC_PRODUCTION_TOKEN`, validates a caller-supplied asset manifest, checks the production blob binding, and reads existing production user/device/project/entitlement rows before asset transfer can be attempted. It performs no R2 upload, no D1 write, no operation apply, always reports `readyToAdvanceCursor: false`, and does not touch app SwiftData.

Added 2026-07-08, self-validated: `POST /api/sync/production/v1/apply/preflight` added as the first production-applier boundary route. It requires `SYNC_PRODUCTION_TOKEN`, validates operation-window shape, checks existing production user/device/project/entitlement/cursor rows, and reports blockers for cursor mismatch, unavailable project writes, pending dependencies/assets, or unimplemented SwiftData apply. It performs no D1 write, does not mutate app SwiftData, always reports `readyToApply: false`, and blocks cursor advancement until a flagged SwiftData applier exists and commits successfully.

Added 2026-07-08, self-validated: `POST /api/sync/production/v1/orchestrator/eligibility` added as the first lifecycle-orchestrator boundary route. It requires `SYNC_PRODUCTION_TOKEN`, validates launch/foreground/network-recovery/silent-push/background-refresh/manual trigger eligibility against existing production user/device/project/entitlement/cursor rows and caller-supplied app/network state. It performs no writes, schedules no lifecycle work, does not apply operations, always reports `eligibleToRun: false`, and blocks orchestration until production rollout gates and a flagged SwiftData applier exist.

Added 2026-07-08, self-validated: `POST /api/sync/production/v1/release/readiness` added as the release/rollback rehearsal boundary route. It requires `SYNC_PRODUCTION_TOKEN`, reads production environment and rollout flag summaries, accepts caller-supplied evidence for schema deployment, auth, migration, assets, applier rollback, orchestrator drill, monitoring, support runbooks, backup/export, quota controls, environment separation, multi-device convergence, and kill-switch testing. It performs no writes, enables no rollout flags, always reports `readyToRelease: false`, and blocks production writes until a separate audited enable path exists.

Added 2026-07-08, self-validated: `npm run sync:prod:validate` added to validate the production foundation contract without contacting Cloudflare. The validator checks that production routes are documented, use separate production bindings/token, retain disabled write/app-mutation contracts, include the production schema tables, and do not expose ready-to-release/apply/orchestrate true states in the foundation routes.

Updated 2026-07-08, self-validated: `npm run sync:prod:validate` now inspects the production handler section specifically, verifies every production endpoint is routed and documented, checks production setup guidance is present, and fails if the production foundation routes contain `.run()` D1 execution calls or INSERT/UPDATE/DELETE SQL. This keeps the foundation namespace read-only until an explicit audited enable path is designed.

Updated 2026-07-08, self-validated: `npm run sync:prod:validate` now also checks production schema safety defaults and foreign-key anchors. Required defaults include writes disabled, consent missing, lifecycle active, migration not started, sequences/cursors at zero, project write entitlement off, migration planned, asset transfer pending, and apply state idle. Required foreign keys anchor users, projects, devices, environments, and operations so production rows have clear ownership and recovery context.

Updated 2026-07-08, self-validated: `npm run sync:prod:validate` now also enforces blob/rollout read-only safety for production foundation routes. It fails if the production handler writes or deletes R2 objects, starts or resumes multipart uploads, disables kill switches, or sets `writes_enabled = 1`. This keeps the foundation server routes unable to mutate D1, R2, rollout state, or production write flags.

Updated 2026-07-08, self-validated: `npm run sync:prod:validate` now checks route-specific fail-closed contracts for every production foundation endpoint. The validator verifies each route has its expected disabled response fields in source and matching README wording, including no-write health/identity, no-apply migration, no-cursor-advance assets/apply, no-run orchestrator, and no-release readiness.

Updated 2026-07-08, self-validated: `npm run sync:prod:validate` now checks `wrangler.toml` environment separation. It verifies scratch POC bindings remain active, production D1/R2 bindings remain documented but commented out, and POC resource names (`wsp_sync_poc`, `wsp-sync-poc`) stay distinct from production resource names (`wsp_sync_production`, `wsp-sync-production`) until production is explicitly enabled.

Added 2026-07-08, self-validated: `npm run sync:prod:validate:all` now runs the production foundation validator and then loads `cloudflare-worker/sql/sync_production_schema.sql` into an in-memory SQLite database. This gives the production foundation a single local no-Cloudflare command for Worker syntax, contract checks, environment separation checks, and schema parse validation.

Added 2026-07-08, self-validated: production route fail-closed expectations moved into `cloudflare-worker/sync-production-foundation-contract.json`. The validator now reads the manifest for endpoint paths, methods, required disabled source fields, and required README wording, making the production foundation contract auditable as data instead of only inline validator code.

Updated 2026-07-08, self-validated: `npm run sync:prod:validate:all` now validates the production contract manifest shape before using it. It fails on missing routes arrays, duplicate route paths, unsupported methods, missing required source/doc checks, or empty check strings.

Updated 2026-07-08, self-validated: `npm run sync:prod:validate:all` now checks that each manifest method is reflected in the production Worker dispatcher. The health endpoint must remain guarded as `GET`; the production preflight/readiness endpoints must remain guarded by the shared `POST` method check.

Updated 2026-07-08, self-validated: `npm run sync:prod:validate:all` now checks that every production contract manifest route has matching README method/path documentation using the full `/api/sync/production/v1` route prefix. This keeps the auditable manifest, Worker dispatcher, and public setup docs aligned.

Updated 2026-07-08, self-validated: production contract manifest entries now declare `requiresAuth` and `requiresProductionDb`. The validator fails if those flags are missing, if auth-required routes are not behind the production token check, if DB-required routes are not behind the `SYNC_PRODUCTION_DB` configuration check, or if the README omits the shared POST-route auth/DB contract.

Updated 2026-07-08, self-validated: production contract manifest entries now declare `requiresProductionBlobs`. The asset preflight route is marked as requiring `SYNC_PRODUCTION_BLOBS`, and the validator checks the Worker blocker plus README coverage while still forbidding R2 writes/uploads in foundation routes.

Updated 2026-07-08, self-validated: `npm run sync:prod:validate:all` now enforces Worker namespace binding separation. Production routes must not reference scratch POC bindings (`SYNC_DB`, `SYNC_BLOBS`, `SYNC_POC_TOKEN`), and scratch POC routes must not reference production bindings (`SYNC_PRODUCTION_DB`, `SYNC_PRODUCTION_BLOBS`, `SYNC_PRODUCTION_TOKEN`).

Updated 2026-07-08, self-validated: `npm run sync:prod:validate:all` now checks production Worker route literals against `sync-production-foundation-contract.json`. If a new production route is added to the Worker without a manifest entry, validation fails before the route can bypass the auditable fail-closed contract.

Updated 2026-07-08, self-validated: `sync-production-foundation-contract.json` now declares the production namespace (`/api/sync/production/v1`) and phase (`server-foundation`). The validator checks that the Worker production handler uses that namespace and uses the manifest namespace for README route documentation checks.

Updated 2026-07-08, self-validated: production contract manifest entries now declare `public`. The validator enforces that only `/health` may be public, public routes must not require auth, all non-public production routes must require auth, and the README must document that production health is the only public production foundation route.

Updated 2026-07-08, self-validated: `sync-production-foundation-contract.json` now declares a top-level read-only foundation policy. The validator requires D1 writes, R2 writes/uploads, SwiftData mutation, cursor advancement, and rollout enablement to remain forbidden, and it also fails if production routes ever report `readyToAdvanceCursor: true`.

Updated 2026-07-08, self-validated: `npm run sync:prod:validate:all` now requires README coverage for the top-level read-only production foundation policy. The docs must explicitly state that D1 writes, R2 writes/uploads, SwiftData mutation, cursor advancement, and rollout enablement are forbidden in this phase.

Updated 2026-07-08, self-validated: `npm run sync:prod:validate:all` now enforces exact production validation script contracts in `package.json`. `sync:prod:validate` must run Worker syntax plus foundation contract checks, and `sync:prod:validate:all` must additionally load `sql/sync_production_schema.sql` into in-memory SQLite.

Updated 2026-07-08, self-validated: `npm run sync:prod:validate:all` now checks the production foundation schema for destructive or unexpected mutating SQL. `sql/sync_production_schema.sql` must not contain `DROP`, `ALTER`, or `TRUNCATE`, and the only allowed data mutation is the `INSERT OR IGNORE` seed for the `sync_schema_versions` row.

Updated 2026-07-08, self-validated: `npm run sync:prod:validate:all` now checks production schema lookup indexes and primary-key anchors. It verifies user/device/project/migration/asset/operation/audit indexes plus entitlement, cursor, and tombstone primary keys used by preflight identity and cursor lookups.

Updated 2026-07-08, self-validated: JSON responses now default to `Cache-Control: no-store`, with explicit caller headers still able to override when intentional. The production validator checks this default so preflight/readiness responses are not accidentally cacheable.

Updated 2026-07-08, self-validated: `sync-production-foundation-contract.json` now declares `policy.cacheControl = "no-store"`. The validator checks the manifest, Worker JSON default, and README coverage so the production foundation cache policy remains part of the auditable contract.

Updated 2026-07-08, self-validated: `sync-production-foundation-contract.json` now declares `policy.maxAssetManifestItems = 1000`. The validator checks the manifest, Worker `MAX_SYNC_PRODUCTION_ASSET_MANIFEST_ITEMS` constant, production asset preflight enforcement, and README coverage so asset preflight request sizing remains auditable.

Updated 2026-07-08, self-validated: `sync-production-foundation-contract.json` now declares `policy.maxApplyWindowOperations = 500`. Production apply preflight rejects operation windows above that size, and the validator checks the manifest, Worker constant/enforcement, and README coverage. This does not enable apply or cursor advancement.
