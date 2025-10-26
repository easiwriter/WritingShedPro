# Data Model: Undo/Redo System

**Phase**: 004  
**Status**: Planning 📋

---

## Overview

This document defines the data structures and models needed for the undo/redo system.

---

## Core Data Structures

### 1. UndoableCommand Protocol

```swift
/// Protocol for all undoable commands
protocol UndoableCommand: Codable {
    /// Unique identifier for the command
    var id: UUID { get }
    
    /// When the command was created
    var timestamp: Date { get }
    
    /// Human-readable description of the action
    var description: String { get }
    
    /// Execute the command (do the action)
    func execute()
    
    /// Reverse the command (undo the action)
    func undo()
}
```

### 2. Text Commands

```swift
/// Insert text at a specific position
struct TextInsertCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    
    let position: Int
    let text: String
    weak var targetFile: File?
    
    func execute() {
        // Insert text at position in targetFile
    }
    
    func undo() {
        // Delete text from position
    }
}

/// Delete text in a specific range
struct TextDeleteCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    
    let range: Range<Int>
    let deletedText: String // Store for undo
    weak var targetFile: File?
    
    func execute() {
        // Delete text in range from targetFile
    }
    
    func undo() {
        // Re-insert deletedText at range.lowerBound
    }
}

/// Replace text in a range with new text
struct TextReplaceCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    
    let range: Range<Int>
    let oldText: String
    let newText: String
    weak var targetFile: File?
    
    func execute() {
        // Replace text in range with newText
    }
    
    func undo() {
        // Replace newText back with oldText
    }
}
```

### 3. Formatting Commands

```swift
/// Apply formatting attributes to a text range
struct FormatApplyCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    
    let range: Range<Int>
    let attributes: [AttributedStringKey: Any]
    let previousAttributes: [AttributedStringKey: Any]? // For undo
    weak var targetFile: File?
    
    func execute() {
        // Apply attributes to range
    }
    
    func undo() {
        // Restore previousAttributes
    }
}

/// Remove formatting attributes from a text range
struct FormatRemoveCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    
    let range: Range<Int>
    let attributeKeys: [AttributedStringKey]
    let previousAttributes: [AttributedStringKey: Any] // For undo
    weak var targetFile: File?
    
    func execute() {
        // Remove attributes from range
    }
    
    func undo() {
        // Restore previousAttributes
    }
}
```

### 4. Composite Command

```swift
/// Group multiple commands into one undoable action
struct CompositeCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    
    let commands: [UndoableCommand]
    
    func execute() {
        commands.forEach { $0.execute() }
    }
    
    func undo() {
        commands.reversed().forEach { $0.undo() }
    }
}
```

---

## Undo Manager

```swift
/// Manages undo/redo stacks for a text file
class TextFileUndoManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Whether undo is available
    @Published private(set) var canUndo: Bool = false
    
    /// Whether redo is available
    @Published private(set) var canRedo: Bool = false
    
    /// Description of the action that would be undone
    @Published private(set) var undoActionName: String?
    
    /// Description of the action that would be redone
    @Published private(set) var redoActionName: String?
    
    // MARK: - Private Properties
    
    /// Stack of undoable commands
    private var undoStack: [UndoableCommand] = []
    
    /// Stack of redoable commands
    private var redoStack: [UndoableCommand] = []
    
    /// Maximum number of commands to keep in stack
    private let maxStackSize: Int
    
    /// Reference to the file being edited
    private weak var file: File?
    
    /// Buffer for typing coalescing
    private var typingBuffer: TextInsertCommand?
    
    /// Timer for typing coalescing
    private var typingTimer: Timer?
    
    /// Time interval for grouping typing (default 0.5 seconds)
    private let typingGroupInterval: TimeInterval = 0.5
    
    // MARK: - Initialization
    
    init(file: File, maxStackSize: Int = 100) {
        self.file = file
        self.maxStackSize = maxStackSize
    }
    
    // MARK: - Public Methods
    
    /// Execute a command and add it to the undo stack
    func execute(_ command: UndoableCommand) {
        command.execute()
        
        // Clear redo stack when new action performed
        redoStack.removeAll()
        
        // Add to undo stack
        undoStack.append(command)
        
        // Trim if exceeds max size
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
        
        updateState()
    }
    
    /// Undo the last command
    func undo() {
        guard let command = undoStack.popLast() else { return }
        
        command.undo()
        redoStack.append(command)
        
        updateState()
    }
    
    /// Redo the last undone command
    func redo() {
        guard let command = redoStack.popLast() else { return }
        
        command.execute()
        undoStack.append(command)
        
        updateState()
    }
    
    /// Clear all undo/redo history
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        typingBuffer = nil
        typingTimer?.invalidate()
        updateState()
    }
    
    /// Flush typing buffer (force group current typing)
    func flushTypingBuffer() {
        guard let buffer = typingBuffer else { return }
        execute(buffer)
        typingBuffer = nil
        typingTimer?.invalidate()
    }
    
    // MARK: - Private Methods
    
    private func updateState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        undoActionName = undoStack.last?.description
        redoActionName = redoStack.last?.description
    }
    
    private func startTypingTimer() {
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(
            withTimeInterval: typingGroupInterval,
            repeats: false
        ) { [weak self] _ in
            self?.flushTypingBuffer()
        }
    }
}
```

