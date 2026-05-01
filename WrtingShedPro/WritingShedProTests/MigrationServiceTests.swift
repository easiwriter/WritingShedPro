import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class MigrationServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self,
            CommentModel.self,
            FootnoteModel.self,
            SubmittedFile.self,
            Submission.self,
            Publication.self,
            TrashItem.self,
            StyleSheet.self,
            TextStyleModel.self,
            ImageStyle.self,
            PageSetup.self,
            PrinterPaper.self,
            StoryScene.self,
            Chapter.self,
            Character.self,
            Location.self,
            CustomAttribute.self,
            PlotElement.self,
            Act.self,
            ProseSection.self,
            PoetryCollection.self,
            Book.self,
            TextFileSectionLink.self,
            TextFileCollectionLink.self,
            SceneChapterLink.self,
            SceneActLink.self,
            SceneBookLink.self,
            ScenePlotElementLink.self,
            SceneCharacterLink.self,
            CharacterPlotElementLink.self,
            LocationPlotElementLink.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testRepairPostImportArtifactsRemovesOnlyEmptyOrphanedVersions() throws {
        let project = Project(name: "Project", type: .poetry)
        let folder = Folder(name: "Folder", project: project)
        let file = TextFile(name: "File", parentFolder: folder)
        let linkedVersion = Version(content: "linked", versionNumber: 1)
        linkedVersion.textFile = file

        let emptyOrphan = Version(content: "", versionNumber: 1)
        let nonEmptyOrphan = Version(content: "keep me", versionNumber: 1)
        let formattedOrphan = Version(content: "", versionNumber: 1)
        formattedOrphan.formattedContent = Data([1, 2, 3])

        context.insert(project)
        context.insert(folder)
        context.insert(file)
        context.insert(linkedVersion)
        context.insert(emptyOrphan)
        context.insert(nonEmptyOrphan)
        context.insert(formattedOrphan)
        try context.save()

        let result = MigrationService.repairPostImportArtifacts(context: context)

        XCTAssertEqual(result.orphanedVersionsRemoved, 1)

        let remainingVersions = try context.fetch(FetchDescriptor<Version>())
        XCTAssertTrue(remainingVersions.contains(where: { $0.id == linkedVersion.id }))
        XCTAssertTrue(remainingVersions.contains(where: { $0.id == nonEmptyOrphan.id }))
        XCTAssertTrue(remainingVersions.contains(where: { $0.id == formattedOrphan.id }))
        XCTAssertFalse(remainingVersions.contains(where: { $0.id == emptyOrphan.id }))
    }
}