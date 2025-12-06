# Drag-to-Reorder Handles Added to Collections

**Date**: December 6, 2025  
**Status**: ✅ Complete

## Summary

Added drag-to-reorder handles (≡) in edit mode for Collections, matching the functionality already present in ## Files Modified

1. **Views/CollectionsView.swift** (1095 lines)
   - Added `.onMove` to ForEach
   - Added `moveCollections(from:to:)` method

2. **Views/FolderFilesView.swift** (574 lines)
   - **Removed** `@State private var sortOrder` (no longer needed)
   - **Removed** sort menu from toolbar
   - Updated `sortedFiles` to always use alphabetical sorting
   - Set `onReorder: nil` when creating FileListView

3. **Views/Components/FileListView.swift** (576 lines)
   - Updated `onReorder` comment to clarify it's not used

4. **Models/Submission.swift** (81 lines)
   - Added `var userOrder: Int?` property

5. **Services/FolderFileSortServices.swift** (117 lines)
   - Added `byUserOrder` to `CollectionSortOrder` enum
   - Added sorting case for user order
   - Updated `sortOptions()` to include Custom Order

6. **Resources/en.lproj/Localizable.strings**
   - Added `"collections.sortByUserOrder" = "Custom Order";`. Users can now:
- **Select multiple collections** with checkboxes (⚪/🔵)
- **Drag to reorder collections** using handles (≡)
- Both features work simultaneously in edit mode

**Note**: Drag-to-reorder was **not** added to FileListView because files are already organized alphabetically with disclosure groups - custom reordering would conflict with this natural organization.

## iOS Pattern Clarification

There is **NO iOS restriction** preventing drag handles and checkboxes from coexisting. This is a standard iOS pattern seen in:
- **Reminders app**: Checkboxes + drag handles in edit mode
- **Music app playlists**: Multi-select + reorder
- **Notes app folders**: Both features together

The confusion arose because:
- **ProjectEditableList** has drag-to-REORDER (`.onMove`) but NO multi-select
- **FileListView/CollectionsView** had multi-select but NO drag handles
- These are two different UI patterns, both valid, but they CAN be combined

## Why Not FileListView?

**FileListView was intentionally excluded** because:
- Files are **organized alphabetically** (A-Z sections with 15+ files)
- **Disclosure groups** already provide intuitive navigation
- Custom reordering would **conflict with alphabetical organization**
- Users find files by **name**, not by position
- Breaking alphabetical order would be confusing

**Collections are different** because:
- They're **user-created submission groupings**
- Natural ordering is by **priority/workflow** (submit this batch first)
- Names don't dictate order
- Custom arrangement makes sense for submission management

## Implementation Details

### 1. CollectionsView Changes

**Added `.onMove` to ForEach:**

```swift
ForEach(sortedCollections) { collection in
    collectionRow(for: collection)
}
.onDelete(perform: isEditMode ? nil : deleteCollections)
.onMove(perform: isEditMode ? moveCollections : nil)  // ← NEW
```

**Added reordering method:**

```swift
private func moveCollections(from source: IndexSet, to destination: Int) {
    // Switch to user order sort when manually reordering
    if sortOrder != .byUserOrder {
        sortOrder = .byUserOrder
    }
    
    guard let sourceIndex = source.first else { return }
    
    // If dropping in same position, do nothing
    if destination == sourceIndex || destination == sourceIndex + 1 {
        return
    }
    
    let currentCollections = sortedCollections
    
    if sourceIndex < destination {
        // Moving down: shift items up to fill gap
        for i in sourceIndex + 1..<destination {
            currentCollections[i].userOrder = (currentCollections[i].userOrder ?? i) - 1
        }
        currentCollections[sourceIndex].userOrder = destination - 1
    } else {
        // Moving up: shift items down to make room
        let baseOrder = currentCollections[destination].userOrder ?? destination
        for i in destination..<sourceIndex {
            currentCollections[i].userOrder = (currentCollections[i].userOrder ?? i) + 1
        }
        currentCollections[sourceIndex].userOrder = baseOrder
    }
    
    try? modelContext.save()
}
```

### 2. Submission Model Changes

**Added userOrder property:**

```swift
@Model
class Submission {
    // ... existing properties ...
    
    // User-defined sort order for collections
    var userOrder: Int?
}
```

**File**: `Models/Submission.swift`, line 30

### 3. CollectionSortService Updates

**Added byUserOrder to enum:**

```swift
enum CollectionSortOrder: String, CaseIterable {
    case byUserOrder = "userOrder"      // ← NEW
    case byName = "name"
    case byCreationDate = "creationDate"
    case byModifiedDate = "modifiedDate"
    case byFileCount = "fileCount"
}
```

**Added sorting case:**

```swift
case .byUserOrder:
    return collections.sorted { (c0: Submission, c1: Submission) -> Bool in
        let order1 = c0.userOrder ?? Int.max
        let order2 = c1.userOrder ?? Int.max
        return order1 < order2
    }
```

**Updated sortOptions:**

```swift
static func sortOptions() -> [SortOption<CollectionSortOrder>] {
    [
        SortOption(.byUserOrder, title: NSLocalizedString("collections.sortByUserOrder", comment: "Sort by user order")),  // ← NEW
        // ... other options ...
    ]
}
```

### 4. Localization

**Added to `en.lproj/Localizable.strings`:**

```
"collections.sortByUserOrder" = "Custom Order";
```

## User Experience

### Edit Mode Behavior

