import XCTest
@testable import Writing_Shed_Pro

final class CKSyncEngineShadowSyncReadinessTests: XCTestCase {
    func testShadowSyncDefaultsOffWithKillSwitchesEnabled() {
        let report = ShadowSyncReadinessChecker().evaluate(ShadowSyncConfiguration())

        XCTAssertFalse(report.canAttemptShadowWrite)
        XCTAssertTrue(report.issues.contains { $0.code == "feature-disabled" })
        XCTAssertTrue(report.issues.contains { $0.code == "local-kill-switch-enabled" })
        XCTAssertTrue(report.issues.contains { $0.code == "remote-kill-switch-enabled" })
    }

    func testReadyConfigurationUsesReviewedZoneAndFirstScope() {
        let configuration = ShadowSyncConfiguration(
            isFeatureEnabled: true,
            localKillSwitchEnabled: false,
            remoteKillSwitchEnabled: false
        )

        let report = ShadowSyncReadinessChecker().evaluate(configuration)

        XCTAssertTrue(report.canAttemptShadowWrite)
        XCTAssertTrue(report.issues.isEmpty)
    }

    func testExistingCoreDataZoneIsRejected() {
        let configuration = ShadowSyncConfiguration(
            zoneName: ShadowSyncConfiguration.existingCoreDataZoneName,
            isFeatureEnabled: true,
            localKillSwitchEnabled: false,
            remoteKillSwitchEnabled: false
        )

        let report = ShadowSyncReadinessChecker().evaluate(configuration)

        XCTAssertFalse(report.canAttemptShadowWrite)
        XCTAssertTrue(report.issues.contains { $0.code == "core-data-zone-targeted" })
    }

    func testUnsupportedRecordTypesAreRejected() {
        let configuration = ShadowSyncConfiguration(
            isFeatureEnabled: true,
            localKillSwitchEnabled: false,
            remoteKillSwitchEnabled: false,
            allowedRecordTypes: ["Project", "CommentModel"]
        )

        let report = ShadowSyncReadinessChecker().evaluate(configuration)

        XCTAssertFalse(report.canAttemptShadowWrite)
        XCTAssertTrue(report.issues.contains { $0.code == "unsupported-shadow-record-types" })
    }

    func testAssetsAndTombstonesAreRejectedForFirstShadowScope() {
        let configuration = ShadowSyncConfiguration(
            isFeatureEnabled: true,
            localKillSwitchEnabled: false,
            remoteKillSwitchEnabled: false,
            allowsAssets: true,
            allowsTombstones: true
        )

        let report = ShadowSyncReadinessChecker().evaluate(configuration)

        XCTAssertFalse(report.canAttemptShadowWrite)
        XCTAssertTrue(report.issues.contains { $0.code == "assets-not-reviewed-for-shadow" })
        XCTAssertTrue(report.issues.contains { $0.code == "tombstones-not-reviewed-for-shadow" })
    }

    func testComparisonReportListsMismatchesAndExcludedAssetsWithoutContent() {
        let report = ShadowSyncComparisonReport(
            localRecordCounts: ["Project": 2, "Version": 3],
            shadowRecordCounts: ["Project": 2, "Version": 2],
            excludedAssetCounts: ["Version.formattedContent": 3]
        )

        XCTAssertEqual(report.mismatchedRecordTypes, ["Version"])
        XCTAssertTrue(report.redactedText().contains("Version.formattedContent: 3"))
        XCTAssertFalse(report.redactedText().contains("formatted manuscript body"))
    }

    func testOperationPlannerBlocksWhenReadinessIsBlocked() {
        let readiness = ShadowSyncReadinessChecker().evaluate(ShadowSyncConfiguration())
        let exportReport = ExportDryRunReport(operations: [
            ExportDryRunOperation(kind: .wouldSaveRecord, recordType: "Project", recordName: "Project:one")
        ])

        let plan = ShadowSyncOperationPlanner().plan(readinessReport: readiness, exportDryRunReport: exportReport)

        XCTAssertFalse(plan.canExecute)
        XCTAssertTrue(plan.operations.isEmpty)
        XCTAssertTrue(plan.blockedIssues.contains { $0.code == "readiness-blocked" })
    }

