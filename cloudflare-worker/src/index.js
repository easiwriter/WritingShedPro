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
const MAX_ANALYST_CONTENT_LENGTH = 120000;
const ANALYST_CACHE_VERSION = "v1";
const ANALYST_CACHE_TTL_SECONDS = 60 * 60 * 24 * 30;

const ALLOWED_ANALYSIS_MODES = new Set(["file", "manuscript"]);
const ALLOWED_PROJECT_TYPES = new Set(["fiction", "poetry", "drama", "prose"]);
const ALLOWED_ANALYSIS_PROFILES = new Set([
    "poetry",
    "prose",
    "fiction",
    "shortFiction",
    "drama",
    "verseNovel",
]);
const ALLOWED_SEVERITY_FILTERS = new Set(["all", "high", "medium_high"]);

function isValidSubscriptionTier(subscriptionTier) {
    return typeof subscriptionTier === "string" && subscriptionTier.startsWith("analyst.monthly");
}

function isValidProfileForProjectType(analysisProfile, projectType, fictionClass) {
    if (projectType === "poetry") return analysisProfile === "poetry";
    if (projectType === "prose") return analysisProfile === "prose";
    if (projectType === "drama") return analysisProfile === "drama";

    if (projectType === "fiction") {
        if (fictionClass === "verseNovel") return analysisProfile === "verseNovel";
        if (fictionClass === "shortFiction") return analysisProfile === "shortFiction";
        return analysisProfile === "fiction";
    }

    return false;
}

function normalizeAnalystOptions(options) {
    const safeOptions = typeof options === "object" && options !== null ? options : {};
    const severity = ALLOWED_SEVERITY_FILTERS.has(safeOptions.severity)
        ? safeOptions.severity
        : "all";
    const focusAreas = Array.isArray(safeOptions.focusAreas)
        ? safeOptions.focusAreas.filter((item) => typeof item === "string" && item.trim().length > 0)
        : [];

    return { severity, focusAreas };
}

function normalizeAnalystMetadata(metadata) {
    const safeMetadata = typeof metadata === "object" && metadata !== null ? metadata : {};

    return {
        fileName: typeof safeMetadata.fileName === "string" ? safeMetadata.fileName.slice(0, 200) : undefined,
        fileCount: Number.isInteger(safeMetadata.fileCount) ? safeMetadata.fileCount : undefined,
        wordCount: Number.isInteger(safeMetadata.wordCount) ? safeMetadata.wordCount : undefined,
    };
}

function stableSeedFromString(value) {
    // Deterministic 32-bit FNV-1a hash, clamped to signed positive int range.
    let hash = 2166136261;
    const text = String(value || "");
    for (let i = 0; i < text.length; i++) {
        hash ^= text.charCodeAt(i);
        hash = Math.imul(hash, 16777619);
    }
    return Math.abs(hash >>> 0) % 2147483647;
}

async function sha256Hex(value) {
    const encoded = new TextEncoder().encode(String(value || ""));
    const digest = await crypto.subtle.digest("SHA-256", encoded);
    return Array.from(new Uint8Array(digest))
        .map((byte) => byte.toString(16).padStart(2, "0"))
        .join("");
}

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

        const url = new URL(request.url);
        const pathname = url.pathname;

        // Route to appropriate handler
        if (pathname.startsWith("/api/manuscript-analyst/review")) {
            return handleManuscriptAnalystReview(request, env);
        }

        // Default: support handler
        return handleSupport(request, env);
    },
};

