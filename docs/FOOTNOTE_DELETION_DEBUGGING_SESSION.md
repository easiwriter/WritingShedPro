# Footnote Marker Deletion - Debugging Session

## Console Output Analysis

From the user's console log, we see:

### When Tapping Footnote
```
🔢 Footnote attachment tapped! ID: 036854DC-38E2-46DF-B510-89D5662A784B, number: 1
🔢 Found footnote in database, showing detail view
```

### When Deleting
```
🗑️ FootnoteDetailView.moveToTrash() called for footnote: E0228C55-5A7C-4366-AA81-5698068C0CD3
✅ Footnote E0228C55-5A7C-4366-AA81-5698068C0CD3 moved to trash, isDeleted=false ⚠️
🗑️ Removing footnote E0228C55-5A7C-4366-AA81-5698068C0CD3 from text
⚠️ Footnote attachment not found in text
```

### Footnote Attachments in Text
```
📝🎨 FootnoteAttachment.image() generating - footnoteID: 036854DC-38E2-46DF-B510-89D5662A784B, number: 1
📝🎨 FootnoteAttachment.image() generating - footnoteID: 42350612-5256-40D3-B5FB-8C9157BC8884, number: 2
```

## Key Findings

### Issue #1: ID Mismatch
- **Tapped Attachment ID**: `036854DC-38E2-46DF-B510-89D5662A784B`
- **Deleted Footnote ID**: `E0228C55-5A7C-4366-AA81-5698068C0CD3`
- **IDs in Text**: `036854DC...` and `42350612...`

The footnote being deleted (`E0228C55...`) does NOT match any attachment in the text!

### Issue #2: isDeleted Shows False
```
✅ Footnote E0228C55... moved to trash, isDeleted=false
```

This should show `isDeleted=true` after calling `moveFootnoteToTrash()`. Suggests:
- SwiftData isn't persisting the change
- Or we're looking at a stale/snapshot copy of the footnote

## Root Cause Hypothesis

The problem appears to be that:

1. User taps footnote attachment with ID `036854DC...`
2. Database lookup finds a footnote, but it has a DIFFERENT attachmentID (`E0228C55...`)
3. When we try to remove the marker using `E0228C55...`, it's not found because the text contains `036854DC...`

This suggests the database lookup in `handleFootnoteTap()` is incorrect or there's data corruption.

## Investigation Questions

1. **Is the database query correct?**
   - We're querying: `footnote.attachmentID == attachmentID`
   - Are we sure the tapped footnote's attachmentID matches the database footnote's attachmentID?

2. **Is there data corruption?**
   - Could there be multiple footnotes with the same attachmentID?
   - Could the attachmentID in the database not match the ID in the text attachment?

3. **Is SwiftUI creating a snapshot?**
   - When passing `footnote` to the sheet, is it creating a copy?
   - Would that prevent changes from being visible?

## Enhanced Logging Added

### In handleFootnoteTap()
Now logs:
- Attachment footnoteID being tapped
- Database footnote ID
- Database footnote attachmentID  
- Footnote number

### In removeFootnoteFromTextView()
Now logs:
- AttachmentID being searched for
- All footnote attachments found in text
- Each attachment's ID, position, and number

## Next Steps

1. **Run the app again** with the enhanced logging
2. **Tap a footnote marker**
3. **Click delete**
4. **Check the console** for:
   - Does the database footnote's attachmentID match the tapped attachment ID?
   - Are there multiple footnotes in the database with similar IDs?
   - What attachmentIDs are actually in the text when we try to remove?

## Expected Correct Flow

```
1. Tap attachment with footnoteID X
2. Query database for footnote WHERE attachmentID == X
3. Find footnote with:
   - id = Y (database record ID)
   - attachmentID = X (matches attachment)
4. Delete footnote Y from database
5. Remove attachment with footnoteID X from text
```

## Date
Debugging: 28 November 2025
