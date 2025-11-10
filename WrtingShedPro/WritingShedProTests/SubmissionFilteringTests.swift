//
//  SubmissionFilteringTests.swift
//  WritingShedProTests
//
//  Feature 008b: Submission File Filtering Tests
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class SubmissionFilteringTests: XCTestCase {
    
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
    
    // MARK: - File Eligibility Tests
    
    func testFileInSameProjectIsEligible() throws {
        // Given - A file in the same project
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Draft", project: project)
        let textFile = TextFile(name: "Test Poem", initialContent: "Content", parentFolder: folder)
        let publication = Publication(name: "Poetry Magazine", project: project)
        
        context.insert(project)
        context.insert(folder)
        context.insert(textFile)
        context.insert(publication)
        try context.save()
        
        // Then - File should be eligible for submission
        XCTAssertTrue(belongsToProject(file: textFile, project: project), 
                     "File in same project should be eligible")
    }
    
    func testFileInDifferentProjectNotEligible() throws {
        // Given - A file in a different project
        let project1 = Project(name: "Project 1")
        let project2 = Project(name: "Project 2")
        let folder = Folder(name: "Draft", project: project2)
        let textFile = TextFile(name: "Test Poem", initialContent: "Content", parentFolder: folder)
        let publication = Publication(name: "Poetry Magazine", project: project1)
        
        context.insert(project1)
        context.insert(project2)
        context.insert(folder)
        context.insert(textFile)
        context.insert(publication)
        try context.save()
        
        // Then - File should not be eligible
        XCTAssertFalse(belongsToProject(file: textFile, project: project1), 
                      "File in different project should not be eligible")
    }
    
    func testUnsubmittedFileIsEligible() throws {
        // Given - A file that hasn't been submitted anywhere
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Draft", project: project)
        let textFile = TextFile(name: "Test Poem", initialContent: "Content", parentFolder: folder)
        let publication = Publication(name: "Poetry Magazine", project: project)
        
        context.insert(project)
        context.insert(folder)
        context.insert(textFile)
        context.insert(publication)
        try context.save()
        
        // Then - File should be eligible
        XCTAssertFalse(isAlreadySubmitted(file: textFile, publication: publication), 
                      "Unsubmitted file should be eligible")
    }
    
    func testSubmittedVersionNotEligibleForSamePublication() throws {
        // Given - A file already submitted to a publication
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Draft", project: project)
        let textFile = TextFile(name: "Test Poem", initialContent: "Content", parentFolder: folder)
        let publication = Publication(name: "Poetry Magazine", project: project)
        let submission = Submission(publication: publication, project: project)
        
        context.insert(project)
        context.insert(folder)
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
        
        // Then - Same version should not be eligible for same publication
        XCTAssertTrue(isAlreadySubmitted(file: textFile, publication: publication), 
                     "Already submitted version should not be eligible for same publication")
    }
    
    func testNewVersionEligibleAfterEdit() throws {
        // Given - A file with v1 submitted, then edited to create v2
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Draft", project: project)
        let textFile = TextFile(name: "Test Poem", initialContent: "Version 1", parentFolder: folder)
        let publication = Publication(name: "Poetry Magazine", project: project)
        let submission = Submission(publication: publication, project: project)
        
        context.insert(project)
        context.insert(folder)
        context.insert(textFile)
        context.insert(publication)
        context.insert(submission)
        
        let version1 = textFile.currentVersion
        let submittedFile = SubmittedFile(
            submission: submission,
            textFile: textFile,
            version: version1,
            status: .pending,
            project: project
        )
        context.insert(submittedFile)
        try context.save()
        
        // When - File is edited, creating version 2
        let version2 = textFile.createNewVersion(content: "Version 2")
        try context.save()
        
        // Then - Version 2 should be eligible (version 1 is already submitted)
        // In the actual app, this is checked by comparing version numbers
        XCTAssertNotEqual(version1?.versionNumber, version2?.versionNumber, 
                         "Should have different version numbers")
        XCTAssertTrue(version1?.isLocked ?? false, "Version 1 should be locked")
        XCTAssertFalse(version2?.isLocked ?? true, "Version 2 should not be locked")
    }
    
    func testFileEligibleForDifferentPublication() throws {
        // Given - A file submitted to Publication A
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Draft", project: project)
        let textFile = TextFile(name: "Test Poem", initialContent: "Content", parentFolder: folder)
        let publicationA = Publication(name: "Magazine A", project: project)
        let publicationB = Publication(name: "Magazine B", project: project)
        let submission = Submission(publication: publicationA, project: project)
        
        context.insert(project)
        context.insert(folder)
        context.insert(textFile)
        context.insert(publicationA)
        context.insert(publicationB)
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
        
        // Then - File should be eligible for Publication B
        XCTAssertTrue(isAlreadySubmitted(file: textFile, publication: publicationA), 
                     "Should be marked as submitted to Publication A")
        XCTAssertFalse(isAlreadySubmitted(file: textFile, publication: publicationB), 
                      "Should NOT be marked as submitted to Publication B")
    }
    
    func testRejectedVersionNotEligibleForResubmission() throws {
        // Given - A file submitted and rejected from a publication
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Draft", project: project)
        let textFile = TextFile(name: "Test Poem", initialContent: "Content", parentFolder: folder)
        let publication = Publication(name: "Poetry Magazine", project: project)
        let submission = Submission(publication: publication, project: project)
        
        context.insert(project)
        context.insert(folder)
        context.insert(textFile)
        context.insert(publication)
        context.insert(submission)
        
        let submittedFile = SubmittedFile(
            submission: submission,
            textFile: textFile,
            version: textFile.currentVersion,
            status: .rejected,
            statusDate: Date(),
            project: project
        )
        context.insert(submittedFile)
        try context.save()
        
        // Then - Same version should not be eligible for resubmission
        XCTAssertTrue(isAlreadySubmitted(file: textFile, publication: publication), 
                     "Rejected version should not be eligible for resubmission")
    }
    
    func testAcceptedVersionNotEligibleForResubmission() throws {
        // Given - A file accepted by a publication
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Draft", project: project)
        let textFile = TextFile(name: "Test Poem", initialContent: "Content", parentFolder: folder)
        let publication = Publication(name: "Poetry Magazine", project: project)
        let submission = Submission(publication: publication, project: project)
        
        context.insert(project)
        context.insert(folder)
        context.insert(textFile)
        context.insert(publication)
        context.insert(submission)
        
        let submittedFile = SubmittedFile(
            submission: submission,
            textFile: textFile,
            version: textFile.currentVersion,
            status: .accepted,
            statusDate: Date(),
            project: project
        )
        context.insert(submittedFile)
        try context.save()
        
        // Then - Same version should not be eligible for resubmission
        XCTAssertTrue(isAlreadySubmitted(file: textFile, publication: publication), 
                     "Accepted version should not be eligible for resubmission")
    }
    
    // MARK: - Helper Methods (mimicking AddSubmissionView logic)
    
    private func belongsToProject(file: TextFile, project: Project) -> Bool {
        var currentFolder = file.parentFolder
        while let folder = currentFolder {
            if folder.project?.id == project.id {
                return true
            }
            currentFolder = folder.parentFolder
        }
        return false
    }
    
    private func isAlreadySubmitted(file: TextFile, publication: Publication) -> Bool {
        guard let currentVersion = file.currentVersion else { return false }
        
        // Check if this file + version combination is already submitted to this publication
        let submissions = publication.submissions ?? []
        for submission in submissions {
            let submittedFiles = submission.submittedFiles ?? []
            for submittedFile in submittedFiles {
                if submittedFile.textFile?.id == file.id &&
                   submittedFile.version?.versionNumber == currentVersion.versionNumber {
                    return true
                }
            }
        }
        return false
    }
}
