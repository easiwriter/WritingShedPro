# Edit Mode Workflow - Visual Guide

## Your Questions Answered

### Q1: "How does Edit work with existing delete and move?"

**A:** Edit Mode is a **mode shift** that changes the entire UI behavior. It enables selection, THEN provides actions via toolbar buttons.

### Q2: "Delete should move items to Trash, not permanently delete"

**A:** ✅ Correct! Throughout Feature 008a, "Delete" ALWAYS means "Move to Trash". Permanent deletion is out of scope.

---

## The Two Modes

### Normal Mode (Default State)

```
┌─────────────────────────────────────┐
│ Draft (5 items)           [Edit]    │ ← Edit button switches modes
├─────────────────────────────────────┤
│ my-poem.txt                      📄 │ ← Tap opens file
│ another-poem.txt                 📄 │ ← Swipe reveals actions
│ draft-story.txt                  📄 │
│ haiku.txt                        📄 │
│ sonnet.txt                       📄 │
└─────────────────────────────────────┘

USER ACTIONS IN NORMAL MODE:
├─ Tap file          → Opens file for editing
├─ Swipe left ───────→ Shows [Move] [Delete] buttons (single file)
└─ Tap "Edit" button → Switches to EDIT MODE
```

**Single File Quick Actions (Swipe):**
```
┌─────────────────────────────────────┐
│ my-poem.txt          [Move] [Delete]│ ← Swipe revealed
└─────────────────────────────────────┘
                        ↓       ↓
                    To Folder  To Trash (with confirmation)
```

---

### Edit Mode (Batch Operations)

```
┌─────────────────────────────────────┐
│ Draft (5 items)     [Cancel]        │ ← Cancel exits mode
├─────────────────────────────────────┤
│ ⚫ my-poem.txt                   📄 │ ← Selected (filled circle)
│ ⚪ another-poem.txt              📄 │ ← Not selected (empty circle)
│ ⚫ draft-story.txt               📄 │ ← Selected
│ ⚫ haiku.txt                     📄 │ ← Selected
│ ⚪ sonnet.txt                    📄 │ ← Not selected
└─────────────────────────────────────┘
  [Move 3 items]  [Delete 3 items]     ← Toolbar appears when items selected
       ↓                ↓
   To Folder       To Trash
                (with confirmation)

USER ACTIONS IN EDIT MODE:
├─ Tap file          → Toggles selection (⚪ ⟷ ⚫) - does NOT open
├─ Swipe             → Disabled (no swipe in edit mode)
├─ Tap "Move X"      → Shows destination picker sheet
├─ Tap "Delete X"    → Shows confirmation → Moves to Trash
└─ Tap "Cancel"      → Exits edit mode, clears selections
```

---

## Complete Workflows

### Workflow 1: Move Multiple Files (Edit Mode)

```
Step 1: Enter Edit Mode
┌─────────────────────────────────────┐
│ Draft                   [Edit] ← TAP│
├─────────────────────────────────────┤
│ poem1.txt                        📄 │
│ poem2.txt                        📄 │
│ poem3.txt                        📄 │
└─────────────────────────────────────┘

Step 2: Edit Mode Active - Select Files
┌─────────────────────────────────────┐
│ Draft              [Cancel]         │
├─────────────────────────────────────┤
│ ⚪ poem1.txt                     📄 │ ← TAP to select
│ ⚪ poem2.txt                     📄 │ ← TAP to select
│ ⚪ poem3.txt                     📄 │ ← TAP to select
└─────────────────────────────────────┘

Step 3: Files Selected - Toolbar Appears
┌─────────────────────────────────────┐
│ Draft              [Cancel]         │
├─────────────────────────────────────┤
│ ⚫ poem1.txt                     📄 │ ← Selected
│ ⚫ poem2.txt                     📄 │ ← Selected
│ ⚫ poem3.txt                     📄 │ ← Selected
└─────────────────────────────────────┘
  [Move 3 items] ← TAP  [Delete 3]
         ↓
Step 4: Choose Destination
┌─────────────────────────────────────┐
│ Move to Folder         [Cancel]     │
├─────────────────────────────────────┤
│ ⚪ Draft                            │
│ ⚫ Ready          ← TAP to select    │
│ ⚪ Set Aside                        │
└─────────────────────────────────────┘
  [Move to Ready]
         ↓
Step 5: Done - Auto-Exit Edit Mode
┌─────────────────────────────────────┐
│ Draft (0 items)           [Edit]    │ ← Back to normal mode
├─────────────────────────────────────┤
│ (empty - files moved)                │
└─────────────────────────────────────┘
```

