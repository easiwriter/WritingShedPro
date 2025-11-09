//
//  PublicationModelTests.swift
//  WritingShedProTests
//
//  Feature 008b Phase 1: Publication Management System - Model Tests
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class PublicationModelTests: XCTestCase {
    
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
    
    // MARK: - Publication Tests
    
    func testPublicationCreation() throws {
        // Given
        let project = Project(name: "Test Project")
        context.insert(project)
        
        let publication = Publication(
            name: "Test Magazine",
            type: .magazine,
            url: "https://example.com",
            notes: "Test notes",
            deadline: Date().addingTimeInterval(86400 * 30), // 30 days from now
            project: project
        )
        
        // When
        context.insert(publication)
        try context.save()
        
        // Then
        XCTAssertEqual(publication.name, "Test Magazine")
        XCTAssertEqual(publication.type, .magazine)
        XCTAssertEqual(publication.url, "https://example.com")
        XCTAssertEqual(publication.notes, "Test notes")
        XCTAssertNotNil(publication.deadline)
        XCTAssertNotNil(publication.project)
        XCTAssertEqual(publication.submissions?.count ?? 0, 0)
    }
    
    func testPublicationWithOptionalType() throws {
        // Given - Test CloudKit compatibility with optional enum
        let publication = Publication(name: "Unknown Type")
        publication.type = nil
        
        // When
        context.insert(publication)
        try context.save()
        
        // Then
        XCTAssertNil(publication.type)
        XCTAssertEqual(publication.name, "Unknown Type")
    }
    
    func testPublicationDeadlineComputedProperties() throws {
        // Given - Publication with deadline 15 days in future
        let futureDate = Calendar.current.date(byAdding: .day, value: 15, to: Date())!
        let publication = Publication(name: "Future Deadline", deadline: futureDate)
        context.insert(publication)
        
        // Then
        XCTAssertTrue(publication.hasDeadline)
        XCTAssertEqual(publication.daysUntilDeadline, 15)
        XCTAssertFalse(publication.isDeadlinePassed)
        XCTAssertTrue(publication.isDeadlineApproaching)
        XCTAssertEqual(publication.deadlineStatus, .approaching)
    }
    
    func testPublicationPassedDeadline() throws {
        // Given - Publication with deadline 5 days in past
        let pastDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let publication = Publication(name: "Past Deadline", deadline: pastDate)
        context.insert(publication)
        
        // Then
        XCTAssertTrue(publication.hasDeadline)
        XCTAssertTrue(publication.isDeadlinePassed)
        XCTAssertFalse(publication.isDeadlineApproaching)
        XCTAssertEqual(publication.deadlineStatus, .passed)
    }
    
    func testPublicationNoDeadline() throws {
        // Given
        let publication = Publication(name: "No Deadline")
        context.insert(publication)
        
        // Then
        XCTAssertFalse(publication.hasDeadline)
        XCTAssertNil(publication.daysUntilDeadline)
        XCTAssertFalse(publication.isDeadlinePassed)
        XCTAssertFalse(publication.isDeadlineApproaching)
        XCTAssertEqual(publication.deadlineStatus, .none)
    }
    
    // MARK: - Submission Tests
    
    func testSubmissionCreation() throws {
        // Given
        let project = Project(name: "Test Project")
        context.insert(project)
        
        let publication = Publication(name: "Test Magazine", project: project)
        context.insert(publication)
        
        let submission = Submission(
            publication: publication,
            project: project,
            submittedDate: Date(),
            notes: "Test submission"
        )
        
        // When
        context.insert(submission)
        try context.save()
        
        // Then
        XCTAssertEqual(submission.publication?.name, "Test Magazine")
        XCTAssertEqual(submission.project?.name, "Test Project")
        XCTAssertNotNil(submission.submittedDate)
        XCTAssertEqual(submission.notes, "Test submission")
        XCTAssertEqual(submission.fileCount, 0)
    }
    
    func testSubmissionComputedProperties() throws {
        // Given
        let project = Project(name: "Test Project")
        context.insert(project)
        
        let publication = Publication(name: "Test Magazine", project: project)
        context.insert(publication)
        
        let submission = Submission(publication: publication, project: project)
        context.insert(submission)
        
        // Create submitted files with different statuses
        let pendingFile = SubmittedFile(submission: submission, status: .pending, project: project)
        let acceptedFile = SubmittedFile(submission: submission, status: .accepted, project: project)
        let rejectedFile = SubmittedFile(submission: submission, status: .rejected, project: project)
        
        context.insert(pendingFile)
        context.insert(acceptedFile)
        context.insert(rejectedFile)
        
        try context.save()
        
        // Then
        XCTAssertEqual(submission.fileCount, 3)
        XCTAssertEqual(submission.pendingCount, 1)
        XCTAssertEqual(submission.acceptedCount, 1)
        XCTAssertEqual(submission.rejectedCount, 1)
        XCTAssertEqual(submission.overallStatus, .partiallyAccepted)
    }
    
    func testSubmissionOverallStatusAllAccepted() throws {
        // Given
        let project = Project(name: "Test Project")
        let publication = Publication(name: "Test Magazine", project: project)
        let submission = Submission(publication: publication, project: project)
        
        context.insert(project)
        context.insert(publication)
        context.insert(submission)
        
        let acceptedFile1 = SubmittedFile(submission: submission, status: .accepted, project: project)
        let acceptedFile2 = SubmittedFile(submission: submission, status: .accepted, project: project)
        
        context.insert(acceptedFile1)
        context.insert(acceptedFile2)
        
        try context.save()
        
        // Then
        XCTAssertEqual(submission.overallStatus, .allAccepted)
    }
    
    // MARK: - SubmittedFile Tests
    
    func testSubmittedFileCreation() throws {
        // Given
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
            statusDate: Date(),
            statusNotes: "Awaiting response",
            project: project
        )
        
        // When
        context.insert(submittedFile)
        try context.save()
        
        // Then
        XCTAssertEqual(submittedFile.submission?.id, submission.id)
        XCTAssertEqual(submittedFile.textFile?.name, "Test File")
        XCTAssertEqual(submittedFile.version?.id, version?.id)
        XCTAssertEqual(submittedFile.status, .pending)
        XCTAssertNotNil(submittedFile.statusDate)
        XCTAssertEqual(submittedFile.statusNotes, "Awaiting response")
    }
    
    func testSubmittedFileWithOptionalStatus() throws {
        // Given - Test CloudKit compatibility with optional enum
        let project = Project(name: "Test Project")
        let submission = Submission(publication: Publication(name: "Test"), project: project)
        let submittedFile = SubmittedFile(submission: submission, project: project)
        submittedFile.status = nil
        
        context.insert(project)
        context.insert(submission)
        context.insert(submittedFile)
        
        // When
        try context.save()
        
        // Then
        XCTAssertNil(submittedFile.status)
        XCTAssertNil(submittedFile.acceptanceDate)
        XCTAssertNil(submittedFile.rejectionDate)
    }
    
    func testSubmittedFileAcceptanceDate() throws {
        // Given
        let project = Project(name: "Test Project")
        let submission = Submission(publication: Publication(name: "Test"), project: project)
        let acceptanceDate = Date()
        
        let submittedFile = SubmittedFile(
            submission: submission,
            status: .accepted,
            statusDate: acceptanceDate,
            project: project
        )
        
        context.insert(project)
        context.insert(submission)
        context.insert(submittedFile)
        
        // Then
        XCTAssertEqual(submittedFile.acceptanceDate, acceptanceDate)
        XCTAssertNil(submittedFile.rejectionDate)
    }
    
    func testSubmittedFileRejectionDate() throws {
        // Given
        let project = Project(name: "Test Project")
        let submission = Submission(publication: Publication(name: "Test"), project: project)
        let rejectionDate = Date()
        
        let submittedFile = SubmittedFile(
            submission: submission,
            status: .rejected,
            statusDate: rejectionDate,
            project: project
        )
        
        context.insert(project)
        context.insert(submission)
        context.insert(submittedFile)
        
        // Then
        XCTAssertNil(submittedFile.acceptanceDate)
        XCTAssertEqual(submittedFile.rejectionDate, rejectionDate)
    }
    
    // MARK: - Relationship Tests
    
    func testPublicationProjectRelationship() throws {
        // Given
        let project = Project(name: "Test Project")
        context.insert(project)
        
        let publication1 = Publication(name: "Magazine 1", project: project)
        let publication2 = Publication(name: "Magazine 2", project: project)
        
        context.insert(publication1)
        context.insert(publication2)
        
        try context.save()
        
        // Then - Bidirectional relationship
        XCTAssertEqual(publication1.project?.name, "Test Project")
        XCTAssertEqual(publication2.project?.name, "Test Project")
        XCTAssertEqual(project.publications?.count ?? 0, 2)
    }
    
    func testSubmissionRelationships() throws {
        // Given
        let project = Project(name: "Test Project")
        let publication = Publication(name: "Test Magazine", project: project)
        let submission = Submission(publication: publication, project: project)
        
        context.insert(project)
        context.insert(publication)
        context.insert(submission)
        
        try context.save()
        
        // Then - Multiple bidirectional relationships
        XCTAssertEqual(submission.publication?.name, "Test Magazine")
        XCTAssertEqual(submission.project?.name, "Test Project")
        XCTAssertEqual(publication.submissions?.count ?? 0, 1)
        XCTAssertEqual(project.submissions?.count ?? 0, 1)
    }
    
    func testSubmittedFileRelationships() throws {
        // Given
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Test Folder", project: project)
        let textFile = TextFile(name: "Test File", initialContent: "Content", parentFolder: folder)
        let version = textFile.currentVersion
        
        let publication = Publication(name: "Test Magazine", project: project)
        let submission = Submission(publication: publication, project: project)
        let submittedFile = SubmittedFile(
            submission: submission,
            textFile: textFile,
            version: version,
            project: project
        )
        
        context.insert(project)
        context.insert(folder)
        context.insert(textFile)
        context.insert(publication)
        context.insert(submission)
        context.insert(submittedFile)
        
        try context.save()
        
        // Then - All bidirectional relationships work
        XCTAssertEqual(submittedFile.textFile?.name, "Test File")
        XCTAssertEqual(submittedFile.version?.id, version?.id)
        XCTAssertEqual(submittedFile.submission?.id, submission.id)
        XCTAssertEqual(submittedFile.project?.name, "Test Project")
        
        XCTAssertEqual(textFile.submittedFiles?.count ?? 0, 1)
        XCTAssertEqual(version?.submittedFiles?.count ?? 0, 1)
        XCTAssertEqual(submission.submittedFiles?.count ?? 0, 1)
        XCTAssertEqual(project.submittedFiles?.count ?? 0, 1)
    }
    
    // MARK: - Enum Tests
    
    func testPublicationTypeEnum() throws {
        // Given
        let magazine = Publication(name: "Magazine", type: .magazine)
        let competition = Publication(name: "Competition", type: .competition)
        
        // Then
        XCTAssertEqual(magazine.type?.displayName, "Magazine")
        XCTAssertEqual(magazine.type?.icon, "📰")
        
        XCTAssertEqual(competition.type?.displayName, "Competition")
        XCTAssertEqual(competition.type?.icon, "🏆")
    }
    
    func testSubmissionStatusEnum() throws {
        // Given
        let pending = SubmissionStatus.pending
        let accepted = SubmissionStatus.accepted
        let rejected = SubmissionStatus.rejected
        
        // Then
        XCTAssertEqual(pending.displayName, "Pending")
        XCTAssertEqual(pending.icon, "⏳")
        
        XCTAssertEqual(accepted.displayName, "Accepted")
        XCTAssertEqual(accepted.icon, "✓")
        
        XCTAssertEqual(rejected.displayName, "Rejected")
        XCTAssertEqual(rejected.icon, "✗")
    }
}
