# WSP Messages Operator

Simple operator app for maintaining support messages and tutorial videos stored in Cloudflare.

## Setup

1. Enter endpoint and admin token in the app:
   - Endpoint: e.g. https://wsp-support.writingshedpro.workers.dev
   - Token: value of ADMIN_API_TOKEN configured in the worker.
2. Use Refresh to load messages.
3. In Videos tab: upload and delete tutorial videos from the `tutorials/` bucket path.
4. In Messages tab: create, edit, and archive support messages.

Notes:
- Archiving keeps messages in the database.
- User-side deletion in Writing Shed Pro is per-device and local only.