    func testOperationPlannerPlansAllowedRecordSavesOnly() {
        let readiness = readyReadinessReport()
        let exportReport = ExportDryRunReport(operations: [
            ExportDryRunOperation(kind: .wouldSaveRecord, recordType: "Project", recordName: "Project:one"),
            ExportDryRunOperation(kind: .wouldDefer, recordType: "Publication", recordName: "Publication:one"),
            ExportDryRunOperation(kind: .warning, recordType: "TextFile", recordName: "TextFile:one")
        ])

        let plan = ShadowSyncOperationPlanner().plan(readinessReport: readiness, exportDryRunReport: exportReport)

        XCTAssertTrue(plan.canExecute)
        XCTAssertEqual(plan.operations, [
            ShadowSyncPlannedOperation(kind: .saveRecord, recordType: "Project", recordName: "Project:one")
        ])
        XCTAssertTrue(plan.blockedIssues.isEmpty)
    }

    func testOperationPlannerRejectsAssetsTombstonesAndUnsupportedRecords() {
        let readiness = readyReadinessReport()
        let exportReport = ExportDryRunReport(operations: [
            ExportDryRunOperation(kind: .wouldSaveRecord, recordType: "CommentModel", recordName: "CommentModel:one"),
            ExportDryRunOperation(kind: .wouldSaveAsset, recordType: "TextFile", recordName: "TextFile:one", fieldName: "coverImageData"),
            ExportDryRunOperation(kind: .wouldSaveTombstone, recordType: "Project", recordName: "Tombstone:one")
        ])

        let plan = ShadowSyncOperationPlanner().plan(readinessReport: readiness, exportDryRunReport: exportReport)

        XCTAssertFalse(plan.canExecute)
        XCTAssertTrue(plan.operations.isEmpty)
        XCTAssertTrue(plan.blockedIssues.contains { $0.code == "operation-record-type-not-allowed" })
        XCTAssertTrue(plan.blockedIssues.contains { $0.code == "operation-asset-not-allowed" })
        XCTAssertTrue(plan.blockedIssues.contains { $0.code == "operation-tombstone-not-allowed" })
    }

    func testDiagnosticsReportSummarizesStateWithoutErrorDetailsOrContent() {
        let readiness = readyReadinessReport()
        let exportReport = ExportDryRunReport(operations: [
            ExportDryRunOperation(kind: .wouldSaveRecord, recordType: "Project", recordName: "Project:one")
        ])
        let plan = ShadowSyncOperationPlanner().plan(readinessReport: readiness, exportDryRunReport: exportReport)
        let comparison = ShadowSyncComparisonReport(
            localRecordCounts: ["Project": 1],
            shadowRecordCounts: ["Project": 0],
            excludedAssetCounts: ["Version.formattedContent": 1]
        )

        let diagnostics = ShadowSyncDiagnosticsReport(
            readinessReport: readiness,
            zonePreflightReport: ShadowSyncZonePreflightReport(status: .proposedZoneAvailable, issues: []),
            operationPlan: plan,
            stopConditionReport: ShadowSyncStopConditionReport(conditions: []),
            attemptSnapshot: ShadowSyncAttemptSnapshot(lastExportAttempt: .wouldStart, lastImportReadAttempt: .succeeded, pendingOperationCount: 2),
            comparisonReport: comparison,
            existingSyncActive: true,
            lastErrorCode: "network-unavailable"
        )

        let text = diagnostics.redactedText()
        XCTAssertTrue(text.contains("Enabled: enabled"))
        XCTAssertTrue(text.contains("Zone preflight: proposedZoneAvailable"))
        XCTAssertTrue(text.contains("Zone isolation confirmed: true"))
        XCTAssertTrue(text.contains("Kill switch: off"))
        XCTAssertTrue(text.contains("Existing sync active: true"))
        XCTAssertTrue(text.contains("saveRecord: 1"))
        XCTAssertTrue(text.contains("Must disable shadow sync: false"))
        XCTAssertTrue(text.contains("Last export attempt: wouldStart"))
        XCTAssertTrue(text.contains("Last import read attempt: succeeded"))
        XCTAssertTrue(text.contains("Pending operation count: 2"))
        XCTAssertTrue(text.contains("Project"))
        XCTAssertTrue(text.contains("network-unavailable"))
        XCTAssertFalse(text.contains("formatted manuscript body"))
        XCTAssertFalse(text.contains("private CloudKit error details"))
    }

