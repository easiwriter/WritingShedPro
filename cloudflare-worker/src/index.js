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
const MAX_DIAGNOSTICS_LENGTH = 12000;
const MAX_ANALYST_CONTENT_LENGTH = 120000;
const ANALYST_CACHE_VERSION = "v7";
const ANALYST_CACHE_TTL_SECONDS = 60 * 60 * 24 * 30;
const MAX_MESSAGE_TITLE_LENGTH = 200;
const MAX_MESSAGE_BODY_LENGTH = 4000;
const TUTORIAL_VIDEO_ORDER_KEY = "tutorials/_order.json";
const MAX_SINGLE_UPLOAD_BYTES = 95 * 1024 * 1024;
const DEFAULT_MULTIPART_PART_SIZE_BYTES = 20 * 1024 * 1024;

const PRODUCT_SALE_TYPES = new Map([
    ["com.writingshedpro.prosewriter", "prose"],
    ["com.writingshedpro.poetrywriter", "poetry"],
    ["com.writingshedpro.fictionwriter", "fiction"],
    ["com.writingshedpro.dramawriter", "drama"],
    ["com.writingshedpro.allinbundle", "bundle"],
    ["com.writingshedpro.manuscriptanalyst", "manuscriptAnalyst"],
]);

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
    const poetryFormName = typeof safeMetadata.poetryFormName === "string"
        ? safeMetadata.poetryFormName.slice(0, 120)
        : undefined;
    const poetryFormRequirementsSummary = typeof safeMetadata.poetryFormRequirementsSummary === "string"
        ? safeMetadata.poetryFormRequirementsSummary.slice(0, 500)
        : undefined;

    return {
        fileName: typeof safeMetadata.fileName === "string" ? safeMetadata.fileName.slice(0, 200) : undefined,
        fileCount: Number.isInteger(safeMetadata.fileCount) ? safeMetadata.fileCount : undefined,
        wordCount: Number.isInteger(safeMetadata.wordCount) ? safeMetadata.wordCount : undefined,
        poetryFormName,
        poetryFormRequirementsSummary,
        preservePoetryForm: typeof safeMetadata.preservePoetryForm === "boolean"
            ? safeMetadata.preservePoetryForm
            : undefined,
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

function publicationHistoryResponse(query) {
    const normalizedQuery = query.toLowerCase();
    const asksForPublicationHistory = /\bpublications?\s+history\b/.test(normalizedQuery)
        || /\bview\s+all\s+publication\s+submissions\b/.test(normalizedQuery);

    if (!asksForPublicationHistory) return null;

    return `To view Publication History:
1. Return to the project list.
2. Tap or click the ellipsis button for the project.
3. Choose Show Publication History.
4. Review the submitted file name, date submitted, publication type, publication name, and status.
5. Tap or click a row to open Submission Details, or use Print to print the complete history.`;
}

export default {
    async fetch(request, env) {
        // CORS preflight
        if (request.method === "OPTIONS") {
            return new Response(null, {
                status: 204,
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type, Authorization",
                    "Access-Control-Max-Age": "86400",
                },
            });
        }

        const url = new URL(request.url);
        const pathname = url.pathname;

        if (pathname.startsWith("/tutorials/") || pathname.startsWith("/samples/")) {
            return handleR2Asset(request, env, pathname);
        }

        // Route to appropriate handler
        if (pathname.startsWith("/api/manuscript-analyst/review")) {
            return handleManuscriptAnalystReview(request, env);
        }

        if (pathname === "/api/messages") {
            return handleGetMessages(request, env);
        }

        if (pathname === "/api/sales") {
            return handleRecordSale(request, env);
        }

        if (pathname === "/api/tutorial-videos") {
            return handleListTutorialVideos(request, env);
        }

        if (pathname.startsWith("/api/admin/messages")) {
            return handleAdminMessages(request, env, pathname);
        }

        if (pathname === "/api/admin/sales") {
            return handleAdminSales(request, env);
        }

        if (pathname.startsWith("/api/admin/tutorial-videos")) {
            return handleAdminTutorialVideos(request, env, pathname);
        }

        // Default: support handler
        return handleSupport(request, env);
    },
};