---

## Text Diff Utilities

```swift
/// Represents a difference between two strings
struct TextDiff: Codable {
    let changes: [Change]
    
    enum Change: Codable {
        case insert(position: Int, text: String)
        case delete(range: Range<Int>, deletedText: String)
    }
    
    /// Compute diff from old string to new string
    static func diff(from old: String, to new: String) -> TextDiff {
        // Implementation using Myers' diff algorithm or similar
        // Returns minimal set of changes to transform old to new
    }
    
    /// Apply diff to a string
    static func apply(_ diff: TextDiff, to text: String) -> String {
        var result = text
        for change in diff.changes {
            switch change {
            case .insert(let position, let text):
                result.insert(contentsOf: text, at: result.index(result.startIndex, offsetBy: position))
            case .delete(let range, _):
                result.removeSubrange(range)
            }
        }
        return result
    }
    
    /// Create a command from a diff
    func toCommand(file: File) -> UndoableCommand {
        if changes.count == 1 {
            switch changes[0] {
            case .insert(let position, let text):
                return TextInsertCommand(
                    id: UUID(),
                    timestamp: Date(),
                    description: "Typing",
                    position: position,
                    text: text,
                    targetFile: file
                )
            case .delete(let range, let deletedText):
                return TextDeleteCommand(
                    id: UUID(),
                    timestamp: Date(),
                    description: "Deletion",
                    range: range,
                    deletedText: deletedText,
                    targetFile: file
                )
            }
        } else {
            // Multiple changes - create composite command
            let commands = changes.map { change -> UndoableCommand in
                // Convert each change to appropriate command
            }
            return CompositeCommand(
                id: UUID(),
                timestamp: Date(),
                description: "Edit",
                commands: commands
            )
        }
    }
}
```

---

## Serialization Format

### SerializedCommand

```swift
/// Codable wrapper for persisting commands
struct SerializedCommand: Codable {
    let id: UUID
    let type: CommandType
    let timestamp: Date
    let description: String
    let data: CommandData
    
    enum CommandType: String, Codable {
        case textInsert
        case textDelete
        case textReplace
        case formatApply
        case formatRemove
        case composite
    }
    
    enum CommandData: Codable {
        case textInsert(position: Int, text: String)
        case textDelete(range: ClosedRange<Int>, deletedText: String)
        case textReplace(range: ClosedRange<Int>, oldText: String, newText: String)
        case formatApply(range: ClosedRange<Int>, attributes: [String: String])
        case formatRemove(range: ClosedRange<Int>, attributeKeys: [String])
        case composite(commands: [SerializedCommand])
    }
    
    /// Convert from UndoableCommand
    static func from(_ command: UndoableCommand) -> SerializedCommand {
        // Implementation
    }
    
    /// Convert to UndoableCommand
    func toCommand(file: File) -> UndoableCommand {
        // Implementation
    }
}
```

