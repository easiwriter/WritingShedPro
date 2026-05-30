import XCTest
@testable import Writing_Shed_Pro

final class CloudKitSyncThrottlerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CloudKitSyncThrottler.shared.reset()
    }

    override func tearDown() {
        CloudKitSyncThrottler.shared.reset()
        super.tearDown()
    }

    func testHasActiveCloudKitEventClearsStaleImportAfterTimeout() {
        let throttler = CloudKitSyncThrottler.shared
        throttler._testSetImportInProgress(startedAt: Date().addingTimeInterval(-610))

        let active = throttler.hasActiveCloudKitEvent

        XCTAssertFalse(active)
        XCTAssertFalse(throttler.importInProgress)
        XCTAssertTrue(throttler.importCompleted)
        XCTAssertFalse(throttler.importSucceeded)

        let staleEvent = throttler.recentCloudKitEvents.first {
            $0.type == "import" && $0.phase == "timeout" && $0.status == "stale-cleared"
        }
        XCTAssertNotNil(staleEvent)
    }

    func testHasActiveCloudKitEventKeepsRecentImportActive() {
        let throttler = CloudKitSyncThrottler.shared
        throttler._testSetImportInProgress(startedAt: Date().addingTimeInterval(-30))

        let active = throttler.hasActiveCloudKitEvent

        XCTAssertTrue(active)
        XCTAssertTrue(throttler.importInProgress)
    }

    func testMirroringResetClearsInProgressFlags() {
        let throttler = CloudKitSyncThrottler.shared
        throttler._testSetImportInProgress(startedAt: Date())
        throttler._testSetExportInProgress(startedAt: Date())

        throttler._testHandleMirroringReset(reason: "ServerChangeTokenExpired")

        XCTAssertFalse(throttler.importInProgress)
        XCTAssertFalse(throttler.exportInProgress)

        let resetEvent = throttler.recentCloudKitEvents.first {
            $0.type == "mirroring" && $0.phase == "did-reset" && $0.status == "reset"
        }
        XCTAssertNotNil(resetEvent)
    }

    func testRepeatedImportStartDoesNotResetOriginalStartTime() {
        let throttler = CloudKitSyncThrottler.shared
        let originalStart = Date().addingTimeInterval(-610)
        throttler._testMarkImportStarted(at: originalStart)
        throttler._testMarkImportStarted(at: Date())

        let active = throttler.hasActiveCloudKitEvent

        XCTAssertFalse(active)
        XCTAssertFalse(throttler.importInProgress)

        let staleEvent = throttler.recentCloudKitEvents.first {
            $0.type == "import" && $0.phase == "timeout" && $0.status == "stale-cleared"
        }
        XCTAssertNotNil(staleEvent)
    }

    func testRepeatedExportStartDoesNotResetOriginalStartTime() {
        let throttler = CloudKitSyncThrottler.shared
        let originalStart = Date().addingTimeInterval(-610)
        throttler._testMarkExportStarted(at: originalStart)
        throttler._testMarkExportStarted(at: Date())

        let active = throttler.hasActiveCloudKitEvent

        XCTAssertFalse(active)
        XCTAssertFalse(throttler.exportInProgress)

        let staleEvent = throttler.recentCloudKitEvents.first {
            $0.type == "export" && $0.phase == "timeout" && $0.status == "stale-cleared"
        }
        XCTAssertNotNil(staleEvent)
    }

    // MARK: - lastSuccessfulExportTime

    func testLastSuccessfulExportTimeIsNilInitially() {
        let throttler = CloudKitSyncThrottler.shared
        XCTAssertNil(throttler.lastSuccessfulExportTime)
    }

    func testLastSuccessfulExportTimeResetToNil() {
        let throttler = CloudKitSyncThrottler.shared
        // After reset, the property should be nil
        throttler.reset()
        XCTAssertNil(throttler.lastSuccessfulExportTime)
    }

    // MARK: - isPostReset

    func testIsPostResetFalseInitially() {
        let throttler = CloudKitSyncThrottler.shared
        throttler.reset()
        XCTAssertFalse(throttler.isPostReset)
    }

    func testMirroringResetSetsIsPostReset() {
        let throttler = CloudKitSyncThrottler.shared

        throttler._testHandleMirroringReset(reason: "ManualReset")

        XCTAssertTrue(throttler.isPostReset)
    }

    func testResetClearsIsPostReset() {
        let throttler = CloudKitSyncThrottler.shared

        // First set it via mirroring reset
        throttler._testHandleMirroringReset()

        throttler.reset()
        XCTAssertFalse(throttler.isPostReset)
    }

    func testPostResetUsesLongerStaleTimeout() {
        let throttler = CloudKitSyncThrottler.shared

        // Trigger mirroring reset to set isPostReset
        throttler._testHandleMirroringReset()
        XCTAssertTrue(throttler.isPostReset)

        // Set import started 1200s ago (> 600s normal, < 1800s post-reset)
        throttler._testSetImportInProgress(startedAt: Date().addingTimeInterval(-1200))

        // With isPostReset=true, 1200s < 1800s threshold → should stay active
        let active = throttler.hasActiveCloudKitEvent
        XCTAssertTrue(active, "1200s should not trigger stale timeout during post-reset (threshold is 1800s)")
        XCTAssertTrue(throttler.importInProgress)
    }
}
