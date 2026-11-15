const APP_STORE_CONNECT_BASE_URL = "https://api.appstoreconnect.apple.com";
const WRITING_SHED_PRO_APPLE_ID = "6747890719";
const APP_DOWNLOAD_PRODUCT_TYPES = new Set([
    "1",
    "1F",
    "1T",
    "1E",
    "1EP",
    "1EU",
    "F1",
]);
const REPORT_PRODUCT_IDS = new Set([
    "com.writingshedpro.prosewriter",
    "com.writingshedpro.poetrywriter",
    "com.writingshedpro.fictionwriter",
    "com.writingshedpro.dramawriter",
    "com.writingshedpro.allinbundle",
    "com.writingshedpro.fullaccess",
    "com.writingshedpro.manuscriptanalyst",
]);

export class AppStoreConnectError extends Error {
    constructor(status, message) {
        super(message);
        this.status = status;
    }
}

export function appStoreConnectResponseError(status) {
    if (status === 401 || status === 403) {
        return new AppStoreConnectError(
            502,
            "Apple rejected the Sales and Trends credentials. Check the API key, issuer ID, and Sales and Reports access."
        );
    }
    return new AppStoreConnectError(
        status,
        `Apple Sales and Trends request failed (${status})`
    );
}

function encodeBase64URL(value) {
    const bytes = typeof value === "string"
        ? new TextEncoder().encode(value)
        : new Uint8Array(value);
    const binary = String.fromCharCode(...bytes);
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function privateKeyBytes(privateKey) {
    const base64 = privateKey
        .replace(/-----BEGIN PRIVATE KEY-----/g, "")
        .replace(/-----END PRIVATE KEY-----/g, "")
        .replace(/\s/g, "");
    return Uint8Array.from(atob(base64), (character) => character.charCodeAt(0));
}

export async function createAppStoreConnectToken(privateKey, keyID, issuerID, now = Date.now()) {
    const issuedAt = Math.floor(now / 1000);
    const header = encodeBase64URL(JSON.stringify({
        alg: "ES256",
        kid: keyID.trim(),
        typ: "JWT",
    }));
    const payload = encodeBase64URL(JSON.stringify({
        iss: issuerID.trim(),
        iat: issuedAt,
        exp: issuedAt + 15 * 60,
        aud: "appstoreconnect-v1",
    }));
    const signingInput = `${header}.${payload}`;
    const signingKey = await crypto.subtle.importKey(
        "pkcs8",
        privateKeyBytes(privateKey),
        { name: "ECDSA", namedCurve: "P-256" },
        false,
        ["sign"]
    );
    const signature = await crypto.subtle.sign(
        { name: "ECDSA", hash: "SHA-256" },
        signingKey,
        new TextEncoder().encode(signingInput)
    );
    return `${signingInput}.${encodeBase64URL(signature)}`;
}

function parseTSV(text) {
    const lines = text.replace(/\r/g, "").split("\n").filter((line) => line.length > 0);
    if (lines.length === 0) return [];
    const headers = lines[0].split("\t");
    return lines.slice(1).map((line) => {
        const values = line.split("\t");
        return Object.fromEntries(headers.map((header, index) => [header, values[index] ?? ""]));
    });
}

export function summarizeSalesReport(text) {
    const totals = new Map();
    for (const row of parseTSV(text)) {
        const productID = row.SKU?.trim();
        if (!REPORT_PRODUCT_IDS.has(productID)) continue;

        const productType = row["Product Type Identifier"]?.trim();
        if (!productType?.startsWith("IA")) continue;

        const units = Number.parseInt(row.Units, 10);
        if (!Number.isFinite(units) || units === 0) continue;

        const current = totals.get(productID) ?? { productID, purchases: 0, refunds: 0 };
        if (units > 0) {
            current.purchases += units;
        } else {
            current.refunds += Math.abs(units);
        }
        totals.set(productID, current);
    }
    return [...totals.values()];
}

export function summarizeAppDownloads(text) {
    const totals = new Map();
    for (const row of parseTSV(text)) {
        if (row["Apple Identifier"]?.trim() !== WRITING_SHED_PRO_APPLE_ID) continue;

        const productType = row["Product Type Identifier"]?.trim();
        if (!APP_DOWNLOAD_PRODUCT_TYPES.has(productType)) continue;

        const device = row.Device?.trim().toLowerCase();
        let platform = "iOS";
        if (device?.includes("desktop") || device?.includes("mac")) {
            platform = "macOS";
        } else if (device?.includes("vision")) {
            platform = "visionOS";
        }

        const units = Number.parseInt(row.Units, 10);
        if (!Number.isFinite(units) || units === 0) continue;

        totals.set(platform, (totals.get(platform) ?? 0) + units);
    }
    return [...totals].map(([platform, downloads]) => ({ platform, downloads }));
}

export async function downloadDailySalesReport(reportDate, env, fetchImpl = fetch) {
    const required = [
        env.APP_STORE_CONNECT_PRIVATE_KEY,
        env.APP_STORE_CONNECT_KEY_ID,
        env.APP_STORE_CONNECT_ISSUER_ID,
        env.APP_STORE_CONNECT_VENDOR_NUMBER,
    ];
    if (required.some((value) => typeof value !== "string" || value.trim().length === 0)) {
        throw new AppStoreConnectError(503, "Apple Sales and Trends is not configured");
    }

    const token = await createAppStoreConnectToken(
        env.APP_STORE_CONNECT_PRIVATE_KEY,
        env.APP_STORE_CONNECT_KEY_ID,
        env.APP_STORE_CONNECT_ISSUER_ID
    );
    const url = new URL("/v1/salesReports", APP_STORE_CONNECT_BASE_URL);
    url.searchParams.set("filter[frequency]", "DAILY");
    url.searchParams.set("filter[reportDate]", reportDate);
    url.searchParams.set("filter[reportSubType]", "SUMMARY");
    url.searchParams.set("filter[reportType]", "SALES");
    url.searchParams.set("filter[vendorNumber]", env.APP_STORE_CONNECT_VENDOR_NUMBER.trim());
    url.searchParams.set("filter[version]", "1_0");

    const response = await fetchImpl(url, {
        headers: {
            Authorization: ["Bearer", token].join(" "),
            Accept: "application/a-gzip",
        },
    });
    if (response.status === 404) {
        return {
            isAvailable: false,
            sales: [],
            appDownloads: [],
        };
    }
    if (!response.ok) {
        throw appStoreConnectResponseError(response.status);
    }

    const decompressed = response.body.pipeThrough(new DecompressionStream("gzip"));
    const text = await new Response(decompressed).text();
    return {
        isAvailable: true,
        sales: summarizeSalesReport(text),
        appDownloads: summarizeAppDownloads(text),
    };
}

export function reportDatesForMonth(month, now = new Date()) {
    if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month)) return [];
    const [year, monthNumber] = month.split("-").map(Number);
    const first = new Date(Date.UTC(year, monthNumber - 1, 1));
    const lastOfMonth = new Date(Date.UTC(year, monthNumber, 0));
    const yesterday = new Date(Date.UTC(
        now.getUTCFullYear(),
        now.getUTCMonth(),
        now.getUTCDate() - 1
    ));
    const last = lastOfMonth < yesterday ? lastOfMonth : yesterday;
    if (first > last) return [];

    const dates = [];
    for (const date = first; date <= last; date.setUTCDate(date.getUTCDate() + 1)) {
        dates.push(date.toISOString().slice(0, 10));
    }
    return dates;
}
