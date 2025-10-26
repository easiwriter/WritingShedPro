# Implementation Plan: Undo/Redo System

**Phase**: 004  
**Status**: Planning 📋

---

## Overview

This document provides a step-by-step implementation plan for adding comprehensive undo/redo functionality to text files in Writing Shed Pro.

---

## Phases

### Phase 1: Core Command System (3-4 days)

**Goal**: Build the foundational command pattern infrastructure

#### Tasks
1. **Create command protocol**
   - [ ] Define `UndoableCommand` protocol
   - [ ] Add timestamp and description properties
   - [ ] Define execute() and undo() methods

2. **Implement basic commands**
   - [ ] Create `TextInsertCommand` class
   - [ ] Create `TextDeleteCommand` class
   - [ ] Create `TextReplaceCommand` class
   - [ ] Add Codable conformance for persistence

3. **Create UndoManager**
   - [ ] Create `TextFileUndoManager` class
   - [ ] Implement undo stack management
   - [ ] Implement redo stack management
   - [ ] Add canUndo and canRedo published properties
   - [ ] Implement execute, undo, redo, and clear methods

4. **Unit tests**
   - [ ] Test command execution and reversal
   - [ ] Test undo/redo stack operations
   - [ ] Test stack clearing
   - [ ] Test edge cases (empty stacks, etc.)

**Deliverables**: Working command system with unit tests

---

### Phase 2: Text Editor Integration (4-5 days)

**Goal**: Connect undo system to text editing

#### Tasks
1. **Text diff implementation**
   - [ ] Research and choose diff algorithm (Myers or similar)
   - [ ] Implement TextDiff struct with Change enum
   - [ ] Add diff(from:to:) static method
   - [ ] Add apply(_:to:) method
   - [ ] Unit test diff accuracy

2. **Change detection**
   - [ ] Create `UndoableTextEditor` view wrapper
   - [ ] Implement onChange handler
   - [ ] Detect change type (insert, delete, replace)
   - [ ] Create appropriate commands
   - [ ] Handle AttributedString changes

3. **Typing coalescing**
   - [ ] Add typing buffer to UndoManager
   - [ ] Implement timer-based grouping
   - [ ] Create CompositeCommand for grouped changes
   - [ ] Test coalescing behavior

4. **Keyboard shortcuts**
   - [ ] Add Cmd+Z handler (undo)
   - [ ] Add Cmd+Shift+Z handler (redo)
   - [ ] Test on macOS and iOS with keyboard
   - [ ] Handle platform differences

**Deliverables**: Functional undo/redo in text editor with keyboard support

---

### Phase 3: UI Components (2-3 days)

**Goal**: Add visual controls and feedback

#### Tasks
1. **Toolbar buttons**
   - [ ] Add undo button to FileEditView toolbar
   - [ ] Add redo button to FileEditView toolbar
   - [ ] Use SF Symbols (arrow.uturn.backward, arrow.uturn.forward)
   - [ ] Bind button enabled state to canUndo/canRedo

2. **Visual feedback**
   - [ ] Add tooltips with action descriptions (macOS)
   - [ ] Add button styling and animations
   - [ ] Test accessibility labels
   - [ ] Add VoiceOver announcements

3. **Menu items (macOS)**
   - [ ] Add Undo menu item to Edit menu
   - [ ] Add Redo menu item to Edit menu
   - [ ] Show action description in menu text
   - [ ] Connect menu items to undo manager

**Deliverables**: Complete UI with toolbar buttons and menu items

---

### Phase 4: Formatting Commands (3-4 days)

**Goal**: Support undo/redo for text formatting

#### Tasks
1. **Formatting command types**
   - [ ] Create `FormatApplyCommand` class
   - [ ] Create `FormatRemoveCommand` class
   - [ ] Support AttributedString attribute changes
   - [ ] Handle multiple formatting attributes

2. **Format change detection**
   - [ ] Detect bold/italic/underline changes
   - [ ] Detect font changes
   - [ ] Detect color changes
   - [ ] Create appropriate format commands

3. **AttributedString handling**
   - [ ] Store attribute runs efficiently
   - [ ] Handle overlapping format ranges
   - [ ] Test format undo/redo accuracy
   - [ ] Handle format conflicts

4. **Integration tests**
   - [ ] Test text + formatting changes
   - [ ] Test multiple format changes
   - [ ] Test format removal
   - [ ] Test complex scenarios

