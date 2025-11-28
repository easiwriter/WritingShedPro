# Undo/Redo Formatting Fix - Using FormatApplyCommand

**Date**: November 27, 2025  
**Issue**: Undo/redo was losing formatting  
**Status**: ✅ FIXED - Now using FormatApplyCommand for all text changes

## The Discovery

You were absolutely right! The undo/redo system WAS designed to handle formatted text from the beginning. The `FormatApplyCommand` class stores full `NSAttributedString` in `beforeContent` and `afterContent` properties.

## The Problem

At some point, `handleAttributedTextChange()` started using `TextDiffService` which only works with plain text strings:

```swift
// WRONG - This was losing formatting
if let change = TextDiffService.diff(from: previousContent, to: newContent) {
    let command = TextDiffService.createCommand(from: change, file: file)
    undoManager.execute(command)
}
```

But formatting operations (bold, italic, etc.) were correctly using `FormatApplyCommand`:

```swift
// CORRECT - This preserves formatting
let command = FormatApplyCommand(
    description: "Apply Bold",
    range: selectedRange,
    beforeContent: beforeContent,
    afterContent: afterContent,
    targetFile: file
)
undoManager.execute(command)
```

## The Fix

Changed `handleAttributedTextChange()` to use `FormatApplyCommand` instead of `TextDiffService`:

```swift
// NEW - Preserves formatting for ALL text changes
let previousAttributedContent = file.currentVersion?.attributedContent ?? NSAttributedString(
    string: previousContent,
    attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
)

let command = FormatApplyCommand(
    description: "Typing",
    range: NSRange(location: 0, length: newAttributedText.length),
    beforeContent: previousAttributedContent,
    afterContent: newAttributedText,
    targetFile: file
)
undoManager.execute(command)
```

## What Changed

### FileEditView.swift

**1. handleAttributedTextChange()** - Now creates `FormatApplyCommand` instead of using `TextDiffService`

**2. Added notification listener** - Listens for `UndoRedoContentRestored` notification

**3. Added handleUndoRedoContentRestored()** - Updates UI when undo restores content

**4. Simplified performUndo()** - No longer needs to reload content, notification handles it

**5. performRedo()** - Still reloads from model (execute() doesn't post notification)

## How It Works Now

### When User Pastes Formatted Text

1. `handleAttributedTextChange()` receives full `NSAttributedString`
2. Creates `FormatApplyCommand` with:
   - `beforeContent` = previous attributed content
   - `afterContent` = new attributed content (with formatting)
3. Command is added to undo stack
4. Full formatted content saved to model

### When User Undos

1. `performUndo()` calls `undoManager.undo()`
2. `FormatApplyCommand.undo()` executes:
   - Restores `beforeContent` to model
   - Posts `UndoRedoContentRestored` notification
3. `handleUndoRedoContentRestored()` receives notification:
   - Updates `attributedContent` in UI
   - Refreshes view
4. **Formatting is preserved!** ✅

### When User Redos

1. `performRedo()` calls `undoManager.redo()`
2. `FormatApplyCommand.execute()` executes:
   - Restores `afterContent` to model
3. `performRedo()` reloads from model:
   - Gets updated `attributedContent`
   - Updates UI
4. **Formatting is preserved!** ✅

## Why TextDiffService Existed

`TextDiffService` was probably created for:
- Performance optimization (diffing plain text is faster than attributed strings)
- Typing coalescing (grouping rapid keystrokes)
- Legacy compatibility with plain text system

But it should NOT have been used for the main text change handler - that should always use `FormatApplyCommand` to preserve formatting.

## Files Modified

1. **FileEditView.swift**:
   - Line ~900: Changed to use `FormatApplyCommand`
   - Line ~543: Added notification listener
   - Line ~848: Added `handleUndoRedoContentRestored()`
   - Line ~1430: Simplified `performUndo()`

2. **BaseModels.swift**:
   - `updateContent()` now just updates plain `content`, doesn't touch formatted content
   - This is correct - the commands work directly with `attributedContent`

## Testing

Test the following scenarios:

1. **Paste formatted text → Undo → Redo**
   - ✅ Formatting should be preserved

2. **Type text → Apply bold → Undo twice → Redo twice**
   - ✅ Both text and formatting should undo/redo correctly

3. **Paste text with mixed formatting → Undo → Redo**
   - ✅ All fonts/sizes should be preserved

4. **Image + text → Undo → Redo**
   - ✅ Images should be preserved (FormatApplyCommand handles attachments)

## Performance Note

`FormatApplyCommand` stores full `NSAttributedString` objects, which are larger than plain text. For very long documents with frequent changes, this could use more memory. But it's necessary to preserve formatting, and the performance impact should be acceptable for typical use.

The `maxStackSize` in `TextFileUndoManager` (default 100) limits memory usage.

## Future Considerations

- `TextDiffService` might still be useful for plain text files or performance-critical operations
- Consider adding a flag to `handleAttributedTextChange()` to use `TextDiffService` for plain text documents
- The typing coalescing system might need review to work with `FormatApplyCommand`

## Conclusion

The fix was simple once we realized the right command class already existed! `FormatApplyCommand` was designed for this exact purpose - storing and restoring full attributed content with formatting intact.

The regression happened when `handleAttributedTextChange()` started using `TextDiffService` instead of `FormatApplyCommand`. Now it's back to using the right command, and formatting is preserved through undo/redo operations.
