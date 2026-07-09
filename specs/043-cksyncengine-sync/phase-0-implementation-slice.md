# Phase 0: Test-Only Implementation Slice

**Status**: Approved for test-only implementation
**Created**: 2026-07-09
**Depends on**:

- [phase-0-review-checklist.md](phase-0-review-checklist.md)
- [phase-0-dry-run-mapper-plan.md](phase-0-dry-run-mapper-plan.md)
- [rollout-gates.md](rollout-gates.md)

## Purpose

Define the first code slice to implement after Phase 0 review. This slice is intentionally test-only and should not start CKSyncEngine, call CloudKit, mutate SwiftData, or change any `@Model` schema.

## Existing Test Pattern

The app already has a `WrtingShedPro/WritingShedProTests` target using:

- `XCTest`
- `@testable import Writing_Shed_Pro`
- in-memory `ModelContainer` fixtures for SwiftData model tests

The dry-run mapper tests should follow that pattern rather than introducing a new test framework.

## Proposed Files

| File | Purpose |
| --- | --- |
| `WrtingShedPro/Writing Shed Pro/Services/Sync/DryRun/SyncRecordEnvelope.swift` | Plain values for record type, record name, fields, relationships, and asset placeholders |
| `WrtingShedPro/Writing Shed Pro/Services/Sync/DryRun/CoreRecordMapper.swift` | Maps the first subset into envelopes |
| `WrtingShedPro/Writing Shed Pro/Services/Sync/DryRun/DryRunSyncReport.swift` | Aggregates mapper output into deterministic diagnostics |
| `WrtingShedPro/WritingShedProTests/CKSyncEngineDryRunMapperTests.swift` | Unit tests for the first subset |

The `Services/Sync/DryRun` folder name is provisional. If the Xcode project uses manual file membership, add the files to the app and test targets deliberately.

## Compile-Time Guardrails

The first slice should use plain Swift/Foundation types only. It should not import CloudKit unless a later Phase 1 inspector type requires it.

Suggested constraints:

- `SyncRecordEnvelope` must not contain `CKRecord`.
- `SyncAssetPlaceholder` must describe the source field and byte count only.
- `CoreRecordMapper` must not hold a `ModelContext`.
- `CoreRecordMapper` must not call `modelContext.insert`, `modelContext.delete`, or `modelContext.save`.
- `DryRunSyncReport` must redact body content by default.

## Initial Type Sketch

```swift
struct SyncRecordEnvelope: Equatable {
    var recordType: String
    var recordName: String
    var fields: [String: SyncFieldValue]
    var assetPlaceholders: [SyncAssetPlaceholder]
    var diagnostics: [SyncMappingDiagnostic]
}

enum SyncFieldValue: Equatable {
    case string(String)
    case int(Int64)
    case bool(Bool)
    case date(Date)
    case bytesCount(Int)
    case null
}

struct SyncAssetPlaceholder: Equatable {
    var entityType: String
    var entityID: UUID
    var fieldName: String
    var byteCount: Int
}
```

This is not final API design; it is a bounded way to avoid `CKRecord` coupling during Phase 0.

## First Tests

Use `WrtingShedPro/WritingShedProTests/CKSyncEngineDryRunMapperTests.swift`.

Required tests:

- `testProjectRecordNameIsDeterministic`
- `testProjectMappingExcludesChildArrays`
- `testFolderMappingPreservesParentAndProjectIDs`
- `testRootFolderWithProjectDoesNotWarn`
- `testFolderWithMissingParentAndProjectWarnsButMaps`
- `testTextFileMappingSkipsUndoRedoData`
- `testTextFileMappingUsesCoverImagePlaceholder`
- `testVersionMappingUsesFormattedContentPlaceholder`
- `testVersionMappingPreservesReferenceMetadataCount`
- `testDryRunReportOrdersRecordsDeterministically`
- `testTombstoneRecordNameIsDeterministic`
- `testTombstoneCanCarryParentContextWithoutDeletingChildren`
- `testDryRunReportCountsTombstonesSeparatelyFromLiveRecords`
- `testUnsupportedRecordTypeReturnsDiagnostic`

## Acceptance Criteria

- Tests run in the existing `WritingShedProTests` target.
- No CloudKit import is needed for the Phase 0 mapper slice.
- No runtime UI or app launch code references the dry-run mapper.
- Mapper output is deterministic and redacted.
- Unsupported model types return diagnostics rather than disappearing silently.

## Stop Point

This slice is approved for implementation. Stop before runtime CKSyncEngine integration, CloudKit writes, SwiftData mutation imports, or any `@Model` schema changes.