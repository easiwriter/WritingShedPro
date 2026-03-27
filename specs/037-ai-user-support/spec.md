# Feature 037: AI User Support

**Status:** Planning  
**Branch:** TBD  
**Date:** 2026-03-27  
**Priority:** Medium  
**Dependencies:** Feature 019 (Settings Menu — Contact Support)  
**Platform:** iOS 16+, macOS 13+ (Mac Catalyst)  
**LLM Provider:** OpenAI (API key available since 2025-03-24; stored as Cloudflare Worker secret — never in source)

---

## Overview

Enhance the existing Contact Support flow with an AI-powered first-response system. When a user submits a support query (bug report or suggestion), the app sends it to a Cloudflare Worker proxy, which forwards it to an LLM API with a system prompt containing app documentation, known issues, and troubleshooting steps. The AI-generated response is displayed in-app immediately. Users can still escalate to email if the AI response doesn't resolve their issue.

### User Value

- **Instant Help**: Users get an immediate, contextual response instead of waiting for an email reply
- **24/7 Availability**: AI support works any time, regardless of developer availability
- **Reduced Support Load**: Common questions and known issues resolved automatically
- **Graceful Fallback**: Users can always escalate to direct email support

---

## Architecture

### System Design

```
┌─────────────────────┐
│  Writing Shed Pro    │
│  (iOS / macOS)       │
│                      │
│  ContactSupportView  │
│         │            │
│    POST /support     │
└─────────┬───────────┘
          │ HTTPS
          ▼
┌─────────────────────┐
│  Cloudflare Worker   │
│                      │
│  - Rate limiting     │
│  - Input validation  │
│  - API key (secret)  │
│  - System prompt     │
│         │            │
│    LLM API call      │
└─────────┬───────────┘
          │ HTTPS
          ▼
┌─────────────────────┐
│  LLM Provider       │
│  (OpenAI / Anthropic)│
│                      │
│  Returns response    │
└─────────────────────┘
```

### Why Cloudflare Worker

- **API key security**: The LLM API key is stored as a Cloudflare secret, never present in the app binary. Embedding keys in the app — even encrypted — is insecure because the key must be decrypted at runtime and can be extracted via binary inspection, memory debugging, or network proxying.
- **Free tier**: 100,000 requests/day on the free plan — more than sufficient for support queries
- **Low latency**: Edge-deployed globally
- **Simple**: ~30 lines of code, no infrastructure to manage
- **Rate limiting & cost control**: Enforce per-device or per-IP limits server-side

---

## Requirements

### Functional Requirements

#### FR-1: Cloudflare Worker Proxy
- [ ] FR-1.1: Create a Cloudflare Worker that accepts POST requests with support query data
- [ ] FR-1.2: Store LLM API key as a Cloudflare Worker secret (never in app code)
- [ ] FR-1.3: Validate incoming request structure (require `query`, `reportType`, `deviceInfo`, `appVersion`)
- [ ] FR-1.4: Forward query to LLM API with a system prompt containing app documentation and known issues
- [ ] FR-1.5: Return the LLM response as JSON to the app
- [ ] FR-1.6: Return appropriate error responses (400 for bad input, 429 for rate limit, 500 for LLM failure)

#### FR-2: Rate Limiting & Abuse Prevention
- [ ] FR-2.1: Implement per-IP rate limiting (e.g., 5 requests per hour)
- [ ] FR-2.2: Enforce a maximum input length for query text (e.g., 2000 characters)
- [ ] FR-2.3: Reject requests missing required fields
- [ ] FR-2.4: Retain the existing robot-check (arithmetic challenge) in the app before sending

#### FR-3: System Prompt & Knowledge Base
- [ ] FR-3.1: Craft a system prompt that presents responses as Writing Shed Pro support (no mention of AI in user-facing output)
- [ ] FR-3.2: Include structured app documentation, feature descriptions, and common workflows in the system prompt
- [ ] FR-3.3: Include known issues and workarounds
- [ ] FR-3.4: Instruct the LLM to recommend contacting the developer for issues it cannot resolve
- [ ] FR-3.5: Instruct the LLM to never fabricate features that don't exist
- [ ] FR-3.6: System prompt is stored and maintained in the Cloudflare Worker, not in the app
- [ ] FR-3.7: Maintain a structured **Known Issues Catalog** as part of the system prompt, with entries containing: bug ID, symptoms (keywords/phrases a user might say), status (open/fixed/workaround), affected versions, fix version (if applicable), and workaround text
- [ ] FR-3.8: Instruct the LLM to match user-reported symptoms against the catalog and surface relevant known issues, workarounds, or version-specific fixes
- [ ] FR-3.9: Instruct the LLM to ask targeted diagnostic questions when a query doesn't clearly match a known issue (e.g., app version, device type, steps taken)
- [ ] FR-3.10: The catalog is developer-maintained and updated via Worker redeployment — no app update required

