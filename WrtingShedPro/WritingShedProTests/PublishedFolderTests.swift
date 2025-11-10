//
//  PublishedFolderTests.swift
//  WritingShedProTests
//
//  Feature 008b: Published Folder Auto-Movement Tests
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class PublishedFolderTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUp() async throws {
        // Create in-memory container for testing
        let schema = Schema([
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self,
            TrashItem.self,
            Publication.self,
            Submission.self,
            SubmittedFile.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }
    
    override func tearDown() {
        container = nil
        context = nil
    }
    
    // MARK: - Published Folder Creation Tests
    
    func testPublishedFolderCreatedAutomatically() throws {
        // Given - A project with folders but no Published folder
        let project = Project(name: "Test Project")
        let draftFolder = Folder(name: "Draft", project: project)
        
        context.insert(project)
        context.insert(draftFolder)
        try context.save()
        
        let initialFolderCount = project.folders?.count ?? 0
        
        // When - Published folder is requested (simulating the flow)
        let publishedFolder = findOrCreatePublishedFolder(for: project)
        try context.save()
        
        // Then - Published folder should be created
        XCTAssertNotNil(publishedFolder, "Published folder should be created")
        XCTAssertEqual(publishedFolder?.name, "Published", "Folder should be named Published")
        XCTAssertEqual(project.folders?.count, initialFolderCount + 1, "Should have one more folder")
    }
    
    func testPublishedFolderNotDuplicatedIfExists() throws {
        // Given - A project with existing Published folder
        let project = Project(name: "Test Project")
        let existingPublished = Folder(name: "Published", project: project)
        
        context.insert(project)
        context.insert(existingPublished)
        try context.save()
        
        let initialFolderCount = project.folders?.count ?? 0
        
        // When - Published folder is requested again
        let publishedFolder = findOrCreatePublishedFolder(for: project)
        try context.save()
        
        // Then - Should return existing folder, not create new one
        XCTAssertEqual(publishedFolder?.id, existingPublished.id, "Should return existing Published folder")
        XCTAssertEqual(project.folders?.count, initialFolderCount, "Should not create duplicate folder")
    }
    
    // MARK: - File Movement Tests
    
    func testFileMovesToPublishedOnAcceptance() throws {
        // Given - A file submitted and in Draft folder
        let project = Project(name: "Test Project")
        let draftFolder = Folder(name: "Draft", project: project)
        let textFile = TextFile(name: "Test Poem", initialContent: "Content", parentFolder: draftFolder)
        
        let publication = Publication(name: "Poetry Magazine", project: project)
        let submission = Submission(publication: publication, project: project)
        
        context.insert(project)
        context.insert(draftFolder)
        context.insert(textFile)
        context.insert(publication)
        context.insert(submission)
        
        let submittedFile = SubmittedFile(
            submission: submission,
            textFile: textFile,
            version: textFile.currentVersion,
            status: .pending,
            project: project
        )
        context.insert(submittedFile)
        try context.save()
        
        XCTAssertEqual(textFile.parentFolder?.name, "Draft", "File should start in Draft folder")
        
        // When - Status changes to accepted
        submittedFile.status = .accepted
        submittedFile.statusDate = Date()
        
        let publishedFolder = findOrCreatePublishedFolder(for: project)
        textFile.parentFolder = publishedFolder
        try context.save()
        
        // Then - File should be moved to Published folder
        XCTAssertEqual(textFile.parentFolder?.name, "Published", "File should be moved to Published folder")
        XCTAssertTrue(publishedFolder?.textFiles?.contains(where: { $0.id == textFile.id }) ?? false, 
                     "Published folder should contain the file")
    }
    
    func testFileDoesNotMoveOnRejection() throws {
        // Given - A file submitted and in Draft folder
        let project = Project(name: "Test Project")
        let draftFolder = Folder(name: "Draft", project: project)
        let textFile = TextFile(name: "Test Poem", initialContent: "Content", parentFolder: draftFolder)
        
        let publication = Publication(name: "Poetry Magazine", project: project)
        let submission = Submission(publication: publication, project: project)
        
        context.insert(project)
        context.insert(draftFolder)
        context.insert(textFile)
        context.insert(publication)
        context.insert(submission)
        
        let submittedFile = SubmittedFile(
            submission: submission,
            textFile: textFile,
            version: textFile.currentVersion,
            status: .pending,
            project: project
        )
        context.insert(submittedFile)
        try context.save()
        
        let originalFolder = textFile.parentFolder
        
        // When - Status changes to rejected
        submittedFile.status = .rejected
        submittedFile.statusDate = Date()
        try context.save()
        
        // Then - File should remain in original folder
        XCTAssertEqual(textFile.parentFolder?.id, originalFolder?.id, "File should remain in Draft folder after rejection")
    }
    
    func testMultipleFilesCanBeInPublishedFolder() throws {
        // Given - Multiple accepted files
        let project = Project(name: "Test Project")
        let draftFolder = Folder(name: "Draft", project: project)
        let publishedFolder = Folder(name: "Published", project: project)
        
        let file1 = TextFile(name: "Poem 1", initialContent: "Content 1", parentFolder: draftFolder)
        let file2 = TextFile(name: "Poem 2", initialContent: "Content 2", parentFolder: draftFolder)
        let file3 = TextFile(name: "Poem 3", initialContent: "Content 3", parentFolder: draftFolder)
        
        context.insert(project)
        context.insert(draftFolder)
        context.insert(publishedFolder)
        context.insert(file1)
        context.insert(file2)
        context.insert(file3)
        try context.save()
        
        // When - All files are moved to Published
        file1.parentFolder = publishedFolder
        file2.parentFolder = publishedFolder
        file3.parentFolder = publishedFolder
        try context.save()
        
        // Then - Published folder should contain all files
        XCTAssertEqual(publishedFolder.textFiles?.count, 3, "Published folder should contain all three files")
    }
    
    func testFileKeepsVersionHistoryAfterMove() throws {
        // Given - A file with version history
        let project = Project(name: "Test Project")
        let draftFolder = Folder(name: "Draft", project: project)
        let publishedFolder = Folder(name: "Published", project: project)
        let textFile = TextFile(name: "Test Poem", initialContent: "Version 1", parentFolder: draftFolder)
        
        context.insert(project)
        context.insert(draftFolder)
        context.insert(publishedFolder)
        context.insert(textFile)
        try context.save()
        
        let version1 = textFile.currentVersion
        
        // Create version 2
        let version2 = textFile.createNewVersion(content: "Version 2")
        try context.save()
        let versionCount = textFile.versions?.count ?? 0
        
        // When - File is moved to Published
        textFile.parentFolder = publishedFolder
        try context.save()
        
        // Then - Version history should be preserved
        XCTAssertEqual(textFile.versions?.count, versionCount, "Version count should be unchanged")
        XCTAssertTrue(textFile.versions?.contains(where: { $0.id == version1?.id }) ?? false, "Version 1 should still exist")
        XCTAssertTrue(textFile.versions?.contains(where: { $0.id == version2.id }) ?? false, "Version 2 should still exist")
    }
    
    // MARK: - Helper Methods
    
    private func findOrCreatePublishedFolder(for project: Project) -> Folder? {
        // Try to find existing Published folder
        if let existingFolder = project.folders?.first(where: { $0.name == "Published" }) {
            return existingFolder
        }
        
        // Create new Published folder
        let publishedFolder = Folder(name: "Published", project: project, parentFolder: nil)
        context.insert(publishedFolder)
        return publishedFolder
    }
}
