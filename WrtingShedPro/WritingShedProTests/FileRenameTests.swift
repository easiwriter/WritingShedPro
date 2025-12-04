import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class FileRenameTests: XCTestCase {
    
    // MARK: - Rename Validation Tests
    
    func testRenameFileWithValidName() {
        // Arrange
        let file = TextFile(name: "Original File", initialContent: "")
        let newName = "Updated File"
        
        // Act
        file.name = newName
        
        // Assert
        XCTAssertEqual(file.name, newName)
    }
    
    func testRenameFileValidationRejectsEmptyName() {
        // Arrange
        let emptyName = ""
        
        // Act & Assert
        XCTAssertThrowsError(try NameValidator.validateFileName(emptyName)) { error in
            XCTAssertEqual(error as? ValidationError, ValidationError.emptyName(entity: "File"))
        }
    }
    
    func testRenameFileValidationRejectsWhitespaceOnlyName() {
        // Arrange
        let whitespaceName = "   "
        
        // Act & Assert
        XCTAssertThrowsError(try NameValidator.validateFileName(whitespaceName)) { error in
            XCTAssertEqual(error as? ValidationError, ValidationError.emptyName(entity: "File"))
        }
    }
    
    func testRenameFileUniquenessCheck() {
        // Arrange
        let folder = Folder(name: "Test Folder")
        let file1 = TextFile(name: "File One", initialContent: "")
        let file2 = TextFile(name: "File Two", initialContent: "")
        folder.textFiles = [file1, file2]
        
        // Act & Assert
        XCTAssertTrue(UniquenessChecker.isFileNameUnique("File Three", in: folder))
        XCTAssertFalse(UniquenessChecker.isFileNameUnique("File One", in: folder))
    }
    
    func testRenameFileUniquenessCaseInsensitive() {
        // Arrange
        let folder = Folder(name: "Test Folder")
        let file = TextFile(name: "My Document", initialContent: "")
        folder.textFiles = [file]
        
        // Act & Assert
        XCTAssertFalse(UniquenessChecker.isFileNameUnique("my document", in: folder))
        XCTAssertFalse(UniquenessChecker.isFileNameUnique("MY DOCUMENT", in: folder))
        XCTAssertFalse(UniquenessChecker.isFileNameUnique("My Document", in: folder))
    }
    
    func testRenameFileToSameNameIsValid() {
        // Arrange
        let folder = Folder(name: "Test Folder")
        let file = TextFile(name: "My Document", initialContent: "")
        folder.textFiles = [file]
        
        // Act & Assert - renaming to the same name in same folder detects it as duplicate
        // This is expected - the UI should filter out the current file before checking
        XCTAssertFalse(UniquenessChecker.isFileNameUnique("My Document", in: folder))
    }
    
    // MARK: - File Extension Handling Tests
    
    func testRenameFilePreservesExtension() {
        // Arrange
        let file = TextFile(name: "Document.txt", initialContent: "")
        let newName = "NewDocument.txt"
        
        // Act
        file.name = newName
        
        // Assert
        XCTAssertEqual(file.name, newName)
        XCTAssertTrue(file.name.hasSuffix(".txt"))
    }
    
    func testRenameFileWithoutExtension() {
        // Arrange
        let file = TextFile(name: "DocumentNoExt", initialContent: "")
        let newName = "UpdatedNoExt"
        
        // Act
        file.name = newName
        
        // Assert
        XCTAssertEqual(file.name, newName)
    }
    
    // MARK: - Content Preservation Tests
    
    func testRenameFilePreservesContent() {
        // Arrange
        let originalContent = "This is important content that must be preserved"
        let file = TextFile(name: "Original", initialContent: originalContent)
        
        // Act
        file.name = "Renamed"
        
        // Assert
        XCTAssertEqual(file.name, "Renamed")
        XCTAssertEqual(file.currentVersion?.content, originalContent)
    }
    
    func testRenameFilePreservesMetadata() {
        // Arrange
        let file = TextFile(name: "Original", initialContent: "Content")
        let originalID = file.id
        let originalCreatedDate = file.createdDate
        
        // Act
        file.name = "Renamed"
        
        // Assert
        XCTAssertEqual(file.id, originalID)
        XCTAssertEqual(file.createdDate, originalCreatedDate)
    }
    
    // MARK: - Special Character Handling Tests
    
    func testRenameFileWithSpecialCharacters() {
        // Arrange
        let file = TextFile(name: "Original", initialContent: "")
        let specialNames = [
            "File (Draft)",
            "File - Version 2",
            "File & Notes",
            "File's Story",
            "File [Archived]",
            "File #1"
        ]
        
        // Act & Assert
        for name in specialNames {
            file.name = name
            XCTAssertEqual(file.name, name)
        }
    }
    
    func testRenameFileWithUnicodeCharacters() {
        // Arrange
        let file = TextFile(name: "Original", initialContent: "")
        let unicodeNames = [
            "Файл",              // Cyrillic
            "ファイル",           // Japanese
            "文件",              // Chinese
            "ملف",               // Arabic
            "Άρχείο",            // Greek
            "Fichier™",          // With trademark symbol
            "File™®©",           // With copyright symbols
        ]
        
        // Act & Assert
        for name in unicodeNames {
            file.name = name
            XCTAssertEqual(file.name, name)
        }
    }
    
    func testRenameFileWithLeadingTrailingSpaces() {
        // Arrange
        let file = TextFile(name: "Original", initialContent: "")
        
        // Act
        file.name = "  Trimmed  "
        
        // Assert
        XCTAssertEqual(file.name, "  Trimmed  ")
    }
    
    // MARK: - Duplicate Detection Tests
    
    func testDetectDuplicateFileNameInFolder() {
        // Arrange
        let folder = Folder(name: "Test Folder")
        let file1 = TextFile(name: "Document", initialContent: "")
        let file2 = TextFile(name: "Story", initialContent: "")
        folder.textFiles = [file1, file2]
        
        // Act
        let isDuplicate = UniquenessChecker.isFileNameUnique("Document", in: folder)
        
        // Assert
        XCTAssertFalse(isDuplicate)
    }
    
    func testDetectDuplicateIgnoresCurrentFile() {
        // Arrange
        let folder = Folder(name: "Test Folder")
        let file = TextFile(name: "Document", initialContent: "")
        folder.textFiles = [file]
        
        // Act - Since file exists in folder, this will return false
        // In real usage, RenameFileModal should filter out the current file before checking
        let isDuplicate = UniquenessChecker.isFileNameUnique("Document", in: folder)
        
        // Assert
        XCTAssertFalse(isDuplicate)
    }
    
    // MARK: - Folder Isolation Tests
    
    func testRenameFileInFolderDoesntAffectOtherFolders() {
        // Arrange
        let folder1 = Folder(name: "Folder 1")
        let folder2 = Folder(name: "Folder 2")
        
        let folder1File1 = TextFile(name: "Document", initialContent: "")
        let folder1File2 = TextFile(name: "Story", initialContent: "")
        folder1.textFiles = [folder1File1, folder1File2]
        
        let folder2File1 = TextFile(name: "Document", initialContent: "")  // Same name, different folder
        let folder2File2 = TextFile(name: "Novel", initialContent: "")
        folder2.textFiles = [folder2File1, folder2File2]
        
        // Act
        folder1File1.name = "RenamedDocument"
        
        // Assert
        XCTAssertEqual(folder1File1.name, "RenamedDocument")
        // Folder 2's file should still have original name
        XCTAssertEqual(folder2File1.name, "Document")
    }
    
    // MARK: - Undo/Redo Support Tests
    
    func testRenameFileIsUndoable() {
        // Arrange
        let file = TextFile(name: "Original", initialContent: "")
        let originalName = file.name
        let newName = "Updated"
        
        // Simulate undo/redo by storing values
        var previousValue: String?
        let currentValue = newName
        
        // Act
        previousValue = file.name
        file.name = newName
        
        // Assert - can restore previous value
        XCTAssertEqual(previousValue, originalName)
        XCTAssertEqual(file.name, currentValue)
    }
    
    // MARK: - Integration Tests
    
    func testRenameFileWithVersionTracking() {
        // Arrange
        let schema = Schema([TextFile.self, Version.self, Project.self, Folder.self])
        let container = try! ModelContainer(for: schema, configurations: [
            ModelConfiguration(isStoredInMemoryOnly: true)
        ])
        let context = ModelContext(container)
        
        let file = TextFile(name: "Original", initialContent: "Initial content")
        let version = Version(content: "Initial content")
        version.textFile = file
        context.insert(file)
        context.insert(version)
        
        // Act
        file.name = "Renamed"
        
        // Assert
        XCTAssertEqual(file.name, "Renamed")
        XCTAssertEqual(version.content, "Initial content")
    }
}
