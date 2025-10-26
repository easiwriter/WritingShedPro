# Requirements Checklist: Undo/Redo System

**Phase**: 004  
**Status**: Planning 📋

---

## Functional Requirements

### Core Undo/Redo
- [ ] User can undo text insertion
- [ ] User can undo text deletion
- [ ] User can undo text replacement
- [ ] User can redo undone text insertion
- [ ] User can redo undone text deletion
- [ ] User can redo undone text replacement
- [ ] Undo/redo works for AttributedString content
- [ ] Multiple undo/redo cycles work correctly

### Formatting Undo/Redo
- [ ] User can undo bold formatting application
- [ ] User can undo italic formatting application
- [ ] User can undo underline formatting application
- [ ] User can undo font changes
- [ ] User can undo color changes
- [ ] User can redo formatting changes
- [ ] Overlapping format ranges handled correctly

### Keyboard Shortcuts
- [ ] Cmd+Z performs undo (macOS)
- [ ] Cmd+Shift+Z performs redo (macOS)
- [ ] Cmd+Y performs redo (macOS, optional)
- [ ] Cmd+Z works with external keyboard (iOS)
- [ ] Shake to undo works (iOS)
- [ ] Shortcuts work while typing
- [ ] Shortcuts work in menus

### UI Components
- [ ] Undo button visible in toolbar
- [ ] Redo button visible in toolbar
- [ ] Undo button disabled when canUndo = false
- [ ] Redo button disabled when canRedo = false
- [ ] Undo button shows correct icon
- [ ] Redo button shows correct icon
- [ ] Buttons have accessibility labels
- [ ] Tooltips show action descriptions (macOS)

### Menu Integration (macOS)
- [ ] Edit menu has Undo item
- [ ] Edit menu has Redo item
- [ ] Menu items show action names
- [ ] Menu items show keyboard shortcuts
- [ ] Menu items are enabled/disabled correctly
- [ ] Menu items work when clicked

### Stack Management
- [ ] Undo stack stores commands correctly
- [ ] Redo stack stores commands correctly
- [ ] New action clears redo stack
- [ ] Stack respects maximum size limit
- [ ] Oldest commands removed when limit reached
- [ ] Clear history command works
- [ ] Stack size configurable per file

### Typing Coalescing
- [ ] Rapid typing grouped into single undo action
- [ ] Grouping timeout configurable (default 0.5s)
- [ ] Timer resets on each keystroke
- [ ] Buffer flushed on timeout
- [ ] Buffer flushed before other commands
- [ ] Coalescing works for continuous typing only
- [ ] Deletions not coalesced with insertions

### Persistence
- [ ] Undo stack saved to File model
- [ ] Redo stack saved to File model
- [ ] Stacks restored on file open
- [ ] Commands serialized correctly
- [ ] Commands deserialized correctly
- [ ] Corrupted data handled gracefully
- [ ] Save triggered on app background
- [ ] Save triggered on app quit

---

## Technical Requirements

### Command Pattern
- [ ] UndoableCommand protocol defined
- [ ] All commands conform to protocol
- [ ] Commands are Codable
- [ ] Commands have unique IDs
- [ ] Commands have timestamps
- [ ] Commands have descriptions
- [ ] execute() method implemented
- [ ] undo() method implemented

### Text Diff
- [ ] Diff algorithm implemented
- [ ] Diff detects insertions correctly
- [ ] Diff detects deletions correctly
- [ ] Diff detects replacements correctly
- [ ] Diff uses minimal changes
- [ ] Diff performance acceptable (<100ms)
- [ ] Diff handles large texts (>10MB)
- [ ] Diff handles Unicode correctly

### Memory Management
- [ ] Commands use weak references to File
- [ ] No memory leaks detected
- [ ] Stack memory usage acceptable (<5MB per 100 commands)
- [ ] Memory pressure handled
- [ ] Auto-clear on low memory
- [ ] Compressed persistence data

### Performance
- [ ] Undo operation < 100ms
- [ ] Redo operation < 100ms
- [ ] Command execution < 50ms
- [ ] Save undo state < 500ms
- [ ] Restore undo state < 500ms
- [ ] No UI lag during typing
- [ ] No UI lag during undo/redo

### Error Handling
- [ ] Nil checks for weak references
- [ ] Validation before command execution
- [ ] Graceful degradation on errors
- [ ] Error logging implemented
- [ ] No crashes on corrupted data
- [ ] No crashes on missing data
- [ ] User feedback for critical errors

---

## Data Model Requirements

### File Model Extensions
- [ ] undoStackData property added
- [ ] redoStackData property added
- [ ] undoStackMaxSize property added
- [ ] lastUndoSaveDate property added
- [ ] saveUndoState() method implemented
- [ ] restoreUndoState() method implemented
- [ ] clearUndoHistory() method implemented

