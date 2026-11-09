import assert from "node:assert/strict";
import test from "node:test";
import {
    reportDatesForMonth,
    summarizeSalesReport,
} from "../src/apple-sales-reports.mjs";
import {
    TRIAL_DURATION_MS,
    validateTrialEvent,
} from "../src/trial-telemetry.mjs";

test("summarizes Writing Shed purchases and refunds by product SKU", () => {
    const report = [
        "SKU\tUnits\tProduct Type Identifier",
        "com.writingshedpro.fullaccess\t3\tIA1",
        "com.writingshedpro.fullaccess\t-1\tIA1",
        "com.writingshedpro.manuscriptanalyst\t2\tIAY",
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

test("returns only published daily report dates for a month", () => {
    assert.deepEqual(
        reportDatesForMonth("2026-11", new Date("2026-11-09T08:00:00Z")),
        [
            "2026-11-01", "2026-11-02", "2026-11-03", "2026-11-04",
            "2026-11-05", "2026-11-06", "2026-11-07", "2026-11-08",
        ]
    );
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
