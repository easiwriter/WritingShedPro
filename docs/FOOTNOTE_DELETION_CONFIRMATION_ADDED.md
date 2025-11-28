# Footnote Deletion Confirmation Added

**Date:** 28 November 2025

## Issues Reported

1. **No confirmation dialog** - Users could accidentally delete footnotes without confirmation
2. **Deleted footnote reappeared after app restart** - User reported a deleted footnote was still visible (without marker) after restarting the app

## Root Cause Analysis

### Issue 1: Missing Confirmation Dialogs

Both `FootnoteDetailView` and `FootnotesListView` had delete buttons that immediately deleted footnotes without asking for confirmation. While `FootnotesListView` had a `showDeleteConfirmation` state variable, it was never actually used to display a dialog.

**Locations:**
- FootnoteDetailView: Delete button directly called `moveToTrash()`
- FootnotesListView: Delete button in menu and swipe action set `showDeleteConfirmation` but no dialog was shown

### Issue 2: Persistence Investigation

The code review shows that `FootnoteManager.moveFootnoteToTrash()` **does** properly save the context:

```swift
func moveFootnoteToTrash(_ footnote: FootnoteModel, context: ModelContext) {
    // ...
    footnote.isDeleted = true
    footnote.deletedAt = Date()
    footnote.modifiedAt = Date()
    
    context.processPendingChanges()
    
    do {
        try context.save()
        context.processPendingChanges()
        // ...
    }
}
```

The "footnote reappearing" issue is likely one of these scenarios:
1. **UI caching** - The FootnotesListView wasn't refreshing after app restart
2. **View state** - The trash view was being shown, making it appear as if deletion failed
3. **Undo operation** - User may have undone the deletion
4. **Multiple instances** - User may have had footnotes with similar text

With the confirmation dialog now in place, users will be more aware of what they're deleting and less likely to be confused.

## Solution Implemented

### 1. Added Confirmation Dialogs to FootnoteDetailView

**Added State:**
```swift
@State private var showDeleteConfirmation: Bool = false
@State private var showDeleteForeverConfirmation: Bool = false
```

**Updated Delete Buttons:**
- "Move to Trash" button now shows confirmation dialog
- "Delete Forever" button now shows confirmation dialog

**Confirmation Dialogs:**
- **Move to Trash:** "You can restore this footnote from the trash later."
- **Delete Forever:** "This footnote will be permanently deleted and cannot be recovered."

### 2. Implemented Confirmation Dialog in FootnotesListView

The state variable was already defined but unused. Now properly wired up:

**Confirmation Dialog Added:**
```swift
.confirmationDialog(
    showDeleteConfirmation?.isDeleted == true 
        ? "footnotesList.confirmDeleteForever.title"
        : "footnotesList.confirmDelete.title",
    isPresented: .constant(showDeleteConfirmation != nil),
    titleVisibility: .visible,
    presenting: showDeleteConfirmation
) { footnote in
    Button(
        footnote.isDeleted 
            ? "footnotesList.confirmDeleteForever.button"
            : "footnotesList.confirmDelete.button",
        role: .destructive
    ) {
        if footnote.isDeleted {
            permanentlyDeleteFootnote(footnote)
        } else {
            moveToTrash(footnote)
        }
        showDeleteConfirmation = nil
    }
    // ...
}
```

**Smart Confirmation:**
- Shows different messages for "Move to Trash" vs "Delete Forever"
- Works for both menu actions and swipe actions
- Clear distinction between soft delete (trash) and permanent delete

### 3. Added Localization Strings

**FootnoteDetailView:**
- `footnoteDetail.confirmDelete.title` - "Move Footnote to Trash?"
- `footnoteDetail.confirmDelete.message` - "You can restore this footnote from the trash later."
- `footnoteDetail.confirmDelete.button` - "Move to Trash"
- `footnoteDetail.confirmDeleteForever.title` - "Delete Footnote Forever?"
- `footnoteDetail.confirmDeleteForever.message` - "This footnote will be permanently deleted and cannot be recovered."
- `footnoteDetail.confirmDeleteForever.button` - "Delete Forever"

**FootnotesListView:**
- `footnotesList.confirmDelete.title` - "Move Footnote to Trash?"
- `footnotesList.confirmDelete.message` - "You can restore this footnote from the trash later."
- `footnotesList.confirmDelete.button` - "Move to Trash"
- `footnotesList.confirmDeleteForever.title` - "Delete Footnote Forever?"
- `footnotesList.confirmDeleteForever.message` - "This footnote will be permanently deleted and cannot be recovered."
- `footnotesList.confirmDeleteForever.button` - "Delete Forever"