async function handleManuscriptAnalystReview(request, env) {
    if (request.method !== "POST") {
        return jsonResponse({ error: "Method not allowed" }, 405);
    }

    let body;
    try {
        body = await request.json();
    } catch {
        return jsonResponse({ error: "Invalid JSON" }, 400);
    }

    const {
        analysisMode,
        projectType,
        fictionClass,
        analysisProfile,
        subscriptionTier,
        content,
        metadata,
        options,
    } = body;

    // Validate required fields
    const errors = [];
    if (!analysisMode || !ALLOWED_ANALYSIS_MODES.has(analysisMode)) errors.push("analysisMode");
    if (!projectType || !ALLOWED_PROJECT_TYPES.has(projectType)) errors.push("projectType");
    if (!analysisProfile || !ALLOWED_ANALYSIS_PROFILES.has(analysisProfile)) errors.push("analysisProfile");
    if (!isValidSubscriptionTier(subscriptionTier)) errors.push("subscriptionTier");
    if (typeof content !== "string" || content.trim().length === 0) errors.push("content");

    if (errors.length > 0) {
        return jsonResponse(
            { error: `Invalid or missing fields: ${errors.join(", ")}` },
            400
        );
    }

    if (!isValidProfileForProjectType(analysisProfile, projectType, fictionClass)) {
        return jsonResponse(
            { error: "analysisProfile does not match projectType/fictionClass" },
            400
        );
    }

    if (content.length > MAX_ANALYST_CONTENT_LENGTH) {
        return jsonResponse(
            { error: `content exceeds ${MAX_ANALYST_CONTENT_LENGTH} characters` },
            413
        );
    }

    const safeMetadata = normalizeAnalystMetadata(metadata);
    const safeOptions = normalizeAnalystOptions(options);

    const apiKey = env.LLM_API_KEY;
    if (!apiKey) {
        return jsonResponse({ error: "Service configuration error" }, 500);
    }

    try {
        const systemPrompt = buildAnalystSystemPrompt(analysisProfile, projectType, fictionClass);
        const userPrompt = buildAnalystUserPrompt(content, safeMetadata, safeOptions, analysisProfile);
        const cacheFingerprint = await sha256Hex(JSON.stringify({
            v: ANALYST_CACHE_VERSION,
            analysisMode,
            projectType,
            fictionClass: fictionClass || null,
            analysisProfile,
            content,
            metadata: safeMetadata,
            options: safeOptions,
        }));
        const cacheURL = new URL(request.url);
        cacheURL.searchParams.set("cache", ANALYST_CACHE_VERSION);
        cacheURL.searchParams.set("key", cacheFingerprint);
        const cacheKey = new Request(cacheURL.toString(), { method: "GET" });
        const cachedResponse = await caches.default.match(cacheKey);
        if (cachedResponse) {
            return new Response(cachedResponse.body, {
                status: cachedResponse.status,
                headers: {
                    ...Object.fromEntries(cachedResponse.headers.entries()),
                    "X-Analyst-Cache": "HIT",
                },
            });
        }

        const stableSeed = stableSeedFromString([
            analysisMode,
            projectType,
            fictionClass || "",
            analysisProfile,
            safeMetadata.fileName || "",
            content,
        ].join("|"));

        const startTime = Date.now();

        const llmResponse = await fetch("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: {
                "Authorization": `Bearer ${apiKey}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                model: "gpt-4o-mini",
                max_tokens: 1800,
                temperature: 0,
                seed: stableSeed,
                response_format: { type: "json_object" },
                messages: [
                    {
                        role: "system",
                        content: systemPrompt,
                    },
                    {
                        role: "user",
                        content: userPrompt,
                    },
                ],
            }),
        });

        if (!llmResponse.ok) {
            const error = await llmResponse.text();
            console.error("OpenAI API error:", llmResponse.status, error);
            if (llmResponse.status === 429) {
                return jsonResponse(
                    { error: "Rate limited - please try again later", softCapState: "throttled" },
                    429
                );
            }
            return jsonResponse({ error: "Analysis service temporarily unavailable" }, 502);
        }

        const data = await llmResponse.json();
        const analysisText = data.choices?.[0]?.message?.content ?? "";
        const analysisTimeMs = Date.now() - startTime;
        const tokensUsed = data.usage?.total_tokens ?? 0;

        // Parse the analysis response
        const analysis = parseAnalysisResponse(analysisText, analysisProfile);

        const response = jsonResponse(
            {
                status: "success",
                timestamp: new Date().toISOString(),
                reviewId: crypto.randomUUID(),
                analysis: {
                    summary: analysis.summary,
                    overallSentiment: analysis.sentiment,
                    analysisProfile: analysisProfile,
                    suggestedFocusOrder: analysis.focusAreas,
                },
                suggestions: analysis.suggestions,
                metadata: {
                    contentAnalyzed: content.length,
                    tokensUsed: tokensUsed,
                    analysisTimeMs: analysisTimeMs,
                    model: "gpt-4o-mini",
                    softCapState: calculateSoftCapState(tokensUsed, subscriptionTier),
                },
            },
            200,
            {
                "Cache-Control": `public, max-age=${ANALYST_CACHE_TTL_SECONDS}`,
                "X-Analyst-Cache": "MISS",
            }
        );

        await caches.default.put(cacheKey, response.clone());
        return response;
    } catch (err) {
        console.error("Manuscript analyst request failed:", err);
        return jsonResponse({ error: "Analysis service temporarily unavailable" }, 502);
    }
}

async function handleSupport(request, env) {
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
}

function jsonResponse(body, status, extraHeaders = {}) {
    return new Response(JSON.stringify(body), {
        status,
        headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            ...extraHeaders,
        },
    });
}

function buildAnalystSystemPrompt(analysisProfile, projectType, fictionClass) {
    const basePrompt = `You are an expert editorial assistant specializing in ${analysisProfile} writing. Your role is to provide constructive, specific feedback on writing samples.

You must provide critique only. Do not rewrite or generate replacement passages for the user.

Feedback should be practical and manual-edit oriented.

Treat every claim as an editorial reading, not an objective verdict.

Do not present subjective value judgments as settled facts. Prefer grounded language such as "may", "might", "could", "seems", "suggests", or "reads as" when discussing effect or quality.

Anchor every suggestion in observable textual evidence. Quote a brief phrase from the source in the observation or rationale when possible.

Only mark something as high severity when it clearly interferes with comprehension, coherence, or stated intent. If a point is debatable, taste-based, or subtle, prefer medium or low severity.

Do not manufacture balance. If the writing is strong in an area, say so plainly. If a concern is uncertain, admit the uncertainty.

Avoid contradictory judgments about the same passage unless you explicitly explain the tension as an interpretive ambiguity.

You provide feedback in JSON format with the following structure:
{
    "summary": "2-3 sentence editorial reading of the writing's strengths and possible areas for revision",
  "sentiment": "encouraging|mixed|critical",
  "focusAreas": ["area1", "area2", "area3"],
  "suggestions": [
    {
      "id": "unique_id",
      "category": "category_name",
      "severity": "high|medium|low",
            "location": "Line N or Line N-M (must use source line numbers) or null",
            "observation": "an evidence-grounded editorial reading of what you noticed",
            "suggestion": "a possible revision focus or craft experiment",
            "rationale": "why this may matter for reader experience or authorial intent"
    }
  ]
}

CRITICAL LINE-NUMBER RULES:
- The user content is provided with explicit line-number prefixes in the form "0001 | text".
- If you cite a location, you MUST use those exact numbers as "Line N" or "Line N-M".
- Do not estimate or invent line numbers.
- If no precise location applies, set "location" to null.

OUTPUT QUALITY RULES:
- Keep the summary concise, specific, and non-grandiose.
- Focus areas must be supported by the actual suggestions you provide.
- Prefer fewer, better-supported suggestions over a long list of weak ones.
- Never imply that your reading is the only valid reading of the text.`;

    if (analysisProfile === "poetry") {
        return basePrompt + `

POETRY-SPECIFIC GUIDANCE:
- Focus on: imagery, diction, lineation, rhythm and meter, stanza architecture, sonic texture, emotional coherence
- Categories: Poetic Form & Lineation, Rhythm, Meter & Sound, Imagery & Precision, Structure & Organization, Emotional Coherence
- Evaluate line breaks and their effectiveness
- Comment on use of literary devices (metaphor, simile, alliteration, etc.)
- Consider adherence to declared poetic form if applicable
- De-emphasize plot/character diagnostics unless narrative elements are explicit`;
    } else if (analysisProfile === "prose") {
        return basePrompt + `

PROSE-SPECIFIC GUIDANCE:
- Focus on: clarity, structure, transitions, voice consistency, exposition density, readability
- Categories: Clarity & Language, Essay / Reflective Structure, Pacing & Structure, Tone & Voice, Engagement
- Evaluate whether the writing communicates ideas effectively
- Look for redundancy and opportunities for tightening
- Consider reader engagement and pacing
- Do not force fiction-style character/plot analysis`;
    } else if (analysisProfile === "fiction") {
        return basePrompt + `

FICTION-SPECIFIC GUIDANCE:
- Focus on: plot logic, character motivation, scene effectiveness, pacing, tension, continuity, stakes, voice, POV control
- Categories: Pacing & Structure, Character Development, Narrative Consistency, Tone & Voice, Engagement
- Evaluate story momentum and tension
- Assess character consistency and believability
- Comment on show-vs-tell balance`;
    } else if (analysisProfile === "shortFiction") {
        return basePrompt + `

SHORT FICTION-SPECIFIC GUIDANCE:
- Focus on: compression, economy, payoff, scene intent, momentum, stakes
- Categories: Pacing & Structure, Character Development, Narrative Consistency, Tone & Voice, Engagement
- Weight concise execution and ending effectiveness more heavily than long-form pacing`;
    } else if (analysisProfile === "drama") {
        return basePrompt + `

DRAMA-SPECIFIC GUIDANCE:
- Focus on: scene dynamics, dialogue effectiveness, stage clarity, dramatic tension, objectives and escalation
- Categories: Dramatic Function, Dialogue, Scene Dynamics, Character Development, Engagement
- Evaluate stageable moments and technical feasibility
- Assess dialogue patterns and subtext
- Consider act/scene structure`;
    } else if (analysisProfile === "verseNovel") {
        return basePrompt + `

VERSE NOVEL-SPECIFIC GUIDANCE:
- Focus on: narrative movement and poetic craft together, including continuity, scene clarity, lineation, imagery, rhythm, and compression
- Categories: Narrative Consistency, Poetic Form & Lineation, Rhythm, Meter & Sound, Character Development, Engagement
- Evaluate both prose storytelling AND poetic technique
- Assess whether verse enhances or obstructs the story
- Balance poem-level and narrative-level feedback`;
    }
    return basePrompt;
}

function buildAnalystUserPrompt(content, metadata, options, analysisProfile) {
    let prompt = `Please analyze the following ${analysisProfile} writing sample:\n\n`;
    
    if (metadata) {
        if (metadata.fileName) prompt += `[File: ${metadata.fileName}]\n`;
        if (metadata.wordCount) prompt += `[Word Count: ${metadata.wordCount}]\n`;
    }
    
    const numberedContent = addSourceLineNumbers(content || "");
    prompt += `\nSource (line-numbered):\n${numberedContent}\n\n`;
    
    if (options?.focusAreas && options.focusAreas.length > 0) {
        prompt += `Focus particularly on: ${options.focusAreas.join(", ")}\n\n`;
    }
    
    prompt += `Provide structured feedback as JSON. Limit to ${options?.severity === "high" ? "high-severity" : "all"} issues unless severity is specified as 'all'. Do not provide rewritten text.`;
    
    return prompt;
}

function addSourceLineNumbers(content) {
    const lines = String(content).replace(/\r\n?/g, "\n").split("\n");
    return lines
        .map((line, idx) => `${String(idx + 1).padStart(4, "0")} | ${line}`)
        .join("\n");
}

function parseAnalysisResponse(text, analysisProfile) {
    try {
        // Try to extract JSON from the response
        const jsonMatch = text.match(/\{[\s\S]*\}/);
        if (!jsonMatch) {
            return createFallbackAnalysis(analysisProfile);
        }
        
        const parsed = JSON.parse(jsonMatch[0]);
        
        return {
            summary: parsed.summary || "Analysis completed.",
            sentiment: parsed.sentiment || "mixed",
            focusAreas: parsed.focusAreas || [],
            suggestions: (parsed.suggestions || []).map((s, idx) => ({
                id: s.id || `sugg_${idx}`,
                category: s.category || "General",
                severity: s.severity || "medium",
                location: s.location || null,
                observation: s.observation || "",
                suggestion: s.suggestion || "",
                rationale: s.rationale || "",
            })),
        };
    } catch (e) {
        console.error("Failed to parse analysis response:", e);
        return createFallbackAnalysis(analysisProfile);
    }
}

function createFallbackAnalysis(analysisProfile) {
    return {
        summary: "Analysis completed. Review the suggestions below.",
        sentiment: "mixed",
        focusAreas: [],
        suggestions: [],
    };
}

function calculateSoftCapState(tokensUsed, subscriptionTier) {
    // Conservative monthly limits
    const monthlyTokenLimit = 100_000;
    const monthlyReviewLimit = 50;
    
    // For now, always return "normal" — actual tracking would be
    // implemented on the server side with a database
    return "normal";
}
