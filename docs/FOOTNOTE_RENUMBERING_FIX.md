# Footnote Renumbering Fix

## Issue

After deleting a footnote, the marker was removed correctly but the remaining footnote markers weren't renumbered. For example:
- Document has footnotes numbered 1, 2, 3
- Delete footnote 1
- Footnotes should now be numbered 1, 2 (not remain as 2, 3)

## Root Cause

The `updateFootnoteAttachmentNumbers()` function was looking up footnotes using the wrong ID:

```swift
// WRONG - searches by database ID
if let footnote = FootnoteManager.shared.getFootnote(id: attachment.footnoteID, context: modelContext)
```

The `attachment.footnoteID` is actually the `attachmentID` from the database, not the database record `id`. This caused the lookup to fail, so numbers were never updated.

## Fix

Changed to use the correct lookup method:

```swift
// CORRECT - searches by attachmentID
if let footnote = FootnoteManager.shared.getFootnoteByAttachment(attachmentID: attachment.footnoteID, context: modelContext)
```

## How It Works

1. User deletes footnote 1
2. `FootnoteManager.moveFootnoteToTrash()` is called
3. Database is updated and `renumberFootnotes()` is called
   - Footnote 2 becomes footnote 1 in database
   - Footnote 3 becomes footnote 2 in database
4. `footnoteNumbersDidChange` notification is posted
5. `handleFootnoteNumbersChanged()` is triggered
6. `updateFootnoteAttachmentNumbers()` is called:
   - Enumerates all FootnoteAttachments in text
   - Looks up each footnote in database by attachmentID
   - Updates attachment.number to match database number
   - Updates attributedContent to refresh UI

## Files Modified

- `WrtingShedPro/Writing Shed Pro/Views/FileEditView.swift`
  - Fixed `updateFootnoteAttachmentNumbers()` to use `getFootnoteByAttachment()` instead of `getFootnote()`
  - Added logging for when footnotes aren't found

## Testing

1. Create a document with 3 footnotes (numbered 1, 2, 3)
2. Delete footnote 1
3. Verify remaining footnotes are renumbered to 1, 2
4. Delete footnote 1 again
5. Verify remaining footnote is numbered 1

## Console Output

When working correctly:
```
🗑️ Removing footnote <id> from text (attachmentID: <attachmentID>)
📝🗑️ Removed footnote <attachmentID> from text view at position <N>
✅ Footnote removed from position <N>
🔢 Received footnoteNumbersDidChange notification
🔢 Updating footnote attachment numbers for our version
🔢 Updating attachment <attachmentID> from 2 to 1
🔢 Updating attachment <attachmentID> from 3 to 2
✅ Footnote attachment numbers updated
```

## Related Issues

This is the same ID mismatch issue that was preventing marker deletion. The pattern is:
- `FootnoteModel` has two UUIDs: `id` (database) and `attachmentID` (text)
- `FootnoteAttachment` has `footnoteID` which corresponds to `FootnoteModel.attachmentID`
- Always use `getFootnoteByAttachment(attachmentID:)` when looking up by attachment ID
- Only use `getFootnote(id:)` when you have the database record ID

## Date

Fixed: 28 November 2025
