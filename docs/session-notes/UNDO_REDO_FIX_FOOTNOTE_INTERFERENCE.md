# Undo/Redo Fix: Footnote Operations Clearing Redo Stack

**Date:** 27 November 2025  
**Issue:** Redo stopped working after footnote deletion/restoration implementation
**Root Cause:** Footnote delete/restore operations were inadvertently creating new undo commands

---

## Problem

After implementing footnote deletion and restoration in the previous session, redo functionality broke:

1. User pastes text
2. User presses Undo (text disappears) ✅
3. User presses Redo (nothing happens) ❌

### Root Cause

When a footnote was deleted or restored, the code called `saveChanges()` which:
1. Updated `attributedContent`
2. Triggered `handleAttributedTextChange()`
3. Created a new undo command via `undoManager.execute(command)`
4. **Cleared the redo stack** (by design in `TextFileUndoManager.execute()`)

This is correct behavior for normal user edits, but **footnote delete/restore are programmatic operations** that shouldn't interfere with the undo/redo stack since they have their own database-level undo handling.

---

## Solution

Modified `removeFootnoteFromText()` and `restoreFootnoteToText()` to:
1. Set `isPerformingUndoRedo = true` flag **before** modifying text
2. Update the model directly without going through `saveChanges()`
3. Reset the flag after a brief delay

This prevents these operations from creating new undo commands while still properly saving the changes.

---

## Code Changes

### 1. Fixed `removeFootnoteFromText()`

**Before:**
```swift
private func removeFootnoteFromText(_ footnote: FootnoteModel) {
    guard let textView = textViewCoordinator.textView else { return }
    
    if let removedRange = FootnoteInsertionHelper.removeFootnoteFromTextView(textView, footnoteID: footnote.id) {
        attributedContent = textView.attributedText ?? NSAttributedString()
        saveChanges()  // ❌ This clears redo stack!
    }
}
```

**After:**
```swift
private func removeFootnoteFromText(_ footnote: FootnoteModel) {
    guard let textView = textViewCoordinator.textView else { return }
    
    // Set flag to prevent this from creating a new undo command
    isPerformingUndoRedo = true
    
    if let removedRange = FootnoteInsertionHelper.removeFootnoteFromTextView(textView, footnoteID: footnote.id) {
        // Update the attributed content binding
        attributedContent = textView.attributedText ?? NSAttributedString()
        
        // Update the model directly
        file.currentVersion?.attributedContent = attributedContent
        previousContent = attributedContent.string
        file.modifiedDate = Date()
        
        // Save context
        do {
            try modelContext.save()
        } catch {
            print("❌ Error saving context: \(error)")
        }
    }
    
    // Reset flag
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.isPerformingUndoRedo = false
    }
}
```

### 2. Fixed `restoreFootnoteToText()`

**Before:**
```swift
private func restoreFootnoteToText(_ footnote: FootnoteModel) {
    // ... insert attachment code ...
    
    attributedContent = textView.attributedText ?? NSAttributedString()
    // No saveChanges() call at all!
}
```

**After:**
```swift
private func restoreFootnoteToText(_ footnote: FootnoteModel) {
    guard let textView = textViewCoordinator.textView else { return }
    guard let currentVersion = file.currentVersion else { return }
    
    // Set flag to prevent this from creating a new undo command
    isPerformingUndoRedo = true
    
    // ... insert attachment code ...
    
    // Update the attributed content binding
    attributedContent = textView.attributedText ?? NSAttributedString()
    
    // Update the model directly
    file.currentVersion?.attributedContent = attributedContent
    previousContent = attributedContent.string
    file.modifiedDate = Date()
    
    // Save context
    do {
        try modelContext.save()
    } catch {
        print("❌ Error saving context: \(error)")
    }
    
    // Reset flag
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.isPerformingUndoRedo = false
    }
}
```

### 3. Fixed Callbacks

**Before:**
```swift
onUpdate: {
    saveChanges()  // ❌ Creates undo command
}
onRestore: {
    restoreFootnoteToText(footnote)
    saveChanges()  // ❌ Creates undo command
}
```

**After:**
```swift
onUpdate: {
    // Footnote text was updated - no need to save, already saved in FootnoteManager
    forceRefresh.toggle()
}
onRestore: {
    // Footnote was restored from trash, re-insert it
    restoreFootnoteToText(footnote)
    // No saveChanges() - handled internally
}
```

---

## How It Works Now

### Normal User Edit (Paste)
1. User pastes text
2. `handleAttributedTextChange()` detects change
3. `isPerformingUndoRedo` is `false`, so continues
4. Creates undo command
5. **Clears redo stack** (correct behavior)

### Programmatic Footnote Delete
1. User clicks "Delete" in FootnoteDetailView
2. `removeFootnoteFromText()` called
3. Sets `isPerformingUndoRedo = true`
4. Removes attachment from text
5. Updates model directly
6. Saves to context
7. `handleAttributedTextChange()` triggered by `attributedContent` update
8. **Skips creating undo command** because `isPerformingUndoRedo = true`
9. Redo stack preserved ✅

### Undo/Redo Cycle
1. User pastes text → undo command created, redo stack cleared
2. User presses Undo → text removed, command moved to redo stack
3. User presses Redo → text restored, command moved back to undo stack ✅
4. Redo stack still has the command because no interfering saves occurred

---

## Testing Checklist

- [x] Paste text, undo, redo → text reappears
- [x] Type text, undo, redo → text reappears
- [x] Delete footnote → marker removed, redo still works
- [x] Restore footnote → marker restored, redo still works
- [x] Multiple undo/redo cycles work correctly
- [x] Footnote operations don't appear in undo stack

---

## Key Principle

**Rule:** Programmatic text modifications (like footnote operations, auto-corrections, etc.) should:
1. Set `isPerformingUndoRedo = true` **before** modifying text
2. Update the model directly without calling `saveChanges()`
3. Save to context manually
4. Reset the flag after completion

This prevents them from interfering with user-initiated undo/redo operations.

---

## Files Modified

1. **FileEditView.swift**
   - Updated `removeFootnoteFromText()` to use `isPerformingUndoRedo` flag
   - Updated `restoreFootnoteToText()` to use `isPerformingUndoRedo` flag
   - Fixed callbacks to not call `saveChanges()`

---

## Status

✅ **Fixed** - Redo now works correctly even after footnote operations
✅ **Tested** - All undo/redo scenarios work as expected
✅ **Compiled** - No errors

---

## Summary

The footnote deletion/restoration implementation was inadvertently creating new undo commands by calling `saveChanges()`, which cleared the redo stack. The fix uses the existing `isPerformingUndoRedo` flag to prevent these programmatic operations from interfering with the undo/redo system. This pattern should be used for all programmatic text modifications going forward.
