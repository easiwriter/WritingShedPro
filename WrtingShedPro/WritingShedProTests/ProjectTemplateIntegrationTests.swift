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
        
        // Then: Verify folders are created (flat structure)
        // Poetry: Poems, Collections, Submissions, Manuscript, Research, Magazines, Competitions, Other, Trash
        let projectFolders = newProject.folders ?? []
        XCTAssertEqual(projectFolders.count, 9, "Should create 9 folders for poetry project")
        
        // Verify expected folder names exist
        let folderNames = Set(projectFolders.compactMap { $0.name })
        let expectedFolders: Set<String> = [
            "Poems", "Collections", "Submissions", "Manuscript",
            "Research", "Magazines", "Competitions", 
            "Other", "Trash"
        ]
        XCTAssertEqual(folderNames, expectedFolders, "Should have correct folder names")
    }
    
    func testCanNavigateToCreatedFolders() throws {
        // Given: A project with template folders
        let project = Project(name: "Test Project", type: .generalPurpose)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When: Accessing folders directly from project
        let projectFolders = project.folders ?? []
        
        // Then: Can access each folder
        XCTAssertEqual(projectFolders.count, 2, "Blank project should have 2 folders")
        
        for folder in projectFolders {
            XCTAssertNotNil(folder.name, "Folder should have name")
            XCTAssertEqual(folder.project, project, "Folder should reference project")
            
            // Verify blank project has expected folders
            XCTAssertTrue(["Folders", "Trash"].contains(folder.name), "Should be expected folder name")
        }
    }
    
    func testProjectFoldersAreQueryable() throws {
        // Given: A project with template folders
        let project = Project(name: "Test Project", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When: Accessing all project folders
        let projectFolders = project.folders ?? []
        
        // Then: Can access all folders
        XCTAssertEqual(projectFolders.count, 9, "Should find 9 folders for poetry project")
        
        let folderNames = Set(projectFolders.compactMap { $0.name })
        XCTAssert(folderNames.contains("Poems"), "Should contain Poems folder")
        XCTAssert(folderNames.contains("Collections"), "Should contain Collections folder")
        XCTAssert(folderNames.contains("Submissions"), "Should contain Submissions folder")
        XCTAssert(folderNames.contains("Magazines"), "Should contain Magazines folder")
        XCTAssert(folderNames.contains("Trash"), "Should contain Trash folder")
    }
    
    func testMultipleProjectsHaveIsolatedFolderStructures() throws {
        // Given: Two projects with different types
        let poetryProject = Project(name: "Poetry Project", type: .poetry)
        let proseProject = Project(name: "Prose Project", type: .generalPurpose)
        
        modelContext.insert(poetryProject)
        modelContext.insert(proseProject)
        
        ProjectTemplateService.createDefaultFolders(for: poetryProject, in: modelContext)
        ProjectTemplateService.createDefaultFolders(for: proseProject, in: modelContext)
        
        // When: Accessing folders for each project
        let poetryFolders = poetryProject.folders ?? []
        let proseFolders = proseProject.folders ?? []
        
        // Then: Each has its own folder structure
        XCTAssertEqual(poetryFolders.count, 9, "Poetry project should have 9 folders")
        XCTAssertEqual(proseFolders.count, 2, "Blank project should have 2 folders")
        
        // Verify type-specific folders
        let poetryFolderNames = Set(poetryFolders.compactMap { $0.name })
        let proseFolderNames = Set(proseFolders.compactMap { $0.name })
        
        XCTAssert(poetryFolderNames.contains("Magazines"), "Poetry project should have Magazines folder")
        XCTAssert(poetryFolderNames.contains("Poems"), "Poetry project should have Poems folder")
        
        XCTAssertFalse(proseFolderNames.contains("Magazines"), "General Purpose project should not have Magazines folder")
        XCTAssertEqual(proseFolderNames, ["Folders", "Trash"], "General Purpose project should only have Folders and Trash")
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
        let folders = project.folders ?? []
        
        // Then: Verify flat structure matches spec (all folders at root level)
        XCTAssertEqual(folders.count, 9, "Should have 9 folders total for poetry project")
        
        let folderNames = Set(folders.compactMap { $0.name })
        let expectedNames = Set([
            "Poems", "Collections", "Submissions", "Manuscript",
            "Research", 
            "Magazines", "Competitions", "Other", 
            "Trash"
        ])
        XCTAssertEqual(folderNames, expectedNames, "Folder names should match spec")
        
        // Verify all folders have no subfolders (flat structure)
        for folder in folders {
            XCTAssertEqual(folder.folders?.count ?? 0, 0, "\(folder.name ?? "unknown") should have no subfolders in flat structure")
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
