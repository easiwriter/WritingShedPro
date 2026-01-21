# Unified Undo Implementation for Reference Deletion

## Status
✅ COMPLETED - Implemented unified undo/redo for reference deletion using UITextView's undoManager

## Problem Solved
Previously, reference deletion undo was broken because two independent undo managers were working in parallel:
1. **UITextView.undoManager** - Automatically handled text deletion
2. **TextFileUndoManager** - Handled ReferenceDeleteCommand execution

When user pressed undo, only one system would undo, leaving the system in an inconsistent state:
- Text restored but database state not restored, OR
- Database restored but text marker not visible

## Solution Implemented
**Option 1: Use UITextView's undoManager exclusively**

Instead of using TextFileUndoManager for reference deletion, we now:
1. Execute database changes immediately via `executeReferenceDelete()`
2. Register the undo action with UITextView's undoManager via `registerUndo(withTarget:handler:)`
3. When user presses undo, both text AND database restoration happen together

## Technical Implementation

### Key Methods

#### `handleReferenceDeleted(_ attachment: ReferenceAttachment)`
- Main entry point when reference is deleted from text
- Captures entry state (refCount, referencingFileIDs) before deletion
- Calls `executeReferenceDelete()` to perform immediate database update
- Registers undo action with UITextView.undoManager

#### `executeReferenceDelete(...)`
- Performs immediate database changes:
  - Decrements reference count
  - Removes file ID from referencingFileIDs
  - Saves model context
  - Regenerates back matter with orphaned entry filtering
- Called both on delete and on redo

#### `restoreReferenceState(...)`
- Registered as undo action with UITextView.undoManager
- Restores reference count and referencingFileIDs to previous values
- Saves model context
- Regenerates back matter
- Registers redo action to perform delete again

### Flow Diagram

```
User deletes reference marker
           ↓
handleReferenceDeleted() captures state
           ↓
executeReferenceDelete() updates database
           ↓
registerUndo() with UITextView.undoManager
           ↓
Back matter regenerated (orphaned filter applied)
           ↓
[Both text and database in consistent state]

User presses UNDO
           ↓
UITextView restores text marker (automatic)
           ↓
restoreReferenceState() called from undoManager
           ↓
Database state restored
Back matter regenerated
           ↓
[Text and database both restored, entry visible in back matter]

User presses REDO
           ↓
executeReferenceDelete() called from registered redo
           ↓
Back matter regenerated
           ↓
[Text marker deleted, entry removed from back matter again]
```

## What Changed

### Removed
- Creation and execution of ReferenceDeleteCommand
- ReferenceDeleteCommand.execute() calls
- ReferenceDeleteCommandUndone notification observer
- TextFileUndoManager.execute(command) calls
- TODO comment about broken undo

### Added
- `executeReferenceDelete()` method - performs immediate database changes
- `restoreReferenceState()` method - restores database state on undo
- Direct registration with UITextView.undoManager in handleReferenceDeleted()
- Proper redo registration in restoreReferenceState()

### Modified Files
- `FileEditView.swift`:
  - handleReferenceDeleted() - now uses UITextView.undoManager
  - Added executeReferenceDelete()
  - Added restoreReferenceState()
  - Removed ReferenceDeleteCommandUndone observer

## Testing Checklist

### Delete Operation
- [ ] Delete reference marker - verify it disappears from text
- [ ] Verify entry removed from back matter (refCount=0 filter)
- [ ] Verify reference count decremented in database
- [ ] Verify file ID removed from referencingFileIDs

### Undo Operation
- [ ] Press Undo once
- [ ] Text marker restored
- [ ] Reference count restored
- [ ] Entry reappears in back matter
- [ ] NO SECOND UNDO NEEDED (unified action)

### Redo Operation
- [ ] Press Redo
- [ ] Text marker deleted again
- [ ] Entry removed from back matter again
- [ ] Reference count decremented again

### Edge Cases
- [ ] Delete multiple references - undo/redo works for each
- [ ] Undo after creating new entry - all coordinated
- [ ] Delete, undo, delete again - works correctly
- [ ] Delete while typing nearby text - coordinated undo

## Technical Notes

### Why This Works
- UITextView.undoManager records text changes automatically
- By registering our database changes as undo targets on the same undoManager, they're part of the same undo group
- One undo action restores both text (automatic) and database (via handler)

### Key Design Decision
- Database changes happen **immediately**, not deferred
- Undo action captures the old state in closure via `[weak self, ...]` capture list
- Prevents issues with state changing between delete and undo

### Thread Safety
- modelContext operations happen on main thread (UI editing context)
- Undo/Redo handlers execute on main thread
- No concurrent database access issues

## Related Features
- **Feature 029**: Reference Detection & Metadata - uses this unified undo system
- **Back Matter Generation**: Uses `referenceCount > 0` filter to exclude orphaned entries
- **Reference Counting**: Tracks refCount and referencingFileIDs for cleanup

## Commit Information
- **Commit Hash**: 764be58
- **Branch**: 021-smart-poetry-creation
- **Date**: Current session
- **Reverted Invalid Approach**: 7377b21 (removed disabling of UITextView.undoManager)
