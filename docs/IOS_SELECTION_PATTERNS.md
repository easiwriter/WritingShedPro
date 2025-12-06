# iOS Selection Patterns - Clarification

**Date:** 6 December 2025  
**Status:** ✅ Clarified and Aligned with iOS Standards

## Overview

Clarified the selection patterns used across the app to align with standard iOS conventions. The app uses **tap-to-select** for multi-select operations, not drag-to-select.

## iOS Standard Patterns

### Pattern 1: Swipe-to-Delete (No Multi-Select)
**Used in:** ProjectEditableList

**Features:**
- **Normal Mode:** Swipe left on item → Delete button appears
- **Edit Mode:** Red minus circles appear, tap to delete
- **Edit Mode:** Reorder handles (≡) for drag-to-reorder
- **No multi-select:** Delete one item at a time

**Example:** iOS Mail (delete individual emails), iOS Reminders

### Pattern 2: Multi-Select with Checkmarks
**Used in:** FileListView, CollectionsView

**Features:**
- **Normal Mode:** Tap item → Navigate to detail view
- **Normal Mode:** Swipe left → Quick actions (Move, Delete)
- **Edit Mode:** Circular checkboxes appear (⚪ unchecked, 🔵 checked)
- **Edit Mode:** Tap item → Toggle selection
- **Edit Mode:** Bottom toolbar with bulk actions (Move, Delete, Export, etc.)
- **No drag-to-select:** Standard iOS is tap-only

**Example:** iOS Photos, iOS Files, iOS Mail (with "Select" button)

## Why No Drag-to-Select?

### iOS Convention:
- **Desktop Pattern:** Drag-to-select multiple items (Windows, macOS Finder)
- **iOS/iPad Pattern:** Tap-to-select with checkmarks
- **Reason:** Touch interfaces need larger tap targets; dragging is reserved for scrolling and reordering

### iOS Uses Drag For:
1. **Scrolling** - Primary gesture for navigation
2. **Reordering** - Drag items to new positions (with visible handles)
3. **Drag & Drop** - Moving items between apps

### iOS Uses Tap For:
1. **Selection** - Checkbox toggle
2. **Navigation** - Open detail view
3. **Actions** - Button taps

## Current Implementation

### FileListView ✅
```swift
// Edit mode row
.onTapGesture {
    if isEditMode {
        toggleSelection(for: file)  // ← Tap to select
    } else {
        onFileSelected(file)  // ← Navigate
    }
}
```

**Features:**
- Tap file → Toggle checkmark
- Bottom toolbar appears when items selected
- Actions: Move, Delete, Export, Submit, Add to Collection, Rename

### CollectionsView ✅
```swift
// Edit mode row
.onTapGesture {
    toggleSelection(for: collection)  // ← Tap to select
}
```

**Features:**
- Tap collection → Toggle checkmark
- Bottom toolbar with: Delete, Add to Publication

### ProjectEditableList ✅
```swift
// Standard List
.onDelete(perform: deleteProjects)
.onMove(perform: isEditMode ? moveProjects : nil)
```

**Features:**
- Swipe left → Delete
- Edit mode → Red minus circles
- Edit mode → Drag handles for reordering

## Comparison

| Feature | Projects | Files/Collections |
|---------|----------|-------------------|
| Normal tap | Navigate | Navigate |
| Normal swipe | Delete | Quick actions |
| Edit mode tap | N/A | Toggle selection |
| Edit mode visual | Red minus | Checkboxes |
| Multi-select | No | Yes |
| Bulk actions | No | Yes (toolbar) |
| Reordering | Yes (drag handles) | No |

## User Experience

### For Multi-Select (Files/Collections):
1. Tap "Edit" button
2. Checkboxes appear on all items
3. Tap items to select (can select many)
4. Bottom toolbar shows available actions
5. Tap action button (Move, Delete, etc.)
6. Tap "Done" to exit edit mode

### Quick Single Actions:
- **Swipe left** on any item → Quick actions appear
- No need to enter edit mode
- Faster for single items

### Projects (Different Pattern):
- Edit mode for delete and reorder only
- No multi-select needed
- Simpler workflow

## What Was Removed

### Attempted Drag-to-Select:
- Added state variables: `isDragging`, `dragStartID`
- Added `DragGesture` to file/collection rows
- **Problem:** Doesn't work well in SwiftUI List
- **Problem:** Conflicts with scrolling
- **Problem:** Not iOS standard

### Why It Didn't Work:
1. SwiftUI List rows don't track position relative to other rows
2. Drag gesture conflicts with List's scroll gesture
3. Each row's gesture only knows about that row
4. Would need complex coordinate tracking
5. Not how iOS users expect it to work

## Best Practices

### iOS Multi-Select:
✅ **DO:** Use tap-to-select with checkboxes  
✅ **DO:** Show bulk actions in bottom toolbar  
✅ **DO:** Keep swipe actions for quick single operations  
✅ **DO:** Use clear "Edit/Done" toggle

❌ **DON'T:** Try to implement drag-to-select  
❌ **DON'T:** Use non-standard selection patterns  
❌ **DON'T:** Mix desktop and mobile conventions

### Performance:
- Tap is instant (no gesture recognition delay)
- Checkmarks provide clear visual feedback
- Users know exactly what's selected
- Familiar from all iOS apps

## Conclusion

✅ **Current Implementation is Correct**

The app follows standard iOS patterns:
- **Tap-to-select** for multi-select with checkmarks
- **Swipe-to-delete** for quick single actions
- **Edit mode** for bulk operations
- **Drag-to-reorder** for changing order (projects only)

**No changes needed** - the current implementation matches iOS conventions and user expectations.

### References:
- iOS Human Interface Guidelines - Lists
- iOS Human Interface Guidelines - Selections
- iOS Photos app behavior
- iOS Files app behavior
- iOS Mail app behavior

All standard iOS apps use tap-to-select, not drag-to-select.
