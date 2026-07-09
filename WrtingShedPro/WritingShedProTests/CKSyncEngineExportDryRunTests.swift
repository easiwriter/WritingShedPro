import XCTest
@testable import Writing_Shed_Pro

final class CKSyncEngineExportDryRunTests: XCTestCase {
    func testChangedRecordWouldSaveRecord() {
        let file = envelope(recordType: "TextFile", id: UUID(), fields: ["name": .string("Draft")])

        let report = ExportDryRunBuilder().build(changedEnvelopes: [file])

        XCTAssertEqual(report.operations, [
            ExportDryRunOperation(kind: .wouldSaveRecord, recordType: "TextFile", recordName: file.recordName)
        ])
    }

    func testAssetPlaceholderWouldSaveAssetWithoutContent() {
        let versionID = UUID()
        let version = envelope(
            recordType: "Version",
            id: versionID,
            fields: ["content": .string("Plain text only")],
            assetPlaceholders: [SyncAssetPlaceholder(entityType: "Version", entityID: versionID, fieldName: "formattedContent", byteCount: 128)]
        )

        let report = ExportDryRunBuilder().build(changedEnvelopes: [version])

        XCTAssertEqual(report.operationCounts[.wouldSaveAsset], 1)
        XCTAssertEqual(report.assetPlaceholders, [SyncAssetPlaceholder(entityType: "Version", entityID: versionID, fieldName: "formattedContent", byteCount: 128)])
        XCTAssertFalse(report.redactedText().contains("Plain text only"))
        XCTAssertTrue(report.redactedText().contains("Version.formattedContent"))
    }

    func testLargeAssetPlaceholderAddsWarningDiagnostic() {
        let versionID = UUID()
        let version = envelope(
            recordType: "Version",
            id: versionID,
            assetPlaceholders: [SyncAssetPlaceholder(entityType: "Version", entityID: versionID, fieldName: "formattedContent", byteCount: 5 * 1024 * 1024)]
        )

        let report = ExportDryRunBuilder().build(changedEnvelopes: [version])

        XCTAssertTrue(report.diagnostics.contains { $0.code == "large-asset-placeholder" && $0.severity == .warning })
        XCTAssertEqual(report.operationCounts[.warning], 1)
    }

    func testOversizedAssetPlaceholderAddsErrorDiagnostic() {
        let versionID = UUID()
        let version = envelope(
            recordType: "Version",
            id: versionID,
            assetPlaceholders: [SyncAssetPlaceholder(entityType: "Version", entityID: versionID, fieldName: "formattedContent", byteCount: 50 * 1024 * 1024 + 1)]
        )

        let report = ExportDryRunBuilder().build(changedEnvelopes: [version])

        XCTAssertTrue(report.diagnostics.contains { $0.code == "oversized-asset-placeholder" && $0.severity == .error })
        XCTAssertEqual(report.operationCounts[.warning], 1)
    }

    func testLocalOnlyDiagnosticWouldSkipLocalOnly() {
        let fileID = UUID()
        let file = envelope(
            recordType: "TextFile",
            id: fileID,
            diagnostics: [SyncMappingDiagnostic(severity: .info, code: "local-only-field-skipped", entityType: "TextFile", entityID: fileID, fieldName: "undoStackData", message: "undoStackData is local-only")]
        )

        let report = ExportDryRunBuilder().build(changedEnvelopes: [file])

        XCTAssertTrue(report.operations.contains(ExportDryRunOperation(kind: .wouldSkipLocalOnly, recordType: "TextFile", recordName: file.recordName, fieldName: "undoStackData")))
        XCTAssertEqual(report.operationCounts[.wouldSaveRecord], 1)
    }

    func testLinkInsertWouldSaveLinkRecord() {
        let link = envelope(recordType: "SceneCharacterLink", id: UUID(), fields: ["sceneID": .string(UUID().uuidString), "characterID": .string(UUID().uuidString)])

        let report = ExportDryRunBuilder().build(changedEnvelopes: [link])

        XCTAssertEqual(report.operations, [
            ExportDryRunOperation(kind: .wouldSaveRecord, recordType: "SceneCharacterLink", recordName: link.recordName)
        ])
    }

