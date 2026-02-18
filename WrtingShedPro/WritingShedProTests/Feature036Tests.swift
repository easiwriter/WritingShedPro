import XCTest
import SwiftData
@testable import Writing_Shed_Pro


/// Tests for Feature 036: Project Folder Revamp
/// Covers model CRUD, Body Matter assembly, and migration service
final class Feature036Tests: XCTestCase {
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
            PoetryCollection.self, Book.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)
        
        // Reset migration flag for each test
        UserDefaults.standard.removeObject(forKey: "hasRunFeature036Migration")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "hasRunFeature036Migration")
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createProject(name: String, type: ProjectType, fictionClass: FictionClass? = nil) -> Project {
        let project = Project(name: name, type: type)
        if let fc = fictionClass {
            project.fictionClass = fc
        }
        modelContext.insert(project)
        return project
    }
    
    private func createFolder(name: String, project: Project? = nil, parent: Folder? = nil, userOrder: Int? = nil) -> Folder {
        let folder = Folder(name: name, project: project, parentFolder: parent, userOrder: userOrder)
        modelContext.insert(folder)
        return folder
    }
    
    private func createTextFile(name: String, folder: Folder, includedInManuscript: Bool = true) -> TextFile {
        let file = TextFile(name: name, parentFolder: folder)
        file.includedInManuscript = includedInManuscript
        modelContext.insert(file)
        if folder.textFiles == nil {
            folder.textFiles = [file]
        } else {
            folder.textFiles?.append(file)
        }
        return file
    }
    
    // MARK: - Task 9.1: Model Tests — PoetryCollection
    
    func testPoetryCollectionCRUD() throws {
        let project = createProject(name: "Poetry Test", type: .poetry)
        
        let collection = PoetryCollection(name: "Sonnets", synopsis: "14-line poems", userOrder: 0)
        collection.project = project
        modelContext.insert(collection)
        try modelContext.save()
        
        XCTAssertEqual(collection.name, "Sonnets")
        XCTAssertEqual(collection.synopsis, "14-line poems")
        XCTAssertEqual(collection.userOrder, 0)
        XCTAssertFalse(collection.isInBodyMatter)
        XCTAssertNil(collection.bodyMatterOrder)
        XCTAssertNotNil(collection.project)
    }
    
    func testPoetryCollectionTextFileRelationship() throws {
        let project = createProject(name: "Poetry Test", type: .poetry)
        let poemsFolder = createFolder(name: "Poems", project: project)
        
        let collection = PoetryCollection(name: "My Collection", userOrder: 0)
        collection.project = project
        modelContext.insert(collection)
        
        let file1 = createTextFile(name: "Poem 1", folder: poemsFolder)
        let file2 = createTextFile(name: "Poem 2", folder: poemsFolder)
        file1.poetryCollection = collection
        file2.poetryCollection = collection
        
        try modelContext.save()
        
        XCTAssertEqual(collection.textFiles?.count, 2)
        XCTAssertEqual(file1.poetryCollection?.id, collection.id)
    }
    
    func testPoetryCollectionDeleteNullifiesTextFiles() throws {
        let project = createProject(name: "Poetry Test", type: .poetry)
        let poemsFolder = createFolder(name: "Poems", project: project)
        
        let collection = PoetryCollection(name: "Temp Collection", userOrder: 0)
        collection.project = project
        modelContext.insert(collection)
        
        let file = createTextFile(name: "Poem", folder: poemsFolder)
        file.poetryCollection = collection
        try modelContext.save()
        
        modelContext.delete(collection)
        try modelContext.save()
        
        // File should still exist but collection reference should be nil
        XCTAssertNil(file.poetryCollection)
    }
    
    func testPoetryCollectionBodyMatterTracking() throws {
        let collection = PoetryCollection(name: "Test", userOrder: 0)
        modelContext.insert(collection)
        
        XCTAssertFalse(collection.isInBodyMatter)
        XCTAssertNil(collection.bodyMatterOrder)
        
        collection.isInBodyMatter = true
        collection.bodyMatterOrder = 3
        try modelContext.save()
        
        XCTAssertTrue(collection.isInBodyMatter)
        XCTAssertEqual(collection.bodyMatterOrder, 3)
    }
    
    // MARK: - Task 9.1: Model Tests — Book
    
    func testBookCRUD() throws {
        let project = createProject(name: "Verse Novel", type: .fiction, fictionClass: .verseNovel)
        
        let book = Book(name: "Book One", synopsis: "The beginning", userOrder: 0)
        book.project = project
        modelContext.insert(book)
        try modelContext.save()
        
        XCTAssertEqual(book.name, "Book One")
        XCTAssertEqual(book.synopsis, "The beginning")
        XCTAssertEqual(book.userOrder, 0)
        XCTAssertFalse(book.isInBodyMatter)
    }
    
    func testBookSceneRelationship() throws {
        let project = createProject(name: "Verse Novel", type: .fiction, fictionClass: .verseNovel)
        
        let book = Book(name: "Book One", userOrder: 0)
        book.project = project
        modelContext.insert(book)
        
        let scene = StoryScene()
        scene.name = "Episode 1"
        scene.project = project
        scene.book = book
        modelContext.insert(scene)
        
        try modelContext.save()
        
        XCTAssertEqual(book.scenes?.count, 1)
        XCTAssertEqual(scene.book?.id, book.id)
    }
    
    func testBookDeleteNullifiesScenes() throws {
        let project = createProject(name: "Verse Novel", type: .fiction, fictionClass: .verseNovel)
        
        let book = Book(name: "Book One", userOrder: 0)
        book.project = project
        modelContext.insert(book)
        
        let scene = StoryScene()
        scene.name = "Episode 1"
        scene.project = project
        scene.book = book
        modelContext.insert(scene)
        try modelContext.save()
        
        modelContext.delete(book)
        try modelContext.save()
        
        XCTAssertNil(scene.book)
    }
    
    // MARK: - Task 9.1: Model Tests — Body Matter on existing types
    
    func testChapterBodyMatterProperties() {
        let chapter = Chapter(name: "Ch 1", userOrder: 0)
        modelContext.insert(chapter)
        
        XCTAssertFalse(chapter.isInBodyMatter)
        XCTAssertNil(chapter.bodyMatterOrder)
        
        chapter.isInBodyMatter = true
        chapter.bodyMatterOrder = 5
        
        XCTAssertTrue(chapter.isInBodyMatter)
        XCTAssertEqual(chapter.bodyMatterOrder, 5)
    }
    
    func testActBodyMatterProperties() {
        let act = Act(name: "Act 1", userOrder: 0)
        modelContext.insert(act)
        
        XCTAssertFalse(act.isInBodyMatter)
        act.isInBodyMatter = true
        act.bodyMatterOrder = 0
        XCTAssertTrue(act.isInBodyMatter)
    }
    
    func testProseSectionBodyMatterProperties() {
        let section = ProseSection(name: "Section 1", userOrder: 0)
        modelContext.insert(section)
        
        XCTAssertFalse(section.isInBodyMatter)
        section.isInBodyMatter = true
        section.bodyMatterOrder = 2
        XCTAssertTrue(section.isInBodyMatter)
        XCTAssertEqual(section.bodyMatterOrder, 2)
    }
    
    func testStorySceneBodyMatterProperties() {
        let scene = StoryScene()
        scene.name = "Scene 1"
        modelContext.insert(scene)
        
        XCTAssertFalse(scene.isInBodyMatter)
        scene.isInBodyMatter = true
        scene.bodyMatterOrder = 1
        XCTAssertTrue(scene.isInBodyMatter)
    }
    
    // MARK: - Task 9.2: ManuscriptAssemblyService — Body Matter Tests
    
    func testPoetryBodyMatterAssembly() throws {
        let project = createProject(name: "Poetry", type: .poetry)
        let poemsFolder = createFolder(name: "Poems", project: project)
        project.folders = [poemsFolder]
        
        // Create two collections with poems
        let col1 = PoetryCollection(name: "Sonnets", userOrder: 0)
        col1.project = project
        col1.isInBodyMatter = true
        col1.bodyMatterOrder = 1  // Second in body matter
        modelContext.insert(col1)
        
        let col2 = PoetryCollection(name: "Haikus", userOrder: 1)
        col2.project = project
        col2.isInBodyMatter = true
        col2.bodyMatterOrder = 0  // First in body matter
        modelContext.insert(col2)
        
        let poem1 = createTextFile(name: "Sonnet 1", folder: poemsFolder)
        poem1.poetryCollection = col1
        
        let poem2 = createTextFile(name: "Haiku 1", folder: poemsFolder)
        poem2.poetryCollection = col2
        
        try modelContext.save()
        
        let service = ManuscriptAssemblyService(context: modelContext)
        let sections = service.getBodySections(for: project)
        
        // Body Matter ordering should produce Haikus first (order 0), then Sonnets (order 1)
        XCTAssertEqual(sections.count, 2)
        if sections.count == 2 {
            XCTAssertEqual(sections[0].title, "Haikus")
            XCTAssertEqual(sections[1].title, "Sonnets")
        }
    }
    
    func testProseBodyMatterAssembly() throws {
        let project = createProject(name: "Prose", type: .prose)
        let proseFolder = createFolder(name: "Prose", project: project)
        project.folders = [proseFolder]
        
        let sec1 = ProseSection(name: "Introduction", userOrder: 0)
        sec1.project = project
        sec1.isInBodyMatter = true
        sec1.bodyMatterOrder = 0
        modelContext.insert(sec1)
        
        let sec2 = ProseSection(name: "Chapter One", userOrder: 1)
        sec2.project = project
        sec2.isInBodyMatter = true
        sec2.bodyMatterOrder = 1
        modelContext.insert(sec2)
        
        let file1 = createTextFile(name: "Intro Text", folder: proseFolder)
        file1.section = sec1
        
        let file2 = createTextFile(name: "Chapter Text", folder: proseFolder)
        file2.section = sec2
        
        try modelContext.save()
        
        let service = ManuscriptAssemblyService(context: modelContext)
        let sections = service.getBodySections(for: project)
        
        XCTAssertEqual(sections.count, 2)
        if sections.count == 2 {
            XCTAssertEqual(sections[0].title, "Introduction")
            XCTAssertEqual(sections[1].title, "Chapter One")
        }
    }
    
    func testNovelBodyMatterAssembly() throws {
        let project = createProject(name: "Novel", type: .fiction, fictionClass: .novel)
        let chaptersFolder = createFolder(name: "Chapters", project: project)
        project.folders = [chaptersFolder]
        
        let ch1 = Chapter(name: "Chapter 1", userOrder: 0)
        ch1.project = project
        ch1.isInBodyMatter = true
        ch1.bodyMatterOrder = 0
        modelContext.insert(ch1)
        
        // Scene in chapter
        let scene = StoryScene()
        scene.name = "Opening"
        scene.project = project
        scene.chapter = ch1
        modelContext.insert(scene)
        
        let sceneFile = TextFile(name: "Opening Scene", parentFolder: chaptersFolder)
        sceneFile.includedInManuscript = true
        sceneFile.scene = scene
        scene.textFile = sceneFile
        modelContext.insert(sceneFile)
        
        try modelContext.save()
        
        let service = ManuscriptAssemblyService(context: modelContext)
        let sections = service.getBodySections(for: project)
        
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.title, "Chapter 1")
    }
    
    func testShortFictionBodyMatterAssembly() throws {
        let project = createProject(name: "Short Fiction", type: .fiction, fictionClass: .shortFiction)
        let scenesFolder = createFolder(name: "Scenes", project: project)
        project.folders = [scenesFolder]
        
        let scene1 = StoryScene()
        scene1.name = "Scene A"
        scene1.project = project
        scene1.isInBodyMatter = true
        scene1.bodyMatterOrder = 0
        modelContext.insert(scene1)
        
        let file1 = TextFile(name: "Scene A Text", parentFolder: scenesFolder)
        file1.includedInManuscript = true
        file1.scene = scene1
        scene1.textFile = file1
        modelContext.insert(file1)
        
        try modelContext.save()
        
        let service = ManuscriptAssemblyService(context: modelContext)
        let sections = service.getBodySections(for: project)
        
        XCTAssertGreaterThanOrEqual(sections.count, 1)
    }
    
    func testDramaBodyMatterAssembly() throws {
        let project = createProject(name: "Drama", type: .drama)
        let scenesFolder = createFolder(name: "Scenes", project: project)
        project.folders = [scenesFolder]
        
        let act = Act(name: "Act I", userOrder: 0)
        act.project = project
        act.isInBodyMatter = true
        act.bodyMatterOrder = 0
        modelContext.insert(act)
        
        let scene = StoryScene()
        scene.name = "Opening Scene"
        scene.project = project
        scene.act = act
        modelContext.insert(scene)
        
        let file = TextFile(name: "Scene Text", parentFolder: scenesFolder)
        file.includedInManuscript = true
        file.scene = scene
        scene.textFile = file
        modelContext.insert(file)
        
        try modelContext.save()
        
        let service = ManuscriptAssemblyService(context: modelContext)
        let sections = service.getBodySections(for: project)
        
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.title, "Act I")
    }
    
    func testEmptyBodyMatterFallsBackToFolderLogic() throws {
        // When no items have isInBodyMatter=true, should fall back to folder-based logic
        let project = createProject(name: "Poetry", type: .poetry)
        let poemsFolder = createFolder(name: "Poems", project: project)
        project.folders = [poemsFolder]
        
        let file = createTextFile(name: "A Poem", folder: poemsFolder)
        _ = file
        
        try modelContext.save()
        
        let service = ManuscriptAssemblyService(context: modelContext)
        let sections = service.getBodySections(for: project)
        
        // Should still produce sections via fallback
        XCTAssertGreaterThanOrEqual(sections.count, 1)
    }
    
    func testBodyMatterOrderingIsRespected() throws {
        let project = createProject(name: "Novel", type: .fiction, fictionClass: .novel)
        let chaptersFolder = createFolder(name: "Chapters", project: project)
        project.folders = [chaptersFolder]
        
        // Create chapters in reverse body matter order, each with a scene+file
        let ch3 = Chapter(name: "Chapter 3", userOrder: 2)
        ch3.project = project
        ch3.isInBodyMatter = true
        ch3.bodyMatterOrder = 0  // First in body matter
        modelContext.insert(ch3)
        let s3 = StoryScene(); s3.name = "S3"; s3.project = project; s3.chapter = ch3; modelContext.insert(s3)
        let f3 = TextFile(name: "F3", parentFolder: chaptersFolder); f3.includedInManuscript = true; f3.scene = s3; s3.textFile = f3; modelContext.insert(f3)
        
        let ch1 = Chapter(name: "Chapter 1", userOrder: 0)
        ch1.project = project
        ch1.isInBodyMatter = true
        ch1.bodyMatterOrder = 2  // Last in body matter
        modelContext.insert(ch1)
        let s1 = StoryScene(); s1.name = "S1"; s1.project = project; s1.chapter = ch1; modelContext.insert(s1)
        let f1 = TextFile(name: "F1", parentFolder: chaptersFolder); f1.includedInManuscript = true; f1.scene = s1; s1.textFile = f1; modelContext.insert(f1)
        
        let ch2 = Chapter(name: "Chapter 2", userOrder: 1)
        ch2.project = project
        ch2.isInBodyMatter = true
        ch2.bodyMatterOrder = 1  // Middle
        modelContext.insert(ch2)
        let s2 = StoryScene(); s2.name = "S2"; s2.project = project; s2.chapter = ch2; modelContext.insert(s2)
        let f2 = TextFile(name: "F2", parentFolder: chaptersFolder); f2.includedInManuscript = true; f2.scene = s2; s2.textFile = f2; modelContext.insert(f2)
        
        try modelContext.save()
        
        let service = ManuscriptAssemblyService(context: modelContext)
        let sections = service.getBodySections(for: project)
        
        XCTAssertEqual(sections.count, 3)
        if sections.count == 3 {
            XCTAssertEqual(sections[0].title, "Chapter 3")
            XCTAssertEqual(sections[1].title, "Chapter 2")
            XCTAssertEqual(sections[2].title, "Chapter 1")
        }
    }
    
    func testOnlyBodyMatterItemsAreIncluded() throws {
        let project = createProject(name: "Novel", type: .fiction, fictionClass: .novel)
        let chaptersFolder = createFolder(name: "Chapters", project: project)
        project.folders = [chaptersFolder]
        
        let inBodyMatter = Chapter(name: "Included Chapter", userOrder: 0)
        inBodyMatter.project = project
        inBodyMatter.isInBodyMatter = true
        inBodyMatter.bodyMatterOrder = 0
        modelContext.insert(inBodyMatter)
        let s1 = StoryScene(); s1.name = "S1"; s1.project = project; s1.chapter = inBodyMatter; modelContext.insert(s1)
        let f1 = TextFile(name: "F1", parentFolder: chaptersFolder); f1.includedInManuscript = true; f1.scene = s1; s1.textFile = f1; modelContext.insert(f1)
        
        let notInBodyMatter = Chapter(name: "Excluded Chapter", userOrder: 1)
        notInBodyMatter.project = project
        notInBodyMatter.isInBodyMatter = false
        modelContext.insert(notInBodyMatter)
        let s2 = StoryScene(); s2.name = "S2"; s2.project = project; s2.chapter = notInBodyMatter; modelContext.insert(s2)
        let f2 = TextFile(name: "F2", parentFolder: chaptersFolder); f2.includedInManuscript = true; f2.scene = s2; s2.textFile = f2; modelContext.insert(f2)
        
        try modelContext.save()
        
        let service = ManuscriptAssemblyService(context: modelContext)
        let sections = service.getBodySections(for: project)
        
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.title, "Included Chapter")
    }
    
    // MARK: - Task 9.3: Migration Tests
    
    func testMigrationRenamesAllPoemsToBodyMatter() throws {
        let project = createProject(name: "Poetry", type: .poetry)
        let manuscript = createFolder(name: "Manuscript", project: project)
        project.folders = [manuscript]
        
        let bodyFolder = createFolder(name: "All Poems", parent: manuscript)
        manuscript.folders = [bodyFolder]
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        XCTAssertEqual(bodyFolder.name, "Body Matter")
    }
    
    func testMigrationRenamesAllChaptersToBodyMatter() throws {
        let project = createProject(name: "Novel", type: .fiction, fictionClass: .novel)
        let manuscript = createFolder(name: "Manuscript", project: project)
        project.folders = [manuscript]
        
        let bodyFolder = createFolder(name: "All Chapters", parent: manuscript)
        manuscript.folders = [bodyFolder]
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        XCTAssertEqual(bodyFolder.name, "Body Matter")
    }
    
    func testMigrationRenamesAllSectionsToBodyMatter() throws {
        let project = createProject(name: "Prose", type: .prose)
        let manuscript = createFolder(name: "Manuscript", project: project)
        project.folders = [manuscript]
        
        let bodyFolder = createFolder(name: "All Sections", parent: manuscript)
        manuscript.folders = [bodyFolder]
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        XCTAssertEqual(bodyFolder.name, "Body Matter")
    }
    
    func testMigrationRenamesAllActsToBodyMatter() throws {
        let project = createProject(name: "Drama", type: .drama)
        let manuscript = createFolder(name: "Manuscript", project: project)
        project.folders = [manuscript]
        
        let bodyFolder = createFolder(name: "All Acts", parent: manuscript)
        manuscript.folders = [bodyFolder]
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        XCTAssertEqual(bodyFolder.name, "Body Matter")
    }
    
    func testMigrationPopulatesBodyMatterForProseSections() throws {
        let project = createProject(name: "Prose", type: .prose)
        
        let sec1 = ProseSection(name: "Part 1", userOrder: 0)
        sec1.project = project
        modelContext.insert(sec1)
        
        let sec2 = ProseSection(name: "Part 2", userOrder: 1)
        sec2.project = project
        modelContext.insert(sec2)
        
        try modelContext.save()
        
        XCTAssertFalse(sec1.isInBodyMatter)
        XCTAssertFalse(sec2.isInBodyMatter)
        
        MigrationService.migrateFeature036(context: modelContext)
        
        XCTAssertTrue(sec1.isInBodyMatter)
        XCTAssertTrue(sec2.isInBodyMatter)
        XCTAssertEqual(sec1.bodyMatterOrder, 0)
        XCTAssertEqual(sec2.bodyMatterOrder, 1)
    }
    
    func testMigrationPopulatesBodyMatterForChapters() throws {
        let project = createProject(name: "Novel", type: .fiction, fictionClass: .novel)
        
        let ch1 = Chapter(name: "Ch 1", userOrder: 0)
        ch1.project = project
        modelContext.insert(ch1)
        
        let ch2 = Chapter(name: "Ch 2", userOrder: 1)
        ch2.project = project
        modelContext.insert(ch2)
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        XCTAssertTrue(ch1.isInBodyMatter)
        XCTAssertTrue(ch2.isInBodyMatter)
        XCTAssertEqual(ch1.bodyMatterOrder, 0)
        XCTAssertEqual(ch2.bodyMatterOrder, 1)
    }
    
    func testMigrationPopulatesBodyMatterForActs() throws {
        let project = createProject(name: "Drama", type: .drama)
        
        let act1 = Act(name: "Act I", userOrder: 0)
        act1.project = project
        modelContext.insert(act1)
        
        let act2 = Act(name: "Act II", userOrder: 1)
        act2.project = project
        modelContext.insert(act2)
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        XCTAssertTrue(act1.isInBodyMatter)
        XCTAssertTrue(act2.isInBodyMatter)
        XCTAssertEqual(act1.bodyMatterOrder, 0)
        XCTAssertEqual(act2.bodyMatterOrder, 1)
    }
    
    func testMigrationPopulatesBodyMatterForShortFictionScenes() throws {
        let project = createProject(name: "Short Fiction", type: .fiction, fictionClass: .shortFiction)
        
        let scene1 = StoryScene()
        scene1.name = "Opening"
        scene1.userOrder = 0
        scene1.project = project
        modelContext.insert(scene1)
        
        let scene2 = StoryScene()
        scene2.name = "Climax"
        scene2.userOrder = 1
        scene2.project = project
        modelContext.insert(scene2)
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        XCTAssertTrue(scene1.isInBodyMatter)
        XCTAssertTrue(scene2.isInBodyMatter)
        XCTAssertEqual(scene1.bodyMatterOrder, 0)
        XCTAssertEqual(scene2.bodyMatterOrder, 1)
    }
    
    func testMigrationCreatesDefaultPoetryCollection() throws {
        let project = createProject(name: "Poetry", type: .poetry)
        let poemsFolder = createFolder(name: "Poems", project: project)
        project.folders = [poemsFolder]
        
        let poem1 = createTextFile(name: "Poem A", folder: poemsFolder)
        let poem2 = createTextFile(name: "Poem B", folder: poemsFolder)
        _ = poem1
        _ = poem2
        
        try modelContext.save()
        
        XCTAssertTrue(project.poetryCollections?.isEmpty ?? true)
        
        MigrationService.migrateFeature036(context: modelContext)
        
        // Should create a default collection with both poems
        let collections = project.poetryCollections ?? []
        XCTAssertEqual(collections.count, 1)
        XCTAssertTrue(collections.first?.isInBodyMatter ?? false)
        XCTAssertEqual(collections.first?.textFiles?.count, 2)
    }
    
    func testMigrationMigratesOldSubmissionCollections() throws {
        let project = createProject(name: "Poetry", type: .poetry)
        let poemsFolder = createFolder(name: "Poems", project: project)
        project.folders = [poemsFolder]
        
        let poem1 = createTextFile(name: "Poem 1", folder: poemsFolder)
        let poem2 = createTextFile(name: "Poem 2", folder: poemsFolder)
        
        // Create old-style collection submission
        let oldCollection = Submission(project: project)
        oldCollection.name = "My Chapbook"
        oldCollection.isCollection = true
        oldCollection.collectionDescription = "A chapbook of poems"
        oldCollection.userOrder = 0
        modelContext.insert(oldCollection)
        
        let sf1 = SubmittedFile(submission: oldCollection, textFile: poem1)
        modelContext.insert(sf1)
        let sf2 = SubmittedFile(submission: oldCollection, textFile: poem2)
        modelContext.insert(sf2)
        oldCollection.submittedFiles = [sf1, sf2]
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        // Should have migrated to PoetryCollection
        let collections = project.poetryCollections ?? []
        XCTAssertEqual(collections.count, 1)
        XCTAssertEqual(collections.first?.name, "My Chapbook")
        XCTAssertEqual(collections.first?.synopsis, "A chapbook of poems")
        XCTAssertTrue(collections.first?.isInBodyMatter ?? false)
        
        // Poems should be assigned to the new collection
        XCTAssertNotNil(poem1.poetryCollection)
        XCTAssertNotNil(poem2.poetryCollection)
    }
    
    func testMigrationRemovesCollectionsFolderFromNonPoetry() throws {
        let project = createProject(name: "Prose", type: .prose)
        let collections = createFolder(name: "Collections", project: project, userOrder: 2)
        project.folders = [collections]
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        // Collections folder should be deleted
        let foldersNamed = project.folders?.filter { $0.name == "Collections" }
        XCTAssertTrue(foldersNamed?.isEmpty ?? true)
    }
    
    func testMigrationKeepsCollectionsFolderForPoetry() throws {
        let project = createProject(name: "Poetry", type: .poetry)
        let collections = createFolder(name: "Collections", project: project, userOrder: 3)
        let poemsFolder = createFolder(name: "Poems", project: project, userOrder: 1)
        project.folders = [collections, poemsFolder]
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        let foldersNamed = project.folders?.filter { $0.name == "Collections" }
        XCTAssertEqual(foldersNamed?.count, 1)
    }
    
    func testMigrationVerseNovelChaptersToBooks() throws {
        let project = createProject(name: "Verse Novel", type: .fiction, fictionClass: .verseNovel)
        
        let ch1 = Chapter(name: "Book One", synopsis: "The beginning", userOrder: 0)
        ch1.project = project
        modelContext.insert(ch1)
        
        let scene = StoryScene()
        scene.name = "Episode 1"
        scene.project = project
        scene.chapter = ch1
        modelContext.insert(scene)
        
        try modelContext.save()
        
        XCTAssertTrue(project.books?.isEmpty ?? true)
        
        MigrationService.migrateFeature036(context: modelContext)
        
        let books = project.books ?? []
        XCTAssertEqual(books.count, 1)
        XCTAssertEqual(books.first?.name, "Book One")
        XCTAssertEqual(books.first?.synopsis, "The beginning")
        XCTAssertTrue(books.first?.isInBodyMatter ?? false)
        
        // Scene should be assigned to new book
        XCTAssertNotNil(scene.book)
        XCTAssertEqual(scene.book?.name, "Book One")
    }
    
    func testMigrationIsIdempotent() throws {
        let project = createProject(name: "Prose", type: .prose)
        let manuscript = createFolder(name: "Manuscript", project: project)
        project.folders = [manuscript]
        let bodyFolder = createFolder(name: "All Sections", parent: manuscript)
        manuscript.folders = [bodyFolder]
        
        let sec = ProseSection(name: "Part 1", userOrder: 0)
        sec.project = project
        modelContext.insert(sec)
        
        try modelContext.save()
        
        // Run migration once
        MigrationService.migrateFeature036(context: modelContext)
        
        XCTAssertEqual(bodyFolder.name, "Body Matter")
        XCTAssertTrue(sec.isInBodyMatter)
        XCTAssertEqual(sec.bodyMatterOrder, 0)
        
        // Reset flag and run again
        UserDefaults.standard.removeObject(forKey: "hasRunFeature036Migration")
        MigrationService.migrateFeature036(context: modelContext)
        
        // Should not change anything — already renamed, already populated
        XCTAssertEqual(bodyFolder.name, "Body Matter")
        XCTAssertTrue(sec.isInBodyMatter)
        XCTAssertEqual(sec.bodyMatterOrder, 0)
    }
    
    func testMigrationSetsUserDefaultsFlag() throws {
        let project = createProject(name: "Test", type: .prose)
        modelContext.insert(project)
        try modelContext.save()
        
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasRunFeature036Migration"))
        
        MigrationService.migrateFeature036(context: modelContext)
        
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasRunFeature036Migration"))
    }
    
    func testMigrationIsIdempotentEvenWithFlagPreSet() throws {
        // Migration no longer checks UserDefaults before running — it's idempotent by design
        // so that newly synced CloudKit projects still get migrated.
        let project = createProject(name: "Prose", type: .prose)
        
        let sec = ProseSection(name: "Part 1", userOrder: 0)
        sec.project = project
        modelContext.insert(sec)
        
        try modelContext.save()
        
        // Set flag before running — migration should still run (idempotent)
        UserDefaults.standard.set(true, forKey: "hasRunFeature036Migration")
        
        MigrationService.migrateFeature036(context: modelContext)
        
        // Migration runs regardless of flag — body matter should be populated
        XCTAssertTrue(sec.isInBodyMatter)
        XCTAssertEqual(sec.bodyMatterOrder, 0)
    }
    
    func testMigrationSkipsExistingPoetryCollections() throws {
        let project = createProject(name: "Poetry", type: .poetry)
        
        // Pre-existing poetry collection
        let existing = PoetryCollection(name: "Existing", userOrder: 0)
        existing.project = project
        existing.isInBodyMatter = true
        existing.bodyMatterOrder = 0
        modelContext.insert(existing)
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        // Should not create additional collections
        let collections = project.poetryCollections ?? []
        XCTAssertEqual(collections.count, 1)
        XCTAssertEqual(collections.first?.name, "Existing")
    }
    
    func testMigrationSkipsExistingBooks() throws {
        let project = createProject(name: "Verse Novel", type: .fiction, fictionClass: .verseNovel)
        
        let existing = Book(name: "Existing Book", userOrder: 0)
        existing.project = project
        existing.isInBodyMatter = true
        modelContext.insert(existing)
        
        // Also add a chapter (shouldn't be migrated since books exist)
        let chapter = Chapter(name: "Old Chapter", userOrder: 0)
        chapter.project = project
        modelContext.insert(chapter)
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        let books = project.books ?? []
        XCTAssertEqual(books.count, 1)
        XCTAssertEqual(books.first?.name, "Existing Book")
    }
    
    func testMigrationHandlesMultipleProjects() throws {
        let poetry = createProject(name: "Poetry", type: .poetry)
        let novel = createProject(name: "Novel", type: .fiction, fictionClass: .novel)
        let prose = createProject(name: "Prose", type: .prose)
        
        // Poetry: manuscript folder to rename
        let poetryManuscript = createFolder(name: "Manuscript", project: poetry)
        poetry.folders = [poetryManuscript]
        let poetryBody = createFolder(name: "All Poems", parent: poetryManuscript)
        poetryManuscript.folders = [poetryBody]
        
        // Novel: chapter to populate
        let ch = Chapter(name: "Ch 1", userOrder: 0)
        ch.project = novel
        modelContext.insert(ch)
        
        // Prose: section to populate
        let sec = ProseSection(name: "Part 1", userOrder: 0)
        sec.project = prose
        modelContext.insert(sec)
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        XCTAssertEqual(poetryBody.name, "Body Matter")
        XCTAssertTrue(ch.isInBodyMatter)
        XCTAssertTrue(sec.isInBodyMatter)
    }
    
    func testMigrationDoesNotDeleteChaptersForVerseNovel() throws {
        // CloudKit safety: old Chapter entities should NOT be deleted
        let project = createProject(name: "Verse Novel", type: .fiction, fictionClass: .verseNovel)
        
        let chapter = Chapter(name: "Old Chapter", userOrder: 0)
        chapter.project = project
        modelContext.insert(chapter)
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        // Chapter should still exist (CloudKit safety)
        let chapters = project.chapters ?? []
        XCTAssertEqual(chapters.count, 1)
    }
    
    // MARK: - Task 9.2: Verse Novel Body Matter Assembly
    
    func testVerseNovelBodyMatterAssembly() throws {
        let project = createProject(name: "Verse Novel", type: .fiction, fictionClass: .verseNovel)
        let scenesFolder = createFolder(name: "Scenes", project: project)
        project.folders = [scenesFolder]
        
        let book1 = Book(name: "Book One", userOrder: 0)
        book1.project = project
        book1.isInBodyMatter = true
        book1.bodyMatterOrder = 0
        modelContext.insert(book1)
        
        let book2 = Book(name: "Book Two", userOrder: 1)
        book2.project = project
        book2.isInBodyMatter = true
        book2.bodyMatterOrder = 1
        modelContext.insert(book2)
        
        // Episode in Book One
        let scene1 = StoryScene()
        scene1.name = "Episode 1"
        scene1.project = project
        scene1.book = book1
        scene1.userOrder = 0
        modelContext.insert(scene1)
        
        let file1 = TextFile(name: "Episode 1 Text", parentFolder: scenesFolder)
        file1.includedInManuscript = true
        file1.scene = scene1
        scene1.textFile = file1
        modelContext.insert(file1)
        
        // Episode in Book Two
        let scene2 = StoryScene()
        scene2.name = "Episode 2"
        scene2.project = project
        scene2.book = book2
        scene2.userOrder = 0
        modelContext.insert(scene2)
        
        let file2 = TextFile(name: "Episode 2 Text", parentFolder: scenesFolder)
        file2.includedInManuscript = true
        file2.scene = scene2
        scene2.textFile = file2
        modelContext.insert(file2)
        
        try modelContext.save()
        
        let service = ManuscriptAssemblyService(context: modelContext)
        let sections = service.getBodySections(for: project)
        
        XCTAssertEqual(sections.count, 2)
        if sections.count == 2 {
            XCTAssertEqual(sections[0].title, "Book One")
            XCTAssertEqual(sections[1].title, "Book Two")
            XCTAssertEqual(sections[0].files.count, 1)
            XCTAssertEqual(sections[1].files.count, 1)
        }
    }
    
    func testVerseNovelFallsBackToChapters() throws {
        // When no Book entities exist, verse novel should fall back to legacy Chapter entities
        let project = createProject(name: "Verse Novel", type: .fiction, fictionClass: .verseNovel)
        let scenesFolder = createFolder(name: "Scenes", project: project)
        project.folders = [scenesFolder]
        
        let chapter = Chapter(name: "Legacy Chapter", userOrder: 0)
        chapter.project = project
        modelContext.insert(chapter)
        
        let scene = StoryScene()
        scene.name = "Episode 1"
        scene.project = project
        scene.chapter = chapter
        modelContext.insert(scene)
        
        let file = TextFile(name: "Episode Text", parentFolder: scenesFolder)
        file.includedInManuscript = true
        file.scene = scene
        scene.textFile = file
        modelContext.insert(file)
        
        try modelContext.save()
        
        let service = ManuscriptAssemblyService(context: modelContext)
        let sections = service.getBodySections(for: project)
        
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.title, "Legacy Chapter")
    }
    
    // MARK: - Task 9.3: Additional Migration Rename Tests
    
    func testMigrationRenamesAllStoriesToBodyMatter() throws {
        let project = createProject(name: "Short Fiction", type: .fiction, fictionClass: .shortFiction)
        let manuscript = createFolder(name: "Manuscript", project: project)
        project.folders = [manuscript]
        
        let bodyFolder = createFolder(name: "All Stories", parent: manuscript)
        manuscript.folders = [bodyFolder]
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        XCTAssertEqual(bodyFolder.name, "Body Matter")
    }
    
    func testMigrationRenamesAllBooksToBodyMatter() throws {
        let project = createProject(name: "Verse Novel", type: .fiction, fictionClass: .verseNovel)
        let manuscript = createFolder(name: "Manuscript", project: project)
        project.folders = [manuscript]
        
        let bodyFolder = createFolder(name: "All Books", parent: manuscript)
        manuscript.folders = [bodyFolder]
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        XCTAssertEqual(bodyFolder.name, "Body Matter")
    }
    
    func testMigrationRenamesLegacyBodyToBodyMatter() throws {
        let project = createProject(name: "Poetry", type: .poetry)
        let manuscript = createFolder(name: "Manuscript", project: project)
        project.folders = [manuscript]
        
        let bodyFolder = createFolder(name: "Body", parent: manuscript)
        manuscript.folders = [bodyFolder]
        
        try modelContext.save()
        
        MigrationService.migrateFeature036(context: modelContext)
        
        XCTAssertEqual(bodyFolder.name, "Body Matter")
    }
    
    // MARK: - Task 9.3: Verse Novel Body Matter Population
    
    func testMigrationPopulatesBodyMatterForVerseNovelBooks() throws {
        let project = createProject(name: "Verse Novel", type: .fiction, fictionClass: .verseNovel)
        
        let book1 = Book(name: "Book One", userOrder: 0)
        book1.project = project
        modelContext.insert(book1)
        
        let book2 = Book(name: "Book Two", userOrder: 1)
        book2.project = project
        modelContext.insert(book2)
        
        try modelContext.save()
        
        XCTAssertFalse(book1.isInBodyMatter)
        XCTAssertFalse(book2.isInBodyMatter)
        
        MigrationService.migrateFeature036(context: modelContext)
        
        XCTAssertTrue(book1.isInBodyMatter)
        XCTAssertTrue(book2.isInBodyMatter)
        XCTAssertEqual(book1.bodyMatterOrder, 0)
        XCTAssertEqual(book2.bodyMatterOrder, 1)
    }
    
    // MARK: - BodyMatterItem Protocol Conformance
    
    func testAllBodyMatterItemTypesConform() {
        // Verify BodyMatterItem protocol properties on each type
        
        let collection = PoetryCollection(name: "Test", userOrder: 0)
        modelContext.insert(collection)
        XCTAssertFalse(collection.isInBodyMatter)
        collection.isInBodyMatter = true
        collection.bodyMatterOrder = 0
        XCTAssertTrue(collection.isInBodyMatter)
        
        let section = ProseSection(name: "Test", userOrder: 0)
        modelContext.insert(section)
        section.isInBodyMatter = true
        section.bodyMatterOrder = 1
        XCTAssertTrue(section.isInBodyMatter)
        
        let chapter = Chapter(name: "Test", userOrder: 0)
        modelContext.insert(chapter)
        chapter.isInBodyMatter = true
        chapter.bodyMatterOrder = 2
        XCTAssertTrue(chapter.isInBodyMatter)
        
        let scene = StoryScene()
        scene.name = "Test"
        modelContext.insert(scene)
        scene.isInBodyMatter = true
        scene.bodyMatterOrder = 3
        XCTAssertTrue(scene.isInBodyMatter)
        
        let book = Book(name: "Test", userOrder: 0)
        modelContext.insert(book)
        book.isInBodyMatter = true
        book.bodyMatterOrder = 4
        XCTAssertTrue(book.isInBodyMatter)
        
        let act = Act(name: "Test", userOrder: 0)
        modelContext.insert(act)
        act.isInBodyMatter = true
        act.bodyMatterOrder = 5
        XCTAssertTrue(act.isInBodyMatter)
    }
    
    // MARK: - Poetry Assembly Fallback (userOrder, no body matter flag)
    
    func testPoetryAssemblyFallsBackToUserOrder() throws {
        // When no collections have isInBodyMatter=true, should use all collections by userOrder
        let project = createProject(name: "Poetry", type: .poetry)
        let poemsFolder = createFolder(name: "Poems", project: project)
        project.folders = [poemsFolder]
        
        let col1 = PoetryCollection(name: "First Collection", userOrder: 0)
        col1.project = project
        // No isInBodyMatter set — defaults to false
        modelContext.insert(col1)
        
        let col2 = PoetryCollection(name: "Second Collection", userOrder: 1)
        col2.project = project
        modelContext.insert(col2)
        
        let poem1 = createTextFile(name: "Poem A", folder: poemsFolder)
        poem1.poetryCollection = col1
        
        let poem2 = createTextFile(name: "Poem B", folder: poemsFolder)
        poem2.poetryCollection = col2
        
        try modelContext.save()
        
        let service = ManuscriptAssemblyService(context: modelContext)
        let sections = service.getBodySections(for: project)
        
        XCTAssertEqual(sections.count, 2)
        if sections.count == 2 {
            XCTAssertEqual(sections[0].title, "First Collection")
            XCTAssertEqual(sections[1].title, "Second Collection")
        }
    }
    
    // MARK: - getBodyMatterFiles Convenience
    
    func testGetBodyMatterFilesReturnsAllFiles() throws {
        let project = createProject(name: "Novel", type: .fiction, fictionClass: .novel)
        let chaptersFolder = createFolder(name: "Chapters", project: project)
        project.folders = [chaptersFolder]
        
        let ch1 = Chapter(name: "Ch 1", userOrder: 0)
        ch1.project = project
        ch1.isInBodyMatter = true
        ch1.bodyMatterOrder = 0
        modelContext.insert(ch1)
        
        let s1 = StoryScene(); s1.name = "S1"; s1.project = project; s1.chapter = ch1; modelContext.insert(s1)
        let f1 = TextFile(name: "F1", parentFolder: chaptersFolder); f1.includedInManuscript = true; f1.scene = s1; s1.textFile = f1; modelContext.insert(f1)
        
        let ch2 = Chapter(name: "Ch 2", userOrder: 1)
        ch2.project = project
        ch2.isInBodyMatter = true
        ch2.bodyMatterOrder = 1
        modelContext.insert(ch2)
        
        let s2 = StoryScene(); s2.name = "S2"; s2.project = project; s2.chapter = ch2; modelContext.insert(s2)
        let f2 = TextFile(name: "F2", parentFolder: chaptersFolder); f2.includedInManuscript = true; f2.scene = s2; s2.textFile = f2; modelContext.insert(f2)
        
        try modelContext.save()
        
        let service = ManuscriptAssemblyService(context: modelContext)
        let files = service.getBodyMatterFiles(for: project)
        
        XCTAssertEqual(files.count, 2)
    }
}
