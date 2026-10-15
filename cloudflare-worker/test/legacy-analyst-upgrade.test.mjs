import assert from "node:assert/strict";
import test from "node:test";
import {
    LEGACY_ANALYST_UPGRADE_STATUS,
    createLegacyAnalystUpgradeResponse,
    isLegacyAnalystRequest,
} from "../src/legacy-analyst-upgrade.mjs";

test("detects requests from clients that do not send a transaction header", () => {
    assert.equal(isLegacyAnalystRequest(null), true);
    assert.equal(isLegacyAnalystRequest(undefined), true);
    assert.equal(isLegacyAnalystRequest("   "), true);
    assert.equal(isLegacyAnalystRequest("2000000123456789"), false);
});

test("creates a non-analysis update notice for legacy clients", () => {
    const now = new Date("2026-10-15T10:30:00.000Z");
    const response = createLegacyAnalystUpgradeResponse("fiction", now);

    assert.equal(response.status, LEGACY_ANALYST_UPGRADE_STATUS);
    assert.equal(response.timestamp, now.toISOString());
    assert.equal(response.reviewId, `update-required-${now.getTime()}`);
    assert.equal(response.analysis.analysisProfile, "fiction");
    assert.match(response.analysis.summary, /must be updated/i);
    assert.match(response.analysis.summary, /App Store/i);
    assert.deepEqual(response.suggestions, []);
    assert.equal(response.metadata.contentAnalyzed, 0);
    assert.equal(response.metadata.tokensUsed, 0);
    assert.equal(response.metadata.model, "none");
});