async function handleR2Asset(request, env, pathname) {
    if (request.method !== "GET" && request.method !== "HEAD") {
        return new Response("Method not allowed", { status: 405 });
    }

    const bucket = env.TUTORIAL_VIDEOS;
    if (!bucket) {
        return new Response("Video storage unavailable", { status: 500 });
    }

    const key = decodeURIComponent(pathname.replace(/^\//, ""));
    const head = await bucket.head(key);
    if (!head) {
        return new Response("Not found", { status: 404 });
    }

    const rangeHeader = request.headers.get("range");
    const parsedRange = parseByteRange(rangeHeader, head.size);
    if (rangeHeader && !parsedRange) {
        return new Response("Requested Range Not Satisfiable", {
            status: 416,
            headers: {
                "Content-Range": `bytes */${head.size}`,
                "Accept-Ranges": "bytes",
            },
        });
    }

    const object = parsedRange
        ? await bucket.get(key, {
            range: {
                offset: parsedRange.start,
                length: parsedRange.end - parsedRange.start + 1,
            },
        })
        : await bucket.get(key);

    if (!object) {
        return new Response("Not found", { status: 404 });
    }

    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set("etag", object.httpEtag);
    headers.set("cache-control", "public, max-age=31536000, immutable");
    headers.set("accept-ranges", "bytes");

    if (parsedRange) {
        headers.set("content-range", `bytes ${parsedRange.start}-${parsedRange.end}/${head.size}`);
        headers.set("content-length", String(parsedRange.end - parsedRange.start + 1));
    } else if (!headers.has("content-length")) {
        headers.set("content-length", String(head.size));
    }

    if (!headers.has("content-type")) {
        if (key.endsWith(".mov")) {
            headers.set("content-type", "video/quicktime");
        } else if (key.endsWith(".mp4")) {
            headers.set("content-type", "video/mp4");
        } else if (key.endsWith(".wsp")) {
            headers.set("content-type", "application/octet-stream");
        } else {
            headers.set("content-type", "application/octet-stream");
        }
    }

    return new Response(request.method === "HEAD" ? null : object.body, {
        status: parsedRange ? 206 : 200,
        headers,
    });
}

function parseByteRange(rangeHeader, totalSize) {
    if (!rangeHeader || typeof rangeHeader !== "string") {
        return null;
    }

    const trimmed = rangeHeader.trim();
    if (!trimmed.startsWith("bytes=")) {
        return null;
    }

    const firstRange = trimmed.slice(6).split(",")[0]?.trim();
    if (!firstRange) {
        return null;
    }

    const [startStr, endStr] = firstRange.split("-");
    if (startStr === undefined || endStr === undefined) {
        return null;
    }

    // Suffix range: bytes=-500
    if (startStr === "") {
        const suffixLength = Number.parseInt(endStr, 10);
        if (!Number.isFinite(suffixLength) || suffixLength <= 0) {
            return null;
        }
        const clampedLength = Math.min(suffixLength, totalSize);
        const start = totalSize - clampedLength;
        const end = totalSize - 1;
        return { start, end };
    }

    const start = Number.parseInt(startStr, 10);
    if (!Number.isFinite(start) || start < 0 || start >= totalSize) {
        return null;
    }

    // Open-ended range: bytes=500-
    if (endStr === "") {
        return { start, end: totalSize - 1 };
    }

    const end = Number.parseInt(endStr, 10);
    if (!Number.isFinite(end) || end < start) {
        return null;
    }

    return {
        start,
        end: Math.min(end, totalSize - 1),
    };
}

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
        const systemPrompt = buildAnalystSystemPrompt(analysisProfile, projectType, fictionClass, safeMetadata);
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
                max_tokens: 4000,
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

    const { query, reportType, deviceInfo, appVersion, diagnosticsSnapshot } = body;

    if (!query || typeof query !== "string" || query.trim().length === 0) {
        return jsonResponse({ error: "Missing required field: query" }, 400);
    }
    if (!reportType || typeof reportType !== "string") {
        return jsonResponse({ error: "Missing required field: reportType" }, 400);
    }

    const trimmedQuery = query.slice(0, MAX_QUERY_LENGTH);
    const commandResponse = publicationHistoryResponse(trimmedQuery);
    if (commandResponse) {
        return jsonResponse({ response: commandResponse }, 200);
    }

    const safeDiagnostics = typeof diagnosticsSnapshot === "string"
        ? diagnosticsSnapshot.slice(0, MAX_DIAGNOSTICS_LENGTH)
        : "";
    const safeDeviceInfo = typeof deviceInfo === "string" ? deviceInfo.slice(0, 200) : "Unknown";
    const safeAppVersion = typeof appVersion === "string" ? appVersion.slice(0, 50) : "Unknown";
    const diagnosticsBlock = safeDiagnostics.trim().length > 0
        ? `\n\nDiagnostics Snapshot:\n${safeDiagnostics}`
        : "";

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
                        content: `[${reportType}] ${trimmedQuery}\n\nDevice: ${safeDeviceInfo}\nApp Version: ${safeAppVersion}${diagnosticsBlock}`,
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

async function handleGetMessages(request, env) {
    if (request.method !== "GET") {
        return jsonResponse({ error: "Method not allowed" }, 405);
    }

    if (!env.MESSAGES_DB) {
        return jsonResponse({ error: "Messages service unavailable" }, 500);
    }

    await ensureMessagesCriticalColumn(env);

    try {
        const { results } = await env.MESSAGES_DB
            .prepare(`
                SELECT id, title, body, created_at, updated_at, is_critical
                FROM messages
                WHERE is_archived = 0
                ORDER BY updated_at DESC
            `)
            .all();

        const messages = (results || []).map((row) => ({
            id: row.id,
            title: row.title,
            body: row.body,
            createdAt: row.created_at,
            updatedAt: row.updated_at,
            isCritical: row.is_critical === 1,
        }));

        return jsonResponse({ messages }, 200, { "Cache-Control": "no-store" });
    } catch (err) {
        console.error("Failed to fetch messages:", err);
        return jsonResponse({ error: "Messages service unavailable" }, 502);
    }
}

async function handleListTutorialVideos(request, env) {
    if (request.method !== "GET") {
        return jsonResponse({ error: "Method not allowed" }, 405);
    }

    const bucket = env.TUTORIAL_VIDEOS;
    if (!bucket) {
        return jsonResponse({ error: "Video storage unavailable" }, 500);
    }

    try {
        const videos = await listTutorialVideosFromBucket(bucket);

        return jsonResponse({ videos }, 200, { "Cache-Control": "no-store" });
    } catch (err) {
        console.error("Failed to list tutorial videos:", err);
        return jsonResponse({ error: "Video service unavailable" }, 502);
    }
}

async function handleAdminTutorialVideos(request, env, pathname) {
    if (!isAuthorizedAdminRequest(request, env)) {
        return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const bucket = env.TUTORIAL_VIDEOS;
    if (!bucket) {
        return jsonResponse({ error: "Video storage unavailable" }, 500);
    }

    const basePath = "/api/admin/tutorial-videos";
    const suffix = pathname.slice(basePath.length);

    if (suffix.startsWith("/multipart")) {
        return handleAdminMultipartTutorialVideos(request, bucket, suffix);
    }

    if (suffix === "/order") {
        if (request.method === "PUT") {
            return handleAdminReorderTutorialVideos(request, bucket);
        }

        return jsonResponse({ error: "Method not allowed" }, 405);
    }

    const hasKey = suffix.startsWith("/") && suffix.length > 1;
    const encodedKey = hasKey ? suffix.slice(1) : null;
    const key = encodedKey ? decodeURIComponent(encodedKey) : null;

    if (!hasKey) {
        if (request.method === "GET") {
            try {
                const videos = await listTutorialVideosFromBucket(bucket);
                return jsonResponse({ videos }, 200, { "Cache-Control": "no-store" });
            } catch (err) {
                console.error("Failed to list admin tutorial videos:", err);
                return jsonResponse({ error: "Video service unavailable" }, 502);
            }
        }

        if (request.method === "POST") {
            return handleAdminUploadTutorialVideo(request, bucket);
        }

        return jsonResponse({ error: "Method not allowed" }, 405);
    }

    if (request.method === "DELETE") {
        return handleAdminDeleteTutorialVideo(bucket, key);
    }

    return jsonResponse({ error: "Method not allowed" }, 405);
}

async function handleAdminUploadTutorialVideo(request, bucket) {
    const url = new URL(request.url);
    const fileNameParam = tutorialVideoFileNameParam(request, url);
    const safeFileName = sanitizeVideoFileName(fileNameParam);

    if (!safeFileName) {
        return jsonResponse({ error: "Missing or invalid file name" }, 400);
    }

    const lower = safeFileName.toLowerCase();
    if (!lower.endsWith(".mov") && !lower.endsWith(".mp4")) {
        return jsonResponse({ error: "Only .mov and .mp4 files are allowed" }, 400);
    }

    const contentLengthHeader = request.headers.get("content-length");
    if (contentLengthHeader) {
        const contentLength = Number.parseInt(contentLengthHeader, 10);
        if (Number.isFinite(contentLength) && contentLength > MAX_SINGLE_UPLOAD_BYTES) {
            return jsonResponse(
                { error: "File too large for single upload. Use multipart upload." },
                413
            );
        }
    }

    let body;
    try {
        body = await request.arrayBuffer();
    } catch {
        return jsonResponse({ error: "Invalid upload body" }, 400);
    }

    if (!body || body.byteLength === 0) {
        return jsonResponse({ error: "Upload body is empty" }, 400);
    }

    if (body.byteLength > MAX_SINGLE_UPLOAD_BYTES) {
        return jsonResponse(
            { error: "File too large for single upload. Use multipart upload." },
            413
        );
    }

    const httpMetadata = {
        contentType: lower.endsWith(".mov") ? "video/quicktime" : "video/mp4",
    };

    try {
        const key = await createUniqueTutorialVideoKey(bucket, safeFileName);
        await bucket.put(key, body, { httpMetadata });
        await appendTutorialVideoOrder(bucket, key);
        return jsonResponse({ ok: true, key }, 201);
    } catch (err) {
        console.error("Failed to upload tutorial video:", err);
        return jsonResponse({ error: "Video upload failed" }, 502);
    }
}

async function handleAdminMultipartTutorialVideos(request, bucket, suffix) {
    if (suffix === "/multipart/start") {
        if (request.method !== "POST") {
            return jsonResponse({ error: "Method not allowed" }, 405);
        }
        return handleStartMultipartTutorialVideo(request, bucket);
    }

    if (suffix === "/multipart/complete") {
        if (request.method !== "POST") {
            return jsonResponse({ error: "Method not allowed" }, 405);
        }
        return handleCompleteMultipartTutorialVideo(request, bucket);
    }

    if (suffix === "/multipart/abort") {
        if (request.method !== "POST") {
            return jsonResponse({ error: "Method not allowed" }, 405);
        }
        return handleAbortMultipartTutorialVideo(request, bucket);
    }

    const match = suffix.match(/^\/multipart\/([^/]+)\/(\d+)$/);
    if (!match) {
        return jsonResponse({ error: "Invalid multipart path" }, 400);
    }

    if (request.method !== "PUT") {
        return jsonResponse({ error: "Method not allowed" }, 405);
    }

    const [, encodedUploadId, partNumberStr] = match;
    const uploadId = decodeURIComponent(encodedUploadId);
    const partNumber = Number.parseInt(partNumberStr, 10);
    if (!Number.isFinite(partNumber) || partNumber < 1 || partNumber > 10000) {
        return jsonResponse({ error: "Invalid part number" }, 400);
    }

    const url = new URL(request.url);
    const keyParam = url.searchParams.get("key") || "";
    const key = decodeURIComponent(keyParam);
    if (!isTutorialVideoFileKey(key)) {
        return jsonResponse({ error: "Invalid tutorial video key" }, 400);
    }

    return handleUploadMultipartTutorialVideoPart(request, bucket, key, uploadId, partNumber);
}

async function handleStartMultipartTutorialVideo(request, bucket) {
    const url = new URL(request.url);
    const fileNameParam = tutorialVideoFileNameParam(request, url);
    const safeFileName = sanitizeVideoFileName(fileNameParam);

    if (!safeFileName) {
        return jsonResponse({ error: "Missing or invalid file name" }, 400);
    }

    const lower = safeFileName.toLowerCase();
    if (!lower.endsWith(".mov") && !lower.endsWith(".mp4")) {
        return jsonResponse({ error: "Only .mov and .mp4 files are allowed" }, 400);
    }

    try {
        const key = await createUniqueTutorialVideoKey(bucket, safeFileName);
        const multipartUpload = await bucket.createMultipartUpload(key, {
            httpMetadata: {
                contentType: lower.endsWith(".mov") ? "video/quicktime" : "video/mp4",
            },
        });

        return jsonResponse(
            {
                ok: true,
                key,
                uploadId: multipartUpload.uploadId,
                partSizeBytes: DEFAULT_MULTIPART_PART_SIZE_BYTES,
                maxSingleUploadBytes: MAX_SINGLE_UPLOAD_BYTES,
            },
            201
        );
    } catch (err) {
        console.error("Failed to start multipart upload:", err);
        return jsonResponse({ error: "Video multipart start failed" }, 502);
    }
}

async function handleUploadMultipartTutorialVideoPart(request, bucket, key, uploadId, partNumber) {
    let body;
    try {
        body = await request.arrayBuffer();
    } catch {
        return jsonResponse({ error: "Invalid upload body" }, 400);
    }

    if (!body || body.byteLength === 0) {
        return jsonResponse({ error: "Upload body is empty" }, 400);
    }

    if (body.byteLength > MAX_SINGLE_UPLOAD_BYTES) {
        return jsonResponse({ error: "Multipart part too large" }, 413);
    }

    try {
        const multipartUpload = bucket.resumeMultipartUpload(key, uploadId);
        const uploadedPart = await multipartUpload.uploadPart(partNumber, body);
        return jsonResponse(
            {
                ok: true,
                partNumber,
                etag: uploadedPart.etag,
            },
            200
        );
    } catch (err) {
        console.error("Failed to upload multipart tutorial video part:", err);
        return jsonResponse({ error: "Video multipart part upload failed" }, 502);
    }
}

async function handleCompleteMultipartTutorialVideo(request, bucket) {
    let body;
    try {
        body = await request.json();
    } catch {
        return jsonResponse({ error: "Invalid JSON" }, 400);
    }

    const key = typeof body?.key === "string" ? body.key : "";
    const uploadId = typeof body?.uploadId === "string" ? body.uploadId : "";
    const rawParts = Array.isArray(body?.parts) ? body.parts : [];

    if (!isTutorialVideoFileKey(key)) {
        return jsonResponse({ error: "Invalid tutorial video key" }, 400);
    }

    if (!uploadId) {
        return jsonResponse({ error: "Missing uploadId" }, 400);
    }

    const parts = rawParts
        .map((part) => ({
            partNumber: Number.parseInt(String(part?.partNumber), 10),
            etag: typeof part?.etag === "string" ? part.etag : "",
        }))
        .filter((part) => Number.isFinite(part.partNumber) && part.partNumber >= 1 && part.etag.length > 0)
        .sort((a, b) => a.partNumber - b.partNumber);

    if (parts.length === 0) {
        return jsonResponse({ error: "Missing multipart parts" }, 400);
    }

    for (let i = 1; i < parts.length; i++) {
        if (parts[i].partNumber === parts[i - 1].partNumber) {
            return jsonResponse({ error: "Duplicate part numbers" }, 400);
        }
    }

    try {
        const multipartUpload = bucket.resumeMultipartUpload(key, uploadId);
        await multipartUpload.complete(parts);
        await appendTutorialVideoOrder(bucket, key);
        return jsonResponse({ ok: true, key }, 201);
    } catch (err) {
        console.error("Failed to complete multipart tutorial upload:", err);
        return jsonResponse({ error: "Video multipart completion failed" }, 502);
    }
}

async function handleAbortMultipartTutorialVideo(request, bucket) {
    let body;
    try {
        body = await request.json();
    } catch {
        return jsonResponse({ error: "Invalid JSON" }, 400);
    }

    const key = typeof body?.key === "string" ? body.key : "";
    const uploadId = typeof body?.uploadId === "string" ? body.uploadId : "";

    if (!isTutorialVideoFileKey(key)) {
        return jsonResponse({ error: "Invalid tutorial video key" }, 400);
    }

    if (!uploadId) {
        return jsonResponse({ error: "Missing uploadId" }, 400);
    }

    try {
        const multipartUpload = bucket.resumeMultipartUpload(key, uploadId);
        await multipartUpload.abort();
        return jsonResponse({ ok: true }, 200);
    } catch (err) {
        console.error("Failed to abort multipart tutorial upload:", err);
        return jsonResponse({ error: "Video multipart abort failed" }, 502);
    }
}

async function handleAdminDeleteTutorialVideo(bucket, key) {
    if (!key || !key.startsWith("tutorials/")) {
        return jsonResponse({ error: "Invalid tutorial video key" }, 400);
    }

    try {
        await bucket.delete(key);
        await removeTutorialVideoFromOrder(bucket, key);
        return jsonResponse({ ok: true }, 200);
    } catch (err) {
        console.error("Failed to delete tutorial video:", err);
        return jsonResponse({ error: "Video deletion failed" }, 502);
    }
}

async function handleAdminReorderTutorialVideos(request, bucket) {
    let body;
    try {
        body = await request.json();
    } catch {
        return jsonResponse({ error: "Invalid JSON" }, 400);
    }

    if (!Array.isArray(body?.orderedKeys)) {
        return jsonResponse({ error: "Missing required field: orderedKeys" }, 400);
    }

    const currentObjects = await listTutorialVideoObjectsFromBucket(bucket);
    const currentKeys = currentObjects.map((object) => object.key);
    const normalizedKeys = normalizeTutorialVideoOrder(
        currentKeys,
        body.orderedKeys.filter((key) => typeof key === "string" && isTutorialVideoFileKey(key))
    );

    try {
        await bucket.put(
            TUTORIAL_VIDEO_ORDER_KEY,
            JSON.stringify({ orderedKeys: normalizedKeys, updatedAt: Date.now() }),
            { httpMetadata: { contentType: "application/json" } }
        );
        return jsonResponse({ ok: true }, 200);
    } catch (err) {
        console.error("Failed to reorder tutorial videos:", err);
        return jsonResponse({ error: "Video reorder failed" }, 502);
    }
}

async function listTutorialVideosFromBucket(bucket) {
    const objects = await listTutorialVideoObjectsFromBucket(bucket);
    const orderedKeys = await loadTutorialVideoOrder(bucket);
    const orderedObjects = orderTutorialVideoObjects(objects, orderedKeys);

    return orderedObjects.map((object) => {
        const relativeKey = object.key.replace(/^tutorials\//, "");
        const dotIndex = relativeKey.lastIndexOf(".");
        const fileName = dotIndex > 0 ? relativeKey.slice(0, dotIndex) : relativeKey;
        const fileExtension = dotIndex > 0 ? relativeKey.slice(dotIndex + 1).toLowerCase() : "";
        const id = `tutorials/${relativeKey}`;

        return {
            id,
            key: `tutorials/${relativeKey}`,
            title: formatTutorialTitle(fileName),
            fileName,
            fileExtension,
            size: object.size,
            updatedAt: object.uploaded ? new Date(object.uploaded).getTime() : null,
        };
    });
}

async function listTutorialVideoObjectsFromBucket(bucket) {
    const objects = [];
    let cursor;

    do {
        const listed = await bucket.list({
            prefix: "tutorials/",
            cursor,
            limit: 100,
        });

        objects.push(...(listed.objects || []));
        cursor = listed.truncated ? listed.cursor : undefined;
    } while (cursor);

    return objects
        .filter((object) => object?.key && typeof object.key === "string" && isTutorialVideoFileKey(object.key))
        .sort((a, b) => {
            const aTime = a.uploaded ? new Date(a.uploaded).getTime() : 0;
            const bTime = b.uploaded ? new Date(b.uploaded).getTime() : 0;
            return bTime - aTime;
        });
}

function orderTutorialVideoObjects(objects, orderedKeys) {
    const byKey = new Map(objects.map((object) => [object.key, object]));
    const orderedObjects = [];
    const seen = new Set();

    if (Array.isArray(orderedKeys)) {
        for (const key of orderedKeys) {
            const object = byKey.get(key);
            if (object && !seen.has(key)) {
                orderedObjects.push(object);
                seen.add(key);
            }
        }
    }

    for (const object of objects) {
        if (!seen.has(object.key)) {
            orderedObjects.push(object);
            seen.add(object.key);
        }
    }

    return orderedObjects;
}

function isTutorialVideoFileKey(key) {
    const lower = String(key || "").toLowerCase();
    return lower.endsWith(".mov") || lower.endsWith(".mp4");
}

function tutorialVideoFileNameParam(request, url) {
    const queryName = url.searchParams.get("fileName") || "";
    const headerName = request.headers.get("X-File-Name") || "";
    const querySafeName = sanitizeVideoFileName(queryName);

    if (isTutorialVideoFileKey(querySafeName)) {
        return queryName;
    }

    return headerName || queryName;
}

async function loadTutorialVideoOrder(bucket) {
    const object = await bucket.get(TUTORIAL_VIDEO_ORDER_KEY);
    if (!object) {
        return null;
    }

    try {
        const parsed = JSON.parse(await object.text());
        return Array.isArray(parsed?.orderedKeys)
            ? parsed.orderedKeys.filter((key) => typeof key === "string" && isTutorialVideoFileKey(key))
            : null;
    } catch {
        return null;
    }
}

async function appendTutorialVideoOrder(bucket, key) {
    const currentObjects = await listTutorialVideoObjectsFromBucket(bucket);
    const currentKeys = currentObjects.map((object) => object.key);
    const storedOrder = await loadTutorialVideoOrder(bucket);
    const baseOrder = normalizeTutorialVideoOrder(currentKeys, storedOrder);

    if (!baseOrder.includes(key)) {
        baseOrder.push(key);
    }

    await bucket.put(
        TUTORIAL_VIDEO_ORDER_KEY,
        JSON.stringify({ orderedKeys: baseOrder, updatedAt: Date.now() }),
        { httpMetadata: { contentType: "application/json" } }
    );
}

async function removeTutorialVideoFromOrder(bucket, key) {
    const currentObjects = await listTutorialVideoObjectsFromBucket(bucket);
    const currentKeys = currentObjects.map((object) => object.key);
    const storedOrder = await loadTutorialVideoOrder(bucket);
    const baseOrder = normalizeTutorialVideoOrder(currentKeys, storedOrder).filter((existingKey) => existingKey !== key);

    await bucket.put(
        TUTORIAL_VIDEO_ORDER_KEY,
        JSON.stringify({ orderedKeys: baseOrder, updatedAt: Date.now() }),
        { httpMetadata: { contentType: "application/json" } }
    );
}

function normalizeTutorialVideoOrder(currentKeys, orderedKeys) {
    const normalized = [];
    const seen = new Set();

    if (Array.isArray(orderedKeys)) {
        for (const key of orderedKeys) {
            if (currentKeys.includes(key) && !seen.has(key)) {
                normalized.push(key);
                seen.add(key);
            }
        }
    }

    for (const key of currentKeys) {
        if (!seen.has(key)) {
            normalized.push(key);
            seen.add(key);
        }
    }

    return normalized;
}

async function createUniqueTutorialVideoKey(bucket, safeFileName) {
    const objects = await listTutorialVideoObjectsFromBucket(bucket);
    const existingKeys = new Set(objects.map((object) => object.key));
    return makeUniqueTutorialVideoKey(safeFileName, existingKeys);
}

function makeUniqueTutorialVideoKey(safeFileName, existingKeys) {
    const dotIndex = safeFileName.lastIndexOf(".");
    const baseName = dotIndex > 0 ? safeFileName.slice(0, dotIndex) : safeFileName;
    const extension = dotIndex > 0 ? safeFileName.slice(dotIndex) : "";
    let candidate = `tutorials/${safeFileName}`;
    let suffix = 2;

    while (existingKeys.has(candidate)) {
        candidate = `tutorials/${baseName}-${suffix}${extension}`;
        suffix += 1;
    }

    return candidate;
}

function sanitizeVideoFileName(fileName) {
    const trimmed = String(fileName || "").trim();
    if (!trimmed) {
        return "";
    }

    const base = trimmed
        .replace(/[\\/]/g, "-")
        .replace(/\s+/g, "-")
        .replace(/[^a-zA-Z0-9._-]/g, "")
        .replace(/-+/g, "-")
        .replace(/^[-.]+|[-.]+$/g, "");

    return base.slice(0, 120);
}

function formatTutorialTitle(fileName) {
    const normalized = String(fileName || "")
        .replace(/[_-]+/g, " ")
        .replace(/\s+/g, " ")
        .trim();

    if (!normalized) {
        return "Tutorial Video";
    }

    return normalized
        .split(" ")
        .map((word) => {
            if (word.length <= 2) {
                return word.toUpperCase();
            }
            return word.charAt(0).toUpperCase() + word.slice(1);
        })
        .join(" ");
}

async function handleAdminMessages(request, env, pathname) {
    if (!isAuthorizedAdminRequest(request, env)) {
        return jsonResponse({ error: "Unauthorized" }, 401);
    }

    if (!env.MESSAGES_DB) {
        return jsonResponse({ error: "Messages service unavailable" }, 500);
    }

    await ensureMessagesCriticalColumn(env);

    const basePath = "/api/admin/messages";
    const suffix = pathname.slice(basePath.length);
    const hasMessageID = suffix.startsWith("/") && suffix.length > 1;
    const messageID = hasMessageID ? decodeURIComponent(suffix.slice(1)) : null;

    if (!hasMessageID && request.method === "DELETE") {
        const url = new URL(request.url);
        if (url.searchParams.get("deleteArchived") === "1") {
            return handleAdminDeleteArchivedMessages(env);
        }
    }

    if (!hasMessageID) {
        if (request.method === "GET") {
            return handleAdminListMessages(request, env);
        }
        if (request.method === "POST") {
            return handleAdminCreateMessage(request, env);
        }
        return jsonResponse({ error: "Method not allowed" }, 405);
    }

    if (request.method === "PUT") {
        return handleAdminUpdateMessage(request, env, messageID);
    }

    if (request.method === "DELETE") {
        return handleAdminArchiveOrDeleteMessage(env, messageID);
    }

    return jsonResponse({ error: "Method not allowed" }, 405);
}

async function handleAdminListMessages(request, env) {
    const url = new URL(request.url);
    const includeArchived = url.searchParams.get("includeArchived") === "1";

    try {
        const query = includeArchived
            ? `
                SELECT id, title, body, created_at, updated_at, is_archived, is_critical
                FROM messages
                ORDER BY updated_at DESC
            `
            : `
                SELECT id, title, body, created_at, updated_at, is_archived, is_critical
                FROM messages
                WHERE is_archived = 0
                ORDER BY updated_at DESC
            `;

        const { results } = await env.MESSAGES_DB.prepare(query).all();
        const messages = (results || []).map((row) => ({
            id: row.id,
            title: row.title,
            body: row.body,
            createdAt: row.created_at,
            updatedAt: row.updated_at,
            isArchived: row.is_archived === 1,
            isCritical: row.is_critical === 1,
        }));

        return jsonResponse({ messages }, 200, { "Cache-Control": "no-store" });
    } catch (err) {
        console.error("Failed to list admin messages:", err);
        return jsonResponse({ error: "Messages service unavailable" }, 502);
    }
}

async function handleAdminCreateMessage(request, env) {
    let body;
    try {
        body = await request.json();
    } catch {
        return jsonResponse({ error: "Invalid JSON" }, 400);
    }

    const validation = validateMessageInput(body, { allowPartial: false });
    if (validation.error) {
        return jsonResponse({ error: validation.error }, 400);
    }

    const now = Date.now();
    const id = crypto.randomUUID();
    const isArchived = body.isArchived === true ? 1 : 0;
    const isCritical = body.isCritical === true ? 1 : 0;

    try {
        await env.MESSAGES_DB
            .prepare(`
                INSERT INTO messages (id, title, body, created_at, updated_at, is_archived, is_critical)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            `)
            .bind(id, validation.title, validation.body, now, now, isArchived, isCritical)
            .run();

        return jsonResponse(
            {
                message: {
                    id,
                    title: validation.title,
                    body: validation.body,
                    createdAt: now,
                    updatedAt: now,
                    isArchived: isArchived === 1,
                    isCritical: isCritical === 1,
                },
            },
            201
        );
    } catch (err) {
        console.error("Failed to create message:", err);
        return jsonResponse({ error: "Messages service unavailable" }, 502);
    }
}

async function handleAdminUpdateMessage(request, env, id) {
    let body;
    try {
        body = await request.json();
    } catch {
        return jsonResponse({ error: "Invalid JSON" }, 400);
    }

    const validation = validateMessageInput(body, { allowPartial: true });
    if (validation.error) {
        return jsonResponse({ error: validation.error }, 400);
    }

    const updates = [];
    const bindings = [];

    if (validation.title !== undefined) {
        updates.push("title = ?");
        bindings.push(validation.title);
    }
    if (validation.body !== undefined) {
        updates.push("body = ?");
        bindings.push(validation.body);
    }
    if (body.isArchived !== undefined) {
        updates.push("is_archived = ?");
        bindings.push(body.isArchived === true ? 1 : 0);
    }
    if (body.isCritical !== undefined) {
        updates.push("is_critical = ?");
        bindings.push(body.isCritical === true ? 1 : 0);
    }

    if (updates.length === 0) {
        return jsonResponse({ error: "No updatable fields supplied" }, 400);
    }

    const now = Date.now();
    updates.push("updated_at = ?");
    bindings.push(now);
    bindings.push(id);

    try {
        const result = await env.MESSAGES_DB
            .prepare(`UPDATE messages SET ${updates.join(", ")} WHERE id = ?`)
            .bind(...bindings)
            .run();

        if (!result.success || result.meta?.changes === 0) {
            return jsonResponse({ error: "Message not found" }, 404);
        }

        return jsonResponse({ ok: true, updatedAt: now }, 200);
    } catch (err) {
        console.error("Failed to update message:", err);
        return jsonResponse({ error: "Messages service unavailable" }, 502);
    }
}

async function handleAdminArchiveMessage(env, id) {
    const now = Date.now();
    try {
        const result = await env.MESSAGES_DB
            .prepare("UPDATE messages SET is_archived = 1, updated_at = ? WHERE id = ?")
            .bind(now, id)
            .run();

        if (!result.success || result.meta?.changes === 0) {
            return jsonResponse({ error: "Message not found" }, 404);
        }

        return jsonResponse({ ok: true }, 200);
    } catch (err) {
        console.error("Failed to archive message:", err);
        return jsonResponse({ error: "Messages service unavailable" }, 502);
    }
}

async function handleAdminArchiveOrDeleteMessage(env, id) {
    try {
        const existing = await env.MESSAGES_DB
            .prepare("SELECT id, is_archived FROM messages WHERE id = ?")
            .bind(id)
            .first();

        if (!existing) {
            return jsonResponse({ error: "Message not found" }, 404);
        }

        if (existing.is_archived === 1) {
            await env.MESSAGES_DB
                .prepare("DELETE FROM messages WHERE id = ?")
                .bind(id)
                .run();
            return jsonResponse({ ok: true, deleted: true }, 200);
        }

        return handleAdminArchiveMessage(env, id);
    } catch (err) {
        console.error("Failed to archive or delete message:", err);
        return jsonResponse({ error: "Messages service unavailable" }, 502);
    }
}

async function handleAdminDeleteArchivedMessages(env) {
    try {
        const result = await env.MESSAGES_DB
            .prepare("DELETE FROM messages WHERE is_archived = 1")
            .run();

        return jsonResponse({ ok: true, deletedCount: result?.meta?.changes ?? 0 }, 200);
    } catch (err) {
        console.error("Failed to delete archived messages:", err);
        return jsonResponse({ error: "Messages service unavailable" }, 502);
    }
}

async function handleRecordSale(request, env) {
    if (request.method !== "POST") {
        return jsonResponse({ error: "Method not allowed" }, 405);
    }

    if (!env.MESSAGES_DB) {
        return jsonResponse({ error: "Sales service unavailable" }, 500);
    }

    let body;
    try {
        body = await request.json();
    } catch {
        return jsonResponse({ error: "Invalid JSON" }, 400);
    }

    const productID = typeof body?.productID === "string" ? body.productID.trim() : "";
    const transactionID = typeof body?.transactionID === "string" ? body.transactionID.trim() : "";
    const projectType = PRODUCT_SALE_TYPES.get(productID);

    if (!projectType) {
        return jsonResponse({ error: "Invalid productID" }, 400);
    }
    if (!transactionID || transactionID.length > 120) {
        return jsonResponse({ error: "Invalid transactionID" }, 400);
    }

    const purchaseDate = normalizedPurchaseDate(body?.purchaseDate);
    const saleMonth = saleMonthFromTimestamp(purchaseDate);
    const now = Date.now();

    try {
        await ensureSalesTables(env);

        const insertResult = await env.MESSAGES_DB
            .prepare(`
                INSERT OR IGNORE INTO sales_events (transaction_id, product_id, project_type, sale_month, purchase_date, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
            `)
            .bind(transactionID, productID, projectType, saleMonth, purchaseDate, now)
            .run();

        const inserted = (insertResult?.meta?.changes ?? 0) > 0;
        if (inserted) {
            await env.MESSAGES_DB
                .prepare(`
                    INSERT INTO monthly_sales (sale_month, project_type, sale_count, updated_at)
                    VALUES (?, ?, 1, ?)
                    ON CONFLICT(sale_month, project_type) DO UPDATE SET
                        sale_count = sale_count + 1,
                        updated_at = excluded.updated_at
                `)
                .bind(saleMonth, projectType, now)
                .run();
        }

        return jsonResponse({ ok: true, inserted, month: saleMonth, projectType }, 200);
    } catch (err) {
        console.error("Failed to record sale:", err);
        return jsonResponse({ error: "Sales service unavailable" }, 502);
    }
}

async function handleAdminSales(request, env) {
    if (!isAuthorizedAdminRequest(request, env)) {
        return jsonResponse({ error: "Unauthorized" }, 401);
    }

    if (request.method !== "GET") {
        return jsonResponse({ error: "Method not allowed" }, 405);
    }

    if (!env.MESSAGES_DB) {
        return jsonResponse({ error: "Sales service unavailable" }, 500);
    }

    const url = new URL(request.url);
    const requestedMonth = url.searchParams.get("month");

    try {
        await ensureSalesTables(env);

        const { results: monthRows } = await env.MESSAGES_DB
            .prepare("SELECT DISTINCT sale_month FROM monthly_sales ORDER BY sale_month DESC")
            .all();
        const months = (monthRows || []).map((row) => row.sale_month).filter(Boolean);
        const selectedMonth = isValidSaleMonth(requestedMonth) ? requestedMonth : (months[0] || saleMonthFromTimestamp(Date.now()));

        const { results } = await env.MESSAGES_DB
            .prepare(`
                SELECT sale_month, project_type, sale_count, updated_at
                FROM monthly_sales
                WHERE sale_month = ?
                ORDER BY project_type ASC
            `)
            .bind(selectedMonth)
            .all();

        const sales = (results || []).map((row) => ({
            month: row.sale_month,
            projectType: row.project_type,
            count: row.sale_count,
            updatedAt: row.updated_at,
        }));

        return jsonResponse({ months, selectedMonth, sales }, 200, { "Cache-Control": "no-store" });
    } catch (err) {
        console.error("Failed to fetch sales:", err);
        return jsonResponse({ error: "Sales service unavailable" }, 502);
    }
}

function normalizedPurchaseDate(value) {
    if (typeof value === "number" && Number.isFinite(value) && value > 0) {
        return Math.trunc(value);
    }
    if (typeof value === "string") {
        const parsed = Date.parse(value);
        if (Number.isFinite(parsed) && parsed > 0) {
            return parsed;
        }
    }
    return Date.now();
}

function saleMonthFromTimestamp(timestamp) {
    const date = new Date(timestamp);
    const year = date.getUTCFullYear();
    const month = String(date.getUTCMonth() + 1).padStart(2, "0");
    return `${year}-${month}`;
}

function isValidSaleMonth(month) {
    return typeof month === "string" && /^\d{4}-\d{2}$/.test(month);
}

async function ensureSalesTables(env) {
    await env.MESSAGES_DB
        .prepare(`
            CREATE TABLE IF NOT EXISTS sales_events (
                transaction_id TEXT PRIMARY KEY,
                product_id TEXT NOT NULL,
                project_type TEXT NOT NULL,
                sale_month TEXT NOT NULL,
                purchase_date INTEGER NOT NULL,
                created_at INTEGER NOT NULL
            )
        `)
        .run();

    await env.MESSAGES_DB
        .prepare("CREATE INDEX IF NOT EXISTS idx_sales_events_month ON sales_events(sale_month DESC, project_type)")
        .run();

    await env.MESSAGES_DB
        .prepare(`
            CREATE TABLE IF NOT EXISTS monthly_sales (
                sale_month TEXT NOT NULL,
                project_type TEXT NOT NULL,
                sale_count INTEGER NOT NULL DEFAULT 0,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY (sale_month, project_type)
            )
        `)
        .run();

    await env.MESSAGES_DB
        .prepare("CREATE INDEX IF NOT EXISTS idx_monthly_sales_month ON monthly_sales(sale_month DESC)")
        .run();
}

function validateMessageInput(body, { allowPartial }) {
    const hasTitle = typeof body?.title === "string";
    const hasBody = typeof body?.body === "string";

    if (!allowPartial && (!hasTitle || !hasBody)) {
        return { error: "Missing required fields: title, body" };
    }

    if (hasTitle) {
        const title = body.title.trim();
        if (!title) {
            return { error: "Title cannot be empty" };
        }
        if (title.length > MAX_MESSAGE_TITLE_LENGTH) {
            return { error: `Title exceeds ${MAX_MESSAGE_TITLE_LENGTH} characters` };
        }
        body.title = title;
    }

    if (hasBody) {
        const messageBody = body.body.trim();
        if (!messageBody) {
            return { error: "Body cannot be empty" };
        }
        if (messageBody.length > MAX_MESSAGE_BODY_LENGTH) {
            return { error: `Body exceeds ${MAX_MESSAGE_BODY_LENGTH} characters` };
        }
        body.body = messageBody;
    }

    if (body?.isCritical !== undefined && typeof body.isCritical !== "boolean") {
        return { error: "isCritical must be a boolean" };
    }

    if (body?.isArchived !== undefined && typeof body.isArchived !== "boolean") {
        return { error: "isArchived must be a boolean" };
    }

    return {
        title: hasTitle ? body.title : undefined,
        body: hasBody ? body.body : undefined,
    };
}

async function ensureMessagesCriticalColumn(env) {
    try {
        await env.MESSAGES_DB
            .prepare(
                "ALTER TABLE messages ADD COLUMN is_critical INTEGER NOT NULL DEFAULT 0 CHECK (is_critical IN (0, 1))"
            )
            .run();
    } catch (err) {
        const message = String(err?.message || "").toLowerCase();
        if (!message.includes("duplicate column name") && !message.includes("already exists")) {
            console.error("Failed to ensure is_critical column:", err);
            throw err;
        }
    }
}

function isAuthorizedAdminRequest(request, env) {
    const configuredToken = env.ADMIN_API_TOKEN;
    if (!configuredToken || typeof configuredToken !== "string") {
        return false;
    }

    const authHeader = request.headers.get("Authorization") || "";
    if (!authHeader.startsWith("Bearer ")) {
        return false;
    }

    const token = authHeader.slice(7).trim();
    return token.length > 0 && token === configuredToken;
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

function buildAnalystSystemPrompt(analysisProfile, projectType, fictionClass, metadata) {
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
    "summary": "a developed editorial reading (4-6 sentences) of the writing's strengths and possible areas for revision, naming specific craft elements rather than generalities",
  "sentiment": "encouraging|mixed|critical",
  "focusAreas": ["area1", "area2", "area3"],
  "suggestions": [
    {
      "id": "unique_id",
      "category": "category_name",
      "severity": "high|medium|low",
            "location": "Line N or Line N-M (must use source line numbers) or null",
            "observation": "a thorough, evidence-grounded editorial reading of what you noticed, quoting a brief phrase from the source and explaining precisely how the passage operates",
            "suggestion": "a concrete, developed revision focus or craft experiment the author could try, with enough specificity to act on (without rewriting the text for them)",
            "rationale": "a full explanation of why this may matter for reader experience or authorial intent, tracing the likely effect on the reader"
    }
  ]
}

CRITICAL LINE-NUMBER RULES:
- The user content is provided with explicit line-number prefixes in the form "0001 | text".
- If you cite a location, you MUST use those exact numbers as "Line N" or "Line N-M".
- Do not estimate or invent line numbers.
- If no precise location applies, set "location" to null.

OUTPUT QUALITY RULES:
- Make the summary substantive and specific (4-6 sentences), naming concrete craft elements; avoid grandiose or vague praise.
- Focus areas must be supported by the actual suggestions you provide.
- BE COMPREHENSIVE. Work through the piece systematically and surface every distinct, well-supported issue you can evidence, across the full range of relevant craft categories. As a guideline, provide at least 6-10 suggestions for a substantial sample, and more for longer texts, whenever the text genuinely supports them. Do not stop after two or three points.
- Each suggestion's observation, suggestion, and rationale must each be fully developed (aim for 3-5 sentences each), not one-line notes. In the observation, quote the relevant phrase, explain precisely how the passage operates, and name the specific craft mechanism at work. In the rationale, trace the concrete effect on the reader and why it matters.
- The only legitimate reason to provide few suggestions is a genuinely short or already-polished passage. Never withhold a supported observation for the sake of brevity.
- Quality still governs: every suggestion must be anchored in textual evidence. Do not invent weak or speculative points purely to inflate the count.
- Never imply that your reading is the only valid reading of the text.`;

    if (analysisProfile === "poetry") {
        const preserveForm = metadata?.preservePoetryForm === true;
        const declaredForm = metadata?.poetryFormName && metadata.poetryFormName.trim().length > 0
            ? metadata.poetryFormName.trim()
            : null;
        const formConstraintBlock = preserveForm
            ? `
- FORM SAFETY RULE (MANDATORY): Do not suggest edits that would break the poem's current form.
- Preserve the existing line count, stanza count, refrain positions, and fixed structural pattern unless the user explicitly asks to change form.
- Prefer within-line revisions (diction, syntax, imagery, sound) over structural rewrites.
- Do not suggest adding/removing/reordering full lines or stanzas when a fixed form is declared.
- If the only possible improvement appears form-breaking, mark it as low severity and offer a form-preserving alternative.`
            : "";

        return basePrompt + `

POETRY-SPECIFIC GUIDANCE:
- Focus on: imagery, diction, lineation, rhythm and meter, stanza architecture, sonic texture, emotional coherence
- Categories: Poetic Form & Lineation, Rhythm, Meter & Sound, Imagery & Precision, Structure & Organization, Emotional Coherence
- Evaluate line breaks and their effectiveness
- Comment on use of literary devices (metaphor, simile, alliteration, etc.)
- Consider adherence to declared poetic form if applicable
- De-emphasize plot/character diagnostics unless narrative elements are explicit${declaredForm ? `
- Declared form: ${declaredForm}` : ""}${formConstraintBlock}`;
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
        if (analysisProfile === "poetry") {
            if (metadata.poetryFormName) prompt += `[Declared Poetry Form: ${metadata.poetryFormName}]\n`;
            if (metadata.poetryFormRequirementsSummary) {
                prompt += `[Form Requirements: ${metadata.poetryFormRequirementsSummary}]\n`;
            }
            if (metadata.preservePoetryForm === true) {
                prompt += `[Constraint: Suggest revisions that preserve the existing poetic form.]\n`;
            }
        }
    }
    
    const numberedContent = addSourceLineNumbers(content || "", {
        skipMatchingTitles: projectType === "poetry",
        fileName: metadata.fileName,
    });
    prompt += `\nSource (line-numbered):\n${numberedContent}\n\n`;
    
    if (options?.focusAreas && options.focusAreas.length > 0) {
        prompt += `Focus particularly on: ${options.focusAreas.join(", ")}\n\n`;
    }
    
    prompt += `Provide structured feedback as JSON. Limit to ${options?.severity === "high" ? "high-severity" : "all"} issues unless severity is specified as 'all'. Be comprehensive and detailed: work through the whole piece, cover the full range of relevant craft categories, provide as many well-evidenced suggestions as the text genuinely supports (aim for at least 6-10 on a substantial sample), and develop each observation, suggestion, and rationale fully (3-5 sentences each). Do not provide rewritten text.`;
    
    return prompt;
}

function addSourceLineNumbers(content, options = {}) {
    const lines = String(content).replace(/\r\n?/g, "\n").split("\n");

    // If content is already line-numbered (e.g. "0001 | ..."), keep it as-is.
    const firstNonEmpty = lines.find((line) => line.trim().length > 0);
    if (firstNonEmpty && /^\s*\d{3,6}\s\|/.test(firstNonEmpty)) {
        return lines.join("\n");
    }

    let lineNumber = 0;
    let expectedTitle = options.skipMatchingTitles ? normalizeSourceTitle(options.fileName) : null;
    return lines
        .map((line) => {
            const trimmed = line.trim();
            const modernBoundary = trimmed.match(/^\[\[WSP_FILE:\s*(.+)\]\]$/);
            const legacyBoundary = trimmed.match(/^---\s+(.+)\s+---$/);
            const boundaryTitle = modernBoundary?.[1] || legacyBoundary?.[1];
            if (boundaryTitle) {
                expectedTitle = options.skipMatchingTitles ? normalizeSourceTitle(boundaryTitle) : null;
                return line;
            }
            if (trimmed.length === 0) return line;
            if (expectedTitle && normalizeSourceTitle(trimmed) === expectedTitle) {
                expectedTitle = null;
                return line;
            }
            expectedTitle = null;
            lineNumber += 1;
            return `${String(lineNumber).padStart(4, "0")} | ${line}`;
        })
        .join("\n");
}

function normalizeSourceTitle(value) {
    return String(value || "").trim().replace(/\s+/g, " ").toLocaleLowerCase();
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
