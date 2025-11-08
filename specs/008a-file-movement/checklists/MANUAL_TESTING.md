# Feature 008a: File Movement System - Manual Testing Checklist

**Date**: November 8, 2025  
**Tester**: _______________  
**Platform**: iOS ☐  |  macOS ☐  
**Device/Simulator**: _______________

---

## Pre-Test Setup

- [ ] Clean install of app on test device
- [ ] Create test project with all three folders: Draft, Ready, Set Aside
- [ ] Create 10-15 test files across different folders
- [ ] Sign in to iCloud account for sync testing
- [ ] Have second device ready for sync tests (if applicable)

---

## Part 1: Single File Movement (Swipe Actions)

### Basic Move
- [ ] **US-001**: Swipe left on a file in Draft folder
- [ ] Verify "Move" action appears with folder icon
- [ ] Tap "Move" button
- [ ] Verify MoveDestinationPicker sheet appears
- [ ] Verify current folder (Draft) is highlighted and disabled
- [ ] Verify Trash is not shown in destination list
- [ ] Tap "Ready" folder
- [ ] Verify file disappears from Draft list
- [ ] Navigate to Ready folder
- [ ] Verify file appears in Ready folder
- [ ] **Success**: Move completes in under 3 taps ✅

### Move with Name Conflict
- [ ] Create file "Test.txt" in Draft folder
- [ ] Create file "Test.txt" in Ready folder
- [ ] Move "Test.txt" from Draft to Ready
- [ ] Verify file auto-renames to "Test (2).txt"
- [ ] Verify original "Test.txt" unchanged in Ready
- [ ] **Success**: No data loss, unique names maintained ✅

### Swipe Delete
- [ ] Swipe left on a file
- [ ] Verify "Delete" action appears (red, trash icon)
- [ ] Tap "Delete" button
- [ ] Verify file disappears from folder
- [ ] Navigate to Trash
- [ ] Verify file appears in Trash with "From: [folder]" label
- [ ] **Success**: File moved to trash in under 2 taps ✅

---

## Part 2: Edit Mode (Multi-Selection)

### Activating Edit Mode
- [ ] In file list, tap "Select" button in toolbar
- [ ] Verify "Select" changes to "Cancel"
- [ ] Verify "Move" and "Delete" buttons appear (disabled)
- [ ] Verify selection circles (⚪) appear on all rows
- [ ] Verify swipe actions are disabled
- [ ] **Success**: Edit mode activates cleanly ✅

### Multi-Selection
- [ ] Tap on 3 different files
- [ ] Verify circles fill in (⚫) on selected files
- [ ] Verify "3 Files" label appears on Move button
- [ ] Verify "3 Files" label appears on Delete button
- [ ] Tap a selected file again
- [ ] Verify circle deselects back to (⚪)
- [ ] Verify count updates to "2 Files"
- [ ] **Success**: Selection state is always clear ✅

### Select All
- [ ] In edit mode, tap "Select All" button (if present)
- [ ] Verify all files show filled circles (⚫)
- [ ] Verify button changes to "Deselect All"
- [ ] Tap "Deselect All"
- [ ] Verify all circles empty (⚪)
- [ ] **Success**: Bulk selection works ✅

### Multi-File Move
- [ ] Select 5 files from Draft folder
- [ ] Tap "Move" button (shows "5 Files")
- [ ] Select "Ready" folder from picker
- [ ] Verify all 5 files move to Ready
- [ ] Verify "Select" mode exits automatically
- [ ] Navigate to Ready folder
- [ ] Verify all 5 files present
- [ ] **Success**: Multi-move completes in ~5 seconds ✅

### Multi-File Delete
- [ ] Select 3 files from Ready folder
- [ ] Tap "Delete" button (shows "3 Files")
- [ ] Verify confirmation alert appears
- [ ] Tap "Delete" in alert
- [ ] Verify files disappear from Ready
- [ ] Navigate to Trash
- [ ] Verify 3 new items in Trash
- [ ] **Success**: Multi-delete works with confirmation ✅

