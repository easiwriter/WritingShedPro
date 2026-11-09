const TRIAL_ID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TRIAL_EVENTS = new Set(["started", "expired"]);
const TRIAL_DURATION_MS = 10 * 24 * 60 * 60 * 1000;
const MAX_CLOCK_SKEW_MS = 5 * 60 * 1000;

export function validateTrialEvent(body, now = Date.now()) {
    const trialID = typeof body?.trialID === "string" ? body.trialID.trim() : "";
    const event = typeof body?.event === "string" ? body.event.trim() : "";
    const startedAt = Number(body?.startedAt);
    const observedAt = body?.observedAt == null ? null : Number(body.observedAt);

    if (!TRIAL_ID_PATTERN.test(trialID)) {
        return { error: "Invalid trialID" };
    }
    if (!TRIAL_EVENTS.has(event)) {
        return { error: "Invalid trial event" };
    }
    if (!Number.isFinite(startedAt) || startedAt <= 0 || startedAt > now + MAX_CLOCK_SKEW_MS) {
        return { error: "Invalid trial start date" };
    }
    if (event === "expired") {
        if (!Number.isFinite(observedAt) || observedAt < startedAt + TRIAL_DURATION_MS) {
            return { error: "Invalid trial expiry date" };
        }
        if (observedAt > now + MAX_CLOCK_SKEW_MS) {
            return { error: "Invalid trial expiry date" };
        }
    }

    return {
        value: {
            trialID: trialID.toLowerCase(),
            event,
            startedAt: Math.trunc(startedAt),
            scheduledEndAt: Math.trunc(startedAt) + TRIAL_DURATION_MS,
            observedAt: observedAt == null ? null : Math.trunc(observedAt),
        },
    };
}

export function emptyTrialMetrics(month) {
    return {
        month,
        starts: 0,
        scheduledEnds: 0,
        observedExpiries: 0,
        conversions: 0,
        activeAtMonthEnd: 0,
    };
}

export { TRIAL_DURATION_MS };
