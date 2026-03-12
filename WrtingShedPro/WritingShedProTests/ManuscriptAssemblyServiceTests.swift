import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class ManuscriptAssemblyServiceTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var assemblyService: ManuscriptAssemblyService!
    
    override func setUp() {
        super.setUp()
        // Create in-memory model container for testing
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
        assemblyService = ManuscriptAssemblyService(context: modelContext)
    }
    
    override func tearDown() {
        assemblyService = nil
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Source Folder Name Tests
    
    func testGetBodySourceFolderNameForPoetry() {
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        
        let folderName = assemblyService.getBodySourceFolderName(for: project)
        XCTAssertEqual(folderName, "Poems")
    }
    
    func testGetBodySourceFolderNameForShortFiction() {
        let project = Project(name: "Test Short Fiction", type: .fiction)
        project.fictionClass = .shortFiction
        modelContext.insert(project)
        
        let folderName = assemblyService.getBodySourceFolderName(for: project)
        XCTAssertEqual(folderName, "Scenes")
    }
    
    func testGetBodySourceFolderNameForNovel() {
        let project = Project(name: "Test Novel", type: .fiction)
        project.fictionClass = .novel
        modelContext.insert(project)
        
        let folderName = assemblyService.getBodySourceFolderName(for: project)
        XCTAssertEqual(folderName, "Chapters")
    }
    
    func testGetBodySourceFolderNameForDrama() {
        let project = Project(name: "Test Drama", type: .drama)
        modelContext.insert(project)
        
        let folderName = assemblyService.getBodySourceFolderName(for: project)
        XCTAssertEqual(folderName, "Scenes")
    }
    
    func testGetBodySourceFolderNameForProse() {
        let project = Project(name: "Test Prose", type: .prose)
        modelContext.insert(project)
        
        let folderName = assemblyService.getBodySourceFolderName(for: project)
        XCTAssertEqual(folderName, "Prose")
    }
    
    // MARK: - Section Tests
    
    func testGetSectionsReturnsEmptyForNewProject() {
        let project = Project(name: "Test", type: .poetry)
        modelContext.insert(project)
        
        let sections = assemblyService.getSections(for: project)
        XCTAssertTrue(sections.isEmpty, "New project should have no sections")
    }
    
    func testGetBodySectionsForPoetryWithFiles() {
        // Create poetry project with Poems folder and files
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        
        let poemsFolder = Folder(name: "Poems", project: project)
        modelContext.insert(poemsFolder)
        project.folders = [poemsFolder]
        
        // Add text files
        let file1 = TextFile()
        file1.name = "Poem 1"
        file1.parentFolder = poemsFolder
        file1.includedInManuscript = true
        modelContext.insert(file1)
        
        let file2 = TextFile()
        file2.name = "Poem 2"
        file2.parentFolder = poemsFolder
        file2.includedInManuscript = true
        modelContext.insert(file2)
        
        poemsFolder.textFiles = [file1, file2]
        
        let sections = assemblyService.getBodySections(for: project)
        
        XCTAssertEqual(sections.count, 1, "Should have one body section")
        XCTAssertEqual(sections.first?.sectionType, .body)
        XCTAssertEqual(sections.first?.files.count, 2, "Section should have 2 files")
    }
    
    func testExcludedFilesAreNotIncluded() {
        // Create poetry project with Poems folder
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        
        let poemsFolder = Folder(name: "Poems", project: project)
        modelContext.insert(poemsFolder)
        project.folders = [poemsFolder]
        
        // Add included file
        let includedFile = TextFile()
        includedFile.name = "Included Poem"
        includedFile.parentFolder = poemsFolder
        includedFile.includedInManuscript = true
        modelContext.insert(includedFile)
        
        // Add excluded file
        let excludedFile = TextFile()
        excludedFile.name = "Excluded Poem"
        excludedFile.parentFolder = poemsFolder
        excludedFile.includedInManuscript = false
        modelContext.insert(excludedFile)
        
        poemsFolder.textFiles = [includedFile, excludedFile]
        
        let sections = assemblyService.getBodySections(for: project)
        
        XCTAssertEqual(sections.first?.files.count, 1, "Only included file should be in section")
        XCTAssertEqual(sections.first?.files.first?.name, "Included Poem")
    }
    
    // MARK: - Manuscript Subfolders Tests
    
    func testManuscriptSubfoldersAreCreated() {
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        
        // Create Manuscript folder
        let manuscriptFolder = Folder(name: "Manuscript", project: project)
        modelContext.insert(manuscriptFolder)
        project.folders = [manuscriptFolder]
        
        // Create subfolders
        ProjectTemplateService.createManuscriptSubfolders(in: manuscriptFolder, context: modelContext)
        
        // Save context to ensure relationships are populated
        try? modelContext.save()
        
        let subfolders = manuscriptFolder.folders ?? []
        let subfolderNames = Set(subfolders.compactMap { $0.name })
        
        XCTAssertEqual(subfolders.count, 3, "Should have 3 subfolders")
        XCTAssertTrue(subfolderNames.contains("Front Matter"))
        // Body folder name is now project-type specific (e.g., "All Poems" for poetry)
        XCTAssertTrue(subfolderNames.contains("Body Matter"), "Poetry project should have 'Body Matter' body folder")
        XCTAssertTrue(subfolderNames.contains("Back Matter"))
    }
    
    // MARK: - ManuscriptSettings Tests
    
    func testDefaultManuscriptSettings() {
        let settings = ManuscriptSettings()
        
        XCTAssertEqual(settings.sectionBreakStyle, .pageBreak)
        XCTAssertEqual(settings.footnoteNumbering, .perFile)
        XCTAssertTrue(settings.includeSectionHeadings)
        XCTAssertTrue(settings.includeFileTitles)
    }
    
    func testManuscriptSettingsCodable() throws {
        var settings = ManuscriptSettings()
        settings.sectionBreakStyle = .sectionMark
        settings.footnoteNumbering = .perSection
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ManuscriptSettings.self, from: data)
        
        XCTAssertEqual(decoded.sectionBreakStyle, .sectionMark)
        XCTAssertEqual(decoded.footnoteNumbering, .perSection)
    }
    
    // MARK: - ManuscriptSection Tests
    
    func testManuscriptSectionEquality() {
        let id = UUID()
        let section1 = ManuscriptSection(id: id, title: "Test", sectionType: .body)
        let section2 = ManuscriptSection(id: id, title: "Different", sectionType: .frontMatter)
        
        XCTAssertEqual(section1, section2, "Sections with same ID should be equal")
    }
    
    func testSectionTypeSortOrder() {
        XCTAssertLessThan(ManuscriptSection.SectionType.frontMatter.sortOrder, ManuscriptSection.SectionType.body.sortOrder)
        XCTAssertLessThan(ManuscriptSection.SectionType.body.sortOrder, ManuscriptSection.SectionType.backMatter.sortOrder)
    }
    
    // MARK: - ManuscriptContent Tests
    
    func testManuscriptContentWordCount() {
        let text = "Hello world this is a test"
        let content = ManuscriptContent(
            attributedString: NSAttributedString(string: text)
        )
        
        XCTAssertEqual(content.wordCount, 6)
    }
    
    func testManuscriptContentCharacterCount() {
        let text = "Hello world"
        let content = ManuscriptContent(
            attributedString: NSAttributedString(string: text)
        )
        
        // Character count excludes whitespace
        XCTAssertEqual(content.characterCount, 10) // "Helloworld" without space
    }
    
    // MARK: - TextFile includedInManuscript Tests
    
    func testTextFileIncludedInManuscriptDefaultsToTrue() {
        let file = TextFile()
        XCTAssertTrue(file.includedInManuscript, "New files should be included by default")
    }
    
    func testTextFileIncludedInManuscriptCanBeToggled() {
        let file = TextFile()
        file.includedInManuscript = false
        XCTAssertFalse(file.includedInManuscript)
        
        file.includedInManuscript = true
        XCTAssertTrue(file.includedInManuscript)
    }
    
    // MARK: - Back Matter Integration Tests (Feature 029)
    
    func testAssembleContentWithBackMatterNoReferences() async throws {
        // Create a project with basic content but no references
        let project = Project(name: "Test Project", type: .prose)
        modelContext.insert(project)
        
        // Create Prose folder with a file
        let folder = Folder(name: "Prose", project: project)
        modelContext.insert(folder)
        project.folders = [folder]
        
        let file = TextFile(name: "Chapter 1", parentFolder: folder)
        file.includedInManuscript = true
        let version = Version(content: "Test content")
        version.textFile = file
        file.versions = [version]
        modelContext.insert(file)
        modelContext.insert(version)
        folder.textFiles = [file]
        
        try modelContext.save()
        
        var options = ExportOptions()
        options.includeNotes = true
        options.includeGlossary = true
        options.includeBibliography = true
        options.includeIndex = true
        
        let content = try await assemblyService.assembleContentWithBackMatter(for: project, options: options)
        
        // Should have content but no back matter (no reference entries exist)
        XCTAssertGreaterThan(content.attributedString.length, 0)
    }
    
    func testAssembleContentWithBackMatterDisabled() async throws {
        // Create a project
        let project = Project(name: "Test Project", type: .prose)
        modelContext.insert(project)
        
        // Create Prose folder with a file
        let folder = Folder(name: "Prose", project: project)
        modelContext.insert(folder)
        project.folders = [folder]
        
        let file = TextFile(name: "Chapter 1", parentFolder: folder)
        file.includedInManuscript = true
        let version = Version(content: "Test content")
        version.textFile = file
        file.versions = [version]
        modelContext.insert(file)
        modelContext.insert(version)
        folder.textFiles = [file]
        
        try modelContext.save()
        
        // Disable all back matter
        var options = ExportOptions()
        options.includeNotes = false
        options.includeGlossary = false
        options.includeBibliography = false
        options.includeIndex = false
        
        let content = try await assemblyService.assembleContentWithBackMatter(for: project, options: options)
        
        // Should return content without back matter
        XCTAssertGreaterThan(content.attributedString.length, 0)
    }
}

