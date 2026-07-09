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

    func testBatchPolicyAllowsSmallExecutableFirstAttempt() {
        let report = ShadowSyncBatchPolicyChecker().evaluate(ShadowSyncBatchPolicy(
            operationPlan: operationPlan(recordCount: 3),
            maximumFirstAttemptOperationCount: 10
        ))

        XCTAssertTrue(report.policy.canAttemptFirstBatch)
        XCTAssertTrue(report.blockers.isEmpty)
        XCTAssertTrue(report.redactedText().contains("Planned operation count: 3"))
    }

    func testBatchPolicyBlocksOversizedFirstAttempt() {
        let report = ShadowSyncBatchPolicyChecker().evaluate(ShadowSyncBatchPolicy(
            operationPlan: operationPlan(recordCount: 11),
            maximumFirstAttemptOperationCount: 10
        ))

        XCTAssertFalse(report.policy.canAttemptFirstBatch)
        XCTAssertEqual(report.blockers, ["first-attempt-batch-too-large"])
    }

    func testBatchPolicyBlocksEmptyOrNonExecutablePlan() {
        let report = ShadowSyncBatchPolicyChecker().evaluate(ShadowSyncBatchPolicy(
            operationPlan: ShadowSyncOperationPlan(operations: [], blockedIssues: [
                ShadowSyncReadinessIssue(severity: .error, code: "readiness-blocked", message: "Blocked.")
            ])
        ))

        XCTAssertFalse(report.policy.canAttemptFirstBatch)
        XCTAssertEqual(report.blockers, [
            "no-operations-planned",
            "operation-plan-not-executable"
        ])
    }

    func testBatchPolicyBlocksInvalidBatchLimit() {
        let report = ShadowSyncBatchPolicyChecker().evaluate(ShadowSyncBatchPolicy(
            operationPlan: operationPlan(recordCount: 1),
            maximumFirstAttemptOperationCount: 0
        ))

        XCTAssertFalse(report.policy.canAttemptFirstBatch)
        XCTAssertEqual(report.blockers, [
            "first-attempt-batch-too-large",
            "invalid-batch-limit"
        ])
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

    func testEnvironmentPolicyAllowsDevelopmentOnlyByDefault() {
        let report = ShadowSyncEnvironmentPolicyChecker().evaluate(ShadowSyncEnvironmentPolicy(
            cloudKitEnvironment: .development
        ))

        XCTAssertTrue(report.policy.canReviewShadowWriteEnvironment)
        XCTAssertTrue(report.blockers.isEmpty)
        XCTAssertTrue(report.redactedText().contains("CloudKit environment: development"))
    }

    func testEnvironmentPolicyBlocksProductionAndUnknownByDefault() {
        let production = ShadowSyncEnvironmentPolicyChecker().evaluate(ShadowSyncEnvironmentPolicy(
            cloudKitEnvironment: .production
        ))
        let unknown = ShadowSyncEnvironmentPolicyChecker().evaluate(ShadowSyncEnvironmentPolicy(
            cloudKitEnvironment: .unknown
        ))

        XCTAssertFalse(production.policy.canReviewShadowWriteEnvironment)
        XCTAssertFalse(unknown.policy.canReviewShadowWriteEnvironment)
        XCTAssertEqual(production.blockers, ["production-cloudkit-environment-blocked"])
        XCTAssertEqual(unknown.blockers, ["unknown-cloudkit-environment-blocked"])
    }

    func testAccountPolicyAllowsAvailableAccountOnlyByDefault() {
        let report = ShadowSyncAccountPolicyChecker().evaluate(ShadowSyncAccountPolicy(
            accountStatus: .available
        ))

        XCTAssertTrue(report.policy.canReviewShadowWriteAccount)
        XCTAssertTrue(report.blockers.isEmpty)
        XCTAssertTrue(report.redactedText().contains("CloudKit account status: available"))
    }

    func testAccountPolicyBlocksUnavailableAccountStatesByDefault() {
        let cases: [(CloudKitInspectorAccountStatus, String)] = [
            (.noAccount, "cloudkit-account-missing"),
            (.restricted, "cloudkit-account-restricted"),
            (.couldNotDetermine, "cloudkit-account-undetermined"),
            (.temporarilyUnavailable, "cloudkit-account-temporarily-unavailable"),
            (.unknown, "cloudkit-account-unknown")
        ]

        for (status, blocker) in cases {
            let report = ShadowSyncAccountPolicyChecker().evaluate(ShadowSyncAccountPolicy(
                accountStatus: status
            ))

            XCTAssertFalse(report.policy.canReviewShadowWriteAccount)
            XCTAssertEqual(report.blockers, [blocker])
        }
    }

    func testTriggerPolicyAllowsOnlyManualDiagnosticsWhenExposureAllows() {
        let exposure = allowedInternalExposureReport()
        let report = ShadowSyncTriggerPolicyChecker().evaluate(ShadowSyncTriggerPolicy(
            trigger: .manualDiagnostics,
            exposureReport: exposure
        ))

        XCTAssertTrue(report.policy.canStartShadowWriteAttempt)
        XCTAssertTrue(report.blockers.isEmpty)
        XCTAssertTrue(report.redactedText().contains("Trigger: manualDiagnostics"))
    }

    func testTriggerPolicyBlocksAutomaticTriggersEvenWhenExposureAllows() {
        let exposure = allowedInternalExposureReport()
        for trigger in [ShadowSyncTrigger.appLaunch, .foregroundResume, .editorSave, .backgroundTask] {
            let report = ShadowSyncTriggerPolicyChecker().evaluate(ShadowSyncTriggerPolicy(
                trigger: trigger,
                exposureReport: exposure
            ))

            XCTAssertFalse(report.policy.canStartShadowWriteAttempt)
            XCTAssertTrue(report.blockers.contains("automatic-trigger-blocked"))
        }
    }

    func testTriggerPolicyBlocksManualDiagnosticsWhenExposureBlocks() {
        let gateReview = ShadowSyncGateReviewReport(diagnosticsReport: passingDiagnosticsReport())
        let exposure = ShadowSyncExposureChecker().evaluate(ShadowSyncExposurePolicy(
            channel: .appStore,
            internalReviewerApproved: true,
            remoteKillSwitchEnabled: false,
            localKillSwitchEnabled: false,
            gateReviewReport: gateReview
        ))

        let report = ShadowSyncTriggerPolicyChecker().evaluate(ShadowSyncTriggerPolicy(
            trigger: .manualDiagnostics,
            exposureReport: exposure
        ))

        XCTAssertFalse(report.policy.canStartShadowWriteAttempt)
        XCTAssertTrue(report.blockers.contains("exposure-blocked"))
        XCTAssertTrue(report.blockers.contains("release-channel-blocked"))
    }

    func testRetryPolicyDefaultsToNoRetry() {
        let report = ShadowSyncRetryPolicyChecker().evaluate(ShadowSyncRetryPolicy(
            triggerReport: allowedManualTriggerReport()
        ))

        XCTAssertFalse(report.policy.allowsRetry)
        XCTAssertTrue(report.blockers.isEmpty)
        XCTAssertTrue(report.redactedText().contains("Maximum retry count: 0"))
    }

    func testRetryPolicyAllowsOneDelayedRetryAfterAllowedManualTrigger() {
        let report = ShadowSyncRetryPolicyChecker().evaluate(ShadowSyncRetryPolicy(
            maximumRetryCount: 1,
            minimumRetryDelaySeconds: 300,
            triggerReport: allowedManualTriggerReport()
        ))

        XCTAssertTrue(report.policy.allowsRetry)
        XCTAssertTrue(report.blockers.isEmpty)
    }

    func testRetryPolicyBlocksUnboundedOrImmediateRetry() {
        let report = ShadowSyncRetryPolicyChecker().evaluate(ShadowSyncRetryPolicy(
            maximumRetryCount: 2,
            minimumRetryDelaySeconds: 60,
            triggerReport: allowedManualTriggerReport()
        ))

        XCTAssertFalse(report.policy.allowsRetry)
        XCTAssertEqual(report.blockers, [
            "retry-count-too-high",
            "retry-delay-too-short"
        ])
    }

    func testRetryPolicyBlocksRetryWhenTriggerIsBlocked() {
        let triggerReport = ShadowSyncTriggerPolicyChecker().evaluate(ShadowSyncTriggerPolicy(
            trigger: .appLaunch,
            exposureReport: allowedInternalExposureReport()
        ))
        let report = ShadowSyncRetryPolicyChecker().evaluate(ShadowSyncRetryPolicy(
            maximumRetryCount: 1,
            minimumRetryDelaySeconds: 300,
            triggerReport: triggerReport
        ))

        XCTAssertFalse(report.policy.allowsRetry)
        XCTAssertTrue(report.blockers.contains("trigger-blocked"))
        XCTAssertTrue(report.blockers.contains("automatic-trigger-blocked"))
    }

    func testWriteAttemptReviewAllowsOnlyWhenAllPureGatesPass() {
        let report = passingWriteAttemptReviewReport()

        XCTAssertTrue(report.canReviewFirstWriteAttempt)
        XCTAssertTrue(report.blockers.isEmpty)
        XCTAssertTrue(report.redactedText().contains("Can review first write attempt: true"))
    }

    func testWriteAttemptReviewAggregatesPrefixedBlockers() {
        let gateReview = ShadowSyncGateReviewReport(diagnosticsReport: passingDiagnosticsReport())
        let exposure = ShadowSyncExposureChecker().evaluate(ShadowSyncExposurePolicy(
            channel: .appStore,
            internalReviewerApproved: true,
            remoteKillSwitchEnabled: false,
            localKillSwitchEnabled: false,
            gateReviewReport: gateReview
        ))
        let trigger = ShadowSyncTriggerPolicyChecker().evaluate(ShadowSyncTriggerPolicy(
            trigger: .appLaunch,
            exposureReport: exposure
        ))
        let retry = ShadowSyncRetryPolicyChecker().evaluate(ShadowSyncRetryPolicy(
            maximumRetryCount: 2,
            minimumRetryDelaySeconds: 60,
            triggerReport: trigger
        ))
        let batch = ShadowSyncBatchPolicyChecker().evaluate(ShadowSyncBatchPolicy(
            operationPlan: operationPlan(recordCount: 11),
            maximumFirstAttemptOperationCount: 10
        ))
        let sideEffects = ShadowSyncSideEffectPolicyChecker().evaluate(ShadowSyncSideEffectPolicy(
            willMutateSwiftData: true
        ))

        let report = ShadowSyncWriteAttemptReviewChecker().evaluate(
            gateReviewReport: gateReview,
            exposureReport: exposure,
            environmentReport: allowedDevelopmentEnvironmentReport(),
            accountReport: allowedAccountReport(),
            triggerReport: trigger,
            retryReport: retry,
            batchReport: batch,
            sideEffectReport: sideEffects
        )

        XCTAssertFalse(report.canReviewFirstWriteAttempt)
        XCTAssertTrue(report.blockers.contains("exposure:release-channel-blocked"))
        XCTAssertTrue(report.blockers.contains("trigger:automatic-trigger-blocked"))
        XCTAssertTrue(report.blockers.contains("retry:retry-count-too-high"))
        XCTAssertTrue(report.blockers.contains("retry:retry-delay-too-short"))
        XCTAssertTrue(report.blockers.contains("batch:first-attempt-batch-too-large"))
        XCTAssertTrue(report.blockers.contains("side-effect:swiftdata-mutation-blocked"))
    }

    func testWriteAttemptReviewBlocksProductionEnvironmentEvenWhenOtherGatesPass() {
        let gateReview = ShadowSyncGateReviewReport(diagnosticsReport: passingDiagnosticsReport())
        let exposure = allowedInternalExposureReport()
        let trigger = allowedManualTriggerReport()
        let retry = ShadowSyncRetryPolicyChecker().evaluate(ShadowSyncRetryPolicy(triggerReport: trigger))
        let batch = ShadowSyncBatchPolicyChecker().evaluate(ShadowSyncBatchPolicy(
            operationPlan: operationPlan(recordCount: 3),
            maximumFirstAttemptOperationCount: 10
        ))
        let environment = ShadowSyncEnvironmentPolicyChecker().evaluate(ShadowSyncEnvironmentPolicy(
            cloudKitEnvironment: .production
        ))

        let report = ShadowSyncWriteAttemptReviewChecker().evaluate(
            gateReviewReport: gateReview,
            exposureReport: exposure,
            environmentReport: environment,
            accountReport: allowedAccountReport(),
            triggerReport: trigger,
            retryReport: retry,
            batchReport: batch,
            sideEffectReport: ShadowSyncSideEffectPolicyChecker().evaluate(ShadowSyncSideEffectPolicy())
        )

        XCTAssertFalse(report.canReviewFirstWriteAttempt)
        XCTAssertTrue(report.blockers.contains("environment:production-cloudkit-environment-blocked"))
        XCTAssertTrue(report.redactedText().contains("Environment allowed: false"))
    }

    func testWriteAttemptReviewBlocksUnavailableAccountEvenWhenOtherGatesPass() {
        let gateReview = ShadowSyncGateReviewReport(diagnosticsReport: passingDiagnosticsReport())
        let exposure = allowedInternalExposureReport()
        let trigger = allowedManualTriggerReport()
        let retry = ShadowSyncRetryPolicyChecker().evaluate(ShadowSyncRetryPolicy(triggerReport: trigger))
        let batch = ShadowSyncBatchPolicyChecker().evaluate(ShadowSyncBatchPolicy(
            operationPlan: operationPlan(recordCount: 3),
            maximumFirstAttemptOperationCount: 10
        ))
        let account = ShadowSyncAccountPolicyChecker().evaluate(ShadowSyncAccountPolicy(
            accountStatus: .noAccount
        ))

        let report = ShadowSyncWriteAttemptReviewChecker().evaluate(
            gateReviewReport: gateReview,
            exposureReport: exposure,
            environmentReport: allowedDevelopmentEnvironmentReport(),
            accountReport: account,
            triggerReport: trigger,
            retryReport: retry,
            batchReport: batch,
            sideEffectReport: ShadowSyncSideEffectPolicyChecker().evaluate(ShadowSyncSideEffectPolicy())
        )

        XCTAssertFalse(report.canReviewFirstWriteAttempt)
        XCTAssertTrue(report.blockers.contains("account:cloudkit-account-missing"))
        XCTAssertTrue(report.redactedText().contains("Account allowed: false"))
    }

    func testWriteAttemptReviewBlocksSideEffectsEvenWhenOtherGatesPass() {
        let gateReview = ShadowSyncGateReviewReport(diagnosticsReport: passingDiagnosticsReport())
        let exposure = allowedInternalExposureReport()
        let trigger = allowedManualTriggerReport()
        let retry = ShadowSyncRetryPolicyChecker().evaluate(ShadowSyncRetryPolicy(triggerReport: trigger))
        let batch = ShadowSyncBatchPolicyChecker().evaluate(ShadowSyncBatchPolicy(
            operationPlan: operationPlan(recordCount: 3),
            maximumFirstAttemptOperationCount: 10
        ))
        let sideEffects = ShadowSyncSideEffectPolicyChecker().evaluate(ShadowSyncSideEffectPolicy(
            willTouchExistingCoreDataZone: true
        ))

        let report = ShadowSyncWriteAttemptReviewChecker().evaluate(
            gateReviewReport: gateReview,
            exposureReport: exposure,
            environmentReport: allowedDevelopmentEnvironmentReport(),
            accountReport: allowedAccountReport(),
            triggerReport: trigger,
            retryReport: retry,
            batchReport: batch,
            sideEffectReport: sideEffects
        )

        XCTAssertFalse(report.canReviewFirstWriteAttempt)
        XCTAssertTrue(report.blockers.contains("side-effect:core-data-zone-touch-blocked"))
        XCTAssertTrue(report.redactedText().contains("Side effects allowed: false"))
    }

    func testWriteAttemptPreviewRedactsRecordNamesAndShowsCounts() {
        let preview = ShadowSyncWriteAttemptPreviewBuilder().build(reviewReport: passingWriteAttemptReviewReport())

        XCTAssertEqual(preview.plannedRecordCounts, ["Project": 3])
        let text = preview.redactedText()
        XCTAssertTrue(text.contains("Can review first write attempt: true"))
        XCTAssertTrue(text.contains("Shadow zone: WritingShedProSyncZone"))
        XCTAssertTrue(text.contains("Trigger: manualDiagnostics"))
        XCTAssertTrue(text.contains("Project: 3"))
        XCTAssertFalse(text.contains("Project:0"))
        XCTAssertFalse(text.contains("formatted manuscript body"))
    }

    func testWriteAttemptPreviewIncludesAggregateBlockers() {
        let gateReview = ShadowSyncGateReviewReport(diagnosticsReport: passingDiagnosticsReport())
        let exposure = ShadowSyncExposureChecker().evaluate(ShadowSyncExposurePolicy(
            channel: .appStore,
            internalReviewerApproved: true,
            remoteKillSwitchEnabled: false,
            localKillSwitchEnabled: false,
            gateReviewReport: gateReview
        ))
        let trigger = ShadowSyncTriggerPolicyChecker().evaluate(ShadowSyncTriggerPolicy(
            trigger: .manualDiagnostics,
            exposureReport: exposure
        ))
        let retry = ShadowSyncRetryPolicyChecker().evaluate(ShadowSyncRetryPolicy(triggerReport: trigger))
        let batch = ShadowSyncBatchPolicyChecker().evaluate(ShadowSyncBatchPolicy(
            operationPlan: operationPlan(recordCount: 1),
            maximumFirstAttemptOperationCount: 10
        ))
        let sideEffects = ShadowSyncSideEffectPolicyChecker().evaluate(ShadowSyncSideEffectPolicy())
        let review = ShadowSyncWriteAttemptReviewChecker().evaluate(
            gateReviewReport: gateReview,
            exposureReport: exposure,
            environmentReport: allowedDevelopmentEnvironmentReport(),
            accountReport: allowedAccountReport(),
            triggerReport: trigger,
            retryReport: retry,
            batchReport: batch,
            sideEffectReport: sideEffects
        )

        let text = ShadowSyncWriteAttemptPreviewBuilder().build(reviewReport: review).redactedText()

        XCTAssertTrue(text.contains("Can review first write attempt: false"))
        XCTAssertTrue(text.contains("exposure:release-channel-blocked"))
        XCTAssertTrue(text.contains("trigger:exposure-blocked"))
    }

    func testPreflightEvidenceAllowsCapturedBlockerFreeEvidence() {
        let preview = ShadowSyncWriteAttemptPreviewBuilder().build(reviewReport: passingWriteAttemptReviewReport())
        let report = ShadowSyncPreflightEvidencePolicyChecker().evaluate(ShadowSyncPreflightEvidencePolicy(
            readOnlyInspectorCaptured: true,
            exportDryRunCaptured: true,
            gateReviewCaptured: true,
            writeAttemptPreviewCaptured: true,
            writeAttemptPreviewReport: preview
        ))

        XCTAssertTrue(report.hasRequiredEvidence)
        XCTAssertTrue(report.blockers.isEmpty)
        XCTAssertTrue(report.redactedText().contains("Has required evidence: true"))
    }

    func testPreflightEvidenceBlocksMissingEvidence() {
        let report = ShadowSyncPreflightEvidencePolicyChecker().evaluate(ShadowSyncPreflightEvidencePolicy())

        XCTAssertFalse(report.hasRequiredEvidence)
        XCTAssertEqual(report.blockers, [
            "export-dry-run-missing",
            "gate-review-missing",
            "read-only-inspector-missing",
            "write-attempt-preview-blocked",
            "write-attempt-preview-missing"
        ])
    }

    func testPreflightEvidenceBlocksBlockedPreview() {
        let gateReview = ShadowSyncGateReviewReport(diagnosticsReport: passingDiagnosticsReport())
        let exposure = ShadowSyncExposureChecker().evaluate(ShadowSyncExposurePolicy(
            channel: .appStore,
            internalReviewerApproved: true,
            remoteKillSwitchEnabled: false,
            localKillSwitchEnabled: false,
            gateReviewReport: gateReview
        ))
        let trigger = ShadowSyncTriggerPolicyChecker().evaluate(ShadowSyncTriggerPolicy(
            trigger: .manualDiagnostics,
            exposureReport: exposure
        ))
        let retry = ShadowSyncRetryPolicyChecker().evaluate(ShadowSyncRetryPolicy(triggerReport: trigger))
        let batch = ShadowSyncBatchPolicyChecker().evaluate(ShadowSyncBatchPolicy(
            operationPlan: operationPlan(recordCount: 1),
            maximumFirstAttemptOperationCount: 10
        ))
        let review = ShadowSyncWriteAttemptReviewChecker().evaluate(
            gateReviewReport: gateReview,
            exposureReport: exposure,
            environmentReport: allowedDevelopmentEnvironmentReport(),
            accountReport: allowedAccountReport(),
            triggerReport: trigger,
            retryReport: retry,
            batchReport: batch,
            sideEffectReport: ShadowSyncSideEffectPolicyChecker().evaluate(ShadowSyncSideEffectPolicy())
        )
        let preview = ShadowSyncWriteAttemptPreviewBuilder().build(reviewReport: review)

        let report = ShadowSyncPreflightEvidencePolicyChecker().evaluate(ShadowSyncPreflightEvidencePolicy(
            readOnlyInspectorCaptured: true,
            exportDryRunCaptured: true,
            gateReviewCaptured: true,
            writeAttemptPreviewCaptured: true,
            writeAttemptPreviewReport: preview
        ))

        XCTAssertFalse(report.hasRequiredEvidence)
        XCTAssertEqual(report.blockers, ["write-attempt-preview-blocked"])
    }

    func testFirstWritePreflightPassesWhenReviewAndEvidencePass() {
        let review = passingWriteAttemptReviewReport()
        let evidence = passingPreflightEvidenceReport(review: review)
        let approval = passingManualApprovalReport()

        let report = ShadowSyncFirstWritePreflightChecker().evaluate(
            writeAttemptReviewReport: review,
            preflightEvidenceReport: evidence,
            manualApprovalReport: approval
        )

        XCTAssertTrue(report.isReadyForManualFirstWriteReview)
        XCTAssertTrue(report.blockers.isEmpty)
        XCTAssertTrue(report.redactedText().contains("Ready for manual first write review: true"))
    }

    func testFirstWritePreflightAggregatesReviewAndEvidenceBlockers() {
        let gateReview = ShadowSyncGateReviewReport(diagnosticsReport: passingDiagnosticsReport())
        let exposure = ShadowSyncExposureChecker().evaluate(ShadowSyncExposurePolicy(
            channel: .appStore,
            internalReviewerApproved: true,
            remoteKillSwitchEnabled: false,
            localKillSwitchEnabled: false,
            gateReviewReport: gateReview
        ))
        let trigger = ShadowSyncTriggerPolicyChecker().evaluate(ShadowSyncTriggerPolicy(
            trigger: .manualDiagnostics,
            exposureReport: exposure
        ))
        let retry = ShadowSyncRetryPolicyChecker().evaluate(ShadowSyncRetryPolicy(triggerReport: trigger))
        let batch = ShadowSyncBatchPolicyChecker().evaluate(ShadowSyncBatchPolicy(
            operationPlan: operationPlan(recordCount: 1),
            maximumFirstAttemptOperationCount: 10
        ))
        let review = ShadowSyncWriteAttemptReviewChecker().evaluate(
            gateReviewReport: gateReview,
            exposureReport: exposure,
            environmentReport: allowedDevelopmentEnvironmentReport(),
            accountReport: allowedAccountReport(),
            triggerReport: trigger,
            retryReport: retry,
            batchReport: batch,
            sideEffectReport: ShadowSyncSideEffectPolicyChecker().evaluate(ShadowSyncSideEffectPolicy())
        )
        let evidence = ShadowSyncPreflightEvidencePolicyChecker().evaluate(ShadowSyncPreflightEvidencePolicy())
        let approval = ShadowSyncManualApprovalPolicyChecker().evaluate(ShadowSyncManualApprovalPolicy())

        let report = ShadowSyncFirstWritePreflightChecker().evaluate(
            writeAttemptReviewReport: review,
            preflightEvidenceReport: evidence,
            manualApprovalReport: approval
        )

        XCTAssertFalse(report.isReadyForManualFirstWriteReview)
        XCTAssertTrue(report.blockers.contains("review:exposure:release-channel-blocked"))
        XCTAssertTrue(report.blockers.contains("evidence:read-only-inspector-missing"))
        XCTAssertTrue(report.blockers.contains("evidence:write-attempt-preview-missing"))
        XCTAssertTrue(report.blockers.contains("approval:checklist-not-accepted"))
    }

    func testManualApprovalPolicyRequiresAcceptedChecklistAndReceiptFields() {
        let report = ShadowSyncManualApprovalPolicyChecker().evaluate(ShadowSyncManualApprovalPolicy())

        XCTAssertFalse(report.policy.hasManualApproval)
        XCTAssertEqual(report.blockers, [
            "approval-timestamp-missing",
            "checklist-not-accepted",
            "checklist-version-missing",
            "reviewer-missing"
        ])
    }

    func testManualApprovalPolicyPassesWithRecordedReceipt() {
        let report = passingManualApprovalReport()

        XCTAssertTrue(report.policy.hasManualApproval)
        XCTAssertTrue(report.blockers.isEmpty)
        XCTAssertTrue(report.redactedText().contains("Reviewer recorded: present"))
        XCTAssertFalse(report.redactedText().contains("Keith"))
    }

    func testSideEffectPolicyAllowsNoSideEffects() {
        let report = ShadowSyncSideEffectPolicyChecker().evaluate(ShadowSyncSideEffectPolicy())

        XCTAssertTrue(report.allowsSideEffects)
        XCTAssertTrue(report.blockers.isEmpty)
        XCTAssertTrue(report.redactedText().contains("Allows side effects: true"))
    }

    func testSideEffectPolicyBlocksProductionAndLocalMutationRisks() {
        let report = ShadowSyncSideEffectPolicyChecker().evaluate(ShadowSyncSideEffectPolicy(
            willMutateSwiftData: true,
            willImportShadowRecordsIntoSwiftData: true,
            willCreateCloudKitZone: true,
            willDeleteCloudKitZone: true,
            willTouchExistingCoreDataZone: true,
            willCreateAssets: true,
            willUseShadowDataInUserFacingWorkflows: true
        ))

        XCTAssertFalse(report.allowsSideEffects)
        XCTAssertEqual(report.blockers, [
            "asset-creation-blocked",
            "core-data-zone-touch-blocked",
            "shadow-import-into-swiftdata-blocked",
            "swiftdata-mutation-blocked",
            "user-facing-shadow-data-blocked",
            "zone-creation-blocked",
            "zone-delete-blocked"
        ])
    }

    func testWriteAttemptReviewBlocksZoneCreationSideEffect() {
        let gateReview = ShadowSyncGateReviewReport(diagnosticsReport: passingDiagnosticsReport())
        let exposure = allowedInternalExposureReport()
        let trigger = allowedManualTriggerReport()
        let retry = ShadowSyncRetryPolicyChecker().evaluate(ShadowSyncRetryPolicy(triggerReport: trigger))
        let batch = ShadowSyncBatchPolicyChecker().evaluate(ShadowSyncBatchPolicy(
            operationPlan: operationPlan(recordCount: 3),
            maximumFirstAttemptOperationCount: 10
        ))
        let sideEffects = ShadowSyncSideEffectPolicyChecker().evaluate(ShadowSyncSideEffectPolicy(
            willCreateCloudKitZone: true
        ))

        let report = ShadowSyncWriteAttemptReviewChecker().evaluate(
            gateReviewReport: gateReview,
            exposureReport: exposure,
            environmentReport: allowedDevelopmentEnvironmentReport(),
            accountReport: allowedAccountReport(),
            triggerReport: trigger,
            retryReport: retry,
            batchReport: batch,
            sideEffectReport: sideEffects
        )

        XCTAssertFalse(report.canReviewFirstWriteAttempt)
        XCTAssertTrue(report.blockers.contains("side-effect:zone-creation-blocked"))
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

    private func allowedInternalExposureReport() -> ShadowSyncExposureReport {
        ShadowSyncExposureChecker().evaluate(ShadowSyncExposurePolicy(
            channel: .internalDiagnostics,
            internalReviewerApproved: true,
            remoteKillSwitchEnabled: false,
            localKillSwitchEnabled: false,
            gateReviewReport: ShadowSyncGateReviewReport(diagnosticsReport: passingDiagnosticsReport())
        ))
    }

    private func allowedManualTriggerReport() -> ShadowSyncTriggerReport {
        ShadowSyncTriggerPolicyChecker().evaluate(ShadowSyncTriggerPolicy(
            trigger: .manualDiagnostics,
            exposureReport: allowedInternalExposureReport()
        ))
    }

    private func allowedDevelopmentEnvironmentReport() -> ShadowSyncEnvironmentReport {
        ShadowSyncEnvironmentPolicyChecker().evaluate(ShadowSyncEnvironmentPolicy(
            cloudKitEnvironment: .development
        ))
    }

    private func allowedAccountReport() -> ShadowSyncAccountReport {
        ShadowSyncAccountPolicyChecker().evaluate(ShadowSyncAccountPolicy(
            accountStatus: .available
        ))
    }

    private func passingWriteAttemptReviewReport() -> ShadowSyncWriteAttemptReviewReport {
        let gateReview = ShadowSyncGateReviewReport(diagnosticsReport: passingDiagnosticsReport())
        let exposure = allowedInternalExposureReport()
        let trigger = allowedManualTriggerReport()
        let retry = ShadowSyncRetryPolicyChecker().evaluate(ShadowSyncRetryPolicy(
            triggerReport: trigger
        ))
        let batch = ShadowSyncBatchPolicyChecker().evaluate(ShadowSyncBatchPolicy(
            operationPlan: operationPlan(recordCount: 3),
            maximumFirstAttemptOperationCount: 10
        ))

        return ShadowSyncWriteAttemptReviewChecker().evaluate(
            gateReviewReport: gateReview,
            exposureReport: exposure,
            environmentReport: allowedDevelopmentEnvironmentReport(),
            accountReport: allowedAccountReport(),
            triggerReport: trigger,
            retryReport: retry,
            batchReport: batch,
            sideEffectReport: ShadowSyncSideEffectPolicyChecker().evaluate(ShadowSyncSideEffectPolicy())
        )
    }

    private func passingPreflightEvidenceReport(review: ShadowSyncWriteAttemptReviewReport) -> ShadowSyncPreflightEvidenceReport {
        let preview = ShadowSyncWriteAttemptPreviewBuilder().build(reviewReport: review)
        return ShadowSyncPreflightEvidencePolicyChecker().evaluate(ShadowSyncPreflightEvidencePolicy(
            readOnlyInspectorCaptured: true,
            exportDryRunCaptured: true,
            gateReviewCaptured: true,
            writeAttemptPreviewCaptured: true,
            writeAttemptPreviewReport: preview
        ))
    }

    private func passingManualApprovalReport() -> ShadowSyncManualApprovalReport {
        ShadowSyncManualApprovalPolicyChecker().evaluate(ShadowSyncManualApprovalPolicy(
            checklistAccepted: true,
            reviewerIdentifier: "Keith",
            checklistVersion: "phase-4-shadow-write-review-checklist.md@2026-07-09",
            approvalRecordedAt: "2026-07-09T11:45:00Z"
        ))
    }

    private func operationPlan(recordCount: Int) -> ShadowSyncOperationPlan {
        let operations = (0..<recordCount).map { index in
            ShadowSyncPlannedOperation(kind: .saveRecord, recordType: "Project", recordName: "Project:\(index)")
        }
        return ShadowSyncOperationPlan(operations: operations, blockedIssues: [])
    }
}
