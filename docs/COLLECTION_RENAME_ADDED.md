# Collection Rename Feature Added

**Date**: December 6, 2025  
**Status**: ✅ Complete

## Summary

Added rename functionality to CollectionsView, matching the rename feature already available for files in FileListView. Users can now rename collections directly from the edit mode toolbar.

## User Experience

### How to Rename a Collection

1. Navigate to **Collections** in your project
2. Tap **Edit** button (top right)
3. Select **one collection** by tapping its checkbox
4. Tap **Rename** button in bottom toolbar
5. Enter new name
6. Tap **Rename** to confirm

### UI Layout

**Edit Mode Toolbar (bottom):**
```
┌─────────────────────────────────────────┐
│  Delete (1)    Rename    Add to Pub     │
└─────────────────────────────────────────┘
```

**Rename button states:**
- **Enabled**: Exactly 1 collection selected
- **Disabled**: 0 or 2+ collections selected (can only rename one at a time)

### Rename Modal

Similar to file rename modal:
- Text field pre-filled with current name
- Auto-focuses for immediate editing
- **Rename** button (disabled if empty or unchanged)
- **Cancel** button

### Duplicate Detection

If attempting to rename to a name that already exists:
- Shows alert: "Name Already Exists"
- Options:
  - **Use Anyway** - Allows duplicate names
  - **Cancel** - Returns to edit name

## Implementation Details

### 1. RenameCollectionModal Component

Created new file: `Views/Components/RenameCollectionModal.swift`

```swift
struct RenameCollectionModal: View {
    let collection: Submission
    let collectionsInProject: [Submission]
    let onRename: (String) -> Void
    
    @State private var newName: String = ""
    @State private var showDuplicateWarning = false
    @FocusState private var isNameFieldFocused: Bool
    
    // TextField with validation
    // Duplicate detection against other collections
    // Updates collection.name and collection.modifiedDate
}
```

**Key features:**
- Pre-fills with current collection name
- Case-insensitive duplicate detection
- Updates `modifiedDate` on rename
- Clears selection and exits edit mode after rename

### 2. CollectionsView Changes

**Added state variables:**
```swift
@State private var showRenameSheet = false
@State private var collectionToRename: Submission?
```

**Added toolbar button:**
```swift
Button {
    renameSelectedCollection()
} label: {
    Label("collectionsView.rename", systemImage: "pencil")
}
.disabled(selectedCollections.count != 1)
```

**Added method:**
```swift
private func renameSelectedCollection() {
    guard let collection = selectedCollections.first else { return }
    collectionToRename = collection
    showRenameSheet = true
}
```

**Added sheet:**
```swift
.sheet(isPresented: $showRenameSheet) {
    if let collection = collectionToRename {
        RenameCollectionModal(
            collection: collection,
            collectionsInProject: sortedCollections,
            onRename: { _ in
                selectedCollectionIDs.removeAll()
                withAnimation {
                    editMode = .inactive
                }
            }
        )
    }
}
```

### 3. Localization Strings

Added to `en.lproj/Localizable.strings`:

```
"collectionsView.rename" = "Rename";
"collectionsView.rename.accessibility" = "Rename selected collection";
"collectionsView.rename.title" = "Rename Collection";
"collectionsView.rename.prompt" = "Enter a new name for this collection";
"collectionsView.rename.placeholder" = "Collection name";
"collectionsView.rename.confirm" = "Rename";
"collectionsView.rename.cancel" = "Cancel";
"collectionsView.rename.duplicateTitle" = "Name Already Exists";
"collectionsView.rename.duplicateMessage" = "A collection with this name already exists. Do you want to use this name anyway?";
"collectionsView.rename.duplicateConfirm" = "Use Anyway";
"collectionsView.rename.duplicateCancel" = "Cancel";
```

## Design Consistency

### Matches FileListView Pattern

Both file rename and collection rename follow the same pattern:

| Feature | Files | Collections |
|---------|-------|-------------|
| **Access** | Edit mode → Select 1 → Rename | Edit mode → Select 1 → Rename |
| **Button** | Pencil icon | Pencil icon |
| **Modal** | RenameFileModal | RenameCollectionModal |
| **Pre-fill** | Current file name | Current collection name |
| **Validation** | Duplicate detection | Duplicate detection |
| **Post-rename** | Exit edit mode | Exit edit mode |

### Button Order (Bottom Toolbar)

**Collections:**
1. Delete (red/destructive)
2. **Rename (pencil)** ← NEW!
3. Add to Publication (book.badge.plus)

