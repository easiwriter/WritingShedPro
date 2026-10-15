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

6. Configure App Store Server API access for Manuscript Analyst:
   - In App Store Connect, open **Users and Access > Integrations > In-App Purchase**.
   - Create an In-App Purchase key and download its `.p8` private key.
   - Copy the key ID and issuer ID shown by App Store Connect.
   - Store all three values as Worker secrets:
   ```bash
   npx wrangler secret put APPLE_IAP_KEY_ID
   npx wrangler secret put APPLE_IAP_ISSUER_ID
   npx wrangler secret put APPLE_IAP_PRIVATE_KEY < /path/to/SubscriptionKey_KEYID.p8
   ```
   Production verification is the default. For a separate sandbox Worker only, set
   `APPLE_IAP_ENVIRONMENT = "Sandbox"` and the matching
   `APPLE_APP_BUNDLE_ID` in that Worker's variables. Never enable sandbox
   verification on the production Worker.

7. Deploy:
   ```bash
   npm run messages:deploy
   ```
   This prints the Worker URL (e.g. `https://wsp-support.<your-subdomain>.workers.dev`).

8. Update the endpoint URL in the app's `SupportService.swift` to match.

## Manuscript Analyst authorization

Every `POST /api/manuscript-analyst/review` request must include the
`X-Apple-Transaction-ID` header. The app obtains this identifier only from a
locally verified current StoreKit entitlement.

Before reading from the analysis cache or calling the LLM, the Worker queries
Apple's production App Store Server API and requires all of the following:

- the exact `com.writingshedpro.manuscriptanalyst` product;
- the `com.appworks.writingshedpro` bundle;
- a production auto-renewable subscription;
- the transaction ID supplied by the app;
- a future expiration date; and
- no revocation or superseding upgrade.

Missing Apple credentials fail closed with HTTP 503. Invalid, expired, or
revoked subscriptions fail with HTTP 401 or 403.

Requests with no transaction header are identified as older app versions. The
Worker returns a zero-token `update_required` result that those clients display
as an instruction to update Writing Shed Pro from the App Store. Current
clients recognize that status as an app-update error and do not save it as an
analysis. The Worker does not read from the analysis cache or call the LLM for
these requests.

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

## Sales API

Public reporting endpoint:

- `POST /api/sales` with `transactionID`, `productID`, and `purchaseDate`.
- A Full Access conversion also sends `trialTransactionID` and `trialPurchaseDate`.

The Worker ignores the client-supplied purchase date when recording a sale. It
queries Apple's App Store Server API and requires the returned transaction ID,
product, app bundle, and environment to match, with no revocation. Apple-signed
purchase dates, ownership type, transaction type, price, currency, offers, and
original transaction IDs are stored in `verified_store_transactions`.

The app persists each successfully verified transaction ID and does not report
it again on later entitlement refreshes or app launches. Failed requests remain
eligible for retry. This persisted state is only a network optimization and is
not used to grant entitlements.

Verification failures are stored in `transaction_verification_failures`.
HTTP 401/403 responses are classified as `appleRejected`; service and
configuration failures are classified as `temporaryFailure`. Repeated failures
update the same transaction row and increment its attempt count. A later
successful verification marks the row resolved. The authenticated
`GET /api/admin/sales` response includes the latest 100 failure records for the
Messages Operator sales screen.

The sales event table is idempotent by StoreKit transaction ID. Legacy module
and Manuscript Analyst purchases retain their existing monthly totals. Version
19+ trial cohorts are reported as:

- `trial`: trials activated in the selected month that have not converted.
- `convertedTrial`: trials activated in the selected month that later bought Full Access.
- `fullAccess`: direct Full Access purchases with no preceding trial, grouped by purchase month.

`ensureSalesTables` adds the nullable conversion columns to an existing D1
database on first use. Apply the schema command when creating a fresh database.
Deploy the Worker before releasing the app version that reports trial and Full
Access products:

```bash
npm run messages:deploy
```

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
