import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class CKSyncEngineDryRunMapperTests: XCTestCase {
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var mapper: CoreRecordMapper!

    override func setUpWithError() throws {
        let schema = Schema([
            Project.self, Folder.self, TextFile.self, Version.self,
            StyleSheet.self, TextStyleModel.self, ImageStyle.self,
            StoryScene.self, Chapter.self, Act.self, ProseSection.self,
            Book.self, PoetryCollection.self, Character.self, Location.self,
            PlotElement.self, CustomAttribute.self,
            TextFileSectionLink.self, TextFileCollectionLink.self,
            SceneChapterLink.self, SceneActLink.self, SceneBookLink.self,
            ScenePlotElementLink.self, SceneCharacterLink.self,
            CharacterPlotElementLink.self, LocationPlotElementLink.self,
            SceneLocationLink.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
        mapper = CoreRecordMapper()
    }

    override func tearDownWithError() throws {
        mapper = nil
        modelContext = nil
        modelContainer = nil
    }

    func testProjectRecordNameIsDeterministic() {
        let project = Project(name: "Mapping", type: .fiction)

        let envelope = mapper.map(project: project)

        XCTAssertEqual(envelope.recordType, "Project")
        XCTAssertEqual(envelope.recordName, "Project:\(project.id.uuidString)")
        XCTAssertEqual(envelope.fields["entityID"], .string(project.id.uuidString))
    }

    func testProjectMappingExcludesChildArrays() {
        let project = Project(name: "No Children", type: .prose)
        project.folders = [Folder(name: "Drafts", project: project)]

        let envelope = mapper.map(project: project)

        XCTAssertNil(envelope.fields["folders"])
        XCTAssertNil(envelope.fields["publications"])
        XCTAssertNil(envelope.fields["versions"])
    }

    func testFolderMappingPreservesParentAndProjectIDs() {
        let project = Project(name: "Folder Project", type: .prose)
        let parent = Folder(name: "Parent", project: project)
        let child = Folder(name: "Child", parentFolder: parent)

        let envelope = mapper.map(folder: child)

        XCTAssertEqual(envelope.fields["parentFolderID"], .string(parent.id.uuidString))
        XCTAssertEqual(envelope.fields["projectID"], .string(project.id.uuidString))
    }

    func testRootFolderWithProjectDoesNotWarn() {
        let project = Project(name: "Root Project", type: .prose)
        let folder = Folder(name: "Root", project: project)

        let envelope = mapper.map(folder: folder)

        XCTAssertTrue(envelope.diagnostics.isEmpty)
    }

    func testFolderWithMissingParentAndProjectWarnsButMaps() {
        let folder = Folder(name: "Pending")

        let envelope = mapper.map(folder: folder)

        XCTAssertEqual(envelope.recordName, "Folder:\(folder.id.uuidString)")
        XCTAssertTrue(envelope.diagnostics.contains { $0.code == "pending-folder-project" })
    }

    func testTextFileMappingSkipsUndoRedoData() {
        let file = TextFile(name: "Draft")
        file.undoStackData = Data([1, 2, 3])
        file.redoStackData = Data([4, 5])

        let envelope = mapper.map(textFile: file)

        XCTAssertNil(envelope.fields["undoStackData"])
        XCTAssertNil(envelope.fields["redoStackData"])
        XCTAssertEqual(envelope.fields["undoStackPolicy"], .string("localOnly"))
        XCTAssertEqual(envelope.diagnostics.filter { $0.code == "local-only-field-skipped" }.count, 2)
    }

    func testTextFileMappingUsesCoverImagePlaceholder() {
        let file = TextFile(name: "Cover")
        file.coverImageData = Data([9, 8, 7, 6])

        let envelope = mapper.map(textFile: file)

        XCTAssertEqual(envelope.assetPlaceholders, [
            SyncAssetPlaceholder(entityType: "TextFile", entityID: file.id, fieldName: "coverImageData", byteCount: 4)
        ])
        XCTAssertNil(envelope.fields["coverImageData"])
    }

    func testVersionMappingUsesFormattedContentPlaceholder() {
        let version = Version(content: "Plain", versionNumber: 1)
        version.formattedContent = Data([1, 2, 3, 4, 5])

        let envelope = mapper.map(version: version)

        XCTAssertEqual(envelope.assetPlaceholders, [
            SyncAssetPlaceholder(entityType: "Version", entityID: version.id, fieldName: "formattedContent", byteCount: 5)
        ])
        XCTAssertNil(envelope.fields["formattedContent"])
    }

    func testVersionMappingPreservesReferenceMetadataCount() {
        let version = Version(content: "Plain", versionNumber: 1)
        version.referenceMetadataData = Data([1, 2, 3])

        let envelope = mapper.map(version: version)

        XCTAssertEqual(envelope.fields["referenceMetadataData"], .bytesCount(3))
    }

    func testDryRunReportOrdersRecordsDeterministically() {
        let project = Project(name: "Ordered", type: .prose)
        let folder = Folder(name: "Folder", project: project)
        let file = TextFile(name: "File", parentFolder: folder)
        let version = file.versions?.first ?? Version(content: "Plain", versionNumber: 1)

        let report = DryRunSyncReport(envelopes: [
            mapper.map(version: version),
            mapper.map(textFile: file),
            mapper.map(project: project),
            mapper.map(folder: folder)
        ])

        XCTAssertEqual(report.envelopes.map(\.recordType), ["Folder", "Project", "TextFile", "Version"])
        XCTAssertFalse(report.redactedText().contains("Plain"))
    }

    func testTombstoneRecordNameIsDeterministic() {
        let entityID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let deletedDate = Date(timeIntervalSince1970: 123)

        let tombstone = mapper.tombstone(
            entityType: "TextFile",
            entityID: entityID,
            deletedDate: deletedDate,
            deletedByDeviceID: "device-a",
            deleteReason: .userDelete
        )

        XCTAssertEqual(tombstone.recordType, "Tombstone")
        XCTAssertEqual(tombstone.recordName, "Tombstone:TextFile:11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(tombstone.fields["entityType"], .string("TextFile"))
        XCTAssertEqual(tombstone.fields["entityID"], .string(entityID.uuidString))
        XCTAssertEqual(tombstone.fields["deletedDate"], .date(deletedDate))
        XCTAssertEqual(tombstone.fields["deletedByDeviceID"], .string("device-a"))
        XCTAssertEqual(tombstone.fields["deleteReason"], .string("userDelete"))
    }

    func testTombstoneCanCarryParentContextWithoutDeletingChildren() {
        let fileID = UUID()
        let projectID = UUID()

        let tombstone = mapper.tombstone(
            entityType: "TextFile",
            entityID: fileID,
            deletedDate: Date(timeIntervalSince1970: 456),
            deletedByDeviceID: "device-a",
            deleteReason: .emptyTrash,
            parentEntityType: "Project",
            parentEntityID: projectID
        )

        XCTAssertEqual(tombstone.fields["parentEntityType"], .string("Project"))
        XCTAssertEqual(tombstone.fields["parentEntityID"], .string(projectID.uuidString))
        XCTAssertNil(tombstone.fields["childEntityIDs"])
    }

    func testDryRunReportCountsTombstonesSeparatelyFromLiveRecords() {
        let project = Project(name: "Live", type: .prose)
        let fileID = UUID()
        let tombstone = mapper.tombstone(
            entityType: "TextFile",
            entityID: fileID,
            deletedDate: Date(timeIntervalSince1970: 789),
            deletedByDeviceID: "device-a",
            deleteReason: .userDelete
        )

        let report = DryRunSyncReport(envelopes: [mapper.map(project: project)], tombstones: [tombstone])

        XCTAssertEqual(report.recordCounts["Project"], 1)
        XCTAssertNil(report.recordCounts["Tombstone"])
        XCTAssertEqual(report.tombstoneCounts["TextFile"], 1)
        XCTAssertTrue(report.redactedText().contains("Tombstones:"))
        XCTAssertTrue(report.redactedText().contains("- TextFile: 1"))
    }

    func testUnsupportedRecordTypeReturnsDiagnostic() {
        let entityID = UUID()

        let envelope = mapper.unsupported(entityType: "PageSetup", entityID: entityID)

        XCTAssertEqual(envelope.recordType, "PageSetup")
        XCTAssertEqual(envelope.recordName, "PageSetup:\(entityID.uuidString)")
        XCTAssertEqual(envelope.diagnostics, [
            SyncMappingDiagnostic(
                severity: .warning,
                code: "unsupported-record-type",
                entityType: "PageSetup",
                entityID: entityID,
                fieldName: nil,
                message: "Record type is not part of the approved Phase 0 dry-run mapper scope."
            )
        ])
    }
}