#### FR-4: App Integration — Support Flow
- [ ] FR-4.1: The existing Contact Support form and Send button are retained; tapping Send submits the query to the Cloudflare Worker (no separate AI-branded button)
- [ ] FR-4.2: On tap, POST the query to the Cloudflare Worker endpoint
- [ ] FR-4.3: Show a loading indicator while waiting for the response
- [ ] FR-4.4: Display the response in a scrollable view within the app (no AI branding)
- [ ] FR-4.5: After displaying the response, offer two actions:
  - "This Helped" — dismisses the support view
  - "Ask Developer" — proceeds to the existing email flow with the original query pre-filled
- [ ] FR-4.6: Handle network errors gracefully — if the service is unreachable, fall back to the email flow with the message: "The support service is temporarily unavailable. You can email the developer instead."

#### FR-5: Privacy & Transparency
- [ ] FR-5.1: Display a brief notice before sending: "Your query will be reviewed and a response provided. No personal data is stored."
- [ ] FR-5.2: Do not send any user-identifiable information beyond device model, OS version, and app version
- [ ] FR-5.3: The Cloudflare Worker must not log or persist query content beyond the request lifecycle
- [ ] FR-5.4: Update the app's privacy policy to mention automated support processing

---

## User Interface

### Modified Contact Support Flow

The existing `ContactSupportView` retains its current form. The Send button submits to the Cloudflare Worker instead of (or before) opening the mail compose:

```
┌──────────────────────────────────┐
│         Contact Support          │
│──────────────────────────────────│
│  [Bug Report]  [Suggestion]      │
│                                  │
│  Subject: ___________________    │
│                                  │
│  Details:                        │
│  ┌────────────────────────────┐  │
│  │                            │  │
│  └────────────────────────────┘  │
│                                  │
│  Steps to reproduce (optional):  │
│  ┌────────────────────────────┐  │
│  │                            │  │
│  └────────────────────────────┘  │
│                                  │
│  Device: iPad — iPadOS 18.3      │
│  App Version: 2.1 (45)          │
│                                  │
│  What is 3 + 7?  [__]           │
│                                  │
│  ┌──────────────────────────┐   │
│  │    📨  Send              │   │
│  └──────────────────────────┘   │
└──────────────────────────────────┘
```

### Support Response View

Displayed after the response is received:

```
┌──────────────────────────────────┐
│        Support Response          │
│──────────────────────────────────│
│                                  │
│  Based on your report, here's    │
│  what I'd suggest:               │
│                                  │
│  1. Go to Settings > ...         │
│  2. Try restarting the app...    │
│  3. If the issue persists...     │
│                                  │
│  (scrollable)                    │
│                                  │
│──────────────────────────────────│
│  ┌────────────┐ ┌──────────────┐│
│  │ This Helped│ │Ask Developer ││
│  └────────────┘ └──────────────┘│
└──────────────────────────────────┘
```

---

## Technical Approach

### Cloudflare Worker (Server Side)

The Worker is a lightweight JavaScript function deployed to Cloudflare's edge network:

```javascript
export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const { query, reportType, deviceInfo, appVersion } = await request.json();

    if (!query || !reportType) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400,
        headers: { "Content-Type": "application/json" }
      });
    }

    // Rate limiting via Cloudflare's built-in or KV-based check
    // ... (implementation detail)

    const llmResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${env.LLM_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        max_tokens: 800,
        messages: [
          { role: "system", content: env.SYSTEM_PROMPT },
          { role: "user", content: `[${reportType}] ${query}\n\nDevice: ${deviceInfo}\nApp Version: ${appVersion}` }
        ]
      })
    });

    const data = await llmResponse.json();
    const answer = data.choices?.[0]?.message?.content ?? "I'm sorry, I couldn't generate a response. Please email the developer directly.";

    return new Response(JSON.stringify({ response: answer }), {
      headers: { "Content-Type": "application/json" }
    });
  }
};
```

### App Side (Swift)

#### Network Service

A new `AISupportService` handles communication with the Cloudflare Worker:

