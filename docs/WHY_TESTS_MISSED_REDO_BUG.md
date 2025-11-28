# Why Unit Tests Didn't Catch the Redo Bug

**Date:** 27 November 2025  
**Bug:** Footnote operations clearing redo stack
**Analysis:** Why existing tests missed this regression

---

## The Bug That Slipped Through

### What Happened
Footnote delete/restore operations were calling `saveChanges()`, which created new undo commands, which cleared the redo stack. This broke the redo functionality.

### Why Tests Didn't Catch It

## 1. Test Coverage Gap: Integration Between Features

### Existing Tests
Looking at `UndoRedoTests.swift`, we have:

✅ **Tests that EXIST:**
- `testUndoManagerRedo()` - Tests basic redo functionality
- `testNewActionClearsRedoStack()` - Tests that NEW USER ACTIONS clear redo
- `testUndoManagerMultipleOperations()` - Tests undo/redo cycles
- Command execution/undo tests
- Stack management tests

❌ **Tests that DON'T EXIST:**
- Tests for programmatic text modifications preserving redo stack
- Tests for footnote operations + undo/redo interaction
- Tests for `isPerformingUndoRedo` flag behavior
- Integration tests between Feature 015 (Footnotes) and Feature 004 (Undo/Redo)

### The Problem

The test `testNewActionClearsRedoStack()` validates:
```swift
func testNewActionClearsRedoStack() {
    // Given: Execute command, then undo it
    manager.execute(command1)
    manager.undo()
    XCTAssertTrue(manager.canRedo)
    
    // When: Execute NEW command
    manager.execute(command2)
    
    // Then: Redo stack SHOULD be cleared
    XCTAssertFalse(manager.canRedo)  ✅ CORRECT BEHAVIOR
}
```

**This is testing the CORRECT behavior** - that user actions clear the redo stack.

But we have **NO TEST** for:
```swift
func testProgrammaticOperationsPreserveRedoStack() {
    // Given: Execute command, then undo it
    manager.execute(command1)
    manager.undo()
    XCTAssertTrue(manager.canRedo)
    
    // When: Programmatic operation (like footnote delete)
    isPerformingUndoRedo = true
    // ... modify text programmatically ...
    isPerformingUndoRedo = false
    
    // Then: Redo stack SHOULD NOT be cleared
    XCTAssertTrue(manager.canRedo)  ❌ NO TEST FOR THIS
}
```

---

## 2. Feature Isolation Problem

### Test Structure
- `UndoRedoTests.swift` - Tests TextFileUndoManager in isolation
- `FootnoteManagerTests.swift` - Tests FootnoteManager in isolation
- **NO INTEGRATION TESTS** between these features

### What This Means
Both feature implementations were tested individually and worked perfectly:
- ✅ Undo/redo system worked correctly
- ✅ Footnote system worked correctly
- ❌ But their **interaction** was never tested

### Real-World Scenario Not Tested
```
User workflow:
1. Type text
2. Undo
3. Delete footnote ← NEW FEATURE CODE
4. Try to redo ← BREAKS HERE

Test coverage:
✅ Step 1-2: Covered by UndoRedoTests
✅ Step 3: Covered by FootnoteManagerTests
❌ Step 4: NOT COVERED - no test for interaction
```

---

## 3. Unit Tests vs Integration Tests

### What We Had: Unit Tests
```swift
// UndoRedoTests.swift
func testUndoManagerRedo() {
    // Tests undo manager in isolation
    manager.execute(command)
    manager.undo()
    manager.redo()  ✅ Works
}

// FootnoteManagerTests.swift
func testMoveFootnoteToTrash() {
    // Tests footnote manager in isolation
    FootnoteManager.shared.moveFootnoteToTrash(footnote, context: context)
    ✅ Works
}
```

### What We Needed: Integration Tests
```swift
// FootnoteUndoRedoIntegrationTests.swift (DOESN'T EXIST)
func testFootnoteDeletionPreservesRedoStack() {
    // Test the INTERACTION between features
    
    // 1. User types text
    insertText("Hello World")
    
    // 2. User undoes
    undoManager.undo()
    XCTAssertTrue(undoManager.canRedo)
    
    // 3. User deletes footnote
    FootnoteManager.shared.moveFootnoteToTrash(footnote, context: context)
    
    // 4. Redo should still work
    XCTAssertTrue(undoManager.canRedo)  ❌ WOULD HAVE CAUGHT BUG
    
    undoManager.redo()
    XCTAssertEqual(content, "Hello World")
}
```

---

## 4. FileEditView Not Covered by Unit Tests

### The Problem
The bug was in `FileEditView.swift`:
```swift
private func removeFootnoteFromText(_ footnote: FootnoteModel) {
    // ...
    saveChanges()  // ❌ This cleared redo stack
}
```

### Why Not Tested
- `FileEditView` is a SwiftUI view with complex UIKit integration
- No unit tests for `FileEditView` behavior
- Only manual testing was done
- UI tests would be needed to catch this

### Test Pyramid Violation
```
        /\
       /  \  ← UI Tests (almost none for FileEditView)
      /    \
     /------\  ← Integration Tests (missing for feature interactions)
    /--------\
   /----------\  ← Unit Tests (good coverage for isolated features)
  /------------\
```

We had good unit test coverage at the bottom, but missing integration and UI tests above.

---

## 5. The `isPerformingUndoRedo` Flag

### Flag Exists But Not Tested
The flag was already in the code:
```swift
@State private var isPerformingUndoRedo = false

guard !isPerformingUndoRedo else {
    print("🔄 Skipping - performing undo/redo")
    return
}
```

