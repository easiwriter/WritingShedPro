export const SALES_RANGES = Object.freeze([
    { id: "1d", days: 1 },
    { id: "7d", days: 7 },
    { id: "2w", days: 14 },
    { id: "5w", days: 35 },
    { id: "13w", days: 91 },
    { id: "26w", days: 182 },
]);

export function isValidSalesRange(range) {
    return SALES_RANGES.some((option) => option.id === range);
}

export function salesRangeTimestampRange(range, now = new Date()) {
    const option = SALES_RANGES.find((candidate) => candidate.id === range);
    if (!option) return null;

    const end = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
    return {
        start: end - option.days * 24 * 60 * 60 * 1000,
        end,
    };
}

export function salesRangeTimestampRangeEndingOn(range, reportDate) {
    const option = SALES_RANGES.find((candidate) => candidate.id === range);
    if (!option || !/^\d{4}-\d{2}-\d{2}$/.test(reportDate)) return null;

    const reportTimestamp = Date.parse(`${reportDate}T00:00:00Z`);
    if (!Number.isFinite(reportTimestamp)) return null;

    const dayMilliseconds = 24 * 60 * 60 * 1000;
    const end = range === "1d"
        ? reportTimestamp + dayMilliseconds
        : reportTimestamp
            - new Date(reportTimestamp).getUTCDay() * dayMilliseconds
            + dayMilliseconds;
    return {
        start: end - option.days * dayMilliseconds,
        end,
    };
}

export function reportDatesForSalesRange(range, now = new Date()) {
    const timestamps = salesRangeTimestampRange(range, now);
    return reportDatesForTimestampRange(timestamps);
}

export function reportDatesForTimestampRange(timestamps) {
    if (!timestamps) return [];

    const dates = [];
    for (
        let timestamp = timestamps.start;
        timestamp < timestamps.end;
        timestamp += 24 * 60 * 60 * 1000
    ) {
        dates.push(new Date(timestamp).toISOString().slice(0, 10));
    }
    return dates;
}