```swift
import Foundation

@Observable
class AISupportService {
    var isLoading = false
    var response: String?
    var error: String?

    private let endpoint = URL(string: "https://support.writing-shed.com/api/support")!

    func submitQuery(reportType: String, subject: String, details: String,
                     deviceInfo: String, appVersion: String) async {
        isLoading = true
        response = nil
        error = nil

        let query = "\(subject)\n\n\(details)"
        let payload: [String: String] = [
            "query": query,
            "reportType": reportType,
            "deviceInfo": deviceInfo,
            "appVersion": appVersion
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 30

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                error = "Unexpected response"
                isLoading = false
                return
            }

            if httpResponse.statusCode == 429 {
                error = "Too many requests. Please try again later or email the developer."
            } else if httpResponse.statusCode != 200 {
                error = "Service temporarily unavailable. Please email the developer."
            } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let aiResponse = json["response"] as? String {
                response = aiResponse
            } else {
                error = "Could not parse response. Please email the developer."
            }
        } catch {
            self.error = "Could not reach support service. Please email the developer."
        }

        isLoading = false
    }
}
```

#### View Changes

`ContactSupportView` is modified to:
1. Replace the single "Send" button with two buttons: "Ask AI Assistant" and "Email Developer"
2. Add a new `AIResponseView` sheet that displays the AI response
3. Both paths still require passing the robot check

---

## Costs & Limits

| Item | Estimate |
|---|---|
| Cloudflare Worker | Free tier: 100K requests/day |
| LLM API (gpt-4o-mini) | ~$0.15 per 1M input tokens, ~$0.60 per 1M output tokens |
| Estimated cost per query | ~$0.001 (less than 1/10th of a cent) |
| Rate limit | 5 queries per IP per hour |
| Max input length | 2000 characters |
| Max response tokens | 800 (~600 words) |

---

## Security Considerations

1. **API key never in app**: The LLM API key exists only as a Cloudflare Worker secret
2. **Input validation**: Worker validates request structure and enforces max input length
3. **Rate limiting**: Per-IP rate limiting prevents abuse and cost runaway
4. **No PII stored**: Queries are not logged or persisted by the Worker
5. **Robot check retained**: The arithmetic challenge remains as a client-side gate
6. **HTTPS only**: All communication over TLS
7. **CORS restricted**: Worker only accepts requests from the app's expected User-Agent / origin

---

## Testing

### Unit Tests
- [ ] `AISupportService` handles successful responses
- [ ] `AISupportService` handles 429 rate-limit responses
- [ ] `AISupportService` handles network errors gracefully
- [ ] `AISupportService` handles malformed JSON responses
- [ ] Input validation rejects empty queries

### Integration Tests
- [ ] End-to-end: app → Worker → LLM → response displayed
- [ ] Rate limiting triggers after threshold exceeded
- [ ] Fallback to email works when AI service is down

### Manual Testing
- [ ] Submit a bug report via AI and verify response is relevant
- [ ] Submit a suggestion via AI and verify response is relevant
- [ ] Verify "This Helped" dismisses the view
- [ ] Verify "Email Developer" opens the mail compose with pre-filled content
- [ ] Verify behaviour when device is offline
- [ ] Verify robot check still blocks automated submissions

---

## Implementation Plan

### Phase 1: Cloudflare Worker
1. Create Cloudflare Worker project
2. Implement request validation and LLM proxy
3. Add rate limiting (Cloudflare Rate Limiting or KV-based)
4. Craft and test the system prompt with app documentation
5. Deploy and verify with curl/Postman

### Phase 2: App Integration
1. Create `AISupportService` with `@Observable`
2. Modify `ContactSupportView` to add "Ask AI Assistant" button
3. Create `AIResponseView` for displaying the AI response
4. Add "This Helped" / "Email Developer" actions
5. Handle loading, error, and offline states
6. Add privacy notice before sending

### Phase 3: Knowledge Base & Tuning
1. Compile app documentation into the system prompt
2. Add known issues and workarounds
3. Test with real-world support queries
4. Iterate on system prompt based on response quality

---

## Change Log

- **2026-03-27**: Initial specification created
- **2026-03-27**: Removed all user-facing AI branding; support flow uses existing Send button; escalation button renamed to "Ask Developer"; error/privacy messages neutralised
- **2026-03-27**: Added FR-3.7–3.10: Known Issues Catalog with symptom matching, diagnostic questions, developer-maintained via Worker redeployment
