import Foundation

enum ExportDryRunOperationKind: String, Equatable {
    case wouldSaveRecord
    case wouldSaveAsset
    case wouldSaveTombstone
    case wouldSkipLocalOnly
    case wouldDefer
    case warning
}

enum ExportAssetSizeBand: String, Equatable {
    case small
    case medium
    case large
    case oversized

    static func band(for byteCount: Int) -> ExportAssetSizeBand {
        if byteCount > 50 * 1024 * 1024 { return .oversized }
        if byteCount >= 5 * 1024 * 1024 { return .large }
        if byteCount >= 256 * 1024 { return .medium }
        return .small
    }
}

struct ExportDryRunOperation: Equatable {
    var kind: ExportDryRunOperationKind
    var recordType: String
    var recordName: String
    var fieldName: String?

    init(kind: ExportDryRunOperationKind, recordType: String, recordName: String, fieldName: String? = nil) {
        self.kind = kind
        self.recordType = recordType
        self.recordName = recordName
        self.fieldName = fieldName
    }
}

struct ExportDryRunReport: Equatable {
    var operations: [ExportDryRunOperation]
    var assetPlaceholders: [SyncAssetPlaceholder]
    var diagnostics: [SyncMappingDiagnostic]

    init(operations: [ExportDryRunOperation], assetPlaceholders: [SyncAssetPlaceholder] = [], diagnostics: [SyncMappingDiagnostic] = []) {
        self.operations = operations.sorted {
            if $0.kind.rawValue != $1.kind.rawValue { return $0.kind.rawValue < $1.kind.rawValue }
            if $0.recordType != $1.recordType { return $0.recordType < $1.recordType }
            if $0.recordName != $1.recordName { return $0.recordName < $1.recordName }
            return ($0.fieldName ?? "") < ($1.fieldName ?? "")
        }
        self.assetPlaceholders = assetPlaceholders.sorted {
            if $0.entityType != $1.entityType { return $0.entityType < $1.entityType }
            if $0.entityID != $1.entityID { return $0.entityID.uuidString < $1.entityID.uuidString }
            return $0.fieldName < $1.fieldName
        }
        self.diagnostics = diagnostics.sorted {
            if $0.severity.sortOrder != $1.severity.sortOrder { return $0.severity.sortOrder < $1.severity.sortOrder }
            if $0.entityType != $1.entityType { return $0.entityType < $1.entityType }
            return ($0.entityID?.uuidString ?? "") < ($1.entityID?.uuidString ?? "")
        }
    }

    var operationCounts: [ExportDryRunOperationKind: Int] {
        operations.reduce(into: [:]) { counts, operation in
            counts[operation.kind, default: 0] += 1
        }
    }