// MARK: - ManuscriptContent.buildFileCollectionMap Tests

final class ManuscriptContentFileCollectionMapTests: XCTestCase {

    // MARK: - Helpers

    private func makeFile() -> TextFile {
        TextFile(name: "File")
    }

    private func makeBodySection(title: String, files: [TextFile]) -> ManuscriptSection {
        ManuscriptSection(title: title, sectionType: .body, files: files)
    }

    private func makeFrontMatterSection(title: String, files: [TextFile]) -> ManuscriptSection {
        ManuscriptSection(title: title, sectionType: .frontMatter, files: files)
    }

    private func makeBackMatterSection(title: String, files: [TextFile]) -> ManuscriptSection {
        ManuscriptSection(title: title, sectionType: .backMatter, files: files)
    }

    // MARK: - Empty / No-Op Cases

    func testEmptySectionsProducesEmptyMap() {
        var content = ManuscriptContent()
        content.buildFileCollectionMap()
        XCTAssertTrue(content.fileCollectionMap.isEmpty)
    }

    func testOnlyFrontMatterSectionProducesEmptyMap() {
        let file = makeFile()
        let section = makeFrontMatterSection(title: "Preface", files: [file])
        var content = ManuscriptContent(
            sections: [section],
            fileOffsets: [file.id: 0]
        )
        content.buildFileCollectionMap()
        XCTAssertTrue(content.fileCollectionMap.isEmpty)
    }

