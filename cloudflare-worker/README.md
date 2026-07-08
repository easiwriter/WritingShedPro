# WSP Support — Cloudflare Worker

Proxies user support queries from Writing Shed Pro to the OpenAI API.

## Setup

1. Install dependencies:
   ```bash
   cd cloudflare-worker
   npm install
   ```

2. Log in to Cloudflare (one-time):
   ```bash
   npx wrangler login
   ```

3. Store the OpenAI API key as a secret:
   ```bash
   npx wrangler secret put LLM_API_KEY
   # Paste your key at the interactive prompt (input is hidden)
   ```

4. Create/configure the D1 database for support messages:
   ```bash
   # Check auth/session first
   npm run cf:whoami

   # Create once (or use existing)
   npm run messages:d1:create

   # List databases (verify name and id)
   npm run messages:d1:list

   # Apply schema (remote D1)
   npm run messages:d1:migrate

   # Optional: apply schema to local preview DB
   npm run messages:d1:migrate:local
   ```
   Then add the returned database id/name to `wrangler.toml` under a `d1_databases`
   binding named `MESSAGES_DB`.

   If you see `Authentication error [code: 10000]`, refresh session and retry:
   ```bash
   npx wrangler logout
   npx wrangler login
   npm run cf:whoami
   ```

5. Set admin token secret (used by operator app/panel):
   ```bash
   npx wrangler secret put ADMIN_API_TOKEN
   ```

6. Deploy:
   ```bash
   npm run messages:deploy
   ```
   This prints the Worker URL (e.g. `https://wsp-support.<your-subdomain>.workers.dev`).

7. Update the endpoint URL in the app's `SupportService.swift` to match.

## Cloudflare Sync POC

Feature `042-cloudflare-sync-poc` adds `/api/sync/v1/*` routes for a sync proof of concept. The current server POC does not change production app sync; WSP still uses its existing SwiftData/CloudKit path until a later debug-only app client is added.

Sync POC routes:

- `GET /api/sync/v1/health` -> reports route version and whether optional sync bindings/secrets are configured.
- `POST /api/sync/v1/bootstrap`
- `POST /api/sync/v1/push`
- `POST /api/sync/v1/pull`
- `POST /api/sync/v1/snapshot`

The POST routes require `Authorization: Bearer <SYNC_POC_TOKEN>`. They support bootstrap, operation push, cursor-based pull, and snapshot upload for POC testing.

Create the optional POC resources:

```bash
npm run sync:d1:create
npm run sync:d1:list
npm run sync:r2:create
npx wrangler secret put SYNC_POC_TOKEN
```

After `sync:d1:create`, copy the returned database id into the commented `SYNC_DB` block in `wrangler.toml`, then uncomment the `SYNC_DB` and `SYNC_BLOBS` bindings.

Apply the schema:

```bash
npm run sync:d1:migrate
npm run sync:d1:migrate:local
```

Local health check:

```bash
npm run build
npx wrangler dev
curl http://localhost:8787/api/sync/v1/health
```

## Cloudflare Sync Production Foundation

The production sync foundation starts with D1/R2 resources that are separate from the scratch POC resources above. The schema in `sql/sync_production_schema.sql` defines users, devices, projects, entitlements, migration runs, operations, cursors, tombstones, assets, rollout flags, audit events, and support actions. It is a server foundation only: no app-side SwiftData mutation is wired to this schema yet.

Create production resources only when intentionally starting the production implementation phase:

```bash
npm run sync:prod:d1:create
npm run sync:prod:d1:list
npm run sync:prod:r2:create
```

Apply the production foundation schema:

```bash
npm run sync:prod:d1:migrate
npm run sync:prod:d1:migrate:local
```

Validate the local production foundation contract without contacting Cloudflare:

```bash
npm run sync:prod:validate
npm run sync:prod:smoke
npm run sync:prod:validate:all
```

The validator reads `sync-production-foundation-contract.json` for the production route fail-closed contract. The `validate:all` command also loads `sql/sync_production_schema.sql` into an in-memory SQLite database to catch schema syntax errors before D1 migration.

The smoke check imports the Worker locally with mocked production bindings and exercises public `/health` binding-status reporting, unknown-route and wrong-method rejection, protected-route missing-auth, wrong-token, unconfigured-token, unconfigured-DB, and invalid-JSON rejection before route-specific DB work, `/identity/check` read-only write denial, `/migration/preflight` plan-only readiness, `/assets/preflight` missing-blob readiness blocking, transfer-ready preflight without R2 upload, and oversized-manifest rejection before DB/R2 work, `/apply/preflight` oversized-window rejection before DB/cursor work and SwiftData-applier-not-implemented blocking, `/orchestrator/eligibility` lifecycle-not-wired blocking, `/release/readiness` release-enable-endpoint blocking, plus `/users/summary` aggregate response shape, no-store caching, and absence of D1 mutation calls. It also fails if the production contract contains a route without deliberate route-specific smoke coverage.

Production routes must remain disabled by default until environment separation, auth, migration planning, asset transfer, applier rollback, monitoring, support runbooks, and release drills are implemented and verified.

The production foundation contract is read-only: D1 writes, R2 writes/uploads, SwiftData mutation, cursor advancement, and rollout enablement are not allowed in this phase.

JSON responses default to `Cache-Control: no-store`; callers may only override caching intentionally with explicit response headers.

