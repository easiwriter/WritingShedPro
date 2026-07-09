import Foundation

struct CoreRecordMapper {
    private let schemaVersion: Int64 = 1

    func map(project: Project) -> SyncRecordEnvelope {
        var fields = baseFields(entityType: "Project", entityID: project.id, modifiedDate: project.modifiedDate)
        put(project.name, as: "name", into: &fields)
        put(project.typeRaw, as: "typeRaw", into: &fields)
        put(project.statusRaw, as: "statusRaw", into: &fields)
        put(project.creationDate, as: "creationDate", into: &fields)
        put(project.details, as: "details", into: &fields)
        put(project.notes, as: "notes", into: &fields)
        put(project.author, as: "author", into: &fields)
        put(project.userOrder, as: "userOrder", into: &fields)
        fields["isTrashed"] = .bool(project.isTrashed)
        put(project.deletedDate, as: "deletedDate", into: &fields)
        put(project.fictionClassRaw, as: "fictionClassRaw", into: &fields)
        fields["useMonomyth"] = .bool(project.useMonomyth)
        put(project.storyStructureRaw, as: "storyStructureRaw", into: &fields)
        put(project.dramaScriptTypeRaw, as: "dramaScriptTypeRaw", into: &fields)
        put(project.manuscriptSettingsData, as: "manuscriptSettingsData", into: &fields)
        put(project.tocSettingsData, as: "tocSettingsData", into: &fields)
        put(project.styleSheet?.id, as: "styleSheetID", into: &fields)

        return envelope(recordType: "Project", entityID: project.id, fields: fields)
    }

    func map(folder: Folder) -> SyncRecordEnvelope {
        var fields = baseFields(entityType: "Folder", entityID: folder.id, modifiedDate: nil)
        var diagnostics: [SyncMappingDiagnostic] = []
        let resolvedProjectID = folder.project?.id ?? folder.parentFolder?.resolvedProject?.id

        put(folder.name, as: "name", into: &fields)
        put(folder.userOrder, as: "userOrder", into: &fields)
        put(resolvedProjectID, as: "projectID", into: &fields)
        put(folder.parentFolder?.id, as: "parentFolderID", into: &fields)
        put(folder.frontMatterSettingsData, as: "frontMatterSettingsData", into: &fields)
        put(folder.backMatterSettingsData, as: "backMatterSettingsData", into: &fields)
        put(folder.dramaFrontMatterSettingsData, as: "dramaFrontMatterSettingsData", into: &fields)
        put(folder.dramaBackMatterSettingsData, as: "dramaBackMatterSettingsData", into: &fields)

        if resolvedProjectID == nil && folder.parentFolder == nil {
            diagnostics.append(Self.diagnostic(
                severity: .warning,
                code: "pending-folder-project",
                entityType: "Folder",
                entityID: folder.id,
                fieldName: "projectID",
                message: "Folder has no projectID or parentFolderID; keep pending rather than treating as orphaned."
            ))
        }

        return envelope(recordType: "Folder", entityID: folder.id, fields: fields, diagnostics: diagnostics)
    }

