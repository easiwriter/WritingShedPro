import XCTest
import SwiftData
@testable import Write_

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
    
    func testProjectCreationAutomaticallyCreatesFolders() throws {
        // Given: Creating a new project (simulating AddProjectSheet behavior)
        let projectName = "My Poetry Collection"
        let projectType = ProjectType.poetry
        
        // When: Creating and inserting project with template generation
        let newProject = Project(name: projectName, type: projectType)
        modelContext.insert(newProject)
        ProjectTemplateService.createDefaultFolders(for: newProject, in: modelContext)
        
        // Then: Verify folders are created by traversing hierarchy
        func countAllFolders(_ folders: [Folder]) -> Int {
            var count = folders.count
            for folder in folders {
                count += countAllFolders(folder.folders ?? [])
            }
            return count
        }
        
        let totalFolders = countAllFolders(newProject.folders ?? [])
        XCTAssertEqual(totalFolders, 15, "Should create 15 folders (3 root + 8 type subfolders + 4 publications subfolders)")
    }
    
    func testCanNavigateToCreatedFolders() throws {
        // Given: A project with template folders
        let project = Project(name: "Test Project", type: .prose)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When: Accessing root folders directly from project
        let rootFolders = project.folders ?? []
        
        // Then: Can access each root folder and its children
        XCTAssertEqual(rootFolders.count, 3, "Should have 3 root folders")
        
        for rootFolder in rootFolders {
            XCTAssertNotNil(rootFolder.name, "Root folder should have name")
            XCTAssertNotNil(rootFolder.folders, "Root folder should have folders array")
            
            if rootFolder.name == "Your Prose" {
                XCTAssertEqual(rootFolder.folders?.count, 8, "Type folder should have 8 subfolders")
            } else if rootFolder.name == "Publications" {
                XCTAssertEqual(rootFolder.folders?.count, 4, "Publications should have 4 subfolders")
            } else if rootFolder.name == "Trash" {
                XCTAssertEqual(rootFolder.folders?.count, 0, "Trash should have no subfolders")
            }
        }
    }
    
    func testSubfoldersAreQueryableByParent() throws {
        // Given: A project with template folders
        let project = Project(name: "Test Project", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When: Finding the "Your Poetry" folder
        let rootFolders = project.folders ?? []
        let typeFolders = rootFolders.filter { $0.name == "Your Poetry" }
        XCTAssertEqual(typeFolders.count, 1)
        
        let typeFolder = typeFolders[0]
        
        // Then: Can access its children
        let children = typeFolder.folders ?? []
        
        XCTAssertEqual(children.count, 8, "Should find 8 child folders")
        
        let childNames = children.compactMap { $0.name }.sorted()
        XCTAssert(childNames.contains("Draft"), "Should contain Draft folder")
        XCTAssert(childNames.contains("Ready"), "Should contain Ready folder")
        XCTAssert(childNames.contains("Published"), "Should contain Published folder")
    }
    
    func testMultipleProjectsHaveIsolatedFolderStructures() throws {
        // Given: Two projects with different types
        let poetryProject = Project(name: "Poetry Project", type: .poetry)
        let proseProject = Project(name: "Prose Project", type: .prose)
        
        modelContext.insert(poetryProject)
        modelContext.insert(proseProject)
        
        ProjectTemplateService.createDefaultFolders(for: poetryProject, in: modelContext)
        ProjectTemplateService.createDefaultFolders(for: proseProject, in: modelContext)
        
        // When: Accessing folders for each project
        let poetryRootFolders = poetryProject.folders ?? []
        let proseRootFolders = proseProject.folders ?? []
        
        // Then: Each has its own folder structure
        XCTAssertEqual(poetryRootFolders.count, 3, "Poetry project should have 3 root folders")
        XCTAssertEqual(proseRootFolders.count, 3, "Prose project should have 3 root folders")
        
        // Verify type-specific folders
        let poetryTypeFolder = poetryRootFolders.first { $0.name == "Your Poetry" }
        let proseTypeFolder = proseRootFolders.first { $0.name == "Your Prose" }
        
        XCTAssertNotNil(poetryTypeFolder, "Poetry project should have 'Your Poetry' folder")
        XCTAssertNotNil(proseTypeFolder, "Prose project should have 'Your Prose' folder")
        
        XCTAssertNil(poetryRootFolders.first { $0.name == "Your Prose" }, "Poetry project should not have prose folder")
        XCTAssertNil(proseRootFolders.first { $0.name == "Your Poetry" }, "Prose project should not have poetry folder")
    }
    
    func testDeletingProjectCascadeDeletesFolders() throws {
        // Given: A project with template folders
        let project = Project(name: "Test Project", type: .drama)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Verify root folders exist
        let rootFoldersBefore = project.folders ?? []
        XCTAssertEqual(rootFoldersBefore.count, 3, "Should have 3 root folders before deletion")
        
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
        let rootFolders = project.folders ?? []
        
        // Then: Verify exact structure matches spec
        
        // Root level: 3 folders
        XCTAssertEqual(rootFolders.count, 3, "Should have 3 root folders")
        
        let rootNames = Set(rootFolders.compactMap { $0.name })
        XCTAssertEqual(rootNames, Set(["Your Poetry", "Publications", "Trash"]), "Root folders should match spec")
        
        // "Your Poetry" subfolders
        let poetryFolder = rootFolders.first { $0.name == "Your Poetry" }!
        let poetrySubfolders = poetryFolder.folders ?? []
        XCTAssertEqual(poetrySubfolders.count, 8, "Poetry folder should have 8 subfolders")
        
        let poetrySubNames = Set(poetrySubfolders.compactMap { $0.name })
        let expectedPoetrySubNames = Set(["All", "Draft", "Ready", "Set Aside", "Published", "Collections", "Submissions", "Research"])
        XCTAssertEqual(poetrySubNames, expectedPoetrySubNames, "Poetry subfolders should match spec")
        
        // "Publications" subfolders
        let publicationsFolder = rootFolders.first { $0.name == "Publications" }!
        let publicationsSubfolders = publicationsFolder.folders ?? []
        XCTAssertEqual(publicationsSubfolders.count, 4, "Publications folder should have 4 subfolders")
        
        let publicationsSubNames = Set(publicationsSubfolders.compactMap { $0.name })
        let expectedPublicationsSubNames = Set(["Magazines", "Competitions", "Commissions", "Other"])
        XCTAssertEqual(publicationsSubNames, expectedPublicationsSubNames, "Publications subfolders should match spec")
        
        // "Trash" should be empty
        let trashFolder = rootFolders.first { $0.name == "Trash" }!
        let trashSubfolders = trashFolder.folders ?? []
        XCTAssertEqual(trashSubfolders.count, 0, "Trash should have no subfolders")
    }
    
    func testEmptyFoldersAreReadyForContent() throws {
        // Given: A project with template folders
        let project = Project(name: "Test Project", type: .prose)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When: Finding a subfolder (e.g., "Draft") by navigating through parent hierarchy
        let rootFolders = project.folders ?? []
        let typeFolder = rootFolders.first { $0.name == "Your Prose" }
        XCTAssertNotNil(typeFolder, "Should have type-specific folder")
        
        let draftFolders = (typeFolder?.folders ?? []).filter { $0.name == "Draft" }
        XCTAssertEqual(draftFolders.count, 1)
        
        let draftFolder = draftFolders[0]
        
        // Then: Verify it's ready to contain files
        XCTAssertNotNil(draftFolder.files, "Should have files array initialized")
        XCTAssertEqual(draftFolder.files?.count, 0, "Should start with no files")
        XCTAssertNotNil(draftFolder.folders, "Should have folders array initialized")
        XCTAssertEqual(draftFolder.folders?.count, 0, "Should start with no subfolders")
        
        // Can add a file
        let testFile = File(name: "Chapter 1.txt", content: "Once upon a time...", parentFolder: draftFolder)
        modelContext.insert(testFile)
        draftFolder.files?.append(testFile)
        
        XCTAssertEqual(draftFolder.files?.count, 1, "Should now contain one file")
    }
}
