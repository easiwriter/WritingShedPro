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
    if (!analysisMode) errors.push("analysisMode");
    if (!projectType) errors.push("projectType");
    if (!analysisProfile) errors.push("analysisProfile");
    if (!subscriptionTier) errors.push("subscriptionTier");
    if (!content || content.trim().length === 0) errors.push("content");

    if (errors.length > 0) {
        return jsonResponse(
            { error: `Missing required fields: ${errors.join(", ")}` },
            400
        );
    }

    const apiKey = env.LLM_API_KEY;
    if (!apiKey) {
        return jsonResponse({ error: "Service configuration error" }, 500);
    }

    try {
        const systemPrompt = buildAnalystSystemPrompt(analysisProfile, projectType, fictionClass);
        const userPrompt = buildAnalystUserPrompt(content, metadata, options, analysisProfile);

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
                temperature: 0.3,
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

        return jsonResponse(
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
            200
        );
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

function jsonResponse(body, status) {
    return new Response(JSON.stringify(body), {
        status,
        headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
    });
}

function buildAnalystSystemPrompt(analysisProfile, projectType, fictionClass) {
    const basePrompt = `You are an expert editorial assistant specializing in ${analysisProfile} writing. Your role is to provide constructive, specific feedback on writing samples.

You provide feedback in JSON format with the following structure:
{
  "summary": "2-3 sentence overview of the writing's strengths and key areas for improvement",
  "sentiment": "encouraging|mixed|critical",
  "focusAreas": ["area1", "area2", "area3"],
  "suggestions": [
    {
      "id": "unique_id",
      "category": "category_name",
      "severity": "high|medium|low",
      "location": "specific location or null",
      "observation": "what you noticed",
      "suggestion": "what to do about it",
      "rationale": "why this matters"
    }
  ]
}`;

    if (analysisProfile === "poetry") {
        return basePrompt + `

POETRY-SPECIFIC GUIDANCE:
- Focus on: imagery, lineation, meter and rhythm, rhyme scheme, poetic forms, emotional resonance
- Categories: Poetic Form & Lineation, Imagery & Language, Sound & Rhythm, Emotional Impact, Structure & Organization
- Evaluate line breaks and their effectiveness
- Comment on use of literary devices (metaphor, simile, alliteration, etc.)
- Consider adherence to declared poetic form if applicable`;
    } else if (analysisProfile === "prose") {
        return basePrompt + `

PROSE-SPECIFIC GUIDANCE:
- Focus on: clarity, sentence variety, paragraph structure, argument flow, readability
- Categories: Clarity & Directness, Sentence Structure, Paragraph Development, Argument Flow, Style & Voice
- Evaluate whether the writing communicates ideas effectively
- Look for redundancy and opportunities for tightening
- Consider reader engagement and pacing`;
    } else if (analysisProfile === "fiction") {
        return basePrompt + `

FICTION-SPECIFIC GUIDANCE:
- Focus on: plot structure, character development, pacing, dialogue, world-building
- Categories: Plot & Structure, Character Development, Dialogue, Pacing, Narrative Voice
- Evaluate story momentum and tension
- Assess character consistency and believability
- Comment on show-vs-tell balance`;
    } else if (analysisProfile === "drama") {
        return basePrompt + `

DRAMA-SPECIFIC GUIDANCE:
- Focus on: scene dynamics, dialogue authenticity, stage directions, dramatic tension, character interaction
- Categories: Scene Dynamics, Dialogue, Stage Directions, Character Interaction, Dramatic Tension
- Evaluate stageable moments and technical feasibility
- Assess dialogue patterns and subtext
- Consider act/scene structure`;
    } else if (analysisProfile === "verseNovel") {
        return basePrompt + `

VERSE NOVEL-SPECIFIC GUIDANCE:
- Focus on: narrative coherence, poetic craft, character through verse, sustained tension
- Categories: Narrative Continuity, Poetic Craft, Character Voice, Verse Patterns, Dramatic Momentum
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
    
    prompt += `\n${content}\n\n`;
    
    if (options?.focusAreas && options.focusAreas.length > 0) {
        prompt += `Focus particularly on: ${options.focusAreas.join(", ")}\n\n`;
    }
    
    prompt += `Provide structured feedback as JSON. Limit to ${options?.severity === "high" ? "high-severity" : "all"} issues unless severity is specified as 'all'.`;
    
    return prompt;
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
