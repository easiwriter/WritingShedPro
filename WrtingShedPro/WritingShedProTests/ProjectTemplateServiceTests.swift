import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class ProjectTemplateServiceTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        // Create in-memory model container for testing
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
    
    // MARK: - Test Flat Folder Structure
    
    func testCreateDefaultFoldersForPoetryProject() throws {
        // Given a poetry project
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify 13 folders exist in flat structure
        let folders = project.folders ?? []
        
        XCTAssertEqual(folders.count, 12, "Should have 12 folders for poetry project")
        
        let folderNames = Set(folders.compactMap { $0.name })
        let expectedNames: Set<String> = [
            "All", "Draft", "Ready", "Collections", "Set Aside", "Published",
            "Research", "Magazines", "Competitions", "Commissions",
            "Other", "Trash"
        ]
        XCTAssertEqual(folderNames, expectedNames, "Should have correct folder names")
    }
    
    func testCreateDefaultFoldersForBlankProject() throws {
        // Given a blank project
        let project = Project(name: "Test Blank", type: .blank)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify 2 folders exist in flat structure
        let folders = project.folders ?? []
        
        XCTAssertEqual(folders.count, 2, "Should have 2 folders for blank project")
        
        let folderNames = Set(folders.compactMap { $0.name })
        let expectedNames: Set<String> = ["Files", "Trash"]
        XCTAssertEqual(folderNames, expectedNames, "Should have correct folder names")
    }
    
    func testCreateDefaultFoldersForNovelProject() throws {
        // Given a novel project
        let project = Project(name: "Test Novel", type: .novel)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify 11 folders exist in flat structure
        let folders = project.folders ?? []
        
        XCTAssertEqual(folders.count, 11, "Should have 11 folders for novel project")
        
        let folderNames = Set(folders.compactMap { $0.name })
        let expectedNames: Set<String> = [
            "Novel", "Chapters", "Scenes", "Characters", "Locations", "Set Aside",
            "Research", "Competitions", "Commissions", "Other", "Trash"
        ]
        XCTAssertEqual(folderNames, expectedNames, "Should have correct folder names")
    }
    
    func testCreateDefaultFoldersForScriptProject() throws {
        // Given a script project
        let project = Project(name: "Test Script", type: .script)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify 11 folders exist in flat structure
        let folders = project.folders ?? []
        
        XCTAssertEqual(folders.count, 11, "Should have 11 folders for script project")
        
        let folderNames = Set(folders.compactMap { $0.name })
        let expectedNames: Set<String> = [
            "Script", "Acts", "Scenes", "Characters", "Locations", "Set Aside",
            "Research", "Competitions", "Commissions", "Other", "Trash"
        ]
        XCTAssertEqual(folderNames, expectedNames, "Should have correct folder names")
    }
    
    func testCreateDefaultFoldersForShortStoryProject() throws {
        // Given a short story project
        let project = Project(name: "Test Short Story", type: .shortStory)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify 11 folders exist in flat structure (same as poetry)
        let folders = project.folders ?? []
        
        XCTAssertEqual(folders.count, 12, "Should have 12 folders for short story project")
        
        let folderNames = Set(folders.compactMap { $0.name })
        let expectedNames: Set<String> = [
            "All", "Draft", "Ready", "Collections", "Set Aside", "Published",
            "Research", "Magazines", "Competitions", "Commissions",
            "Other", "Trash"
        ]
        XCTAssertEqual(folderNames, expectedNames, "Should have correct folder names")
    }
    
    // MARK: - Test Flat Structure
    
    func testAllFoldersCreatedAtRootLevel() throws {
        // Given a poetry project
        let project = Project(name: "Test Project", type: .poetry)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify all folders are at root level (no nesting initially)
        let folders = project.folders ?? []
        
        for folder in folders {
            XCTAssertEqual(folder.folders?.count ?? 0, 0, "\(folder.name ?? "unknown") should have no initial subfolders")
            XCTAssertNil(folder.parentFolder, "\(folder.name ?? "unknown") should have no parent folder")
            XCTAssertEqual(folder.project?.id, project.id, "\(folder.name ?? "unknown") should reference project")
        }
    }
    
    // MARK: - Test Folder Capabilities
    
    func testSubfolderOnlyFolderCapabilities() throws {
        // Given a poetry project with folders
        let project = Project(name: "Test Project", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify subfolder-only folders from spec
        let subfolderOnlyNames = ["Magazines", "Competitions", "Commissions", "Other"]
        
        let folders = project.folders ?? []
        for name in subfolderOnlyNames {
            if let folder = folders.first(where: { $0.name == name }) {
                XCTAssertTrue(FolderCapabilityService.canAddSubfolder(to: folder), 
                            "\(name) should allow subfolders (📁)")
                XCTAssertFalse(FolderCapabilityService.canAddFile(to: folder), 
                             "\(name) should NOT allow files (📁)")
            }
        }
    }
    
    func testFileOnlyFolderCapabilities() throws {
        // Given a poetry project with folders
        let project = Project(name: "Test Project", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify file-only folders from FolderCapabilityService
        let fileOnlyNames = ["Draft", "Research"]
        
        let folders = project.folders ?? []
        for name in fileOnlyNames {
            if let folder = folders.first(where: { $0.name == name }) {
                XCTAssertFalse(FolderCapabilityService.canAddSubfolder(to: folder), 
                             "\(name) should NOT allow subfolders (📄)")
                XCTAssertTrue(FolderCapabilityService.canAddFile(to: folder), 
                            "\(name) should allow files (📄)")
            }
        }
    }
    
    func testMixedCapabilityFolderCapabilities() throws {
        // Given a poetry project with folders
        let project = Project(name: "Test Project", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify read-only folders cannot have files added
        let readOnlyNames = ["All", "Ready", "Set Aside", "Published", "Trash"]
        
        let folders = project.folders ?? []
        for name in readOnlyNames {
            if let folder = folders.first(where: { $0.name == name }) {
                XCTAssertFalse(FolderCapabilityService.canAddSubfolder(to: folder), 
                            "\(name) should NOT allow subfolders (read-only)")
                XCTAssertFalse(FolderCapabilityService.canAddFile(to: folder), 
                            "\(name) should NOT allow files (read-only)")
            }
        }
    }
    
    func testNovelProjectFolderCapabilities() throws {
        // Given a novel project with folders
        let project = Project(name: "Test Novel", type: .novel)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        
        // Verify subfolder-only (📁)
        let subfolderOnly = ["Chapters", "Competitions", "Commissions", "Other"]
        for name in subfolderOnly {
            if let folder = folders.first(where: { $0.name == name }) {
                XCTAssertTrue(FolderCapabilityService.canAddSubfolder(to: folder))
                XCTAssertFalse(FolderCapabilityService.canAddFile(to: folder))
            }
        }
        
        // Verify file-only (📄)
        let fileOnly = ["Scenes", "Characters", "Locations", "Research"]
        for name in fileOnly {
            if let folder = folders.first(where: { $0.name == name }) {
                XCTAssertFalse(FolderCapabilityService.canAddSubfolder(to: folder))
                XCTAssertTrue(FolderCapabilityService.canAddFile(to: folder))
            }
        }
        
        // Verify read-only (no manual additions)
        let readOnly = ["Novel", "Set Aside", "Trash"]
        for name in readOnly {
            if let folder = folders.first(where: { $0.name == name }) {
                XCTAssertFalse(FolderCapabilityService.canAddSubfolder(to: folder))
                XCTAssertFalse(FolderCapabilityService.canAddFile(to: folder))
            }
        }
    }
    
    func testScriptProjectFolderCapabilities() throws {
        // Given a script project with folders
        let project = Project(name: "Test Script", type: .script)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        
        // Verify subfolder-only (📁)
        let subfolderOnly = ["Acts", "Competitions", "Commissions", "Other"]
        for name in subfolderOnly {
            if let folder = folders.first(where: { $0.name == name }) {
                XCTAssertTrue(FolderCapabilityService.canAddSubfolder(to: folder))
                XCTAssertFalse(FolderCapabilityService.canAddFile(to: folder))
            }
        }
        
        // Verify file-only (📄)
        let fileOnly = ["Scenes", "Characters", "Locations", "Research"]
        for name in fileOnly {
            if let folder = folders.first(where: { $0.name == name }) {
                XCTAssertFalse(FolderCapabilityService.canAddSubfolder(to: folder))
                XCTAssertTrue(FolderCapabilityService.canAddFile(to: folder))
            }
        }
        
        // Verify read-only (no manual additions)
        let readOnly = ["Script", "Set Aside", "Trash"]
        for name in readOnly {
            if let folder = folders.first(where: { $0.name == name }) {
                XCTAssertFalse(FolderCapabilityService.canAddSubfolder(to: folder))
                XCTAssertFalse(FolderCapabilityService.canAddFile(to: folder))
            }
        }
    }
    
    // MARK: - Test Edge Cases
    
    func testMultipleProjectsHaveIndependentFolders() throws {
        // Given two projects
        let project1 = Project(name: "Project 1", type: .poetry)
        let project2 = Project(name: "Project 2", type: .blank)
        modelContext.insert(project1)
        modelContext.insert(project2)
        
        // When creating default folders for both
        ProjectTemplateService.createDefaultFolders(for: project1, in: modelContext)
        ProjectTemplateService.createDefaultFolders(for: project2, in: modelContext)
        
        // Then verify each has independent folder sets
        let folders1 = project1.folders ?? []
        let folders2 = project2.folders ?? []
        
        XCTAssertEqual(folders1.count, 12, "Project 1 should have 12 folders")
        XCTAssertEqual(folders2.count, 2, "Project 2 should have 2 folders")
        
        // Verify no overlap in folder IDs
        let ids1 = Set(folders1.map { $0.id })
        let ids2 = Set(folders2.map { $0.id })
        XCTAssertTrue(ids1.isDisjoint(with: ids2), "Folder IDs should be unique across projects")
    }
    
    func testAllFoldersHaveProjectReference() throws {
        // Given a project with default folders
        let project = Project(name: "Test Project", type: .novel)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify all folders reference the project
        let folders = project.folders ?? []
        for folder in folders {
            XCTAssertNotNil(folder.project, "\(folder.name ?? "unknown") should have project reference")
            XCTAssertEqual(folder.project?.id, project.id, "\(folder.name ?? "unknown") should reference correct project")
        }
    }
}
