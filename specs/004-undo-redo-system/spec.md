# Specification: Undo/Redo System for Text Files (iOS/MacOS)

**Phase:** 004  
**Status:** Planning 📋  
**Dependencies:** [003-text-file-creation](../003-text-file-creation/spec.md)

---

## Context & Prerequisites

### Completed in Phase 003 ✅
- Text file creation in all file-only folders
- Basic text editing with TextEditor
- Content stored as AttributedString in File model
- File list display and navigation
- Content persistence in SwiftData

### Current Limitations
- No undo/redo functionality for text changes
- No undo/redo for formatting changes
- Limited to system-level undo (insufficient for complex editing)
- No persistent undo history across sessions

---

## Overview

Implement comprehensive undo/redo functionality for text files, supporting both content changes and formatting modifications. The system will provide unlimited undo/redo levels with persistent history, keyboard shortcuts, and visual feedback. This phase builds the foundation for advanced text editing features before implementing the complete editor.

**Key Design Decisions:**
- Custom undo/redo manager (not relying solely on system UndoManager)
- Command pattern for all text and formatting operations
- Persistent undo stack stored with file versions
- Keyboard shortcuts (Cmd+Z, Cmd+Shift+Z on macOS / Cmd+Z on iOS)
- Visual indicators for undo/redo state
- Stack limits to prevent memory issues (configurable, default 100 actions)

---

## Goals

### Primary Goals
1. **Content undo/redo**: Full undo/redo support for text insertion, deletion, and replacement
2. **Formatting undo/redo**: Support for undoing/redoing text formatting changes (bold, italic, font changes, etc.)
3. **Unlimited history**: Support configurable undo history depth (default 100 actions)
4. **Keyboard shortcuts**: Standard Cmd+Z (undo) and Cmd+Shift+Z (redo) shortcuts
5. **Visual feedback**: Enable/disable state for undo/redo buttons based on stack state
6. **Persistent history**: Save undo stack with file for recovery after app restart
7. **Memory efficiency**: Efficient storage using diffs rather than full content snapshots
8. **Grouping**: Intelligent grouping of rapid changes (typing) into single undo actions

### Secondary Goals
- Undo/redo toolbar buttons in text editor
- Undo/redo menu items in app menu (macOS)
- Clear undo history command
- Redo branch support (undo, make changes, redo shows new branch)

### Non-Goals (Future Phases)
- Multi-cursor undo/redo
- Collaborative editing with conflict resolution
- Undo across multiple files
- Visual timeline of changes

---

## Technical Architecture

### 1. Command Pattern Implementation

#### UndoableCommand Protocol
```swift
protocol UndoableCommand {
    var timestamp: Date { get }
    var description: String { get }
    func execute()
    func undo()
}
```

#### Command Types
- **TextInsertCommand**: Insert text at position
- **TextDeleteCommand**: Delete text range
- **TextReplaceCommand**: Replace text range with new text
- **FormatApplyCommand**: Apply formatting to range
- **FormatRemoveCommand**: Remove formatting from range
- **CompositeCommand**: Group multiple commands (for typing coalescing)

### 2. Undo Manager

```swift
class TextFileUndoManager: ObservableObject {
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false
    
    private var undoStack: [UndoableCommand] = []
    private var redoStack: [UndoableCommand] = []
    private let maxStackSize: Int
    
    // Command grouping for typing
    private var typingBuffer: TextInsertCommand?
    private var typingTimer: Timer?
    
    func execute(_ command: UndoableCommand)
    func undo()
    func redo()
    func clear()
    func groupingDelay() -> TimeInterval // 0.5 seconds default
}
```

### 3. Text Editor Integration

#### FileEditView Changes
- Add `@StateObject var undoManager = TextFileUndoManager()`
- Wrap TextEditor changes in commands
- Add undo/redo toolbar buttons
- Implement keyboard shortcuts
- Bind undo manager to TextEditor's UndoManager

#### Text Change Detection
```swift
struct UndoableTextEditor: View {
    @Binding var text: AttributedString
    @ObservedObject var undoManager: TextFileUndoManager
    
    var body: some View {
        TextEditor(text: $text)
            .onChange(of: text) { oldValue, newValue in
                handleTextChange(from: oldValue, to: newValue)
            }
    }
    
    private func handleTextChange(from old: AttributedString, to new: AttributedString) {
        // Detect change type (insert, delete, replace)
        // Create appropriate command
        // Execute through undo manager
    }
}
```

### 4. Storage Model

