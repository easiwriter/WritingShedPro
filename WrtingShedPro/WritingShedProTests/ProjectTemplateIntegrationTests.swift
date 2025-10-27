import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class ProjectTemplateIntegrationTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        let schema = Schema([Project.self, Folder.self, File.self])
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
        
        // Then: Verify folders are created (hierarchical structure)
        let projectFolders = newProject.folders ?? []
        XCTAssertEqual(projectFolders.count, 11, "Should create 11 folders for poetry project (hierarchical structure)")
        
        // Verify expected folder names exist
        let folderNames = Set(projectFolders.compactMap { $0.name })
        let expectedFolders: Set<String> = [
            "All", "Draft", "Ready", "Set Aside", "Published",
            "Research", "Magazines", "Competitions", "Commissions", 
            "Other", "Trash"
        ]
        XCTAssertEqual(folderNames, expectedFolders, "Should have correct folder names")
    }
    
    func testCanNavigateToCreatedFolders() throws {
        // Given: A project with template folders
        let project = Project(name: "Test Project", type: .blank)
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
            XCTAssertTrue(["Files", "Trash"].contains(folder.name), "Should be expected folder name")
        }
    }
    
    func testProjectFoldersAreQueryable() throws {
        // Given: A project with template folders
        let project = Project(name: "Test Project", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When: Accessing all project folders
        let projectFolders = project.folders ?? []
        
        // Then: Can access all folders in hierarchical structure
        XCTAssertEqual(projectFolders.count, 13, "Should find 13 folders for poetry project")
        
        let folderNames = Set(projectFolders.compactMap { $0.name })
        XCTAssert(folderNames.contains("Draft"), "Should contain Draft folder")
        XCTAssert(folderNames.contains("Ready"), "Should contain Ready folder")
        XCTAssert(folderNames.contains("Published"), "Should contain Published folder")
        XCTAssert(folderNames.contains("Magazines"), "Should contain Magazines folder")
        XCTAssert(folderNames.contains("Trash"), "Should contain Trash folder")
    }
    
    func testMultipleProjectsHaveIsolatedFolderStructures() throws {
        // Given: Two projects with different types
        let poetryProject = Project(name: "Poetry Project", type: .poetry)
        let proseProject = Project(name: "Prose Project", type: .blank)
        
        modelContext.insert(poetryProject)
        modelContext.insert(proseProject)
        
        ProjectTemplateService.createDefaultFolders(for: poetryProject, in: modelContext)
        ProjectTemplateService.createDefaultFolders(for: proseProject, in: modelContext)
        
        // When: Accessing folders for each project
        let poetryFolders = poetryProject.folders ?? []
        let proseFolders = proseProject.folders ?? []
        
        // Then: Each has its own folder structure
        XCTAssertEqual(poetryFolders.count, 11, "Poetry project should have 11 folders")
        XCTAssertEqual(proseFolders.count, 2, "Blank project should have 2 folders")
        
        // Verify type-specific folders
        let poetryFolderNames = Set(poetryFolders.compactMap { $0.name })
        let proseFolderNames = Set(proseFolders.compactMap { $0.name })
        
        XCTAssert(poetryFolderNames.contains("Magazines"), "Poetry project should have Magazines folder")
        XCTAssert(poetryFolderNames.contains("Published"), "Poetry project should have Published folder")
        
        XCTAssertFalse(proseFolderNames.contains("Magazines"), "Blank project should not have Magazines folder")
        XCTAssertEqual(proseFolderNames, ["Files", "Trash"], "Blank project should only have Files and Trash")
    }
    
    func testDeletingProjectCascadeDeletesFolders() throws {
        // Given: A project with template folders
        let project = Project(name: "Test Project", type: .script)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Verify folders exist (Script has 7 type + 4 publications + 1 trash = 12 total in flat structure)
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
        XCTAssertEqual(folders.count, 11, "Should have 11 folders total for poetry project")
        
        let folderNames = Set(folders.compactMap { $0.name })
        let expectedNames = Set([
            "All", "Draft", "Ready", "Set Aside", "Published",
            "Research", 
            "Magazines", "Competitions", "Commissions", "Other", 
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
        
        // When: Finding the "Draft" folder (in flat structure, directly at root)
        let folders = project.folders ?? []
        let draftFolder = folders.first { $0.name == "Draft" }
        XCTAssertNotNil(draftFolder, "Should have Draft folder")
        
        guard let draft = draftFolder else {
            XCTFail("Draft folder not found")
            return
        }
        
        // Then: Verify it's ready to contain files
        XCTAssertNotNil(draft.files, "Should have files array initialized")
        XCTAssertEqual(draft.files?.count, 0, "Should start with no files")
        
        // Can add a file
        let testFile = File(name: "Chapter 1.txt", content: "Once upon a time...")
        testFile.parentFolder = draft
        modelContext.insert(testFile)
        draft.files?.append(testFile)
        
        XCTAssertEqual(draft.files?.count, 1, "Should now contain one file")
    }
}