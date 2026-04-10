# Implementation Plan: Reliable CloudKit Sync

**Branch**: `038-cloudkit-rate-limiting` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/038-cloudkit-rate-limiting/spec.md`

## Summary

Writing Shed Pro generates excessive CloudKit write operations during editing (formatting, comments, footnotes, references all save immediately). This causes rate-limiting and sync stalls. The plan introduces a centralized write coalescing service that batches rapid saves into fewer operations, adds persistent history tracking, builds stall detection with progressive recovery, and surfaces sync health to the user — all while preserving the existing passive-sync architecture.

## Technical Context

**Language/Version**: Swift 5.0, targeting iOS 18.5+ / macOS 14.0+
**Primary Dependencies**: SwiftUI, SwiftData, CloudKit, Combine, NSPersistentCloudKitContainer
**Storage**: SwiftData with CloudKit backend (SQLite at `URL.documentsDirectory/writingshed.sqlite`, container `iCloud.com.appworks.writingshedpro`)
**Testing**: XCTest (80+ unit test files, 3 UI test files, in-memory ModelContainer for tests)
**Target Platform**: iOS 18.5+ (iPhone/iPad), macOS 14.0+ (Mac Catalyst)
**Project Type**: Mobile (iOS + macOS via Catalyst)
**Performance Goals**: ≥50% reduction in save operations during intensive editing; all changes sync within 10 minutes of idle
**Constraints**: Offline-capable (local-first), no proactive sync nudges (passive architecture), single ModelContext, autosave enabled
**Scale/Scope**: Single-user app, 45+ SwiftData model classes, ~80 service files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Code Quality
- **Status**: PASS
- All new code will follow existing Swift style conventions, be localised where user-facing, and go through code review
- Write coalescing service will be fully commented with inline documentation

### II. Testing Standards
- **Status**: PASS
- CloudKitSyncThrottler already has tests; new write coalescing and stall detection will follow the same XCTest + in-memory ModelContainer pattern
- Unit tests for coalescing logic, integration tests for save-count verification

### III. User Experience Consistency
- **Status**: PASS
- Sync status indicator will follow existing Settings UI patterns
- Non-alarming language; no modal alerts or blocking behavior
- Consistent across iOS and macOS (Catalyst)

### IV. Performance Requirements
- **Status**: PASS
- Target: ≥50% fewer save operations during intensive editing
- No performance regressions — coalescing adds negligible delay (2-3s max before flush)
- Profiling required before release to verify no memory growth from buffered changes

### Additional Constraints
- No new third-party dependencies introduced
- Security: no changes to data access patterns or authentication

## Project Structure

### Documentation (this feature)

```
specs/038-cloudkit-rate-limiting/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (internal service contracts)
└── tasks.md             # Phase 2 output (/speckit.tasks - NOT created by /speckit.plan)
```

### Source Code (repository root)

```
WrtingShedPro/Writing Shed Pro/
├── Services/
│   ├── CloudKitSyncThrottler.swift    # MODIFY: add stall detection, sync health state
│   ├── WriteCoalescer.swift           # NEW: centralized save coalescing service
│   └── SyncHealthMonitor.swift        # NEW: stall detection and progressive recovery
├── Managers/
│   ├── CommentManager.swift           # MODIFY: replace direct save() with coalesced save
│   └── FootnoteManager.swift          # MODIFY: replace direct save() with coalesced save
├── Views/
│   ├── ContentView.swift              # MODIFY: flush coalescer on background transition
│   ├── FileEditView.swift             # MODIFY: route formatting saves through coalescer
│   └── SyncStatusView.swift           # NEW: sync health indicator for Settings
├── Drama/Models/Commands/
│   └── ReferenceDeleteCommand.swift   # MODIFY: route save through coalescer
└── Write_App.swift                    # MODIFY: enable persistent history tracking, init new services

WrtingShedPro/WritingShedProTests/
├── WriteCoalescerTests.swift          # NEW: unit tests for coalescing logic
├── SyncHealthMonitorTests.swift       # NEW: unit tests for stall detection
└── CloudKitSyncThrottlerTests.swift   # MODIFY: add tests for new sync health state
```

**Structure Decision**: Mobile (iOS + macOS Catalyst) single-project structure. All changes are within the existing `WrtingShedPro/Writing Shed Pro/` directory. No new top-level directories needed.

## Complexity Tracking

No constitution violations detected. All changes fit within existing architecture.

