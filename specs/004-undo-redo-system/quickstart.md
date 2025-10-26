# Quick Start: Undo/Redo System

**Phase**: 004  
**For**: Developers implementing undo/redo functionality

---

## What You're Building

A comprehensive undo/redo system that allows users to:
- Undo/redo text changes with Cmd+Z / Cmd+Shift+Z
- Undo/redo formatting changes
- Persist undo history across app restarts
- See visual feedback for undo/redo availability

---

## Key Files to Create

### 1. Commands (in `Models/Commands/`)
```
Commands/
├── UndoableCommand.swift        # Protocol definition
├── TextInsertCommand.swift      # Insert text command
├── TextDeleteCommand.swift      # Delete text command
├── TextReplaceCommand.swift     # Replace text command
├── FormatApplyCommand.swift     # Apply formatting command
├── FormatRemoveCommand.swift    # Remove formatting command
├── CompositeCommand.swift       # Group multiple commands
└── SerializedCommand.swift      # For persistence
```

### 2. Undo Manager (in `Services/`)
```
Services/
├── TextFileUndoManager.swift    # Main undo/redo manager
└── TextDiffService.swift        # Diff algorithm utilities
```

### 3. UI Components (in `Views/`)
```
Views/
└── Components/
    └── UndoableTextEditor.swift # Text editor with undo support
```

### 4. Extensions
```
Extensions/
└── File+UndoRedo.swift          # File model undo/redo methods
```

---

## Implementation Steps

### Step 1: Create Command Protocol (Day 1)

```swift
// Models/Commands/UndoableCommand.swift
protocol UndoableCommand: Codable {
    var id: UUID { get }
    var timestamp: Date { get }
    var description: String { get }
    func execute()
    func undo()
}
```

### Step 2: Implement Basic Commands (Day 1-2)

```swift
// Models/Commands/TextInsertCommand.swift
struct TextInsertCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    let position: Int
    let text: String
    weak var targetFile: File?
    
    func execute() {
        // Insert text at position
    }
    
    func undo() {
        // Delete the inserted text
    }
}
```

### Step 3: Create Undo Manager (Day 2-3)

```swift
// Services/TextFileUndoManager.swift
class TextFileUndoManager: ObservableObject {
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false
    
    private var undoStack: [UndoableCommand] = []
    private var redoStack: [UndoableCommand] = []
    
    func execute(_ command: UndoableCommand) { /* ... */ }
    func undo() { /* ... */ }
    func redo() { /* ... */ }
}
```

### Step 4: Add to FileEditView (Day 4-5)

```swift
// Views/FileEditView.swift
struct FileEditView: View {
    @StateObject private var undoManager: TextFileUndoManager
    
    var body: some View {
        TextEditor(text: $text)
            .onChange(of: text) { old, new in
                handleTextChange(from: old, to: new)
            }
            .toolbar {
                ToolbarItem {
                    Button(action: { undoManager.undo() }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!undoManager.canUndo)
                }
                
                ToolbarItem {
                    Button(action: { undoManager.redo() }) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!undoManager.canRedo)
                }
            }
    }
    
    private func handleTextChange(from old: String, to new: String) {
        let diff = TextDiff.diff(from: old, to: new)
        let command = diff.toCommand(file: file)
        undoManager.execute(command)
    }
}
```

### Step 5: Add Keyboard Shortcuts (Day 5)

```swift
.onAppear {
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers == "z" {
                if event.modifierFlags.contains(.shift) {
                    undoManager.redo()
                } else {
                    undoManager.undo()
                }
                return nil
            }
        }
        return event
    }
}
```

### Step 6: Add Persistence (Day 6-7)

```swift
// Extensions/File+UndoRedo.swift
extension File {
    func saveUndoState(_ undoManager: TextFileUndoManager) {
        let encoder = JSONEncoder()
        undoStackData = try? encoder.encode(undoManager.undoStack)
        redoStackData = try? encoder.encode(undoManager.redoStack)
    }
    
    func restoreUndoState() -> TextFileUndoManager? {
        guard let data = undoStackData else { return nil }
        // Decode and restore
    }
}
```