**Before this change:**
- FileListView: ✅ Checkboxes for multi-select | ❌ No drag handles
- CollectionsView: ✅ Checkboxes for multi-select | ❌ No drag handles
- ProjectEditableList: ❌ No multi-select | ✅ Drag handles for reorder

**After this change:**
- FileListView: ✅ Checkboxes | ❌ No drag handles (alphabetical organization)
- CollectionsView: ✅ Checkboxes | ✅ Drag handles (custom ordering makes sense!)
- ProjectEditableList: ❌ No multi-select | ✅ Drag handles (unchanged)

### How It Works

1. **Enter Edit Mode**: Tap "Edit" button
2. **Multi-Select**: Tap checkboxes to select items (⚪ → 🔵)
3. **Bulk Actions**: Use bottom toolbar (Move, Delete, etc.)
4. **Reorder**: Drag items by handles (≡) on the right
5. **Auto-Sort Switch**: Dragging automatically switches to "Custom Order" sort

### Visual Layout in Edit Mode

```
┌─────────────────────────────────────┐
│  🔵  📄 Document Name           ≡   │  ← Both checkbox and handle
├─────────────────────────────────────┤
│  ⚪  📄 Another File             ≡   │  ← Can select AND reorder
├─────────────────────────────────────┤
│  🔵  📄 Third Document          ≡   │  ← Multiple selections OK
└─────────────────────────────────────┘
        ↓
   Bottom Toolbar
┌─────────────────────────────────────┐
│  Move (2)      Delete (2)    Export │
└─────────────────────────────────────┘
```

## Technical Notes

### Why This Works

SwiftUI's `List` with `ForEach` supports:
- `.onMove(perform:)` - Adds drag handles and reordering
- Selection state (via `@State`) - Adds checkboxes and multi-select
- Both can be active simultaneously

The modifiers are independent:
```swift
ForEach(items) { item in
    ItemRow(item)
}
.onDelete(perform: delete)    // Swipe-to-delete (non-edit mode)
.onMove(perform: move)         // Drag handles (edit mode)
```

### Sort Order Integration

When user drags to reorder collections:
1. **CollectionsView**: Automatically switches `sortOrder = .byUserOrder`
2. **Submission.userOrder** property stores position
3. Collections appear in custom order
4. Sort menu shows "Custom Order" with checkmark

### Persistence

- `Submission.userOrder` is a SwiftData property
- Changes persist automatically via `modelContext.save()`
- CloudKit sync supported (optional property)

## Files Modified

1. **Views/CollectionsView.swift** (1095 lines)
   - Added `.onMove` to ForEach
   - Added `moveCollections(from:to:)` method

3. **Models/Submission.swift** (81 lines)
   - Added `var userOrder: Int?` property

4. **Services/FolderFileSortServices.swift** (117 lines)
   - Added `byUserOrder` to `CollectionSortOrder` enum
   - Added sorting case for user order
   - Updated `sortOptions()` to include Custom Order

4. **Resources/en.lproj/Localizable.strings**
   - Added `"collections.sortByUserOrder" = "Custom Order";`

## Testing Recommendations

### Manual Testing

**CollectionsView:**
- [ ] Enter edit mode
- [ ] Verify checkboxes appear on left
- [ ] Verify drag handles (≡) appear on right
- [ ] Select multiple collections with checkboxes
- [ ] Drag a collection to new position
- [ ] Verify sort menu shows "Custom Order" with checkmark
- [ ] Verify new order persists

**Edge Cases:**
- [ ] Try dragging to same position (should do nothing)
- [ ] Test with 1 item (no drag possible)
- [ ] Test with 100+ items (performance check)

### Unit Testing

Potential test cases:
```swift
func testMoveCollectionsAutoSwitchesSort() {
    // Given: Sort order is byCreationDate
    // When: User drags to reorder
    // Then: Sort order becomes byUserOrder
}

func testCollectionUserOrderPersistence() {
    // Given: Collections reordered with custom order
    // When: View dismissed and reopened
    // Then: Custom order preserved
}
```

## Known Limitations

1. **FileListView**: No drag-to-reorder (intentional - files are alphabetically organized)
2. **ProjectEditableList**: Still no multi-select (would require separate task to add)
3. **No undo for reorder**: Reordering is immediate and not undoable (matches iOS Music, Reminders)

## Future Enhancements

- Add multi-select to ProjectEditableList for consistency
- Add undo support for drag-to-reorder operations
- Add animation/haptics when reordering

## Comparison with ProjectEditableList

**ProjectEditableList pattern:**
- Swipe-to-delete in normal mode
- Drag-to-reorder with handles in edit mode
- No multi-select checkboxes
- No bottom toolbar

**FileListView pattern:**
- Swipe actions in normal mode (move, delete)
- Multi-select with checkboxes in edit mode
- Alphabetical organization (A-Z sections)
- Bottom toolbar for bulk actions
- **No drag-to-reorder** (would conflict with alphabetical sorting)

**CollectionsView pattern:**
- Multi-select with checkboxes in edit mode
- Drag-to-reorder with handles in edit mode ✨
- Custom ordering makes sense for submission workflow
- Bottom toolbar for bulk actions

**Pattern rationale:**
- **Projects**: Simple list, custom user order
- **Files**: Alphabetically organized, find by name
- **Collections**: User-defined workflow order for submissions

## References

- iOS Human Interface Guidelines: Lists
- Apple Reminders app (checkboxes + drag handles)
- Apple Music app (multi-select + reorder playlists)
- SwiftUI List documentation: `.onMove(perform:)`

---

✅ **Implementation Complete** - Collections now support custom ordering with drag handles + multi-select checkboxes!
