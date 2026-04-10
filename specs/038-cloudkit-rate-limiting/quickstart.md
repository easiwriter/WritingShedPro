# Quickstart: 038 Reliable CloudKit Sync

**Branch**: `038-cloudkit-rate-limiting`

## What This Feature Does

Reduces CloudKit rate-limiting and sync stalls by:
1. Coalescing rapid save operations into fewer actual saves
2. Detecting sync stalls and recovering automatically
3. Showing sync health status to the user

## Key Files

| File | Role |
|------|------|
| `Services/WriteCoalescer.swift` | NEW — Centralized save coalescing |
| `Services/SyncHealthMonitor.swift` | NEW — Stall detection and recovery |
| `Services/CloudKitSyncThrottler.swift` | MODIFIED — Add lastSuccessfulExportTime |
| `Views/SyncStatusView.swift` | NEW — Sync health indicator in Settings |
| `Managers/CommentManager.swift` | MODIFIED — Use coalescer instead of direct save |
| `Managers/FootnoteManager.swift` | MODIFIED — Use coalescer instead of direct save |
| `Views/FileEditView.swift` | MODIFIED — Route formatting saves through coalescer |
| `Views/ContentView.swift` | MODIFIED — Flush coalescer on background |
| `Write_App.swift` | MODIFIED — Enable history tracking, init services |

## How It Works

### Write Coalescing
- All `modelContext.save()` calls are replaced with `writeCoalescer.requestSave()`
- The coalescer waits 2 seconds of idle time, then executes a single save
- On app background: immediate flush (no pending changes lost)
- Result: 5 rapid footnote adds = 1 save instead of 5

### Stall Detection
- Every 60 seconds, SyncHealthMonitor checks: "Has my last local change been exported?"
- If the gap exceeds 5 minutes → degraded; 10 minutes → stalled
- Recovery escalates: wait → wait longer → schedule DB reset

### Sync Status
- Settings shows: synced / syncing / catching up / sync delayed
- Non-alarming, display-only (no user actions required)

## Testing

```bash
# Run unit tests
xcodebuild test -scheme "Writing Shed Pro" -destination "platform=iOS Simulator,name=iPhone 16"
```

Key test files:
- `WriteCoalescerTests.swift` — Verifies coalescing reduces save count
- `SyncHealthMonitorTests.swift` — Verifies stall detection thresholds and recovery escalation
- `CloudKitSyncThrottlerTests.swift` — Existing + new lastSuccessfulExportTime tests

## Architecture Constraints

- **No proactive sync nudges** — The system is passive; it never forces CloudKit operations
- **Single ModelContext** — All saves go through the main context
- **Autosave remains enabled** — Safety net for unexpected termination
- **No new SwiftData models** — All state is runtime-only (in-memory)