#### Extend File Model
```swift
// In BaseModels.swift - File class extension
@Model
final class File {
    // ... existing properties ...
    
    // Undo/redo persistence
    var undoStackData: Data? // Encoded undo commands
    var redoStackData: Data? // Encoded redo commands
    var undoStackMaxSize: Int = 100
    
    // Encoding/decoding helpers
    func saveUndoState(_ undoManager: TextFileUndoManager)
    func restoreUndoState() -> TextFileUndoManager?
}
```

### 5. Diff Algorithm

Efficient storage using Myers' diff algorithm or similar:
```swift
struct TextDiff {
    let changes: [Change]
    
    enum Change {
        case insert(position: Int, text: String)
        case delete(range: Range<Int>)
    }
    
    static func diff(from old: String, to new: String) -> TextDiff
    static func apply(_ diff: TextDiff, to text: String) -> String
}
```

---

## User Interface

### 1. Toolbar Additions (FileEditView)

```
┌─────────────────────────────────────────────┐
│  < Back    [File Name]    Undo Redo  Save   │
│─────────────────────────────────────────────│
│                                             │
│  [Text Editor Content]                      │
│                                             │
│                                             │
└─────────────────────────────────────────────┘
```

**Toolbar Items:**
- **Undo button**: Curved arrow left icon, disabled when canUndo = false
- **Redo button**: Curved arrow right icon, disabled when canRedo = false
- **Tooltip**: Show last action description on hover (macOS)

### 2. Keyboard Shortcuts

**macOS:**
- `Cmd+Z`: Undo
- `Cmd+Shift+Z`: Redo
- `Cmd+Y`: Alternative redo (optional)

**iOS:**
- Shake to undo (system default)
- `Cmd+Z`: Undo (with keyboard)
- `Cmd+Shift+Z`: Redo (with keyboard)

### 3. Menu Items (macOS)

**Edit Menu:**
```
Edit
├── Undo [Action Description]    ⌘Z
├── Redo [Action Description]    ⇧⌘Z
├── ──────────────────────────
├── Cut                          ⌘X
├── Copy                         ⌘C
├── Paste                        ⌘V
└── ...
```

---

## Implementation Plan

### Phase 1: Core Command System
1. Create `UndoableCommand` protocol
2. Implement basic command types (TextInsert, TextDelete, TextReplace)
3. Create `TextFileUndoManager` class
4. Add unit tests for command execution and reversal

### Phase 2: Text Editor Integration
1. Create `UndoableTextEditor` wrapper
2. Implement text change detection
3. Add diff algorithm for efficient storage
4. Integrate with existing FileEditView
5. Add keyboard shortcut handlers

### Phase 3: UI Components
1. Add undo/redo toolbar buttons
2. Implement button enable/disable logic
3. Add tooltips with action descriptions
4. Style buttons to match app design

### Phase 4: Formatting Commands
1. Create format-related command types
2. Implement formatting change detection
3. Add undo/redo for bold, italic, font changes
4. Test with AttributedString modifications

### Phase 5: Persistence
1. Extend File model with undo stack storage
2. Implement command encoding/decoding
3. Add save/restore logic
4. Test persistence across app restarts

### Phase 6: Advanced Features
1. Implement typing coalescing
2. Add composite commands
3. Implement stack size limits
4. Add clear history command
5. Performance optimization

---

## Data Model Changes

### File Model Extension

```swift
@Model
final class File {
    // Existing properties...
    var id: UUID = UUID()
    var name: String?
    var content: String?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var userOrder: Int?
    var currentVersionIndex: Int = 0
    var parentFolder: Folder?
    @Relationship(deleteRule: .cascade, inverse: \Version.file) var versions: [Version]?
    
    // NEW: Undo/Redo properties
    var undoStackData: Data?
    var redoStackData: Data?
    var undoStackMaxSize: Int = 100
    var lastUndoSaveDate: Date?
    
    // NEW: Undo management methods
    func saveUndoState(_ undoManager: TextFileUndoManager) {
        // Encode and save undo/redo stacks
    }
    
    func restoreUndoState() -> TextFileUndoManager? {
        // Decode and return undo manager with saved state
    }
    
    func clearUndoHistory() {
        undoStackData = nil
        redoStackData = nil
        lastUndoSaveDate = nil
    }
}
```

### Command Storage

Commands will be encoded as JSON for persistence:
```swift
struct SerializedCommand: Codable {
    let type: String // "insert", "delete", "replace", "format"
    let timestamp: Date
    let description: String
    let data: [String: String] // Command-specific data
}
```

---

## Testing Strategy

### Unit Tests
- Command execution and reversal
- Undo/redo stack management
- Text diff algorithm accuracy
- Command encoding/decoding
- Typing coalescing logic

### Integration Tests
- Text editor undo/redo workflow
- Formatting undo/redo workflow
- Persistence across app restarts
- Keyboard shortcut handling
- Multiple undo/redo cycles

