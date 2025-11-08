# File Movement Quick Start Guide

**Feature 008a: File Movement System**  
Move your writing between Draft, Ready, and Set Aside folders with ease.

---

## Overview

Writing Shed Pro's file movement system helps you organize your writing across three folders:
- **Draft** - Work in progress
- **Ready** - Polished and ready to submit
- **Set Aside** - Ideas and drafts for later

You can move files individually or in groups, and recover deleted files from Trash.

---

## Moving a Single File

### Using Swipe Actions (iOS Standard)

1. **Find the file** you want to move in any folder
2. **Swipe left** on the file name
3. **Tap "Move"** (blue folder icon)
4. **Select a destination** folder from the list
5. Done! The file appears in the new folder

**Quick Tip**: This works just like Mail, Files, and Photos apps on iPhone.

**Example**: Moving "Chapter 1.txt" from Draft to Ready
```
Draft folder
  ├─ Chapter 1.txt  ← Swipe left here
  └─ Notes.txt

[Swipe reveals: Move | Delete buttons]

Tap "Move" → Select "Ready" folder

Ready folder
  ├─ Chapter 1.txt  ← File now here!
  └─ Synopsis.txt
```

---

## Moving Multiple Files

### Using Edit Mode (Select Multiple)

1. **Open the folder** containing files to move
2. **Tap "Select"** button in the toolbar
3. **Tap each file** you want to move (⚪ → ⚫)
4. **Tap "Move"** button at the bottom
   - Shows count: "3 Files" 
5. **Select destination** folder
6. Done! All selected files move together

**Quick Tip**: Just like selecting photos in the Photos app.

**Example**: Moving 5 completed chapters to Ready
```
Draft folder (Edit Mode Active)

⚫ Chapter 1.txt    ← Selected
⚫ Chapter 2.txt    ← Selected  
⚫ Chapter 3.txt    ← Selected
⚪ Notes.txt        ← Not selected
⚫ Chapter 4.txt    ← Selected
⚫ Chapter 5.txt    ← Selected

[Bottom toolbar shows: Move (5 Files) | Delete (5 Files)]

Tap "Move" → Select "Ready" → All 5 chapters move!
```

### Canceling Edit Mode

- Tap **"Cancel"** button to exit without making changes
- Swipe actions return automatically

---

## Deleting Files to Trash

### Delete Single File

1. **Swipe left** on the file
2. **Tap "Delete"** (red trash icon)
3. File moves to Trash (recoverable!)

### Delete Multiple Files

1. **Tap "Select"** to enter edit mode
2. **Select files** to delete
3. **Tap "Delete"** button (shows count: "3 Files")
4. **Confirm** in the alert dialog
5. Files move to Trash

**Important**: Files in Trash can be recovered with "Put Back"!

---

## Recovering Files from Trash

### Put Back a Single File

1. **Navigate to Trash** (in sidebar)
2. **Swipe left** on the item
3. **Tap "Put Back"** (blue arrow icon)
4. File returns to its **original folder** automatically

**Example**: Recovering accidentally deleted chapter
```
Trash
  ├─ Chapter 5.txt
  │  From: Draft       ← Shows original location
  └─ Old Notes.txt
     From: Set Aside

Swipe left on "Chapter 5.txt" → Tap "Put Back"

→ File automatically returns to Draft folder!
```

### Put Back Multiple Files

1. **Navigate to Trash**
2. **Tap "Select"** to enter edit mode
3. **Select items** to restore
4. **Tap "Put Back"** button at the bottom
5. All items return to their original folders

### What If the Original Folder Is Gone?

If you deleted a file from "Ready" folder, but then deleted the Ready folder itself:
- Writing Shed Pro **automatically restores** the file to **Draft** folder
- You'll see a notification: "Original folder not found, restored to Draft"

**This ensures your writing is never lost!**

---

## Name Conflicts (Auto-Rename)

### What Happens When Two Files Have the Same Name?

Writing Shed Pro automatically renames files to prevent data loss.

