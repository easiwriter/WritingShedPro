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
        
        // Then verify folders exist in flat structure
        // Poetry: Poems, Collections, Submissions, Manuscript, Research, Magazines, Competitions, Commissions, Other, Trash
        let folders = project.folders ?? []
        
        XCTAssertEqual(folders.count, 10, "Should have 10 folders for poetry project")
        
        let folderNames = Set(folders.compactMap { $0.name })
        let expectedNames: Set<String> = [
            "Poems", "Collections", "Submissions", "Manuscript",
            "Research", "Magazines", "Competitions", "Commissions",
            "Other", "Trash"
        ]
        XCTAssertEqual(folderNames, expectedNames, "Should have correct folder names")
    }
    
    func testCreateDefaultFoldersForBlankProject() throws {
        // Given a blank project
        let project = Project(name: "Test Blank", type: .generalPurpose)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify 2 folders exist in flat structure
        let folders = project.folders ?? []
        
        XCTAssertEqual(folders.count, 2, "Should have 2 folders for blank project")
        
        let folderNames = Set(folders.compactMap { $0.name })
        let expectedNames: Set<String> = ["Folders", "Trash"]
        XCTAssertEqual(folderNames, expectedNames, "Should have correct folder names")
    }
    
    func testCreateDefaultFoldersForFictionProject() throws {
        // Given a fiction project (Short Fiction by default when fictionClass is nil)
        let project = Project(name: "Test Fiction", type: .fiction)
        // fictionClass defaults to nil, which falls into shortFiction branch
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify folders exist in flat structure
        // Short Fiction: Scenes, Characters, Locations, Chapters, Plot, Collections, Submissions, Research, Magazines, Competitions, Agents, Publishers, Other, Trash
        let folders = project.folders ?? []
        
        XCTAssertEqual(folders.count, 14, "Should have 14 folders for Short Fiction project")
        
        let folderNames = Set(folders.compactMap { $0.name })
        let expectedNames: Set<String> = [
            "Scenes", "Characters", "Locations", "Chapters", "Plot",
            "Collections", "Submissions", "Research",
            "Magazines", "Competitions", "Agents", "Publishers", "Other", "Trash"
        ]
        XCTAssertEqual(folderNames, expectedNames, "Should have correct folder names for Short Fiction")
    }
    
    func testCreateDefaultFoldersForNovelProject() throws {
        // Given a novel project
        let project = Project(name: "Test Novel", type: .fiction)
        project.fictionClass = .novel
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify folders exist in flat structure
        // Novel: Scenes, Characters, Locations, Chapters, Plot, Collections, Submissions, Research, Publishers, Agents, Other, Trash
        let folders = project.folders ?? []
        
        XCTAssertEqual(folders.count, 12, "Should have 12 folders for Novel project")
        
        let folderNames = Set(folders.compactMap { $0.name })
        let expectedNames: Set<String> = [
            "Scenes", "Characters", "Locations", "Chapters", "Plot",
            "Collections", "Submissions", "Research",
            "Publishers", "Agents", "Other", "Trash"
        ]
        XCTAssertEqual(folderNames, expectedNames, "Should have correct folder names for Novel")
    }
    
    func testCreateDefaultFoldersForShortFictionProject() throws {
        // Given a short fiction project
        let project = Project(name: "Test Short Fiction", type: .fiction)
        project.fictionClass = .shortFiction
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify folders exist in flat structure
        let folders = project.folders ?? []
        
        XCTAssertEqual(folders.count, 14, "Should have 14 folders for Short Fiction project")
        
        let folderNames = Set(folders.compactMap { $0.name })
        let expectedNames: Set<String> = [
            "Scenes", "Characters", "Locations", "Chapters", "Plot",
            "Collections", "Submissions", "Research",
            "Magazines", "Competitions", "Agents", "Publishers", "Other", "Trash"
        ]
        XCTAssertEqual(folderNames, expectedNames, "Should have correct folder names for Short Fiction")
    }
    
    func testCreateDefaultFoldersForDramaProject() throws {
        // Given a drama project
        let project = Project(name: "Test Drama", type: .drama)
        modelContext.insert(project)
        
        // When creating default folders
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        // Then verify folders exist in flat structure
        // Drama: Scripts, Collections, Submissions, Research, Competitions, Commissions, Other, Trash
        let folders = project.folders ?? []
        
        XCTAssertEqual(folders.count, 8, "Should have 8 folders for drama project")
        
        let folderNames = Set(folders.compactMap { $0.name })
        let expectedNames: Set<String> = [
            "Scripts", "Collections", "Submissions",
            "Research", "Competitions", "Commissions", "Other", "Trash"
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
        // Updated: Poems is now the content folder (replaces Draft)
        let fileOnlyNames = ["Poems", "Research"]
        
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
        // Updated: Workflow folders (All, Ready, Set Aside, Published) are removed
        // Collections, Manuscript, Trash are read-only
        let readOnlyNames = ["Collections", "Manuscript", "Trash"]
        
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
    
    func testFictionProjectFolderCapabilities() throws {
        // Given a fiction project with folders (Short Fiction)
        let project = Project(name: "Test Fiction", type: .fiction)
        project.fictionClass = .shortFiction
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        
        // Verify subfolder-only (📁) - Publications folders
        let subfolderOnly = ["Magazines", "Competitions", "Publishers", "Agents", "Other"]
        for name in subfolderOnly {
            if let folder = folders.first(where: { $0.name == name }) {
                XCTAssertTrue(FolderCapabilityService.canAddSubfolder(to: folder),
                             "\(name) should allow subfolders")
                XCTAssertFalse(FolderCapabilityService.canAddFile(to: folder),
                              "\(name) should NOT allow files")
            }
        }
        
        // Verify file-only (📄) - Scenes and Research
        let fileOnly = ["Scenes", "Research"]
        for name in fileOnly {
            if let folder = folders.first(where: { $0.name == name }) {
                XCTAssertFalse(FolderCapabilityService.canAddSubfolder(to: folder),
                              "\(name) should NOT allow subfolders")
                XCTAssertTrue(FolderCapabilityService.canAddFile(to: folder),
                             "\(name) should allow files")
            }
        }
        
        // Verify special fiction folders exist
        let fictionFolders = ["Scenes", "Characters", "Locations", "Plot", "Collections", "Submissions"]
        for name in fictionFolders {
            XCTAssertNotNil(folders.first(where: { $0.name == name }),
                           "\(name) folder should exist")
        }
        
        // Verify Trash is read-only
        if let trashFolder = folders.first(where: { $0.name == "Trash" }) {
            XCTAssertFalse(FolderCapabilityService.canAddSubfolder(to: trashFolder))
            XCTAssertFalse(FolderCapabilityService.canAddFile(to: trashFolder))
        }
    }
    
    func testNovelProjectHasChaptersFolder() throws {
        // Given a novel project
        let project = Project(name: "Test Novel", type: .fiction)
        project.fictionClass = .novel
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        
        // Novel should have both Chapters and Scenes folders
        XCTAssertNotNil(folders.first(where: { $0.name == "Chapters" }),
                       "Novel should have Chapters folder")
        XCTAssertNotNil(folders.first(where: { $0.name == "Scenes" }),
                       "Novel should have Scenes folder (content folder)")
    }
    
    func testShortFictionProjectHasScenesFolder() throws {
        // Given a short fiction project
        let project = Project(name: "Test Short Fiction", type: .fiction)
        project.fictionClass = .shortFiction
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        
        // Short Fiction should have both Scenes and Chapters folders
        XCTAssertNotNil(folders.first(where: { $0.name == "Scenes" }),
                       "Short Fiction should have Scenes folder")
        XCTAssertNotNil(folders.first(where: { $0.name == "Chapters" }),
                       "Short Fiction should have Chapters folder")
    }
    
    func testDramaProjectFolderCapabilities() throws {
        // Given a drama project with folders
        let project = Project(name: "Test Drama", type: .drama)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        
        // Verify subfolder-only (📁)
        let subfolderOnly = ["Competitions", "Commissions", "Other"]
        for name in subfolderOnly {
            if let folder = folders.first(where: { $0.name == name }) {
                XCTAssertTrue(FolderCapabilityService.canAddSubfolder(to: folder))
                XCTAssertFalse(FolderCapabilityService.canAddFile(to: folder))
            }
        }
        
        // Verify file-only (📄) - Scripts and Research
        let fileOnly = ["Scripts", "Research"]
        for name in fileOnly {
            if let folder = folders.first(where: { $0.name == name }) {
                XCTAssertFalse(FolderCapabilityService.canAddSubfolder(to: folder))
                XCTAssertTrue(FolderCapabilityService.canAddFile(to: folder))
            }
        }
        
        // Verify read-only (no manual additions)
        let readOnly = ["Collections", "Trash"]
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
        let project2 = Project(name: "Project 2", type: .generalPurpose)
        modelContext.insert(project1)
        modelContext.insert(project2)
        
        // When creating default folders for both
        ProjectTemplateService.createDefaultFolders(for: project1, in: modelContext)
        ProjectTemplateService.createDefaultFolders(for: project2, in: modelContext)
        
        // Then verify each has independent folder sets
        let folders1 = project1.folders ?? []
        let folders2 = project2.folders ?? []
        
        XCTAssertEqual(folders1.count, 10, "Project 1 (Poetry) should have 10 folders")
        XCTAssertEqual(folders2.count, 2, "Project 2 (General) should have 2 folders")
        
        // Verify no overlap in folder IDs
        let ids1 = Set(folders1.map { $0.id })
        let ids2 = Set(folders2.map { $0.id })
        XCTAssertTrue(ids1.isDisjoint(with: ids2), "Folder IDs should be unique across projects")
    }
    
    func testAllFoldersHaveProjectReference() throws {
        // Given a project with default folders
        let project = Project(name: "Test Project", type: .fiction)
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
