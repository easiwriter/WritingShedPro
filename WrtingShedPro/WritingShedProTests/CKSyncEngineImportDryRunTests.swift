import XCTest
@testable import Writing_Shed_Pro

final class CKSyncEngineImportDryRunTests: XCTestCase {
    func testRemoteRecordWithNoLocalMatchWouldInsert() {
        let project = envelope(recordType: "Project", id: UUID())
        let report = ImportDryRunDecoder().decode(remoteEnvelopes: [project])

        XCTAssertEqual(report.operationCounts[.wouldInsert], 1)
        XCTAssertTrue(report.diagnostics.isEmpty)
    }

    func testMatchingRemoteRecordWouldSkipUnchanged() {
        let project = envelope(recordType: "Project", id: UUID(), fields: ["name": .string("Same")])
        let report = ImportDryRunDecoder(localEnvelopes: [project]).decode(remoteEnvelopes: [project])

        XCTAssertEqual(report.operations, [
            ImportDryRunOperation(kind: .wouldSkipUnchanged, recordType: "Project", recordName: project.recordName)
        ])
    }

    func testChangedRemoteRecordWouldUpdateWithChangedFieldsOnly() {
        let id = UUID()
        let local = envelope(recordType: "Project", id: id, fields: ["name": .string("Local"), "typeRaw": .string("prose")])
        let remote = envelope(recordType: "Project", id: id, fields: ["name": .string("Remote"), "typeRaw": .string("prose")])

        let report = ImportDryRunDecoder(localEnvelopes: [local]).decode(remoteEnvelopes: [remote])

        XCTAssertEqual(report.operations, [
            ImportDryRunOperation(kind: .wouldUpdate, recordType: "Project", recordName: remote.recordName, changedFields: ["name"])
        ])
    }

    func testNewerRemoteRecordWouldUpdate() {
        let id = UUID()
        let local = envelope(recordType: "Project", id: id, fields: ["name": .string("Local"), "modifiedDate": .date(Date(timeIntervalSince1970: 100))])
        let remote = envelope(recordType: "Project", id: id, fields: ["name": .string("Remote"), "modifiedDate": .date(Date(timeIntervalSince1970: 200))])

        let report = ImportDryRunDecoder(localEnvelopes: [local]).decode(remoteEnvelopes: [remote])

        XCTAssertEqual(report.operations, [
            ImportDryRunOperation(kind: .wouldUpdate, recordType: "Project", recordName: remote.recordName, changedFields: ["modifiedDate", "name"])
        ])
    }

    func testOlderRemoteRecordWouldSkip() {
        let id = UUID()
        let local = envelope(recordType: "Project", id: id, fields: ["name": .string("Local"), "modifiedDate": .date(Date(timeIntervalSince1970: 200))])
        let remote = envelope(recordType: "Project", id: id, fields: ["name": .string("Remote"), "modifiedDate": .date(Date(timeIntervalSince1970: 100))])

        let report = ImportDryRunDecoder(localEnvelopes: [local]).decode(remoteEnvelopes: [remote])

        XCTAssertEqual(report.operations, [
            ImportDryRunOperation(kind: .wouldSkipUnchanged, recordType: "Project", recordName: remote.recordName, changedFields: ["modifiedDate", "name"])
        ])
    }

    func testEqualModifiedDatesWithDifferentFieldsBecomeConflict() {
        let id = UUID()
        let modifiedDate = Date(timeIntervalSince1970: 200)
        let local = envelope(recordType: "Project", id: id, fields: ["name": .string("Local"), "modifiedDate": .date(modifiedDate)])
        let remote = envelope(recordType: "Project", id: id, fields: ["name": .string("Remote"), "modifiedDate": .date(modifiedDate)])

        let report = ImportDryRunDecoder(localEnvelopes: [local]).decode(remoteEnvelopes: [remote])

        XCTAssertEqual(report.operations, [
            ImportDryRunOperation(kind: .conflict, recordType: "Project", recordName: remote.recordName, changedFields: ["name"])
        ])
        XCTAssertTrue(report.redactedText().contains("- conflict: 1"))
    }

    func testChildBeforeParentInSameBatchDoesNotBecomePending() {
        let projectID = UUID()
        let folder = envelope(recordType: "Folder", id: UUID(), fields: ["projectID": .string(projectID.uuidString)])
        let project = envelope(recordType: "Project", id: projectID)

        let report = ImportDryRunDecoder().decode(remoteEnvelopes: [folder, project])

        XCTAssertEqual(report.operationCounts[.wouldInsert], 2)
        XCTAssertTrue(report.pendingRelationships.isEmpty)
    }

