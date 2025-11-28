# Footnote Marker Deletion Fix

## Issue

When deleting a footnote through the UI, the footnote marker in the text was not being removed in all cases, leaving orphaned markers that no longer have associated footnote data.

## Root Cause

The app had two paths for deleting footnotes:

1. **FootnoteDetailView** → Correctly called `onDelete` callback → `removeFootnoteFromText()` ✅
2. **FootnotesListView** → Only updated database, did NOT remove marker ❌

## Solution Implemented

### 1. Added Callbacks to FootnotesListView

Added two new callback properties to `FootnotesListView`:
- `onFootnoteDeleted: ((FootnoteModel) -> Void)?` - Called when footnote moved to trash
- `onFootnoteRestored: ((FootnoteModel) -> Void)?` - Called when footnote restored

```swift
var onFootnoteDeleted: ((FootnoteModel) -> Void)?
var onFootnoteRestored: ((FootnoteModel) -> Void)?
```

### 2. Updated FootnotesListView Methods

Modified `moveToTrash()` and `restoreFootnote()` to call the new callbacks:

```swift
private func moveToTrash(_ footnote: FootnoteModel) {
    FootnoteManager.shared.moveFootnoteToTrash(footnote, context: modelContext)
    loadFootnotes()
    onFootnoteChanged?()
    onFootnoteDeleted?(footnote) // NEW: Notify parent to remove marker
}

private func restoreFootnote(_ footnote: FootnoteModel) {
    FootnoteManager.shared.restoreFootnote(footnote, context: modelContext)
    loadFootnotes()
    onFootnoteChanged?()
    onFootnoteRestored?(footnote) // NEW: Notify parent to restore marker
}
```

### 3. Wired Up Callbacks in FileEditView

Connected the callbacks when creating `FootnotesListView`:

```swift
FootnotesListView(
    version: currentVersion,
    onJumpToFootnote: { footnote in
        jumpToFootnote(footnote)
    },
    onDismiss: {
        showFootnotesList = false
    },
    onFootnoteChanged: {
        saveChanges()
    },
    onFootnoteDeleted: { footnote in
        // NEW: Remove marker from text
        removeFootnoteFromText(footnote)
    },
    onFootnoteRestored: { footnote in
        // NEW: Restore marker to text
        restoreFootnoteToText(footnote)
    }
)
```

## Files Modified

1. `WrtingShedPro/Writing Shed Pro/Views/Footnotes/FootnotesListView.swift`
   - Added `onFootnoteDeleted` and `onFootnoteRestored` callback properties
   - Updated `moveToTrash()` and `restoreFootnote()` to call callbacks

2. `WrtingShedPro/Writing Shed Pro/Views/FileEditView.swift`
   - Wired up new callbacks when creating `FootnotesListView`

## Testing

- ✅ Delete footnote from FootnoteDetailView → Marker removed
- ✅ Delete footnote from FootnotesListView → Marker removed
- ✅ Restore footnote from trash → Marker restored
- ✅ Footnote renumbering works correctly after deletion/restoration

## Known Limitations

The following scenarios are NOT yet handled and would require additional work:

### 1. Text Deletion with Backspace/Cut

**Issue**: When a user deletes text containing a footnote marker using backspace or cut, the marker is removed from the text but the footnote remains in the database.

**Why Complex**: 
- Requires implementing `textView(_:shouldChangeTextIn:replacementText:)` delegate method
- Need to detect when an `NSTextAttachment` (footnote marker) is being deleted
- Must handle undo/redo properly (deleted footnote should be restorable)
- Need to distinguish between programmatic deletions and user deletions

**Workaround**: Users should delete footnotes using the footnote UI (detail view or list view) rather than selecting and deleting the marker text.

### 2. Paste/Undo with Footnote Markers

**Issue**: When pasting or undoing text that contains footnote markers:
- The markers may appear but point to non-existent footnotes
- Or they may need to create new footnotes
- Undo/redo chains can get complex

**Why Complex**:
- Footnote attachments contain `footnoteID` that references database objects
- When pasting, those IDs may not exist in the current document
- Need to decide: create new footnotes? Link to existing ones? Show error?
- Undo/redo must handle footnote creation/deletion atomically with text changes

**Workaround**: Avoid cutting/pasting text with footnote markers. If needed, manually recreate footnotes.

## Recommendations for Future Work

If the limitations above become problematic for users, consider:

1. **Implement `textView(_:shouldChangeTextIn:replacementText:)`**
   - Detect attachment deletions
   - Move associated footnotes to trash (soft delete)
   - Support undo by restoring footnotes

2. **Handle Paste Special**
   - Strip footnote markers from pasted content
   - Show warning to user that footnotes were not pasted
   - Or implement footnote duplication system

3. **Orphaned Marker Detection**
   - Periodically scan document for footnote markers
   - Check if associated footnotes exist in database
   - Offer to clean up orphaned markers or restore footnotes

4. **Alternative: Prevent Marker Deletion**
   - Make footnote markers non-deleteable except through UI
   - Intercept deletion attempts and show footnote detail view
   - Force users to use proper deletion workflow

## Additional Bug Fixed: ID Mismatch

### Issue

Even with the callbacks properly wired, deletion wasn't working because of an ID mismatch:
- `FootnoteModel` has two UUID properties: `id` (database) and `attachmentID` (text attachment)
- `FootnoteAttachment` stores `footnoteID` which must match `FootnoteModel.attachmentID`
- The code was incorrectly using `footnote.id` instead of `footnote.attachmentID`

### Fix

**In `removeFootnoteFromText()`**:
```swift
// Changed from footnote.id to footnote.attachmentID
FootnoteInsertionHelper.removeFootnoteFromTextView(textView, footnoteID: footnote.attachmentID)
```

**In `restoreFootnoteToText()`**:
```swift
// Changed from footnote.id to footnote.attachmentID  
let attachment = FootnoteAttachment(footnoteID: footnote.attachmentID, number: footnote.number)
```

This ensures the attachment lookup succeeds when removing/restoring footnotes.

## Date

Fixed: 28 November 2025
