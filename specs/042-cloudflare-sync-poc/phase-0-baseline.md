# Phase 0 Baseline: Cloudflare Sync POC

**Date**: 2026-07-04  
**Status**: Started  
**Scope**: Cloudflare backend skeleton only

## Purpose

Create the backend scaffolding for the Cloudflare sync proof of concept without changing Writing Shed Pro's production SwiftData/CloudKit sync path.

Phase 0 establishes:

- versioned sync endpoint routes
- D1 schema migration for operation-log tables
- package scripts for creating/migrating the POC database
- documented Worker bindings and secrets
- rollback boundary before any app integration

## Current Production State

The app still uses the existing SwiftData/CloudKit mirroring path. No app-side Cloudflare sync service has been added in Phase 0.

The existing Cloudflare Worker continues to serve support, messages, tutorial video, and manuscript analyst endpoints. The sync POC routes are dormant unless explicitly called.

## Added Backend Surface

New route prefix:

```text
/api/sync/v1
```

Phase 0 endpoints:

- `GET /api/sync/v1/health`
- `POST /api/sync/v1/bootstrap`
- `POST /api/sync/v1/push`
- `POST /api/sync/v1/pull`
- `POST /api/sync/v1/snapshot`

Only `/health` returns a success payload in Phase 0. The other endpoints validate method/auth/config and then return `501` until Phase 1 implements server behavior.

## New Files

- `cloudflare-worker/sql/sync_poc_schema.sql`
- `specs/042-cloudflare-sync-poc/phase-0-baseline.md`

## Modified Files

- `cloudflare-worker/src/index.js`
- `cloudflare-worker/package.json`
- `cloudflare-worker/wrangler.toml`
- `cloudflare-worker/README.md`

## D1 Schema

The schema creates operation-log tables with a `sync_` prefix:

- `sync_devices`
- `sync_projects`
- `sync_operations`
- `sync_tombstones`
- `sync_device_cursors`
- `sync_snapshots`
- `sync_conflicts`

The schema is intentionally separate from the existing messages database schema.

## Setup Commands

From `cloudflare-worker/`:

```bash
npm run sync:d1:create
npm run sync:d1:list
npm run sync:d1:migrate
npm run sync:d1:migrate:local
npm run sync:r2:create
npx wrangler secret put SYNC_POC_TOKEN
```

After creating the D1 database and R2 bucket, uncomment/fill the `SYNC_DB` and `SYNC_BLOBS` binding blocks in `wrangler.toml`.

## Cloudflare Resources Created

- D1 database: `wsp_sync_poc`
- D1 database id: `0e59e874-c89d-4175-ab77-5bcabf430c54`
- R2 bucket: `wsp-sync-poc`
- Worker secret: `SYNC_POC_TOKEN` uploaded remotely

`wrangler.toml` now has active bindings:

```toml
[[d1_databases]]
binding = "SYNC_DB"
database_name = "wsp_sync_poc"
database_id = "0e59e874-c89d-4175-ab77-5bcabf430c54"

[[r2_buckets]]
binding = "SYNC_BLOBS"
bucket_name = "wsp-sync-poc"
```

The D1 schema was applied locally and remotely. The remote migration executed 12 queries successfully and left the database at bookmark `00000001-00000006-0000509e-d1d05ab5739120a41df33cd67211d472`.

## Rollback Boundary

Phase 0 can be rolled back by reverting the files listed above. It does not require any CloudKit recovery action and does not touch user data.

If remote Cloudflare resources were created, rollback can leave them unused or delete them from Cloudflare Dashboard after confirming no other Worker depends on them.

## Validation

- `node --check src/index.js` passed.
- Editor diagnostics reported no errors for the modified Worker/config/schema files.
- Local Wrangler dev loaded `SYNC_DB` and `SYNC_BLOBS` bindings successfully.
- `GET http://localhost:8787/api/sync/v1/health` returned `200 OK` with `syncDbConfigured: true` and `syncBlobsConfigured: true`.
- Local health returned `authConfigured: false` because `SYNC_POC_TOKEN` is stored as a remote Worker secret and no local `.dev.vars` token has been created.

## Next Phase

Phase 1 should implement the server POC:

- append operations to D1
- assign per-project server sequence numbers
- implement pull cursors
- implement tombstone rejection/quarantine
- add local Worker tests or curl fixtures for rename/trash/stale update flows
