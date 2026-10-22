import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class ProjectPresentationDeduplicationTests: XCTestCase {

    func testPresentedProjectsKeepsDistinctIDsEvenWhenOneHasMoreContent() {
        let creationDate = Date(timeIntervalSince1970: 1_710_000_000)
        let sparse = Project(name: "The Republic of Heaven", type: .prose, creationDate: creationDate)
        let rich = Project(name: "The Republic of Heaven", type: .prose, creationDate: creationDate)

        let manuscript = Folder(name: "Manuscript", project: rich)
        let draft = TextFile(name: "Draft", parentFolder: manuscript)
        manuscript.textFiles = [draft]
        rich.folders = [manuscript]

        let visible = DeduplicationService.presentedProjects(from: [sparse, rich])

        XCTAssertEqual(Set(visible.map(\.id)), Set([sparse.id, rich.id]))
    }

    func testPresentedProjectsKeepsStructurallyIdenticalProjectsWithDistinctIDs() {
        let first = Project(name: "Poems 2026", type: .poetry, creationDate: Date(timeIntervalSince1970: 1_710_000_000))
        let second = Project(name: "Poems 2026", type: .poetry, creationDate: Date(timeIntervalSince1970: 1_720_000_000))

        let firstManuscript = Folder(name: "Manuscript", project: first)
        let firstDraft = TextFile(name: "Draft", parentFolder: firstManuscript)
        firstManuscript.textFiles = [firstDraft]
        first.folders = [firstManuscript]

        let secondManuscript = Folder(name: "Manuscript", project: second)
        let secondDraft = TextFile(name: "Draft", parentFolder: secondManuscript)
        secondManuscript.textFiles = [secondDraft]
        second.folders = [secondManuscript]

        let visible = DeduplicationService.presentedProjects(from: [first, second])

        XCTAssertEqual(Set(visible.map(\.id)), Set([first.id, second.id]))
    }

    func testPresentedProjectsKeepsSameNameTypeProjectsWhenRelationshipsDiffer() {
        let populated = Project(name: "Poems 2026", type: .poetry, creationDate: Date(timeIntervalSince1970: 1_710_000_000))
        let relationshipLagging = Project(name: "Poems 2026", type: .poetry, creationDate: Date(timeIntervalSince1970: 1_720_000_000))

        let manuscript = Folder(name: "Manuscript", project: populated)
        let draft = TextFile(name: "Draft", parentFolder: manuscript)
        manuscript.textFiles = [draft]
        populated.folders = [manuscript]

        let visible = DeduplicationService.presentedProjects(from: [populated, relationshipLagging])

        XCTAssertEqual(Set(visible.map(\.id)), Set([populated.id, relationshipLagging.id]))
    }

    func testPresentedProjectsCollapsesRowsWithSameUUID() {
        let first = Project(name: "Poems 2026", type: .poetry)
        let second = Project(name: "Poems 2026", type: .poetry)
        second.id = first.id

        let visible = DeduplicationService.presentedProjects(from: [first, second])

        XCTAssertEqual(visible.count, 1)
        XCTAssertEqual(visible.first?.id, first.id)
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

    @MainActor func testZombieCleanupSkipsActiveProjectEvenWithMatchingUUIDTombstone() throws {
        defer { DeduplicationService.clearAllTombstones() }

        let project = Project(name: "Poem Shed", type: .poetry)
        let schema = Schema([Project.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        context.insert(project)
        try context.save()

        DeduplicationService.recordTombstone(for: project)

        let deleted = DeduplicationService.deleteZombieProjects(context: context)

        XCTAssertEqual(deleted, 0)

        let descriptor = FetchDescriptor<Project>()
        let remaining = try context.fetch(descriptor)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.name, "Poem Shed")
    }

    @MainActor func testSyncedDuplicateFamilyMatchesOnlySameUUID() throws {
        let creationDate = Date(timeIntervalSince1970: 1_710_000_000)
        let original = Project(name: "The Republic of Heaven", type: .poetry, creationDate: creationDate)
        let clone = Project(name: "The Republic of Heaven", type: .poetry, creationDate: creationDate)
        clone.id = original.id
        let recreated = Project(name: "The Republic of Heaven", type: .poetry, creationDate: creationDate)

        let schema = Schema([Project.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        context.insert(original)
        context.insert(clone)
        context.insert(recreated)

        let family = DeduplicationService.syncedDuplicateFamily(for: original, context: context)

        XCTAssertEqual(family.count, 2)
        XCTAssertTrue(family.allSatisfy { $0.id == original.id })
        XCTAssertFalse(family.contains(where: { $0.persistentModelID == recreated.persistentModelID }))
    }
}