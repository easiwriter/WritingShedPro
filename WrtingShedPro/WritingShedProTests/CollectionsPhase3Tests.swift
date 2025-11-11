import XCTest
import SwiftData
@testable import Writing_Shed_Pro

/// Comprehensive tests for Feature 008c Phase 3: Collection Details and File Management
/// Tests file addition, version selection, and collection interaction
final class CollectionsPhase3Tests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testProject: Project!
    var readyFolder: Folder!
    var testCollection: Submission!
    
    override func setUp() {
        super.setUp()
        // Create in-memory model container for testing
        let schema = Schema([
            Project.self, Folder.self, TextFile.self, Version.self, TrashItem.self,
            Submission.self, SubmittedFile.self, Publication.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)
        
        // Setup test data
        testProject = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(testProject)
        ProjectTemplateService.createDefaultFolders(for: testProject, in: modelContext)
        
        // Get Ready folder
        let folders = testProject.folders ?? []
        readyFolder = folders.first { $0.name == "Ready" }!
        
        // Create test collection (Submission with no publication)
        testCollection = Submission(publication: nil, project: testProject)
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
    
    // MARK: - Collection Details View Tests
    
    func testCollectionDetailViewEmptyState() throws {
        // Given a collection with no files
        XCTAssertTrue(testCollection.submittedFiles?.isEmpty ?? true, "Collection should be empty initially")
        
        // Then the empty state should be visible
        let fileCount = testCollection.submittedFiles?.count ?? 0
        XCTAssertEqual(fileCount, 0, "Collection should have zero files")
    }
    
    func testCollectionDetailViewWithFiles() throws {
        // Given a collection
        let testFile = TextFile(name: "Test File", initialContent: "Test content", parentFolder: readyFolder)
        modelContext.insert(testFile)
        readyFolder.textFiles?.append(testFile)
        
        // When adding a submitted file
        let submittedFile = SubmittedFile(
            submission: testCollection,
            textFile: testFile,
            version: testFile.currentVersion,
            status: .pending
        )
        modelContext.insert(submittedFile)
        testCollection.submittedFiles?.append(submittedFile)
        try! modelContext.save()
        
        // Then the collection should contain the file
        XCTAssertEqual(testCollection.submittedFiles?.count, 1, "Collection should have one file")
        XCTAssertEqual(testCollection.submittedFiles?.first?.textFile?.name, "Test File")
    }
    
    func testCollectionFileSorting() throws {
        // Given multiple files in a collection
        let file1 = TextFile(name: "Zebra File", initialContent: "Content 1", parentFolder: readyFolder)
        let file2 = TextFile(name: "Apple File", initialContent: "Content 2", parentFolder: readyFolder)
        let file3 = TextFile(name: "Banana File", initialContent: "Content 3", parentFolder: readyFolder)
        
        modelContext.insert(file1)
        modelContext.insert(file2)
        modelContext.insert(file3)
        readyFolder.textFiles = [file1, file2, file3]
        
        // Add in non-alphabetical order
        let sf1 = SubmittedFile(submission: testCollection, textFile: file1, version: file1.currentVersion, status: .pending)
        let sf2 = SubmittedFile(submission: testCollection, textFile: file2, version: file2.currentVersion, status: .pending)
        let sf3 = SubmittedFile(submission: testCollection, textFile: file3, version: file3.currentVersion, status: .pending)
        
        modelContext.insert(sf1)
        modelContext.insert(sf2)
        modelContext.insert(sf3)
        testCollection.submittedFiles = [sf1, sf2, sf3]
        try! modelContext.save()
        
        // Then files should be sortable alphabetically
        let sortedFiles = testCollection.submittedFiles?.sorted { f1, f2 in
            let name1 = f1.textFile?.name ?? ""
            let name2 = f2.textFile?.name ?? ""
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        } ?? []
        
        XCTAssertEqual(sortedFiles.count, 3, "Should have 3 files")
        XCTAssertEqual(sortedFiles[0].textFile?.name, "Apple File")
        XCTAssertEqual(sortedFiles[1].textFile?.name, "Banana File")
        XCTAssertEqual(sortedFiles[2].textFile?.name, "Zebra File")
    }
    
    // MARK: - Add Files to Collection Tests
    
    func testGetAvailableFilesFromReady() throws {
        // Given files in Ready folder
        let file1 = TextFile(name: "File 1", initialContent: "Content", parentFolder: readyFolder)
        let file2 = TextFile(name: "File 2", initialContent: "Content", parentFolder: readyFolder)
        
        modelContext.insert(file1)
        modelContext.insert(file2)
        readyFolder.textFiles = [file1, file2]
        try! modelContext.save()
        
        // When getting available files
        let availableFiles = readyFolder.textFiles ?? []
        
        // Then all Ready files should be available
        XCTAssertEqual(availableFiles.count, 2, "Should have 2 available files")
        XCTAssertTrue(availableFiles.contains { $0.name == "File 1" })
        XCTAssertTrue(availableFiles.contains { $0.name == "File 2" })
    }
    
    func testFilterOutAlreadyAddedFiles() throws {
        // Given files in Ready folder
        let file1 = TextFile(name: "File 1", initialContent: "Content", parentFolder: readyFolder)
        let file2 = TextFile(name: "File 2", initialContent: "Content", parentFolder: readyFolder)
        
        modelContext.insert(file1)
        modelContext.insert(file2)
        readyFolder.textFiles = [file1, file2]
        
        // When one file is already in the collection
        let submittedFile1 = SubmittedFile(
            submission: testCollection,
            textFile: file1,
            version: file1.currentVersion,
            status: .pending
        )
        modelContext.insert(submittedFile1)
        testCollection.submittedFiles = [submittedFile1]
        try! modelContext.save()
        
        // Then only file2 should be available
        let alreadyAdded = Set((testCollection.submittedFiles ?? []).compactMap { $0.textFile?.id })
        let availableFiles = (readyFolder.textFiles ?? []).filter { !alreadyAdded.contains($0.id) }
        
        XCTAssertEqual(availableFiles.count, 1, "Should have 1 available file")
        XCTAssertEqual(availableFiles.first?.name, "File 2")
    }
    
    func testAddSingleFileToCollection() throws {
        // Given a file in Ready folder
        let testFile = TextFile(name: "Test File", initialContent: "Content", parentFolder: readyFolder)
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        try! modelContext.save()
        
        // When adding file to collection
        let submittedFile = SubmittedFile(
            submission: testCollection,
            textFile: testFile,
            version: testFile.currentVersion,
            status: .pending
        )
        modelContext.insert(submittedFile)
        testCollection.submittedFiles?.append(submittedFile)
        try! modelContext.save()
        
        // Then file should be in collection
        XCTAssertEqual(testCollection.submittedFiles?.count, 1)
        XCTAssertEqual(testCollection.submittedFiles?.first?.textFile?.name, "Test File")
        XCTAssertEqual(testCollection.submittedFiles?.first?.status, .pending)
    }
    
    func testAddMultipleFilesToCollection() throws {
        // Given multiple files in Ready folder
        let file1 = TextFile(name: "File 1", initialContent: "Content 1", parentFolder: readyFolder)
        let file2 = TextFile(name: "File 2", initialContent: "Content 2", parentFolder: readyFolder)
        let file3 = TextFile(name: "File 3", initialContent: "Content 3", parentFolder: readyFolder)
        
        modelContext.insert(file1)
        modelContext.insert(file2)
        modelContext.insert(file3)
        readyFolder.textFiles = [file1, file2, file3]
        try! modelContext.save()
        
        // When adding all three files to collection
        let selectedFileIds = [file1.id, file2.id, file3.id]
        for fileId in selectedFileIds {
            if let file = readyFolder.textFiles?.first(where: { $0.id == fileId }) {
                let submittedFile = SubmittedFile(
                    submission: testCollection,
                    textFile: file,
                    version: file.currentVersion,
                    status: .pending
                )
                modelContext.insert(submittedFile)
                testCollection.submittedFiles?.append(submittedFile)
            }
        }
        try! modelContext.save()
        
        // Then all files should be in collection
        XCTAssertEqual(testCollection.submittedFiles?.count, 3)
    }
    
    // MARK: - Version Selection Tests
    
    func testDefaultVersionSelection() throws {
        // Given a file with multiple versions
        let testFile = TextFile(name: "Test File", initialContent: "Version 1", parentFolder: readyFolder)
        // Initial version is versionNumber 1
        testFile.createNewVersion(content: "Version 2")  // Creates versionNumber 2
        testFile.createNewVersion(content: "Version 3")  // Creates versionNumber 3
        
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        try! modelContext.save()
        
        // When adding file without explicit version selection
        let currentVersion = testFile.currentVersion
        let submittedFile = SubmittedFile(
            submission: testCollection,
            textFile: testFile,
            version: currentVersion,
            status: .pending
        )
        modelContext.insert(submittedFile)
        testCollection.submittedFiles?.append(submittedFile)
        try! modelContext.save()
        
        // Then current version should be the latest one (version 3)
        XCTAssertNotNil(submittedFile.version, "Version should not be nil")
        XCTAssertEqual(testFile.versions?.count, 3, "File should have 3 versions")
        // currentVersion points to the last version in the array after createNewVersion
        XCTAssertEqual(submittedFile.version?.versionNumber, 3, "Should use latest version (Version 3)")
    }
    
    func testSelectSpecificVersion() throws {
        // Given a file with multiple versions
        let testFile = TextFile(name: "Test File", initialContent: "Version 1", parentFolder: readyFolder)
        let version1 = testFile.currentVersion  // Capture first version
        testFile.createNewVersion(content: "Version 2")
        testFile.createNewVersion(content: "Version 3")
        
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        try! modelContext.save()
        
        // When selecting a specific version (version 1)
        let submittedFile = SubmittedFile(
            submission: testCollection,
            textFile: testFile,
            version: version1,
            status: .pending
        )
        modelContext.insert(submittedFile)
        testCollection.submittedFiles?.append(submittedFile)
        try! modelContext.save()
        
        // Then selected version should be stored
        XCTAssertNotNil(submittedFile.version, "Should have a selected version")
        XCTAssertEqual(submittedFile.version?.content, "Version 1", "Should preserve version content")
    }
    
    func testVersionSelectionPreservesContent() throws {
        // Given a file with different content in each version
        let testFile = TextFile(name: "Test File", initialContent: "Original content", parentFolder: readyFolder)
        let version1 = testFile.currentVersion
        testFile.createNewVersion(content: "Updated content")
        let version2 = testFile.currentVersion
        
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        try! modelContext.save()
        
        // Then version 1 content should be preserved
        XCTAssertEqual(version1?.content, "Original content", "Version 1 should have original content")
        
        // And version 2 content should be different
        XCTAssertEqual(version2?.content, "Updated content", "Version 2 should have updated content")
        XCTAssertNotEqual(version1?.content, version2?.content, "Versions should have different content")
    }
    
    func testMultipleFilesWithDifferentVersions() throws {
        // Given two files with versions
        let file1 = TextFile(name: "File 1", initialContent: "F1V1", parentFolder: readyFolder)
        let file1V1 = file1.currentVersion
        file1.createNewVersion(content: "F1V2")
        
        let file2 = TextFile(name: "File 2", initialContent: "F2V1", parentFolder: readyFolder)
        let file2V1 = file2.currentVersion
        file2.createNewVersion(content: "F2V2")
        let file2V2 = file2.currentVersion
        
        modelContext.insert(file1)
        modelContext.insert(file2)
        readyFolder.textFiles = [file1, file2]
        try! modelContext.save()
        
        // When adding file1 with first version and file2 with latest version
        let sf1 = SubmittedFile(
            submission: testCollection,
            textFile: file1,
            version: file1V1,
            status: .pending
        )
        let sf2 = SubmittedFile(
            submission: testCollection,
            textFile: file2,
            version: file2V2,
            status: .pending
        )
        
        modelContext.insert(sf1)
        modelContext.insert(sf2)
        testCollection.submittedFiles = [sf1, sf2]
        try! modelContext.save()
        
        // Then each file should have correct version content
        XCTAssertEqual(sf1.version?.content, "F1V1", "File 1 should use first version")
        XCTAssertEqual(sf2.version?.content, "F2V2", "File 2 should use latest version")
    }
    
    // MARK: - Collection File Management Tests
    
    func testDeleteFileFromCollection() throws {
        // Given a collection with a file
        let testFile = TextFile(name: "Test File", initialContent: "Content", parentFolder: readyFolder)
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        
        let submittedFile = SubmittedFile(
            submission: testCollection,
            textFile: testFile,
            version: testFile.currentVersion,
            status: .pending
        )
        modelContext.insert(submittedFile)
        testCollection.submittedFiles = [submittedFile]
        try! modelContext.save()
        
        // When deleting the file from collection
        testCollection.submittedFiles?.removeAll { $0.id == submittedFile.id }
        modelContext.delete(submittedFile)
        try! modelContext.save()
        
        // Then collection should be empty
        XCTAssertTrue(testCollection.submittedFiles?.isEmpty ?? true)
    }
    
    func testFileStatusTracking() throws {
        // Given a file added to collection
        let testFile = TextFile(name: "Test File", initialContent: "Content", parentFolder: readyFolder)
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        
        let submittedFile = SubmittedFile(
            submission: testCollection,
            textFile: testFile,
            version: testFile.currentVersion,
            status: .pending
        )
        modelContext.insert(submittedFile)
        testCollection.submittedFiles = [submittedFile]
        try! modelContext.save()
        
        // When changing status
        submittedFile.status = .accepted
        try! modelContext.save()
        
        // Then status should be updated
        XCTAssertEqual(submittedFile.status, .accepted)
    }
    
    func testSubmissionStatusValues() throws {
        // Given different status values
        let testFile = TextFile(name: "Test File", initialContent: "Content", parentFolder: readyFolder)
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        
        // When creating files with different statuses
        let pendingFile = SubmittedFile(submission: testCollection, textFile: testFile, status: .pending)
        let acceptedFile = SubmittedFile(submission: testCollection, textFile: testFile, status: .accepted)
        let rejectedFile = SubmittedFile(submission: testCollection, textFile: testFile, status: .rejected)
        
        modelContext.insert(pendingFile)
        modelContext.insert(acceptedFile)
        modelContext.insert(rejectedFile)
        
        // Then all statuses should be valid
        XCTAssertEqual(pendingFile.status, .pending)
        XCTAssertEqual(acceptedFile.status, .accepted)
        XCTAssertEqual(rejectedFile.status, .rejected)
    }
    
    // MARK: - Empty State Tests
    
    func testEmptyCollectionIndicator() throws {
        // Given an empty collection
        XCTAssertTrue(testCollection.submittedFiles?.isEmpty ?? true)
        
        // Then it should be recognized as empty
        let isEmpty = (testCollection.submittedFiles?.isEmpty ?? true)
        XCTAssertTrue(isEmpty)
    }
    
    func testCollectionBecomesNonEmptyAfterAddingFile() throws {
        // Given an empty collection
        XCTAssertTrue(testCollection.submittedFiles?.isEmpty ?? true)
        
        // When adding a file
        let testFile = TextFile(name: "Test File", initialContent: "Content", parentFolder: readyFolder)
        modelContext.insert(testFile)
        readyFolder.textFiles = [testFile]
        
        let submittedFile = SubmittedFile(
            submission: testCollection,
            textFile: testFile,
            version: testFile.currentVersion,
            status: .pending
        )
        modelContext.insert(submittedFile)
        testCollection.submittedFiles?.append(submittedFile)
        try! modelContext.save()
        
        // Then collection should not be empty
        XCTAssertFalse(testCollection.submittedFiles?.isEmpty ?? true)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkflow() throws {
        // Given ready files exist
        let file1 = TextFile(name: "Story One", initialContent: "Chapter 1", parentFolder: readyFolder)
        let file2 = TextFile(name: "Story Two", initialContent: "Chapter 1", parentFolder: readyFolder)
        
        modelContext.insert(file1)
        modelContext.insert(file2)
        readyFolder.textFiles = [file1, file2]
        
        // When creating collection and adding files
        for file in [file1, file2] {
            let submittedFile = SubmittedFile(
                submission: testCollection,
                textFile: file,
                version: file.currentVersion,
                status: .pending
            )
            modelContext.insert(submittedFile)
            testCollection.submittedFiles?.append(submittedFile)
        }
        try! modelContext.save()
        
        // Then workflow should be complete
        XCTAssertEqual(testCollection.submittedFiles?.count, 2)
        XCTAssertEqual(testCollection.fileCount, 2)
        
        // And files should be retrievable
        let addedFiles = testCollection.submittedFiles?.compactMap { $0.textFile?.name } ?? []
        XCTAssertTrue(addedFiles.contains("Story One"))
        XCTAssertTrue(addedFiles.contains("Story Two"))
    }
}
