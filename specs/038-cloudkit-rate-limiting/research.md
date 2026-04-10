# Research: Reliable CloudKit Sync

**Feature**: 038-cloudkit-rate-limiting
**Date**: 2026-04-10

## R1: Write Coalescing Strategy

### Decision
Introduce a centralized `WriteCoalescer` service that intercepts all `modelContext.save()` calls and batches them using a debounced flush timer. Callers request a save; the coalescer waits for an idle window (configurable, default 2 seconds) before executing a single `modelContext.save()`.

### Rationale
- The codebase currently has 20+ individual `save()` call sites across CommentManager (6×), FootnoteManager (7×), FileEditView (formatting), FileMoveService (6×), PoetryFormService (4×), StyleSheetService (3×), and ReferenceDeleteCommand (1×)
- Each save triggers a CloudKit export operation via NSPersistentCloudKitContainer
- Rapid operations (e.g., adding 5 footnotes) generate 5 separate exports when 1 would suffice
- A centralized coalescer means each call site changes only 1 line: `save()` → `coalescer.requestSave()`
- The coalescer handles the timer, flush-on-background, and flush-on-idle logic in one place

### Alternatives Considered
1. **Per-call-site debouncing** — Add individual timers to each manager/service. Rejected: duplicates logic across 20+ sites, hard to coordinate, easy to miss sites.
2. **SwiftData autosave-only** — Rely entirely on `autosaveEnabled = true` and remove all explicit saves. Rejected: autosave timing is unpredictable and not controllable; formatting saves were made explicit for Catalyst stability reasons.
3. **Combine-based save pipeline** — Route all saves through a Combine subject with `.debounce()`. Rejected: adds Combine dependency to pure SwiftData code; the coalescer can use a simple Timer internally.

## R2: Catalyst Formatting Stability Constraint

### Decision
The write coalescer will use a short flush delay (2 seconds default) rather than long batching windows. Formatting changes will go through the coalescer like everything else — the 2-second window is short enough that Catalyst stability is preserved (the issue was with saves never happening, not with 2-second delays).

### Rationale
- Formatting saves were originally made immediate to fix a Mac Catalyst stability bug where changes were lost
- The root cause was saves not happening at all (relying on autosave which was unreliable on Catalyst), not saves being delayed by seconds
- A 2-second coalescing window guarantees the save happens promptly while still batching rapid clicks
- If Catalyst issues resurface, the coalescer can be configured with a shorter window per-operation-type

### Alternatives Considered
1. **Bypass coalescer for formatting** — Keep formatting saves immediate. Rejected: formatting is one of the highest-frequency save sources; exempting it defeats the purpose.
2. **Zero-delay coalescer for formatting** — Use `RunLoop.main` scheduling so the save happens on the next run loop iteration, batching multiple same-frame saves. Rejected: too complex for marginal benefit; 2-second window is sufficient.

## R3: Persistent History Tracking

### Decision
Enable `NSPersistentHistoryTrackingKey` on the SwiftData ModelContainer configuration. This is a one-line configuration change.

### Rationale
- Apple's documentation recommends persistent history tracking for CloudKit sync
- It enables NSPersistentCloudKitContainer to process changes in batches rather than per-transaction
- It should reduce the number of CloudKit operations generated per save
- The existing codebase does NOT enable this despite using NSPersistentCloudKitContainer

### Alternatives Considered
1. **Skip it** — Continue without history tracking. Rejected: Apple explicitly recommends it and it's a low-risk, high-reward change.

## R4: Stall Detection Approach

### Decision
Add a `SyncHealthMonitor` that runs a periodic check (every 60 seconds) comparing the timestamp of the last local change against the timestamp of the last successful CloudKit export event. If the gap exceeds a threshold (default 5 minutes), the monitor flags a stall and begins progressive recovery.

### Rationale
- The existing CloudKitSyncThrottler already observes sync events (import/export start, success, failure) and rate-limit errors
- It tracks `exportCompleted`, `exportSucceeded`, `consecutiveExportRateLimits`
- The new monitor builds on these existing signals rather than introducing new CloudKit observation
- Progressive recovery: wait (2min) → log warning → wait (5min) → schedule reset if still stalled
- This is PASSIVE monitoring — it does not force sync operations, which would violate the existing architecture

### Alternatives Considered
1. **Extend CloudKitSyncThrottler directly** — Add stall detection to the existing service. Rejected: the throttler is already complex (~700 lines); separation of concerns keeps both manageable.
2. **User-triggered only** — Only detect stalls when the user checks sync status. Rejected: users shouldn't have to manually verify sync; the system should self-heal.
3. **Aggressive recovery** — Immediately reset sync database on stall detection. Rejected: dangerous; many "stalls" resolve naturally. Progressive escalation is safer.

## R5: Sync Status Visibility

### Decision
Add a small sync status indicator in the Settings view that shows one of four states: synced (checkmark), syncing (animated), stalled (warning), recovering (progress). Use the existing CloudKitSyncThrottler state plus the new SyncHealthMonitor state.

### Rationale
- Users have expressed concern about whether sync is working
- The throttler already tracks `isSyncing`, `rateLimitedUntil`, and success/failure state
- A simple status view (not a detailed dashboard) is sufficient for user confidence
- Non-alarming: "stalled" shows as a yellow indicator with "Catching up..." text, not an error

### Alternatives Considered
1. **Detailed sync dashboard** — Show event logs, operation counts, etc. Rejected: over-engineering for user needs; the diagnostic log already exists in CloudKitSyncThrottler for developer debugging.
2. **Status bar icon** — Show sync state in the navigation bar of every view. Rejected: clutters the UI; Settings is sufficient for status checks.
3. **Push notifications for stalls** — Alert users when sync stalls. Rejected: alarming; contradicts FR-015.

## R6: Flush-on-Background Safety

### Decision
The WriteCoalescer will observe `scenePhase` changes and flush all pending saves immediately when the app transitions to background. Additionally, it will register for `UIApplication.willResignActiveNotification` as a backup.

### Rationale
- FR-007 requires flushing before background
- SwiftUI's `scenePhase` is the primary lifecycle signal but can sometimes be delayed
- `willResignActiveNotification` fires earlier and more reliably
- Both signals call the same flush method; double-flush is safe (second flush is a no-op if nothing is dirty)

### Alternatives Considered
1. **scenePhase only** — Rejected: unreliable on Catalyst in some scenarios.
2. **Background task** — Request `BGProcessingTask` to continue saves. Rejected: unnecessary complexity; flush is fast (single save call).

## R7: App Termination Data Safety

### Decision
The WriteCoalescer does NOT maintain a separate in-memory buffer of unsaved changes. Instead, it simply delays the `modelContext.save()` call. SwiftData model objects are already modified in-place on the ModelContext — the coalescer just controls _when_ the save is called. If the app is terminated, `autosaveEnabled = true` on the mainContext means SwiftData will save automatically before termination in most cases.

### Rationale
- FR-018 requires changes to be recoverable if the app terminates during coalescing
- SwiftData's `autosaveEnabled` is the safety net — changes are already applied to model objects, just not persisted to disk yet
- The coalescer's 2-second window is short; the risk window is minimal
- Adding a separate WAL/journal for uncommitted changes would be over-engineering

### Alternatives Considered
1. **Custom write-ahead log** — Buffer changes in a separate file. Rejected: massive complexity for a 2-second risk window.
2. **Disable autosave, manage all saves manually** — Rejected: contradicts existing architecture and increases risk.
