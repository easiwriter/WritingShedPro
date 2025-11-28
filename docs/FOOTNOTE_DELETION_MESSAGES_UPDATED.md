# Footnote Deletion Messages Updated + Debugging Guide

**Date:** 28 November 2025

## Issue Reported

User reports:
1. **Two footnotes still visible after deletion** - Footnotes remain in the document after confirming deletion
2. **Unclear confirmation message** - Dialog says "can be recovered later" but doesn't explain how

## Changes Made

### 1. Updated Confirmation Dialog Messages

Made the messages more informative about what happens and how to restore:

**FootnoteDetailView:**
- **Before:** "You can restore this footnote from the trash later."
- **After:** "The footnote marker will be removed from your text. You can restore it later from the Footnotes list (tap the trash icon)."

**FootnotesListView:**
- **Before:** "You can restore this footnote from the trash later."
- **After:** "The footnote marker will be removed from your text. You can restore it later by tapping the trash icon above."

### 2. Clarified Trash Access

The trash system IS fully implemented:
- Soft delete marks footnotes as `isDeleted = true`
- Marker is removed from text
- Deleted footnotes accessible via trash icon in FootnotesListView toolbar
- Can restore or permanently delete from trash

**How to Access Trash:**
1. Open Footnotes list
2. Tap trash icon (🗑️) in top-right toolbar
3. View/restore deleted footnotes
4. Tap document icon to return to active footnotes

## Debugging the "2 Footnotes Still Visible" Issue

If footnotes are still visible after deletion, here's how to diagnose:

### Check 1: Are They Actually Deleted in Database?

**Console Logging to Check:**
When you delete a footnote, you should see:
```
🗑️ FootnoteDetailView.moveToTrash() called for footnote: <UUID>
🗑️ Calling onDelete callback...
✅ Footnote <UUID> moved to trash, isDeleted=true
🗑️ Removing footnote <UUID> from text
```

**If you see `isDeleted=false`** → Database save is failing
**If you see `⚠️ Footnote attachment not found in text`** → Marker removal is failing

### Check 2: Did the Confirmation Dialog Actually Confirm?

The new confirmation dialog system works like this:
1. Tap delete button → Sets `showDeleteConfirmation = true`
2. Dialog appears with "Move to Trash" (destructive) and "Cancel"
3. Only "Move to Trash" button actually calls `moveToTrash()`
4. "Cancel" just dismisses the dialog

**Test:** After tapping delete, make sure you're tapping the RED "Move to Trash" button, not accidentally dismissing the dialog.

### Check 3: View Different Footnote Lists

There might be confusion between:
- **Active footnotes** (default view in FootnotesListView)
- **Deleted footnotes** (trash view - tap trash icon)
- **Footnotes in the document text** (the superscript markers)

**Scenario that might explain "still seeing 2 footnotes":**
1. You deleted footnote #1
2. The marker was removed from text
3. Footnote #2 was renumbered to become footnote #1
4. You now see 2 markers in text (correct - only one was deleted)
5. But in FootnotesListView, you might have one active and one in trash

### Check 4: App Restart Persistence

**Test Procedure:**
1. Note the footnote IDs/text before deletion
2. Delete a footnote
3. Check console for "✅ Footnote <UUID> moved to trash, isDeleted=true"
4. Close app completely (force quit)
5. Reopen app
6. Open FootnotesListView and check trash
7. Is the deleted footnote in trash with `isDeleted = true`?

**If footnote reappears as active after restart:**
- Context save might be failing
- Check for SwiftData errors in console
- Might be iCloud sync reverting changes

### Check 5: Marker Removal vs Database Deletion

These are TWO separate operations:

**Operation 1: Database (FootnoteManager)**
```swift
func moveFootnoteToTrash(_ footnote: FootnoteModel, context: ModelContext) {
    footnote.isDeleted = true
    footnote.deletedAt = Date()
    try context.save()  // ← Persists to database
}
```

**Operation 2: Text View (FileEditView)**
```swift
func removeFootnoteFromText(_ footnote: FootnoteModel) {
    // Find and remove attachment from NSTextStorage
    textStorage.removeAttribute(.attachment, range: ...)
}
```

**Both must succeed for proper deletion!**

## Manual Testing Steps

### To Verify Deletion Works:

1. **Create Test Document:**
   - Add 3 footnotes to a document
   - Note their numbers and text content

2. **Delete Middle Footnote:**
   - Tap footnote marker #2
   - Tap "Delete" button
   - In confirmation dialog, tap RED "Move to Trash" button
   - Dialog should dismiss

3. **Verify Immediate Effects:**
   - Marker #2 should disappear from text
   - Marker #3 should become marker #2
   - Now only 2 markers visible in text (numbered 1 and 2)

4. **Check Trash:**
   - Open Footnotes list  
   - Tap trash icon in toolbar
   - Deleted footnote should appear in trash section
   - Should show "Deleted: X time ago"

5. **Verify Persistence:**
   - Force quit the app
   - Reopen app
   - Open document
   - Check that only 2 markers are visible
   - Check trash - deleted footnote should still be there

6. **Test Restore:**
   - In trash view, find deleted footnote
   - Swipe left → "Restore" or tap menu → "Restore"
   - Marker should reappear in text at original position
   - All footnotes should renumber correctly

### Console Commands for Debugging

While app is running, watch for these log lines:

**On Delete:**
```
🗑️ FootnoteDetailView.moveToTrash() called
✅ Footnote <UUID> moved to trash, isDeleted=true
🗑️ Removing footnote <UUID> from text
✅ Footnote removed from position <N>
```

**On Restore:**
```
♻️ Restoring footnote <UUID> to text at position <N>
✅ Footnote <UUID> restored, isDeleted=false
```

## Files Modified

1. **`Resources/en.lproj/Localizable.strings`**
   - Updated `footnoteDetail.confirmDelete.message`
   - Updated `footnotesList.confirmDelete.message`

## Next Steps

**If the issue persists after these changes:**

1. **Check Xcode console** during deletion to see if errors occur
2. **Verify the confirmation dialog** - make sure you're tapping the destructive button
3. **Count footnotes carefully** - deletion might be working but renumbering makes it confusing
4. **Check trash view** - deleted footnotes should be there, not gone
5. **Report specific error messages** from console if deletion fails

**Remember:** "Moving to trash" means:
- ✅ Marker removed from text immediately
- ✅ Footnote kept in database with `isDeleted = true`
- ✅ Accessible from trash view (tap trash icon)
- ✅ Can be restored or permanently deleted
- ❌ NOT the same as permanently deleting

The system is designed to be recoverable - footnotes are never immediately deleted, they're soft-deleted to trash first.
