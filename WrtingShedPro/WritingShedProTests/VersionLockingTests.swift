//
//  VersionLockingTests.swift
//  WritingShedProTests
//
//  Feature 008b: Version Locking Tests
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class VersionLockingTests: XCTestCase {
    
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
    
    // MARK: - Version Locking Tests
    
    func testVersionNotLockedWhenNotSubmitted() throws {
        // Given - A file with no submissions
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Test Folder", project: project)
        let textFile = TextFile(name: "Test File", initialContent: "Content", parentFolder: folder)
        let version = textFile.currentVersion
        
        context.insert(project)
        context.insert(folder)
        context.insert(textFile)
        try context.save()
        
        // Then - Version should not be locked
        XCTAssertFalse(version?.isLocked ?? true, "Version should not be locked when not submitted")
        XCTAssertTrue(version?.referencingSubmissions.isEmpty ?? false, "Should have no referencing submissions")
    }
    
    func testVersionLockedWhenSubmitted() throws {
        // Given - A file submitted to a publication
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Test Folder", project: project)
        let textFile = TextFile(name: "Test File", initialContent: "Content", parentFolder: folder)
        let version = textFile.currentVersion
        
        let publication = Publication(name: "Test Magazine", project: project)
        let submission = Submission(publication: publication, project: project)
        
        context.insert(project)
        context.insert(folder)
        context.insert(textFile)
        context.insert(publication)
        context.insert(submission)
        
        let submittedFile = SubmittedFile(
            submission: submission,
            textFile: textFile,
            version: version,
            status: .pending,
            project: project
        )
        context.insert(submittedFile)
        try context.save()
        
        // Then - Version should be locked
        XCTAssertTrue(version?.isLocked ?? false, "Version should be locked when submitted")
        XCTAssertEqual(version?.referencingSubmissions.count, 1, "Should have one referencing submission")
    }
    
    func testVersionLockedWithMultipleSubmissions() throws {
        // Given - A file submitted to multiple publications
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Test Folder", project: project)
        let textFile = TextFile(name: "Test File", initialContent: "Content", parentFolder: folder)
        let version = textFile.currentVersion
        
        let publication1 = Publication(name: "Magazine 1", project: project)
        let publication2 = Publication(name: "Magazine 2", project: project)
        let submission1 = Submission(publication: publication1, project: project)
        let submission2 = Submission(publication: publication2, project: project)
        
        context.insert(project)
        context.insert(folder)
        context.insert(textFile)
        context.insert(publication1)
        context.insert(publication2)
        context.insert(submission1)
        context.insert(submission2)
        
        let submittedFile1 = SubmittedFile(
            submission: submission1,
            textFile: textFile,
            version: version,
            status: .pending,
            project: project
        )
        let submittedFile2 = SubmittedFile(
            submission: submission2,
            textFile: textFile,
            version: version,
            status: .pending,
            project: project
        )
        
        context.insert(submittedFile1)
        context.insert(submittedFile2)
        try context.save()
        
        // Then - Version should be locked with multiple references
        XCTAssertTrue(version?.isLocked ?? false, "Version should be locked when submitted to multiple publications")
        XCTAssertEqual(version?.referencingSubmissions.count, 2, "Should have two referencing submissions")
    }
    
    func testNewVersionNotLockedAfterEdit() throws {
        // Given - A file with a submitted version that is edited
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Test Folder", project: project)
        let textFile = TextFile(name: "Test File", initialContent: "Original content", parentFolder: folder)
        let originalVersion = textFile.currentVersion
        
        let publication = Publication(name: "Test Magazine", project: project)
        let submission = Submission(publication: publication, project: project)
        
        context.insert(project)
        context.insert(folder)
        context.insert(textFile)
        context.insert(publication)
        context.insert(submission)
        
        let submittedFile = SubmittedFile(
            submission: submission,
            textFile: textFile,
            version: originalVersion,
            status: .pending,
            project: project
        )
        context.insert(submittedFile)
        try context.save()
        
        // When - File is edited (creating a new version)
        textFile.updateContent(NSAttributedString(string: "Updated content"))
        try context.save()
        
        let newVersion = textFile.currentVersion
        
        // Then - Original version is locked, new version is not
        XCTAssertTrue(originalVersion?.isLocked ?? false, "Original submitted version should remain locked")
        XCTAssertFalse(newVersion?.isLocked ?? true, "New version should not be locked")
        XCTAssertNotEqual(originalVersion?.id, newVersion?.id, "Should have different version IDs")
    }
    
    func testVersionLockedEvenAfterStatusChange() throws {
        // Given - A file submitted and then accepted
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Test Folder", project: project)
        let textFile = TextFile(name: "Test File", initialContent: "Content", parentFolder: folder)
        let version = textFile.currentVersion
        
        let publication = Publication(name: "Test Magazine", project: project)
        let submission = Submission(publication: publication, project: project)
        
        context.insert(project)
        context.insert(folder)
        context.insert(textFile)
        context.insert(publication)
        context.insert(submission)
        
        let submittedFile = SubmittedFile(
            submission: submission,
            textFile: textFile,
            version: version,
            status: .pending,
            project: project
        )
        context.insert(submittedFile)
        try context.save()
        
        // When - Status changes to accepted
        submittedFile.status = .accepted
        submittedFile.statusDate = Date()
        try context.save()
        
        // Then - Version should still be locked
        XCTAssertTrue(version?.isLocked ?? false, "Version should remain locked after status change")
        XCTAssertEqual(submittedFile.status, .accepted, "Status should be updated to accepted")
    }
    
    func testVersionLockedEvenAfterRejection() throws {
        // Given - A file submitted and then rejected
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Test Folder", project: project)
        let textFile = TextFile(name: "Test File", initialContent: "Content", parentFolder: folder)
        let version = textFile.currentVersion
        
        let publication = Publication(name: "Test Magazine", project: project)
        let submission = Submission(publication: publication, project: project)
        
        context.insert(project)
        context.insert(folder)
        context.insert(textFile)
        context.insert(publication)
        context.insert(submission)
        
        let submittedFile = SubmittedFile(
            submission: submission,
            textFile: textFile,
            version: version,
            status: .pending,
            project: project
        )
        context.insert(submittedFile)
        try context.save()
        
        // When - Status changes to rejected
        submittedFile.status = .rejected
        submittedFile.statusDate = Date()
        try context.save()
        
        // Then - Version should still be locked (maintains submission history)
        XCTAssertTrue(version?.isLocked ?? false, "Version should remain locked after rejection")
        XCTAssertEqual(submittedFile.status, .rejected, "Status should be updated to rejected")
    }
    
    func testReferencingSubmissionsReturnsCorrectData() throws {
        // Given - A version submitted to two publications
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Test Folder", project: project)
        let textFile = TextFile(name: "Test File", initialContent: "Content", parentFolder: folder)
        let version = textFile.currentVersion
        
        let publication1 = Publication(name: "Magazine 1", project: project)
        let publication2 = Publication(name: "Competition", type: .competition, project: project)
        let submission1 = Submission(publication: publication1, project: project)
        let submission2 = Submission(publication: publication2, project: project)
        
        context.insert(project)
        context.insert(folder)
        context.insert(textFile)
        context.insert(publication1)
        context.insert(publication2)
        context.insert(submission1)
        context.insert(submission2)
        
        let submittedFile1 = SubmittedFile(
            submission: submission1,
            textFile: textFile,
            version: version,
            status: .accepted,
            project: project
        )
        let submittedFile2 = SubmittedFile(
            submission: submission2,
            textFile: textFile,
            version: version,
            status: .pending,
            project: project
        )
        
        context.insert(submittedFile1)
        context.insert(submittedFile2)
        try context.save()
        
        // Then - Should return both submitted files
        let referencingSubmissions = version?.referencingSubmissions ?? []
        XCTAssertEqual(referencingSubmissions.count, 2, "Should have two referencing submissions")
        
        let acceptedSubmission = referencingSubmissions.first { $0.status == .accepted }
        let pendingSubmission = referencingSubmissions.first { $0.status == .pending }
        
        XCTAssertNotNil(acceptedSubmission, "Should have accepted submission")
        XCTAssertNotNil(pendingSubmission, "Should have pending submission")
    }
}
