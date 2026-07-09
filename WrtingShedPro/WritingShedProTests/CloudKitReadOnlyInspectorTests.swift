import XCTest
@testable import Writing_Shed_Pro

final class CloudKitReadOnlyInspectorTests: XCTestCase {
    func testClassifiesExpectedDefaultProposedAndForeignZones() {
        let inspector = CloudKitReadOnlyInspector(client: FakeReadOnlyCloudKitClient())

        let zones = inspector.classify(zoneNames: [
            CloudKitReadOnlyInspector.existingCoreDataZoneName,
            CloudKitReadOnlyInspector.defaultZoneName,
            CloudKitReadOnlyInspector.proposedSyncZoneName,
            "co.pointfree.SQLiteData.defaultZone"
        ])

        XCTAssertEqual(zones, [
            CloudKitZoneInventoryItem(zoneName: CloudKitReadOnlyInspector.defaultZoneName, classification: .defaultZone),
            CloudKitZoneInventoryItem(zoneName: CloudKitReadOnlyInspector.existingCoreDataZoneName, classification: .existingCoreDataZone),
            CloudKitZoneInventoryItem(zoneName: CloudKitReadOnlyInspector.proposedSyncZoneName, classification: .proposedCKSyncEngineZone),
            CloudKitZoneInventoryItem(zoneName: "co.pointfree.SQLiteData.defaultZone", classification: .foreignZone)
        ])
    }

    func testMissingProposedZoneIsWarningOnly() async {
        let client = FakeReadOnlyCloudKitClient(zoneNames: [CloudKitReadOnlyInspector.existingCoreDataZoneName])
        let inspector = CloudKitReadOnlyInspector(client: client)

        let report = await inspector.inspect()

        XCTAssertEqual(client.zoneReadCount, 1)
        XCTAssertTrue(report.warnings.contains("Proposed CKSyncEngine zone is missing; this is expected before shadow sync creates it."))
        XCTAssertFalse(report.redactedText().lowercased().contains("delete"))
        XCTAssertFalse(report.redactedText().lowercased().contains("reset"))
    }

    func testUnavailableAccountDoesNotReadZones() async {
        let client = FakeReadOnlyCloudKitClient(accountStatus: .noAccount, zoneNames: [CloudKitReadOnlyInspector.existingCoreDataZoneName])
        let inspector = CloudKitReadOnlyInspector(client: client)

        let report = await inspector.inspect()

        XCTAssertEqual(client.zoneReadCount, 0)
        XCTAssertEqual(report.accountStatus, .noAccount)
        XCTAssertTrue(report.zones.isEmpty)
    }

    func testCombinesLocalDryRunCountsWithoutManuscriptContent() async {
        let project = Project(name: "Inspector", type: .prose)
        let mapper = CoreRecordMapper()
        let dryRunReport = DryRunSyncReport(envelopes: [mapper.map(project: project)])
        let inspector = CloudKitReadOnlyInspector(client: FakeReadOnlyCloudKitClient(zoneNames: [CloudKitReadOnlyInspector.proposedSyncZoneName]))

        let report = await inspector.inspect(localDryRunReport: dryRunReport)
        let text = report.redactedText()

        XCTAssertTrue(text.contains("Local dry-run:"))
        XCTAssertTrue(text.contains("- Project: 1"))
        XCTAssertFalse(text.contains("Inspector"))
    }

    func testSystemClientReadOnlyInspectorCanRunTwiceWhenExplicitlyEnabled() async throws {
        guard ProcessInfo.processInfo.environment["WSP_RUN_REAL_CLOUDKIT_INSPECTOR"] == "1" else {
            throw XCTSkip("Set WSP_RUN_REAL_CLOUDKIT_INSPECTOR=1 to manually verify the real read-only CloudKit inspector.")
        }

        let inspector = CloudKitReadOnlyInspector()

        let firstReport = await inspector.inspect()
        let secondReport = await inspector.inspect()

        XCTAssertEqual(firstReport.accountStatus, .available)
        XCTAssertEqual(secondReport.accountStatus, .available)
        XCTAssertEqual(firstReport.zones, secondReport.zones)
        XCTAssertFalse(firstReport.redactedText().lowercased().contains("reset"))
        XCTAssertFalse(secondReport.redactedText().lowercased().contains("reset"))
    }
}

private final class FakeReadOnlyCloudKitClient: ReadOnlyCloudKitClient {
    private let status: CloudKitInspectorAccountStatus
    private let zones: [String]
    private(set) var zoneReadCount = 0

    init(accountStatus: CloudKitInspectorAccountStatus = .available, zoneNames: [String] = []) {
        self.status = accountStatus
        self.zones = zoneNames
    }

    func accountStatus() async -> CloudKitInspectorAccountStatus {
        status
    }

    func privateZoneNames() async throws -> [String] {
        zoneReadCount += 1
        return zones
    }
}
