# Tasks: Reliable CloudKit Sync

**Input**: Design documents from `/specs/038-cloudkit-rate-limiting/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included — constitution requires automated tests for all features (Constitution §II).

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Enable persistent history tracking and prepare the coalescer foundation

- [ ] T001 Enable persistent history tracking in ModelContainer configuration in `WrtingShedPro/Writing Shed Pro/Write_App.swift` — add `NSPersistentHistoryTrackingKey: true` to the ModelConfiguration options (FR-009)
- [ ] T002 Add `SyncHealthState` enum (healthy, syncing, degraded, stalled, recovering) with display text and indicator properties in `WrtingShedPro/Writing Shed Pro/Services/SyncHealthMonitor.swift` — create the file with just the enum for now
- [ ] T003 Add localisation strings for sync status display text ("All synced", "Syncing...", "Catching up...", "Sync delayed", "Restoring sync...") in `WrtingShedPro/Writing Shed Pro/Resources/en.lproj/Localizable.strings`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build WriteCoalescer — the core service that ALL user stories depend on

**CRITICAL**: No user story work can begin until WriteCoalescer is functional and tested

- [ ] T004 Create `WriteCoalescer` as `@Observable` `@MainActor` class in `WrtingShedPro/Writing Shed Pro/Services/WriteCoalescer.swift` — implement `requestSave()`, `flush()`, `cancelPending()` with configurable `flushDelay` (default 2.0s), `pendingSave`, `saveCount`, `requestCount`, `lastFlushTime` properties per data-model contract
- [ ] T005 Add flush-on-background lifecycle handling in `WriteCoalescer` — observe `UIApplication.willResignActiveNotification` and call `flush()` (FR-007, research R6)
- [ ] T006 Add `lastSuccessfulExportTime: Date?` property to `CloudKitSyncThrottler` in `WrtingShedPro/Writing Shed Pro/Services/CloudKitSyncThrottler.swift` — set it when `exportSucceeded` transitions to true (per contracts)
- [ ] T007 Create `WriteCoalescerTests` in `WrtingShedPro/WritingShedProTests/WriteCoalescerTests.swift` — test: (a) single requestSave produces one save, (b) 10 rapid requestSave calls within 2s produce one save, (c) flush() immediately saves when pending, (d) flush() is no-op when not pending, (e) requestSave after flush starts new timer
- [ ] T008 Add test for `lastSuccessfulExportTime` in `WrtingShedPro/WritingShedProTests/CloudKitSyncThrottlerTests.swift` — verify property is set on export success and nil initially

**Checkpoint**: WriteCoalescer is functional with tests passing. Ready for call-site migration.

---

## Phase 3: User Story 1 — Editing Without Sync Disruption (Priority: P1) MVP

**Goal**: Reduce save operations during active editing by routing all save() calls through WriteCoalescer. 50% fewer saves during intensive editing.

**Independent Test**: Open document, perform 50 rapid edits (typing + formatting + comments), verify save count is ≤25 (down from ~50+). No rate-limit errors in sync log.

### Implementation for User Story 1

- [ ] T009 [P] [US1] Initialise `WriteCoalescer` in app startup and inject into SwiftUI environment in `WrtingShedPro/Writing Shed Pro/Write_App.swift` — create instance with main `ModelContext`, add to `.environment()`
- [ ] T010 [P] [US1] Add flush-on-background call in `WrtingShedPro/Writing Shed Pro/Views/ContentView.swift` — in `.onChange(of: scenePhase)` when transitioning to `.background`, call `writeCoalescer.flush()`
- [ ] T011 [P] [US1] Replace all direct `try? modelContext.save()` calls with `writeCoalescer.requestSave()` in `WrtingShedPro/Writing Shed Pro/Managers/CommentManager.swift` (6 call sites: ~L53, L102, L118, L134, L150, L183) — inject WriteCoalescer via init parameter
- [ ] T012 [P] [US1] Replace all direct `try? modelContext.save()` calls with `writeCoalescer.requestSave()` in `WrtingShedPro/Writing Shed Pro/Managers/FootnoteManager.swift` (7 call sites: ~L65, L123, L147, L212, L245 + insert/delete methods) — inject WriteCoalescer via init parameter
- [ ] T013 [US1] Replace formatting save calls with `writeCoalescer.requestSave()` in `WrtingShedPro/Writing Shed Pro/Views/FileEditView.swift` — find all immediate `save()` calls in formatting handlers (~L6014-L6028 area) and replace with coalescer
- [ ] T014 [P] [US1] Replace save calls with `writeCoalescer.requestSave()` in `WrtingShedPro/Writing Shed Pro/Services/FileMoveService.swift` (6 call sites: ~L42, L62, L96) — inject WriteCoalescer
- [ ] T015 [P] [US1] Replace save calls with `writeCoalescer.requestSave()` in `WrtingShedPro/Writing Shed Pro/Services/PoetryFormService.swift` (4 call sites: ~L202, L262, L311, L360) — inject WriteCoalescer
- [ ] T016 [P] [US1] Replace save calls with `writeCoalescer.requestSave()` in `WrtingShedPro/Writing Shed Pro/Services/StyleSheetService.swift` (3 call sites: ~L284, L409, L606) — inject WriteCoalescer
- [ ] T017 [P] [US1] Replace save call with `writeCoalescer.requestSave()` in `WrtingShedPro/Writing Shed Pro/Drama/Models/Commands/ReferenceDeleteCommand.swift` (~L130) — inject WriteCoalescer
- [ ] T018 [US1] Update existing unit tests that depend on immediate `save()` in managers — ensure `CommentManagerTests`, `FootnoteManager` tests, and related tests either inject a WriteCoalescer (with 0s delay for tests) or call `flush()` after operations
- [ ] T019 [US1] Add integration test in `WrtingShedPro/WritingShedProTests/WriteCoalescerTests.swift` — test that 10 rapid `requestSave()` calls from different simulated operations (comment + footnote + formatting) result in ≤3 actual saves (validates SC-001 50% reduction)

**Checkpoint**: All save() calls routed through coalescer. US1 independently testable — run 50 rapid edits, verify save count reduced by ≥50%.

---

## Phase 4: User Story 2 — Sync Stall Detection and Recovery (Priority: P2)

**Goal**: Detect when sync has stalled and recover automatically using progressive escalation. Show sync health status in Settings.

**Independent Test**: Simulate export stall (mock lastSuccessfulExportTime to 10+ minutes ago), verify SyncHealthMonitor detects stall, escalates through recovery stages, and eventually schedules DB reset.

### Implementation for User Story 2

- [ ] T020 [US2] Complete `SyncHealthMonitor` implementation in `WrtingShedPro/Writing Shed Pro/Services/SyncHealthMonitor.swift` — add `@Observable` `@MainActor` class with `healthState`, `lastLocalChangeTime`, `lastSuccessfulExportTime`, `stallDetectedAt`, `recoveryAttempts` properties; implement `checkHealth()` with 60s periodic timer, `recordLocalChange()`, `recordExportSuccess()`, `attemptRecovery()` per data-model contract
- [ ] T021 [US2] Wire `SyncHealthMonitor` to `CloudKitSyncThrottler` in `WrtingShedPro/Writing Shed Pro/Services/SyncHealthMonitor.swift` — read `lastSuccessfulExportTime` and `consecutiveExportRateLimits` from throttler; call `scheduleAutoResetIfNeeded()` on recovery attempt 3 (FR-011, FR-013)
- [ ] T022 [US2] Wire `WriteCoalescer` to `SyncHealthMonitor` — after each successful `flush()` in WriteCoalescer, call `syncHealthMonitor.recordLocalChange()` (FR-010)
- [ ] T023 [US2] Add diagnostic logging for stall detection in `SyncHealthMonitor` — log state transitions, recovery attempts, and outcomes using `CloudKitSyncThrottler.logEvent()` (FR-012)
- [ ] T024 [US2] Create `SyncStatusView` in `WrtingShedPro/Writing Shed Pro/Views/SyncStatusView.swift` — display icon (checkmark/spinner/warning) + text per health state enum; include secondary "Last synced X ago" text when stalled; VoiceOver label; Dynamic Type support (FR-014, FR-015)
- [ ] T025 [US2] Integrate `SyncStatusView` into Settings screen in `WrtingShedPro/Writing Shed Pro/Views/SettingsSheet.swift` — add sync status row above the existing "Reset Sync Database" button
- [ ] T026 [US2] Initialise `SyncHealthMonitor` in app startup and inject into SwiftUI environment in `WrtingShedPro/Writing Shed Pro/Write_App.swift` — create instance with references to `CloudKitSyncThrottler.shared` and `WriteCoalescer`
- [ ] T027 [P] [US2] Create `SyncHealthMonitorTests` in `WrtingShedPro/WritingShedProTests/SyncHealthMonitorTests.swift` — test: (a) healthy when no pending changes, (b) degraded when gap > 5min, (c) stalled when gap > 10min, (d) recovery escalation (attempt 1 → wait, attempt 2 → wait, attempt 3 → schedule reset), (e) recovery resets on export success, (f) state returns to healthy when gap clears

**Checkpoint**: Stall detection working, sync status visible in Settings. US2 independently testable — mock stalled state and verify detection + recovery + UI indicator.

---

## Phase 5: User Story 3 — Multi-Device Consistency After Extended Editing (Priority: P3)

**Goal**: Validate that coalescing and stall recovery work reliably at scale over long editing sessions with hundreds of changes.

**Independent Test**: Perform 200+ changes in a single session, verify all changes flush within 30 seconds of session end, no data loss.

### Implementation for User Story 3

- [ ] T028 [US3] Add session-end flush guarantee in WriteCoalescer — ensure `flush()` is called when the editing view disappears (`.onDisappear` in `WrtingShedPro/Writing Shed Pro/Views/FileEditView.swift`) so accumulated changes are saved before navigating away
- [ ] T029 [US3] Add rate-limit awareness to WriteCoalescer in `WrtingShedPro/Writing Shed Pro/Services/WriteCoalescer.swift` — when `CloudKitSyncThrottler.rateLimitedUntil` is active, extend `flushDelay` to reduce save frequency further (FR-006); restore normal delay when rate limit clears
- [ ] T030 [US3] Add stress test in `WrtingShedPro/WritingShedProTests/WriteCoalescerTests.swift` — simulate 200 rapid `requestSave()` calls over 60 seconds, verify total saves ≤30 (validate coalescing at scale) and final `flush()` completes within 30 seconds of last request

**Checkpoint**: Extended session handling validated. All three user stories independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, cleanup, and cross-cutting improvements

- [ ] T031 [P] Audit all remaining `modelContext.save()` / `try? context.save()` calls across the entire codebase — grep for any save calls not yet routed through WriteCoalescer (e.g., in views, other services, undo/redo commands) and migrate them
- [ ] T032 [P] Add save-count diagnostic logging to WriteCoalescer — log `requestCount` vs `saveCount` ratio periodically (every 5 minutes while active) for ongoing monitoring of coalescing effectiveness
- [ ] T033 Run `quickstart.md` validation — execute the test commands from quickstart.md and verify all tests pass
- [ ] T034 Verify Catalyst stability — test formatting changes on macOS Catalyst specifically (rapid bold/italic/underline clicks) to confirm 2-second coalescing delay does not regress the original stability fix

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (T002 enum needed by T004) — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Phase 2 completion (WriteCoalescer must exist)
- **User Story 2 (Phase 4)**: Depends on Phase 2 (CloudKitSyncThrottler.lastSuccessfulExportTime) — can run in parallel with US1
- **User Story 3 (Phase 5)**: Depends on Phase 3 (US1 must be complete — all save calls migrated) and Phase 4 (US2 stall detection must exist for rate-limit awareness)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Phase 2 — no dependencies on other stories
- **User Story 2 (P2)**: Can start after Phase 2 — can run in parallel with US1
- **User Story 3 (P3)**: Depends on US1 (save migration) and US2 (stall detection) — must be last

### Within Each User Story

- Tests should be written alongside implementation
- Service creation before call-site migration
- Call-site migration before integration tests
- Story complete before moving to next priority

### Parallel Opportunities

- **Phase 1**: T001, T002, T003 can all run in parallel (different files)
- **Phase 2**: T004 first, then T005 depends on T004; T006 parallel with T004; T007/T008 after their respective implementations
- **Phase 3**: T009, T010, T011, T012, T014, T015, T016, T017 can all run in parallel (different files); T013 and T018 after migrations; T019 last
- **Phase 4**: T020-T023 sequential (same file or dependencies); T024+T025 parallel with T20-T23; T027 parallel after T020
- **Phase 6**: T031, T032 parallel; T033, T034 after everything

---

## Parallel Example: User Story 1

```
# These can all run simultaneously (different files):
T011: CommentManager.swift — replace save() calls
T012: FootnoteManager.swift — replace save() calls
T014: FileMoveService.swift — replace save() calls
T015: PoetryFormService.swift — replace save() calls
T016: StyleSheetService.swift — replace save() calls
T017: ReferenceDeleteCommand.swift — replace save() call