---

## Testing Checklist

### Manual Testing
- [ ] Type text, press Cmd+Z → text undone
- [ ] Press Cmd+Shift+Z → text redone
- [ ] Click undo button → text undone
- [ ] Click redo button → text redone
- [ ] Undo button disabled when nothing to undo
- [ ] Redo button disabled when nothing to redo
- [ ] Type, undo, type new text → redo stack cleared
- [ ] Close app, reopen → undo history restored
- [ ] Apply formatting, undo → formatting removed
- [ ] Redo formatting → formatting reapplied

### Unit Tests to Write
```swift
func testTextInsertCommand() {
    let command = TextInsertCommand(...)
    command.execute()
    // Assert text inserted
    command.undo()
    // Assert text removed
}

func testUndoStackManagement() {
    let manager = TextFileUndoManager()
    manager.execute(command1)
    manager.execute(command2)
    XCTAssertTrue(manager.canUndo)
    manager.undo()
    XCTAssertTrue(manager.canRedo)
}
```

---

## Common Pitfalls

### 1. **Memory Leaks with Weak References**
❌ Problem: Commands hold strong references to File
```swift
var targetFile: File? // Strong reference → memory leak
```

✅ Solution: Use weak references
```swift
weak var targetFile: File?
```

### 2. **Not Clearing Redo Stack**
❌ Problem: Redo stack not cleared after new action
```swift
func execute(_ command: UndoableCommand) {
    command.execute()
    undoStack.append(command)
    // Forgot to clear redoStack!
}
```

✅ Solution: Clear redo stack on new action
```swift
func execute(_ command: UndoableCommand) {
    command.execute()
    redoStack.removeAll() // ← Important!
    undoStack.append(command)
}
```

### 3. **Forgetting to Update Published Properties**
❌ Problem: UI doesn't update
```swift
func undo() {
    undoStack.popLast()?.undo()
    // canUndo not updated → buttons stay enabled
}
```

✅ Solution: Update state after each operation
```swift
func undo() {
    undoStack.popLast()?.undo()
    updateState() // ← Updates @Published properties
}
```

### 4. **Not Handling Corrupted Persistence Data**
❌ Problem: App crashes on invalid data
```swift
let commands = try decoder.decode([SerializedCommand].self, from: data)
// Crashes if data is corrupted
```

✅ Solution: Handle errors gracefully
```swift
do {
    let commands = try decoder.decode([SerializedCommand].self, from: data)
    return commands
} catch {
    print("Corrupted undo data: \(error)")
    return nil // Start fresh
}
```

---

## Quick Reference

### SF Symbols
- Undo: `arrow.uturn.backward`
- Redo: `arrow.uturn.forward`

### Keyboard Shortcuts
- macOS Undo: `⌘Z`
- macOS Redo: `⇧⌘Z`
- iOS: Shake to undo (system default)

### Typical Command Flow
```
User types "Hello"
    ↓
onChange detects change
    ↓
Create TextInsertCommand
    ↓
undoManager.execute(command)
    ↓
Command added to undoStack
    ↓
canUndo = true
    ↓
UI updates (undo button enabled)
```

---

## Performance Tips

1. **Use Diffs**: Store differences, not full content
2. **Coalesce Typing**: Group rapid keystrokes into one undo action
3. **Limit Stack Size**: Default to 100 commands max
4. **Lazy Encode**: Only encode for persistence, not every command
5. **Profile Early**: Test with large files (>10MB) early in development

---

## Next Steps After Implementation

1. Add undo/redo for formatting changes (bold, italic, etc.)
2. Implement typing coalescing for better UX
3. Add visual timeline of changes
4. Optimize for large files
5. Add user-configurable stack size setting

---

## Need Help?

- Review `spec.md` for full technical details
- Check `data-model.md` for complete data structures
- See `plan.md` for detailed task breakdown
- Run unit tests to validate implementation

---

**Last Updated**: 26 October 2025