### Cancel Edit Mode
- [ ] Enter edit mode and select 2 files
- [ ] Tap "Cancel" button
- [ ] Verify edit mode exits
- [ ] Verify selection circles disappear
- [ ] Verify swipe actions work again
- [ ] **Success**: Cancel works without data loss ✅

---

## Part 3: Trash & Put Back

### Basic Put Back
- [ ] Delete a file "Document.txt" from Draft
- [ ] Navigate to Trash
- [ ] Swipe left on "Document.txt"
- [ ] Verify "Put Back" action appears (blue, arrow icon)
- [ ] Tap "Put Back"
- [ ] Verify item disappears from Trash
- [ ] Navigate to Draft folder
- [ ] Verify "Document.txt" restored to Draft
- [ ] **Success**: Put Back restores to original location ✅

### Put Back with Deleted Folder
- [ ] Delete a file from Ready folder
- [ ] **Manually delete the Ready folder** (or simulate via code)
- [ ] Navigate to Trash
- [ ] Tap "Put Back" on the file
- [ ] Verify notification: "Original folder not found, restored to Draft"
- [ ] Navigate to Draft
- [ ] Verify file appears in Draft
- [ ] **Success**: Fallback to Draft works ✅

### Put Back with Name Conflict
- [ ] Delete file "Test.txt" from Draft
- [ ] Create new file "Test.txt" in Draft
- [ ] Navigate to Trash
- [ ] Put back original "Test.txt"
- [ ] Navigate to Draft
- [ ] Verify both files present: "Test.txt" and "Test (2).txt"
- [ ] **Success**: Auto-rename prevents data loss ✅

### Multi-File Put Back
- [ ] Delete 5 files from various folders
- [ ] Navigate to Trash
- [ ] Enter edit mode, select all 5 items
- [ ] Tap "Put Back" button
- [ ] Verify all 5 items disappear from Trash
- [ ] Navigate to each original folder
- [ ] Verify files restored correctly
- [ ] **Success**: Multi-put-back works ✅

### Permanent Delete
- [ ] In Trash, swipe left on an item
- [ ] Verify "Delete Forever" action appears (red)
- [ ] Tap "Delete Forever"
- [ ] Verify confirmation alert with strong warning
- [ ] Tap "Delete Forever" in alert
- [ ] Verify item permanently removed from Trash
- [ ] **Success**: Permanent delete requires confirmation ✅

---

## Part 4: Mac Catalyst Features (macOS Only)

### Right-Click Context Menu (File List)
- [ ] Right-click on a file in file list
- [ ] Verify context menu appears with: Open, Move To..., Delete
- [ ] Select "Open" → verify file opens
- [ ] Right-click again, select "Move To..." → verify picker appears
- [ ] Right-click again, select "Delete" → verify file moves to trash
- [ ] **Success**: Context menus work on macOS ✅

### Right-Click Context Menu (Trash)
- [ ] Navigate to Trash
- [ ] Right-click on a trash item
- [ ] Verify context menu appears with: Put Back, Delete Forever
- [ ] Select "Put Back" → verify item restores
- [ ] Delete another file, right-click in Trash
- [ ] Select "Delete Forever" → verify confirmation and deletion
- [ ] **Success**: Trash context menus work ✅

### Cmd+Click Multi-Select (Optional)
- [ ] Hold Cmd key and click multiple files
- [ ] Verify files are selected (if supported)
- [ ] Perform move or delete operation
- [ ] **Success**: Cmd+Click works (or note if not implemented) ✅

---

## Part 5: CloudKit Sync

### Basic Sync
- [ ] On Device 1: Move file from Draft to Ready
- [ ] Wait 5-10 seconds
- [ ] On Device 2: Open Ready folder
- [ ] Verify file appears in Ready
- [ ] On Device 2: Check Draft folder
- [ ] Verify file no longer in Draft
- [ ] **Success**: Move syncs across devices ✅

### Trash Sync
- [ ] On Device 1: Delete file to Trash
- [ ] Wait 5-10 seconds
- [ ] On Device 2: Navigate to Trash
- [ ] Verify file appears in Trash with correct "From:" label
- [ ] **Success**: Trash syncs with metadata ✅