# Then these depend on the above:
T013: FileEditView.swift — replace formatting saves
T018: Update existing unit tests for coalescer injection
T019: Integration test for save count reduction
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational — WriteCoalescer + tests (T004-T008)
3. Complete Phase 3: User Story 1 — migrate all save calls (T009-T019)
4. **STOP and VALIDATE**: Run 50 rapid edits, verify ≥50% fewer saves, no rate-limit errors
5. This alone delivers the biggest win — most rate-limiting risk eliminated

### Incremental Delivery

1. Setup + Foundational → WriteCoalescer ready
2. Add User Story 1 → Test save reduction → Deploy (MVP — biggest impact)
3. Add User Story 2 → Test stall detection + sync status UI → Deploy
4. Add User Story 3 → Test extended session reliability → Deploy
5. Polish → Final audit, Catalyst verification → Release

---

## Notes

- All file paths are under `WrtingShedPro/Writing Shed Pro/` (iOS/macOS Catalyst project)
- Test files are under `WrtingShedPro/WritingShedProTests/`
- The WriteCoalescer uses `@Observable` (not `ObservableObject`) per project conventions
- Line numbers are approximate — verify exact locations before editing
- The existing 0.5s text-typing debounce in FileEditView remains unchanged
- JSONImportService already does a single batched save — no changes needed there
- Commit after each task or logical group of parallel tasks