---

### Workflow 2: Delete Multiple Files (Edit Mode → Trash)

```
Step 1: Enter Edit Mode & Select
┌─────────────────────────────────────┐
│ Draft              [Cancel]         │
├─────────────────────────────────────┤
│ ⚫ old-poem.txt                  📄 │
│ ⚫ bad-draft.txt                 📄 │
│ ⚪ keep-this.txt                 📄 │
└─────────────────────────────────────┘
  [Move 2 items]  [Delete 2 items] ← TAP
                         ↓
Step 2: Confirmation Dialog
┌─────────────────────────────────────┐
│          Delete 2 files?            │
│                                     │
│  This will move them to Trash.      │
│  You can restore them later.        │
│                                     │
│     [Cancel]    [Delete] ← TAP      │
└─────────────────────────────────────┘
         ↓
Step 3: Files Moved to Trash
┌─────────────────────────────────────┐
│ Trash (2 items)           [Edit]    │
├─────────────────────────────────────┤
│ old-poem.txt        From: Draft  📄 │ ← TrashItem created
│ bad-draft.txt       From: Draft  📄 │ ← TrashItem created
└─────────────────────────────────────┘
  [Put Back]  [Empty Trash - Future]
```

**Important:** Files are NOT permanently deleted - they're moved to Trash with TrashItem tracking original location.

---

### Workflow 3: Quick Single File (Swipe - No Edit Mode)

```
Step 1: Swipe Left on File (Normal Mode)
┌─────────────────────────────────────┐
│ Draft                     [Edit]    │
├─────────────────────────────────────┤
│ keep.txt                         📄 │
│ delete-this.txt  [Move] [Delete] 📄 │ ← SWIPED LEFT
│ another.txt                      📄 │
└─────────────────────────────────────┘
                      ↓       ↓
                   To Folder  To Trash

Step 2: Tap Delete
┌─────────────────────────────────────┐
│        Delete "delete-this.txt"?    │
│                                     │
│  Move to Trash?                     │
│                                     │
│     [Cancel]    [Delete] ← TAP      │
└─────────────────────────────────────┘
         ↓
Step 3: File in Trash (Still in Normal Mode)
┌─────────────────────────────────────┐
│ Trash (1 item)            [Edit]    │
├─────────────────────────────────────┤
│ delete-this.txt  From: Draft     📄 │
└─────────────────────────────────────┘
```

---

## Delete = Move to Trash (Not Permanent)

### What Happens When User "Deletes"

```
USER TAPS DELETE
       ↓
┌─────────────────────────┐
│  Confirmation Dialog    │
│  "Delete X files?"      │
│  [Cancel] [Delete]      │
└─────────────────────────┘
       ↓ User confirms
┌─────────────────────────┐
│  FileMoveService        │
│  .deleteFile(file)      │
└─────────────────────────┘
       ↓
┌─────────────────────────┐
│  1. Create TrashItem    │
│     - file reference    │
│     - originalFolder    │
│     - deletedDate       │
└─────────────────────────┘
       ↓
┌─────────────────────────┐
│  2. Remove from source  │
│     file.parentFolder   │
│     = nil               │
└─────────────────────────┘
       ↓
┌─────────────────────────┐
│  3. File appears in     │
│     Trash folder view   │
│     (via TrashItem)     │
└─────────────────────────┘
       ↓
┌─────────────────────────┐
│  User can "Put Back"    │
│  to restore file        │
└─────────────────────────┘
```

### What's NOT Happening

❌ File is NOT permanently deleted  
❌ File data is NOT destroyed  
❌ No way to "Empty Trash" in this feature  
❌ No auto-delete after 30 days

✅ File still exists in database  
✅ File can be restored  
✅ TrashItem tracks original location  

---

## Mode Switching Summary

