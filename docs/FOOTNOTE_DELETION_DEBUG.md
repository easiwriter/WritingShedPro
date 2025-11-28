# Footnote Deletion Debug - Marker Not Removed Issue

## Problem Report

User reports that when deleting a footnote from the FootnoteDetailView dialog (by tapping on a footnote marker, then tapping delete), the footnote is deleted from the database but the marker remains in the text.

## Expected Behavior

1. User taps footnote marker in text
2. FootnoteDetailView sheet appears
3. User taps delete button
4. Footnote is moved to trash in database
5. **Marker should be removed from text**

## Current Investigation

### Code Flow Analysis

The deletion flow should work as follows:

```
FootnoteDetailView.moveToTrash()
  → FootnoteManager.shared.moveFootnoteToTrash()
  → onDelete?() callback
    → FileEditView onDelete closure
      → removeFootnoteFromText(footnote)
        → FootnoteInsertionHelper.removeFootnoteFromTextView()
```

### Potential Issues

1. **Callback not wired**: The `onDelete` callback might not be properly connected
   - STATUS: Wiring looks correct in FileEditView.swift line 510-513
   
2. **Footnote lookup failure**: The footnote might not be found in the text
   - `removeFootnoteFromText()` searches by `footnote.id`
   - `FootnoteInsertionHelper.removeFootnoteFromTextView()` searches for attachment with matching ID
   - If footnote ID doesn't match attachment ID, removal will fail

3. **Sheet dismissal timing**: The sheet might be dismissed before the callback completes
   - The callback is called synchronously before sheet dismisses
   - Should not be an issue

## Debug Logging Added

Added console logging to trace the issue:

### In FootnoteDetailView.swift
```swift
private func moveToTrash() {
    print("🗑️ FootnoteDetailView.moveToTrash() called for footnote: \(footnote.id)")
    FootnoteManager.shared.moveFootnoteToTrash(footnote, context: modelContext)
    print("🗑️ Calling onDelete callback...")
    onDelete?()
    print("🗑️ onDelete callback completed")
}
```

### In FileEditView.swift
```swift
onDelete: {
    print("🗑️ FootnoteDetailView onDelete callback triggered for footnote: \(footnote.id)")
    removeFootnoteFromText(footnote)
    selectedFootnoteForDetail = nil
},
```

### In removeFootnoteFromText()
Already has logging:
- "🗑️ Removing footnote {id} from text"
- "✅ Footnote removed from position {position}"
- "⚠️ Footnote attachment not found in text"

## Testing Instructions

1. Run the app with the new debug logging
2. Create a footnote in a document
3. Tap the footnote marker to open detail view
4. Tap the delete button
5. Check the console output for:
   - Whether moveToTrash() is called
   - Whether onDelete callback fires
   - Whether removeFootnoteFromText() is called
   - Whether the attachment is found in text
   - Any errors or warnings

## Expected Console Output

If working correctly:
```
🗑️ FootnoteDetailView.moveToTrash() called for footnote: <UUID>
✅ Footnote <UUID> moved to trash, isDeleted=true
🗑️ Calling onDelete callback...
🗑️ FootnoteDetailView onDelete callback triggered for footnote: <UUID>
🗑️ Removing footnote <UUID> from text
📝🗑️ Removed footnote <UUID> from text view at position <N>
✅ Footnote removed from position <N>
🗑️ onDelete callback completed
```

## Possible Root Cause

Based on code review, the most likely issue is:

**ID Mismatch**: The `footnote.id` (FootnoteModel.id) might not match the `attachmentID` stored in the FootnoteAttachment.

### Verification Needed

Check if:
- `FootnoteModel.id` is the same as `FootnoteModel.attachmentID`
- OR if `FootnoteAttachment.footnoteID` should be compared against `FootnoteModel.id` or `FootnoteModel.attachmentID`

Looking at the code:
- `FootnoteAttachment` stores `footnoteID: UUID`  
- `FootnoteModel` stores both `id: UUID` and `attachmentID: UUID`
- When creating a footnote, `attachmentID` is generated separately from `id`
- The attachment is created with `FootnoteAttachment(footnoteID: attachmentID, number: ...)`

**CRITICAL**: The search in `removeFootnoteFromText()` uses `footnote.id`, but it should use `footnote.attachmentID`!

## Fix Required

In `FileEditView.removeFootnoteFromText()`, change:

```swift
// WRONG: Searches by footnote.id
if let removedRange = FootnoteInsertionHelper.removeFootnoteFromTextView(textView, footnoteID: footnote.id) {
```

To:

```swift
// CORRECT: Searches by footnote.attachmentID
if let removedRange = FootnoteInsertionHelper.removeFootnoteFromTextView(textView, footnoteID: footnote.attachmentID) {
```

## Fix Applied

### Issue Found

The bug was an ID mismatch:
- `FootnoteModel` has two IDs: `id` (database record ID) and `attachmentID` (text attachment ID)
- `FootnoteAttachment` stores `footnoteID` which corresponds to `FootnoteModel.attachmentID`
- The code was using `footnote.id` instead of `footnote.attachmentID` when searching for/creating attachments

### Changes Made

1. **In `removeFootnoteFromText()`** (FileEditView.swift ~line 1138):
   ```swift
   // OLD (WRONG):
   FootnoteInsertionHelper.removeFootnoteFromTextView(textView, footnoteID: footnote.id)
   
   // NEW (CORRECT):
   FootnoteInsertionHelper.removeFootnoteFromTextView(textView, footnoteID: footnote.attachmentID)
   ```

2. **In `restoreFootnoteToText()`** (FileEditView.swift ~line 1200):
   ```swift
   // OLD (WRONG):
   let attachment = FootnoteAttachment(footnoteID: footnote.id, number: footnote.number)
   
   // NEW (CORRECT):
   let attachment = FootnoteAttachment(footnoteID: footnote.attachmentID, number: footnote.number)
   ```

### Testing Required

1. Create a footnote
2. Tap the footnote marker to open detail view
3. Tap delete - marker should now be removed ✅
4. Restore the footnote from trash - marker should reappear ✅

## Date

Investigated: 28 November 2025
Fixed: 28 November 2025
