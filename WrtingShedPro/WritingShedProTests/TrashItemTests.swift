//
//  TrashItemTests.swift
//  WritingShedProTests
//
//  Tests for TrashItem model
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class TrashItemTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory model container for testing
        let schema = Schema([
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self,
            TrashItem.self
        ])
        
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Failed to create model container for tests: \(error)")
        }
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testTrashItemCreation() {
        // Given
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Documents", project: project)
        let textFile = TextFile(name: "Test.txt", parentFolder: folder)
        
        modelContext.insert(project)
        modelContext.insert(folder)
        modelContext.insert(textFile)
        
        // When
        let trashItem = TrashItem(
            textFile: textFile,
            originalFolder: folder,
            project: project
        )
        modelContext.insert(trashItem)
        
        // Then
        XCTAssertNotNil(trashItem.id, "TrashItem should have an ID")
        XCTAssertNotNil(trashItem.deletedDate, "TrashItem should have a deleted date")
        XCTAssertEqual(trashItem.textFile, textFile, "TrashItem should reference the text file")
        XCTAssertEqual(trashItem.originalFolder, folder, "TrashItem should reference the original folder")
        XCTAssertEqual(trashItem.project, project, "TrashItem should reference the project")
    }
    
    func testTrashItemDeletedDateIsSet() {
        // Given
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Documents", project: project)
        let textFile = TextFile(name: "Test.txt", parentFolder: folder)
        
        modelContext.insert(project)
        modelContext.insert(folder)
        modelContext.insert(textFile)
        
        let beforeDate = Date()
        
        // When
        let trashItem = TrashItem(
            textFile: textFile,
            originalFolder: folder,
            project: project
        )
        modelContext.insert(trashItem)
        
        let afterDate = Date()
        
        // Then
        XCTAssertNotNil(trashItem.deletedDate, "Deleted date should be set")
        XCTAssertGreaterThanOrEqual(trashItem.deletedDate, beforeDate, "Deleted date should be after or equal to before date")
        XCTAssertLessThanOrEqual(trashItem.deletedDate, afterDate, "Deleted date should be before or equal to after date")
    }
    
    // MARK: - Computed Property Tests
    
    func testDisplayName() {
        // Given
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Documents", project: project)
        let textFile = TextFile(name: "MyDocument.txt", parentFolder: folder)
        
        modelContext.insert(project)
        modelContext.insert(folder)
        modelContext.insert(textFile)
        
        let trashItem = TrashItem(
            textFile: textFile,
            originalFolder: folder,
            project: project
        )
        modelContext.insert(trashItem)
        
        // When/Then
        XCTAssertEqual(trashItem.displayName, "MyDocument.txt", "Display name should match file name")
    }
    
    func testDisplayNameWhenTextFileIsNil() {
        // Given
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Documents", project: project)
        let textFile = TextFile(name: "Test.txt", parentFolder: folder)
        
        modelContext.insert(project)
        modelContext.insert(folder)
        modelContext.insert(textFile)
        
        let trashItem = TrashItem(
            textFile: textFile,
            originalFolder: folder,
            project: project
        )
        modelContext.insert(trashItem)
        
        // When
        trashItem.textFile = nil
        
        // Then
        XCTAssertEqual(trashItem.displayName, "Unknown", "Display name should be 'Unknown' when textFile is nil")
    }
    
    func testOriginalFolderName() {
        // Given
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Documents", project: project)
        let textFile = TextFile(name: "Test.txt", parentFolder: folder)
        
        modelContext.insert(project)
        modelContext.insert(folder)
        modelContext.insert(textFile)
        
        let trashItem = TrashItem(
            textFile: textFile,
            originalFolder: folder,
            project: project
        )
        modelContext.insert(trashItem)
        
        // When/Then
        XCTAssertEqual(trashItem.originalFolderName, "Documents", "Original folder name should match folder name")
    }
    
    func testOriginalFolderNameWhenFolderIsNil() {
        // Given
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Documents", project: project)
        let textFile = TextFile(name: "Test.txt", parentFolder: folder)
        
        modelContext.insert(project)
        modelContext.insert(folder)
        modelContext.insert(textFile)
        
        let trashItem = TrashItem(
            textFile: textFile,
            originalFolder: folder,
            project: project
        )
        modelContext.insert(trashItem)
        
        // When
        trashItem.originalFolder = nil
        
        // Then
        XCTAssertEqual(trashItem.originalFolderName, "Unknown", "Original folder name should be 'Unknown' when folder is nil")
    }
    
    func testCanRestoreToOriginalWhenFolderExists() {
        // Given
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Documents", project: project)
        let textFile = TextFile(name: "Test.txt", parentFolder: folder)
        
        modelContext.insert(project)
        modelContext.insert(folder)
        modelContext.insert(textFile)
        
        let trashItem = TrashItem(
            textFile: textFile,
            originalFolder: folder,
            project: project
        )
        modelContext.insert(trashItem)
        
        // When/Then
        XCTAssertTrue(trashItem.canRestoreToOriginal, "Should be able to restore when original folder exists")
    }
    
    func testCanRestoreToOriginalWhenFolderIsDeleted() {
        // Given
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Documents", project: project)
        let textFile = TextFile(name: "Test.txt", parentFolder: folder)
        
        modelContext.insert(project)
        modelContext.insert(folder)
        modelContext.insert(textFile)
        
        let trashItem = TrashItem(
            textFile: textFile,
            originalFolder: folder,
            project: project
        )
        modelContext.insert(trashItem)
        
        // When
        trashItem.originalFolder = nil
        
        // Then
        XCTAssertFalse(trashItem.canRestoreToOriginal, "Should not be able to restore when original folder is deleted")
    }
    
    // MARK: - Relationship Tests
    
    func testTextFileRelationship() {
        // Given
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Documents", project: project)
        let textFile = TextFile(name: "Test.txt", parentFolder: folder)
        
        modelContext.insert(project)
        modelContext.insert(folder)
        modelContext.insert(textFile)
        
        let trashItem = TrashItem(
            textFile: textFile,
            originalFolder: folder,
            project: project
        )
        modelContext.insert(trashItem)
        
        // When/Then
        XCTAssertEqual(trashItem.textFile, textFile, "TrashItem should maintain reference to TextFile")
    }
    
    func testCascadeDeleteWhenTextFileDeleted() {
        // Given
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Documents", project: project)
        let textFile = TextFile(name: "Test.txt", parentFolder: folder)
        
        modelContext.insert(project)
        modelContext.insert(folder)
        modelContext.insert(textFile)
        
        let trashItem = TrashItem(
            textFile: textFile,
            originalFolder: folder,
            project: project
        )
        modelContext.insert(trashItem)
        
        do {
            try modelContext.save()
        } catch {
            XCTFail("Failed to save context: \(error)")
        }
        
        let trashItemID = trashItem.id
        
        // When - Delete the text file
        modelContext.delete(textFile)
        
        do {
            try modelContext.save()
        } catch {
            XCTFail("Failed to save after delete: \(error)")
        }
        
        // Then - TrashItem should have null textFile reference (cascade delete from TrashItem side)
        let descriptor = FetchDescriptor<TrashItem>(
            predicate: #Predicate { $0.id == trashItemID }
        )
        
        do {
            let results = try modelContext.fetch(descriptor)
            XCTAssertEqual(results.count, 1, "TrashItem should still exist")
            XCTAssertNil(results.first?.textFile, "TrashItem.textFile should be nil after TextFile deleted")
        } catch {
            XCTFail("Failed to fetch TrashItem: \(error)")
        }
    }
    
    func testNullifyOriginalFolderWhenFolderDeleted() {
        // Given
        let project = Project(name: "Test Project")
        let folder = Folder(name: "Documents", project: project)
        let textFile = TextFile(name: "Test.txt", parentFolder: folder)
        
        modelContext.insert(project)
        modelContext.insert(folder)
        modelContext.insert(textFile)
        
        let trashItem = TrashItem(
            textFile: textFile,
            originalFolder: folder,
            project: project
        )
        modelContext.insert(trashItem)
        
        do {
            try modelContext.save()
        } catch {
            XCTFail("Failed to save context: \(error)")
        }
        
        // When - Delete the folder
        modelContext.delete(folder)
        
        do {
            try modelContext.save()
        } catch {
            XCTFail("Failed to save after delete: \(error)")
        }
        
        // Then - originalFolder should be nullified
        XCTAssertNil(trashItem.originalFolder, "originalFolder should be nullified when folder is deleted")
        XCTAssertFalse(trashItem.canRestoreToOriginal, "Should not be restorable after folder deletion")
    }
}