    func testLinkDeleteWouldSaveLinkTombstoneOnly() {
        let linkID = UUID()
        let sceneID = UUID()
        let tombstone = SyncTombstoneEnvelope(entityType: "SceneCharacterLink", entityID: linkID, deletedDate: Date(timeIntervalSince1970: 1), deletedByDeviceID: "device-a", deleteReason: .userDelete, parentEntityType: "StoryScene", parentEntityID: sceneID)

        let report = ExportDryRunBuilder().build(changedEnvelopes: [], tombstones: [tombstone])

        XCTAssertEqual(report.operations, [
            ExportDryRunOperation(kind: .wouldSaveTombstone, recordType: "SceneCharacterLink", recordName: tombstone.recordName)
        ])
        XCTAssertNil(report.operationCounts[.wouldSaveRecord])
    }

    func testParentDeleteIntentDoesNotCreateChildDeletes() {
        let projectID = UUID()
        let tombstone = SyncTombstoneEnvelope(entityType: "Project", entityID: projectID, deletedDate: Date(timeIntervalSince1970: 1), deletedByDeviceID: "device-a", deleteReason: .emptyTrash)

        let report = ExportDryRunBuilder().build(changedEnvelopes: [], tombstones: [tombstone])

        XCTAssertEqual(report.operationCounts[.wouldSaveTombstone], 1)
        XCTAssertFalse(report.operations.contains { $0.recordType == "Folder" || $0.recordType == "TextFile" })
    }

    func testDeferredSeedStyleWouldDefer() {
        let stylesheet = envelope(recordType: "StyleSheet", id: UUID())

        let report = ExportDryRunBuilder().build(changedEnvelopes: [], deferredEnvelopes: [stylesheet])

        XCTAssertEqual(report.operations, [
            ExportDryRunOperation(kind: .wouldDefer, recordType: "StyleSheet", recordName: stylesheet.recordName)
        ])
    }

    func testWarningDiagnosticWouldReportWarning() {
        let folderID = UUID()
        let folder = envelope(
            recordType: "Folder",
            id: folderID,
            diagnostics: [SyncMappingDiagnostic(severity: .warning, code: "pending-folder-project", entityType: "Folder", entityID: folderID, fieldName: "projectID", message: "Pending project relationship")]
        )

        let report = ExportDryRunBuilder().build(changedEnvelopes: [folder])

        XCTAssertTrue(report.operations.contains(ExportDryRunOperation(kind: .warning, recordType: "Folder", recordName: folder.recordName, fieldName: "projectID")))
        XCTAssertTrue(report.redactedText().contains("pending-folder-project"))
    }

    func testSnapshotChangeTrackerFindsAddedAndUpdatedEnvelopes() {
        let unchanged = envelope(recordType: "Project", id: UUID(), fields: ["name": .string("Same")])
        let updatedID = UUID()
        let updatedBaseline = envelope(recordType: "TextFile", id: updatedID, fields: ["name": .string("Old")])
        let updatedCurrent = envelope(recordType: "TextFile", id: updatedID, fields: ["name": .string("New")])
        let added = envelope(recordType: "Version", id: UUID())

        let changed = SyncChangeTracker(baselineEnvelopes: [unchanged, updatedBaseline]).changedEnvelopes(currentEnvelopes: [updatedCurrent, unchanged, added])

        XCTAssertEqual(changed, [updatedCurrent, added])
    }

    func testSnapshotChangeTrackerDoesNotInferDeletesFromMissingCurrentEnvelope() {
        let missing = envelope(recordType: "TextFile", id: UUID(), fields: ["name": .string("Missing")])

        let changed = SyncChangeTracker(baselineEnvelopes: [missing]).changedEnvelopes(currentEnvelopes: [])

        XCTAssertTrue(changed.isEmpty)
    }

    private func envelope(recordType: String, id: UUID, fields: [String: SyncFieldValue] = [:], assetPlaceholders: [SyncAssetPlaceholder] = [], diagnostics: [SyncMappingDiagnostic] = []) -> SyncRecordEnvelope {
        var allFields = fields
        allFields["entityID"] = .string(id.uuidString)
        allFields["entityType"] = .string(recordType)
        allFields["schemaVersion"] = .int(1)
        return SyncRecordEnvelope(
            recordType: recordType,
            recordName: "\(recordType):\(id.uuidString)",
            fields: allFields,
            assetPlaceholders: assetPlaceholders,
            diagnostics: diagnostics
        )
    }
}
