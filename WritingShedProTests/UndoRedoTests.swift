import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class UndoRedoTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testFile: File!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory model container for testing
        let schema = Schema([Project.self, Folder.self, File.self, Version.self, TextFile.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = ModelContext(modelContainer)
            
            // Create test file
            testFile = File(name: "Test File", content: "Hello World")
            modelContext.insert(testFile)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    override func tearDown() {
        testFile = nil
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }
    
    // MARK: - TextInsertCommand Tests
    
    func testTextInsertCommandExecute() {
        // Given
        testFile.content = "Hello"
        let command = TextInsertCommand(position: 5, text: " World", targetFile: testFile)
        
        // When
        command.execute()
        
        // Then
        XCTAssertEqual(testFile.content, "Hello World")
    }
    
    func testTextInsertCommandUndo() {
        // Given
        testFile.content = "Hello"
        let command = TextInsertCommand(position: 5, text: " World", targetFile: testFile)
        command.execute()
        XCTAssertEqual(testFile.content, "Hello World")
        
        // When
        command.undo()
        
        // Then
        XCTAssertEqual(testFile.content, "Hello")
    }
    
    func testTextInsertAtBeginning() {
        // Given
        testFile.content = "World"
        let command = TextInsertCommand(position: 0, text: "Hello ", targetFile: testFile)
        
        // When
        command.execute()
        
        // Then
        XCTAssertEqual(testFile.content, "Hello World")
    }
    
    // MARK: - TextDeleteCommand Tests
    
    func testTextDeleteCommandExecute() {
        // Given
        testFile.content = "Hello World"
        let command = TextDeleteCommand(
            startPosition: 5,
            endPosition: 11,
            deletedText: " World",
            targetFile: testFile
        )
        
        // When
        command.execute()
        
        // Then
        XCTAssertEqual(testFile.content, "Hello")
    }
    
    func testTextDeleteCommandUndo() {
        // Given
        testFile.content = "Hello World"
        let command = TextDeleteCommand(
            startPosition: 5,
            endPosition: 11,
            deletedText: " World",
            targetFile: testFile
        )
        command.execute()
        XCTAssertEqual(testFile.content, "Hello")
        
        // When
        command.undo()
        
        // Then
        XCTAssertEqual(testFile.content, "Hello World")
    }
    
    // MARK: - TextReplaceCommand Tests
    
    func testTextReplaceCommandExecute() {
        // Given
        testFile.content = "Hello World"
        let command = TextReplaceCommand(
            startPosition: 6,
            endPosition: 11,
            oldText: "World",
            newText: "Swift",
            targetFile: testFile
        )
        
        // When
        command.execute()
        
        // Then
        XCTAssertEqual(testFile.content, "Hello Swift")
    }
    
    func testTextReplaceCommandUndo() {
        // Given
        testFile.content = "Hello World"
        let command = TextReplaceCommand(
            startPosition: 6,
            endPosition: 11,
            oldText: "World",
            newText: "Swift",
            targetFile: testFile
        )
        command.execute()
        XCTAssertEqual(testFile.content, "Hello Swift")
        
        // When
        command.undo()
        
        // Then
        XCTAssertEqual(testFile.content, "Hello World")
    }
    
    // MARK: - TextFileUndoManager Tests
    
    func testUndoManagerExecute() {
        // Given
        testFile.content = "Hello"
        let manager = TextFileUndoManager(file: testFile)
        let command = TextInsertCommand(position: 5, text: " World", targetFile: testFile)
        
        // When
        manager.execute(command)
        
        // Then
        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
        XCTAssertEqual(testFile.content, "Hello World")
    }
    
    func testUndoManagerUndo() {
        // Given
        testFile.content = "Hello"
        let manager = TextFileUndoManager(file: testFile)
        let command = TextInsertCommand(position: 5, text: " World", targetFile: testFile)
        manager.execute(command)
        
        // When
        manager.undo()
        
        // Then
        XCTAssertFalse(manager.canUndo)
        XCTAssertTrue(manager.canRedo)
        XCTAssertEqual(testFile.content, "Hello")
    }
    
    func testUndoManagerRedo() {
        // Given
        testFile.content = "Hello"
        let manager = TextFileUndoManager(file: testFile)
        let command = TextInsertCommand(position: 5, text: " World", targetFile: testFile)
        manager.execute(command)
        manager.undo()
        
        // When
        manager.redo()
        
        // Then
        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
        XCTAssertEqual(testFile.content, "Hello World")
    }
    
    func testUndoManagerMultipleOperations() {
        // Given
        testFile.content = "A"
        let manager = TextFileUndoManager(file: testFile)
        
        // When
        let command1 = TextInsertCommand(position: 1, text: "B", targetFile: testFile)
        manager.execute(command1)
        
        let command2 = TextInsertCommand(position: 2, text: "C", targetFile: testFile)
        manager.execute(command2)
        
        // Then
        XCTAssertEqual(testFile.content, "ABC")
        
        // Undo once
        manager.undo()
        XCTAssertEqual(testFile.content, "AB")
        
        // Undo again
        manager.undo()
        XCTAssertEqual(testFile.content, "A")
        
        // Redo
        manager.redo()
        XCTAssertEqual(testFile.content, "AB")
    }
    
    func testUndoManagerClear() {
        // Given
        testFile.content = "Hello"
        let manager = TextFileUndoManager(file: testFile)
        let command = TextInsertCommand(position: 5, text: " World", targetFile: testFile)
        manager.execute(command)
        
        // When
        manager.clear()
        
        // Then
        XCTAssertFalse(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
    }
    
    func testUndoManagerMaxStackSize() {
        // Given
        testFile.content = ""
        let manager = TextFileUndoManager(file: testFile, maxStackSize: 3)
        
        // When - Add 5 commands (exceeds max of 3)
        for i in 0..<5 {
            let command = TextInsertCommand(position: i, text: String(i), targetFile: testFile)
            manager.execute(command)
        }
        
        // Then - Only 3 should remain
        XCTAssertEqual(manager.undoStack.count, 3)
    }
    
    func testNewActionClearsRedoStack() {
        // Given
        testFile.content = "A"
        let manager = TextFileUndoManager(file: testFile)
        
        let command1 = TextInsertCommand(position: 1, text: "B", targetFile: testFile)
        manager.execute(command1)
        manager.undo()
        
        XCTAssertTrue(manager.canRedo)
        
        // When - Execute new command
        let command2 = TextInsertCommand(position: 1, text: "C", targetFile: testFile)
        manager.execute(command2)
        
        // Then - Redo stack should be cleared
        XCTAssertFalse(manager.canRedo)
        XCTAssertEqual(testFile.content, "AC")
    }
}