    func testChildBeforeMissingParentBecomesPendingRelationship() {
        let textFileID = UUID()
        let version = envelope(recordType: "Version", id: UUID(), fields: ["textFileID": .string(textFileID.uuidString)])

        let report = ImportDryRunDecoder().decode(remoteEnvelopes: [version])

        XCTAssertEqual(report.operations, [
            ImportDryRunOperation(
                kind: .pendingRelationship,
                recordType: "Version",
                recordName: version.recordName,
                pendingRelationships: [
                    PendingRelationship(sourceRecordType: "Version", sourceRecordName: version.recordName, fieldName: "textFileID", targetRecordType: "TextFile", targetRecordName: "TextFile:\(textFileID.uuidString)")
                ]
            )
        ])
    }

    func testLinkRecordWithOneMissingEndpointBecomesPendingRelationship() {
        let textFileID = UUID()
        let collectionID = UUID()
        let localTextFile = envelope(recordType: "TextFile", id: textFileID)
        let link = envelope(recordType: "TextFileCollectionLink", id: UUID(), fields: [
            "textFileID": .string(textFileID.uuidString),
            "poetryCollectionID": .string(collectionID.uuidString)
        ])

        let report = ImportDryRunDecoder(localEnvelopes: [localTextFile]).decode(remoteEnvelopes: [link])

        XCTAssertEqual(report.operations, [
            ImportDryRunOperation(
                kind: .pendingRelationship,
                recordType: "TextFileCollectionLink",
                recordName: link.recordName,
                pendingRelationships: [
                    PendingRelationship(sourceRecordType: "TextFileCollectionLink", sourceRecordName: link.recordName, fieldName: "poetryCollectionID", targetRecordType: "PoetryCollection", targetRecordName: "PoetryCollection:\(collectionID.uuidString)")
                ]
            )
        ])
    }

    func testLinkRecordWithEndpointsInSameBatchWouldInsert() {
        let sceneID = UUID()
        let characterID = UUID()
        let scene = envelope(recordType: "StoryScene", id: sceneID)
        let character = envelope(recordType: "Character", id: characterID)
        let link = envelope(recordType: "SceneCharacterLink", id: UUID(), fields: [
            "sceneID": .string(sceneID.uuidString),
            "characterID": .string(characterID.uuidString)
        ])

        let report = ImportDryRunDecoder().decode(remoteEnvelopes: [link, scene, character])

        XCTAssertTrue(report.operations.contains(ImportDryRunOperation(kind: .wouldInsert, recordType: "SceneCharacterLink", recordName: link.recordName)))
        XCTAssertFalse(report.pendingRelationships.contains { $0.sourceRecordName == link.recordName })
    }

    func testMissingRequiredRelationshipIDBecomesDiagnosticNotDelete() {
        let version = envelope(recordType: "Version", id: UUID(), fields: ["textFileID": .null])
        let report = ImportDryRunDecoder().decode(remoteEnvelopes: [version])

        XCTAssertEqual(report.operationCounts[.wouldInsert], 1)
        XCTAssertTrue(report.diagnostics.contains { $0.code == "missing-required-relationship-id" })
        XCTAssertNil(report.operationCounts[.wouldApplyTombstone])
    }

    func testRemoteTombstoneIsIntentOnlyAndDoesNotCascadeChildren() {
        let projectID = UUID()
        let tombstone = SyncTombstoneEnvelope(
            entityType: "Project",
            entityID: projectID,
            deletedDate: Date(timeIntervalSince1970: 1),
            deletedByDeviceID: "device-a",
            deleteReason: .userDelete
        )

        let report = ImportDryRunDecoder().decode(remoteEnvelopes: [], tombstones: [tombstone])

        XCTAssertEqual(report.operations, [
            ImportDryRunOperation(kind: .wouldApplyTombstone, recordType: "Tombstone", recordName: tombstone.recordName)
        ])
        XCTAssertNil(report.operationCounts[.pendingRelationship])
    }

    func testUnsupportedRecordTypeAppearsInReport() {
        let pageSetup = envelope(recordType: "PageSetup", id: UUID())
        let report = ImportDryRunDecoder().decode(remoteEnvelopes: [pageSetup])

        XCTAssertEqual(report.operationCounts[.unsupported], 1)
        XCTAssertTrue(report.diagnostics.contains { $0.code == "unsupported-import-record-type" })
    }

    func testReportRedactsRecordContent() {
        let version = envelope(recordType: "Version", id: UUID(), fields: ["content": .string("Secret manuscript text")])
        let report = ImportDryRunDecoder().decode(remoteEnvelopes: [version])

        XCTAssertFalse(report.redactedText().contains("Secret manuscript text"))
        XCTAssertTrue(report.redactedText().contains("CKSyncEngine import dry-run report"))
    }

    private func envelope(recordType: String, id: UUID, fields: [String: SyncFieldValue] = [:]) -> SyncRecordEnvelope {
        var allFields = fields
        allFields["entityID"] = .string(id.uuidString)
        allFields["entityType"] = .string(recordType)
        allFields["schemaVersion"] = .int(1)
        return SyncRecordEnvelope(
            recordType: recordType,
            recordName: "\(recordType):\(id.uuidString)",
            fields: allFields,
            assetPlaceholders: [],
            diagnostics: []
        )
    }
}