**Example**:
```
Draft folder already has:
  └─ Chapter 1.txt

You move another "Chapter 1.txt" from Set Aside to Draft

Result in Draft:
  ├─ Chapter 1.txt      ← Original stays unchanged
  └─ Chapter 1 (2).txt  ← Moved file auto-renamed
```

**The pattern**: 
- First duplicate: `Chapter 1 (2).txt`
- Second duplicate: `Chapter 1 (3).txt`
- And so on...

**Quick Tip**: This is the same naming pattern as Finder on Mac and Files on iPhone.

---

## Mac-Specific Features

### Right-Click Context Menus (macOS only)

On Mac, you can **right-click** any file for quick actions:

**In File Lists**:
- **Open** - Opens the file for editing
- **Move To...** - Shows destination picker
- **Delete** - Moves file to Trash

**In Trash**:
- **Put Back** - Restores to original location
- **Delete Forever** - Permanently deletes (⚠️ cannot undo!)

### Keyboard Shortcuts (Future)

- `Cmd+Click` - Multi-select files (coming soon)
- `Delete` key - Move selected files to Trash (coming soon)

---

## Tips & Best Practices

### Organizing Your Writing

**Draft Folder**:
- Active work in progress
- Ideas and rough drafts
- Research notes

**Ready Folder**:
- Completed and polished work
- Ready for submission or publication
- Final proofread versions

**Set Aside Folder**:
- Future story ideas
- Paused projects
- Material for later

### Workflow Example

1. **Start** new story in **Draft**
2. **Write** and revise in Draft
3. **Move** to **Ready** when polished
4. **Submit** from Ready folder
5. **Move** rejected pieces to **Set Aside** for future revision
6. **Put Back** to Draft when ready to revise

### Cleaning Up Trash

- Review Trash periodically
- **Put Back** anything you still need
- **Delete Forever** old drafts you no longer need
  - ⚠️ Warning: This is permanent!

---

## Common Questions

### Q: Can I move files between different projects?
**A**: No, files can only move within the same project. This keeps your projects organized and prevents accidental mixing of unrelated work.

### Q: What folders can I move files to?
**A**: Only **Draft**, **Ready**, and **Set Aside** folders. You cannot move files directly into or out of Trash - use Delete and Put Back instead.

### Q: Can I undo a move?
**A**: Not with a single Undo button, but you can easily move the file back by repeating the move operation in reverse.

### Q: What happens if I move a file while offline?
**A**: The move happens immediately on your device. When you reconnect, the change will sync to iCloud and your other devices automatically.

### Q: Will my moves sync across devices?
**A**: Yes! All file movements sync via iCloud within a few seconds. Changes you make on iPhone will appear on your Mac and iPad automatically.

### Q: Can I copy files instead of moving them?
**A**: Not currently. File duplication is a future feature. For now, all file operations move (not copy).

### Q: How long do files stay in Trash?
**A**: Forever, until you manually delete them. Auto-deletion after 30 days is a future feature.

---

## Troubleshooting

### File Won't Move

**Problem**: Move button is grayed out or nothing happens.

**Solutions**:
- Check that you're not trying to move to the same folder (disabled)
- Make sure the file still exists (not deleted on another device)
- Try force-quitting and restarting the app

### Can't Find Deleted File

**Problem**: File isn't in Trash after deletion.

**Solutions**:
- Check the Trash folder in the sidebar
- Make sure you're looking in the correct project
- Check other devices - deletion might not have synced yet

### Put Back Restores to Wrong Folder

**Problem**: File restored to Draft instead of original folder.

**Explanation**: This happens when the original folder was deleted or no longer exists. Writing Shed Pro automatically falls back to Draft to ensure you don't lose your work.

**Solution**: Manually move the file to the correct folder using the Move feature.

---

## Getting Help

If you encounter issues with file movement:

1. Check this guide for solutions
2. Review the manual testing checklist for known issues
3. Contact support with details:
   - What you were trying to do
   - What happened instead
   - Screenshots if possible

---

**Last Updated**: November 8, 2025  
**Feature Version**: 008a v1.0  
**Supported Platforms**: iOS 18.5+, macOS 14+ (Mac Catalyst)
