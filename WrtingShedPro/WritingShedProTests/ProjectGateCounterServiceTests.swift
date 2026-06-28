import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class ProjectGateCounterServiceTests: XCTestCase {
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self,
            TrashItem.self,
            StoryScene.self,
            Chapter.self,
            Act.self,
            Book.self,
            SceneChapterLink.self,
            SceneActLink.self,
            SceneBookLink.self,
            ScenePlotElementLink.self,
            SceneCharacterLink.self,
            Character.self,
            Location.self,
            PlotElement.self,
            CharacterPlotElementLink.self,
            LocationPlotElementLink.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }

    func testActiveProjectCountExcludesTrashedProjects() {
        let proseA = Project(name: "Prose A", type: .prose)
        let proseB = Project(name: "Prose B", type: .prose)
        proseB.isTrashed = true
        let poetry = Project(name: "Poetry", type: .poetry)

        modelContext.insert(proseA)
        modelContext.insert(proseB)
        modelContext.insert(poetry)

        let count = ProjectGateCounterService.activeProjectCount(
            ofType: .prose,
            in: [proseA, proseB, poetry]
        )

        XCTAssertEqual(count, 1)
    }

    func testActiveFileCountCountsNestedAndExcludesTrashedFiles() {
        let project = Project(name: "Nested Files", type: .fiction)
        let root = Folder(name: "Scenes", project: project)
        let child = Folder(name: "Part 1", project: nil, parentFolder: root)

        let activeRootFile = TextFile(name: "Scene 1", parentFolder: root)
        let trashedRootFile = TextFile(name: "Scene 2", parentFolder: root)
        let trashItem = TrashItem(textFile: trashedRootFile, originalFolder: root, project: project)
        trashedRootFile.trashItem = trashItem
        let activeChildFile = TextFile(name: "Scene 3", parentFolder: child)

        modelContext.insert(project)
        modelContext.insert(root)
        modelContext.insert(child)
        modelContext.insert(activeRootFile)
        modelContext.insert(trashedRootFile)
        modelContext.insert(trashItem)
        modelContext.insert(activeChildFile)

        let count = ProjectGateCounterService.activeFileCount(in: project)

        XCTAssertEqual(count, 2)
    }

    func testActiveFileCountPreventsSceneOnlyUndercount() {
        let project = Project(name: "Fiction", type: .fiction)
        let researchFolder = Folder(name: "Research", project: project)
        let researchFile = TextFile(name: "World Notes", parentFolder: researchFolder)

        modelContext.insert(project)
        modelContext.insert(researchFolder)
        modelContext.insert(researchFile)

        // No scenes exist yet; old scene-count gating would incorrectly return 0.
        XCTAssertEqual((project.scenes ?? []).filter { !$0.isTrashed }.count, 0)

        let activeFileCount = ProjectGateCounterService.activeFileCount(in: project)
        XCTAssertEqual(activeFileCount, 1)
    }
}