### Put Back Sync
- [ ] On Device 1: Put back item from Trash
- [ ] Wait 5-10 seconds
- [ ] On Device 2: Check Trash → item should be gone
- [ ] On Device 2: Check restored folder → file should be present
- [ ] **Success**: Put Back syncs correctly ✅

### Offline Operation
- [ ] Turn off WiFi/cellular on Device 1
- [ ] Move several files between folders
- [ ] Turn on connectivity
- [ ] Wait 10 seconds
- [ ] On Device 2: Verify moves synced
- [ ] **Success**: Offline operations queue and sync ✅

---

## Part 6: Edge Cases

### Empty Folder
- [ ] Move all files out of a folder
- [ ] Verify empty state shows ("No files in {folder}")
- [ ] **Success**: Empty state displays correctly ✅

### Very Large Trash (Performance)
- [ ] Create and delete 50+ files rapidly
- [ ] Navigate to Trash
- [ ] Verify Trash loads quickly (< 2 seconds)
- [ ] Scroll through trash list
- [ ] Verify smooth scrolling
- [ ] **Success**: Large trash performs well ✅

### Move File to Same Folder
- [ ] Select file in Draft
- [ ] Try to move to Draft (current folder)
- [ ] Verify current folder is disabled in picker
- [ ] **Success**: UI prevents same-folder moves ✅

### Rapid Selections
- [ ] Enter edit mode
- [ ] Rapidly tap 10 files in quick succession
- [ ] Verify all selections register correctly
- [ ] Verify count updates accurately
- [ ] **Success**: No race conditions in selection ✅

### Navigation During Edit Mode
- [ ] Enter edit mode, select 3 files
- [ ] Navigate to different folder
- [ ] Verify edit mode exits or selection clears
- [ ] **Success**: Navigation handles edit mode cleanly ✅

---

## Part 7: Accessibility

### VoiceOver
- [ ] Enable VoiceOver
- [ ] Navigate file list with swipe gestures
- [ ] Verify each file announces name and folder
- [ ] Activate edit mode via VoiceOver
- [ ] Select files and verify selection announces
- [ ] **Success**: VoiceOver fully functional ✅

### Dynamic Type
- [ ] Set text size to largest setting
- [ ] Verify all text readable and not truncated
- [ ] Verify buttons remain tappable
- [ ] **Success**: Supports large text sizes ✅

### Dark Mode
- [ ] Switch to Dark Mode
- [ ] Verify all screens readable
- [ ] Verify selection indicators visible
- [ ] Verify swipe actions visible
- [ ] **Success**: Dark mode fully supported ✅

---

## Part 8: Performance Benchmarks

### Move Performance
- [ ] Select 100 files (or max available)
- [ ] Start timer, tap Move button
- [ ] Select destination folder
- [ ] Stop timer when operation completes
- [ ] **Target**: < 10 seconds for 100 files
- [ ] **Actual time**: _______ seconds
- [ ] **Pass/Fail**: _______

### Delete Performance
- [ ] Select 100 files
- [ ] Start timer, tap Delete button
- [ ] Confirm deletion
- [ ] Stop timer when operation completes
- [ ] **Target**: < 5 seconds for 100 files
- [ ] **Actual time**: _______ seconds
- [ ] **Pass/Fail**: _______

### Put Back Performance
- [ ] Have 100+ items in Trash
- [ ] Select 50 items
- [ ] Start timer, tap Put Back button
- [ ] Stop timer when operation completes
- [ ] **Target**: < 8 seconds for 50 files
- [ ] **Actual time**: _______ seconds
- [ ] **Pass/Fail**: _______

---

## Summary

**Total Tests**: 70+  
**Passed**: _____  
**Failed**: _____  
**Blocked**: _____  

**Critical Issues Found**:
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

**Minor Issues Found**:
1. _______________________________________________
2. _______________________________________________

**Notes**:
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________

**Sign-off**: _______________ Date: _______________
