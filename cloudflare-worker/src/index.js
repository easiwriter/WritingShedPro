// WSP Support — Cloudflare Worker
// Proxies user support queries to the OpenAI API.
// API key stored as Cloudflare secret (LLM_API_KEY).
// System prompt auto-generated from docs/SUPPORT_KNOWLEDGE_BASE.md
// by build-prompt.py — do NOT edit system-prompt.txt by hand.

import SYSTEM_PROMPT from "./system-prompt.txt";

// In-memory rate limiting (per-worker instance). For production with
// multiple edge locations, consider Cloudflare KV or Rate Limiting rules.
const rateLimitMap = new Map();
const RATE_LIMIT_MAX = 5;           // requests per window
const RATE_LIMIT_WINDOW_MS = 3600000; // 1 hour

const MAX_QUERY_LENGTH = 2000;

function isRateLimited(ip) {
    const now = Date.now();
    const entry = rateLimitMap.get(ip);
    if (!entry || now - entry.windowStart > RATE_LIMIT_WINDOW_MS) {
        rateLimitMap.set(ip, { windowStart: now, count: 1 });
        return false;
    }
    entry.count++;
    if (entry.count > RATE_LIMIT_MAX) {
        return true;
    }
    return false;
}

export default {
    async fetch(request, env) {
        // CORS preflight
        if (request.method === "OPTIONS") {
            return new Response(null, {
                status: 204,
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "POST, OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type",
                    "Access-Control-Max-Age": "86400",
                },
            });
        }

        if (request.method !== "POST") {
            return jsonResponse({ error: "Method not allowed" }, 405);
        }

        // Rate limiting
        const ip = request.headers.get("CF-Connecting-IP") || "unknown";
        if (isRateLimited(ip)) {
            return jsonResponse({ error: "Too many requests. Please try again later." }, 429);
        }

        // Parse and validate input
        let body;
        try {
            body = await request.json();
        } catch {
            return jsonResponse({ error: "Invalid JSON" }, 400);
        }

        const { query, reportType, deviceInfo, appVersion } = body;

        if (!query || typeof query !== "string" || query.trim().length === 0) {
            return jsonResponse({ error: "Missing required field: query" }, 400);
        }
        if (!reportType || typeof reportType !== "string") {
            return jsonResponse({ error: "Missing required field: reportType" }, 400);
        }

        const trimmedQuery = query.slice(0, MAX_QUERY_LENGTH);
        const safeDeviceInfo = typeof deviceInfo === "string" ? deviceInfo.slice(0, 200) : "Unknown";
        const safeAppVersion = typeof appVersion === "string" ? appVersion.slice(0, 50) : "Unknown";

        // Call OpenAI
        const apiKey = env.LLM_API_KEY;
        if (!apiKey) {
            return jsonResponse({ error: "Service configuration error" }, 500);
        }

        try {
            const llmResponse = await fetch("https://api.openai.com/v1/chat/completions", {
                method: "POST",
                headers: {
                    "Authorization": `Bearer ${apiKey}`,
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({
                    model: "gpt-4o-mini",
                    max_tokens: 800,
                    temperature: 0.3,
                    messages: [
                        { role: "system", content: SYSTEM_PROMPT },
                        {
                            role: "user",
                            content: `[${reportType}] ${trimmedQuery}\n\nDevice: ${safeDeviceInfo}\nApp Version: ${safeAppVersion}`,
                        },
                    ],
                }),
            });

            if (!llmResponse.ok) {
                console.error("LLM API error:", llmResponse.status);
                return jsonResponse({ error: "Support service temporarily unavailable" }, 502);
            }

            const data = await llmResponse.json();
            const answer =
                data.choices?.[0]?.message?.content ??
                "We could not generate a response at this time. Please tap \"Ask Developer\" to email us directly.";

            return jsonResponse({ response: answer }, 200);
        } catch (err) {
            console.error("LLM request failed:", err);
            return jsonResponse({ error: "Support service temporarily unavailable" }, 502);
        }
    },
};

function jsonResponse(body, status) {
    return new Response(JSON.stringify(body), {
        status,
        headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
    });
}
