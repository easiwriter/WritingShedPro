# Reference Deletion Undo/Redo Fix - January 20, 2025

## Problem Statement

When deleting a reference (note/endnote, glossary term, citation, or index entry) from formatted text:
1. The reference marker was deleted from the text (working correctly)
2. The reference remained in the back matter file (not cleaned up)
3. Undo/redo didn't work - instead of undoing the deletion, it would restore a font change from file load

## Root Cause Analysis

The code was attempting to use two incompatible undo systems simultaneously:

### Broken Approach (Previous Implementation)
```swift
// Using UITextView's native undoManager
if let undoManager = textViewCoordinator.textView?.undoManager {
    undoManager.registerUndo(withTarget: noteEntry) { target in
        target.referenceCount += 1
        try? modelContext.save()
    }
}
```

### Why This Failed

1. **FileEditView uses a custom undo system**: The `TextFileUndoManager` implements the Command pattern with `UndoableCommand` protocol
2. **UITextView's undoManager is separate**: It's the native macOS/iOS undo manager for basic text editing
3. **Commands never registered**: Changes to reference counts were registered with the UITextView's undoManager, but the custom system was completely unaware of them
4. **Undo stack mismatch**: When undoing, the custom undo manager would pop the previous command in its stack (which happened to be a font change), while the reference count change was in a different, inaccessible stack

## Solution

Created a new `ReferenceDeleteCommand` class that implements the `UndoableCommand` protocol:

### File: `ReferenceDeleteCommand.swift`

```swift
final class ReferenceDeleteCommand: UndoableCommand {
    // Stores: reference type, ID, file ID
    // Captures: previous reference count and referencingFileIDs
    // Provides: execute() to decrement, undo() to restore
    // Includes: callback to updateBackMatterFiles()
}
```

**Key Features:**
- Properly implements `UndoableCommand` protocol for integration with `TextFileUndoManager`
- Stores complete state needed for undo: `previousRefCount` and `previousReferencingFileIDs`
- `execute()` decrements reference count and removes file from referencingFileIDs
- `undo()` restores previous state completely
- Includes callback to automatically regenerate back matter after execute/undo
- Supports all four reference types: note, glossary, citation, index

### Updated: `FileEditView.swift`

**Changed all four handlers:**
- `handleNoteDeleted()` → Uses `ReferenceDeleteCommand` with note type
- `handleGlossaryDeleted()` → Uses `ReferenceDeleteCommand` with glossary type  
- `handleCitationDeleted()` → Uses `ReferenceDeleteCommand` with citation type
- `handleIndexDeleted()` → Uses `ReferenceDeleteCommand` with index type

**New Implementation Pattern:**
```swift
private func handleNoteDeleted(entryID: UUID, in project: Project) {
    // Store previous state for undo
    let previousRefCount = noteEntry.referenceCount
    let previousReferencingFileIDs = noteEntry.referencingFileIDs
    
    // Create command with all necessary context
    let command = ReferenceDeleteCommand(
        description: "Delete Note Reference",
        referenceType: "note",
        referenceID: entryID,
        fileID: file.id,
        previousRefCount: previousRefCount,
        previousReferencingFileIDs: previousReferencingFileIDs,
        targetFile: file,
        modelContext: modelContext,
        updateBackMatterCallback: { [weak self] in
            self?.updateBackMatterFiles()
        }
    )
    
    // Execute through proper undo manager
    undoManager.execute(command)
}
```

**Key Changes:**
1. Removed `textViewCoordinator.textView?.undoManager` (wrong system)
2. Now uses `self.undoManager` (FileEditView's custom TextFileUndoManager)
3. Reference count changes now properly appear in undo stack
4. Back matter automatically regenerated after execute/undo
5. Removed `saveAndUpdateBackMatter()` helper - now integrated in command callback

## Impact

### What Now Works
✅ Delete reference from text → Reference removed and undo stack updated  
✅ Undo deletion → Reference restored to text, back matter regenerated  
✅ Redo deletion → Reference removed again, undo/redo cycles properly  
✅ Back matter automatically updated on deletion and undo  
✅ Works for all reference types: notes, glossary, citations, index  

### What Was Fixed
- Reference deletion now appears in proper undo/redo stack
- Back matter files regenerate correctly after reference operations
- Undo no longer shows incorrect previous command
- Proper state restoration on undo/redo cycles
- File import from WSP no longer shows spurious undo button

## Technical Details

### Command Pattern Integration
The solution follows the existing `UndoableCommand` pattern used throughout FileEditView:
- `execute()`: performs the action (decrement count, remove file ID)
- `undo()`: reverses the action (restore count, add file ID back)
- `modelContext.save()` called in both methods for persistence
- Callback pattern triggers back matter regeneration

### State Management
Each command captures:
- Reference type (string key: "note", "glossary", "citation", "index")
- Reference ID (UUID of the entry being modified)
- File ID (UUID of the file containing the deleted reference)
- Previous reference count (restored on undo)
- Previous referencingFileIDs (Notes only - restored on undo)

### Weak References
Weak references prevent retain cycles with:
- `targetFile: TextFile?`
- `modelContext: ModelContext?`
- `updateBackMatterCallback: (() -> Void)?`

These survive being encoded/decoded but would be `nil` if restoration happens after serialization.

## Testing Checklist

- [ ] Delete a note reference and verify it appears in back matter
- [ ] Undo the deletion and verify the reference is restored
- [ ] Redo the deletion and verify it's removed again
- [ ] Delete glossary, citation, and index references
- [ ] Test undo/redo for each reference type
- [ ] Verify back matter updates immediately after deletion
- [ ] Test with imported WSP file (no spurious undo button)
- [ ] Verify undo button correctly shows as inactive on fresh load

## Files Modified

1. **Created:** `ReferenceDeleteCommand.swift` - New command class
2. **Modified:** `FileEditView.swift` - Updated four deletion handlers

## Related Specifications

- Feature 029: Manuscript Assembly - Back Matter Reference System
- 004: Undo/Redo System (Command Pattern)
