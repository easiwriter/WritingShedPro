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
