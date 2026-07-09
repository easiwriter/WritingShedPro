import Foundation

enum ImportDryRunOperationKind: String, Equatable {
    case wouldInsert
    case wouldUpdate
    case wouldSkipUnchanged
    case wouldApplyTombstone
    case pendingRelationship
    case conflict
    case unsupported
}

struct PendingRelationship: Equatable {
    var sourceRecordType: String
    var sourceRecordName: String
    var fieldName: String
    var targetRecordType: String
    var targetRecordName: String
}

struct ImportDryRunOperation: Equatable {
    var kind: ImportDryRunOperationKind
    var recordType: String
    var recordName: String
    var changedFields: [String]
    var pendingRelationships: [PendingRelationship]

    init(
        kind: ImportDryRunOperationKind,
        recordType: String,
        recordName: String,
        changedFields: [String] = [],
        pendingRelationships: [PendingRelationship] = []
    ) {
        self.kind = kind
        self.recordType = recordType
        self.recordName = recordName
        self.changedFields = changedFields.sorted()
        self.pendingRelationships = pendingRelationships.sorted {
            if $0.sourceRecordName != $1.sourceRecordName { return $0.sourceRecordName < $1.sourceRecordName }
            if $0.fieldName != $1.fieldName { return $0.fieldName < $1.fieldName }
            return $0.targetRecordName < $1.targetRecordName
        }
    }
}

struct ImportDryRunReport: Equatable {
    var operations: [ImportDryRunOperation]
    var diagnostics: [SyncMappingDiagnostic]

    init(operations: [ImportDryRunOperation], diagnostics: [SyncMappingDiagnostic] = []) {
        self.operations = operations.sorted {
            if $0.kind.rawValue != $1.kind.rawValue { return $0.kind.rawValue < $1.kind.rawValue }
            if $0.recordType != $1.recordType { return $0.recordType < $1.recordType }
            return $0.recordName < $1.recordName
        }
        self.diagnostics = diagnostics.sorted {
            if $0.severity.sortOrder != $1.severity.sortOrder { return $0.severity.sortOrder < $1.severity.sortOrder }
            if $0.entityType != $1.entityType { return $0.entityType < $1.entityType }
            return ($0.entityID?.uuidString ?? "") < ($1.entityID?.uuidString ?? "")
        }
    }

    var operationCounts: [ImportDryRunOperationKind: Int] {
        operations.reduce(into: [:]) { counts, operation in
            counts[operation.kind, default: 0] += 1
        }
    }

    var pendingRelationships: [PendingRelationship] {
        operations.flatMap(\.pendingRelationships).sorted {
            if $0.sourceRecordName != $1.sourceRecordName { return $0.sourceRecordName < $1.sourceRecordName }
            if $0.fieldName != $1.fieldName { return $0.fieldName < $1.fieldName }
            return $0.targetRecordName < $1.targetRecordName
        }
    }