    func testOnlyBackMatterSectionProducesEmptyMap() {
        let file = makeFile()
        let section = makeBackMatterSection(title: "Index", files: [file])
        var content = ManuscriptContent(
            sections: [section],
            fileOffsets: [file.id: 0]
        )
        content.buildFileCollectionMap()
        XCTAssertTrue(content.fileCollectionMap.isEmpty)
    }

    func testBodyFileWithNoOffsetIsSkipped() {
        let file = makeFile()
        let section = makeBodySection(title: "Poems", files: [file])
        // file.id intentionally missing from fileOffsets
        var content = ManuscriptContent(
            sections: [section],
            fileOffsets: [:]
        )
        content.buildFileCollectionMap()
        XCTAssertTrue(content.fileCollectionMap.isEmpty)
    }

    // MARK: - Section Title Fallback

    func testBodyFileFallsBackToSectionTitle() {
        let file = makeFile()
        let section = makeBodySection(title: "Chapter One", files: [file])
        var content = ManuscriptContent(
            sections: [section],
            fileOffsets: [file.id: 100]
        )
        content.buildFileCollectionMap()
        XCTAssertEqual(content.fileCollectionMap.count, 1)
        XCTAssertEqual(content.fileCollectionMap[0].offset, 100)
        XCTAssertEqual(content.fileCollectionMap[0].collectionName, "Chapter One")
    }

