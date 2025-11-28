# Undo/Redo Fix Status - Manual Testing Required

**Date**: November 27, 2025  
**Issue**: Footnote deletion/restoration clears redo stack  
**Status**: ⚠️ Fix implemented but requires manual testing

## The Problem

When footnote operations modify text, they trigger `handleAttributedTextChange()` which creates undo commands and **clears the redo stack**.

**User-reported bug scenario**:
```
1. Paste paragraph → Undo stack has 1 item
2. Undo → Redo stack now has 1 item
3. Delete footnote → Triggers handleAttributedTextChange() → Creates undo command → CLEARS REDO STACK
4. Redo → Nothing happens ❌
```

## The Fix

### Implementation Pattern

Both `removeFootnoteFromText()` and `restoreFootnoteToText()` now use this pattern:

```swift
private func removeFootnoteFromText(_ footnote: FootnoteModel) {
    guard let textView = textViewCoordinator.textView else { return }
    
    // 1. Set flag FIRST
    isPerformingUndoRedo = true
    
    // 2. Modify text through text view
    FootnoteInsertionHelper.removeFootnoteFromTextView(textView, footnoteID: footnote.id)
    let updatedText = textView.attributedText ?? NSAttributedString()
    
    // 3. Update model
    file.currentVersion?.attributedContent = updatedText
    previousContent = updatedText.string
    
    // 4. Update binding LAST (while flag is still true)
    attributedContent = updatedText
    
    // 5. Reset flag AFTER a delay to ensure binding update completes
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        self.isPerformingUndoRedo = false
    }
}
```

### How It Works

1. **Flag set**: `isPerformingUndoRedo = true`
2. **Text modified**: Through text view helpers
3. **Binding updated**: `attributedContent = updatedText`
4. **Callback fires**: FormattedTextEditor calls `handleAttributedTextChange()`
5. **Guard blocks**: `guard !isPerformingUndoRedo else { return }`
6. **No undo command**: Redo stack preserved ✅
7. **Flag reset**: After delay ensures callback has completed

### Key Timing Issue

The critical insight is that SwiftUI binding updates are **synchronous**:
```
attributedContent = updatedText
  ↓ (immediately)
FormattedTextEditor.updateUIView()
  ↓ (immediately)
onTextChange callback fires
  ↓ (immediately)
handleAttributedTextChange() called
  ↓ (checks flag HERE)
guard !isPerformingUndoRedo
```

So we need:
- Set flag BEFORE updating `attributedContent`
- Reset flag AFTER with `asyncAfter` to ensure the callback has run

## Why Unit Tests Failed

The integration tests in `FootnoteUndoRedoIntegrationTests.swift` are failing because they simulate footnote operations by **directly modifying the model**, not by calling `removeFootnoteFromText()` or `restoreFootnoteToText()`.

### What Tests Do
```swift
// Test just modifies model directly
footnote.isDeleted = true
try? modelContext.save()
// This doesn't go through removeFootnoteFromText()!
```

### What Real App Does
```swift
// Real app calls the method which manages the flag
removeFootnoteFromText(footnote)
  // Inside: isPerformingUndoRedo = true
  // Inside: modifies text + updates binding
  // Inside: resets flag after delay
```

The tests would need to:
1. Create a full FileEditView instance
2. Set up the text view coordinator
3. Call the actual methods
4. Check redo stack preservation

This is complex and would require UI testing infrastructure.

## Manual Testing Required

### Test Procedure

1. **Open a text file** with at least one footnote
2. **Type or paste text** (creates undo command)
3. **Undo** the text change (moves to redo stack)
4. **Delete a footnote** from the footnotes list
5. **Try to Redo** - should restore the text ✅

### Expected Behavior

**BEFORE FIX**:
- Step 5: Redo does nothing ❌ (redo stack was cleared)

**AFTER FIX**:
- Step 5: Redo restores the text ✅ (redo stack preserved)

### Debug Output

The fix includes debug prints to verify timing:
```
🗑️ Removing footnote <uuid> from text
🔄 handleAttributedTextChange called
🔄 isPerformingUndoRedo: true
🔄 Skipping - performing undo/redo
✅ Footnote removed from position 42
🗑️ Reset isPerformingUndoRedo flag
```

Look for:
- ✅ `isPerformingUndoRedo: true` when callback fires
- ✅ `Skipping - performing undo/redo` message
- ❌ Missing these means timing issue

### Alternative Test: Footnote Restoration

Same test but with **restoring** a deleted footnote:
1. Type/paste text → Undo
2. Restore a deleted footnote from trash
3. Redo should work ✅

## Implementation Files

**Primary Changes**:
- `FileEditView.swift` lines ~1087-1130: `removeFootnoteFromText()`
- `FileEditView.swift` lines ~1132-1180: `restoreFootnoteToText()`
- `FileEditView.swift` lines ~845-920: `handleAttributedTextChange()` with guard

**Pattern** can be reused for:
- Comment operations (when implemented)
- Image operations
- Any programmatic text modifications

## Related Documentation

- `FOOTNOTE_FIXES_RENUMBERING_DELETION_VISIBILITY.md` - Initial footnote fixes
- `WHY_TESTS_MISSED_REDO_BUG.md` - Analysis of test coverage gap
- `FOOTNOTE_UNDO_REDO_TESTS_ADDED.md` - Integration tests (failed due to testing approach)
- `UNDO_REDO_FIX_FOOTNOTE_INTERFERENCE.md` - Previous fix attempt

## Next Steps

1. ⏳ **Manual testing required** - Follow test procedure above
2. ⏳ If still broken, increase delay: `.now() + 0.05` → `.now() + 0.1`
3. ⏳ If still broken, may need different approach (explicit parameter to handleAttributedTextChange)
4. ⏳ Document final working solution once verified

## Notes

- The 0.05 second delay is minimal and shouldn't be noticeable to users
- The delay only applies to programmatic operations, not user typing
- User typing is not affected by this flag pattern
- The flag prevents only programmatic changes from creating undo commands
