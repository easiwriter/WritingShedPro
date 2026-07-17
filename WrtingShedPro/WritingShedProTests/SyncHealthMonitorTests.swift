import XCTest
@testable import Writing_Shed_Pro

@MainActor
final class SyncHealthMonitorTests: XCTestCase {

    func testHealthyWhenNoPendingChanges() {
        let monitor = SyncHealthMonitor()

        monitor.checkHealth()

        XCTAssertEqual(monitor.healthState, .healthy)
    }

    func testLocalChangeMarksSyncing() {
        let monitor = SyncHealthMonitor()

        monitor.recordLocalChange()

        XCTAssertEqual(monitor.healthState, .syncing)
        XCTAssertNotNil(monitor.lastLocalChangeTime)
    }

    func testExportSuccessMarksHealthy() {
        let monitor = SyncHealthMonitor()

        monitor.recordLocalChange()
        monitor.recordExportSuccess()

        XCTAssertEqual(monitor.healthState, .healthy)
        XCTAssertNotNil(monitor.lastSuccessfulExportTime)
    }

    func testBlockingFailureMarksBlocked() {
        let monitor = SyncHealthMonitor()

        monitor.recordExportFailure(isBlocking: true)

        XCTAssertEqual(monitor.healthState, .blocked)
        XCTAssertNotNil(monitor.stallDetectedAt)
    }

    func testNonBlockingFailureMarksDegraded() {
        let monitor = SyncHealthMonitor()

        monitor.recordExportFailure(isBlocking: false)

        XCTAssertEqual(monitor.healthState, .degraded)
    }
}
