# Phase 2: Debug App Client

**Date**: 2026-07-04  
**Status**: Started  
**Scope**: Debug-only WSP client for the deployed Cloudflare sync POC

## Purpose

Add a small app-side client that can call the deployed Cloudflare sync POC without changing production SwiftData/CloudKit sync behavior.

This phase proves that Writing Shed Pro can serialize a tiny project graph and communicate with the Worker from the app. It does not apply remote changes back into SwiftData yet.

## Implemented App Surface

New service:

- `WrtingShedPro/Writing Shed Pro/Services/CloudflareSyncPOCService.swift`

Debug UI:

- `SyncDiagnosticsView` now includes a DEBUG/simulator-only `Cloudflare Sync POC` section.

Controls:

- `Check Cloudflare Health`
- `Push/Pull Project Sample`
- `Create Remote Snapshot`
- `Preview Remote Import`

## Endpoint

Default endpoint:

```text
https://wsp-support.wsp-support.workers.dev/api/sync/v1
```

Override with UserDefaults key:

```text
cloudflareSyncPOCEndpoint
```

## Token Handling

The app does not contain the POC bearer token. For Catalyst local testing, set it with:

```bash
defaults write com.appworks.writingshedpro cloudflareSyncPOCToken "<SYNC_POC_TOKEN>"
```

Remove it with:

```bash
defaults delete com.appworks.writingshedpro cloudflareSyncPOCToken
```

The service reads the token from UserDefaults key:

```text
cloudflareSyncPOCToken
```

## Current Push/Pull Behavior

`Push/Pull Project Sample` selects the first non-trashed project from the current `@Query` project list and sends:

- one `Project` upsert operation
- up to 12 `Folder` upsert operations, traversed in project order
- up to 30 `TextFile` upsert operations from those folders

It then pulls operations after the bootstrap sequence and reports accepted/rejected counts, latest sequence, and a read-only remote summary by entity type and operation type.

The payload is intentionally small and text-only. Text file content is capped to 20,000 characters for the POC.

## Current Snapshot Behavior

`Create Remote Snapshot` bootstraps the selected project if needed, then posts a compact JSON snapshot to `/snapshot` for storage in R2.

The snapshot includes:

- project identity and basic metadata
- the same bounded folder sample
- the same bounded text-file sample
- the sample limits used to create it

The app reports the returned server sequence, R2 key, and content hash prefix. It does not read the snapshot back or apply it locally.

## Current Import Preview Behavior

`Preview Remote Import` pulls remote operations from sequence 0 and reconstructs the latest project/folder/text-file state in memory.

It reports:

- project name
- folder count
- text-file count
- total imported text characters
- remote operation count
- latest server sequence

It writes nothing to SwiftData. This is intentional: the current WSP SwiftData store is CloudKit-backed, so creating even a test import project would export that project through production CloudKit. Actual materialization needs a separate explicit debug store or a user-confirmed CloudKit-visible test import path.

## Safety Boundaries

- CloudKit remains the production sync path.
- The client is exposed only in DEBUG/simulator diagnostics UI.
- The service does not apply pulled operations locally.
- The service does not mutate local SwiftData models.
- Import preview reconstructs remote state in memory only.
- The POC token is not stored in source code.
- No schema changes were made to app SwiftData models.

## Validation

- `get_errors` reported no errors for `CloudflareSyncPOCService.swift`.
- `get_errors` reported no errors for `SyncDiagnosticsView.swift`.

## Next Steps

1. User/manual build and launch a DEBUG/Catalyst build.
2. Set `cloudflareSyncPOCToken` in UserDefaults.
3. Open Sync Troubleshooting and run `Check Cloudflare Health`.
4. Run `Push/Pull Project Sample` against non-critical test data.
5. Run `Create Remote Snapshot` and confirm the Worker returns an R2 key/hash.
6. Run `Preview Remote Import` and confirm the counts match the pushed sample.
7. Add explicit local/remote curl fixtures or Worker tests for repeatable server verification.
8. In a later phase, add a separate test project importer/applier rather than applying pulled operations to production projects directly.