    func testDiagnosticsReportIncludesZonePreflightIssues() {
        let readiness = readyReadinessReport()
        let plan = ShadowSyncOperationPlan(operations: [], blockedIssues: [])
        let preflight = ShadowSyncZonePreflightReport(status: .proposedZoneMissing, issues: [
            ShadowSyncReadinessIssue(severity: .info, code: "proposed-zone-missing", message: "Zone is not present.")
        ])

        let diagnostics = ShadowSyncDiagnosticsReport(
            readinessReport: readiness,
            zonePreflightReport: preflight,
            operationPlan: plan,
            stopConditionReport: nil,
            attemptSnapshot: nil,
            comparisonReport: nil,
            existingSyncActive: true,
            lastErrorCode: nil
        )

        let text = diagnostics.redactedText()
        XCTAssertTrue(text.contains("Zone preflight: proposedZoneMissing"))
        XCTAssertTrue(text.contains("Zone isolation confirmed: true"))
        XCTAssertTrue(text.contains("info: proposed-zone-missing"))
    }

    func testStopConditionCheckerRequiresDisableForProductionDataRisks() {
        let report = ShadowSyncStopConditionChecker().evaluate(ShadowSyncStopConditionInput(
            targetZoneName: ShadowSyncConfiguration.existingCoreDataZoneName,
            localSwiftDataDeleteRequested: true,
            cloudKitDeleteRequested: true,
            cloudKitDeleteHasReviewedTombstone: false
        ))

        XCTAssertTrue(report.mustDisableShadowSync)
        XCTAssertEqual(Set(report.conditions), [
            .existingCoreDataZoneTargeted,
            .localSwiftDataDeleteRequested,
            .unreviewedCloudKitDeleteRequested
        ])
    }

    func testStopConditionCheckerAllowsReviewedTombstoneDeleteSignal() {
        let report = ShadowSyncStopConditionChecker().evaluate(ShadowSyncStopConditionInput(
            cloudKitDeleteRequested: true,
            cloudKitDeleteHasReviewedTombstone: true
        ))

        XCTAssertFalse(report.mustDisableShadowSync)
        XCTAssertTrue(report.conditions.isEmpty)
    }

    func testStopConditionCheckerRequiresDisableForErrorLoopAndLatencyImpact() {
        let report = ShadowSyncStopConditionChecker().evaluate(ShadowSyncStopConditionInput(
            consecutiveErrorCount: 3,
            repeatedErrorLimit: 3,
            launchLatencyImpactDetected: true,
            editorSaveLatencyImpactDetected: true
        ))

        XCTAssertTrue(report.mustDisableShadowSync)
        XCTAssertEqual(Set(report.conditions), [
            .repeatedErrorLoop,
            .launchLatencyImpact,
            .editorSaveLatencyImpact
        ])
    }

    func testDiagnosticsReportIncludesStopConditions() {
        let readiness = readyReadinessReport()
        let diagnostics = ShadowSyncDiagnosticsReport(
            readinessReport: readiness,
            zonePreflightReport: nil,
            operationPlan: ShadowSyncOperationPlan(operations: [], blockedIssues: []),
            stopConditionReport: ShadowSyncStopConditionReport(conditions: [.repeatedErrorLoop]),
            attemptSnapshot: nil,
            comparisonReport: nil,
            existingSyncActive: true,
            lastErrorCode: "rate-limited"
        )

        let text = diagnostics.redactedText()
        XCTAssertTrue(text.contains("Must disable shadow sync: true"))
        XCTAssertTrue(text.contains("repeatedErrorLoop"))
        XCTAssertTrue(text.contains("rate-limited"))
    }

    func testAttemptSnapshotRedactsToStateAndCountsOnly() {
        let snapshot = ShadowSyncAttemptSnapshot(
            lastExportAttempt: .failed,
            lastImportReadAttempt: .skipped,
            pendingOperationCount: 4
        )

        let text = snapshot.redactedText()
        XCTAssertTrue(text.contains("Last export attempt: failed"))
        XCTAssertTrue(text.contains("Last import read attempt: skipped"))
        XCTAssertTrue(text.contains("Pending operation count: 4"))
        XCTAssertFalse(text.contains("Project:private-record-name"))
        XCTAssertFalse(text.contains("CloudKit internal error payload"))
    }