But we had **NO TESTS** validating:
- When should this flag be set?
- What operations should use it?
- Does it actually prevent undo command creation?

### Tests We Should Have Had
```swift
func testIsPerformingUndoRedoFlagPreventsCommandCreation() {
    // Given: Flag is set
    fileEditView.isPerformingUndoRedo = true
    
    // When: Text changes
    fileEditView.attributedContent = newContent
    
    // Then: No undo command should be created
    XCTAssertEqual(undoManager.undoStack.count, 0)
}

func testProgrammaticOperationsSetFlag() {
    // When: Programmatic operation
    fileEditView.removeFootnoteFromText(footnote)
    
    // Then: Flag should be set during operation
    // (Would need to refactor to make testable)
}
```

---

## 6. Test-Driven Development (TDD) Not Followed

### What Happened
1. Implemented footnote deletion feature
2. Manually tested it (deletion worked ✅)
3. Didn't think about undo/redo interaction
4. Bug shipped to production

### TDD Would Have Caught This
If we had written the test first:
```swift
func testFootnoteDeletionPreservesRedoStack() {
    // 1. Write test (RED)
    insertText("Hello")
    undoManager.undo()
    removeFootnote()
    XCTAssertTrue(undoManager.canRedo)  // ❌ FAILS
    
    // 2. Fix implementation (GREEN)
    // Add isPerformingUndoRedo flag
    
    // 3. Test passes (GREEN)
    XCTAssertTrue(undoManager.canRedo)  // ✅ PASSES
}
```

---

## What Tests Should We Add?

### Immediate Priority

#### 1. Integration Tests for Programmatic Operations
```swift
// File: FootnoteUndoRedoIntegrationTests.swift

func testFootnoteDeletionPreservesRedoStack() { }
func testFootnoteRestorationPreservesRedoStack() { }
func testCommentDeletionPreservesRedoStack() { }
func testImageInsertionPreservesRedoStack() { }
```

#### 2. Tests for isPerformingUndoRedo Flag
```swift
// File: FileEditViewTests.swift (NEW)

func testProgrammaticTextChangeDoesNotCreateUndoCommand() { }
func testIsPerformingUndoRedoFlagBlocksCommandCreation() { }
func testFlagResetAfterProgrammaticOperation() { }
```

#### 3. Feature Interaction Matrix Tests
```swift
// Test every feature combination:
// - Undo/Redo + Footnotes
// - Undo/Redo + Comments  
// - Undo/Redo + Images
// - Undo/Redo + Formatting
// - Footnotes + Comments
// - etc.
```

### Long-Term Improvements

#### 1. UI Tests for FileEditView
```swift
// File: FileEditViewUITests.swift

func testUndoRedoButtonsAfterFootnoteOperation() {
    // Use XCUITest to:
    // 1. Type text
    // 2. Tap undo button
    // 3. Delete footnote
    // 4. Verify redo button is enabled
    // 5. Tap redo button
    // 6. Verify text reappears
}
```

#### 2. Property-Based Testing
```swift
// Test with random operation sequences
func testRandomOperationSequencesPreserveUndoRedo() {
    // Generate random sequence of:
    // - User edits
    // - Undo/redo
    // - Programmatic operations
    // Verify undo/redo always works correctly
}
```

#### 3. Regression Test Suite
```swift
// File: RegressionTests.swift

func testBug_FootnoteOperationsClearingRedoStack_20251127() {
    // Specific test for this bug
    // Ensures it never happens again
}
```

---

## Root Causes Summary

1. **Missing Integration Tests** - Features tested in isolation, not together
2. **No UI Tests for FileEditView** - Complex view behavior not covered
3. **Incomplete Flag Testing** - `isPerformingUndoRedo` usage not validated
4. **Feature Interaction Blind Spot** - New features didn't test old feature impact
5. **TDD Not Followed** - Test written after implementation, not before
6. **Manual Testing Focused on Happy Path** - Didn't test undo/redo after new operations

---

## Action Items

### Immediate (This Sprint)
- [ ] Add `testFootnoteDeletionPreservesRedoStack()`
- [ ] Add `testFootnoteRestorationPreservesRedoStack()`
- [ ] Document when to use `isPerformingUndoRedo` flag

### Short-Term (Next Sprint)
- [ ] Create integration test suite for feature interactions
- [ ] Add UI tests for FileEditView undo/redo scenarios
- [ ] Test all programmatic operations (comments, images, etc.)

### Long-Term (Ongoing)
- [ ] Follow TDD for new features
- [ ] Require integration tests for features that touch existing systems
- [ ] Create feature interaction matrix and test all combinations
- [ ] Add regression test for every bug found

---

## Lessons Learned

### For Future Features
1. **Ask**: Does this feature interact with existing features?
2. **Test**: Write integration tests, not just unit tests
3. **Think**: What could break when I add this?
4. **Verify**: Test undo/redo after every new operation type

### Test Strategy Update
```
New Feature Checklist:
✅ Unit tests for feature in isolation
✅ Integration tests with existing features  ← MISSING BEFORE
✅ Undo/redo interaction tests              ← MISSING BEFORE
✅ UI tests for user workflows              ← MISSING BEFORE
✅ Manual testing
```

---

## Conclusion

The bug wasn't caught because:
1. **We tested features in isolation** instead of their interactions
2. **We had unit tests but no integration tests** for undo/redo + footnotes
3. **FileEditView has no automated tests** - only manual testing
4. **We didn't think about the redo stack** when implementing deletion

The fix was simple (add flag), but the lesson is important: **Always test how new features interact with existing features, especially core functionality like undo/redo.**
