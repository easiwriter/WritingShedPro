import XCTest
@testable import Writing_Shed_Pro

final class SceneListViewTests: XCTestCase {

    func testSceneFolderNameForVerseNovelIsEpisodes() {
        let project = Project(name: "Verse Novel", type: .fiction)
        project.fictionClass = .verseNovel

        let folderName = SceneListView.sceneFolderName(for: project)

        XCTAssertEqual(folderName, "Episodes")
    }

    func testSceneFolderNameForNovelIsScenes() {
        let project = Project(name: "Novel", type: .fiction)
        project.fictionClass = .novel

        let folderName = SceneListView.sceneFolderName(for: project)

        XCTAssertEqual(folderName, "Scenes")
    }

    func testSceneFolderNameForDramaIsScenes() {
        let project = Project(name: "Play", type: .drama)

        let folderName = SceneListView.sceneFolderName(for: project)

        XCTAssertEqual(folderName, "Scenes")
    }
}
