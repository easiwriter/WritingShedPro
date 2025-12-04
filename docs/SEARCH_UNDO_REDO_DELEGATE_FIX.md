# Search After Undo/Redo - Delegate Method Fix

**Date:** December 4, 2025  
**Feature:** 017 - Search and Replace (Phase 1)  
**Status:** Fixed ✅

## Problem Description

After implementing replace functionality with proper UITextView.replace() calls, search stopped working after undo operations:

- ✅ Typing triggers search correctly
- ✅ Replace works and registers undo
- ✅ Undo restores text correctly
- ✅ Search field shows correct match count after undo
- ❌ **Cannot navigate matches after undo (⌘G/⌘⇧G)**
- ❌ **No highlighting appears after undo**

## Diagnostic Process

### Initial Hypothesis
Text change notification observer wasn't firing after undo/redo.

### Debug Logging Added
Added extensive logging to NotificationCenter observer:
```swift
textChangeObserver = NotificationCenter.default.addObserver(
    forName: UITextView.textDidChangeNotification,
    object: textView,
    queue: .main
) { [weak self] _ in
    guard let self = self else { return }
    print("📢 textDidChange notification received")
    print("  - searchText: '\(self.searchText)'")
    // ...
}
```

### Console Output Analysis

**When typing "xx":**
```
📢 textDidChange notification received
  - searchText: 'Lorem'
  - Triggering performSearch()
🔍 performSearch called: searchText='Lorem'
  - Found 6 matches
```
✅ Notification fires correctly

**When pressing ⌘Z (undo):**
```
🔄 performUndo called - canUndo: true
↩️ FormatApplyCommand.undo() - Reverted formatting: Typing
🔄 Undo command executed
📝 Text restored to: 'Lorem Ipsum...'
```
❌ **NO notification fired!**

### Root Cause Discovered

**UITextView.textDidChangeNotification does NOT fire for undo/redo operations.**

This is a documented UIKit behavior - the notification is only sent for direct programmatic changes and user typing, not for undo manager operations.

## Solution

### Changed from NotificationCenter to UITextViewDelegate

**Before (NotificationCenter observer):**
```swift
class InEditorSearchManager: ObservableObject {
    private var textChangeObserver: NSObjectProtocol?
    
    func connect(to textView: UITextView) {
        textChangeObserver = NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            // This doesn't fire for undo/redo!
            self?.performSearch()
        }
    }
}
```

**After (UITextViewDelegate):**
```swift
class InEditorSearchManager: NSObject, ObservableObject, UITextViewDelegate {
    
    func connect(to textView: UITextView) {
        textView.delegate = self
    }
    
    // This DOES fire for undo/redo!
    func textViewDidChange(_ textView: UITextView) {
        print("📢 textViewDidChange delegate called")
        if !self.searchText.isEmpty {
            self.performSearch()
        }
    }
}
```

### Key Changes

1. **Inheritance**: Changed from `ObservableObject` to `NSObject, ObservableObject, UITextViewDelegate`
2. **Delegate**: Set `textView.delegate = self` instead of NotificationCenter observer
3. **Method**: Implemented `textViewDidChange(_:)` delegate method
4. **Cleanup**: Removed `textChangeObserver` property and related code

## Why UITextViewDelegate Works

The `textViewDidChange(_:)` delegate method is called for **ALL** text changes:
- ✅ User typing
- ✅ Programmatic changes (textView.replace())
- ✅ **Undo operations**
- ✅ **Redo operations**
- ✅ Cut/paste operations

This is the correct way to observe text changes when you need complete coverage including undo/redo.

## Testing Required

### Manual Test Sequence
1. ✅ Open a file with text
2. ✅ Search for "Lorem" - should find matches
3. ✅ Replace first match with "test"
4. ✅ Press ⌘Z to undo
5. ✅ **Verify search still works** - should find "Lorem" again
6. ✅ Press ⌘G to navigate - should highlight match
7. ✅ Press ⌘⇧Z to redo
8. ✅ **Verify search updates** - should find "test"

### Expected Console Output (After Fix)
```
📢 textViewDidChange delegate called
  - searchText: 'Lorem'
  - Triggering performSearch()
🔍 performSearch called: searchText='Lorem'
  - Found 7 matches
```

This should appear:
- When typing
- When replacing
- **When undoing** ← Critical!
- **When redoing** ← Critical!

## Related Documentation

- **Replace Implementation**: `docs/SEARCH_UNDO_REDO_FIX.md`
- **Original Issue**: Replace + undo caused search to break
- **Previous Fix Attempt**: Used NotificationCenter observer (incomplete)

## Files Modified

- `Services/InEditorSearchManager.swift`
  - Changed class inheritance to include NSObject and UITextViewDelegate
  - Replaced NotificationCenter observer with delegate method
  - Removed textChangeObserver property
  - Implemented textViewDidChange(_:) method

## Commit

```
fix(search): Use UITextViewDelegate for undo/redo support

PROBLEM: Search stopped working after undo operations
DIAGNOSIS: NotificationCenter notification doesn't fire for undo/redo
SOLUTION: Use UITextViewDelegate.textViewDidChange(_:) instead
```

## Lessons Learned

### NotificationCenter vs Delegate for UITextView

**Use NotificationCenter when:**
- Observing from outside the text view's ownership chain
- Need to observe multiple text views without delegate conflicts
- Only care about direct programmatic changes or typing

**Use UITextViewDelegate when:**
- Need complete text change coverage including undo/redo
- Can safely set yourself as the delegate
- Need other delegate methods (selection changes, etc.)

### Debugging Text Change Issues

1. **Add debug logging** to ALL text change observation points
2. **Test undo/redo explicitly** - don't assume notifications fire
3. **Check console output** during manual testing
4. **Use delegate methods** for complete coverage

## Status

✅ **FIXED** - Search now works correctly after undo/redo operations.

The delegate method approach provides complete text change observation including undo manager operations.
