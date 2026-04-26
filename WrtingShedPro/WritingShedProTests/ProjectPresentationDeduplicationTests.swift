import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class ProjectPresentationDeduplicationTests: XCTestCase {

    func testPresentedProjectsKeepsRichestSyncedDuplicate() {
        let creationDate = Date(timeIntervalSince1970: 1_710_000_000)
        let sparse = Project(name: "The Republic of Heaven", type: .prose, creationDate: creationDate)
        let rich = Project(name: "The Republic of Heaven", type: .prose, creationDate: creationDate)

        let manuscript = Folder(name: "Manuscript", project: rich)
        let draft = TextFile(name: "Draft", parentFolder: manuscript)
        manuscript.textFiles = [draft]
        rich.folders = [manuscript]

        let visible = DeduplicationService.presentedProjects(from: [sparse, rich])

        XCTAssertEqual(visible.count, 1)
        XCTAssertEqual(visible.first?.id, rich.id)
    }

    func testPresentedProjectsDoesNotCollapseUnnamedProjects() {
        let first = Project(name: nil, type: .prose)
        let second = Project(name: nil, type: .prose)

        let visible = DeduplicationService.presentedProjects(from: [first, second])

        XCTAssertEqual(visible.count, 2)
    }

    func testNameConflictChecksAllProjectsIncludingHiddenDuplicates() {
        let visibleDuplicate = Project(name: "The Republic", type: .prose)
        let hiddenDuplicate = Project(name: "The Republic", type: .prose)
        let other = Project(name: "Poems 2026", type: .poetry)

        let manuscript = Folder(name: "Manuscript", project: visibleDuplicate)
        let draft = TextFile(name: "Draft", parentFolder: manuscript)
        manuscript.textFiles = [draft]
        visibleDuplicate.folders = [manuscript]

        XCTAssertTrue(
            DeduplicationService.hasProjectNameConflict(
                "The Republic",
                in: [visibleDuplicate, hiddenDuplicate, other],
                excluding: visibleDuplicate
            )
        )

        XCTAssertTrue(
            DeduplicationService.hasProjectNameConflict(
                "Poems 2026",
                in: [visibleDuplicate, hiddenDuplicate, other],
                excluding: visibleDuplicate
            )
        )
    }

    @MainActor func testSyncedDuplicateFamilyMatchesSameNameTypeAndCreationDate() throws {
        let creationDate = Date(timeIntervalSince1970: 1_710_000_000)
        let original = Project(name: "The Republic of Heaven", type: .poetry, creationDate: creationDate)
        let clone = Project(name: "The Republic of Heaven", type: .poetry, creationDate: creationDate)
        let recreated = Project(name: "The Republic of Heaven", type: .poetry, creationDate: creationDate.addingTimeInterval(60))

        let schema = Schema([Project.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        context.insert(original)
        context.insert(clone)
        context.insert(recreated)

        let family = DeduplicationService.syncedDuplicateFamily(for: original, context: context)

        XCTAssertEqual(Set(family.map(\.id)), Set([original.id, clone.id]))
        XCTAssertFalse(family.contains(where: { $0.id == recreated.id }))
    }
}