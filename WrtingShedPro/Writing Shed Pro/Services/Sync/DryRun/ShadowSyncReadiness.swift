import Foundation

enum ShadowSyncReadinessSeverity: String, Equatable {
    case info
    case warning
    case error

    var sortOrder: Int {
        switch self {
        case .error: return 0
        case .warning: return 1
        case .info: return 2
        }
    }
}

struct ShadowSyncReadinessIssue: Equatable {
    var severity: ShadowSyncReadinessSeverity
    var code: String
    var message: String
}

struct ShadowSyncConfiguration: Equatable {
    static let existingCoreDataZoneName = "com.apple.coredata.cloudkit.zone"
    static let proposedZoneName = "WritingShedProSyncZone"
    static let firstShadowRecordTypes: Set<String> = ["Project", "Folder", "TextFile", "Version"]

    var zoneName: String = Self.proposedZoneName
    var isFeatureEnabled: Bool = false
    var localKillSwitchEnabled: Bool = true
    var remoteKillSwitchEnabled: Bool = true
    var allowedRecordTypes: Set<String> = Self.firstShadowRecordTypes
    var allowsAssets: Bool = false
    var allowsTombstones: Bool = false
}

struct ShadowSyncReadinessReport: Equatable {
    var configuration: ShadowSyncConfiguration
    var issues: [ShadowSyncReadinessIssue]

