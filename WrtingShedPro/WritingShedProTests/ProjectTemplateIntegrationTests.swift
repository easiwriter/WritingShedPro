import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class ProjectTemplateIntegrationTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        let schema = Schema([Project.self, Folder.self, TextFile.self, Version.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    func testCreateDefaultFoldersCreatesCorrectStructure() throws {
        // Given: A new poetry project
        let newProject = Project(name: "My Poetry", type: .poetry)
        modelContext.insert(newProject)
        
        // When: Creating default folders
        ProjectTemplateService.createDefaultFolders(for: newProject, in: modelContext)
        try modelContext.save()
        
        // Then: Verify root folders are created (Manuscript has 3 subfolders)
        // Poetry: Poems, Collections, Submissions, Manuscript, Research, Magazines, Competitions, Other, Trash
        let allFolders = newProject.folders ?? []
        let rootFolders = allFolders.filter { $0.parentFolder == nil }
        XCTAssertEqual(rootFolders.count, 9, "Should create 9 root folders for poetry project")
        
        // Verify expected folder names exist
        let folderNames = Set(rootFolders.compactMap { $0.name })
        let expectedFolders: Set<String> = [
            "Poems", "Collections", "Submissions", "Manuscript",
            "Research", "Magazines", "Competitions", 
            "Other", "Trash"
        ]
        XCTAssertEqual(folderNames, expectedFolders, "Should have correct folder names")
    }
    
    func testCanNavigateToCreatedFolders() throws {
        // Given: A project with template folders
        let project = Project(name: "Test Project", type: .prose)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When: Accessing folders directly from project
        let projectFolders = project.folders ?? []
        
        // Then: Can access each folder
        XCTAssertEqual(projectFolders.count, 10, "Prose project should have 10 folders")
        
        for folder in projectFolders {
            XCTAssertNotNil(folder.name, "Folder should have name")
            XCTAssertEqual(folder.project, project, "Folder should reference project")
        }
    }
    
    func testProjectFoldersAreQueryable() throws {
        // Given: A project with template folders
        let project = Project(name: "Test Project", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When: Accessing root project folders (excludes Manuscript subfolders)
        let allFolders = project.folders ?? []
        let rootFolders = allFolders.filter { $0.parentFolder == nil }
        
        // Then: Can access all root folders
        XCTAssertEqual(rootFolders.count, 9, "Should find 9 root folders for poetry project")
        
        let folderNames = Set(rootFolders.compactMap { $0.name })
        XCTAssert(folderNames.contains("Poems"), "Should contain Poems folder")
        XCTAssert(folderNames.contains("Collections"), "Should contain Collections folder")
        XCTAssert(folderNames.contains("Submissions"), "Should contain Submissions folder")
        XCTAssert(folderNames.contains("Magazines"), "Should contain Magazines folder")
        XCTAssert(folderNames.contains("Trash"), "Should contain Trash folder")
    }
    
    func testMultipleProjectsHaveIsolatedFolderStructures() throws {
        // Given: Two projects with different types
        let poetryProject = Project(name: "Poetry Project", type: .poetry)
        let proseProject = Project(name: "Prose Project", type: .prose)
        
        modelContext.insert(poetryProject)
        modelContext.insert(proseProject)
        
        ProjectTemplateService.createDefaultFolders(for: poetryProject, in: modelContext)
        ProjectTemplateService.createDefaultFolders(for: proseProject, in: modelContext)
        
        // When: Accessing root folders for each project
        let allPoetryFolders = poetryProject.folders ?? []
        let poetryRootFolders = allPoetryFolders.filter { $0.parentFolder == nil }
        let allProseFolders = proseProject.folders ?? []
        let proseRootFolders = allProseFolders.filter { $0.parentFolder == nil }
        
        // Then: Each has its own folder structure
        XCTAssertEqual(poetryRootFolders.count, 9, "Poetry project should have 9 root folders")
        XCTAssertEqual(proseRootFolders.count, 10, "Prose project should have 10 root folders")
        
        // Verify type-specific folders
        let poetryFolderNames = Set(poetryRootFolders.compactMap { $0.name })
        let proseFolderNames = Set(proseRootFolders.compactMap { $0.name })
        
        XCTAssert(poetryFolderNames.contains("Magazines"), "Poetry project should have Magazines folder")
        XCTAssert(poetryFolderNames.contains("Poems"), "Poetry project should have Poems folder")
        
        XCTAssert(proseFolderNames.contains("Sections"), "Prose project should have Sections folder")
        XCTAssert(proseFolderNames.contains("Prose"), "Prose project should have Prose folder")
        XCTAssertFalse(proseFolderNames.contains("Characters"), "Prose project should not have Characters folder")
    }
    
    func testDeletingProjectCascadeDeletesFolders() throws {
        // Given: A project with template folders
        let project = Project(name: "Test Project", type: .drama)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Verify folders exist
        let foldersBefore = project.folders ?? []
        XCTAssertGreaterThan(foldersBefore.count, 0, "Should have folders before deletion")
        
        // When: Deleting the project
        modelContext.delete(project)
        try modelContext.save()
        
        // Then: All folders should be deleted via cascade
        let allFoldersAfter = try modelContext.fetch(FetchDescriptor<Folder>())
        XCTAssertEqual(allFoldersAfter.count, 0, "All folders should be deleted with project")
    }
    
    func testTemplateStructureMatchesSpecification() throws {
        // Given: A poetry project
        let project = Project(name: "Poetry Project", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When: Analyzing the created structure
        let allFolders = project.folders ?? []
        let rootFolders = allFolders.filter { $0.parentFolder == nil }
        
        // Then: Verify structure matches spec (9 root folders, Manuscript has 3 subfolders)
        XCTAssertEqual(rootFolders.count, 9, "Should have 9 root folders total for poetry project")
        
        let folderNames = Set(rootFolders.compactMap { $0.name })
        let expectedNames = Set([
            "Poems", "Collections", "Submissions", "Manuscript",
            "Research", 
            "Magazines", "Competitions", "Other", 
            "Trash"
        ])
        XCTAssertEqual(folderNames, expectedNames, "Folder names should match spec")
        
        // Verify Manuscript has 3 subfolders (Front Matter, Body, Back Matter)
        for folder in rootFolders {
            if folder.name == "Manuscript" {
                XCTAssertEqual(folder.folders?.count ?? 0, 3, "Manuscript should have 3 subfolders")
                let subfolderNames = Set(folder.folders?.compactMap { $0.name } ?? [])
                XCTAssertEqual(subfolderNames, ["Front Matter", "Body", "Back Matter"], "Manuscript subfolders should match spec")
            } else {
                XCTAssertEqual(folder.folders?.count ?? 0, 0, "\(folder.name ?? "unknown") should have no subfolders")
            }
        }
    }
    
    func testEmptyFoldersAreReadyForContent() throws {
        // Given: A project with template folders
        let project = Project(name: "Test Project", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When: Finding the "Poems" folder (content folder in new structure)
        let folders = project.folders ?? []
        let poemsFolder = folders.first { $0.name == "Poems" }
        XCTAssertNotNil(poemsFolder, "Should have Poems folder")
        
        guard let poems = poemsFolder else {
            XCTFail("Poems folder not found")
            return
        }
        
        // Then: Verify it's ready to contain files
        XCTAssertNotNil(poems.textFiles, "Should have files array initialized")
        XCTAssertEqual(poems.textFiles?.count, 0, "Should start with no files")
        
        // Can add a file with workflow status
        let testFile = TextFile(name: "My Poem.txt", initialContent: "Roses are red...")
        testFile.parentFolder = poems
        testFile.workflowStatus = .draft
        modelContext.insert(testFile)
        poems.textFiles?.append(testFile)
        
        XCTAssertEqual(poems.textFiles?.count, 1, "Should now contain one file")
        XCTAssertEqual(testFile.workflowStatus, .draft, "File should have draft status")
    }
}