### UI Tests
- Button enable/disable states
- Toolbar button interactions
- Keyboard shortcut execution
- Multi-step undo/redo scenarios

### Performance Tests
- Large text file handling
- Memory usage with deep undo stacks
- Diff algorithm performance
- Persistence save/load time

---

## Edge Cases & Error Handling

### Edge Cases
1. **Empty file**: Undo/redo with no content
2. **Large files**: Performance with files > 10MB
3. **Rapid typing**: Coalescing behavior
4. **Format conflicts**: Overlapping format ranges
5. **Stack overflow**: Reaching max stack size
6. **Corrupted data**: Invalid persisted undo stack

### Error Handling
- Graceful degradation if undo data corrupted
- Clear stack if memory pressure detected
- Validate commands before execution
- Log errors without crashing editor

---

## Performance Considerations

### Memory Management
- Use diffs instead of full snapshots
- Limit stack size (default 100 actions)
- Clear old undo data when stack overflows
- Compress persisted data

### Optimization Strategies
- Lazy encoding of undo data (only on save)
- Background encoding for large stacks
- Incremental diff updates
- String interning for repeated content

---

## Accessibility

- VoiceOver announcements for undo/redo actions
- High contrast support for toolbar buttons
- Keyboard navigation for all undo/redo features
- Accessible action descriptions

---

## Localization

### String Keys
```swift
// Undo/Redo Actions
"undo.action.typing" = "Typing"
"undo.action.deletion" = "Deletion"
"undo.action.formatting" = "Formatting"
"undo.button.undo" = "Undo"
"undo.button.redo" = "Redo"
"undo.menu.undo" = "Undo %@"
"undo.menu.redo" = "Redo %@"
"undo.alert.cleared" = "Undo history cleared"
```

---

## Migration Strategy

### Existing Files
- No migration needed (undo data is optional)
- First edit creates undo manager
- Undo history starts from that point

### Backward Compatibility
- App works without undo data
- Gracefully handles missing undo properties
- No breaking changes to existing File model

---

## Success Criteria

### Must Have
- ✅ Undo/redo works for text insertion and deletion
- ✅ Undo/redo works for formatting changes
- ✅ Keyboard shortcuts functional (Cmd+Z, Cmd+Shift+Z)
- ✅ Toolbar buttons show correct enable/disable state
- ✅ Undo history persists across app restarts
- ✅ No memory leaks with deep undo stacks

### Should Have
- ✅ Typing coalescing works smoothly
- ✅ Action descriptions visible in menu/tooltips
- ✅ Performance acceptable for large files (< 100ms per operation)
- ✅ Clear undo history command available

### Nice to Have
- Undo/redo animations
- Visual timeline of changes
- Redo branching support

---

## Future Enhancements (Beyond Phase 004)

1. **Visual timeline**: Show history as graphical timeline
2. **Named snapshots**: User-created savepoints in undo history
3. **Selective undo**: Undo specific change without affecting later changes
4. **Collaborative undo**: Multi-user undo/redo with conflict resolution
5. **Undo across files**: Undo changes that span multiple files
6. **AI-assisted undo**: Smart suggestions for what to undo

---

## Dependencies

### Internal
- Phase 003: Text file creation and editing
- File model with AttributedString support
- FileEditView for text editing

### External
- SwiftUI UndoManager (for keyboard integration)
- Foundation (Codable for persistence)
- Combine (for undo manager state publishing)

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Memory issues with large undo stacks | High | Implement stack size limits, use diffs |
| Persistence data corruption | Medium | Add validation, graceful fallback |
| Performance degradation | Medium | Profile early, optimize diff algorithm |
| Complexity with formatting | High | Start with text-only, add formatting later |
| iOS/macOS behavioral differences | Low | Abstract platform-specific code |

---

## Timeline Estimate

- **Phase 1** (Core Command System): 3-4 days
- **Phase 2** (Text Editor Integration): 4-5 days
- **Phase 3** (UI Components): 2-3 days
- **Phase 4** (Formatting Commands): 3-4 days
- **Phase 5** (Persistence): 3-4 days
- **Phase 6** (Advanced Features): 4-5 days

**Total Estimate**: 19-25 days

---

## References

- [Apple UndoManager Documentation](https://developer.apple.com/documentation/foundation/undomanager)
- [Command Pattern](https://refactoring.guru/design-patterns/command)
- [Myers' Diff Algorithm](https://blog.jcoglan.com/2017/02/12/the-myers-diff-algorithm-part-1/)
- [TextKit 2 Undo Support](https://developer.apple.com/documentation/uikit/textkit)

---

**Document Version**: 1.0  
**Last Updated**: 26 October 2025  
**Author**: Writing Shed Pro Development Team
