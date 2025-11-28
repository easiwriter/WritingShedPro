# Basic Undo/Redo Broken - Debugging Guide

**Date**: November 27, 2025
**Issue**: Paste text → Undo → Redo does nothing
**Status**: 🔴 CRITICAL - Basic functionality broken

## The Problem

Basic undo/redo is broken. Steps to reproduce:
1. Paste some text into a file
2. Undo (text disappears) ✅
3. Redo (text should reappear) ❌ **Nothing happens**

This is a regression - this functionality was working before.

## Debug Steps

### 1. Check Console Output

When you paste → undo → redo, look for these debug prints:

**On Paste:**
```
🔄 handleAttributedTextChange called
🔄 isPerformingUndoRedo: false
🔄 Previous: 'old text'
🔄 New: 'old text + pasted text'
🔄 Content changed - registering with undo manager
```

**On Undo:**
```
🔄 performUndo called - canUndo: true
🔄 After undo - new content: 'old text' (length: X)
🔄 Set selectedRange to end: {X, 0}
🔄 Reset isPerformingUndoRedo flag
```

**On Redo:**
```
🔄 performRedo called - canRedo: true
🔄 After redo - new content: 'old text + pasted text' (length: Y)
🔄 Set selectedRange to end: {Y, 0}
🔄 Reset isPerformingUndoRedo flag
```

### 2. Check What's Missing

**Critical Questions:**
- Does `performRedo called - canRedo:` show `true` or `false`?
- If `false`, the redo stack is empty (was cleared somehow)
- If `true`, but content doesn't update, the command execution failed

### 3. Check Redo Stack

The redo stack gets cleared when:
1. A new command is executed via `undoManager.execute()`
2. This happens in `handleAttributedTextChange()` when text changes

**Possible cause**: Something is calling `handleAttributedTextChange()` between undo and redo, clearing the redo stack.

## Likely Causes

### Cause 1: attributedContent Update During Undo

In `performUndo()`:
```swift
isPerformingUndoRedo = true  // Flag set

undoManager.undo()  // Executes undo, updates model

let newAttributedContent = file.currentVersion?.attributedContent
attributedContent = newAttributedContent  // ← This triggers handleAttributedTextChange()

// Reset flag LATER
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    self.isPerformingUndoRedo = false
}
```

The flag SHOULD prevent `handleAttributedTextChange()` from creating a new command. But if the timing is off, the flag might be false when the callback fires.

### Cause 2: saveChanges() Being Called

If `saveChanges()` is somehow being called after undo, and it triggers a binding update, that could call `handleAttributedTextChange()` and clear the redo stack.

### Cause 3: Async Flag Reset Timing

The flag is reset asynchronously after 0.1 seconds:
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    self.isPerformingUndoRedo = false
}
```

If something triggers `handleAttributedTextChange()` during this 0.1 second window but AFTER the synchronous binding update, the flag would still be true and it would be blocked. But if something triggers it AFTER 0.1 seconds, the flag would be false and it would create a command, clearing redo.

## Next Steps

1. **Run the app and check console output** when doing paste → undo → redo
2. **Look for** `canRedo: false` in the redo output - this means redo stack was cleared
3. **Look for** unexpected `handleAttributedTextChange called` between undo and redo
4. **Check timing** - is `isPerformingUndoRedo: false` appearing before it should?

## Temporary Workaround

If the issue is the async flag reset, try increasing the delay:
```swift
// Change from 0.1 to 0.2 or 0.5
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    self.isPerformingUndoRedo = false
}
```

But this is not a real solution - we need to understand WHY the redo stack is being cleared.

## Files to Check

- `FileEditView.swift` - `performUndo()`, `performRedo()`, `handleAttributedTextChange()`
- `TextFileUndoManager.swift` - `undo()`, `redo()`, `execute()`
- Look for any code that calls `undoManager.execute()` unexpectedly