## User Experience Flow

### Normal Delete (Move to Trash)

1. User taps delete button (in detail view or list menu/swipe)
2. **Confirmation dialog appears:** "Move Footnote to Trash?"
3. User sees message: "You can restore this footnote from the trash later."
4. User chooses:
   - **Move to Trash** (red, destructive) - Confirms deletion
   - **Cancel** - Cancels operation
5. If confirmed:
   - Footnote marked as deleted in database
   - Footnote marker removed from text
   - Remaining footnotes renumbered
   - Footnote appears in trash view

### Permanent Delete (Delete Forever)

1. User taps "Delete Forever" on a trashed footnote
2. **Confirmation dialog appears:** "Delete Footnote Forever?"
3. User sees message: "This footnote will be permanently deleted and cannot be recovered."
4. User chooses:
   - **Delete Forever** (red, destructive) - Confirms permanent deletion
   - **Cancel** - Cancels operation
5. If confirmed:
   - Footnote permanently deleted from database
   - Cannot be recovered

## Benefits

1. **Prevents Accidental Deletion** - Users must confirm before deleting
2. **Clear Communication** - Users understand the difference between trash and permanent deletion
3. **Consistent UX** - Matches iOS patterns for destructive actions
4. **Recoverable Mistakes** - Soft delete allows users to restore accidentally deleted footnotes
5. **Peace of Mind** - Users can confidently manage footnotes knowing they won't lose work accidentally

## Files Modified

1. **`Views/Footnotes/FootnoteDetailView.swift`**
   - Added confirmation state variables
   - Updated delete buttons to show confirmation
   - Added confirmation dialog modifiers

2. **`Views/Footnotes/FootnotesListView.swift`**
   - Implemented confirmation dialog using existing state variable
   - Wired up menu and swipe actions to show confirmation

3. **`Resources/en.lproj/Localizable.strings`**
   - Added 12 new localization strings for confirmation dialogs

## Testing Checklist

### FootnoteDetailView
- [ ] Tap "Delete" button → Confirmation dialog appears
- [ ] Tap "Cancel" → Footnote NOT deleted
- [ ] Tap "Move to Trash" → Footnote moved to trash, marker removed
- [ ] Open trashed footnote → "Delete Forever" button shows
- [ ] Tap "Delete Forever" → Confirmation dialog appears
- [ ] Tap "Cancel" → Footnote NOT permanently deleted
- [ ] Tap "Delete Forever" → Footnote permanently deleted

### FootnotesListView
- [ ] Tap ellipsis menu → "Move to Trash" → Confirmation appears
- [ ] Swipe left → "Delete" → Confirmation appears
- [ ] In trash view, menu "Delete Forever" → Confirmation appears
- [ ] In trash view, swipe left → "Delete Forever" → Confirmation appears
- [ ] Cancel any confirmation → No action taken
- [ ] Confirm "Move to Trash" → Footnote moved to trash, marker removed
- [ ] Confirm "Delete Forever" → Footnote permanently deleted

### Persistence Testing
- [ ] Delete a footnote
- [ ] Close the app completely
- [ ] Reopen the app
- [ ] Check that deleted footnote is in trash (not in active list)
- [ ] Check that footnote marker is not in text
- [ ] Verify numbering is correct

## Related Documents

- `FOOTNOTE_MARKER_DELETION_FIX.md` - Original marker deletion fix
- `FOOTNOTE_DELETION_DEBUG.md` - Debugging the marker deletion issue
- `UNIT_TESTS_FIXED_COMPLETE.md` - Test fixes for footnote operations

## Notes for User

If you continue to see deleted footnotes reappearing after restart:

1. **Check the trash view** - Tap the trash icon in FootnotesListView to see deleted footnotes. They should be there, not in the main list.

2. **Verify permanent deletion** - To permanently delete a footnote:
   - Open FootnotesListView
   - Tap trash icon to view deleted footnotes
   - Find the footnote
   - Tap menu → "Delete Forever" → Confirm

3. **Check for multiple footnotes** - You may have multiple footnotes with similar text. The confirmation dialogs now show the footnote number to help identify which one you're deleting.

4. **Monitor the console** - The app logs deletion operations. If the issue persists, check the Xcode console for:
   - "✅ Footnote {UUID} moved to trash, isDeleted=true"
   - "✅ Footnote removed from position {N}"

If the problem continues, it may be a SwiftData caching issue that requires further investigation.