```
┌────────────────────────────────────────────────────────┐
│                    USER INTERACTION                    │
└────────────────────────────────────────────────────────┘
                            │
                    ┌───────┴───────┐
                    │               │
            ┌───────▼──────┐   ┌───▼────────┐
            │ NORMAL MODE  │   │ EDIT MODE  │
            └──────────────┘   └────────────┘
            │                  │
            │ • Tap = Open     │ • Tap = Select
            │ • Swipe = Action │ • No swipe
            │ • No selections  │ • Circles show state
            │ • No toolbar     │ • Toolbar has actions
            │                  │
            └──────────────────┘

KEY INSIGHT: Edit Mode doesn't just enable selection - it changes
            the ENTIRE behavior of the UI. Tapping a file means
            something completely different in each mode.
```

---

## iOS Standard Examples

This is the EXACT pattern used by:

### Mail.app
- Normal: Tap email opens it
- Edit: Tap email selects it, toolbar shows "Move" / "Archive" / "Delete"

### Files.app
- Normal: Tap file opens it
- Edit: Tap file selects it, toolbar shows actions

### Photos.app
- Normal: Tap photo opens it
- Edit: Tap photo selects it, toolbar shows "Share" / "Delete"

### Notes.app
- Normal: Tap note opens it
- Edit: Tap note selects it, toolbar shows "Move" / "Delete"

**Users already know this pattern!**

---

## Technical Implementation Notes

### FileListView State

```swift
struct FileListView: View {
    // Mode state
    @State private var editMode: EditMode = .inactive
    
    // Selection state
    @State private var selectedFiles: Set<TextFile.ID> = []
    
    // Action state
    @State private var showMoveSheet = false
    @State private var showDeleteConfirm = false
    
    var body: some View {
        List(selection: $selectedFiles) {
            ForEach(files) { file in
                FileRow(file: file)
                    .swipeActions(edge: .trailing) {
                        // Only shown when editMode == .inactive
                        Button("Move") { showMoveSheet = true }
                        Button("Delete", role: .destructive) { 
                            showDeleteConfirm = true 
                        }
                    }
            }
        }
        .environment(\.editMode, $editMode)
        .toolbar {
            // Edit button (normal mode)
            if editMode == .inactive {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { editMode = .active }
                }
            }
            
            // Cancel button (edit mode)
            if editMode == .active {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { 
                        editMode = .inactive
                        selectedFiles.removeAll()
                    }
                }
            }
            
            // Action toolbar (edit mode with selections)
            if editMode == .active && !selectedFiles.isEmpty {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Move \(selectedFiles.count) items") {
                        showMoveSheet = true
                    }
                    Button("Delete \(selectedFiles.count) items") {
                        showDeleteConfirm = true
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete \(selectedFiles.count) files?",
            isPresented: $showDeleteConfirm
        ) {
            Button("Delete", role: .destructive) {
                deleteFiles() // Moves to Trash, NOT permanent
                editMode = .inactive
            }
        } message: {
            Text("This will move them to Trash. You can restore them later.")
        }
    }
    
    private func deleteFiles() {
        for fileID in selectedFiles {
            if let file = files.first(where: { $0.id == fileID }) {
                // Creates TrashItem, moves to Trash
                try? fileMoveService.deleteFile(file)
            }
        }
        selectedFiles.removeAll()
    }
}
```

---

## Summary

### Your Questions Answered

**Q: "How does Edit work with existing delete and move?"**

A: Edit Mode is a mode shift that:
1. Enables file selection (tap toggles ⚪ ⟷ ⚫)
2. Shows toolbar with action buttons (Move X items, Delete X items)
3. Disables swipe actions (to avoid conflicts)
4. Changes tap behavior (select instead of open)
5. Provides Cancel to exit mode

**Q: "Delete should move to Trash, not permanently delete"**

A: ✅ Confirmed! Throughout Feature 008a:
- Delete button → Confirmation → **Moves to Trash**
- TrashItem created with originalFolder reference
- File can be restored via "Put Back"
- NO permanent deletion in this feature
- Empty Trash / Permanent Delete deferred to future

### The Pattern

```
NORMAL MODE: Individual file actions (tap to open, swipe for quick actions)
     ↕ Tap "Edit" / "Cancel"
EDIT MODE: Batch operations (tap to select, toolbar for actions)
```

This is the iOS standard pattern your users already know from Mail, Files, Photos, and Notes.
