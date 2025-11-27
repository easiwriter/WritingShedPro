//
//  PrintServiceTests.swift
//  Writing Shed Pro Tests
//
//  Tests for PrintService
//  Feature 020: Printing Support
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class PrintServiceTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUpWithError() throws {
        // Create in-memory model container for testing
        let schema = Schema([
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self,
            StyleSheet.self,
            TextStyleModel.self,
            PageSetup.self,
            Publication.self,
            Submission.self,
            SubmittedFile.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }
    
    // MARK: - Availability Tests
    
    func testIsPrintingAvailable_ReturnsBoolean() throws {
        // When: Checking if printing is available
        let result = PrintService.isPrintingAvailable()
        
        // Then: Should return a boolean value
        // Note: Value depends on simulator/device capabilities
        XCTAssertNotNil(result, "Should return a boolean value")
    }
    
    // MARK: - Can Print Tests
    
    func testCanPrint_WithValidFile_ReturnsTrue() throws {
        // Given: A text file with content
        let project = Project(name: "Test Project")
        modelContext.insert(project)
        
        let folder = Folder(name: "Test Folder", project: project)
        modelContext.insert(folder)
        
        let textFile = TextFile(name: "Valid File", initialContent: "Test content", parentFolder: folder)
        modelContext.insert(textFile)
        
        // When: Checking if file can be printed
        let result = PrintService.canPrint(file: textFile)
        
        // Then: Should return true
        XCTAssertTrue(result, "File with content should be printable")
    }
    
    func testCanPrint_WithEmptyFile_ReturnsFalse() throws {
        // Given: A text file with no content
        let project = Project(name: "Test Project")
        modelContext.insert(project)
        
        let folder = Folder(name: "Test Folder", project: project)
        modelContext.insert(folder)
        
        let textFile = TextFile(name: "Empty File", initialContent: "", parentFolder: folder)
        modelContext.insert(textFile)
        
        // When: Checking if file can be printed
        let result = PrintService.canPrint(file: textFile)
        
        // Then: Should return false
        XCTAssertFalse(result, "Empty file should not be printable")
    }
    
    func testCanPrint_WithNoVersion_ReturnsFalse() throws {
        // Given: A text file with no versions
        let project = Project(name: "Test Project")
        modelContext.insert(project)
        
        let folder = Folder(name: "Test Folder", project: project)
        modelContext.insert(folder)
        
        let textFile = TextFile(name: "No Version", initialContent: "", parentFolder: folder)
        textFile.versions = []
        modelContext.insert(textFile)
        
        // When: Checking if file can be printed
        let result = PrintService.canPrint(file: textFile)
        
        // Then: Should return false
        XCTAssertFalse(result, "File without version should not be printable")
    }
    
    // MARK: - Print Error Tests
    
    func testPrintError_NoContent_HasCorrectDescription() throws {
        // Given: No content error
        let error = PrintError.noContent
        
        // When: Getting error description
        let description = error.errorDescription
        
        // Then: Should have description
        XCTAssertNotNil(description, "Error should have description")
        XCTAssertFalse(description!.isEmpty, "Description should not be empty")
    }
    
    func testPrintError_NotAvailable_HasCorrectDescription() throws {
        // Given: Not available error
        let error = PrintError.notAvailable
        
        // When: Getting error description
        let description = error.errorDescription
        
        // Then: Should have description
        XCTAssertNotNil(description, "Error should have description")
        XCTAssertFalse(description!.isEmpty, "Description should not be empty")
    }
    
    func testPrintError_Cancelled_HasCorrectDescription() throws {
        // Given: Cancelled error
        let error = PrintError.cancelled
        
        // When: Getting error description
        let description = error.errorDescription
        
        // Then: Should have description
        XCTAssertNotNil(description, "Error should have description")
        XCTAssertFalse(description!.isEmpty, "Description should not be empty")
    }
    
    func testPrintError_Failed_HasCorrectDescription() throws {
        // Given: Failed error with message
        let errorMessage = "Test failure"
        let error = PrintError.failed(errorMessage)
        
        // When: Getting error description
        let description = error.errorDescription
        
        // Then: Should include failure message
        XCTAssertNotNil(description, "Error should have description")
        XCTAssertFalse(description!.isEmpty, "Description should not be empty")
        // The description uses String(format:) with NSLocalizedString, so it should contain the error message
        XCTAssertTrue(description!.contains(errorMessage), "Description should include error message '\(errorMessage)'. Got: '\(description!)'")
    }
    
    // MARK: - Collection/Submission Structure Tests
    
    func testCollectionStructure_SubmissionWithoutPublication_IsCollection() throws {
        // Given: A submission without publication (collection)
        let project = Project(name: "Test Project")
        modelContext.insert(project)
        
        let collection = Submission(publication: nil, project: project)
        collection.name = "Test Collection"
        modelContext.insert(collection)
        
        // When: Checking structure
        // Then: Should be a collection
        XCTAssertNil(collection.publication, "Collection should have nil publication")
        XCTAssertNotNil(collection.name, "Collection should have a name")
        XCTAssertEqual(collection.name, "Test Collection", "Collection name should match")
    }
    
    func testCollectionStructure_WithFiles_AccessibleThroughSubmittedFiles() throws {
        // Given: A collection with files
        let project = Project(name: "Test Project")
        modelContext.insert(project)
        
        let folder = Folder(name: "Test Folder", project: project)
        modelContext.insert(folder)
        
        let file1 = TextFile(name: "File 1", initialContent: "Content 1", parentFolder: folder)
        let file2 = TextFile(name: "File 2", initialContent: "Content 2", parentFolder: folder)
        modelContext.insert(file1)
        modelContext.insert(file2)
        
        let collection = Submission(publication: nil, project: project)
        collection.name = "Test Collection"
        modelContext.insert(collection)
        
        let submittedFile1 = SubmittedFile(
            submission: collection,
            textFile: file1,
            version: file1.currentVersion,
            status: .pending,
            project: project
        )
        let submittedFile2 = SubmittedFile(
            submission: collection,
            textFile: file2,
            version: file2.currentVersion,
            status: .pending,
            project: project
        )
        modelContext.insert(submittedFile1)
        modelContext.insert(submittedFile2)
        
        collection.submittedFiles = [submittedFile1, submittedFile2]
        
        // When: Accessing files through submittedFiles
        let files = collection.submittedFiles?.compactMap { $0.textFile }
        
        // Then: Should get both files
        XCTAssertEqual(files?.count, 2, "Should have 2 files")
        XCTAssertTrue(files?.contains(where: { $0.name == "File 1" }) ?? false, "Should contain File 1")
        XCTAssertTrue(files?.contains(where: { $0.name == "File 2" }) ?? false, "Should contain File 2")
    }
    
    func testSubmissionStructure_WithPublication_IsNotCollection() throws {
        // Given: A submission with publication
        let project = Project(name: "Test Project")
        modelContext.insert(project)
        
        let publication = Publication(name: "Test Magazine", type: .magazine, project: project)
        modelContext.insert(publication)
        
        let submission = Submission(publication: publication, project: project)
        modelContext.insert(submission)
        
        // When: Checking structure
        // Then: Should be a submission (not collection)
        XCTAssertNotNil(submission.publication, "Submission should have publication")
        XCTAssertEqual(submission.publication?.name, "Test Magazine", "Publication name should match")
    }
    
    // MARK: - Content Preparation Tests
    
    func testPrintPreparation_SingleFile_FormatsCorrectly() throws {
        // Given: A single text file
        let project = Project(name: "Test Project")
        modelContext.insert(project)
        
        let folder = Folder(name: "Test Folder", project: project)
        modelContext.insert(folder)
        
        let textFile = TextFile(name: "Test File", initialContent: "Test content for printing", parentFolder: folder)
        modelContext.insert(textFile)
        
        // When: Formatting for print
        let result = PrintFormatter.formatFile(textFile)
        
        // Then: Should have content
        XCTAssertNotNil(result, "Should format file successfully")
        XCTAssertEqual(result?.string, "Test content for printing", "Content should match")
    }
    
    func testPrintPreparation_MultipleFiles_CombinesInOrder() throws {
        // Given: Multiple files in order
        let project = Project(name: "Test Project")
        modelContext.insert(project)
        
        let folder = Folder(name: "Test Folder", project: project)
        modelContext.insert(folder)
        
        let file1 = TextFile(name: "A First", initialContent: "First", parentFolder: folder)
        let file2 = TextFile(name: "B Second", initialContent: "Second", parentFolder: folder)
        let file3 = TextFile(name: "C Third", initialContent: "Third", parentFolder: folder)
        
        modelContext.insert(file1)
        modelContext.insert(file2)
        modelContext.insert(file3)
        
        // When: Formatting multiple files
        let result = PrintFormatter.formatMultipleFiles([file1, file2, file3])
        
        // Then: Should combine in order with separators
        XCTAssertNotNil(result, "Should format files successfully")
        let content = result!.string
        
        // Check order (First should appear before Second, Second before Third)
        let firstIndex = content.range(of: "First")!.lowerBound
        let secondIndex = content.range(of: "Second")!.lowerBound
        let thirdIndex = content.range(of: "Third")!.lowerBound
        
        XCTAssertLessThan(firstIndex, secondIndex, "First should appear before Second")
        XCTAssertLessThan(secondIndex, thirdIndex, "Second should appear before Third")
    }
    
    // MARK: - Edge Case Tests
    
    func testPrintPreparation_FileWithSpecialCharacters_HandlesCorrectly() throws {
        // Given: File with special characters
        let project = Project(name: "Test Project")
        modelContext.insert(project)
        
        let folder = Folder(name: "Test Folder", project: project)
        modelContext.insert(folder)
        
        let specialContent = "Test with émojis 😀, quotes \"curved\", and symbols ©®™"
        let textFile = TextFile(name: "Special File", initialContent: specialContent, parentFolder: folder)
        modelContext.insert(textFile)
        
        // When: Formatting for print
        let result = PrintFormatter.formatFile(textFile)
        
        // Then: Should preserve special characters
        XCTAssertNotNil(result, "Should format file successfully")
        XCTAssertEqual(result?.string, specialContent, "Special characters should be preserved")
    }
    
    func testPrintPreparation_FileWithMultipleLines_PreservesLineBreaks() throws {
        // Given: File with multiple lines
        let project = Project(name: "Test Project")
        modelContext.insert(project)
        
        let folder = Folder(name: "Test Folder", project: project)
        modelContext.insert(folder)
        
        let multilineContent = "Line 1\nLine 2\n\nLine 4"
        let textFile = TextFile(name: "Multiline File", initialContent: multilineContent, parentFolder: folder)
        modelContext.insert(textFile)
        
        // When: Formatting for print
        let result = PrintFormatter.formatFile(textFile)
        
        // Then: Should preserve line breaks
        XCTAssertNotNil(result, "Should format file successfully")
        XCTAssertEqual(result?.string, multilineContent, "Line breaks should be preserved")
        XCTAssertTrue(result!.string.contains("\n\n"), "Double line breaks should be preserved")
    }
}