    var canAttemptShadowWrite: Bool {
        configuration.isFeatureEnabled
            && !configuration.localKillSwitchEnabled
            && !configuration.remoteKillSwitchEnabled
            && !issues.contains { $0.severity == .error }
    }

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine shadow sync readiness",
            "Zone: \(configuration.zoneName)",
            "Can attempt shadow write: \(canAttemptShadowWrite)",
            "",
            "Allowed record types:"
        ]
        for recordType in configuration.allowedRecordTypes.sorted() {
            lines.append("- \(recordType)")
        }

        lines.append("")
        lines.append("Issues:")
        if issues.isEmpty {
            lines.append("- none")
        } else {
            for issue in issues.sorted(by: Self.sortIssues) {
                lines.append("- \(issue.severity.rawValue): \(issue.code)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func sortIssues(_ lhs: ShadowSyncReadinessIssue, _ rhs: ShadowSyncReadinessIssue) -> Bool {
        if lhs.severity.sortOrder != rhs.severity.sortOrder { return lhs.severity.sortOrder < rhs.severity.sortOrder }
        return lhs.code < rhs.code
    }
}

struct ShadowSyncReadinessChecker {
    func evaluate(_ configuration: ShadowSyncConfiguration) -> ShadowSyncReadinessReport {
        var issues: [ShadowSyncReadinessIssue] = []

        if !configuration.isFeatureEnabled {
            issues.append(issue(.info, "feature-disabled", "Shadow sync is disabled by default."))
        }
        if configuration.localKillSwitchEnabled {
            issues.append(issue(.warning, "local-kill-switch-enabled", "Local kill switch blocks shadow writes."))
        }
        if configuration.remoteKillSwitchEnabled {
            issues.append(issue(.warning, "remote-kill-switch-enabled", "Remote kill switch blocks shadow writes."))
        }
        if configuration.zoneName == ShadowSyncConfiguration.existingCoreDataZoneName {
            issues.append(issue(.error, "core-data-zone-targeted", "Shadow sync must never target the existing Core Data zone."))
        }
        if configuration.zoneName != ShadowSyncConfiguration.proposedZoneName {
            issues.append(issue(.error, "unexpected-shadow-zone", "Shadow sync zone must be the reviewed WritingShedProSyncZone."))
        }
        if configuration.allowedRecordTypes.isEmpty {
            issues.append(issue(.error, "empty-shadow-scope", "Shadow sync needs an explicit small record scope."))
        }

        let unsupportedTypes = configuration.allowedRecordTypes.subtracting(ShadowSyncConfiguration.firstShadowRecordTypes)
        if !unsupportedTypes.isEmpty {
            issues.append(issue(.error, "unsupported-shadow-record-types", "First shadow scope may only include Project, Folder, TextFile, and Version."))
        }
        if configuration.allowsAssets {
            issues.append(issue(.error, "assets-not-reviewed-for-shadow", "First shadow scope excludes assets."))
        }
        if configuration.allowsTombstones {
            issues.append(issue(.error, "tombstones-not-reviewed-for-shadow", "First shadow scope excludes tombstones until explicitly reviewed."))
        }

        return ShadowSyncReadinessReport(configuration: configuration, issues: issues)
    }

    private func issue(_ severity: ShadowSyncReadinessSeverity, _ code: String, _ message: String) -> ShadowSyncReadinessIssue {
        ShadowSyncReadinessIssue(severity: severity, code: code, message: message)
    }
}

struct ShadowSyncComparisonReport: Equatable {
    var localRecordCounts: [String: Int]
    var shadowRecordCounts: [String: Int]
    var excludedAssetCounts: [String: Int]

    var mismatchedRecordTypes: [String] {
        let keys = Set(localRecordCounts.keys).union(shadowRecordCounts.keys)
        return keys.filter { localRecordCounts[$0, default: 0] != shadowRecordCounts[$0, default: 0] }.sorted()
    }

    func redactedText() -> String {
        var lines = ["Shadow sync comparison", "", "Local data:"]
        for key in localRecordCounts.keys.sorted() {
            lines.append("- \(key): \(localRecordCounts[key] ?? 0)")
        }

        lines.append("")
        lines.append("Shadow zone:")
        for key in shadowRecordCounts.keys.sorted() {
            lines.append("- \(key): \(shadowRecordCounts[key] ?? 0)")
        }

        lines.append("")
        lines.append("Mismatches:")
        if mismatchedRecordTypes.isEmpty {
            lines.append("- none")
        } else {
            for key in mismatchedRecordTypes {
                lines.append("- \(key)")
            }
        }

        lines.append("")
        lines.append("Excluded assets:")
        if excludedAssetCounts.isEmpty {
            lines.append("- none")
        } else {
            for key in excludedAssetCounts.keys.sorted() {
                lines.append("- \(key): \(excludedAssetCounts[key] ?? 0)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

enum ShadowSyncPlannedOperationKind: String, Equatable {
    case saveRecord
}

struct ShadowSyncPlannedOperation: Equatable {
    var kind: ShadowSyncPlannedOperationKind
    var recordType: String
    var recordName: String
}

struct ShadowSyncOperationPlan: Equatable {
    var operations: [ShadowSyncPlannedOperation]
    var blockedIssues: [ShadowSyncReadinessIssue]

    var canExecute: Bool {
        !operations.isEmpty && !blockedIssues.contains { $0.severity == .error }
    }

    func redactedText() -> String {
        var lines = ["CKSyncEngine shadow sync operation plan", "", "Operations:"]
        if operations.isEmpty {
            lines.append("- none")
        } else {
            for operation in operations.sorted(by: Self.sortOperations) {
                lines.append("- \(operation.kind.rawValue): \(operation.recordType) \(operation.recordName)")
            }
        }

        lines.append("")
        lines.append("Blocked issues:")
        if blockedIssues.isEmpty {
            lines.append("- none")
        } else {
            for issue in blockedIssues.sorted(by: Self.sortIssues) {
                lines.append("- \(issue.severity.rawValue): \(issue.code)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func sortOperations(_ lhs: ShadowSyncPlannedOperation, _ rhs: ShadowSyncPlannedOperation) -> Bool {
        if lhs.recordType != rhs.recordType { return lhs.recordType < rhs.recordType }
        return lhs.recordName < rhs.recordName
    }

    private static func sortIssues(_ lhs: ShadowSyncReadinessIssue, _ rhs: ShadowSyncReadinessIssue) -> Bool {
        if lhs.severity.sortOrder != rhs.severity.sortOrder { return lhs.severity.sortOrder < rhs.severity.sortOrder }
        return lhs.code < rhs.code
    }
}

struct ShadowSyncOperationPlanner {
    func plan(readinessReport: ShadowSyncReadinessReport, exportDryRunReport: ExportDryRunReport) -> ShadowSyncOperationPlan {
        var blockedIssues = readinessReport.issues

        guard readinessReport.canAttemptShadowWrite else {
            blockedIssues.append(issue(.error, "readiness-blocked", "Shadow sync readiness does not allow a write attempt."))
            return ShadowSyncOperationPlan(operations: [], blockedIssues: blockedIssues)
        }

        var operations: [ShadowSyncPlannedOperation] = []
        for operation in exportDryRunReport.operations {
            switch operation.kind {
            case .wouldSaveRecord:
                if readinessReport.configuration.allowedRecordTypes.contains(operation.recordType) {
                    operations.append(ShadowSyncPlannedOperation(kind: .saveRecord, recordType: operation.recordType, recordName: operation.recordName))
                } else {
                    blockedIssues.append(issue(.error, "operation-record-type-not-allowed", "Export dry-run includes a record outside the reviewed shadow scope."))
                }
            case .wouldSaveAsset:
                blockedIssues.append(issue(.error, "operation-asset-not-allowed", "Export dry-run includes an asset operation, which is excluded from the first shadow scope."))
            case .wouldSaveTombstone:
                blockedIssues.append(issue(.error, "operation-tombstone-not-allowed", "Export dry-run includes a tombstone operation, which is excluded from the first shadow scope."))
            case .wouldSkipLocalOnly, .wouldDefer, .warning:
                break
            }
        }

        if blockedIssues.contains(where: { $0.severity == .error }) {
            return ShadowSyncOperationPlan(operations: [], blockedIssues: blockedIssues)
        }

        return ShadowSyncOperationPlan(operations: operations, blockedIssues: blockedIssues)
    }

    private func issue(_ severity: ShadowSyncReadinessSeverity, _ code: String, _ message: String) -> ShadowSyncReadinessIssue {
        ShadowSyncReadinessIssue(severity: severity, code: code, message: message)
    }
}

struct ShadowSyncBatchPolicy: Equatable {
    var operationPlan: ShadowSyncOperationPlan
    var maximumFirstAttemptOperationCount: Int = 10

    var canAttemptFirstBatch: Bool {
        operationPlan.canExecute
            && !operationPlan.operations.isEmpty
            && maximumFirstAttemptOperationCount > 0
            && operationPlan.operations.count <= maximumFirstAttemptOperationCount
    }
}

struct ShadowSyncBatchReport: Equatable {
    var policy: ShadowSyncBatchPolicy

    var blockers: [String] {
        var values: [String] = []
        if !policy.operationPlan.canExecute {
            values.append("operation-plan-not-executable")
        }
        if policy.operationPlan.operations.isEmpty {
            values.append("no-operations-planned")
        }
        if policy.maximumFirstAttemptOperationCount <= 0 {
            values.append("invalid-batch-limit")
        }
        if policy.operationPlan.operations.count > policy.maximumFirstAttemptOperationCount {
            values.append("first-attempt-batch-too-large")
        }
        return values.sorted()
    }

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine shadow batch policy",
            "Planned operation count: \(policy.operationPlan.operations.count)",
            "Maximum first attempt operation count: \(policy.maximumFirstAttemptOperationCount)",
            "Can attempt first batch: \(policy.canAttemptFirstBatch)",
            "",
            "Blockers:"
        ]

        if blockers.isEmpty {
            lines.append("- none")
        } else {
            for blocker in blockers {
                lines.append("- \(blocker)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct ShadowSyncBatchPolicyChecker {
    func evaluate(_ policy: ShadowSyncBatchPolicy) -> ShadowSyncBatchReport {
        ShadowSyncBatchReport(policy: policy)
    }
}

struct ShadowSyncDiagnosticsReport: Equatable {
    var readinessReport: ShadowSyncReadinessReport
    var zonePreflightReport: ShadowSyncZonePreflightReport?
    var operationPlan: ShadowSyncOperationPlan
    var stopConditionReport: ShadowSyncStopConditionReport?
    var attemptSnapshot: ShadowSyncAttemptSnapshot?
    var comparisonReport: ShadowSyncComparisonReport?
    var existingSyncActive: Bool
    var lastErrorCode: String?

    var enabledState: String {
        readinessReport.configuration.isFeatureEnabled ? "enabled" : "disabled"
    }

    var killSwitchState: String {
        switch (readinessReport.configuration.localKillSwitchEnabled, readinessReport.configuration.remoteKillSwitchEnabled) {
        case (true, true): return "local-and-remote"
        case (true, false): return "local"
        case (false, true): return "remote"
        case (false, false): return "off"
        }
    }

    var plannedOperationCounts: [ShadowSyncPlannedOperationKind: Int] {
        operationPlan.operations.reduce(into: [:]) { counts, operation in
            counts[operation.kind, default: 0] += 1
        }
    }

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine shadow sync diagnostics",
            "Enabled: \(enabledState)",
            "Shadow zone: \(readinessReport.configuration.zoneName)",
            "Zone preflight: \(zonePreflightReport?.status.rawValue ?? "not-run")",
            "Zone isolation confirmed: \(zonePreflightReport?.confirmsZoneIsolation ?? false)",
            "Kill switch: \(killSwitchState)",
            "Existing sync active: \(existingSyncActive)",
            "Can attempt shadow write: \(readinessReport.canAttemptShadowWrite)",
            "Plan can execute: \(operationPlan.canExecute)",
            "Must disable shadow sync: \(stopConditionReport?.mustDisableShadowSync ?? false)",
            "Last export attempt: \(attemptSnapshot?.lastExportAttempt.rawValue ?? "none")",
            "Last import read attempt: \(attemptSnapshot?.lastImportReadAttempt.rawValue ?? "none")",
            "Pending operation count: \(attemptSnapshot?.pendingOperationCount ?? 0)",
            "Last error code: \(lastErrorCode ?? "none")",
            "",
            "Planned operations:"
        ]

        let saveRecordCount = plannedOperationCounts[.saveRecord] ?? 0
        lines.append("- saveRecord: \(saveRecordCount)")

        lines.append("")
        lines.append("Readiness blockers:")
        let blockers = operationPlan.blockedIssues.filter { $0.severity == .error }
        if blockers.isEmpty {
            lines.append("- none")
        } else {
            for issue in blockers.sorted(by: Self.sortIssues) {
                lines.append("- \(issue.code)")
            }
        }

        lines.append("")
        lines.append("Zone preflight issues:")
        if let zonePreflightReport, !zonePreflightReport.issues.isEmpty {
            for issue in zonePreflightReport.issues.sorted(by: Self.sortIssues) {
                lines.append("- \(issue.severity.rawValue): \(issue.code)")
            }
        } else {
            lines.append("- none")
        }

        lines.append("")
        lines.append("Stop conditions:")
        if let stopConditionReport, !stopConditionReport.conditions.isEmpty {
            for condition in stopConditionReport.conditions.sorted(by: { $0.rawValue < $1.rawValue }) {
                lines.append("- \(condition.rawValue)")
            }
        } else {
            lines.append("- none")
        }

        lines.append("")
        lines.append("Comparison mismatches:")
        if let comparisonReport, !comparisonReport.mismatchedRecordTypes.isEmpty {
            for recordType in comparisonReport.mismatchedRecordTypes {
                lines.append("- \(recordType)")
            }
        } else {
            lines.append("- none")
        }

        return lines.joined(separator: "\n")
    }

    private static func sortIssues(_ lhs: ShadowSyncReadinessIssue, _ rhs: ShadowSyncReadinessIssue) -> Bool {
        if lhs.severity.sortOrder != rhs.severity.sortOrder { return lhs.severity.sortOrder < rhs.severity.sortOrder }
        return lhs.code < rhs.code
    }
}

struct ShadowSyncGateReviewReport: Equatable {
    var diagnosticsReport: ShadowSyncDiagnosticsReport

    var isReadyForHumanWriteReview: Bool {
        diagnosticsReport.readinessReport.canAttemptShadowWrite
            && (diagnosticsReport.zonePreflightReport?.confirmsZoneIsolation ?? false)
            && diagnosticsReport.operationPlan.canExecute
            && !(diagnosticsReport.stopConditionReport?.mustDisableShadowSync ?? false)
            && diagnosticsReport.existingSyncActive
    }

    var blockers: [String] {
        var values: [String] = []
        if !diagnosticsReport.readinessReport.canAttemptShadowWrite {
            values.append("readiness-blocked")
        }
        if diagnosticsReport.zonePreflightReport?.confirmsZoneIsolation != true {
            values.append("zone-isolation-unconfirmed")
        }
        if !diagnosticsReport.operationPlan.canExecute {
            values.append("operation-plan-not-executable")
        }
        if diagnosticsReport.stopConditionReport?.mustDisableShadowSync == true {
            values.append("stop-condition-present")
        }
        if !diagnosticsReport.existingSyncActive {
            values.append("existing-sync-not-active")
        }
        return values.sorted()
    }

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine Gate 5 review summary",
            "Ready for human write review: \(isReadyForHumanWriteReview)",
            "",
            "Blockers:"
        ]

        if blockers.isEmpty {
            lines.append("- none")
        } else {
            for blocker in blockers {
                lines.append("- \(blocker)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

enum ShadowSyncExposureChannel: String, Equatable {
    case debug
    case internalDiagnostics
    case testFlight
    case appStore
}

struct ShadowSyncExposurePolicy: Equatable {
    var channel: ShadowSyncExposureChannel = .appStore
    var internalReviewerApproved: Bool = false
    var remoteKillSwitchEnabled: Bool = true
    var localKillSwitchEnabled: Bool = true
    var gateReviewReport: ShadowSyncGateReviewReport

    var canExposeShadowWriteControls: Bool {
        switch channel {
        case .debug, .internalDiagnostics:
            return internalReviewerApproved
                && !remoteKillSwitchEnabled
                && !localKillSwitchEnabled
                && gateReviewReport.isReadyForHumanWriteReview
        case .testFlight, .appStore:
            return false
        }
    }
}

struct ShadowSyncExposureReport: Equatable {
    var policy: ShadowSyncExposurePolicy

    var blockers: [String] {
        var values = policy.gateReviewReport.blockers
        if policy.channel == .testFlight || policy.channel == .appStore {
            values.append("release-channel-blocked")
        }
        if !policy.internalReviewerApproved {
            values.append("internal-review-not-approved")
        }
        if policy.remoteKillSwitchEnabled {
            values.append("remote-kill-switch-enabled")
        }
        if policy.localKillSwitchEnabled {
            values.append("local-kill-switch-enabled")
        }
        return Array(Set(values)).sorted()
    }

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine shadow exposure policy",
            "Channel: \(policy.channel.rawValue)",
            "Can expose shadow write controls: \(policy.canExposeShadowWriteControls)",
            "",
            "Blockers:"
        ]

        if blockers.isEmpty {
            lines.append("- none")
        } else {
            for blocker in blockers {
                lines.append("- \(blocker)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct ShadowSyncExposureChecker {
    func evaluate(_ policy: ShadowSyncExposurePolicy) -> ShadowSyncExposureReport {
        ShadowSyncExposureReport(policy: policy)
    }
}

enum ShadowSyncCloudKitEnvironment: String, Equatable {
    case development
    case production
    case unknown
}

struct ShadowSyncEnvironmentPolicy: Equatable {
    var cloudKitEnvironment: ShadowSyncCloudKitEnvironment = .unknown
    var requiresDevelopmentEnvironment: Bool = true

    var canReviewShadowWriteEnvironment: Bool {
        !requiresDevelopmentEnvironment || cloudKitEnvironment == .development
    }
}

struct ShadowSyncEnvironmentReport: Equatable {
    var policy: ShadowSyncEnvironmentPolicy

    var blockers: [String] {
        guard policy.requiresDevelopmentEnvironment else { return [] }

        switch policy.cloudKitEnvironment {
        case .development:
            return []
        case .production:
            return ["production-cloudkit-environment-blocked"]
        case .unknown:
            return ["unknown-cloudkit-environment-blocked"]
        }
    }

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine shadow environment policy",
            "CloudKit environment: \(policy.cloudKitEnvironment.rawValue)",
            "Can review shadow write environment: \(policy.canReviewShadowWriteEnvironment)",
            "",
            "Blockers:"
        ]

        if blockers.isEmpty {
            lines.append("- none")
        } else {
            for blocker in blockers {
                lines.append("- \(blocker)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct ShadowSyncEnvironmentPolicyChecker {
    func evaluate(_ policy: ShadowSyncEnvironmentPolicy) -> ShadowSyncEnvironmentReport {
        ShadowSyncEnvironmentReport(policy: policy)
    }
}

struct ShadowSyncAccountPolicy: Equatable {
    var accountStatus: CloudKitInspectorAccountStatus = .unknown
    var requiresAvailableAccount: Bool = true

    var canReviewShadowWriteAccount: Bool {
        !requiresAvailableAccount || accountStatus == .available
    }
}

struct ShadowSyncAccountReport: Equatable {
    var policy: ShadowSyncAccountPolicy

    var blockers: [String] {
        guard policy.requiresAvailableAccount, policy.accountStatus != .available else { return [] }

        switch policy.accountStatus {
        case .available:
            return []
        case .noAccount:
            return ["cloudkit-account-missing"]
        case .restricted:
            return ["cloudkit-account-restricted"]
        case .couldNotDetermine:
            return ["cloudkit-account-undetermined"]
        case .temporarilyUnavailable:
            return ["cloudkit-account-temporarily-unavailable"]
        case .unknown:
            return ["cloudkit-account-unknown"]
        }
    }

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine shadow account policy",
            "CloudKit account status: \(policy.accountStatus.rawValue)",
            "Can review shadow write account: \(policy.canReviewShadowWriteAccount)",
            "",
            "Blockers:"
        ]

        if blockers.isEmpty {
            lines.append("- none")
        } else {
            for blocker in blockers {
                lines.append("- \(blocker)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct ShadowSyncAccountPolicyChecker {
    func evaluate(_ policy: ShadowSyncAccountPolicy) -> ShadowSyncAccountReport {
        ShadowSyncAccountReport(policy: policy)
    }
}

enum ShadowSyncTrigger: String, Equatable {
    case manualDiagnostics
    case appLaunch
    case foregroundResume
    case editorSave
    case backgroundTask
}

struct ShadowSyncTriggerPolicy: Equatable {
    var trigger: ShadowSyncTrigger = .manualDiagnostics
    var exposureReport: ShadowSyncExposureReport

    var canStartShadowWriteAttempt: Bool {
        trigger == .manualDiagnostics && exposureReport.policy.canExposeShadowWriteControls
    }
}

struct ShadowSyncTriggerReport: Equatable {
    var policy: ShadowSyncTriggerPolicy

    var blockers: [String] {
        var values = policy.exposureReport.blockers
        if policy.trigger != .manualDiagnostics {
            values.append("automatic-trigger-blocked")
        }
        if !policy.exposureReport.policy.canExposeShadowWriteControls {
            values.append("exposure-blocked")
        }
        return Array(Set(values)).sorted()
    }

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine shadow trigger policy",
            "Trigger: \(policy.trigger.rawValue)",
            "Can start shadow write attempt: \(policy.canStartShadowWriteAttempt)",
            "",
            "Blockers:"
        ]

        if blockers.isEmpty {
            lines.append("- none")
        } else {
            for blocker in blockers {
                lines.append("- \(blocker)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct ShadowSyncTriggerPolicyChecker {
    func evaluate(_ policy: ShadowSyncTriggerPolicy) -> ShadowSyncTriggerReport {
        ShadowSyncTriggerReport(policy: policy)
    }
}

struct ShadowSyncRetryPolicy: Equatable {
    var maximumRetryCount: Int = 0
    var minimumRetryDelaySeconds: Int = 300
    var triggerReport: ShadowSyncTriggerReport

    var allowsRetry: Bool {
        triggerReport.policy.canStartShadowWriteAttempt
            && maximumRetryCount > 0
            && maximumRetryCount <= 1
            && minimumRetryDelaySeconds >= 300
    }
}

struct ShadowSyncRetryReport: Equatable {
    var policy: ShadowSyncRetryPolicy

    var blockers: [String] {
        var values = policy.triggerReport.blockers
        if !policy.triggerReport.policy.canStartShadowWriteAttempt {
            values.append("trigger-blocked")
        }
        if policy.maximumRetryCount < 0 {
            values.append("negative-retry-count")
        }
        if policy.maximumRetryCount > 1 {
            values.append("retry-count-too-high")
        }
        if policy.minimumRetryDelaySeconds < 300 {
            values.append("retry-delay-too-short")
        }
        return Array(Set(values)).sorted()
    }

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine shadow retry policy",
            "Maximum retry count: \(policy.maximumRetryCount)",
            "Minimum retry delay seconds: \(policy.minimumRetryDelaySeconds)",
            "Allows retry: \(policy.allowsRetry)",
            "",
            "Blockers:"
        ]

        if blockers.isEmpty {
            lines.append("- none")
        } else {
            for blocker in blockers {
                lines.append("- \(blocker)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct ShadowSyncRetryPolicyChecker {
    func evaluate(_ policy: ShadowSyncRetryPolicy) -> ShadowSyncRetryReport {
        ShadowSyncRetryReport(policy: policy)
    }
}

struct ShadowSyncWriteAttemptReviewReport: Equatable {
    var gateReviewReport: ShadowSyncGateReviewReport
    var exposureReport: ShadowSyncExposureReport
    var environmentReport: ShadowSyncEnvironmentReport
    var accountReport: ShadowSyncAccountReport
    var triggerReport: ShadowSyncTriggerReport
    var retryReport: ShadowSyncRetryReport
    var batchReport: ShadowSyncBatchReport
    var sideEffectReport: ShadowSyncSideEffectReport

    var canReviewFirstWriteAttempt: Bool {
        gateReviewReport.isReadyForHumanWriteReview
            && exposureReport.policy.canExposeShadowWriteControls
            && environmentReport.policy.canReviewShadowWriteEnvironment
            && accountReport.policy.canReviewShadowWriteAccount
            && triggerReport.policy.canStartShadowWriteAttempt
            && retryReport.blockers.isEmpty
            && batchReport.policy.canAttemptFirstBatch
            && sideEffectReport.allowsSideEffects
    }

    var blockers: [String] {
        var values: [String] = []
        values.append(contentsOf: gateReviewReport.blockers.map { "gate:\($0)" })
        values.append(contentsOf: exposureReport.blockers.map { "exposure:\($0)" })
        values.append(contentsOf: environmentReport.blockers.map { "environment:\($0)" })
        values.append(contentsOf: accountReport.blockers.map { "account:\($0)" })
        values.append(contentsOf: triggerReport.blockers.map { "trigger:\($0)" })
        values.append(contentsOf: retryReport.blockers.map { "retry:\($0)" })
        values.append(contentsOf: batchReport.blockers.map { "batch:\($0)" })
        values.append(contentsOf: sideEffectReport.blockers.map { "side-effect:\($0)" })
        return Array(Set(values)).sorted()
    }

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine first shadow write attempt review",
            "Can review first write attempt: \(canReviewFirstWriteAttempt)",
            "Gate ready: \(gateReviewReport.isReadyForHumanWriteReview)",
            "Exposure allowed: \(exposureReport.policy.canExposeShadowWriteControls)",
            "Environment allowed: \(environmentReport.policy.canReviewShadowWriteEnvironment)",
            "Account allowed: \(accountReport.policy.canReviewShadowWriteAccount)",
            "Trigger allowed: \(triggerReport.policy.canStartShadowWriteAttempt)",
            "Retry blockers clear: \(retryReport.blockers.isEmpty)",
            "Batch allowed: \(batchReport.policy.canAttemptFirstBatch)",
            "Side effects allowed: \(sideEffectReport.allowsSideEffects)",
            "",
            "Blockers:"
        ]

        if blockers.isEmpty {
            lines.append("- none")
        } else {
            for blocker in blockers {
                lines.append("- \(blocker)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct ShadowSyncWriteAttemptReviewChecker {
    func evaluate(
        gateReviewReport: ShadowSyncGateReviewReport,
        exposureReport: ShadowSyncExposureReport,
        environmentReport: ShadowSyncEnvironmentReport,
        accountReport: ShadowSyncAccountReport,
        triggerReport: ShadowSyncTriggerReport,
        retryReport: ShadowSyncRetryReport,
        batchReport: ShadowSyncBatchReport,
        sideEffectReport: ShadowSyncSideEffectReport
    ) -> ShadowSyncWriteAttemptReviewReport {
        ShadowSyncWriteAttemptReviewReport(
            gateReviewReport: gateReviewReport,
            exposureReport: exposureReport,
            environmentReport: environmentReport,
            accountReport: accountReport,
            triggerReport: triggerReport,
            retryReport: retryReport,
            batchReport: batchReport,
            sideEffectReport: sideEffectReport
        )
    }
}

struct ShadowSyncWriteAttemptPreviewReport: Equatable {
    var reviewReport: ShadowSyncWriteAttemptReviewReport

    var plannedRecordCounts: [String: Int] {
        reviewReport.batchReport.policy.operationPlan.operations.reduce(into: [:]) { counts, operation in
            counts[operation.recordType, default: 0] += 1
        }
    }

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine first shadow write attempt preview",
            "Can review first write attempt: \(reviewReport.canReviewFirstWriteAttempt)",
            "Shadow zone: \(reviewReport.gateReviewReport.diagnosticsReport.readinessReport.configuration.zoneName)",
            "Trigger: \(reviewReport.triggerReport.policy.trigger.rawValue)",
            "Maximum retry count: \(reviewReport.retryReport.policy.maximumRetryCount)",
            "Minimum retry delay seconds: \(reviewReport.retryReport.policy.minimumRetryDelaySeconds)",
            "Planned operation count: \(reviewReport.batchReport.policy.operationPlan.operations.count)",
            "Maximum first attempt operation count: \(reviewReport.batchReport.policy.maximumFirstAttemptOperationCount)",
            "",
            "Planned record counts:"
        ]

        if plannedRecordCounts.isEmpty {
            lines.append("- none")
        } else {
            for recordType in plannedRecordCounts.keys.sorted() {
                lines.append("- \(recordType): \(plannedRecordCounts[recordType] ?? 0)")
            }
        }

        lines.append("")
        lines.append("Blockers:")
        if reviewReport.blockers.isEmpty {
            lines.append("- none")
        } else {
            for blocker in reviewReport.blockers {
                lines.append("- \(blocker)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct ShadowSyncWriteAttemptPreviewBuilder {
    func build(reviewReport: ShadowSyncWriteAttemptReviewReport) -> ShadowSyncWriteAttemptPreviewReport {
        ShadowSyncWriteAttemptPreviewReport(reviewReport: reviewReport)
    }
}

struct ShadowSyncPreflightEvidencePolicy: Equatable {
    var readOnlyInspectorCaptured: Bool = false
    var exportDryRunCaptured: Bool = false
    var gateReviewCaptured: Bool = false
    var writeAttemptPreviewCaptured: Bool = false
    var writeAttemptPreviewReport: ShadowSyncWriteAttemptPreviewReport?
}

struct ShadowSyncPreflightEvidenceReport: Equatable {
    var policy: ShadowSyncPreflightEvidencePolicy

    var hasRequiredEvidence: Bool {
        blockers.isEmpty
    }

    var blockers: [String] {
        var values: [String] = []
        if !policy.readOnlyInspectorCaptured {
            values.append("read-only-inspector-missing")
        }
        if !policy.exportDryRunCaptured {
            values.append("export-dry-run-missing")
        }
        if !policy.gateReviewCaptured {
            values.append("gate-review-missing")
        }
        if !policy.writeAttemptPreviewCaptured || policy.writeAttemptPreviewReport == nil {
            values.append("write-attempt-preview-missing")
        }
        if policy.writeAttemptPreviewReport?.reviewReport.canReviewFirstWriteAttempt != true {
            values.append("write-attempt-preview-blocked")
        }
        return Array(Set(values)).sorted()
    }

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine shadow preflight evidence",
            "Has required evidence: \(hasRequiredEvidence)",
            "Read-only inspector captured: \(policy.readOnlyInspectorCaptured)",
            "Export dry-run captured: \(policy.exportDryRunCaptured)",
            "Gate review captured: \(policy.gateReviewCaptured)",
            "Write attempt preview captured: \(policy.writeAttemptPreviewCaptured && policy.writeAttemptPreviewReport != nil)",
            "",
            "Blockers:"
        ]

        if blockers.isEmpty {
            lines.append("- none")
        } else {
            for blocker in blockers {
                lines.append("- \(blocker)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct ShadowSyncPreflightEvidencePolicyChecker {
    func evaluate(_ policy: ShadowSyncPreflightEvidencePolicy) -> ShadowSyncPreflightEvidenceReport {
        ShadowSyncPreflightEvidenceReport(policy: policy)
    }
}

struct ShadowSyncManualApprovalPolicy: Equatable {
    var checklistAccepted: Bool = false
    var reviewerIdentifier: String = ""
    var checklistVersion: String = ""
    var approvalRecordedAt: String = ""

    var hasManualApproval: Bool {
        checklistAccepted
            && !reviewerIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !checklistVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !approvalRecordedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ShadowSyncManualApprovalReport: Equatable {
    var policy: ShadowSyncManualApprovalPolicy

    var blockers: [String] {
        var values: [String] = []
        if !policy.checklistAccepted {
            values.append("checklist-not-accepted")
        }
        if policy.reviewerIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            values.append("reviewer-missing")
        }
        if policy.checklistVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            values.append("checklist-version-missing")
        }
        if policy.approvalRecordedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            values.append("approval-timestamp-missing")
        }
        return values.sorted()
    }

    func redactedText() -> String {
        let checklistVersionText = policy.checklistVersion.isEmpty ? "none" : policy.checklistVersion
        let approvalRecordedText = policy.approvalRecordedAt.isEmpty ? "none" : "present"
        let reviewerRecordedText = policy.reviewerIdentifier.isEmpty ? "none" : "present"
        var lines = [
            "CKSyncEngine shadow manual approval",
            "Has manual approval: \(policy.hasManualApproval)",
            "Checklist version: \(checklistVersionText)",
            "Approval recorded: \(approvalRecordedText)",
            "Reviewer recorded: \(reviewerRecordedText)",
            "",
            "Blockers:"
        ]

        if blockers.isEmpty {
            lines.append("- none")
        } else {
            for blocker in blockers {
                lines.append("- \(blocker)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct ShadowSyncManualApprovalPolicyChecker {
    func evaluate(_ policy: ShadowSyncManualApprovalPolicy) -> ShadowSyncManualApprovalReport {
        ShadowSyncManualApprovalReport(policy: policy)
    }
}

struct ShadowSyncFirstWritePreflightReport: Equatable {
    var writeAttemptReviewReport: ShadowSyncWriteAttemptReviewReport
    var preflightEvidenceReport: ShadowSyncPreflightEvidenceReport
    var manualApprovalReport: ShadowSyncManualApprovalReport

    var isReadyForManualFirstWriteReview: Bool {
        writeAttemptReviewReport.canReviewFirstWriteAttempt
            && preflightEvidenceReport.hasRequiredEvidence
            && manualApprovalReport.policy.hasManualApproval
    }

    var blockers: [String] {
        var values: [String] = []
        values.append(contentsOf: writeAttemptReviewReport.blockers.map { "review:\($0)" })
        values.append(contentsOf: preflightEvidenceReport.blockers.map { "evidence:\($0)" })
        values.append(contentsOf: manualApprovalReport.blockers.map { "approval:\($0)" })
        return Array(Set(values)).sorted()
    }

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine first shadow write preflight",
            "Ready for manual first write review: \(isReadyForManualFirstWriteReview)",
            "Write attempt review passed: \(writeAttemptReviewReport.canReviewFirstWriteAttempt)",
            "Preflight evidence captured: \(preflightEvidenceReport.hasRequiredEvidence)",
            "Manual approval recorded: \(manualApprovalReport.policy.hasManualApproval)",
            "",
            "Blockers:"
        ]

        if blockers.isEmpty {
            lines.append("- none")
        } else {
            for blocker in blockers {
                lines.append("- \(blocker)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct ShadowSyncFirstWritePreflightChecker {
    func evaluate(
        writeAttemptReviewReport: ShadowSyncWriteAttemptReviewReport,
        preflightEvidenceReport: ShadowSyncPreflightEvidenceReport,
        manualApprovalReport: ShadowSyncManualApprovalReport
    ) -> ShadowSyncFirstWritePreflightReport {
        ShadowSyncFirstWritePreflightReport(
            writeAttemptReviewReport: writeAttemptReviewReport,
            preflightEvidenceReport: preflightEvidenceReport,
            manualApprovalReport: manualApprovalReport
        )
    }
}

struct ShadowSyncSideEffectPolicy: Equatable {
    var willMutateSwiftData: Bool = false
    var willImportShadowRecordsIntoSwiftData: Bool = false
    var willCreateCloudKitZone: Bool = false
    var willDeleteCloudKitZone: Bool = false
    var willTouchExistingCoreDataZone: Bool = false
    var willCreateAssets: Bool = false
    var willUseShadowDataInUserFacingWorkflows: Bool = false
}

struct ShadowSyncSideEffectReport: Equatable {
    var policy: ShadowSyncSideEffectPolicy

    var allowsSideEffects: Bool {
        blockers.isEmpty
    }

    var blockers: [String] {
        var values: [String] = []
        if policy.willMutateSwiftData {
            values.append("swiftdata-mutation-blocked")
        }
        if policy.willImportShadowRecordsIntoSwiftData {
            values.append("shadow-import-into-swiftdata-blocked")
        }
        if policy.willCreateCloudKitZone {
            values.append("zone-creation-blocked")
        }
        if policy.willDeleteCloudKitZone {
            values.append("zone-delete-blocked")
        }
        if policy.willTouchExistingCoreDataZone {
            values.append("core-data-zone-touch-blocked")
        }
        if policy.willCreateAssets {
            values.append("asset-creation-blocked")
        }
        if policy.willUseShadowDataInUserFacingWorkflows {
            values.append("user-facing-shadow-data-blocked")
        }
        return values.sorted()
    }

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine shadow side-effect policy",
            "Allows side effects: \(allowsSideEffects)",
            "",
            "Blockers:"
        ]

        if blockers.isEmpty {
            lines.append("- none")
        } else {
            for blocker in blockers {
                lines.append("- \(blocker)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct ShadowSyncSideEffectPolicyChecker {
    func evaluate(_ policy: ShadowSyncSideEffectPolicy) -> ShadowSyncSideEffectReport {
        ShadowSyncSideEffectReport(policy: policy)
    }
}

enum ShadowSyncAttemptState: String, Equatable {
    case notAttempted
    case skipped
    case wouldStart
    case succeeded
    case failed
}

struct ShadowSyncAttemptSnapshot: Equatable {
    var lastExportAttempt: ShadowSyncAttemptState = .notAttempted
    var lastImportReadAttempt: ShadowSyncAttemptState = .notAttempted
    var pendingOperationCount: Int = 0

    func redactedText() -> String {
        [
            "CKSyncEngine shadow attempt snapshot",
            "Last export attempt: \(lastExportAttempt.rawValue)",
            "Last import read attempt: \(lastImportReadAttempt.rawValue)",
            "Pending operation count: \(pendingOperationCount)"
        ].joined(separator: "\n")
    }
}

enum ShadowSyncStopCondition: String, Equatable {
    case existingCoreDataZoneTargeted
    case localSwiftDataDeleteRequested
    case unreviewedCloudKitDeleteRequested
    case repeatedErrorLoop
    case launchLatencyImpact
    case editorSaveLatencyImpact
}

struct ShadowSyncStopConditionInput: Equatable {
    var targetZoneName: String = ShadowSyncConfiguration.proposedZoneName
    var localSwiftDataDeleteRequested: Bool = false
    var cloudKitDeleteRequested: Bool = false
    var cloudKitDeleteHasReviewedTombstone: Bool = false
    var consecutiveErrorCount: Int = 0
    var repeatedErrorLimit: Int = 3
    var launchLatencyImpactDetected: Bool = false
    var editorSaveLatencyImpactDetected: Bool = false
}

struct ShadowSyncStopConditionReport: Equatable {
    var conditions: [ShadowSyncStopCondition]

    var mustDisableShadowSync: Bool {
        !conditions.isEmpty
    }

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine shadow sync stop conditions",
            "Must disable shadow sync: \(mustDisableShadowSync)",
            "",
            "Conditions:"
        ]

        if conditions.isEmpty {
            lines.append("- none")
        } else {
            for condition in conditions.sorted(by: { $0.rawValue < $1.rawValue }) {
                lines.append("- \(condition.rawValue)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct ShadowSyncStopConditionChecker {
    func evaluate(_ input: ShadowSyncStopConditionInput) -> ShadowSyncStopConditionReport {
        var conditions: [ShadowSyncStopCondition] = []

        if input.targetZoneName == ShadowSyncConfiguration.existingCoreDataZoneName {
            conditions.append(.existingCoreDataZoneTargeted)
        }
        if input.localSwiftDataDeleteRequested {
            conditions.append(.localSwiftDataDeleteRequested)
        }
        if input.cloudKitDeleteRequested && !input.cloudKitDeleteHasReviewedTombstone {
            conditions.append(.unreviewedCloudKitDeleteRequested)
        }
        if input.consecutiveErrorCount >= input.repeatedErrorLimit {
            conditions.append(.repeatedErrorLoop)
        }
        if input.launchLatencyImpactDetected {
            conditions.append(.launchLatencyImpact)
        }
        if input.editorSaveLatencyImpactDetected {
            conditions.append(.editorSaveLatencyImpact)
        }

        return ShadowSyncStopConditionReport(conditions: conditions)
    }
}

enum ShadowSyncZonePreflightStatus: String, Equatable {
    case proposedZoneAvailable
    case proposedZoneMissing
    case coreDataZoneTargeted
    case unexpectedZoneClassification
}

struct ShadowSyncZonePreflightReport: Equatable {
    var status: ShadowSyncZonePreflightStatus
    var issues: [ShadowSyncReadinessIssue]

    var confirmsZoneIsolation: Bool {
        !issues.contains { $0.severity == .error }
    }

    func redactedText() -> String {
        var lines = [
            "CKSyncEngine shadow zone preflight",
            "Status: \(status.rawValue)",
            "Confirms isolation: \(confirmsZoneIsolation)",
            "",
            "Issues:"
        ]

        if issues.isEmpty {
            lines.append("- none")
        } else {
            for issue in issues.sorted(by: Self.sortIssues) {
                lines.append("- \(issue.severity.rawValue): \(issue.code)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func sortIssues(_ lhs: ShadowSyncReadinessIssue, _ rhs: ShadowSyncReadinessIssue) -> Bool {
        if lhs.severity.sortOrder != rhs.severity.sortOrder { return lhs.severity.sortOrder < rhs.severity.sortOrder }
        return lhs.code < rhs.code
    }
}

struct ShadowSyncZonePreflightChecker {
    func evaluate(readinessReport: ShadowSyncReadinessReport, inspectorReport: SyncInspectorReport) -> ShadowSyncZonePreflightReport {
        let configuration = readinessReport.configuration
        if configuration.zoneName == ShadowSyncConfiguration.existingCoreDataZoneName {
            return ShadowSyncZonePreflightReport(status: .coreDataZoneTargeted, issues: [
                issue(.error, "core-data-zone-targeted", "Shadow sync must never target the existing Core Data zone.")
            ])
        }

        guard let proposedZone = inspectorReport.zones.first(where: { $0.zoneName == configuration.zoneName }) else {
            return ShadowSyncZonePreflightReport(status: .proposedZoneMissing, issues: [
                issue(.info, "proposed-zone-missing", "Proposed shadow zone is missing; future creation must still be separately reviewed.")
            ])
        }

        guard proposedZone.classification == .proposedCKSyncEngineZone else {
            return ShadowSyncZonePreflightReport(status: .unexpectedZoneClassification, issues: [
                issue(.error, "unexpected-zone-classification", "Configured shadow zone was not classified as the proposed CKSyncEngine zone.")
            ])
        }

        return ShadowSyncZonePreflightReport(status: .proposedZoneAvailable, issues: [])
    }

    private func issue(_ severity: ShadowSyncReadinessSeverity, _ code: String, _ message: String) -> ShadowSyncReadinessIssue {
        ShadowSyncReadinessIssue(severity: severity, code: code, message: message)
    }
}
