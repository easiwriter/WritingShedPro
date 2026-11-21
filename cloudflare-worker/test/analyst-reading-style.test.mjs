import assert from "node:assert/strict";
import test from "node:test";
import { buildAnalystReadingStyleGuidance } from "../src/analyst-reading-style.mjs";

test("defines substantial first and second readings without defect-counting", () => {
    const guidance = buildAnalystReadingStyleGuidance("poetry");

    assert.match(guidance, /summary is the FIRST READING/);
    assert.match(guidance, /suggestions collectively form the SECOND READING/);
    assert.match(guidance, /not as an inventory of defects/);
    assert.match(guidance, /Give strengths real analytical attention/);
    assert.match(guidance, /do not manufacture faults/i);
    assert.match(guidance, /Read the piece on its own terms/);
    assert.match(guidance, /Overall assessment/);
    assert.match(guidance, /5-8 substantial second-reading sections/);
});

test("adapts the reading guidance to the requested profile", () => {
    const guidance = buildAnalystReadingStyleGuidance("drama");

    assert.match(guidance, /this drama piece/);
});