    func redactedText() -> String {
        var lines = ["CKSyncEngine import dry-run report", "", "Operations:"]
        for kind in ImportDryRunOperationKind.allReportCases {
            lines.append("- \(kind.rawValue): \(operationCounts[kind] ?? 0)")
        }

        lines.append("")
        lines.append("Pending relationships:")
        if pendingRelationships.isEmpty {
            lines.append("- none")
        } else {
            for relationship in pendingRelationships {
                lines.append("- \(relationship.sourceRecordType).\(relationship.fieldName) -> \(relationship.targetRecordType)")
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

struct ImportDryRunDecoder {
    private let supportedRecordTypes: Set<String> = [
        "Project", "Folder", "TextFile", "Version",
        "TextFileSectionLink", "TextFileCollectionLink",
        "SceneChapterLink", "SceneActLink", "SceneBookLink", "ScenePlotElementLink", "SceneCharacterLink", "SceneLocationLink",
        "CharacterPlotElementLink", "LocationPlotElementLink"
    ]
    private let localEnvelopesByRecordName: [String: SyncRecordEnvelope]

    init(localEnvelopes: [SyncRecordEnvelope] = []) {
        self.localEnvelopesByRecordName = Dictionary(uniqueKeysWithValues: localEnvelopes.map { ($0.recordName, $0) })
    }

    func decode(remoteEnvelopes: [SyncRecordEnvelope], tombstones: [SyncTombstoneEnvelope] = []) -> ImportDryRunReport {
        let remoteRecordNames = Set(remoteEnvelopes.map(\.recordName))
        let knownRecordNames = Set(localEnvelopesByRecordName.keys).union(remoteRecordNames)
        var operations: [ImportDryRunOperation] = []
        var diagnostics: [SyncMappingDiagnostic] = []

        for envelope in remoteEnvelopes {
            guard supportedRecordTypes.contains(envelope.recordType) else {
                operations.append(ImportDryRunOperation(kind: .unsupported, recordType: envelope.recordType, recordName: envelope.recordName))
                diagnostics.append(Self.diagnostic(code: "unsupported-import-record-type", envelope: envelope, message: "Record type is not part of the Phase 2 import dry-run subset."))
                continue
            }

            let pendingRelationships = pendingRelationships(for: envelope, knownRecordNames: knownRecordNames)
            diagnostics.append(contentsOf: missingRequiredRelationshipDiagnostics(for: envelope))
            if !pendingRelationships.isEmpty {
                operations.append(ImportDryRunOperation(kind: .pendingRelationship, recordType: envelope.recordType, recordName: envelope.recordName, pendingRelationships: pendingRelationships))
                continue
            }

            if let localEnvelope = localEnvelopesByRecordName[envelope.recordName] {
                let changedFields = changedFieldNames(local: localEnvelope, remote: envelope)
                operations.append(ImportDryRunOperation(kind: operationKind(local: localEnvelope, remote: envelope, changedFields: changedFields), recordType: envelope.recordType, recordName: envelope.recordName, changedFields: changedFields))
            } else {
                operations.append(ImportDryRunOperation(kind: .wouldInsert, recordType: envelope.recordType, recordName: envelope.recordName))
            }
        }

        for tombstone in tombstones {
            operations.append(ImportDryRunOperation(kind: .wouldApplyTombstone, recordType: tombstone.recordType, recordName: tombstone.recordName))
        }

        return ImportDryRunReport(operations: operations, diagnostics: diagnostics)
    }

    private func pendingRelationships(for envelope: SyncRecordEnvelope, knownRecordNames: Set<String>) -> [PendingRelationship] {
        relationshipFields(for: envelope.recordType).compactMap { fieldName, targetRecordType in
            guard case let .string(targetID) = envelope.fields[fieldName], !targetID.isEmpty else { return nil }
            let targetRecordName = "\(targetRecordType):\(targetID)"
            guard !knownRecordNames.contains(targetRecordName) else { return nil }
            return PendingRelationship(sourceRecordType: envelope.recordType, sourceRecordName: envelope.recordName, fieldName: fieldName, targetRecordType: targetRecordType, targetRecordName: targetRecordName)
        }
    }

    private func relationshipFields(for recordType: String) -> [(fieldName: String, targetRecordType: String)] {
        switch recordType {
        case "Folder":
            return [("projectID", "Project"), ("parentFolderID", "Folder")]
        case "TextFile":
            return [("projectID", "Project"), ("parentFolderID", "Folder")]
        case "Version":
            return [("textFileID", "TextFile")]
        case "TextFileSectionLink":
            return [("textFileID", "TextFile"), ("sectionID", "ProseSection")]
        case "TextFileCollectionLink":
            return [("textFileID", "TextFile"), ("poetryCollectionID", "PoetryCollection")]
        case "SceneChapterLink":
            return [("sceneID", "StoryScene"), ("chapterID", "Chapter")]
        case "SceneActLink":
            return [("sceneID", "StoryScene"), ("actID", "Act")]
        case "SceneBookLink":
            return [("sceneID", "StoryScene"), ("bookID", "Book")]
        case "ScenePlotElementLink":
            return [("sceneID", "StoryScene"), ("plotElementID", "PlotElement")]
        case "SceneCharacterLink":
            return [("sceneID", "StoryScene"), ("characterID", "Character")]
        case "SceneLocationLink":
            return [("sceneID", "StoryScene"), ("locationID", "Location")]
        case "CharacterPlotElementLink":
            return [("characterID", "Character"), ("plotElementID", "PlotElement")]
        case "LocationPlotElementLink":
            return [("locationID", "Location"), ("plotElementID", "PlotElement")]
        default:
            return []
        }
    }

    private func missingRequiredRelationshipDiagnostics(for envelope: SyncRecordEnvelope) -> [SyncMappingDiagnostic] {
        guard envelope.recordType == "Version", envelope.fields["textFileID"] == .null else {
            return []
        }
        return [Self.diagnostic(code: "missing-required-relationship-id", envelope: envelope, fieldName: "textFileID", message: "Version has no textFileID; keep pending rather than deleting or attaching to another file.")]
    }

    private func changedFieldNames(local: SyncRecordEnvelope, remote: SyncRecordEnvelope) -> [String] {
        let fieldNames = Set(local.fields.keys).union(remote.fields.keys)
        return fieldNames.filter { local.fields[$0] != remote.fields[$0] }.sorted()
    }

    private func operationKind(local: SyncRecordEnvelope, remote: SyncRecordEnvelope, changedFields: [String]) -> ImportDryRunOperationKind {
        guard !changedFields.isEmpty else { return .wouldSkipUnchanged }
        guard case let .date(localModifiedDate) = local.fields["modifiedDate"],
              case let .date(remoteModifiedDate) = remote.fields["modifiedDate"] else {
            return .wouldUpdate
        }

        if remoteModifiedDate > localModifiedDate {
            return .wouldUpdate
        }
        if remoteModifiedDate < localModifiedDate {
            return .wouldSkipUnchanged
        }
        return .conflict
    }

    private static func diagnostic(code: String, envelope: SyncRecordEnvelope, fieldName: String? = nil, message: String) -> SyncMappingDiagnostic {
        SyncMappingDiagnostic(
            severity: .warning,
            code: code,
            entityType: envelope.recordType,
            entityID: entityID(from: envelope),
            fieldName: fieldName,
            message: message
        )
    }

    private static func entityID(from envelope: SyncRecordEnvelope) -> UUID? {
        guard case let .string(rawID) = envelope.fields["entityID"] else { return nil }
        return UUID(uuidString: rawID)
    }
}

private extension ImportDryRunOperationKind {
    static var allReportCases: [ImportDryRunOperationKind] {
        [.wouldInsert, .wouldUpdate, .wouldSkipUnchanged, .wouldApplyTombstone, .pendingRelationship, .conflict, .unsupported]
    }
}