Asset preflight accepts at most 1000 manifest items per request.

Apply preflight accepts at most 500 operations per window.

Production foundation routes:

Only production health is public. All production foundation POST routes require `Authorization: Bearer <SYNC_PRODUCTION_TOKEN>` and require `SYNC_PRODUCTION_DB` to be configured. Asset preflight also requires `SYNC_PRODUCTION_BLOBS` to be configured before asset transfer can be considered. The health route only reports whether those bindings exist and performs no writes.

- `GET /api/sync/production/v1/health` -> reports production sync foundation version and whether production D1/R2/token bindings are configured. This route performs no writes.
- `POST /api/sync/production/v1/users/summary` -> reports privacy-safe aggregate user and device counts for enrolled production sync identities. This route requires `Authorization: Bearer <SYNC_PRODUCTION_TOKEN>`, exposes no document content, project names, attachment payloads, or secrets, and performs no writes.
- `POST /api/sync/production/v1/identity/check` -> checks an already-registered user/device/project entitlement against the production schema. This route requires `Authorization: Bearer <SYNC_PRODUCTION_TOKEN>`, performs no writes, and always reports `writesEnabled: false` in the current foundation phase.
- `POST /api/sync/production/v1/migration/preflight` -> evaluates supplied CloudKit project inventory, consent, backup/export, user/device/project entitlement, and source-state signals before a migration run can be planned. This route performs no writes, does not apply operations, and always reports `readyToApplyMigration: false` in the current foundation phase.
- `POST /api/sync/production/v1/assets/preflight` -> validates a supplied asset manifest, production blob binding, and user/device/project entitlement before asset transfer can be attempted. This route performs no R2 upload, no D1 write, no operation apply, and always reports `readyToAdvanceCursor: false` until a later verified upload/checksum path exists.
- `POST /api/sync/production/v1/apply/preflight` -> validates an operation-window shape against existing identity, entitlement, project, and device cursor rows before production apply can be attempted. This route performs no D1 write, does not mutate app SwiftData, and always reports `readyToApply: false` until a flagged SwiftData applier exists and commits before cursor advancement.
- `POST /api/sync/production/v1/orchestrator/eligibility` -> evaluates whether a launch, foreground, network-recovery, silent-push, background-refresh, or manual trigger is allowed for an existing user/device/project/cursor state. This route performs no writes, schedules no lifecycle work, does not apply operations, and always reports `eligibleToRun: false` until the production applier and rollout gates exist.
- `POST /api/sync/production/v1/release/readiness` -> evaluates supplied release evidence plus production environment and rollout flag rows before production writes can be considered. This route performs no writes, enables no flags, and always reports `readyToRelease: false` until a separate audited enable path exists.

Set the production token only when intentionally exercising production foundation routes:

```bash
npx wrangler secret put SYNC_PRODUCTION_TOKEN
```

## Messages API

Public:
- `GET /api/messages` -> list active messages.
- `GET /api/tutorial-videos` -> list available tutorial videos from R2 (`tutorials/` prefix).

Admin (Bearer token required: `Authorization: Bearer <ADMIN_API_TOKEN>`):
- `GET /api/admin/messages?includeArchived=1`
- `POST /api/admin/messages` with `{ "title": "...", "body": "..." }`
- `PUT /api/admin/messages/:id` with any of `{ "title", "body", "isArchived" }`
- `DELETE /api/admin/messages/:id` archives message (keeps row in DB).
- `GET /api/admin/tutorial-videos`
- `POST /api/admin/tutorial-videos?fileName=...` for single uploads (up to ~95 MB)
- `POST /api/admin/tutorial-videos/multipart/start?fileName=...`
- `PUT /api/admin/tutorial-videos/multipart/:uploadId/:partNumber?key=...`
- `POST /api/admin/tutorial-videos/multipart/complete` with `{ "key", "uploadId", "parts": [{ "partNumber", "etag" }] }`
- `POST /api/admin/tutorial-videos/multipart/abort` with `{ "key", "uploadId" }`
- `PUT /api/admin/tutorial-videos/order` with `{ "orderedKeys": ["tutorials/foo.mp4", ...] }`
- `DELETE /api/admin/tutorial-videos/:key`

## Local Development

```bash
npx wrangler dev
```

Test with curl:
```bash
curl -X POST http://localhost:8787 \
  -H "Content-Type: application/json" \
  -d '{"query":"Footnotes disappeared after undo","reportType":"Bug Report","deviceInfo":"iPad — iPadOS 18.3","appVersion":"2.1 (45)"}'
```

## Updating the Knowledge Base

The system prompt is auto-generated from `docs/SUPPORT_KNOWLEDGE_BASE.md`.
To update:

1. Edit `docs/SUPPORT_KNOWLEDGE_BASE.md` (the canonical source of truth).
2. Deploy (the build step runs automatically):
   ```bash
   npm run deploy
   ```

The `build-prompt.py` script strips markdown formatting, prepends the agent
rules, and writes `src/system-prompt.txt`. The worker imports this file at
deploy time. **Do not edit `src/system-prompt.txt` by hand.**
No app update required — changes take effect immediately.

## Rate Limiting

Default: 5 requests per IP per hour. Adjust `RATE_LIMIT_MAX` and `RATE_LIMIT_WINDOW_MS` in `src/index.js`.