    func testGateReviewReportIsReadyOnlyWhenAllPreWriteChecksPass() {
        let report = ShadowSyncGateReviewReport(diagnosticsReport: passingDiagnosticsReport())

        XCTAssertTrue(report.isReadyForHumanWriteReview)
        XCTAssertTrue(report.blockers.isEmpty)
        XCTAssertTrue(report.redactedText().contains("Ready for human write review: true"))
    }

    func testGateReviewReportListsBlockersWithoutAuthorizingWrites() {
        let readiness = ShadowSyncReadinessChecker().evaluate(ShadowSyncConfiguration())
        let diagnostics = ShadowSyncDiagnosticsReport(
            readinessReport: readiness,
            zonePreflightReport: ShadowSyncZonePreflightReport(status: .unexpectedZoneClassification, issues: [
                ShadowSyncReadinessIssue(severity: .error, code: "unexpected-zone-classification", message: "Wrong zone.")
            ]),
            operationPlan: ShadowSyncOperationPlan(operations: [], blockedIssues: [
                ShadowSyncReadinessIssue(severity: .error, code: "readiness-blocked", message: "Blocked.")
            ]),
            stopConditionReport: ShadowSyncStopConditionReport(conditions: [.repeatedErrorLoop]),
            attemptSnapshot: nil,
            comparisonReport: nil,
            existingSyncActive: false,
            lastErrorCode: "rate-limited"
        )

        let report = ShadowSyncGateReviewReport(diagnosticsReport: diagnostics)

        XCTAssertFalse(report.isReadyForHumanWriteReview)
        XCTAssertEqual(report.blockers, [
            "existing-sync-not-active",
            "operation-plan-not-executable",
            "readiness-blocked",
            "stop-condition-present",
            "zone-isolation-unconfirmed"
        ])
        XCTAssertFalse(report.redactedText().contains("rate-limited"))
    }

    func testExposurePolicyBlocksAppStoreAndTestFlightEvenWhenGateReviewIsReady() {
        let gateReview = ShadowSyncGateReviewReport(diagnosticsReport: passingDiagnosticsReport())

        let appStoreReport = ShadowSyncExposureChecker().evaluate(ShadowSyncExposurePolicy(
            channel: .appStore,
            internalReviewerApproved: true,
            remoteKillSwitchEnabled: false,
            localKillSwitchEnabled: false,
            gateReviewReport: gateReview
        ))
        let testFlightReport = ShadowSyncExposureChecker().evaluate(ShadowSyncExposurePolicy(
            channel: .testFlight,
            internalReviewerApproved: true,
            remoteKillSwitchEnabled: false,
            localKillSwitchEnabled: false,
            gateReviewReport: gateReview
        ))

        XCTAssertFalse(appStoreReport.policy.canExposeShadowWriteControls)
        XCTAssertFalse(testFlightReport.policy.canExposeShadowWriteControls)
        XCTAssertTrue(appStoreReport.blockers.contains("release-channel-blocked"))
        XCTAssertTrue(testFlightReport.blockers.contains("release-channel-blocked"))
    }

    func testExposurePolicyAllowsInternalDiagnosticsOnlyWhenFullyReviewedAndKillSwitchesOff() {
        let gateReview = ShadowSyncGateReviewReport(diagnosticsReport: passingDiagnosticsReport())
        let report = ShadowSyncExposureChecker().evaluate(ShadowSyncExposurePolicy(
            channel: .internalDiagnostics,
            internalReviewerApproved: true,
            remoteKillSwitchEnabled: false,
            localKillSwitchEnabled: false,
            gateReviewReport: gateReview
        ))

        XCTAssertTrue(report.policy.canExposeShadowWriteControls)
        XCTAssertTrue(report.blockers.isEmpty)
    }

    func testExposurePolicyBlocksInternalDiagnosticsWhenReviewOrKillSwitchBlocks() {
        let gateReview = ShadowSyncGateReviewReport(diagnosticsReport: passingDiagnosticsReport())
        let report = ShadowSyncExposureChecker().evaluate(ShadowSyncExposurePolicy(
            channel: .internalDiagnostics,
            internalReviewerApproved: false,
            remoteKillSwitchEnabled: true,
            localKillSwitchEnabled: true,
            gateReviewReport: gateReview
        ))

        XCTAssertFalse(report.policy.canExposeShadowWriteControls)
        XCTAssertEqual(report.blockers, [
            "internal-review-not-approved",
            "local-kill-switch-enabled",
            "remote-kill-switch-enabled"
        ])
    }