Matches typical iOS pattern of destructive → modify → add actions.

## Technical Notes

### Why Single Selection Only?

Like FileListView, rename is limited to **one item at a time** because:
- Renaming multiple items to the same name makes no sense
- Batch renaming with different names is complex UX
- Standard iOS pattern (Files app, Photos app)

### Duplicate Handling

Collections **can have duplicate names** (after confirmation):
- Unlike files which must be unique within a folder
- Collections are distinguished by UUID, not name
- Warning shown but not blocking
- User decision respected

### Data Updates

On rename:
```swift
collection.name = trimmedName
collection.modifiedDate = Date()
```

This ensures:
- Sort by Modified Date reflects the change
- CloudKit sync picks up the change
- Undo/versioning can track the change (future)

### Persistence

Changes persist automatically because:
- `Submission` is a SwiftData `@Model`
- Direct property modification is tracked
- Parent view's `@Query` reflects changes
- No explicit `save()` needed

## Files Created/Modified

1. **Views/Components/RenameCollectionModal.swift** (NEW - 116 lines)
   - Modal view for collection rename
   - Duplicate detection logic
   - Text field with validation

2. **Views/CollectionsView.swift** (1120 lines)
   - Added rename state variables
   - Added rename button to toolbar
   - Added `renameSelectedCollection()` method
   - Added rename sheet

3. **Resources/en.lproj/Localizable.strings**
   - Added 10 new strings for rename feature

## Testing Recommendations

### Manual Testing

**Basic Rename:**
- [ ] Open Collections
- [ ] Enter edit mode
- [ ] Select one collection
- [ ] Verify Rename button is enabled
- [ ] Tap Rename
- [ ] Verify modal shows with current name
- [ ] Enter new name
- [ ] Tap Rename
- [ ] Verify name changes in list

**Button States:**
- [ ] Verify Rename disabled with 0 selected
- [ ] Verify Rename enabled with 1 selected
- [ ] Verify Rename disabled with 2+ selected

**Duplicate Detection:**
- [ ] Try to rename to existing collection name
- [ ] Verify alert appears
- [ ] Tap "Cancel" - verify returns to edit
- [ ] Try again, tap "Use Anyway" - verify allows duplicate

**Edge Cases:**
- [ ] Try to rename to empty string (should be disabled)
- [ ] Try to rename to same name (should be disabled)
- [ ] Try with whitespace-only name (should be disabled)
- [ ] Rename then immediately delete (verify no crashes)

**Post-Rename Behavior:**
- [ ] Verify edit mode exits after rename
- [ ] Verify selection clears after rename
- [ ] Verify sort order updates if "Modified Date" selected

### Unit Testing

Potential test cases:
```swift
func testRenameUpdatesCollectionName() {
    // Given: Collection with name "Old Name"
    // When: Rename to "New Name"
    // Then: collection.name == "New Name"
}

func testRenameUpdatesModifiedDate() {
    // Given: Collection with old modifiedDate
    // When: Rename collection
    // Then: modifiedDate updated to current time
}

func testDuplicateDetection() {
    // Given: Collections ["A", "B", "C"]
    // When: Try to rename "B" to "A"
    // Then: Shows duplicate warning
}

func testRenameButtonDisabledWithMultipleSelections() {
    // Given: 2 collections selected
    // Then: Rename button is disabled
}
```

## Known Limitations

1. **No batch rename**: Can only rename one collection at a time
2. **No undo**: Rename is immediate, no built-in undo (could be added later)
3. **Duplicate names allowed**: After confirmation, can have duplicate collection names
4. **No rename in normal mode**: Must enter edit mode first (consistent with Files pattern)

## Future Enhancements

- Add undo support for rename operations
- Add rename option to context menu (long-press in normal mode)
- Add rename to swipe actions (in normal mode)
- Consider preventing duplicates entirely (like files)
- Add keyboard shortcut for rename (macOS)

## Comparison: Files vs Collections Rename

| Aspect | Files | Collections |
|--------|-------|-------------|
| **Component** | RenameFileModal | RenameCollectionModal |
| **Access** | Edit → Select 1 → Rename | Edit → Select 1 → Rename |
| **Validation** | Folder-scoped duplicates | Project-scoped duplicates |
| **Duplicate Policy** | Warning + override | Warning + override |
| **Updated Properties** | `file.name` | `collection.name`, `collection.modifiedDate` |
| **Post-Action** | Exit edit, clear selection | Exit edit, clear selection |

Both follow the same UX pattern for consistency!

---

✅ **Implementation Complete** - Collections can now be renamed just like files!
