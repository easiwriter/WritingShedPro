# Phase 1: Read-Only CloudKit Inspector Plan

**Status**: Initial scaffold implemented
**Created**: 2026-07-09
**Depends on**:

- [phase-0-review-checklist.md](phase-0-review-checklist.md)
- [phase-0-dry-run-mapper-plan.md](phase-0-dry-run-mapper-plan.md)
- [phase-1-token-policy.md](phase-1-token-policy.md)
- [phase-1-existing-coredata-zone-boundary.md](phase-1-existing-coredata-zone-boundary.md)

## Purpose

Define the first CloudKit-facing work for the CKSyncEngine replacement while keeping the app safe. Phase 1 may inspect CloudKit zones, records, and local mapping reports. It must not write CloudKit records, mutate SwiftData, migrate data, or interfere with the existing sync stack.

## Implementation Status

Initial test-only/service-layer scaffold added:

- `CloudKitReadOnlyInspector`
- `ReadOnlyCloudKitClient`
- `SystemReadOnlyCloudKitClient`
- `SyncInspectorReport`
- `CloudKitZoneInventoryItem`

The scaffold is not wired into app launch or production UI. The system client only checks account status and reads private database zone names. Tests use a fake client and do not contact CloudKit.

Current tests verify:

- Expected zone classification for `_defaultZone`, `com.apple.coredata.cloudkit.zone`, `WritingShedProSyncZone`, and foreign zones.
- Missing proposed zone is warning-only.
- Unavailable iCloud account does not attempt zone reads.
- Local dry-run counts can be included in a redacted inspector report without manuscript/project content.
- The real system client can be manually verified by running `CloudKitReadOnlyInspectorTests/testSystemClientReadOnlyInspectorCanRunTwiceWhenExplicitlyEnabled` with `WSP_RUN_REAL_CLOUDKIT_INSPECTOR=1`. This test is skipped by default.

Manual system-client verification command:

```bash
WSP_RUN_REAL_CLOUDKIT_INSPECTOR=1 xcodebuild test -project "WrtingShedPro/Writing Shed Pro.xcodeproj" -scheme "Writing Shed Pro" -destination 'platform=iOS,id=00008030-000A55161E38802E' -only-testing:"Writing Shed ProTests/CloudKitReadOnlyInspectorTests/testSystemClientReadOnlyInspectorCanRunTwiceWhenExplicitlyEnabled"
```

Xcode manual path:

1. Edit the test scheme.
2. Add environment variable `WSP_RUN_REAL_CLOUDKIT_INSPECTOR` with value `1` for the Test action.
3. Run only `CloudKitReadOnlyInspectorTests/testSystemClientReadOnlyInspectorCanRunTwiceWhenExplicitlyEnabled` on a signed-in real device.
4. Remove the environment variable after the verification run so normal tests skip the real CloudKit read.

Remaining Phase 1 work before CloudKit-backed diagnostics:

- Keep token policy limited to in-memory tokens for any future Phase 1 database/zone change reads.
- Review the documented migration boundary for existing Core Data zone records.
- Optionally add record count sampling only where it can remain metadata-only and asset-safe.

## Explicit Non-Goals

- No CKSyncEngine event loop.
- No CloudKit saves, deletes, zone creation, or zone deletion.
- No SwiftData inserts, updates, deletes, or relationship repairs.
- No migration from existing `NSPersistentCloudKitContainer` records.
- No automatic seed/default creation changes.
- No production UI unless guarded behind diagnostics/internal build gates.

## Inspector Responsibilities

| Area | Responsibility |
| --- | --- |
| Account/database status | Report iCloud account availability and private database reachability |
| Zone listing | List zones in the app container and flag expected, legacy, and foreign zones |
| Record type sampling | Count records by type where CloudKit APIs allow practical sampling |
| Existing Core Data zone awareness | Detect `com.apple.coredata.cloudkit.zone` without modifying it |
| Proposed CKSyncEngine zone awareness | Check whether the proposed new zone exists, but do not create it |
| Dry-run comparison | Compare local dry-run record counts with remote sample counts when record types overlap |
| Diagnostics | Produce redacted, exportable text suitable for support/debugging |

