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
            Chapter.self, StoryScene.self
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
        
        let subfolders = manuscriptFolder.folders ?? []
        let subfolderNames = Set(subfolders.compactMap { $0.name })
        
        XCTAssertEqual(subfolders.count, 3, "Should have 3 subfolders")
        XCTAssertTrue(subfolderNames.contains("Front Matter"))
        XCTAssertTrue(subfolderNames.contains("Body"))
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
}
