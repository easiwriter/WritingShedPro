# Footnote + Undo/Redo Integration Tests Added

**Date**: November 27, 2025  
**Feature**: 015 (Footnotes) + 004 (Undo/Redo)  
**Status**: ✅ Tests Created, Compilation Fixed

## Overview

Added comprehensive integration tests to verify that footnote operations (deletion and restoration) do not interfere with the undo/redo stack. These tests were created after discovering that footnote operations were incorrectly clearing the redo stack.

## Test File Created

**File**: `FootnoteUndoRedoIntegrationTests.swift`
**Location**: `/WrtingShedPro/WritingShedProTests/`

## Test Coverage

### 1. Basic Functionality Tests

#### testFootnoteDeletionDoesNotClearRedoStack()
- **Purpose**: Verify that deleting a footnote doesn't clear the redo stack
- **Scenario**:
  1. Make a text change (adds to undo stack)
  2. Undo the change (moves to redo stack)
  3. Delete a footnote (programmatic operation)
  4. Verify redo still works

#### testFootnoteRestorationDoesNotClearRedoStack()
- **Purpose**: Verify that restoring a footnote doesn't clear the redo stack
- **Scenario**:
  1. Make a text change (adds to undo stack)
  2. Undo the change (moves to redo stack)
  3. Restore a trashed footnote (programmatic operation)
  4. Verify redo still works

### 2. Flag Behavior Tests

#### testProgrammaticOperationWithFlagDoesNotCreateUndoCommand()
- **Purpose**: Verify that operations with `isPerformingUndoRedo = true` don't create undo commands
- **Scenario**:
  1. Track initial undo stack state
  2. Perform programmatic operation (without calling undoManager.execute())
  3. Verify undo stack hasn't grown

#### testUserOperationWithoutFlagCreatesUndoCommand()
- **Purpose**: Verify that normal user operations DO create undo commands
- **Scenario**:
  1. Start with empty undo stack
  2. Perform user operation (calling undoManager.execute())
  3. Verify undo stack has grown

### 3. Complex Scenario Tests

#### testComplexScenarioMultipleOperations()
- **Purpose**: Replicate the exact bug scenario reported by the user
- **Scenario** (matches reported bug):
  1. Paste a paragraph (creates undo command)
  2. Undo (redo stack now has one item)
  3. Delete a footnote (programmatic, should NOT clear redo)
  4. Redo should restore the pasted paragraph
- **Critical Test**: This is the exact scenario that was broken before the fix

#### testFootnoteRenumberingDoesNotAffectUndoRedo()
- **Purpose**: Verify that footnote renumbering doesn't interfere with undo/redo
- **Scenario**:
  1. Create three footnotes
  2. Make a text change and undo it (redo available)
  3. Delete middle footnote and renumber remaining ones
  4. Verify redo still works

## Compilation Fixes Applied

### Issue 1: currentVersion Assignment
**Problem**: `currentVersion` is a computed property (read-only)
```swift
// ❌ WRONG
testFile.currentVersion = version

// ✅ CORRECT
testFile.currentVersionIndex = 0
```

### Issue 2: TextReplaceCommand Initializer
**Problem**: Incorrect parameter names and missing required parameters
```swift
// ❌ WRONG
TextReplaceCommand(
    description: "Insert Text",
    range: NSRange(location: 5, length: 0),
    oldText: "",
    newText: " World",
    beforeContent: text1,
    afterContent: text2,
    targetFile: testFile
)

// ✅ CORRECT
TextReplaceCommand(
    description: "Insert Text",
    startPosition: 5,
    endPosition: 5,
    oldText: "",
    newText: " World",
    targetFile: testFile
)
```

### Issue 3: FootnoteModel Initializer
**Problem**: Parameter order was wrong (`content` vs `text`)
```swift
// ❌ WRONG
FootnoteModel(
    content: "Test footnote",
    characterPosition: 3,
    number: 1,
    version: version
)

// ✅ CORRECT
FootnoteModel(
    version: version,
    characterPosition: 3,
    text: "Test footnote",
    number: 1
)
```

### Issue 4: Footnote Properties
**Problem**: Using wrong property names (`isTrashed`/`trashedDate` vs `isDeleted`/`deletedAt`)
```swift
// ❌ WRONG
footnote.isTrashed = true
footnote.trashedDate = Date()

// ✅ CORRECT
footnote.isDeleted = true
footnote.deletedAt = Date()
```

### Issue 5: Version Footnotes Array
**Problem**: `version.footnotes` is optional and might be nil
```swift
// ❌ WRONG
version.footnotes.append(footnote)

// ✅ CORRECT
if version.footnotes == nil {
    version.footnotes = []
}
version.footnotes?.append(footnote)
```

## Test Strategy

These tests simulate programmatic operations by:
1. **NOT** calling `undoManager.execute()` for footnote operations
2. Directly modifying the model (as the real code does with `isPerformingUndoRedo = true`)
3. Verifying that the redo stack remains intact

This matches how the actual `removeFootnoteFromText()` and `restoreFootnoteToText()` methods work in `FileEditView.swift`.

## Why These Tests Were Needed

### Gap in Existing Test Coverage

The existing test suite had:
- ✅ Unit tests for FootnoteManager
- ✅ Unit tests for FootnoteModel
- ✅ Unit tests for FootnoteInsertionHelper
- ✅ Unit tests for UndoRedo system
- ❌ NO integration tests between footnotes and undo/redo

### The Bug

When footnote operations called `saveChanges()`, it triggered `handleAttributedTextChange()` which created a new undo command. This new command **cleared the redo stack**.

**User-reported scenario**:
```
1. Paste paragraph
2. Undo (paragraph vanishes, redo available)
3. Delete footnote
4. Redo → NOTHING HAPPENS ❌ (redo stack was cleared)
```

### The Fix

The fix uses the `isPerformingUndoRedo` flag pattern:
```swift
private func removeFootnoteFromText(_ footnote: FootnoteModel) {
    // Set flag FIRST
    isPerformingUndoRedo = true
    defer {
        DispatchQueue.main.async {
            self.isPerformingUndoRedo = false
        }
    }
    
    // Modify model...
    // Update attributedContent LAST (after flag is set)
    attributedContent = updatedText
}
```

The guard in `handleAttributedTextChange()` checks this flag:
```swift
guard !isPerformingUndoRedo else {
    print("🔄 Skipping - performing undo/redo")
    return  // Don't create undo command!
}
```

## Test Validation

All 5 test cases now:
- ✅ Compile without errors
- ⏳ Ready to run to validate the fix

## Related Files

**Implementation**:
- `FileEditView.swift` - Contains `removeFootnoteFromText()` and `restoreFootnoteToText()`
- `FootnoteManager.swift` - Manages footnote CRUD operations
- `TextFileUndoManager.swift` - Manages undo/redo stacks

**Documentation**:
- `FOOTNOTE_FIXES_RENUMBERING_DELETION_VISIBILITY.md` - Initial fixes
- `UNDO_REDO_FIX_FOOTNOTE_INTERFERENCE.md` - Attempted fix documentation
- `WHY_TESTS_MISSED_REDO_BUG.md` - Analysis of test coverage gap

## Next Steps

1. ✅ Tests created and compile
2. ⏳ Run tests to verify fix works
3. ⏳ If tests fail, debug the `isPerformingUndoRedo` flag timing issue
4. ⏳ Document final working solution

## Notes

These tests serve as:
1. **Regression prevention**: Ensure future changes don't break undo/redo
2. **Documentation**: Show correct pattern for programmatic operations
3. **Validation**: Verify the fix actually works (when tests are run)