## Read-Only Safety Rules

- Use `CKFetchRecordZonesOperation`, `CKFetchDatabaseChangesOperation`, or equivalent read APIs only.
- Do not call any CloudKit operation that saves records, deletes records, modifies zones, or changes subscriptions.
- Do not advance or persist production change tokens during early diagnostics unless that token store is explicitly test-only.
- Do not use read failures as a trigger for local reset, zone delete, or cleanup.
- Do not query full rich-text payload assets unless the user explicitly requests a deep diagnostic and the command remains read-only.

## Proposed Components

| Component | Responsibility | Runtime gate |
| --- | --- | --- |
| `CloudKitReadOnlyInspector` | CloudKit read-only operations and result normalization | Diagnostics-only |
| `CloudKitZoneInventory` | Plain value describing discovered zones | Diagnostics-only |
| `CloudKitRecordSample` | Record counts/sample metadata by type | Diagnostics-only |
| `SyncInspectorReport` | Combined local dry-run and remote CloudKit snapshot | Diagnostics-only |
| `ReadOnlyCloudKitClient` | Protocol wrapper to make tests deterministic | Test/diagnostics-only |

Names are provisional. The implementation should follow project naming conventions when code begins.

## Expected Zone Classification

| Zone | Classification | Handling |
| --- | --- | --- |
| `com.apple.coredata.cloudkit.zone` | Existing SwiftData/Core Data sync zone | Inspect only; never modify in Phase 1 |
| `_defaultZone` | CloudKit default zone | Inspect only |
| `WritingShedProSyncZone` | Proposed CKSyncEngine zone | Report exists/missing; do not create |
| Any other custom zone | Foreign/legacy zone | Report and warn only; no delete action in Phase 1 |

## Report Shape

Example diagnostic output:

```text
CKSyncEngine read-only inspector
Account: available
Database: private reachable

Zones:
- com.apple.coredata.cloudkit.zone: existing SwiftData zone
- _defaultZone: default zone
- WritingShedProSyncZone: missing, not created

Remote samples:
- Core Data zone: record count sample unavailable without Core Data metadata decode
- Foreign zones: none

Local dry-run:
- Project: 11
- Folder: 64
- TextFile: 143
- Version: 151
- Assets placeheld: 151 formattedContent, 3 coverImageData

Warnings:
- Proposed CKSyncEngine zone is not present. This is expected before Phase 2/3 setup.
```

## Test Requirements

- Inspector classifies expected, default, proposed, and foreign zones correctly.
- Inspector does not invoke save/delete zone operations in tests.
- Inspector handles iCloud account unavailable without suggesting destructive recovery.
- Inspector can combine a local dry-run report with a remote zone inventory.
- Inspector redacts manuscript content and does not fetch CKAsset body data by default.

## Acceptance Criteria

- [x] A diagnostics-only service path can produce a read-only report.
- [x] The report distinguishes existing SwiftData/Core Data zones from the proposed CKSyncEngine zone.
- [x] Missing proposed zone is informational, not an error.
- [x] Foreign zones are warnings only; Phase 1 provides no delete button.
- [x] Running the fake-client inspector twice makes no CloudKit or SwiftData changes.
- [x] Running the skipped-by-default system-client test twice against a real device/account is manually verified as read-only.

Manual verification completed on 2026-07-09: the opt-in test above ran with `WSP_RUN_REAL_CLOUDKIT_INSPECTOR=1` and did not skip. The environment variable was removed afterward so normal test runs skip the real CloudKit read.

## Gate Before Phase 2

Phase 2 import dry-run must not start until:

- Phase 0 review checklist decisions are accepted or updated.
- Phase 1 inspector proves it can read CloudKit state without side effects.
- A test-only token policy is decided for any database/zone change reads: see [phase-1-token-policy.md](phase-1-token-policy.md).
- The proposed new CKSyncEngine zone name is confirmed.
- The migration boundary from the existing Core Data zone is explicitly documented: see [phase-1-existing-coredata-zone-boundary.md](phase-1-existing-coredata-zone-boundary.md).