    func map(textFile: TextFile) -> SyncRecordEnvelope {
        var fields = baseFields(entityType: "TextFile", entityID: textFile.id, modifiedDate: textFile.modifiedDate)
        var assets: [SyncAssetPlaceholder] = []
        var diagnostics: [SyncMappingDiagnostic] = []

        fields["createdDate"] = .date(textFile.createdDate)
        fields["currentVersionIndex"] = .int(Int64(textFile.currentVersionIndex))
        put(textFile.name, as: "name", into: &fields)
        put(textFile.userOrder, as: "userOrder", into: &fields)
        put(textFile.workflowStatusRaw, as: "workflowStatusRaw", into: &fields)
        put(textFile.parentFolder?.id, as: "parentFolderID", into: &fields)
        put(textFile.project?.id, as: "projectID", into: &fields)
        put(textFile.scene?.id, as: "sceneID", into: &fields)
        put(textFile.poetryFormId, as: "poetryFormId", into: &fields)
        put(textFile.poetryFormName, as: "poetryFormName", into: &fields)
        fields["includedInManuscript"] = .bool(textFile.includedInManuscript)
        fields["isTOCFile"] = .bool(textFile.isTOCFile)
        put(textFile.tocSettingsData, as: "tocSettingsData", into: &fields)
        fields["isTableOfFiguresFile"] = .bool(textFile.isTableOfFiguresFile)
        put(textFile.tofSettingsData, as: "tofSettingsData", into: &fields)
        fields["isCoverFile"] = .bool(textFile.isCoverFile)
        fields["contentTypeRaw"] = .string(textFile.contentTypeRaw)
        fields["undoStackPolicy"] = .string("localOnly")

        if let coverImageData = textFile.coverImageData, !coverImageData.isEmpty {
            assets.append(asset(entityType: "TextFile", entityID: textFile.id, fieldName: "coverImageData", data: coverImageData))
        }
        appendLocalOnlyDiagnosticIfPresent(textFile.undoStackData, entityType: "TextFile", entityID: textFile.id, fieldName: "undoStackData", diagnostics: &diagnostics)
        appendLocalOnlyDiagnosticIfPresent(textFile.redoStackData, entityType: "TextFile", entityID: textFile.id, fieldName: "redoStackData", diagnostics: &diagnostics)

        return envelope(recordType: "TextFile", entityID: textFile.id, fields: fields, assetPlaceholders: assets, diagnostics: diagnostics)
    }

    func map(version: Version) -> SyncRecordEnvelope {
        var fields = baseFields(entityType: "Version", entityID: version.id, modifiedDate: nil)
        var assets: [SyncAssetPlaceholder] = []
        var diagnostics: [SyncMappingDiagnostic] = []

        put(version.textFile?.id, as: "textFileID", into: &fields)
        fields["content"] = .string(version.content)
        fields["createdDate"] = .date(version.createdDate)
        fields["versionNumber"] = .int(Int64(version.versionNumber))
        put(version.comment, as: "comment", into: &fields)
        put(version.notes, as: "notes", into: &fields)
        put(version.referenceMetadataData, as: "referenceMetadataData", into: &fields)

        if let formattedContent = version.formattedContent, !formattedContent.isEmpty {
            assets.append(asset(entityType: "Version", entityID: version.id, fieldName: "formattedContent", data: formattedContent))
        }
        if let notesFormattedContent = version.notesFormattedContent, !notesFormattedContent.isEmpty {
            assets.append(asset(entityType: "Version", entityID: version.id, fieldName: "notesFormattedContent", data: notesFormattedContent))
        }
        if version.textFile == nil {
            diagnostics.append(Self.diagnostic(
                severity: .warning,
                code: "pending-version-textfile",
                entityType: "Version",
                entityID: version.id,
                fieldName: "textFileID",
                message: "Version has no textFileID; keep pending rather than treating as orphaned."
            ))
        }

        return envelope(recordType: "Version", entityID: version.id, fields: fields, assetPlaceholders: assets, diagnostics: diagnostics)
    }

    func unsupported(entityType: String, entityID: UUID? = nil) -> SyncRecordEnvelope {
        SyncRecordEnvelope(
            recordType: entityType,
            recordName: recordName(entityType: entityType, entityID: entityID),
            fields: [
                "schemaVersion": .int(schemaVersion),
                "entityType": .string(entityType)
            ],
            assetPlaceholders: [],
            diagnostics: [Self.diagnostic(
                severity: .warning,
                code: "unsupported-record-type",
                entityType: entityType,
                entityID: entityID,
                message: "Record type is not part of the approved Phase 0 dry-run mapper scope."
            )]
        )
    }

