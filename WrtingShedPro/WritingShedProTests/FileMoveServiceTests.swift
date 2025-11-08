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
    
    // MARK: - Edge Case Tests
    
    func testMoveLargeSelection() throws {
        // Given: Create 150 files to test large selection performance
        let project = createTestProject()
        let sourceFolder = createTestFolder(name: "Source", project: project)
        let destFolder = createTestFolder(name: "Destination", project: project)
        
        var files: [TextFile] = []
        for i in 1...150 {
            let file = createTestFile(name: "File\(i).txt", folder: sourceFolder)
            files.append(file)
        }
        
        // When
        let startTime = Date()
        try service.moveFiles(files, to: destFolder)
        let duration = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(duration, 5.0, "Moving 150 files should complete in under 5 seconds")
        XCTAssertEqual(destFolder.textFiles?.count ?? 0, 150, "All 150 files should be in destination")
        XCTAssertEqual(sourceFolder.textFiles?.count ?? 0, 0, "Source should be empty")
        
        // Verify all files moved correctly
        for file in files {
            XCTAssertEqual(file.parentFolder, destFolder, "File should be in destination folder")
        }
    }
    
    func testDeleteLargeSelection() throws {
        // Given: Create 150 files to test large deletion performance
        let project = createTestProject()
        let folder = createTestFolder(name: "Documents", project: project)
        
        var files: [TextFile] = []
        for i in 1...150 {
            let file = createTestFile(name: "File\(i).txt", folder: folder)
            files.append(file)
        }
        
        // When
        let startTime = Date()
        try service.deleteFiles(files)
        let duration = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(duration, 5.0, "Deleting 150 files should complete in under 5 seconds")
        XCTAssertEqual(folder.textFiles?.count ?? 0, 0, "Folder should be empty")
        
        // Verify all TrashItems created
        let descriptor = FetchDescriptor<TrashItem>()
        let trashItems = try modelContext.fetch(descriptor)
        XCTAssertEqual(trashItems.count, 150, "Should create 150 TrashItems")
    }
    
    func testPutBackLargeSelectionWithPerformance() throws {
        // Given: Create 150 trash items
        let project = createTestProject()
        let folder = createTestFolder(name: "Documents", project: project)
        
        var trashItems: [TrashItem] = []
        for i in 1...150 {
            let file = createTestFile(name: "File\(i).txt", folder: folder)
            try service.deleteFile(file)
            
            let fileID = file.id
            let descriptor = FetchDescriptor<TrashItem>(
                predicate: #Predicate { $0.textFile?.id == fileID }
            )
            if let item = try modelContext.fetch(descriptor).first {
                trashItems.append(item)
            }
        }
        
        // When
        let startTime = Date()
        let results = try service.putBackMultiple(trashItems)
        let duration = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(duration, 5.0, "Putting back 150 files should complete in under 5 seconds")
        XCTAssertEqual(results.count, 150, "Should restore all 150 files")
        XCTAssertEqual(folder.textFiles?.count ?? 0, 150, "All files should be back in folder")
    }
    
    func testPutBackMultipleFilesWithSameName() throws {
        // Given: Create multiple trash items with same original name
        let project = createTestProject()
        let folder = createTestFolder(name: "Documents", project: project)
        
        // Create 3 files with same name "Document.txt" at different times
        let file1 = createTestFile(name: "Document.txt", folder: folder)
        try service.deleteFile(file1)
        
        let file2 = createTestFile(name: "Document.txt", folder: folder)
        try service.deleteFile(file2)
        
        let file3 = createTestFile(name: "Document.txt", folder: folder)
        try service.deleteFile(file3)
        
        // Get all trash items
        let descriptor = FetchDescriptor<TrashItem>()
        let trashItems = try modelContext.fetch(descriptor)
        XCTAssertEqual(trashItems.count, 3, "Should have 3 trash items")
        
        // When: Put back all three
        let results = try service.putBackMultiple(trashItems)
        
        // Then: Should auto-rename to avoid conflicts
        XCTAssertEqual(results.count, 3, "Should restore all 3 files")
        XCTAssertEqual(folder.textFiles?.count ?? 0, 3, "Should have 3 files in folder")
        
        // Verify unique names
        let fileNames = (folder.textFiles ?? []).map { $0.name }.sorted()
        XCTAssertTrue(fileNames.contains("Document.txt"), "Should have original name")
        XCTAssertTrue(fileNames.contains("Document (2).txt"), "Should have auto-renamed version")
        XCTAssertTrue(fileNames.contains("Document (3).txt"), "Should have second auto-renamed version")
    }
    
    func testConcurrentMoveOperations() throws {
        // Given: Create multiple files
        let project = createTestProject()
        let folder1 = createTestFolder(name: "Folder1", project: project)
        let folder2 = createTestFolder(name: "Folder2", project: project)
        let folder3 = createTestFolder(name: "Folder3", project: project)
        
        let file1 = createTestFile(name: "File1.txt", folder: folder1)
        let file2 = createTestFile(name: "File2.txt", folder: folder1)
        let file3 = createTestFile(name: "File3.txt", folder: folder2)
        
        // When: Perform concurrent move operations
        let expectation1 = expectation(description: "Move 1 complete")
        let expectation2 = expectation(description: "Move 2 complete")
        let expectation3 = expectation(description: "Move 3 complete")
        
        DispatchQueue.global().async {
            do {
                try self.service.moveFile(file1, to: folder2)
                expectation1.fulfill()
            } catch {
                XCTFail("Move 1 failed: \(error)")
            }
        }
        
        DispatchQueue.global().async {
            do {
                try self.service.moveFile(file2, to: folder3)
                expectation2.fulfill()
            } catch {
                XCTFail("Move 2 failed: \(error)")
            }
        }
        
        DispatchQueue.global().async {
            do {
                try self.service.moveFile(file3, to: folder1)
                expectation3.fulfill()
            } catch {
                XCTFail("Move 3 failed: \(error)")
            }
        }
        
        // Then: Wait for all operations to complete
        wait(for: [expectation1, expectation2, expectation3], timeout: 10.0)
        
        // Verify final state
        XCTAssertEqual(file1.parentFolder, folder2, "File1 should be in Folder2")
        XCTAssertEqual(file2.parentFolder, folder3, "File2 should be in Folder3")
        XCTAssertEqual(file3.parentFolder, folder1, "File3 should be in Folder1")
    }
    
    func testLargeTrashPerformance() throws {
        // Given: Create 1000 trash items to test performance
        let project = createTestProject()
        let folder = createTestFolder(name: "Documents", project: project)
        
        for i in 1...1000 {
            let file = createTestFile(name: "File\(i).txt", folder: folder)
            try service.deleteFile(file)
        }
        
        // When: Query trash
        let startTime = Date()
        let descriptor = FetchDescriptor<TrashItem>(sortBy: [SortDescriptor(\.deletedDate, order: .reverse)])
        let trashItems = try modelContext.fetch(descriptor)
        let duration = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(duration, 2.0, "Fetching 1000 trash items should complete in under 2 seconds")
        XCTAssertEqual(trashItems.count, 1000, "Should have 1000 trash items")
    }
}

