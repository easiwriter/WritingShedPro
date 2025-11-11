# Feature Request: File Rename

**Status**: Requested  
**Priority**: Medium  
**Date**: 11 November 2025

## Description
Currently, there is no way to rename a file within the app. Users must delete the file and recreate it with a new name, which is inconvenient.

## User Request
"I've just realised there is no way to rename a file (is there?)." - User feedback

## Proposed Implementation

### Option 1: Rename Dialog (Recommended)
Add a menu option in FileEditView's toolbar that opens a rename dialog:
1. Long-press or menu button on the file title
2. Show text input dialog with current filename
3. Validate new name for uniqueness (including files in trash)
4. Update `file.name` and save

### Option 2: Inline Editing
Make the file title in the navigation bar tappable/editable:
1. Tap on file name in navigation bar
2. Becomes inline editable textField
3. Press return to confirm, escape to cancel
4. Same validation as above

### Option 3: Add Rename to Main Menu
Add a menu button (⋯) to the toolbar with options:
- Rename...
- Duplicate
- Move to Trash
- Export

## Technical Considerations

### Validation
Must check:
- File name not empty
- No invalid characters (same as creation)
- Name unique within folder
- Name not in trash for same folder

### UI
- Should be discoverable (menu or long-press)
- Should show current filename in input field
- Should highlight filename (not extension) for quick editing
- Should have cancel/confirm buttons

### Related Code
- `UniquenessChecker.isFileNameUnique()` - already handles trash checking
- `FileEditView` - main editor view where rename would be triggered
- `TextFile` model - `name` property to be updated

## Implementation Steps
1. Add `@State var isRenamingFile = false` to FileEditView
2. Add `@State var newFileName = ""` to store input
3. Add menu button with rename option
4. Create rename confirmation dialog
5. Add validation logic (reuse AddFileSheet pattern)
6. Update `file.name` on confirm
7. Save context

## Testing
- Rename file with valid name
- Rename to same name (should allow)
- Rename with duplicate name in folder (should reject)
- Rename with duplicate name in trash (should reject)
- Cancel rename (no changes)
- Empty name (should reject)
- Invalid characters (should reject)

## Notes
- Currently AddFileSheet prevents creating files with names matching deleted files in trash
- Same logic should apply to rename operations
- Consider showing "file already exists" vs "file in trash" messages

## Alternative Consideration
Could also add rename via long-press on file in project browser (FileGridView/FileListView if it exists).
