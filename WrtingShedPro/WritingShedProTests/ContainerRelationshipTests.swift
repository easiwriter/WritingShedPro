//
//  ContainerRelationshipTests.swift
//  Writing Shed ProTests
//
//  Created on 28 February 2026.
//  Tests for many-to-many container relationships and helper methods.
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class ContainerRelationshipTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        let schema = Schema([
            Project.self, Folder.self, TextFile.self, Version.self,
            TrashItem.self, StyleSheet.self, TextStyleModel.self,
            PageSetup.self, PrinterPaper.self,
            Publication.self, Submission.self, SubmittedFile.self,
            CommentModel.self, FootnoteModel.self, PoetryFormModel.self,
            StoryScene.self, Chapter.self, Character.self, Location.self,
            CustomAttribute.self, PlotElement.self,
            Act.self, ProseSection.self,
            PoetryCollection.self, Book.self,
            TextFileSectionLink.self, TextFileCollectionLink.self,
            SceneChapterLink.self, SceneActLink.self, SceneBookLink.self,
            ScenePlotElementLink.self, SceneCharacterLink.self,
            CharacterPlotElementLink.self, LocationPlotElementLink.self
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

    private func poetryCollectionLinks(for file: TextFile) throws -> [TextFileCollectionLink] {
        let links = try modelContext.fetch(FetchDescriptor<TextFileCollectionLink>())
        return links.filter { $0.textFileID == file.id || $0.textFile?.id == file.id }
    }

    private func poetryCollectionIDs(for file: TextFile) throws -> Set<UUID> {
        Set(try poetryCollectionLinks(for: file).compactMap { $0.poetryCollectionID ?? $0.poetryCollection?.id })
    }

    private func poetryCollectionLinkCount(for file: TextFile) throws -> Int {
        try poetryCollectionLinks(for: file).count
    }
    
    // MARK: - TextFile ↔ PoetryCollection
    
    func testAddToPoetryCollection() throws {
        let collection = PoetryCollection(name: "Sonnets")
        modelContext.insert(collection)
        
        let file = TextFile(name: "Poem 1", initialContent: "")
        modelContext.insert(file)
        
        file.addToPoetryCollection(collection)
        try modelContext.save()
        
        XCTAssertTrue(file.isInPoetryCollection(collection))
        XCTAssertEqual(try poetryCollectionLinkCount(for: file), 1)
        XCTAssertEqual(try poetryCollectionIDs(for: file), [collection.id])
    }

    func testAddToPoetryCollectionCreatesScalarLinkWithoutRelationships() throws {
        let collection = PoetryCollection(name: "Sonnets")
        modelContext.insert(collection)

        let file = TextFile(name: "Poem 1", initialContent: "")
        modelContext.insert(file)

        file.addToPoetryCollection(collection)
        try modelContext.save()

        let link = try XCTUnwrap(poetryCollectionLinks(for: file).first)
        XCTAssertEqual(link.textFileID, file.id)
        XCTAssertEqual(link.poetryCollectionID, collection.id)
        XCTAssertNil(link.textFile)
        XCTAssertNil(link.poetryCollection)
    }
    
    func testAddToPoetryCollection_NoDuplicate() throws {
        let collection = PoetryCollection(name: "Sonnets")
        modelContext.insert(collection)
        
        let file = TextFile(name: "Poem 1", initialContent: "")
        modelContext.insert(file)
        
        file.addToPoetryCollection(collection)
        file.addToPoetryCollection(collection) // duplicate
        try modelContext.save()
        
        XCTAssertEqual(try poetryCollectionLinkCount(for: file), 1)
    }
    
    func testMultiplePoetryCollections() throws {
        let col1 = PoetryCollection(name: "Sonnets")
        let col2 = PoetryCollection(name: "Love Poems")
        modelContext.insert(col1)
        modelContext.insert(col2)
        
        let file = TextFile(name: "Poem 1", initialContent: "")
        modelContext.insert(file)
        
        file.addToPoetryCollection(col1)
        file.addToPoetryCollection(col2)
        try modelContext.save()
        
        XCTAssertEqual(try poetryCollectionLinkCount(for: file), 2)
        XCTAssertTrue(file.isInPoetryCollection(col1))
        XCTAssertTrue(file.isInPoetryCollection(col2))
    }
    
    func testRemoveFromPoetryCollection() throws {
        let col1 = PoetryCollection(name: "Sonnets")
        let col2 = PoetryCollection(name: "Love Poems")
        modelContext.insert(col1)
        modelContext.insert(col2)
        
        let file = TextFile(name: "Poem 1", initialContent: "")
        modelContext.insert(file)
        
        file.addToPoetryCollection(col1)
        file.addToPoetryCollection(col2)
        file.removeFromPoetryCollection(col1)
        try modelContext.save()
        
        XCTAssertEqual(try poetryCollectionLinkCount(for: file), 1)
        XCTAssertFalse(file.isInPoetryCollection(col1))
        XCTAssertTrue(file.isInPoetryCollection(col2))
    }

    func testRemoveFromPoetryCollectionKeepsFolderRelationship() throws {
        let project = Project(name: "Poetry Project", type: .poetry)
        let folder = Folder(name: "Draft", project: project)
        let collection = PoetryCollection(name: "Sonnets")
        collection.project = project
        let file = TextFile(name: "Poem 1", initialContent: "", parentFolder: folder)

        modelContext.insert(project)
        modelContext.insert(folder)
        modelContext.insert(collection)
        modelContext.insert(file)

        file.addToPoetryCollection(collection)
        file.removeFromPoetryCollection(collection)
        try modelContext.save()

        XCTAssertEqual(file.parentFolder?.id, folder.id, "Removing collection membership must not detach the file from its folder")
        XCTAssertFalse(file.isInPoetryCollection(collection))
    }
    
    func testRemoveFromAllPoetryCollections() throws {
        let col1 = PoetryCollection(name: "Sonnets")
        let col2 = PoetryCollection(name: "Love Poems")
        modelContext.insert(col1)
        modelContext.insert(col2)
        
        let file = TextFile(name: "Poem 1", initialContent: "")
        modelContext.insert(file)
        
        file.addToPoetryCollection(col1)
        file.addToPoetryCollection(col2)
        file.removeFromAllPoetryCollections()
        try modelContext.save()
        
        XCTAssertEqual(try poetryCollectionLinkCount(for: file), 0)
        XCTAssertFalse(file.isInPoetryCollection(col1))
        XCTAssertFalse(file.isInPoetryCollection(col2))
    }
    
    func testPoetryCollectionBackwardsCompat() throws {
        let collection = PoetryCollection(name: "Sonnets")
        modelContext.insert(collection)
        
        let file = TextFile(name: "Poem 1", initialContent: "")
        modelContext.insert(file)
        
        // Set via backwards-compat property
        file.poetryCollection = collection
        try modelContext.save()
        
        XCTAssertEqual(try poetryCollectionIDs(for: file), [collection.id])
        XCTAssertEqual(try poetryCollectionLinkCount(for: file), 1)
        
        // Clear via backwards-compat property
        file.poetryCollection = nil
        XCTAssertEqual(try poetryCollectionLinkCount(for: file), 0)
    }

    func testDeleteFilesPermanentlyPersistsWithoutWriteCoalescer() throws {
        let project = Project(name: "Test Project", type: .prose)
        let folder = Folder(name: "Draft", project: project)
        let file = TextFile(name: "Draft 1", initialContent: "Hello", parentFolder: folder)

        modelContext.insert(project)
        modelContext.insert(folder)
        modelContext.insert(file)
        try modelContext.save()

        WriteCoalescer.shared = nil

        let service = FileMoveService(modelContext: modelContext)
        try service.deleteFilesPermanently([file])

        XCTAssertFalse(folder.textFiles?.contains(where: { $0.id == file.id }) ?? false,
                   "Permanent delete should remove the file from the folder relationship immediately")

        let freshContext = ModelContext(modelContainer)
        let fileID = file.id
        let descriptor = FetchDescriptor<TextFile>(predicate: #Predicate { $0.id == fileID })
        let remaining = try freshContext.fetch(descriptor)

        XCTAssertTrue(remaining.isEmpty, "Permanent delete should be saved immediately")
    }

    func testDeleteFilesPermanentlyUpdatesFolderFileCountWhenRefetched() throws {
        // Mirrors user flow: file exists in folder -> delete forever -> navigate back to folder.
        let project = Project(name: "Count Refresh Project", type: .prose)
        let folder = Folder(name: "Prose", project: project)
        let firstFile = TextFile(name: "First", initialContent: "A", parentFolder: folder)
        let secondFile = TextFile(name: "Second", initialContent: "B", parentFolder: folder)

        modelContext.insert(project)
        modelContext.insert(folder)
        modelContext.insert(firstFile)
        modelContext.insert(secondFile)
        try modelContext.save()

        XCTAssertEqual(folder.textFiles?.count, 2, "Setup should start with two files")

        WriteCoalescer.shared = nil
        let service = FileMoveService(modelContext: modelContext)
        try service.deleteFilesPermanently([firstFile])

        // Immediate in-memory relationship update (the row count source).
        XCTAssertEqual(folder.textFiles?.count, 1, "Folder relationship count should update immediately after permanent delete")

        // Simulate navigating back to folder list: read from a fresh context.
        let freshContext = ModelContext(modelContainer)
        let folderID = folder.id
        let folderDescriptor = FetchDescriptor<Folder>(predicate: #Predicate { $0.id == folderID })
        let fetchedFolder = try XCTUnwrap(freshContext.fetch(folderDescriptor).first)

        XCTAssertEqual(fetchedFolder.textFiles?.count, 1, "Refetched folder should show updated file count after permanent delete")
    }
    
    // MARK: - TextFile ↔ ProseSection
    
    func testAddToSection() throws {
        let section = ProseSection(name: "Introduction")
        modelContext.insert(section)
        
        let file = TextFile(name: "File 1", initialContent: "")
        modelContext.insert(file)
        
        file.addToSection(section)
        try modelContext.save()
        
        XCTAssertTrue(file.isInSection(section))
        XCTAssertEqual(file.sections?.count, 1)
    }
    
    func testAddToSection_NoDuplicate() throws {
        let section = ProseSection(name: "Introduction")
        modelContext.insert(section)
        
        let file = TextFile(name: "File 1", initialContent: "")
        modelContext.insert(file)
        
        file.addToSection(section)
        file.addToSection(section) // duplicate
        try modelContext.save()
        
        XCTAssertEqual(file.sections?.count, 1)
    }
    
    func testMultipleSections() throws {
        let sec1 = ProseSection(name: "Introduction")
        let sec2 = ProseSection(name: "Conclusion")
        modelContext.insert(sec1)
        modelContext.insert(sec2)
        
        let file = TextFile(name: "File 1", initialContent: "")
        modelContext.insert(file)
        
        file.addToSection(sec1)
        file.addToSection(sec2)
        try modelContext.save()
        
        XCTAssertEqual(file.sections?.count, 2)
        XCTAssertTrue(file.isInSection(sec1))
        XCTAssertTrue(file.isInSection(sec2))
    }
    
    func testRemoveFromSection() throws {
        let sec1 = ProseSection(name: "Introduction")
        let sec2 = ProseSection(name: "Conclusion")
        modelContext.insert(sec1)
        modelContext.insert(sec2)
        
        let file = TextFile(name: "File 1", initialContent: "")
        modelContext.insert(file)
        
        file.addToSection(sec1)
        file.addToSection(sec2)
        file.removeFromSection(sec1)
        try modelContext.save()
        
        XCTAssertFalse(file.isInSection(sec1))
        XCTAssertTrue(file.isInSection(sec2))
    }
    
    func testRemoveFromAllSections() throws {
        let sec1 = ProseSection(name: "Introduction")
        let sec2 = ProseSection(name: "Conclusion")
        modelContext.insert(sec1)
        modelContext.insert(sec2)
        
        let file = TextFile(name: "File 1", initialContent: "")
        modelContext.insert(file)
        
        file.addToSection(sec1)
        file.addToSection(sec2)
        file.removeFromAllSections()
        try modelContext.save()
        
        XCTAssertEqual(file.sections?.count ?? 0, 0)
    }
    
    func testSectionBackwardsCompat() throws {
        let section = ProseSection(name: "Introduction")
        modelContext.insert(section)
        
        let file = TextFile(name: "File 1", initialContent: "")
        modelContext.insert(file)
        
        file.section = section
        try modelContext.save()
        
        XCTAssertEqual(file.section?.id, section.id)
        XCTAssertEqual(file.sections?.count, 1)
        
        file.section = nil
        XCTAssertEqual(file.sections?.count ?? 0, 0)
    }
    
    // MARK: - StoryScene ↔ Chapter
    
    func testAddToChapter() throws {
        let chapter = Chapter(name: "Chapter 1")
        modelContext.insert(chapter)
        
        let scene = StoryScene(name: "Scene 1")
        modelContext.insert(scene)
        
        scene.addToChapter(chapter)
        try modelContext.save()
        
        XCTAssertTrue(scene.isInChapter(chapter))
        XCTAssertEqual(scene.chapters?.count, 1)
    }
    
    func testAddToChapter_NoDuplicate() throws {
        let chapter = Chapter(name: "Chapter 1")
        modelContext.insert(chapter)
        
        let scene = StoryScene(name: "Scene 1")
        modelContext.insert(scene)
        
        scene.addToChapter(chapter)
        scene.addToChapter(chapter) // duplicate
        try modelContext.save()
        
        XCTAssertEqual(scene.chapters?.count, 1)
    }
    
    func testMultipleChapters() throws {
        let ch1 = Chapter(name: "Chapter 1")
        let ch2 = Chapter(name: "Chapter 2")
        modelContext.insert(ch1)
        modelContext.insert(ch2)
        
        let scene = StoryScene(name: "Recurring Scene")
        modelContext.insert(scene)
        
        scene.addToChapter(ch1)
        scene.addToChapter(ch2)
        try modelContext.save()
        
        XCTAssertEqual(scene.chapters?.count, 2)
        XCTAssertTrue(scene.isInChapter(ch1))
        XCTAssertTrue(scene.isInChapter(ch2))
    }
    
    func testRemoveFromChapter() throws {
        let ch1 = Chapter(name: "Chapter 1")
        let ch2 = Chapter(name: "Chapter 2")
        modelContext.insert(ch1)
        modelContext.insert(ch2)
        
        let scene = StoryScene(name: "Scene 1")
        modelContext.insert(scene)
        
        scene.addToChapter(ch1)
        scene.addToChapter(ch2)
        scene.removeFromChapter(ch1)
        try modelContext.save()
        
        XCTAssertFalse(scene.isInChapter(ch1))
        XCTAssertTrue(scene.isInChapter(ch2))
    }
    
    func testRemoveFromAllChapters() throws {
        let ch1 = Chapter(name: "Chapter 1")
        let ch2 = Chapter(name: "Chapter 2")
        modelContext.insert(ch1)
        modelContext.insert(ch2)
        
        let scene = StoryScene(name: "Scene 1")
        modelContext.insert(scene)
        
        scene.addToChapter(ch1)
        scene.addToChapter(ch2)
        scene.removeFromAllChapters()
        try modelContext.save()
        
        XCTAssertEqual(scene.chapters?.count ?? 0, 0)
    }
    
    func testChapterBackwardsCompat() throws {
        let chapter = Chapter(name: "Chapter 1")
        modelContext.insert(chapter)
        
        let scene = StoryScene(name: "Scene 1")
        modelContext.insert(scene)
        
        scene.chapter = chapter
        try modelContext.save()
        
        XCTAssertEqual(scene.chapter?.id, chapter.id)
        XCTAssertEqual(scene.chapters?.count, 1)
        
        scene.chapter = nil
        XCTAssertEqual(scene.chapters?.count ?? 0, 0)
    }
    
    // MARK: - StoryScene ↔ Act
    
    func testAddToAct() throws {
        let act = Act(name: "Act 1")
        modelContext.insert(act)
        
        let scene = StoryScene(name: "Scene 1")
        modelContext.insert(scene)
        
        scene.addToAct(act)
        try modelContext.save()
        
        XCTAssertTrue(scene.isInAct(act))
        XCTAssertEqual(scene.acts?.count, 1)
    }
    
    func testAddToAct_NoDuplicate() throws {
        let act = Act(name: "Act 1")
        modelContext.insert(act)
        
        let scene = StoryScene(name: "Scene 1")
        modelContext.insert(scene)
        
        scene.addToAct(act)
        scene.addToAct(act) // duplicate
        try modelContext.save()
        
        XCTAssertEqual(scene.acts?.count, 1)
    }
    
    func testMultipleActs() throws {
        let act1 = Act(name: "Act 1")
        let act2 = Act(name: "Act 2")
        modelContext.insert(act1)
        modelContext.insert(act2)
        
        let scene = StoryScene(name: "Recurring Scene")
        modelContext.insert(scene)
        
        scene.addToAct(act1)
        scene.addToAct(act2)
        try modelContext.save()
        
        XCTAssertEqual(scene.acts?.count, 2)
        XCTAssertTrue(scene.isInAct(act1))
        XCTAssertTrue(scene.isInAct(act2))
    }
    
    func testRemoveFromAct() throws {
        let act1 = Act(name: "Act 1")
        let act2 = Act(name: "Act 2")
        modelContext.insert(act1)
        modelContext.insert(act2)
        
        let scene = StoryScene(name: "Scene 1")
        modelContext.insert(scene)
        
        scene.addToAct(act1)
        scene.addToAct(act2)
        scene.removeFromAct(act1)
        try modelContext.save()
        
        XCTAssertFalse(scene.isInAct(act1))
        XCTAssertTrue(scene.isInAct(act2))
    }
    
    func testRemoveFromAllActs() throws {
        let act1 = Act(name: "Act 1")
        let act2 = Act(name: "Act 2")
        modelContext.insert(act1)
        modelContext.insert(act2)
        
        let scene = StoryScene(name: "Scene 1")
        modelContext.insert(scene)
        
        scene.addToAct(act1)
        scene.addToAct(act2)
        scene.removeFromAllActs()
        try modelContext.save()
        
        XCTAssertEqual(scene.acts?.count ?? 0, 0)
    }
    
    func testActBackwardsCompat() throws {
        let act = Act(name: "Act 1")
        modelContext.insert(act)
        
        let scene = StoryScene(name: "Scene 1")
        modelContext.insert(scene)
        
        scene.act = act
        try modelContext.save()
        
        XCTAssertEqual(scene.act?.id, act.id)
        XCTAssertEqual(scene.acts?.count, 1)
        
        scene.act = nil
        XCTAssertEqual(scene.acts?.count ?? 0, 0)
    }
    
    // MARK: - StoryScene ↔ Book
    
    func testAddToBook() throws {
        let book = Book(name: "Book 1")
        modelContext.insert(book)
        
        let scene = StoryScene(name: "Episode 1")
        modelContext.insert(scene)
        
        scene.addToBook(book)
        try modelContext.save()
        
        XCTAssertTrue(scene.isInBook(book))
        XCTAssertEqual(scene.books?.count, 1)
    }
    
    func testAddToBook_NoDuplicate() throws {
        let book = Book(name: "Book 1")
        modelContext.insert(book)
        
        let scene = StoryScene(name: "Episode 1")
        modelContext.insert(scene)
        
        scene.addToBook(book)
        scene.addToBook(book) // duplicate
        try modelContext.save()
        
        XCTAssertEqual(scene.books?.count, 1)
    }
    
    func testMultipleBooks() throws {
        let book1 = Book(name: "Book 1")
        let book2 = Book(name: "Book 2")
        modelContext.insert(book1)
        modelContext.insert(book2)
        
        let scene = StoryScene(name: "Cross-Book Episode")
        modelContext.insert(scene)
        
        scene.addToBook(book1)
        scene.addToBook(book2)
        try modelContext.save()
        
        XCTAssertEqual(scene.books?.count, 2)
        XCTAssertTrue(scene.isInBook(book1))
        XCTAssertTrue(scene.isInBook(book2))
    }
    
    func testRemoveFromBook() throws {
        let book1 = Book(name: "Book 1")
        let book2 = Book(name: "Book 2")
        modelContext.insert(book1)
        modelContext.insert(book2)
        
        let scene = StoryScene(name: "Episode 1")
        modelContext.insert(scene)
        
        scene.addToBook(book1)
        scene.addToBook(book2)
        scene.removeFromBook(book1)
        try modelContext.save()
        
        XCTAssertFalse(scene.isInBook(book1))
        XCTAssertTrue(scene.isInBook(book2))
    }
    
    func testRemoveFromAllBooks() throws {
        let book1 = Book(name: "Book 1")
        let book2 = Book(name: "Book 2")
        modelContext.insert(book1)
        modelContext.insert(book2)
        
        let scene = StoryScene(name: "Episode 1")
        modelContext.insert(scene)
        
        scene.addToBook(book1)
        scene.addToBook(book2)
        scene.removeFromAllBooks()
        try modelContext.save()
        
        XCTAssertEqual(scene.books?.count ?? 0, 0)
    }
    
    func testBookBackwardsCompat() throws {
        let book = Book(name: "Book 1")
        modelContext.insert(book)
        
        let scene = StoryScene(name: "Episode 1")
        modelContext.insert(scene)
        
        scene.book = book
        try modelContext.save()
        
        XCTAssertEqual(scene.book?.id, book.id)
        XCTAssertEqual(scene.books?.count, 1)
        
        scene.book = nil
        XCTAssertEqual(scene.books?.count ?? 0, 0)
    }
    
    // MARK: - ContainerDescriptor Tests
    
    func testContainerDescriptorContains() throws {
        let file = TextFile(name: "Poem 1", initialContent: "")
        modelContext.insert(file)
        try modelContext.save()
        
        let descriptor = ContainerDescriptor<TextFile>(
            id: UUID(),
            name: "Test Collection",
            memberIDs: Set([file.id]),
            addItem: { _ in },
            removeItem: { _ in }
        )
        
        XCTAssertTrue(descriptor.contains(file))
    }
    
    func testContainerDescriptorNotContains() throws {
        let file = TextFile(name: "Poem 1", initialContent: "")
        modelContext.insert(file)
        try modelContext.save()
        
        let descriptor = ContainerDescriptor<TextFile>(
            id: UUID(),
            name: "Empty Collection",
            memberIDs: Set<UUID>(),
            addItem: { _ in },
            removeItem: { _ in }
        )
        
        XCTAssertFalse(descriptor.contains(file))
    }
    
    func testContainerDescriptorCallbacks() throws {
        let collection = PoetryCollection(name: "Sonnets")
        modelContext.insert(collection)
        
        let file = TextFile(name: "Poem 1", initialContent: "")
        modelContext.insert(file)
        try modelContext.save()
        
        let descriptor = ContainerDescriptor<TextFile>(
            id: collection.id,
            name: "Sonnets",
            memberIDs: Set<UUID>(),
            addItem: { f in f.addToPoetryCollection(collection) },
            removeItem: { f in f.removeFromPoetryCollection(collection) }
        )
        
        descriptor.addItem(file)
        XCTAssertTrue(file.isInPoetryCollection(collection))
        
        descriptor.removeItem(file)
        XCTAssertFalse(file.isInPoetryCollection(collection))
    }
    
    // MARK: - ContainerAssignable Protocol Tests
    
    func testTextFileDisplayName() throws {
        let file = TextFile(name: "My Poem", initialContent: "")
        modelContext.insert(file)
        
        XCTAssertEqual(file.displayName, "My Poem")
    }
    
    func testStorySceneDisplayName() throws {
        let scene = StoryScene(name: "Opening Scene")
        modelContext.insert(scene)
        
        XCTAssertEqual(scene.displayName, "Opening Scene")
    }
    
    func testStorySceneDisplayName_NilName() throws {
        let scene = StoryScene()
        modelContext.insert(scene)
        
        // Should return localized "Untitled" fallback
        XCTAssertFalse(scene.displayName.isEmpty)
    }
    
    // MARK: - Cross-Container Multi-Membership Tests
    
    func testFileInMultipleCollectionsPreservedOnSingleRemoval() throws {
        let col1 = PoetryCollection(name: "Collection A")
        let col2 = PoetryCollection(name: "Collection B")
        let col3 = PoetryCollection(name: "Collection C")
        modelContext.insert(col1)
        modelContext.insert(col2)
        modelContext.insert(col3)
        
        let file = TextFile(name: "Poem 1", initialContent: "")
        modelContext.insert(file)
        
        file.addToPoetryCollection(col1)
        file.addToPoetryCollection(col2)
        file.addToPoetryCollection(col3)
        try modelContext.save()
        
        XCTAssertEqual(try poetryCollectionLinkCount(for: file), 3)
        
        // Remove from one — others should remain
        file.removeFromPoetryCollection(col2)
        try modelContext.save()
        
        XCTAssertEqual(try poetryCollectionLinkCount(for: file), 2)
        XCTAssertTrue(file.isInPoetryCollection(col1))
        XCTAssertFalse(file.isInPoetryCollection(col2))
        XCTAssertTrue(file.isInPoetryCollection(col3))
    }
    
    func testSceneInMultipleChaptersPreservedOnSingleRemoval() throws {
        let ch1 = Chapter(name: "Chapter 1")
        let ch2 = Chapter(name: "Chapter 2")
        let ch3 = Chapter(name: "Chapter 3")
        modelContext.insert(ch1)
        modelContext.insert(ch2)
        modelContext.insert(ch3)
        
        let scene = StoryScene(name: "Flashback Scene")
        modelContext.insert(scene)
        
        scene.addToChapter(ch1)
        scene.addToChapter(ch2)
        scene.addToChapter(ch3)
        try modelContext.save()
        
        XCTAssertEqual(scene.chapters?.count, 3)
        
        scene.removeFromChapter(ch2)
        try modelContext.save()
        
        XCTAssertEqual(scene.chapters?.count, 2)
        XCTAssertTrue(scene.isInChapter(ch1))
        XCTAssertFalse(scene.isInChapter(ch2))
        XCTAssertTrue(scene.isInChapter(ch3))
    }
    
    // MARK: - Backwards-Compat Setter Replaces All
    
    func testBackwardsCompatSetterReplacesMultiple_PoetryCollection() throws {
        let col1 = PoetryCollection(name: "A")
        let col2 = PoetryCollection(name: "B")
        let col3 = PoetryCollection(name: "C")
        modelContext.insert(col1)
        modelContext.insert(col2)
        modelContext.insert(col3)
        
        let file = TextFile(name: "Poem", initialContent: "")
        modelContext.insert(file)
        
        file.addToPoetryCollection(col1)
        file.addToPoetryCollection(col2)
        XCTAssertEqual(try poetryCollectionLinkCount(for: file), 2)
        
        // Setting via backwards-compat property should replace with single
        file.poetryCollection = col3
        XCTAssertEqual(try poetryCollectionLinkCount(for: file), 1)
        XCTAssertEqual(try poetryCollectionIDs(for: file), [col3.id])
    }
    
    func testBackwardsCompatSetterReplacesMultiple_Chapter() throws {
        let ch1 = Chapter(name: "Ch 1")
        let ch2 = Chapter(name: "Ch 2")
        let ch3 = Chapter(name: "Ch 3")
        modelContext.insert(ch1)
        modelContext.insert(ch2)
        modelContext.insert(ch3)
        
        let scene = StoryScene(name: "Scene")
        modelContext.insert(scene)
        
        scene.addToChapter(ch1)
        scene.addToChapter(ch2)
        XCTAssertEqual(scene.chapters?.count, 2)
        
        scene.chapter = ch3
        XCTAssertEqual(scene.chapters?.count, 1)
        XCTAssertEqual(scene.chapter?.id, ch3.id)
    }
    
    // MARK: - WSP Export Data Structure Tests (v1.3)
    
    func testWSPTextFileData_ArrayFields() throws {
        let sectionId1 = UUID().uuidString
        let sectionId2 = UUID().uuidString
        let collectionId1 = UUID().uuidString
        
        var fileData = WSPTextFileData()
        fileData.id = UUID().uuidString
        fileData.name = "Test File"
        fileData.sectionId = sectionId1  // Legacy single field
        fileData.sectionIds = [sectionId1, sectionId2]  // v1.3 array field
        fileData.poetryCollectionId = collectionId1  // Legacy single field
        fileData.poetryCollectionIds = [collectionId1]  // v1.3 array field
        
        // Encode and decode
        let encoder = JSONEncoder()
        let data = try encoder.encode(fileData)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WSPTextFileData.self, from: data)
        
        // Verify both legacy and array fields survive round-trip
        XCTAssertEqual(decoded.sectionId, sectionId1)
        XCTAssertEqual(decoded.sectionIds?.count, 2)
        XCTAssertEqual(decoded.sectionIds?[0], sectionId1)
        XCTAssertEqual(decoded.sectionIds?[1], sectionId2)
        XCTAssertEqual(decoded.poetryCollectionId, collectionId1)
        XCTAssertEqual(decoded.poetryCollectionIds?.count, 1)
    }
    
    func testWSPTextFileData_NilArrayFields() throws {
        // Simulate legacy v1.2 data with no array fields
        var fileData = WSPTextFileData()
        fileData.id = UUID().uuidString
        fileData.name = "Legacy File"
        fileData.sectionId = UUID().uuidString
        // sectionIds left nil
        // poetryCollectionIds left nil
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(fileData)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WSPTextFileData.self, from: data)
        
        XCTAssertNotNil(decoded.sectionId)
        XCTAssertNil(decoded.sectionIds)
        XCTAssertNil(decoded.poetryCollectionIds)
    }
    
    func testWSPStorySceneData_ArrayFields() throws {
        let chapterId1 = UUID().uuidString
        let chapterId2 = UUID().uuidString
        let actId = UUID().uuidString
        let bookId1 = UUID().uuidString
        let bookId2 = UUID().uuidString
        
        var sceneData = WSPStorySceneData()
        sceneData.id = UUID().uuidString
        sceneData.name = "Test Scene"
        sceneData.chapterId = chapterId1
        sceneData.chapterIds = [chapterId1, chapterId2]
        sceneData.actId = actId
        sceneData.actIds = [actId]
        sceneData.bookId = bookId1
        sceneData.bookIds = [bookId1, bookId2]
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(sceneData)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WSPStorySceneData.self, from: data)
        
        XCTAssertEqual(decoded.chapterId, chapterId1)
        XCTAssertEqual(decoded.chapterIds?.count, 2)
        XCTAssertEqual(decoded.actId, actId)
        XCTAssertEqual(decoded.actIds?.count, 1)
        XCTAssertEqual(decoded.bookId, bookId1)
        XCTAssertEqual(decoded.bookIds?.count, 2)
    }
    
    func testWSPStorySceneData_NilArrayFields() throws {
        // Simulate legacy v1.2 data — only single fields set
        var sceneData = WSPStorySceneData()
        sceneData.id = UUID().uuidString
        sceneData.name = "Legacy Scene"
        sceneData.chapterId = UUID().uuidString
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(sceneData)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WSPStorySceneData.self, from: data)
        
        XCTAssertNotNil(decoded.chapterId)
        XCTAssertNil(decoded.chapterIds)
        XCTAssertNil(decoded.actIds)
        XCTAssertNil(decoded.bookIds)
    }
    
    func testWSPExportData_FormatVersion() throws {
        var exportData = WSPExportData()
        exportData.formatVersion = "1.3"
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(exportData)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WSPExportData.self, from: data)
        
        XCTAssertEqual(decoded.formatVersion, "1.3")
    }
}
