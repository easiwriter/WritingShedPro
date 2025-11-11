import XCTest
import SwiftData
@testable import Writing_Shed_Pro

/// Tests for Feature 008c Phase 4-6: Collection editing, deletion, naming, and publication integration
final class CollectionsPhase456Tests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testProject: Project!
    var readyFolder: Folder!
    var testCollection: Submission!
    
    override func setUp() {
        super.setUp()
        let schema = Schema([
            Project.self, Folder.self, TextFile.self, Version.self, TrashItem.self,
            Submission.self, SubmittedFile.self, Publication.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)
        
        testProject = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(testProject)
        ProjectTemplateService.createDefaultFolders(for: testProject, in: modelContext)
        
        let folders = testProject.folders ?? []
        readyFolder = folders.first { $0.name == "Ready" }!
        
        testCollection = Submission(publication: nil, project: testProject)
        testCollection.name = "Test Collection"
        modelContext.insert(testCollection)
        
        try! modelContext.save()
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        testProject = nil
        readyFolder = nil
        testCollection = nil
        super.tearDown()
    }
    
    // MARK: - Phase 4.1: Edit Version Tests
    
    func testChangeVersionForExistingFile() throws {
        // Given a file with multiple versions in a collection
        let testFile = TextFile(name: "Test File", initialContent: "Version 1", parentFolder: readyFolder)
        let fileV1 = testFile.currentVersion
        testFile.createNewVersion(content: "Version 2")
        let fileV2 = testFile.currentVersion
        testFile.createNewVersion(content: "Version 3")
        let fileV3 = testFile.currentVersion
        
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        
        let submittedFile = SubmittedFile(
            submission: testCollection,
            textFile: testFile,
            version: fileV3,
            status: .pending
        )
        modelContext.insert(submittedFile)
        testCollection.submittedFiles = [submittedFile]
        try! modelContext.save()
        
        // When changing to a different version
        submittedFile.version = fileV1  // Change to first version
        try! modelContext.save()
        
        // Then version should be updated
        XCTAssertEqual(submittedFile.version?.content, "Version 1")
    }
    
    func testChangeMultipleVersionsInCollection() throws {
        // Given collection with multiple files
        let file1 = TextFile(name: "File 1", initialContent: "F1V1", parentFolder: readyFolder)
        let file1V1 = file1.currentVersion
        file1.createNewVersion(content: "F1V2")
        
        let file2 = TextFile(name: "File 2", initialContent: "F2V1", parentFolder: readyFolder)
        let file2V1 = file2.currentVersion
        file2.createNewVersion(content: "F2V2")
        
        modelContext.insert(file1)
        modelContext.insert(file2)
        readyFolder.textFiles = [file1, file2]
        
        let sf1 = SubmittedFile(submission: testCollection, textFile: file1, version: file1.currentVersion, status: .pending)
        let sf2 = SubmittedFile(submission: testCollection, textFile: file2, version: file2.currentVersion, status: .pending)
        
        modelContext.insert(sf1)
        modelContext.insert(sf2)
        testCollection.submittedFiles = [sf1, sf2]
        try! modelContext.save()
        
        // When changing both versions to the first version
        sf1.version = file1V1
        sf2.version = file2V1
        try! modelContext.save()
        
        // Then both should update independently
        XCTAssertEqual(sf1.version?.content, "F1V1")
        XCTAssertEqual(sf2.version?.content, "F2V1")
    }
    
    func testVersionChangePreservesOtherMetadata() throws {
        // Given a file in collection with status and notes
        let testFile = TextFile(name: "Test File", initialContent: "V1", parentFolder: readyFolder)
        testFile.createNewVersion(content: "V2")
        
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        
        let submittedFile = SubmittedFile(
            submission: testCollection,
            textFile: testFile,
            version: testFile.versions?[0],
            status: .accepted
        )
        submittedFile.statusNotes = "Test notes"
        
        modelContext.insert(submittedFile)
        testCollection.submittedFiles = [submittedFile]
        try! modelContext.save()
        
        // When changing version
        submittedFile.version = testFile.currentVersion
        try! modelContext.save()
        
        // Then status and notes should be preserved
        XCTAssertEqual(submittedFile.status, .accepted)
        XCTAssertEqual(submittedFile.statusNotes, "Test notes")
    }
    
    // MARK: - Phase 4.2: Delete Files from Collection Tests
    
    func testDeleteSingleFileFromCollection() throws {
        // Given a collection with files
        let testFile = TextFile(name: "Test File", initialContent: "Content", parentFolder: readyFolder)
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        
        let submittedFile = SubmittedFile(submission: testCollection, textFile: testFile, version: testFile.currentVersion, status: .pending)
        modelContext.insert(submittedFile)
        testCollection.submittedFiles = [submittedFile]
        try! modelContext.save()
        
        XCTAssertEqual(testCollection.submittedFiles?.count, 1)
        
        // When deleting the file
        testCollection.submittedFiles?.removeAll { $0.id == submittedFile.id }
        modelContext.delete(submittedFile)
        try! modelContext.save()
        
        // Then collection should be empty
        XCTAssertEqual(testCollection.submittedFiles?.count, 0)
    }
    
    func testDeleteMultipleFilesSequentially() throws {
        // Given collection with multiple files
        let file1 = TextFile(name: "File 1", initialContent: "Content", parentFolder: readyFolder)
        let file2 = TextFile(name: "File 2", initialContent: "Content", parentFolder: readyFolder)
        
        modelContext.insert(file1)
        modelContext.insert(file2)
        readyFolder.textFiles = [file1, file2]
        
        let sf1 = SubmittedFile(submission: testCollection, textFile: file1, version: file1.currentVersion, status: .pending)
        let sf2 = SubmittedFile(submission: testCollection, textFile: file2, version: file2.currentVersion, status: .pending)
        
        modelContext.insert(sf1)
        modelContext.insert(sf2)
        testCollection.submittedFiles = [sf1, sf2]
        try! modelContext.save()
        
        // When deleting first file
        testCollection.submittedFiles?.removeAll { $0.id == sf1.id }
        modelContext.delete(sf1)
        try! modelContext.save()
        
        // Then second file should remain
        XCTAssertEqual(testCollection.submittedFiles?.count, 1)
        XCTAssertEqual(testCollection.submittedFiles?.first?.id, sf2.id)
        
        // When deleting second file
        testCollection.submittedFiles?.removeAll { $0.id == sf2.id }
        modelContext.delete(sf2)
        try! modelContext.save()
        
        // Then collection should be empty
        XCTAssertTrue(testCollection.submittedFiles?.isEmpty ?? true)
    }
    
    // MARK: - Phase 4.3: Collection Naming Tests
    
    func testCreateCollectionWithName() throws {
        // When creating collection with name
        let namedCollection = Submission(publication: nil, project: testProject)
        namedCollection.name = "Summer Contest"
        modelContext.insert(namedCollection)
        try! modelContext.save()
        
        // Then name should be stored
        XCTAssertEqual(namedCollection.name, "Summer Contest")
    }
    
    func testUpdateCollectionName() throws {
        // Given a named collection
        testCollection.name = "Original Name"
        try! modelContext.save()
        
        // When updating name
        testCollection.name = "Updated Name"
        try! modelContext.save()
        
        // Then name should be updated
        XCTAssertEqual(testCollection.name, "Updated Name")
    }
    
    func testCollectionNameDisplayed() throws {
        // Given collections with and without names
        let namedCollection = Submission(publication: nil, project: testProject)
        namedCollection.name = "Named Collection"
        modelContext.insert(namedCollection)
        
        let unnamedCollection = Submission(publication: nil, project: testProject)
        modelContext.insert(unnamedCollection)
        
        try! modelContext.save()
        
        // Then names should be retrievable
        XCTAssertEqual(namedCollection.name, "Named Collection")
        XCTAssertNil(unnamedCollection.name)
    }
    
    // MARK: - Phase 4.4: Delete Collection Tests
    
    func testDeleteCollection() throws {
        // Given a collection
        let collection = Submission(publication: nil, project: testProject)
        collection.name = "To Delete"
        modelContext.insert(collection)
        try! modelContext.save()
        
        let collectionId = collection.id
        
        // When deleting collection
        modelContext.delete(collection)
        try! modelContext.save()
        
        // Then collection should be removed
        let query = FetchDescriptor<Submission>(
            predicate: #Predicate { s in s.id == collectionId }
        )
        let remainingCollections = try modelContext.fetch(query)
        
        XCTAssertEqual(remainingCollections.count, 0)
    }
    
    func testDeleteCollectionWithFiles() throws {
        // Given a collection with files
        let testFile = TextFile(name: "Test File", initialContent: "Content", parentFolder: readyFolder)
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        
        let submittedFile = SubmittedFile(submission: testCollection, textFile: testFile, version: testFile.currentVersion, status: .pending)
        modelContext.insert(submittedFile)
        testCollection.submittedFiles = [submittedFile]
        try! modelContext.save()
        
        XCTAssertEqual(testCollection.submittedFiles?.count, 1)
        
        let collectionId = testCollection.id
        
        // When deleting collection
        modelContext.delete(testCollection)
        try! modelContext.save()
        
        // Then collection and its files should be deleted
        let query = FetchDescriptor<Submission>(
            predicate: #Predicate { s in s.id == collectionId }
        )
        let remainingCollections = try modelContext.fetch(query)
        
        XCTAssertEqual(remainingCollections.count, 0)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteCollectionWorkflow() throws {
        // Given: Create collection with name
        let collection = Submission(publication: nil, project: testProject)
        collection.name = "Spring Contest"
        modelContext.insert(collection)
        try! modelContext.save()
        
        // When: Add files with different versions
        let file1 = TextFile(name: "Poem 1", initialContent: "V1", parentFolder: readyFolder)
        let file1V1 = file1.currentVersion
        file1.createNewVersion(content: "V2")
        let file1V2 = file1.currentVersion
        
        let file2 = TextFile(name: "Poem 2", initialContent: "V1", parentFolder: readyFolder)
        
        modelContext.insert(file1)
        modelContext.insert(file2)
        readyFolder.textFiles = [file1, file2]
        
        let sf1 = SubmittedFile(submission: collection, textFile: file1, version: file1V1, status: .pending)
        let sf2 = SubmittedFile(submission: collection, textFile: file2, version: file2.currentVersion, status: .pending)
        
        modelContext.insert(sf1)
        modelContext.insert(sf2)
        collection.submittedFiles = [sf1, sf2]
        try! modelContext.save()
        
        // Then: Collection should be complete
        XCTAssertEqual(collection.name, "Spring Contest")
        XCTAssertEqual(collection.submittedFiles?.count, 2)
        
        // And: Change version of file1 to V2
        sf1.version = file1V2
        try! modelContext.save()
        
        XCTAssertEqual(sf1.version?.content, "V2")
        
        // And: Remove file2
        collection.submittedFiles?.removeAll { $0.id == sf2.id }
        modelContext.delete(sf2)
        try! modelContext.save()
        
        XCTAssertEqual(collection.submittedFiles?.count, 1)
    }
    
    func testMultipleCollectionsIndependent() throws {
        // Given two collections with same files
        let file1 = TextFile(name: "Shared File", initialContent: "V1", parentFolder: readyFolder)
        let file1V1 = file1.currentVersion
        file1.createNewVersion(content: "V2")
        let file1V2 = file1.currentVersion
        
        modelContext.insert(file1)
        readyFolder.textFiles = [file1]
        
        let collection1 = Submission(publication: nil, project: testProject)
        collection1.name = "Collection 1"
        let collection2 = Submission(publication: nil, project: testProject)
        collection2.name = "Collection 2"
        
        modelContext.insert(collection1)
        modelContext.insert(collection2)
        
        // When: Add same file with different versions to each
        let sf1 = SubmittedFile(submission: collection1, textFile: file1, version: file1V1, status: .pending)
        let sf2 = SubmittedFile(submission: collection2, textFile: file1, version: file1V2, status: .pending)
        
        modelContext.insert(sf1)
        modelContext.insert(sf2)
        collection1.submittedFiles = [sf1]
        collection2.submittedFiles = [sf2]
        try! modelContext.save()
        
        // Then: Each collection has different version of same file
        XCTAssertEqual(sf1.version?.content, "V1")
        XCTAssertEqual(sf2.version?.content, "V2")
    }
    
    // MARK: - Phase 6: Submit to Publication Tests
    
    func testSubmitCollectionToPublication() throws {
        // Given a collection with files
        let testFile = TextFile(name: "Test File", initialContent: "V1", parentFolder: readyFolder)
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        
        let submittedFile = SubmittedFile(submission: testCollection, textFile: testFile, version: testFile.currentVersion, status: .pending)
        modelContext.insert(submittedFile)
        testCollection.submittedFiles = [submittedFile]
        testCollection.name = "Test Collection"
        try! modelContext.save()
        
        // And a publication
        let publication = Publication(name: "Test Magazine", type: .magazine, project: testProject)
        modelContext.insert(publication)
        try! modelContext.save()
        
        // When creating submission from collection
        let pubSubmission = Submission(publication: publication, project: testProject)
        pubSubmission.name = testCollection.name
        
        let copiedFiles = (testCollection.submittedFiles ?? []).map { original in
            SubmittedFile(
                submission: pubSubmission,
                textFile: original.textFile,
                version: original.version,
                status: .pending
            )
        }
        
        pubSubmission.submittedFiles = copiedFiles
        modelContext.insert(pubSubmission)
        try! modelContext.save()
        
        // Then publication submission should be created with correct properties
        XCTAssertNotNil(pubSubmission.publication)
        XCTAssertEqual(pubSubmission.publication?.id, publication.id)
        XCTAssertEqual(pubSubmission.submittedFiles?.count, 1)
        XCTAssertEqual(pubSubmission.name, "Test Collection")
    }
    
    func testVersionsPreservedInPublicationSubmission() throws {
        // Given a collection with specific versions
        let testFile = TextFile(name: "Test File", initialContent: "V1", parentFolder: readyFolder)
        let file1V1 = testFile.currentVersion
        testFile.createNewVersion(content: "V2")
        
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        
        let submittedFile = SubmittedFile(submission: testCollection, textFile: testFile, version: file1V1, status: .pending)
        modelContext.insert(submittedFile)
        testCollection.submittedFiles = [submittedFile]
        try! modelContext.save()
        
        // And a publication
        let publication = Publication(name: "Contest", type: .competition, project: testProject)
        modelContext.insert(publication)
        try! modelContext.save()
        
        // When creating publication submission
        let pubSubmission = Submission(publication: publication, project: testProject)
        
        let copiedFiles = (testCollection.submittedFiles ?? []).map { original in
            SubmittedFile(
                submission: pubSubmission,
                textFile: original.textFile,
                version: original.version,
                status: .pending
            )
        }
        
        pubSubmission.submittedFiles = copiedFiles
        modelContext.insert(pubSubmission)
        try! modelContext.save()
        
        // Then versions should be preserved exactly
        XCTAssertEqual(pubSubmission.submittedFiles?.first?.version?.content, "V1")
        XCTAssertNotEqual(pubSubmission.submittedFiles?.first?.version?.content, "V2")
    }
    
    func testMultipleSubmissionsFromSameCollection() throws {
        // Given a collection with files
        let testFile = TextFile(name: "Poem", initialContent: "Content", parentFolder: readyFolder)
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        
        let submittedFile = SubmittedFile(submission: testCollection, textFile: testFile, version: testFile.currentVersion, status: .pending)
        modelContext.insert(submittedFile)
        testCollection.submittedFiles = [submittedFile]
        testCollection.name = "My Poems"
        try! modelContext.save()
        
        // And two publications
        let pub1 = Publication(name: "Magazine A", type: .magazine, project: testProject)
        let pub2 = Publication(name: "Magazine B", type: .magazine, project: testProject)
        modelContext.insert(pub1)
        modelContext.insert(pub2)
        try! modelContext.save()
        
        // When submitting same collection to both publications
        let submission1 = Submission(publication: pub1, project: testProject)
        submission1.name = testCollection.name
        let files1 = (testCollection.submittedFiles ?? []).map { original in
            SubmittedFile(submission: submission1, textFile: original.textFile, version: original.version, status: .pending)
        }
        submission1.submittedFiles = files1
        
        let submission2 = Submission(publication: pub2, project: testProject)
        submission2.name = testCollection.name
        let files2 = (testCollection.submittedFiles ?? []).map { original in
            SubmittedFile(submission: submission2, textFile: original.textFile, version: original.version, status: .pending)
        }
        submission2.submittedFiles = files2
        
        modelContext.insert(submission1)
        modelContext.insert(submission2)
        try! modelContext.save()
        
        // Then both submissions should exist and be independent
        XCTAssertEqual(submission1.publication?.id, pub1.id)
        XCTAssertEqual(submission2.publication?.id, pub2.id)
        XCTAssertEqual(submission1.submittedFiles?.count, 1)
        XCTAssertEqual(submission2.submittedFiles?.count, 1)
        XCTAssertNotEqual(submission1.id, submission2.id)
    }
    
    func testModifyCollectionAfterSubmission() throws {
        // Given a collection submitted to publication
        let testFile = TextFile(name: "File", initialContent: "Content", parentFolder: readyFolder)
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        
        let collectionFile = SubmittedFile(submission: testCollection, textFile: testFile, version: testFile.currentVersion, status: .pending)
        modelContext.insert(collectionFile)
        testCollection.submittedFiles = [collectionFile]
        testCollection.name = "Original"
        try! modelContext.save()
        
        let publication = Publication(name: "Mag", type: .magazine, project: testProject)
        modelContext.insert(publication)
        try! modelContext.save()
        
        // Create publication submission
        let pubSubmission = Submission(publication: publication, project: testProject)
        let pubFile = SubmittedFile(submission: pubSubmission, textFile: testFile, version: testFile.currentVersion, status: .pending)
        modelContext.insert(pubFile)
        pubSubmission.submittedFiles = [pubFile]
        modelContext.insert(pubSubmission)
        try! modelContext.save()
        
        let pubFileVersionAtSubmission = pubSubmission.submittedFiles?.first?.version?.content
        
        // When modifying the original collection
        testCollection.name = "Modified"
        testFile.createNewVersion(content: "New Version")
        try! modelContext.save()
        
        // Then publication submission should be unaffected
        XCTAssertEqual(testCollection.name, "Modified")
        XCTAssertEqual(pubSubmission.name, nil)  // Pub submission doesn't have name set
        XCTAssertEqual(pubSubmission.submittedFiles?.first?.version?.content, pubFileVersionAtSubmission)
    }
    
    func testCollectionNamePreservedInSubmission() throws {
        // Given a named collection
        testCollection.name = "Spring Poetry Contest 2025"
        let testFile = TextFile(name: "Poem", initialContent: "Content", parentFolder: readyFolder)
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        
        let submittedFile = SubmittedFile(submission: testCollection, textFile: testFile, version: testFile.currentVersion, status: .pending)
        modelContext.insert(submittedFile)
        testCollection.submittedFiles = [submittedFile]
        try! modelContext.save()
        
        let publication = Publication(name: "Magazine", type: .magazine, project: testProject)
        modelContext.insert(publication)
        try! modelContext.save()
        
        // When creating publication submission
        let pubSubmission = Submission(publication: publication, project: testProject)
        pubSubmission.name = testCollection.name  // Preserve name
        
        let copiedFiles = (testCollection.submittedFiles ?? []).map { original in
            SubmittedFile(submission: pubSubmission, textFile: original.textFile, version: original.version, status: .pending)
        }
        
        pubSubmission.submittedFiles = copiedFiles
        modelContext.insert(pubSubmission)
        try! modelContext.save()
        
        // Then collection name should be preserved
        XCTAssertEqual(pubSubmission.name, "Spring Poetry Contest 2025")
    }
}