---

## File Model Extension

```swift
extension File {
    // MARK: - Undo/Redo Properties (add to existing File model)
    
    /// Serialized undo stack
    var undoStackData: Data?
    
    /// Serialized redo stack
    var redoStackData: Data?
    
    /// Maximum size of undo/redo stacks
    var undoStackMaxSize: Int = 100
    
    /// Last time undo state was saved
    var lastUndoSaveDate: Date?
    
    // MARK: - Undo/Redo Methods
    
    /// Save current undo manager state
    func saveUndoState(_ undoManager: TextFileUndoManager) {
        do {
            // Convert undo stack to serialized commands
            let undoCommands = undoManager.undoStack.map { SerializedCommand.from($0) }
            let redoCommands = undoManager.redoStack.map { SerializedCommand.from($0) }
            
            // Encode to JSON
            let encoder = JSONEncoder()
            undoStackData = try encoder.encode(undoCommands)
            redoStackData = try encoder.encode(redoCommands)
            lastUndoSaveDate = Date()
        } catch {
            print("Failed to save undo state: \(error)")
        }
    }
    
    /// Restore undo manager from saved state
    func restoreUndoState() -> TextFileUndoManager? {
        guard let undoData = undoStackData else { return nil }
        
        do {
            let decoder = JSONDecoder()
            let undoCommands = try decoder.decode([SerializedCommand].self, from: undoData)
            
            let undoManager = TextFileUndoManager(file: self, maxStackSize: undoStackMaxSize)
            
            // Restore commands
            undoManager.undoStack = undoCommands.map { $0.toCommand(file: self) }
            
            if let redoData = redoStackData {
                let redoCommands = try decoder.decode([SerializedCommand].self, from: redoData)
                undoManager.redoStack = redoCommands.map { $0.toCommand(file: self) }
            }
            
            return undoManager
        } catch {
            print("Failed to restore undo state: \(error)")
            return nil
        }
    }
    
    /// Clear undo history
    func clearUndoHistory() {
        undoStackData = nil
        redoStackData = nil
        lastUndoSaveDate = nil
    }
}
```

---

## Memory Estimates

### Per Command Storage
- **TextInsertCommand**: ~100-500 bytes (depending on text length)
- **TextDeleteCommand**: ~100-500 bytes (stores deleted text)
- **TextReplaceCommand**: ~200-1000 bytes (stores both old and new text)
- **FormatApplyCommand**: ~200-400 bytes (attributes dictionary)
- **CompositeCommand**: Sum of contained commands

### Stack Storage
- **100 commands** (default max): ~10-50 KB
- **1000 commands**: ~100-500 KB

### Optimization Strategies
- Use diffs instead of full content snapshots
- Compress persisted data using gzip
- Store string references (interning) for repeated content
- Lazy encoding (only encode when persisting)

---

## Relationships

```
File (1) -----> (0..1) TextFileUndoManager
                        |
                        +---> UndoStack: [UndoableCommand]
                        +---> RedoStack: [UndoableCommand]

UndoableCommand <|---- TextInsertCommand
                <|---- TextDeleteCommand
                <|---- TextReplaceCommand
                <|---- FormatApplyCommand
                <|---- FormatRemoveCommand
                <|---- CompositeCommand
```

---

## Usage Example

```swift
// In FileEditView
@StateObject private var undoManager: TextFileUndoManager

// When text changes
func handleTextChange(from old: String, to new: String) {
    let diff = TextDiff.diff(from: old, to: new)
    let command = diff.toCommand(file: file)
    undoManager.execute(command)
}

// Undo button action
Button("Undo") {
    undoManager.undo()
}
.disabled(!undoManager.canUndo)

// On app background
func saveUndoState() {
    file.saveUndoState(undoManager)
    try? modelContext.save()
}

// On file open
func loadFile() {
    if let restoredManager = file.restoreUndoState() {
        self.undoManager = restoredManager
    } else {
        self.undoManager = TextFileUndoManager(file: file)
    }
}
```

---

**Last Updated**: 26 October 2025
