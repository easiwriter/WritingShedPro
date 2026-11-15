import assert from "node:assert/strict";
import test from "node:test";
import {
    appStoreConnectResponseError,
    reportDatesForMonth,
    summarizeAppDownloads,
    summarizeSalesReport,
} from "../src/apple-sales-reports.mjs";
import {
    buildTrialMetrics,
    TRIAL_DURATION_MS,
    validateTrialEvent,
} from "../src/trial-telemetry.mjs";
import {
    reportDatesForSalesRange,
    salesRangeTimestampRange,
    salesRangeTimestampRangeEndingOn,
} from "../src/sales-ranges.mjs";

test("summarizes Writing Shed purchases and refunds by product SKU", () => {
    const report = [
        "SKU\tUnits\tProduct Type Identifier",
        "com.writingshedpro.fullaccess\t3\tIA1",
        "com.writingshedpro.fullaccess\t-1\tIA1",
        "com.writingshedpro.manuscriptanalyst\t2\tIAY",
        "com.writingshedpro.manuscriptanalyst\t1\t1F",
        "unrelated.app.sku\t99\t1F",
    ].join("\n");

    assert.deepEqual(summarizeSalesReport(report), [
        {
            productID: "com.writingshedpro.fullaccess",
            purchases: 3,
            refunds: 1,
        },
        {
            productID: "com.writingshedpro.manuscriptanalyst",
            purchases: 2,
            refunds: 0,
        },
    ]);
});

test("summarizes free Writing Shed Pro downloads separately by platform", () => {
    const report = [
        "SKU\tUnits\tProduct Type Identifier\tDevice\tApple Identifier",
        "wsp-app-sku\t14\t1F\tiPhone\t6747890719",
        "wsp-app-sku\t5\t1F\tiPad\t6747890719",
        "wsp-app-sku\t7\tF1\tDesktop\t6747890719",
        "wsp-app-sku\t100\t7F\tiPhone\t6747890719",
        "wsp-app-sku\t20\t3F\tDesktop\t6747890719",
        "wsp-app-sku\t4\t3\tiPhone\t6747890719",
        "wsp-app-sku\t-2\t1F\tiPhone\t6747890719",
        "wsp-app-sku\t1\t1F\tApple Vision\t6747890719",
        "com.writingshedpro.manuscriptanalyst\t2\tIAY\tiPhone\t6771675601",
        "wsp-reader-sku\t3\t1F\tiPhone\t6758569999",
    ].join("\n");

    assert.deepEqual(summarizeAppDownloads(report), [
        { platform: "iOS", downloads: 17 },
        { platform: "macOS", downloads: 7 },
        { platform: "visionOS", downloads: 1 },
    ]);
});

test("returns only published daily report dates for a month", () => {
    assert.deepEqual(
        reportDatesForMonth("2026-11", new Date("2026-11-09T08:00:00Z")),
        [
            "2026-11-01", "2026-11-02", "2026-11-03", "2026-11-04",
            "2026-11-05", "2026-11-06", "2026-11-07", "2026-11-08",
        ]
    );
});

test("builds rolling sales ranges from completed UTC days", () => {
    const now = new Date("2026-11-15T09:27:19Z");

    assert.deepEqual(salesRangeTimestampRange("7d", now), {
        start: Date.UTC(2026, 10, 8),
        end: Date.UTC(2026, 10, 15),
    });

    assert.deepEqual(reportDatesForSalesRange("2w", now), [
        "2026-11-01", "2026-11-02", "2026-11-03", "2026-11-04",
        "2026-11-05", "2026-11-06", "2026-11-07", "2026-11-08",
        "2026-11-09", "2026-11-10", "2026-11-11", "2026-11-12",
        "2026-11-13", "2026-11-14",
    ]);
});

test("anchors Connect-style ranges to the latest published report", () => {
    assert.deepEqual(salesRangeTimestampRangeEndingOn("1d", "2026-11-13"), {
        start: Date.UTC(2026, 10, 13),
        end: Date.UTC(2026, 10, 14),
    });
    assert.deepEqual(salesRangeTimestampRangeEndingOn("7d", "2026-11-13"), {
        start: Date.UTC(2026, 10, 2),
        end: Date.UTC(2026, 10, 9),
    });
    assert.deepEqual(salesRangeTimestampRangeEndingOn("2w", "2026-11-13"), {
        start: Date.UTC(2026, 9, 26),
        end: Date.UTC(2026, 10, 9),
    });
});

test("reports Apple credential rejection as an upstream failure", () => {
    const error = appStoreConnectResponseError(401);

    assert.equal(error.status, 502);
    assert.match(error.message, /Apple rejected the Sales and Trends credentials/);
});

test("validates started and observed-expired trial events", () => {
    const now = 2_000_000_000_000;
    const trialID = "9dcf2424-4f77-4f0e-82d8-bddbbb66af13";
    const startedAt = now - TRIAL_DURATION_MS - 1_000;

    const started = validateTrialEvent({ trialID, event: "started", startedAt }, now);
    assert.equal(started.value.scheduledEndAt, startedAt + TRIAL_DURATION_MS);

    const expired = validateTrialEvent({
        trialID,
        event: "expired",
        startedAt,
        observedAt: now,
    }, now);
    assert.equal(expired.value.observedAt, now);
});

test("rejects an expiry observation before the ten-day trial end", () => {
    const now = 2_000_000_000_000;
    const startedAt = now - 1_000;
    const result = validateTrialEvent({
        trialID: "9dcf2424-4f77-4f0e-82d8-bddbbb66af13",
        event: "expired",
        startedAt,
        observedAt: now,
    }, now);

    assert.equal(result.error, "Invalid trial expiry date");
});

test("uses verified trial transactions for activity before lifecycle telemetry", () => {
    const start = Date.UTC(2026, 9, 1);
    const end = Date.UTC(2026, 10, 1);
    const trackingStartedAt = Date.UTC(2026, 10, 9);

    const metrics = buildTrialMetrics(
        "2026-10",
        null,
        {
            starts: 2,
            scheduled_ends: 2,
            conversions: 1,
            active_at_month_end: 1,
        },
        trackingStartedAt,
        start,
        end
    );

    assert.equal(metrics.starts, 2);
    assert.equal(metrics.scheduledEnds, 2);
    assert.equal(metrics.conversions, 1);
    assert.equal(metrics.activeAtMonthEnd, 1);
    assert.equal(metrics.isAvailable, true);
    assert.equal(metrics.isPartial, true);
});

test("does not double-count overlapping transaction and lifecycle trial reports", () => {
    const start = Date.UTC(2026, 10, 1);
    const end = Date.UTC(2026, 11, 1);
    const trackingStartedAt = Date.UTC(2026, 10, 9);

    const metrics = buildTrialMetrics(
        "2026-11",
        {
            starts: 3,
            scheduled_ends: 2,
            observed_expiries: 1,
            conversions: 1,
            active_at_month_end: 1,
        },
        {
            starts: 3,
            scheduled_ends: 2,
            conversions: 1,
            active_at_month_end: 1,
        },
        trackingStartedAt,
        start,
        end
    );

    assert.equal(metrics.starts, 3);
    assert.equal(metrics.scheduledEnds, 2);
    assert.equal(metrics.observedExpiries, 1);
    assert.equal(metrics.conversions, 1);
    assert.equal(metrics.activeAtMonthEnd, 1);
});
