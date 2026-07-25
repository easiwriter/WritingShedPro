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

    func testPresentedProjectsCollapsesStructurallyIdenticalRecoveryClones() {
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

        XCTAssertEqual(visible.count, 1)
    }

    func testPresentedProjectsCollapsesSameNameTypeRecoveryClonesEvenWhenRelationshipsDiffer() {
        let populated = Project(name: "Poems 2026", type: .poetry, creationDate: Date(timeIntervalSince1970: 1_710_000_000))
        let relationshipLagging = Project(name: "Poems 2026", type: .poetry, creationDate: Date(timeIntervalSince1970: 1_720_000_000))

        let manuscript = Folder(name: "Manuscript", project: populated)
        let draft = TextFile(name: "Draft", parentFolder: manuscript)
        manuscript.textFiles = [draft]
        populated.folders = [manuscript]

        let visible = DeduplicationService.presentedProjects(from: [populated, relationshipLagging])

        XCTAssertEqual(visible.count, 1)
        XCTAssertEqual(visible.first?.id, populated.id)
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