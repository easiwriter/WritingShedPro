import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class ProjectTemplateServiceTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        // Create in-memory model container for testing
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
    
    // MARK: - Test Top-Level Folders
    
    func testCreateDefaultFoldersForPoetryProject() throws {
        // Given a poetry project
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify three top-level folders exist via project relationship
        let rootFolders = project.folders ?? []
        
        XCTAssertEqual(rootFolders.count, 3, "Should have 3 root folders")
        
        let folderNames = rootFolders.compactMap { $0.name }.sorted()
        XCTAssertEqual(folderNames, ["Publications", "Trash", "YOUR POETRY"], "Should have correct root folder names")
    }
    
    func testCreateDefaultFoldersForBlankProject() throws {
        // Given a blank project
        let project = Project(name: "Test Blank", type: .blank)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify root folders with correct blank folder name via project relationship
        let rootFolders = project.folders ?? []
        
        let folderNames = rootFolders.compactMap { $0.name }.sorted()
        XCTAssertEqual(folderNames, ["BLANK", "Trash"], "Should have correct blank folder names")
    }
    
    func testCreateDefaultFoldersForNovelProject() throws {
        // Given a novel project
        let project = Project(name: "Test Novel", type: .novel)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify root folders with correct novel folder name via project relationship
        let rootFolders = project.folders ?? []
        
        let folderNames = rootFolders.compactMap { $0.name }.sorted()
        XCTAssertEqual(folderNames, ["Publications", "Trash", "YOUR NOVEL"], "Should have correct novel folder names")
    }
    
    func testCreateDefaultFoldersForScriptProject() throws {
        // Given a script project
        let project = Project(name: "Test Script", type: .script)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify root folders with correct script folder name via project relationship
        let rootFolders = project.folders ?? []
        
        let folderNames = rootFolders.compactMap { $0.name }.sorted()
        XCTAssertEqual(folderNames, ["Publications", "Trash", "YOUR SCRIPT"], "Should have correct script folder names")
    }
    
    func testCreateDefaultFoldersForShortStoryProject() throws {
        // Given a short story project
        let project = Project(name: "Test Short Story", type: .shortStory)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify root folders with correct short story folder name via project relationship
        let rootFolders = project.folders ?? []
        
        let folderNames = rootFolders.compactMap { $0.name }.sorted()
        XCTAssertEqual(folderNames, ["Publications", "Trash", "YOUR STORIES"], "Should have correct short story folder names")
    }
    
    // MARK: - Test Type-Specific Subfolders
    
    func testTypeSpecificFolderHasCorrectSubfolders() throws {
        // Given a project with default folders
        let project = Project(name: "Test Project", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When fetching the type-specific folder via project relationship
        let rootFolders = project.folders ?? []
        let typeFolders = rootFolders.filter { $0.name == "YOUR POETRY" }
        
        XCTAssertEqual(typeFolders.count, 1, "Should have one 'YOUR POETRY' folder")
        guard !typeFolders.isEmpty else {
            XCTFail("Type folder not found")
            return
        }
        
        let typeFolder = typeFolders[0]
        let subfolders = typeFolder.folders ?? []
        
        // Then verify 8 subfolders exist
        XCTAssertEqual(subfolders.count, 8, "Should have 8 subfolders")
        
        let subfolderNames = subfolders.compactMap { $0.name }.sorted()
        let expectedNames = ["All", "Collections", "Draft", "Published", "Ready", "Research", "Set Aside", "Submissions"]
        XCTAssertEqual(subfolderNames, expectedNames, "Should have correct subfolder names")
    }
    
    func testTypeSubfoldersHaveCorrectParentReferences() throws {
        // Given a project with default folders
        let project = Project(name: "Test Project", type: .blank)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When fetching the type-specific folder via project relationship
        let rootFolders = project.folders ?? []
        let typeFolders = rootFolders.filter { $0.name == "BLANK" }
        
        XCTAssertEqual(typeFolders.count, 1, "Should have one 'BLANK' folder")
        guard !typeFolders.isEmpty else {
            XCTFail("Type folder not found")
            return
        }
        
        let typeFolder = typeFolders[0]
        
        // Then verify all subfolders have correct parent references
        let subfolders = typeFolder.folders ?? []
        for subfolder in subfolders {
            XCTAssertEqual(subfolder.parentFolder?.id, typeFolder.id, "\(subfolder.name ?? "unknown") should have correct parent")
        }
    }
    
    // MARK: - Test Publications Subfolders
    
    func testPublicationsFolderHasCorrectSubfolders() throws {
        // Given a project with default folders
        let project = Project(name: "Test Project", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When fetching the Publications folder via project relationship
        let rootFolders = project.folders ?? []
        let pubFolders = rootFolders.filter { $0.name == "Publications" }
        
        XCTAssertEqual(pubFolders.count, 1, "Should have one Publications folder")
        guard !pubFolders.isEmpty else {
            XCTFail("Publications folder not found")
            return
        }
        
        let pubFolder = pubFolders[0]
        let subfolders = pubFolder.folders ?? []
        
        // Then verify 4 subfolders exist
        XCTAssertEqual(subfolders.count, 4, "Should have 4 subfolders")
        
        let subfolderNames = subfolders.compactMap { $0.name }.sorted()
        let expectedNames = ["Commissions", "Competitions", "Magazines", "Other"]
        XCTAssertEqual(subfolderNames, expectedNames, "Should have correct Publications subfolder names")
    }
    
    func testPublicationsSubfoldersHaveCorrectParentReferences() throws {
        // Given a project with default folders
        let project = Project(name: "Test Project", type: .novel)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When fetching the Publications folder via project relationship
        let rootFolders = project.folders ?? []
        let pubFolders = rootFolders.filter { $0.name == "Publications" }
        
        XCTAssertEqual(pubFolders.count, 1, "Should have one Publications folder")
        guard !pubFolders.isEmpty else {
            XCTFail("Publications folder not found")
            return
        }
        
        let pubFolder = pubFolders[0]
        
        // Then verify all subfolders have correct parent references
        let subfolders = pubFolder.folders ?? []
        for subfolder in subfolders {
            XCTAssertEqual(subfolder.parentFolder?.id, pubFolder.id, "\(subfolder.name ?? "unknown") should have correct parent")
        }
    }
    
    // MARK: - Test Trash Folder
    
    func testTrashFolderHasNoSubfolders() throws {
        // Given a project with default folders
        let project = Project(name: "Test Project", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When fetching the Trash folder via project relationship
        let rootFolders = project.folders ?? []
        let trashFolders = rootFolders.filter { $0.name == "Trash" }
        
        XCTAssertEqual(trashFolders.count, 1, "Should have one Trash folder")
        guard !trashFolders.isEmpty else {
            XCTFail("Trash folder not found")
            return
        }
        
        let trashFolder = trashFolders[0]
        let subfolders = trashFolder.folders ?? []
        
        // Then verify no subfolders exist
        XCTAssertEqual(subfolders.count, 0, "Trash folder should have no subfolders")
    }
    
    // MARK: - Test Complete Hierarchy
    
    func testCompleteHierarchyIsCreated() throws {
        // Given a project
        let project = Project(name: "Test Project", type: .shortStory)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify total folder count by traversing hierarchy
        func countAllFolders(_ folders: [Folder]) -> Int {
            var count = folders.count
            for folder in folders {
                count += countAllFolders(folder.folders ?? [])
            }
            return count
        }
        
        let totalCount = countAllFolders(project.folders ?? [])
        
        // 3 root folders + 8 type subfolders + 4 publications subfolders = 15 total
        XCTAssertEqual(totalCount, 15, "Should have 15 total folders")
    }
    
    func testAllFoldersHaveProjectReference() throws {
        // Given a project with default folders
        let project = Project(name: "Test Project", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify that only root-level folders have direct project references
        // (Subfolders are accessed through parent hierarchy, not direct project reference)
        let rootFolders = project.folders ?? []
        for folder in rootFolders {
            XCTAssertNotNil(folder.project, "\(folder.name ?? "unknown") should have project reference")
            XCTAssertEqual(folder.project?.id, project.id, "\(folder.name ?? "unknown") should reference correct project")
        }
    }
    
    // MARK: - Test Edge Cases
    
    func testMultipleProjectsHaveIndependentFolders() throws {
        // Given two projects
        let project1 = Project(name: "Project 1", type: .poetry)
        let project2 = Project(name: "Project 2", type: .script)
        modelContext.insert(project1)
        modelContext.insert(project2)
        
        // When creating default folders for both
        ProjectTemplateService.createDefaultFolders(for: project1, in: modelContext)
        ProjectTemplateService.createDefaultFolders(for: project2, in: modelContext)
        
        // Then verify each has independent folder sets via relationships
        func countAllFolders(_ folders: [Folder]) -> Int {
            var count = folders.count
            for folder in folders {
                count += countAllFolders(folder.folders ?? [])
            }
            return count
        }
        
        let count1 = countAllFolders(project1.folders ?? [])
        let count2 = countAllFolders(project2.folders ?? [])
        
        XCTAssertEqual(count1, 15, "Project 1 should have 15 folders")
        XCTAssertEqual(count2, 15, "Project 2 should have 15 folders")
        
        // Verify no overlap in folder IDs
        func getAllFolderIds(_ folders: [Folder]) -> Set<UUID> {
            var ids = Set<UUID>()
            for folder in folders {
                ids.insert(folder.id)
                ids.formUnion(getAllFolderIds(folder.folders ?? []))
            }
            return ids
        }
        
        let ids1 = getAllFolderIds(project1.folders ?? [])
        let ids2 = getAllFolderIds(project2.folders ?? [])
        XCTAssertTrue(ids1.isDisjoint(with: ids2), "Folder IDs should be unique across projects")
    }
    
    func testProjectTypeExtension() {
        // Test folder name generation for each type
        XCTAssertEqual(ProjectType.blank.typeFolderName, "BLANK")
        XCTAssertEqual(ProjectType.novel.typeFolderName, "YOUR NOVEL")
        XCTAssertEqual(ProjectType.poetry.typeFolderName, "YOUR POETRY")
        XCTAssertEqual(ProjectType.script.typeFolderName, "YOUR SCRIPT")
        XCTAssertEqual(ProjectType.shortStory.typeFolderName, "YOUR STORIES")
    }
}
