# Data Model: Reliable CloudKit Sync

**Feature**: 038-cloudkit-rate-limiting
**Date**: 2026-04-10

## Overview

This feature does NOT introduce new SwiftData `@Model` entities. It introduces observable service objects that manage runtime state. No schema migration is required.

## New Service Objects

### WriteCoalescer

**Purpose**: Centralized save coalescing — accepts save requests and flushes them as a single `modelContext.save()` after an idle threshold.

| Property | Type | Description |
|----------|------|-------------|
| `pendingSave` | `Bool` | Whether a save has been requested but not yet flushed |
| `flushDelay` | `TimeInterval` | Idle threshold before flush (default: 2.0 seconds) |
| `lastFlushTime` | `Date?` | Timestamp of last successful flush |
| `saveCount` | `Int` | Diagnostic counter: number of actual saves performed |
| `requestCount` | `Int` | Diagnostic counter: number of save requests received |

**Methods**:

| Method | Parameters | Description |
|--------|-----------|-------------|
| `requestSave()` | none | Marks a save as pending; resets the flush timer |
| `flush()` | none | Immediately executes `modelContext.save()` if pending; resets timer |
| `cancelPending()` | none | Cancels any pending save without flushing |

**State Transitions**:
```
idle → [requestSave()] → pending → [timer expires] → flushing → idle
                           ↑            ↓
                    [requestSave()]   [flush()]
                    (resets timer)   (immediate)
```

**Lifecycle Rules**:
- Created once at app startup, injected into environment
- Receives a reference to the main `ModelContext`
- Observes `scenePhase` and `willResignActiveNotification` → calls `flush()`
- Timer is invalidated when app enters background

---

### SyncHealthMonitor

**Purpose**: Detects sync stalls and orchestrates progressive recovery.

| Property | Type | Description |
|----------|------|-------------|
| `healthState` | `SyncHealthState` | Current sync health (see enum below) |
| `lastLocalChangeTime` | `Date?` | Timestamp of last local save (updated by WriteCoalescer) |
| `lastSuccessfulExportTime` | `Date?` | Timestamp of last successful export (from CloudKitSyncThrottler) |
| `stallDetectedAt` | `Date?` | When the current stall was first detected |
| `recoveryAttempts` | `Int` | Number of recovery attempts for current stall |

**Methods**:

| Method | Parameters | Description |
|--------|-----------|-------------|
| `checkHealth()` | none | Evaluates current sync health based on time gaps |
| `recordLocalChange()` | none | Called by WriteCoalescer after each flush |
| `recordExportSuccess()` | none | Called when CloudKitSyncThrottler reports export success |
| `attemptRecovery()` | none | Escalates recovery strategy based on attempt count |

**State Transitions**:
```
healthy → [gap > 5min] → degraded → [gap > 10min] → stalled → [recovery starts] → recovering → healthy
                                                        ↓
                                                  [recovery fails after 3 attempts]
                                                        ↓
                                                  stalled (schedules DB reset)
```

---

### SyncHealthState (Enum)

| Case | Display Text | Indicator |
|------|-------------|-----------|
| `healthy` | "All synced" | Green checkmark |
| `syncing` | "Syncing..." | Animated indicator |
| `degraded` | "Catching up..." | Yellow indicator |
| `stalled` | "Sync delayed" | Orange warning |
| `recovering` | "Restoring sync..." | Progress indicator |

---

## Modified Existing Objects

### CloudKitSyncThrottler (existing)

**New properties added**:

| Property | Type | Description |
|----------|------|-------------|
| `lastSuccessfulExportTime` | `Date?` | Set when export succeeds; consumed by SyncHealthMonitor |

**No other changes** — existing rate-limit tracking, backoff, and event coalescing remain unchanged.

---

## Relationships Between Services

```
WriteCoalescer                    SyncHealthMonitor
  ├── holds: ModelContext            ├── reads: CloudKitSyncThrottler.lastSuccessfulExportTime
  ├── calls: modelContext.save()     ├── reads: CloudKitSyncThrottler.consecutiveExportRateLimits
  ├── notifies: SyncHealthMonitor    ├── reads: WriteCoalescer.lastFlushTime
  │   (recordLocalChange)            └── calls: CloudKitSyncThrottler.scheduleAutoResetIfNeeded()
  └── reads: CloudKitSyncThrottler
      (rateLimitedUntil — for UI)

CloudKitSyncThrottler (existing)
  ├── observes: NSPersistentStoreRemoteChangeNotification
  ├── observes: NSPersistentStoreCoordinatorStoresDidChangeNotification
  └── tracks: rate limits, import/export lifecycle
```

## No Database Schema Changes

All new state is runtime-only (in-memory). No SwiftData `@Model` classes are added or modified. No CloudKit schema changes. No migration required.
