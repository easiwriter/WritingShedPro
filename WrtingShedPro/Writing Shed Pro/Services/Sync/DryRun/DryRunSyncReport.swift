import Foundation

struct DryRunSyncReport: Equatable {
    var envelopes: [SyncRecordEnvelope]
    var tombstones: [SyncTombstoneEnvelope]

    init(envelopes: [SyncRecordEnvelope], tombstones: [SyncTombstoneEnvelope] = []) {
        self.envelopes = envelopes.sorted {
            if $0.recordType != $1.recordType {
                return $0.recordType < $1.recordType
            }
            return $0.recordName < $1.recordName
        }
        self.tombstones = tombstones.sorted {
            if $0.entityType != $1.entityType {
                return $0.entityType < $1.entityType
            }
            return $0.recordName < $1.recordName
        }
    }

    var recordCounts: [String: Int] {
        envelopes.reduce(into: [:]) { counts, envelope in
            counts[envelope.recordType, default: 0] += 1
        }
    }

    var assetPlaceholders: [SyncAssetPlaceholder] {
        envelopes
            .flatMap(\.assetPlaceholders)
            .sorted {
                if $0.entityType != $1.entityType { return $0.entityType < $1.entityType }
                if $0.entityID != $1.entityID { return $0.entityID.uuidString < $1.entityID.uuidString }
                return $0.fieldName < $1.fieldName
            }
    }

    var diagnostics: [SyncMappingDiagnostic] {
        envelopes
            .flatMap(\.diagnostics)
            .sorted {
                if $0.severity.sortOrder != $1.severity.sortOrder { return $0.severity.sortOrder < $1.severity.sortOrder }
                if $0.entityType != $1.entityType { return $0.entityType < $1.entityType }
                return ($0.entityID?.uuidString ?? "") < ($1.entityID?.uuidString ?? "")
            }
    }

    var tombstoneCounts: [String: Int] {
        tombstones.reduce(into: [:]) { counts, tombstone in
            counts[tombstone.entityType, default: 0] += 1
        }
    }

    func redactedText() -> String {
        var lines = ["CKSyncEngine dry-run export report", "", "Records:"]
        for key in recordCounts.keys.sorted() {
            lines.append("- \(key): \(recordCounts[key] ?? 0)")
        }

        lines.append("")
        lines.append("Assets placeheld:")
        if assetPlaceholders.isEmpty {
            lines.append("- none")
        } else {
            let grouped = Dictionary(grouping: assetPlaceholders) { "\($0.entityType).\($0.fieldName)" }
            for key in grouped.keys.sorted() {
                lines.append("- \(key): \(grouped[key]?.count ?? 0)")
            }
        }

        lines.append("")
        lines.append("Tombstones:")
        if tombstones.isEmpty {
            lines.append("- none")
        } else {
            for key in tombstoneCounts.keys.sorted() {
                lines.append("- \(key): \(tombstoneCounts[key] ?? 0)")
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
