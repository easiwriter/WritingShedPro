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
        throttler._testSetImportInProgress(startedAt: Date().addingTimeInterval(-310))

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

        let expectation = expectation(description: "Mirroring reset clears in-progress flags")

        NotificationCenter.default.post(
            name: NSNotification.Name("NSCloudKitMirroringDelegateDidResetSyncNotificationName"),
            object: nil,
            userInfo: ["NSCloudKitMirroringDelegateResetReasonKey": "ServerChangeTokenExpired"]
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(throttler.importInProgress)
            XCTAssertFalse(throttler.exportInProgress)

            let resetEvent = throttler.recentCloudKitEvents.first {
                $0.type == "mirroring" && $0.phase == "did-reset" && $0.status == "reset"
            }
            XCTAssertNotNil(resetEvent)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testRepeatedImportStartDoesNotResetOriginalStartTime() {
        let throttler = CloudKitSyncThrottler.shared
        let originalStart = Date().addingTimeInterval(-310)
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
        let originalStart = Date().addingTimeInterval(-310)
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

        let expectation = expectation(description: "Mirroring reset sets isPostReset")

        NotificationCenter.default.post(
            name: NSNotification.Name("NSCloudKitMirroringDelegateDidResetSyncNotificationName"),
            object: nil,
            userInfo: ["NSCloudKitMirroringDelegateResetReasonKey": "ManualReset"]
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(throttler.isPostReset)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testResetClearsIsPostReset() {
        let throttler = CloudKitSyncThrottler.shared

        let expectation = expectation(description: "Reset clears isPostReset")

        // First set it via mirroring reset
        NotificationCenter.default.post(
            name: NSNotification.Name("NSCloudKitMirroringDelegateDidResetSyncNotificationName"),
            object: nil,
            userInfo: [:]
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(throttler.isPostReset)
            throttler.reset()
            XCTAssertFalse(throttler.isPostReset)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testPostResetUsesLongerStaleTimeout() {
        let throttler = CloudKitSyncThrottler.shared

        let expectation = expectation(description: "Post-reset uses longer timeout")

        // Trigger mirroring reset to set isPostReset
        NotificationCenter.default.post(
            name: NSNotification.Name("NSCloudKitMirroringDelegateDidResetSyncNotificationName"),
            object: nil,
            userInfo: [:]
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(throttler.isPostReset)

            // Set import started 400s ago (> 300s normal, < 900s post-reset)
            throttler._testSetImportInProgress(startedAt: Date().addingTimeInterval(-400))

            // With isPostReset=true, 400s < 900s threshold → should stay active
            let active = throttler.hasActiveCloudKitEvent
            XCTAssertTrue(active, "400s should not trigger stale timeout during post-reset (threshold is 900s)")
            XCTAssertTrue(throttler.importInProgress)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }
}