    func redactedText() -> String {
        var lines = ["CKSyncEngine export dry-run report", "", "Operations:"]
        for kind in ExportDryRunOperationKind.allReportCases {
            lines.append("- \(kind.rawValue): \(operationCounts[kind] ?? 0)")
        }

        lines.append("")
        lines.append("Assets:")
        if assetPlaceholders.isEmpty {
            lines.append("- none")
        } else {
            let grouped = Dictionary(grouping: assetPlaceholders) { "\($0.entityType).\($0.fieldName)" }
            for key in grouped.keys.sorted() {
                let totalBytes = grouped[key, default: []].reduce(0) { $0 + $1.byteCount }
                lines.append("- \(key): \(grouped[key]?.count ?? 0) placeholder(s), \(totalBytes) bytes")
            }
        }

        lines.append("")
        lines.append("Diagnostics:")
        if diagnostics.isEmpty {
            lines.append("- none")
        } else {
            for diagnostic in diagnostics {
                lines.append("- \(diagnostic.severity.rawValue): \(diagnostic.code) \(diagnostic.entityType):\(diagnostic.entityID?.uuidString ?? "unknown")")
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct ExportDryRunBuilder {
    func build(
        changedEnvelopes: [SyncRecordEnvelope],
        tombstones: [SyncTombstoneEnvelope] = [],
        deferredEnvelopes: [SyncRecordEnvelope] = []
    ) -> ExportDryRunReport {
        var operations: [ExportDryRunOperation] = []
        var assetPlaceholders: [SyncAssetPlaceholder] = []
        var diagnostics: [SyncMappingDiagnostic] = []

        for envelope in changedEnvelopes {
            operations.append(ExportDryRunOperation(kind: .wouldSaveRecord, recordType: envelope.recordType, recordName: envelope.recordName))
            diagnostics.append(contentsOf: envelope.diagnostics)
            assetPlaceholders.append(contentsOf: envelope.assetPlaceholders)

            for asset in envelope.assetPlaceholders {
                operations.append(ExportDryRunOperation(kind: .wouldSaveAsset, recordType: asset.entityType, recordName: "\(asset.entityType):\(asset.entityID.uuidString)", fieldName: asset.fieldName))
                if let diagnostic = assetSizeDiagnostic(for: asset) {
                    diagnostics.append(diagnostic)
                    operations.append(ExportDryRunOperation(kind: .warning, recordType: asset.entityType, recordName: "\(asset.entityType):\(asset.entityID.uuidString)", fieldName: asset.fieldName))
                }
            }

            for diagnostic in envelope.diagnostics where diagnostic.code == "local-only-field-skipped" {
                operations.append(ExportDryRunOperation(kind: .wouldSkipLocalOnly, recordType: diagnostic.entityType, recordName: recordName(entityType: diagnostic.entityType, entityID: diagnostic.entityID), fieldName: diagnostic.fieldName))
            }

            for diagnostic in envelope.diagnostics where diagnostic.severity == .warning || diagnostic.severity == .error {
                operations.append(ExportDryRunOperation(kind: .warning, recordType: diagnostic.entityType, recordName: recordName(entityType: diagnostic.entityType, entityID: diagnostic.entityID), fieldName: diagnostic.fieldName))
            }
        }

        for tombstone in tombstones {
            operations.append(ExportDryRunOperation(kind: .wouldSaveTombstone, recordType: tombstone.entityType, recordName: tombstone.recordName))
        }

        for envelope in deferredEnvelopes {
            operations.append(ExportDryRunOperation(kind: .wouldDefer, recordType: envelope.recordType, recordName: envelope.recordName))
            diagnostics.append(contentsOf: envelope.diagnostics)
        }

        return ExportDryRunReport(operations: operations, assetPlaceholders: assetPlaceholders, diagnostics: diagnostics)
    }

    private func recordName(entityType: String, entityID: UUID?) -> String {
        guard let entityID else { return "\(entityType):unknown" }
        return "\(entityType):\(entityID.uuidString)"
    }

    private func assetSizeDiagnostic(for asset: SyncAssetPlaceholder) -> SyncMappingDiagnostic? {
        switch ExportAssetSizeBand.band(for: asset.byteCount) {
        case .small, .medium:
            return nil
        case .large:
            return SyncMappingDiagnostic(severity: .warning, code: "large-asset-placeholder", entityType: asset.entityType, entityID: asset.entityID, fieldName: asset.fieldName, message: "Asset placeholder is in the large diagnostic band (\(asset.byteCount) bytes).")
        case .oversized:
            return SyncMappingDiagnostic(severity: .error, code: "oversized-asset-placeholder", entityType: asset.entityType, entityID: asset.entityID, fieldName: asset.fieldName, message: "Asset placeholder is in the oversized diagnostic band (\(asset.byteCount) bytes); review before any future upload path exists.")
        }
    }
}

struct SyncChangeTracker {
    private let baselineEnvelopesByRecordName: [String: SyncRecordEnvelope]

    init(baselineEnvelopes: [SyncRecordEnvelope]) {
        self.baselineEnvelopesByRecordName = Dictionary(uniqueKeysWithValues: baselineEnvelopes.map { ($0.recordName, $0) })
    }

    func changedEnvelopes(currentEnvelopes: [SyncRecordEnvelope]) -> [SyncRecordEnvelope] {
        currentEnvelopes.filter { current in
            guard let baseline = baselineEnvelopesByRecordName[current.recordName] else { return true }
            return baseline != current
        }
        .sorted {
            if $0.recordType != $1.recordType { return $0.recordType < $1.recordType }
            return $0.recordName < $1.recordName
        }
    }
}

private extension ExportDryRunOperationKind {
    static var allReportCases: [ExportDryRunOperationKind] {
        [.wouldSaveRecord, .wouldSaveAsset, .wouldSaveTombstone, .wouldSkipLocalOnly, .wouldDefer, .warning]
    }
}
