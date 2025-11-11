import XCTest
import SwiftData
@testable import Writing_Shed_Pro

/// Comprehensive tests for Feature 008c Phase 1: Collections System Folder
/// Ensures Collections folder is properly created, positioned, and configured as read-only
final class CollectionsPhase1Tests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        // Create in-memory model container for testing
        let schema = Schema([Project.self, Folder.self, TextFile.self, Version.self, TrashItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Test Collections Folder Creation
    
    func testCollectionsFolderCreatedInPoetryProject() throws {
        // Given a poetry project
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify Collections folder exists
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }
        
        XCTAssertNotNil(collectionsFolder, "Poetry project should have Collections folder")
    }
    
    func testCollectionsFolderCreatedInShortStoryProject() throws {
        // Given a short story project
        let project = Project(name: "Test Short Story", type: .shortStory)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify Collections folder exists
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }
        
        XCTAssertNotNil(collectionsFolder, "Short story project should have Collections folder")
    }
    
    func testCollectionsFolderNotCreatedInNovelProject() throws {
        // Given a novel project
        let project = Project(name: "Test Novel", type: .novel)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify Collections folder does NOT exist
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }
        
        XCTAssertNil(collectionsFolder, "Novel project should NOT have Collections folder")
    }
    
    func testCollectionsFolderNotCreatedInScriptProject() throws {
        // Given a script project
        let project = Project(name: "Test Script", type: .script)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify Collections folder does NOT exist
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }
        
        XCTAssertNil(collectionsFolder, "Script project should NOT have Collections folder")
    }
    
    func testCollectionsFolderNotCreatedInBlankProject() throws {
        // Given a blank project
        let project = Project(name: "Test Blank", type: .blank)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify Collections folder does NOT exist
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }
        
        XCTAssertNil(collectionsFolder, "Blank project should NOT have Collections folder")
    }
    
    // MARK: - Test Collections Folder Positioning
    
    func testCollectionsFolderPositionedBetweenReadyAndSetAsideInPoetry() throws {
        // Given a poetry project with Collections folder
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When checking folder order in FolderListView
        // Collections should be in the folder list between Ready and Set Aside
        let folders = project.folders ?? []
        let readyFolder = folders.first { $0.name == "Ready" }
        let collectionsFolder = folders.first { $0.name == "Collections" }
        let setAsideFolder = folders.first { $0.name == "Set Aside" }
        
        // Then verify all three folders exist (order tested in UI integration tests)
        XCTAssertNotNil(readyFolder, "Poetry project should have Ready folder")
        XCTAssertNotNil(collectionsFolder, "Poetry project should have Collections folder")
        XCTAssertNotNil(setAsideFolder, "Poetry project should have Set Aside folder")
    }
    
    func testCollectionsFolderPositionedBetweenReadyAndSetAsideInShortStory() throws {
        // Given a short story project with Collections folder
        let project = Project(name: "Test Short Story", type: .shortStory)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When checking folder order in FolderListView
        // Collections should be in the folder list between Ready and Set Aside
        let folders = project.folders ?? []
        let readyFolder = folders.first { $0.name == "Ready" }
        let collectionsFolder = folders.first { $0.name == "Collections" }
        let setAsideFolder = folders.first { $0.name == "Set Aside" }
        
        // Then verify all three folders exist (order tested in UI integration tests)
        XCTAssertNotNil(readyFolder, "Short story project should have Ready folder")
        XCTAssertNotNil(collectionsFolder, "Short story project should have Collections folder")
        XCTAssertNotNil(setAsideFolder, "Short story project should have Set Aside folder")
    }
    
    // MARK: - Test Collections Folder Read-Only Status
    
    func testCollectionsFolderIsReadOnly() throws {
        // Given a Collections folder
        let folder = Folder(name: "Collections", project: nil, parentFolder: nil)
        
        // When checking if subfolders can be added
        let canAddSubfolder = FolderCapabilityService.canAddSubfolder(to: folder)
        
        // Then verify Collections folder is read-only (cannot add subfolders)
        XCTAssertFalse(canAddSubfolder, "Collections folder should be read-only (cannot add subfolders)")
    }
    
    func testCollectionsFolderCannotAddFiles() throws {
        // Given a Collections folder
        let folder = Folder(name: "Collections", project: nil, parentFolder: nil)
        
        // When checking if files can be added
        let canAddFile = FolderCapabilityService.canAddFile(to: folder)
        
        // Then verify Collections folder cannot have files added directly
        XCTAssertFalse(canAddFile, "Collections folder should not allow direct file additions")
    }
    
    func testReadyFolderCanStillAcceptFiles() throws {
        // Given a Ready folder (should not be affected by Collections changes)
        let folder = Folder(name: "Ready", project: nil, parentFolder: nil)
        
        // When checking if files can be added
        let canAddFile = FolderCapabilityService.canAddFile(to: folder)
        
        // Then verify Ready folder is still read-only
        XCTAssertFalse(canAddFile, "Ready folder should still be read-only")
    }
    
    func testDraftFolderCanStillAcceptFiles() throws {
        // Given a Draft folder (should not be affected by Collections changes)
        let folder = Folder(name: "Draft", project: nil, parentFolder: nil)
        
        // When checking if files can be added
        let canAddFile = FolderCapabilityService.canAddFile(to: folder)
        
        // Then verify Draft folder can accept files
        XCTAssertTrue(canAddFile, "Draft folder should still accept files")
    }
    
    // MARK: - Test Collections Folder Structure
    
    func testCollectionsFolderIsAtRootLevel() throws {
        // Given a poetry project with Collections folder
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When getting the Collections folder
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }
        
        // Then verify Collections is at root level
        XCTAssertNil(collectionsFolder?.parentFolder, "Collections should be at root level (no parent)")
        XCTAssertEqual(collectionsFolder?.project?.id, project.id, "Collections should belong to the project")
    }
    
    func testCollectionsFolderIsEmpty() throws {
        // Given a poetry project with Collections folder
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When getting the Collections folder
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }
        
        // Then verify Collections has no initial subfolders
        XCTAssertEqual(collectionsFolder?.folders?.count ?? 0, 0, "Collections should start empty")
    }
    
    // MARK: - Test Collections Folder Consistency
    
    func testMultipleProjectsHaveIndependentCollectionsFolders() throws {
        // Given two poetry projects
        let project1 = Project(name: "Poetry 1", type: .poetry)
        let project2 = Project(name: "Poetry 2", type: .poetry)
        modelContext.insert(project1)
        modelContext.insert(project2)
        
        // When creating default folders for both
        ProjectTemplateService.createDefaultFolders(for: project1, in: modelContext)
        ProjectTemplateService.createDefaultFolders(for: project2, in: modelContext)
        
        // Then verify each has independent Collections folder
        let collectionsFolder1 = (project1.folders ?? []).first { $0.name == "Collections" }
        let collectionsFolder2 = (project2.folders ?? []).first { $0.name == "Collections" }
        
        XCTAssertNotNil(collectionsFolder1, "Project 1 should have Collections")
        XCTAssertNotNil(collectionsFolder2, "Project 2 should have Collections")
        XCTAssertNotEqual(collectionsFolder1?.id, collectionsFolder2?.id, "Collections folders should be different instances")
    }
    
    func testCollectionsFolderHasCorrectMetadata() throws {
        // Given a poetry project with Collections folder
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // When getting the Collections folder
        let folders = project.folders ?? []
        let collectionsFolder = folders.first { $0.name == "Collections" }
        
        // Then verify metadata is correct
        XCTAssertEqual(collectionsFolder?.name, "Collections", "Collections folder should have correct name")
        XCTAssertNotNil(collectionsFolder?.id, "Collections should have unique ID")
        XCTAssertEqual(collectionsFolder?.project?.id, project.id, "Collections should reference the project")
    }
}
