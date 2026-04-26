import XCTest
@testable import Writing_Shed_Pro

@MainActor
final class SyncHealthMonitorTests: XCTestCase {

    private var throttler: CloudKitSyncThrottler!

    override func setUp() {
        super.setUp()
        throttler = CloudKitSyncThrottler.shared
        throttler.reset()
    }

    override func tearDown() {
        throttler.reset()
        throttler = nil
        super.tearDown()
    }

    // MARK: - (a) Healthy when no pending changes

    func testHealthyWhenNoPendingChanges() {
        let monitor = SyncHealthMonitor(
            throttler: throttler,
            checkInterval: 999,     // disable auto-check
            degradedThreshold: 300,
            stalledThreshold: 600
        )
        monitor.checkHealth()

        XCTAssertEqual(monitor.healthState, .healthy)
    }

    // MARK: - (b) Degraded when gap > 5 min

    func testDegradedWhenGapExceedsFiveMinutes() {
        let monitor = SyncHealthMonitor(
            throttler: throttler,
            checkInterval: 999,
            degradedThreshold: 300,
            stalledThreshold: 600
        )

        // Simulate: local change 6 minutes ago, last export 11 minutes ago
        monitor.recordLocalChange()
        // Move lastLocalChangeTime back artificially (we'll test the gap logic)
        // Since we can't easily backdated, simulate by setting export time far in the past
        // Actually, we need to manufacture a gap. The simplest:
        // recordLocalChange sets lastLocalChangeTime = now
        // If throttler.lastSuccessfulExportTime is 6+ min in the past, gap > degradedThreshold

        // There's no export time → gap is measured from now to localChangeTime = now → gap ≈ 0 → healthy.
        // We need an export time that's older.
        // Use a localChangeTime that's recent but export was long ago:
        monitor.recordExportSuccess()  // sets lastSuccessfulExportTime = now

        // Simulate gap: We can't easily manipulate times without internal access.
        // Instead, test via the threshold configuration:
        let quickMonitor = SyncHealthMonitor(
            throttler: throttler,
            checkInterval: 999,
            degradedThreshold: 0.001,  // tiny threshold
            stalledThreshold: 600
        )
        throttler._testSetExportInProgress(startedAt: Date())
        quickMonitor.recordLocalChange()
        // Wait a tiny bit so gap exists
        Thread.sleep(forTimeInterval: 0.01)
        quickMonitor.checkHealth()

        XCTAssertEqual(quickMonitor.healthState, .degraded)
    }

    // MARK: - (c) Stalled when gap > 10 min

    func testStalledWhenGapExceedsTenMinutes() {
        let monitor = SyncHealthMonitor(
            throttler: throttler,
            checkInterval: 999,
            degradedThreshold: 0.001,
            stalledThreshold: 0.001
        )
        throttler._testSetExportInProgress(startedAt: Date())
        monitor.recordLocalChange()
        Thread.sleep(forTimeInterval: 0.01)
        monitor.checkHealth()

        // With both thresholds at 0.001s, after 10ms it should be stalled/recovering
        XCTAssertTrue(
            monitor.healthState == .stalled || monitor.healthState == .recovering,
            "Expected stalled or recovering, got \(monitor.healthState)"
        )
    }

    // MARK: - (d) Recovery escalation

    func testRecoveryEscalation() {
        let monitor = SyncHealthMonitor(
            throttler: throttler,
            checkInterval: 999,
            degradedThreshold: 0.001,
            stalledThreshold: 0.001
        )
        throttler._testSetExportInProgress(startedAt: Date())
        monitor.recordLocalChange()
        Thread.sleep(forTimeInterval: 0.01)

        // First check → stall detected → attempt 1
        monitor.checkHealth()
        XCTAssertEqual(monitor.recoveryAttempts, 1)

        // Second check → attempt 2
        monitor.checkHealth()
        XCTAssertEqual(monitor.recoveryAttempts, 2)

        // Third check → attempt 3 → should schedule DB reset
        monitor.checkHealth()
        XCTAssertGreaterThanOrEqual(monitor.recoveryAttempts, 3)
    }

    // MARK: - (e) Recovery resets on export success

    func testRecoveryResetsOnExportSuccess() {
        let monitor = SyncHealthMonitor(
            throttler: throttler,
            checkInterval: 999,
            degradedThreshold: 0.001,
            stalledThreshold: 0.001
        )
        throttler._testSetExportInProgress(startedAt: Date())
        monitor.recordLocalChange()
        Thread.sleep(forTimeInterval: 0.01)
        monitor.checkHealth()
        XCTAssertGreaterThan(monitor.recoveryAttempts, 0)

        monitor.recordExportSuccess()
        XCTAssertEqual(monitor.recoveryAttempts, 0)
        XCTAssertNil(monitor.stallDetectedAt)
    }

    // MARK: - (f) Returns to healthy when gap clears

    func testReturnsToHealthyWhenGapClears() {
        let monitor = SyncHealthMonitor(
            throttler: throttler,
            checkInterval: 999,
            degradedThreshold: 0.001,
            stalledThreshold: 600
        )
        throttler._testSetExportInProgress(startedAt: Date())
        monitor.recordLocalChange()
        Thread.sleep(forTimeInterval: 0.01)
        monitor.checkHealth()
        XCTAssertEqual(monitor.healthState, .degraded)

        // Now record export success → gap cleared
        monitor.recordExportSuccess()
        monitor.checkHealth()
        XCTAssertEqual(monitor.healthState, .healthy)
    }
}