    func testMultipleFilesInOneBodySection() {
        let file1 = makeFile()
        let file2 = makeFile()
        let section = makeBodySection(title: "Act I", files: [file1, file2])
        var content = ManuscriptContent(
            sections: [section],
            fileOffsets: [file1.id: 200, file2.id: 50]
        )
        content.buildFileCollectionMap()
        XCTAssertEqual(content.fileCollectionMap.count, 2)
        XCTAssertTrue(content.fileCollectionMap.allSatisfy { $0.collectionName == "Act I" })
    }

    // MARK: - Sorting

    func testMapIsSortedByOffsetAscending() {
        let file1 = makeFile()
        let file2 = makeFile()
        let file3 = makeFile()
        let section = makeBodySection(title: "Poems", files: [file1, file2, file3])
        var content = ManuscriptContent(
            sections: [section],
            fileOffsets: [file1.id: 300, file2.id: 100, file3.id: 200]
        )
        content.buildFileCollectionMap()
        XCTAssertEqual(content.fileCollectionMap.count, 3)
        XCTAssertEqual(content.fileCollectionMap[0].offset, 100)
        XCTAssertEqual(content.fileCollectionMap[1].offset, 200)
        XCTAssertEqual(content.fileCollectionMap[2].offset, 300)
    }

    func testOffsetsAcrossMultipleBodySections() {
        let file1 = makeFile()
        let file2 = makeFile()
        let section1 = makeBodySection(title: "Part One", files: [file1])
        let section2 = makeBodySection(title: "Part Two", files: [file2])
        var content = ManuscriptContent(
            sections: [section1, section2],
            fileOffsets: [file1.id: 500, file2.id: 50]
        )
        content.buildFileCollectionMap()
        XCTAssertEqual(content.fileCollectionMap.count, 2)
        // Sorted: file2 (50) first, file1 (500) second
        XCTAssertEqual(content.fileCollectionMap[0].offset, 50)
        XCTAssertEqual(content.fileCollectionMap[0].collectionName, "Part Two")
        XCTAssertEqual(content.fileCollectionMap[1].offset, 500)
        XCTAssertEqual(content.fileCollectionMap[1].collectionName, "Part One")
    }

    // MARK: - Mixed Section Types

    func testFrontAndBackMatterExcludedBodyIncluded() {
        let frontFile = makeFile()
        let bodyFile  = makeFile()
        let backFile  = makeFile()
        let front = makeFrontMatterSection(title: "Preface", files: [frontFile])
        let body  = makeBodySection(title: "Main", files: [bodyFile])
        let back  = makeBackMatterSection(title: "Notes", files: [backFile])
        var content = ManuscriptContent(
            sections: [front, body, back],
            fileOffsets: [frontFile.id: 0, bodyFile.id: 100, backFile.id: 200]
        )
        content.buildFileCollectionMap()
        XCTAssertEqual(content.fileCollectionMap.count, 1)
        XCTAssertEqual(content.fileCollectionMap[0].offset, 100)
        XCTAssertEqual(content.fileCollectionMap[0].collectionName, "Main")
    }

    // MARK: - Idempotency

    func testBuildingTwiceProducesSameResult() {
        let file = makeFile()
        let section = makeBodySection(title: "Sonnets", files: [file])
        var content = ManuscriptContent(
            sections: [section],
            fileOffsets: [file.id: 42]
        )
        content.buildFileCollectionMap()
        let firstOffsets = content.fileCollectionMap.map(\.offset)
        let firstNames   = content.fileCollectionMap.map(\.collectionName)
        content.buildFileCollectionMap()
        XCTAssertEqual(content.fileCollectionMap.map(\.offset), firstOffsets)
        XCTAssertEqual(content.fileCollectionMap.map(\.collectionName), firstNames)
    }
}