    func testZonePreflightConfirmsExistingProposedZone() {
        let report = ShadowSyncZonePreflightChecker().evaluate(
            readinessReport: readyReadinessReport(),
            inspectorReport: inspectorReport(zones: [
                CloudKitZoneInventoryItem(zoneName: ShadowSyncConfiguration.proposedZoneName, classification: .proposedCKSyncEngineZone),
                CloudKitZoneInventoryItem(zoneName: ShadowSyncConfiguration.existingCoreDataZoneName, classification: .existingCoreDataZone)
            ])
        )

        XCTAssertEqual(report.status, .proposedZoneAvailable)
        XCTAssertTrue(report.confirmsZoneIsolation)
        XCTAssertTrue(report.issues.isEmpty)
    }

    func testZonePreflightTreatsMissingProposedZoneAsInfoOnly() {
        let report = ShadowSyncZonePreflightChecker().evaluate(
            readinessReport: readyReadinessReport(),
            inspectorReport: inspectorReport(zones: [
                CloudKitZoneInventoryItem(zoneName: ShadowSyncConfiguration.existingCoreDataZoneName, classification: .existingCoreDataZone)
            ])
        )

        XCTAssertEqual(report.status, .proposedZoneMissing)
        XCTAssertTrue(report.confirmsZoneIsolation)
        XCTAssertTrue(report.issues.contains { $0.code == "proposed-zone-missing" })
    }

    func testZonePreflightRejectsCoreDataZoneTarget() {
        let configuration = ShadowSyncConfiguration(
            zoneName: ShadowSyncConfiguration.existingCoreDataZoneName,
            isFeatureEnabled: true,
            localKillSwitchEnabled: false,
            remoteKillSwitchEnabled: false
        )
        let readiness = ShadowSyncReadinessChecker().evaluate(configuration)

        let report = ShadowSyncZonePreflightChecker().evaluate(readinessReport: readiness, inspectorReport: inspectorReport())

        XCTAssertEqual(report.status, .coreDataZoneTargeted)
        XCTAssertFalse(report.confirmsZoneIsolation)
        XCTAssertTrue(report.issues.contains { $0.code == "core-data-zone-targeted" })
    }

    func testZonePreflightRejectsUnexpectedClassification() {
        let report = ShadowSyncZonePreflightChecker().evaluate(
            readinessReport: readyReadinessReport(),
            inspectorReport: inspectorReport(zones: [
                CloudKitZoneInventoryItem(zoneName: ShadowSyncConfiguration.proposedZoneName, classification: .foreignZone)
            ])
        )

        XCTAssertEqual(report.status, .unexpectedZoneClassification)
        XCTAssertFalse(report.confirmsZoneIsolation)
        XCTAssertTrue(report.issues.contains { $0.code == "unexpected-zone-classification" })
    }

    private func readyReadinessReport() -> ShadowSyncReadinessReport {
        let configuration = ShadowSyncConfiguration(
            isFeatureEnabled: true,
            localKillSwitchEnabled: false,
            remoteKillSwitchEnabled: false
        )
        return ShadowSyncReadinessChecker().evaluate(configuration)
    }

    private func inspectorReport(zones: [CloudKitZoneInventoryItem] = []) -> SyncInspectorReport {
        SyncInspectorReport(accountStatus: .available, zones: zones, warnings: [], localDryRunReport: nil)
    }

    private func passingDiagnosticsReport() -> ShadowSyncDiagnosticsReport {
        let readiness = readyReadinessReport()
        let exportReport = ExportDryRunReport(operations: [
            ExportDryRunOperation(kind: .wouldSaveRecord, recordType: "Project", recordName: "Project:one")
        ])
        return ShadowSyncDiagnosticsReport(
            readinessReport: readiness,
            zonePreflightReport: ShadowSyncZonePreflightReport(status: .proposedZoneAvailable, issues: []),
            operationPlan: ShadowSyncOperationPlanner().plan(readinessReport: readiness, exportDryRunReport: exportReport),
            stopConditionReport: ShadowSyncStopConditionReport(conditions: []),
            attemptSnapshot: ShadowSyncAttemptSnapshot(lastExportAttempt: .wouldStart, lastImportReadAttempt: .succeeded, pendingOperationCount: 1),
            comparisonReport: nil,
            existingSyncActive: true,
            lastErrorCode: nil
        )
    }
}
