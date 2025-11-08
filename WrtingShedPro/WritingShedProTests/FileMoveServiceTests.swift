//
//  FileMoveServiceTests.swift
//  WritingShedProTests
//
//  Tests for FileMoveService
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class FileMoveServiceTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var service: FileMoveService!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory model container for testing
        let schema = Schema([
            Project.self,
            Folder.self,
            File.self,
            TextFile.self,
            Version.self,
            TrashItem.self
        ])
        
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            modelContext = ModelContext(modelContainer)
            service = FileMoveService(modelContext: modelContext)
        } catch {
            fatalError("Failed to create model container for tests: \(error)")
        }
    }
    
    override func tearDown() {
        service = nil
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    func createTestProject(name: String = "Test Project") -> Project {
        let project = Project(name: name)
        modelContext.insert(project)
        return project
    }
    
    func createTestFolder(name: String, project: Project) -> Folder {
        let folder = Folder(name: name, project: project)
        modelContext.insert(folder)
        return folder
    }
    
    func createTestFile(name: String, folder: Folder) -> TextFile {
        let textFile = TextFile(name: name, parentFolder: folder)
        modelContext.insert(textFile)
        return textFile
    }
    
    // MARK: - Move File Tests
    
    func testMoveFileBetweenFolders() throws {
        // Given
        let project = createTestProject()
        let sourceFolder = createTestFolder(name: "Source", project: project)
        let destFolder = createTestFolder(name: "Destination", project: project)
        let textFile = createTestFile(name: "Test.txt", folder: sourceFolder)
        
        // When
        try service.moveFile(textFile, to: destFolder)
        
        // Then
        XCTAssertEqual(textFile.parentFolder, destFolder, "File should be moved to destination folder")
        XCTAssertFalse(sourceFolder.textFiles?.contains(where: { $0.id == textFile.id }) ?? false, "File should be removed from source folder")
        XCTAssertTrue(destFolder.textFiles?.contains(where: { $0.id == textFile.id }) ?? false, "File should be added to destination folder")
    }
    
    func testMoveFileToSameFolder() throws {
        // Given
        let project = createTestProject()
        let folder = createTestFolder(name: "Documents", project: project)
        let textFile = createTestFile(name: "Test.txt", folder: folder)
        
        // When/Then - Should not throw error
        try service.moveFile(textFile, to: folder)
        XCTAssertEqual(textFile.parentFolder, folder, "File should remain in same folder")
    }
    
    func testMoveFileWithNameConflict() throws {
        // Given
        let project = createTestProject()
        let sourceFolder = createTestFolder(name: "Source", project: project)
        let destFolder = createTestFolder(name: "Destination", project: project)
        let textFile = createTestFile(name: "Test.txt", folder: sourceFolder)
        let _ = createTestFile(name: "Test.txt", folder: destFolder) // Existing file
        
        // When
        try service.moveFile(textFile, to: destFolder)
        
        // Then
        XCTAssertEqual(textFile.name, "Test (2).txt", "File should be renamed to avoid conflict")
        XCTAssertEqual(textFile.parentFolder, destFolder, "File should be moved to destination folder")
    }
    
    func testMoveFileAcrossProjectsThrowsError() throws {
        // Given
        let project1 = createTestProject(name: "Project 1")
        let project2 = createTestProject(name: "Project 2")
        let sourceFolder = createTestFolder(name: "Source", project: project1)
        let destFolder = createTestFolder(name: "Destination", project: project2)
        let textFile = createTestFile(name: "Test.txt", folder: sourceFolder)
        
        // When/Then
        XCTAssertThrowsError(try service.moveFile(textFile, to: destFolder)) { error in
            guard let moveError = error as? FileMoveError else {
                XCTFail("Expected FileMoveError")
                return
            }
            XCTAssertEqual(moveError, FileMoveError.crossProjectMove, "Should throw cross-project move error")
        }
    }
    
    func testMoveFileToTrashFolderThrowsError() throws {
        // Given
        let project = createTestProject()
        let sourceFolder = createTestFolder(name: "Documents", project: project)
        let trashFolder = createTestFolder(name: "Trash", project: project)
        let textFile = createTestFile(name: "Test.txt", folder: sourceFolder)
        
        // When/Then
        XCTAssertThrowsError(try service.moveFile(textFile, to: trashFolder)) { error in
            guard let moveError = error as? FileMoveError else {
                XCTFail("Expected FileMoveError")
                return
            }
            XCTAssertEqual(moveError, FileMoveError.cannotMoveToTrash, "Should throw cannot move to trash error")
        }
    }
    
    // MARK: - Move Multiple Files Tests
    
    func testMoveMultipleFiles() throws {
        // Given
        let project = createTestProject()
        let sourceFolder = createTestFolder(name: "Source", project: project)
        let destFolder = createTestFolder(name: "Destination", project: project)
        let file1 = createTestFile(name: "File1.txt", folder: sourceFolder)
        let file2 = createTestFile(name: "File2.txt", folder: sourceFolder)
        let file3 = createTestFile(name: "File3.txt", folder: sourceFolder)
        
        // When
        try service.moveFiles([file1, file2, file3], to: destFolder)
        
        // Then
        XCTAssertEqual(file1.parentFolder, destFolder, "File1 should be moved")
        XCTAssertEqual(file2.parentFolder, destFolder, "File2 should be moved")
        XCTAssertEqual(file3.parentFolder, destFolder, "File3 should be moved")
        XCTAssertEqual(destFolder.textFiles?.count, 3, "Destination should have 3 files")
    }
    
    func testMoveMultipleFilesRollsBackOnError() throws {
        // Given
        let project1 = createTestProject(name: "Project 1")
        let project2 = createTestProject(name: "Project 2")
        let sourceFolder1 = createTestFolder(name: "Source1", project: project1)
        let sourceFolder2 = createTestFolder(name: "Source2", project: project2)
        let destFolder = createTestFolder(name: "Destination", project: project1)
        let file1 = createTestFile(name: "File1.txt", folder: sourceFolder1)
        let file2 = createTestFile(name: "File2.txt", folder: sourceFolder2) // Different project
        
        // When/Then
        XCTAssertThrowsError(try service.moveFiles([file1, file2], to: destFolder)) { error in
            guard let moveError = error as? FileMoveError else {
                XCTFail("Expected FileMoveError")
                return
            }
            XCTAssertEqual(moveError, FileMoveError.crossProjectMove, "Should throw cross-project error")
        }
        
        // Verify rollback
        XCTAssertEqual(file1.parentFolder, sourceFolder1, "File1 should be rolled back to source")
        XCTAssertEqual(file2.parentFolder, sourceFolder2, "File2 should remain in source")
    }
    
    // MARK: - Delete File Tests
    
    func testDeleteFile() throws {
        // Given
        let project = createTestProject()
        let folder = createTestFolder(name: "Documents", project: project)
        let textFile = createTestFile(name: "Test.txt", folder: folder)
        
        // When
        try service.deleteFile(textFile)
        
        // Then
        XCTAssertNil(textFile.parentFolder, "File should be removed from folder")
        
        // Verify TrashItem created
        let textFileID = textFile.id
        let descriptor = FetchDescriptor<TrashItem>(
            predicate: #Predicate { $0.textFile?.id == textFileID }
        )
        let trashItems = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(trashItems.count, 1, "TrashItem should be created")
        XCTAssertEqual(trashItems.first?.textFile, textFile, "TrashItem should reference the text file")
        XCTAssertEqual(trashItems.first?.originalFolder, folder, "TrashItem should reference original folder")
        XCTAssertEqual(trashItems.first?.project, project, "TrashItem should reference project")
    }
    
    func testDeleteMultipleFiles() throws {
        // Given
        let project = createTestProject()
        let folder = createTestFolder(name: "Documents", project: project)
        let file1 = createTestFile(name: "File1.txt", folder: folder)
        let file2 = createTestFile(name: "File2.txt", folder: folder)
        let file3 = createTestFile(name: "File3.txt", folder: folder)
        
        // When
        try service.deleteFiles([file1, file2, file3])
        
        // Then
        XCTAssertNil(file1.parentFolder, "File1 should be removed from folder")
        XCTAssertNil(file2.parentFolder, "File2 should be removed from folder")
        XCTAssertNil(file3.parentFolder, "File3 should be removed from folder")
        
        // Verify TrashItems created
        let descriptor = FetchDescriptor<TrashItem>()
        let trashItems = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(trashItems.count, 3, "Three TrashItems should be created")
    }
    
    // MARK: - Put Back Tests
    
    func testPutBackToOriginalFolder() throws {
        // Given
        let project = createTestProject()
        let folder = createTestFolder(name: "Documents", project: project)
        let textFile = createTestFile(name: "Test.txt", folder: folder)
        try service.deleteFile(textFile)
        
        let textFileID = textFile.id
        let descriptor = FetchDescriptor<TrashItem>(
            predicate: #Predicate { $0.textFile?.id == textFileID }
        )
        let trashItems = try modelContext.fetch(descriptor)
        guard let trashItem = trashItems.first else {
            XCTFail("TrashItem not found")
            return
        }
        
        // When
        try service.putBack(trashItem)
        
        // Then
        XCTAssertEqual(textFile.parentFolder, folder, "File should be restored to original folder")
        
        // Verify TrashItem deleted
        let remainingTrash = try modelContext.fetch(descriptor)
        XCTAssertTrue(remainingTrash.isEmpty, "TrashItem should be deleted after put back")
    }
    
    func testPutBackToDraftWhenOriginalFolderDeleted() throws {
        // Given
        let project = createTestProject()
        let folder = createTestFolder(name: "Documents", project: project)
        let draftFolder = createTestFolder(name: "Draft", project: project)
        let textFile = createTestFile(name: "Test.txt", folder: folder)
        try service.deleteFile(textFile)
        
        let textFileID = textFile.id
        let descriptor = FetchDescriptor<TrashItem>(
            predicate: #Predicate { $0.textFile?.id == textFileID }
        )
        let trashItems = try modelContext.fetch(descriptor)
        guard let trashItem = trashItems.first else {
            XCTFail("TrashItem not found")
            return
        }
        
        // Delete original folder
        modelContext.delete(folder)
        try modelContext.save()
        
        // When
        try service.putBack(trashItem)
        
        // Then
        XCTAssertEqual(textFile.parentFolder, draftFolder, "File should be restored to Draft folder")
        
        // Verify TrashItem deleted
        let remainingTrash = try modelContext.fetch(descriptor)
        XCTAssertTrue(remainingTrash.isEmpty, "TrashItem should be deleted after put back")
    }
    
    func testPutBackThrowsErrorWhenNoDraftFolder() throws {
        // Given
        let project = createTestProject()
        let folder = createTestFolder(name: "Documents", project: project)
        let textFile = createTestFile(name: "Test.txt", folder: folder)
        try service.deleteFile(textFile)
        
        let textFileID = textFile.id
        let descriptor = FetchDescriptor<TrashItem>(
            predicate: #Predicate { $0.textFile?.id == textFileID }
        )
        let trashItems = try modelContext.fetch(descriptor)
        guard let trashItem = trashItems.first else {
            XCTFail("TrashItem not found")
            return
        }
        
        // Delete original folder (no Draft folder exists)
        modelContext.delete(folder)
        try modelContext.save()
        
        // When/Then
        XCTAssertThrowsError(try service.putBack(trashItem)) { error in
            guard let moveError = error as? FileMoveError else {
                XCTFail("Expected FileMoveError")
                return
            }
            XCTAssertEqual(moveError, FileMoveError.noDraftFolder, "Should throw no draft folder error")
        }
    }
    
    func testPutBackHandlesNameConflicts() throws {
        // Given
        let project = createTestProject()
        let folder = createTestFolder(name: "Documents", project: project)
        let textFile = createTestFile(name: "Test.txt", folder: folder)
        try service.deleteFile(textFile)
        
        // Create a new file with the same name
        let _ = createTestFile(name: "Test.txt", folder: folder)
        
        let textFileID = textFile.id
        let descriptor = FetchDescriptor<TrashItem>(
            predicate: #Predicate { $0.textFile?.id == textFileID }
        )
        let trashItems = try modelContext.fetch(descriptor)
        guard let trashItem = trashItems.first else {
            XCTFail("TrashItem not found")
            return
        }
        
        // When
        try service.putBack(trashItem)
        
        // Then
        XCTAssertEqual(textFile.name, "Test (2).txt", "File should be renamed to avoid conflict")
        XCTAssertEqual(textFile.parentFolder, folder, "File should be restored to original folder")
    }
    
    func testPutBackMultipleFiles() throws {
        // Given
        let project = createTestProject()
        let folder = createTestFolder(name: "Documents", project: project)
        let file1 = createTestFile(name: "File1.txt", folder: folder)
        let file2 = createTestFile(name: "File2.txt", folder: folder)
        let file3 = createTestFile(name: "File3.txt", folder: folder)
        
        try service.deleteFiles([file1, file2, file3])
        
        let descriptor = FetchDescriptor<TrashItem>()
        let trashItems = try modelContext.fetch(descriptor)
        
        // When
        try service.putBackMultiple(trashItems)
        
        // Then
        XCTAssertEqual(file1.parentFolder, folder, "File1 should be restored")
        XCTAssertEqual(file2.parentFolder, folder, "File2 should be restored")
        XCTAssertEqual(file3.parentFolder, folder, "File3 should be restored")
        
        // Verify all TrashItems deleted
        let remainingTrash = try modelContext.fetch(descriptor)
        XCTAssertTrue(remainingTrash.isEmpty, "All TrashItems should be deleted")
    }
    
    // MARK: - Validation Tests
    
    func testValidateMoveSuccess() throws {
        // Given
        let project = createTestProject()
        let sourceFolder = createTestFolder(name: "Source", project: project)
        let destFolder = createTestFolder(name: "Destination", project: project)
        let textFile = createTestFile(name: "Test.txt", folder: sourceFolder)
        
        // When/Then - Should not throw
        XCTAssertNoThrow(try service.validateMove(textFile, to: destFolder))
    }
    
    func testValidateMoveCrossProjectFails() throws {
        // Given
        let project1 = createTestProject(name: "Project 1")
        let project2 = createTestProject(name: "Project 2")
        let sourceFolder = createTestFolder(name: "Source", project: project1)
        let destFolder = createTestFolder(name: "Destination", project: project2)
        let textFile = createTestFile(name: "Test.txt", folder: sourceFolder)
        
        // When/Then
        XCTAssertThrowsError(try service.validateMove(textFile, to: destFolder)) { error in
            guard let moveError = error as? FileMoveError else {
                XCTFail("Expected FileMoveError")
                return
            }
            XCTAssertEqual(moveError, FileMoveError.crossProjectMove)
        }
    }
    
    func testValidateMoveToTrashFails() throws {
        // Given
        let project = createTestProject()
        let sourceFolder = createTestFolder(name: "Documents", project: project)
        let trashFolder = createTestFolder(name: "Trash", project: project)
        let textFile = createTestFile(name: "Test.txt", folder: sourceFolder)
        
        // When/Then
        XCTAssertThrowsError(try service.validateMove(textFile, to: trashFolder)) { error in
            guard let moveError = error as? FileMoveError else {
                XCTFail("Expected FileMoveError")
                return
            }
            XCTAssertEqual(moveError, FileMoveError.cannotMoveToTrash)
        }
    }
    
    // MARK: - Helper Method Tests
    
    func testIsTrashFolder() {
        // Given
        let project = createTestProject()
        let trashFolder = createTestFolder(name: "Trash", project: project)
        let trashFolderLowercase = createTestFolder(name: "trash", project: project)
        let normalFolder = createTestFolder(name: "Documents", project: project)
        
        // When/Then
        XCTAssertTrue(service.isTrashFolder(trashFolder), "Should detect 'Trash' folder")
        XCTAssertTrue(service.isTrashFolder(trashFolderLowercase), "Should detect 'trash' folder (case-insensitive)")
        XCTAssertFalse(service.isTrashFolder(normalFolder), "Should not detect normal folder as trash")
    }
    
    func testFindDraftFolder() throws {
        // Given
        let project = createTestProject()
        let _ = createTestFolder(name: "Documents", project: project)
        let draftFolder = createTestFolder(name: "Draft", project: project)
        
        // When
        let found = try service.findDraftFolder(in: project)
        
        // Then
        XCTAssertEqual(found, draftFolder, "Should find Draft folder")
    }
    
    func testFindDraftFolderThrowsWhenNotFound() throws {
        // Given
        let project = createTestProject()
        let _ = createTestFolder(name: "Documents", project: project)
        
        // When/Then
        XCTAssertThrowsError(try service.findDraftFolder(in: project)) { error in
            guard let moveError = error as? FileMoveError else {
                XCTFail("Expected FileMoveError")
                return
            }
            XCTAssertEqual(moveError, FileMoveError.noDraftFolder)
        }
    }
    
    func testGenerateUniqueName() {
        // Given
        let project = createTestProject()
        let folder = createTestFolder(name: "Documents", project: project)
        let _ = createTestFile(name: "Test.txt", folder: folder)
        let _ = createTestFile(name: "Test (2).txt", folder: folder)
        
        // When
        let uniqueName = service.generateUniqueName(baseName: "Test.txt", in: folder)
        
        // Then
        XCTAssertEqual(uniqueName, "Test (3).txt", "Should generate next available number")
    }
    
    func testGenerateUniqueNameWithoutConflict() {
        // Given
        let project = createTestProject()
        let folder = createTestFolder(name: "Documents", project: project)
        
        // When
        let uniqueName = service.generateUniqueName(baseName: "Test.txt", in: folder)
        
        // Then
        XCTAssertEqual(uniqueName, "Test.txt", "Should return original name when no conflict")
    }
}
