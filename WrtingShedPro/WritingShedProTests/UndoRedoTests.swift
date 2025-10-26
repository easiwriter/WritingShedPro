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
        testFile.currentVersion?.updateContent("Hello")
        let command = TextInsertCommand(position: 5, text: " World", targetFile: testFile)
        
        // When
        command.execute()
        
        // Then
        XCTAssertEqual(testFile.currentVersion?.content, "Hello World")
    }
    
    func testTextInsertCommandUndo() {
        // Given
        testFile.currentVersion?.updateContent("Hello")
        let command = TextInsertCommand(position: 5, text: " World", targetFile: testFile)
        command.execute()
        XCTAssertEqual(testFile.currentVersion?.content, "Hello World")
        
        // When
        command.undo()
        
        // Then
        XCTAssertEqual(testFile.currentVersion?.content, "Hello")
    }
    
    func testTextInsertAtBeginning() {
        // Given
        testFile.currentVersion?.updateContent("World")
        let command = TextInsertCommand(position: 0, text: "Hello ", targetFile: testFile)
        
        // When
        command.execute()
        
        // Then
        XCTAssertEqual(testFile.currentVersion?.content, "Hello World")
    }
    
    // MARK: - TextDeleteCommand Tests
    
    func testTextDeleteCommandExecute() {
        // Given
        testFile.currentVersion?.updateContent("Hello World")
        let command = TextDeleteCommand(
            startPosition: 5,
            endPosition: 11,
            deletedText: " World",
            targetFile: testFile
        )
        
        // When
        command.execute()
        
        // Then
        XCTAssertEqual(testFile.currentVersion?.content, "Hello")
    }
    
    func testTextDeleteCommandUndo() {
        // Given
        testFile.currentVersion?.updateContent("Hello World")
        let command = TextDeleteCommand(
            startPosition: 5,
            endPosition: 11,
            deletedText: " World",
            targetFile: testFile
        )
        command.execute()
        XCTAssertEqual(testFile.currentVersion?.content, "Hello")
        
        // When
        command.undo()
        
        // Then
        XCTAssertEqual(testFile.currentVersion?.content, "Hello World")
    }
    
    // MARK: - TextReplaceCommand Tests
    
    func testTextReplaceCommandExecute() {
        // Given
        testFile.currentVersion?.updateContent("Hello World")
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
        XCTAssertEqual(testFile.currentVersion?.content, "Hello Swift")
    }
    
    func testTextReplaceCommandUndo() {
        // Given
        testFile.currentVersion?.updateContent("Hello World")
        let command = TextReplaceCommand(
            startPosition: 6,
            endPosition: 11,
            oldText: "World",
            newText: "Swift",
            targetFile: testFile
        )
        command.execute()
        XCTAssertEqual(testFile.currentVersion?.content, "Hello Swift")
        
        // When
        command.undo()
        
        // Then
        XCTAssertEqual(testFile.currentVersion?.content, "Hello World")
    }
    
    // MARK: - TextFileUndoManager Tests
    
    func testUndoManagerExecute() {
        // Given
        testFile.currentVersion?.updateContent("Hello")
        let manager = TextFileUndoManager(file: testFile)
        let command = TextInsertCommand(position: 5, text: " World", targetFile: testFile)
        
        // When
        manager.execute(command)
        
        // Then
        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
    }
    
    func testUndoManagerUndo() {
        // Given
        testFile.currentVersion?.updateContent("Hello")
        let manager = TextFileUndoManager(file: testFile)
        let command = TextInsertCommand(position: 5, text: " World", targetFile: testFile)
        
        // Note: Don't execute the command - it's already in the document from typing
        // Just add it to the manager
        manager.execute(command)
        
        // When
        manager.undo()
        
        // Then
        XCTAssertFalse(manager.canUndo)
        XCTAssertTrue(manager.canRedo)
        XCTAssertEqual(testFile.currentVersion?.content, "Hello")
    }
    
    func testUndoManagerRedo() {
        // Given
        testFile.currentVersion?.updateContent("Hello")
        let manager = TextFileUndoManager(file: testFile)
        let command = TextInsertCommand(position: 5, text: " World", targetFile: testFile)
        
        // Simulate: text already added by typing, command recorded
        testFile.currentVersion?.updateContent("Hello World")
        manager.execute(command)
        manager.undo()
        
        // When
        manager.redo()
        
        // Then
        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
        XCTAssertEqual(testFile.currentVersion?.content, "Hello World")
    }
    
    func testUndoManagerMultipleOperations() {
        // Given
        testFile.currentVersion?.updateContent("A")
        let manager = TextFileUndoManager(file: testFile)
        
        // When - Simulate typing: text added, then command recorded
        testFile.currentVersion?.updateContent("AB")
        let command1 = TextInsertCommand(position: 1, text: "B", targetFile: testFile)
        manager.execute(command1)
        
        // Flush to make commands separate (typing coalescing would normally merge them)
        manager.flushTypingBuffer()
        
        testFile.currentVersion?.updateContent("ABC")
        let command2 = TextInsertCommand(position: 2, text: "C", targetFile: testFile)
        manager.execute(command2)
        
        // Flush to finalize second command
        manager.flushTypingBuffer()
        
        // Then
        XCTAssertEqual(testFile.currentVersion?.content, "ABC")
        
        // Undo once
        manager.undo()
        XCTAssertEqual(testFile.currentVersion?.content, "AB")
        
        // Undo again
        manager.undo()
        XCTAssertEqual(testFile.currentVersion?.content, "A")
        
        // Redo
        manager.redo()
        XCTAssertEqual(testFile.currentVersion?.content, "AB")
    }
    
    func testUndoManagerClear() {
        // Given
        testFile.currentVersion?.updateContent("Hello")
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
        testFile.currentVersion?.updateContent("")
        let manager = TextFileUndoManager(file: testFile, maxStackSize: 3)
        
        // When - Add 5 commands (exceeds max of 3)
        var content = ""
        for i in 0..<5 {
            content += String(i)
            testFile.currentVersion?.updateContent(content)
            let command = TextInsertCommand(position: i, text: String(i), targetFile: testFile)
            manager.execute(command)
            // Flush each command to prevent coalescing
            manager.flushTypingBuffer()
        }
        
        // Then - Only 3 should remain
        XCTAssertEqual(manager.undoStack.count, 3)
    }
    
    func testNewActionClearsRedoStack() {
        // Given
        testFile.currentVersion?.updateContent("A")
        let manager = TextFileUndoManager(file: testFile)
        
        testFile.currentVersion?.updateContent("AB")
        let command1 = TextInsertCommand(position: 1, text: "B", targetFile: testFile)
        manager.execute(command1)
        manager.undo()
        
        XCTAssertTrue(manager.canRedo)
        
        // When - Execute new command
        testFile.currentVersion?.updateContent("AC")
        let command2 = TextInsertCommand(position: 1, text: "C", targetFile: testFile)
        manager.execute(command2)
        
        // Then - Redo stack should be cleared
        XCTAssertFalse(manager.canRedo)
        XCTAssertEqual(testFile.currentVersion?.content, "AC")
    }
}
