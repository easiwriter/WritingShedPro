# Internal Service Contracts: Reliable CloudKit Sync

**Feature**: 038-cloudkit-rate-limiting
**Date**: 2026-04-10

## Overview

This feature has no external APIs (no REST endpoints, no GraphQL). All contracts are internal Swift service interfaces. This document defines the public interface each new/modified service exposes.

---

## WriteCoalescer Contract

```
Service: WriteCoalescer
Scope: App-wide singleton, injected via SwiftUI environment
Thread Safety: Main actor isolated (all callers are on main thread)

INPUTS:
  requestSave()
    - Called by: CommentManager, FootnoteManager, FileEditView (formatting),
                 FileMoveService, PoetryFormService, StyleSheetService,
                 ReferenceDeleteCommand, and any future save call site
    - Precondition: ModelContext has dirty objects
    - Effect: Starts/resets flush timer (2s default)

  flush()
    - Called by: scenePhase → background, willResignActiveNotification,
                 explicit user action (e.g., "Save Now")
    - Effect: Immediately saves if pendingSave is true
    - Idempotent: Safe to call multiple times (no-op if nothing pending)

OUTPUTS:
  pendingSave: Bool (observable)
  saveCount: Int (observable, diagnostic)
  requestCount: Int (observable, diagnostic)
  lastFlushTime: Date? (observable, consumed by SyncHealthMonitor)

GUARANTEES:
  - Every requestSave() results in exactly one modelContext.save() within
    max(flushDelay, time-to-background)
  - Rapid requestSave() calls within flushDelay are coalesced into one save
  - flush() on background is non-optional; app will not enter background
    with pending unsaved changes
  - Save errors are logged but not thrown (matches existing save() pattern)

CONFIGURATION:
  flushDelay: TimeInterval (default 2.0, configurable at init)
```

---

## SyncHealthMonitor Contract

```
Service: SyncHealthMonitor
Scope: App-wide singleton, injected via SwiftUI environment
Thread Safety: Main actor isolated
Dependencies: CloudKitSyncThrottler (read), WriteCoalescer (read)

INPUTS:
  recordLocalChange()
    - Called by: WriteCoalescer after each successful flush
    - Updates: lastLocalChangeTime

  recordExportSuccess()
    - Called by: CloudKitSyncThrottler when export completes successfully
    - Updates: lastSuccessfulExportTime, resets recoveryAttempts

  checkHealth()
    - Called by: internal 60-second periodic timer
    - Evaluates: gap between lastLocalChangeTime and lastSuccessfulExportTime

OUTPUTS:
  healthState: SyncHealthState (observable)
    - .healthy: gap < 5 minutes or no pending local changes
    - .syncing: CloudKitSyncThrottler.isSyncing is true
    - .degraded: gap 5-10 minutes
    - .stalled: gap > 10 minutes
    - .recovering: active recovery in progress

  stallDetectedAt: Date? (observable)
  recoveryAttempts: Int (observable)

RECOVERY STRATEGY:
  Attempt 1: Wait 2 minutes (stall may self-resolve)
  Attempt 2: Wait 5 more minutes
  Attempt 3: Schedule sync database reset on next launch
             (calls CloudKitSyncThrottler.scheduleAutoResetIfNeeded())
  
  Recovery resets when:
    - Export succeeds (recordExportSuccess)
    - Health returns to .healthy

GUARANTEES:
  - Never forces sync operations (passive observation only)
  - Never deletes data directly
  - Database reset is scheduled, not executed immediately
  - All state transitions are logged to CloudKitSyncThrottler's event log
```

---

## CloudKitSyncThrottler Modifications Contract

```
Service: CloudKitSyncThrottler (existing, modified)
Changes: Minimal — add one property

NEW OUTPUTS:
  lastSuccessfulExportTime: Date? (observable)
    - Set when: exportSucceeded flag transitions to true
    - Consumed by: SyncHealthMonitor

NO OTHER CHANGES to existing interface.
```

---

## SyncStatusView Contract

```
View: SyncStatusView
Location: Settings screen
Dependencies: SyncHealthMonitor (read), CloudKitSyncThrottler (read)

DISPLAYS:
  - Icon: checkmark (green), spinner (blue), warning (yellow/orange)
  - Text: "All synced", "Syncing...", "Catching up...", "Sync delayed",
          "Restoring sync..."
  - Secondary text (when stalled): "Last synced [relative time ago]"

INTERACTIONS:
  None — display only. No tap actions, no force-sync buttons.
  (Existing "Reset Sync Database" button in Settings remains separate)

ACCESSIBILITY:
  - VoiceOver label describes current sync state
  - Dynamic Type supported for all text
```
