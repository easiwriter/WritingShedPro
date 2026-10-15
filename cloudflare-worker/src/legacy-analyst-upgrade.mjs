export const LEGACY_ANALYST_UPGRADE_STATUS = "update_required";

export function isLegacyAnalystRequest(transactionID) {
    return typeof transactionID !== "string" || transactionID.trim().length === 0;
}

export function createLegacyAnalystUpgradeResponse(analysisProfile, now = new Date()) {
    return {
        status: LEGACY_ANALYST_UPGRADE_STATUS,
        timestamp: now.toISOString(),
        reviewId: `update-required-${now.getTime()}`,
        analysis: {
            summary: "This version of Writing Shed Pro must be updated before Manuscript Analyst can be used. Open the App Store, find Writing Shed Pro, and select Update. Your subscription has not been charged for this request.",
            overallSentiment: "mixed",
            analysisProfile,
            suggestedFocusOrder: [],
            authorshipAssessment: null,
        },
        suggestions: [],
        metadata: {
            contentAnalyzed: 0,
            tokensUsed: 0,
            analysisTimeMs: 0,
            model: "none",
            softCapState: "normal",
        },
    };
}