### Command Classes
- [ ] TextInsertCommand implemented
- [ ] TextDeleteCommand implemented
- [ ] TextReplaceCommand implemented
- [ ] FormatApplyCommand implemented
- [ ] FormatRemoveCommand implemented
- [ ] CompositeCommand implemented
- [ ] SerializedCommand implemented

### Undo Manager
- [ ] TextFileUndoManager class created
- [ ] canUndo published property
- [ ] canRedo published property
- [ ] undoActionName published property
- [ ] redoActionName published property
- [ ] execute() method
- [ ] undo() method
- [ ] redo() method
- [ ] clear() method
- [ ] flushTypingBuffer() method

---

## UI/UX Requirements

### Visual Feedback
- [ ] Button states reflect undo/redo availability
- [ ] Icons appropriate for platform
- [ ] Consistent styling with app theme
- [ ] Animations on undo/redo (optional)
- [ ] Loading indicators for slow operations

### Accessibility
- [ ] VoiceOver announces undo/redo actions
- [ ] Buttons have accessibility labels
- [ ] Action names spoken by VoiceOver
- [ ] High contrast mode supported
- [ ] Keyboard navigation works
- [ ] Focus management correct

### User Feedback
- [ ] Clear indication when undo/redo unavailable
- [ ] Action descriptions visible (tooltips/menu)
- [ ] No confusing UI states
- [ ] Consistent behavior across views
- [ ] Help documentation available

---

## Testing Requirements

### Unit Tests
- [ ] Command execution tests
- [ ] Command reversal tests
- [ ] Stack push/pop tests
- [ ] Diff algorithm tests
- [ ] Serialization tests
- [ ] Deserialization tests
- [ ] Memory leak tests
- [ ] Edge case tests

### Integration Tests
- [ ] End-to-end undo/redo workflow
- [ ] Keyboard shortcut tests
- [ ] UI button interaction tests
- [ ] Persistence tests
- [ ] Multi-step undo/redo tests
- [ ] Format + text undo tests

### UI Tests
- [ ] Button enable/disable tests
- [ ] Toolbar button tap tests
- [ ] Menu item click tests
- [ ] Keyboard shortcut tests
- [ ] Accessibility tests

### Performance Tests
- [ ] Large file undo/redo
- [ ] Deep stack performance
- [ ] Memory usage tests
- [ ] Save/restore timing tests
- [ ] 1000+ command stack tests

---

## Documentation Requirements

- [ ] Code comments for all public APIs
- [ ] Architecture documented
- [ ] Command format documented
- [ ] Usage examples provided
- [ ] API reference complete
- [ ] User guide updated
- [ ] Release notes prepared

---

## Platform-Specific Requirements

### macOS
- [ ] Menu bar integration
- [ ] Tooltip support
- [ ] Cmd key shortcuts
- [ ] Native undo menu items
- [ ] Consistent with macOS HIG

### iOS
- [ ] Shake to undo support
- [ ] Hardware keyboard support
- [ ] Touch-optimized buttons
- [ ] Consistent with iOS HIG
- [ ] iPad-specific layout

---

## Localization Requirements

- [ ] All action names localized
- [ ] All button labels localized
- [ ] All menu items localized
- [ ] All error messages localized
- [ ] All tooltips localized
- [ ] String keys defined
- [ ] Localizable.strings updated

---

## Security/Privacy Requirements

- [ ] No sensitive data in undo history
- [ ] Undo data encrypted if file encrypted
- [ ] Clear undo on logout (if applicable)
- [ ] No undo data in backups (if sensitive)

---

## Deployment Requirements

- [ ] Migration strategy defined
- [ ] Backward compatibility verified
- [ ] Forward compatibility considered
- [ ] Beta testing completed
- [ ] Performance benchmarks met
- [ ] No regressions introduced

---

## Success Criteria

### Must Have (P0)
- ✅ Basic text undo/redo works
- ✅ Keyboard shortcuts work
- ✅ Persistence works
- ✅ No memory leaks
- ✅ No crashes

### Should Have (P1)
- ✅ Formatting undo/redo works
- ✅ Typing coalescing works
- ✅ UI buttons functional
- ✅ Performance acceptable

### Nice to Have (P2)
- ✅ Menu integration (macOS)
- ✅ Advanced tooltips
- ✅ Undo animations

---

## Sign-Off

### Developer Checklist
- [ ] All P0 requirements met
- [ ] All P1 requirements met
- [ ] Code reviewed
- [ ] Tests passing
- [ ] Documentation complete

### QA Checklist
- [ ] Manual testing passed
- [ ] Automated tests passing
- [ ] Performance acceptable
- [ ] Accessibility verified
- [ ] Platform testing complete

### Product Checklist
- [ ] User experience validated
- [ ] Design approved
- [ ] Documentation reviewed
- [ ] Release notes prepared
- [ ] Deployment plan ready

---

**Last Updated**: 26 October 2025
