# Phase 1: Cloudflare Sync Server POC

**Date**: 2026-07-04  
**Status**: Started  
**Scope**: Worker/D1/R2 server behavior only

## Purpose

Turn the Phase 0 sync route skeleton into a minimal inspectable server authority for one-project sync testing.

This phase still does not change Writing Shed Pro app sync behavior. The app remains on the existing SwiftData/CloudKit path until a later debug-only app client is added.

## Implemented Endpoints

All endpoints use the `/api/sync/v1` prefix.

### `GET /health`

Reports service status, API version, phase, and whether `SYNC_DB`, `SYNC_BLOBS`, and `SYNC_POC_TOKEN` are configured.

### `POST /bootstrap`

Authenticated. Creates or updates:

- `sync_devices`
- `sync_projects`
- `sync_device_cursors`

Returns the current project `latestSequence`.

### `POST /head`

Authenticated. Performs a cheap change check for one project/device without returning operation payloads. Returns the project `latestSequence`, the device cursor, the client's supplied `lastKnownSequence`, and whether the server has newer changes.

### `POST /push`

Authenticated. Accepts up to 2000 operations per request. For each accepted operation it:

- assigns the next per-project server sequence
- appends a row to `sync_operations`
- records tombstones for `delete`, `trash`, and `tombstone` operation types
- clears tombstones for `restore` and `untrash` operation types
- records stale updates after tombstone as `sync_conflicts`
- returns accepted and rejected operation lists

A mixed accepted/rejected push returns HTTP `207`.

### `POST /pull`

Authenticated. Returns operations after `afterSequence`, capped to 500 operations per response. Updates the device cursor with the latest pulled sequence.

### `POST /peek`

Authenticated. Returns the same operation page shape as `/pull`, but does not update the device cursor. This supports apply previews and dry-run diagnostics where the client must inspect pending operations before acknowledging them.

### `POST /snapshot`

Authenticated. Stores a JSON snapshot payload in R2 and records metadata in `sync_snapshots`.

## Request Shapes

### Bootstrap

```json
{
  "projectId": "project-uuid",
  "projectName": "Example Project",
  "deviceId": "device-uuid",
  "deviceName": "MacBook Pro"
}
```

### Push

```json
{
  "projectId": "project-uuid",
  "projectName": "Example Project",
  "deviceId": "device-uuid",
  "deviceName": "MacBook Pro",
  "operations": [
    {
      "id": "operation-uuid",
      "entityType": "Project",
      "entityId": "project-uuid",
      "operationType": "rename",
      "baseSequence": 0,
      "clientTimestamp": "2026-07-04T00:00:00Z",
      "payload": { "name": "New Name" }
    }
  ]
}
```

### Pull

```json
{
  "projectId": "project-uuid",
  "deviceId": "device-uuid",
  "afterSequence": 0,
  "limit": 100
}
```

### Peek

```json
{
  "projectId": "project-uuid",
  "deviceId": "device-uuid",
  "afterSequence": 123,
  "limit": 100
}
```

### Head

```json
{
  "projectId": "project-uuid",
  "deviceId": "device-uuid",
  "deviceName": "MacBook Pro",
  "lastKnownSequence": 123
}
```

### Snapshot

```json
{
  "projectId": "project-uuid",
  "deviceId": "device-uuid",
  "snapshot": { "project": { "id": "project-uuid" } }
}
```

## Current Limitations

- Server sequence assignment is intentionally simple for the POC and should be hardened before production-scale concurrent writers.
- There is no production auth model yet; `SYNC_POC_TOKEN` is a shared test bearer token.
- Conflict resolution is tombstone-focused only.
- The app does not call these endpoints yet.
- Local testing of authenticated endpoints needs a local dev token, separate from the remote secret.

## Validation

- `node --check src/index.js` passed after implementation.
- Editor diagnostics reported no errors for `cloudflare-worker/src/index.js`.
- Local Wrangler dev loaded `SYNC_DB`, `SYNC_BLOBS`, and a disposable local `SYNC_POC_TOKEN`.
- Local `/health` returned phase 1 with database, blob, and auth configuration present.
- Local bootstrap, push rename, pull, trash, stale-update rejection, and snapshot upload requests succeeded.
- Stale update after tombstone was recorded as a rejected operation with `reason: stale_update_after_tombstone` and the current `latestSequence`.
- Worker deployed successfully to `https://wsp-support.wsp-support.workers.dev`.
- Remote `GET /api/sync/v1/health` returned phase 1 with `syncDbConfigured`, `syncBlobsConfigured`, and `authConfigured` all `true`.

## Next Steps

1. Add local curl fixtures or Worker tests for bootstrap/push/pull/tombstone flows.
2. Add a debug-only app client in Phase 2.
