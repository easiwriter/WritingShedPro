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

4. Deploy:
   ```bash
   npm run deploy
   ```
   This prints the Worker URL (e.g. `https://wsp-support.<your-subdomain>.workers.dev`).

5. Update the endpoint URL in the app's `SupportService.swift` to match.

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