**Deliverables**: Full formatting undo/redo support

---

### Phase 5: Persistence (3-4 days)

**Goal**: Save and restore undo history

#### Tasks
1. **Data model updates**
   - [ ] Add undoStackData to File model
   - [ ] Add redoStackData to File model
   - [ ] Add undoStackMaxSize property
   - [ ] Add lastUndoSaveDate property
   - [ ] Update SwiftData schema

2. **Command serialization**
   - [ ] Create SerializedCommand struct
   - [ ] Implement encoding for all command types
   - [ ] Implement decoding for all command types
   - [ ] Add error handling for corrupted data

3. **Save/restore logic**
   - [ ] Implement saveUndoState() in File
   - [ ] Implement restoreUndoState() in File
   - [ ] Add clearUndoHistory() method
   - [ ] Trigger save on app background/quit

4. **Migration**
   - [ ] Test with existing files (no undo data)
   - [ ] Add backward compatibility checks
   - [ ] Handle corrupted undo data gracefully
   - [ ] Test data integrity

**Deliverables**: Persistent undo/redo across app restarts

---

### Phase 6: Advanced Features (4-5 days)

**Goal**: Polish and optimize

#### Tasks
1. **Stack management**
   - [ ] Implement max stack size limits
   - [ ] Add stack overflow handling
   - [ ] Trim oldest commands when limit reached
   - [ ] Add clear history command

2. **Performance optimization**
   - [ ] Profile memory usage
   - [ ] Optimize diff algorithm
   - [ ] Add string interning for repeated content
   - [ ] Implement lazy encoding
   - [ ] Test with large files (>10MB)

3. **Memory management**
   - [ ] Add memory pressure monitoring
   - [ ] Auto-clear on low memory
   - [ ] Compress persisted data
   - [ ] Test memory limits

4. **Polish**
   - [ ] Add animations for undo/redo
   - [ ] Improve action descriptions
   - [ ] Add settings for stack size
   - [ ] Update documentation

**Deliverables**: Production-ready undo/redo system

---

## Testing Strategy

### Unit Tests
- Command execution and reversal
- Stack management operations
- Diff algorithm accuracy
- Serialization/deserialization
- Typing coalescing

### Integration Tests
- End-to-end undo/redo workflows
- Persistence across restarts
- Keyboard shortcut handling
- UI button interactions
- Formatting changes

### UI Tests
- Button states
- Toolbar interactions
- Menu item functionality
- Multi-step scenarios

### Performance Tests
- Large file handling
- Deep undo stacks
- Memory usage
- Persistence timing

---

## Success Metrics

### Functional
- ✅ All commands reversible
- ✅ Keyboard shortcuts work
- ✅ Toolbar buttons functional
- ✅ History persists correctly

### Performance
- ✅ < 100ms per undo/redo operation
- ✅ < 5MB memory for 100-command stack
- ✅ < 500ms to save/restore large stacks

### Quality
- ✅ No memory leaks
- ✅ 90%+ test coverage
- ✅ Graceful error handling
- ✅ Accessibility compliant

---

## Risk Management

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Memory issues | Medium | High | Implement limits, profile early |
| Persistence bugs | Medium | Medium | Thorough testing, validation |
| Performance problems | Low | Medium | Profile and optimize |
| Complexity creep | Medium | Low | Start simple, iterate |

---

## Dependencies

- Phase 003 completion (text editing)
- FileEditView for UI integration
- File model for persistence
- AttributedString support

---

## Timeline

| Phase | Duration | Start | End |
|-------|----------|-------|-----|
| Phase 1 | 3-4 days | Day 1 | Day 4 |
| Phase 2 | 4-5 days | Day 5 | Day 9 |
| Phase 3 | 2-3 days | Day 10 | Day 12 |
| Phase 4 | 3-4 days | Day 13 | Day 16 |
| Phase 5 | 3-4 days | Day 17 | Day 20 |
| Phase 6 | 4-5 days | Day 21 | Day 25 |

**Total**: 19-25 days

---

## Notes

- Start with text-only undo/redo, add formatting later
- Use diffs from the beginning for efficiency
- Test memory usage early and often
- Keep UI simple and standard (follow platform conventions)
- Document command format for future extensibility

---

**Last Updated**: 26 October 2025