    func tombstone(
        entityType: String,
        entityID: UUID,
        deletedDate: Date,
        deletedByDeviceID: String,
        deleteReason: SyncDeleteReason,
        parentEntityType: String? = nil,
        parentEntityID: UUID? = nil
    ) -> SyncTombstoneEnvelope {
        SyncTombstoneEnvelope(
            entityType: entityType,
            entityID: entityID,
            deletedDate: deletedDate,
            deletedByDeviceID: deletedByDeviceID,
            deleteReason: deleteReason,
            parentEntityType: parentEntityType,
            parentEntityID: parentEntityID
        )
    }

    private func baseFields(entityType: String, entityID: UUID, modifiedDate: Date?) -> [String: SyncFieldValue] {
        var fields: [String: SyncFieldValue] = [
            "schemaVersion": .int(schemaVersion),
            "entityID": .string(entityID.uuidString),
            "entityType": .string(entityType)
        ]
        put(modifiedDate, as: "modifiedDate", into: &fields)
        return fields
    }

    private func envelope(
        recordType: String,
        entityID: UUID,
        fields: [String: SyncFieldValue],
        assetPlaceholders: [SyncAssetPlaceholder] = [],
        diagnostics: [SyncMappingDiagnostic] = []
    ) -> SyncRecordEnvelope {
        SyncRecordEnvelope(
            recordType: recordType,
            recordName: recordName(entityType: recordType, entityID: entityID),
            fields: fields,
            assetPlaceholders: assetPlaceholders,
            diagnostics: diagnostics
        )
    }

    private func recordName(entityType: String, entityID: UUID?) -> String {
        guard let entityID else { return "\(entityType):unsupported" }
        return "\(entityType):\(entityID.uuidString)"
    }

    private func asset(entityType: String, entityID: UUID, fieldName: String, data: Data) -> SyncAssetPlaceholder {
        SyncAssetPlaceholder(entityType: entityType, entityID: entityID, fieldName: fieldName, byteCount: data.count)
    }

    private func appendLocalOnlyDiagnosticIfPresent(
        _ data: Data?,
        entityType: String,
        entityID: UUID,
        fieldName: String,
        diagnostics: inout [SyncMappingDiagnostic]
    ) {
        guard let data, !data.isEmpty else { return }
        diagnostics.append(Self.diagnostic(
            severity: .info,
            code: "local-only-field-skipped",
            entityType: entityType,
            entityID: entityID,
            fieldName: fieldName,
            message: "\(fieldName) is device-local and is intentionally excluded from CKSyncEngine mapping (\(data.count) bytes)."
        ))
    }

    private func put(_ value: String?, as key: String, into fields: inout [String: SyncFieldValue]) {
        fields[key] = value.map(SyncFieldValue.string) ?? .null
    }

    private func put(_ value: Int?, as key: String, into fields: inout [String: SyncFieldValue]) {
        fields[key] = value.map { .int(Int64($0)) } ?? .null
    }

    private func put(_ value: UUID?, as key: String, into fields: inout [String: SyncFieldValue]) {
        fields[key] = value.map { .string($0.uuidString) } ?? .null
    }

    private func put(_ value: Date?, as key: String, into fields: inout [String: SyncFieldValue]) {
        fields[key] = value.map(SyncFieldValue.date) ?? .null
    }

    private func put(_ value: Data?, as key: String, into fields: inout [String: SyncFieldValue]) {
        fields[key] = value.map { .bytesCount($0.count) } ?? .null
    }

    static func diagnostic(
        severity: SyncMappingSeverity,
        code: String,
        entityType: String,
        entityID: UUID?,
        fieldName: String? = nil,
        message: String
    ) -> SyncMappingDiagnostic {
        SyncMappingDiagnostic(
            severity: severity,
            code: code,
            entityType: entityType,
            entityID: entityID,
            fieldName: fieldName,
            message: message
        )
    }
}
