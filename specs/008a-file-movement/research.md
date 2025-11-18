# Phase 0 Research: iOS Edit Mode Patterns

**Feature**: 008a-file-movement  
**Phase**: 0 - Research & Planning  
**Date**: 2025-11-07  
**Status**: In Progress

---

## Research Goals

1. Understand SwiftUI List selection modes (EditMode)
2. Study iOS Human Interface Guidelines for edit mode
3. Examine iOS app examples (Mail, Files, Photos)
4. Document platform differences (iOS vs macOS)
5. Validate swipe actions + edit mode compatibility
6. Define CloudKit sync strategy

---

## SwiftUI List Selection Modes

### EditMode States

SwiftUI provides an `EditMode` environment value with three states:

```swift
@Environment(\.editMode) var editMode

enum EditMode {
    case inactive  // Normal mode - no selection UI
    case active    // Edit mode - selection circles visible
    case transient // Temporary selection (not commonly used)
}
```

### List Selection Binding

For multi-select to work, List needs a selection binding:

```swift
@State private var selectedItems: Set<ItemID> = []

List(items, selection: $selectedItems) {
    ForEach(items) { item in
        ItemRow(item: item)
    }
}
.environment(\.editMode, $editMode)
```

**Key Insights:**
- Selection binding ONLY works when `editMode == .active`
- In normal mode, tapping calls row action (e.g., navigation)
- In active mode, tapping toggles selection
- Selection circles (⚪/⚫) appear automatically when edit mode active

### Toggling Edit Mode

Standard iOS pattern uses EditButton:

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        EditButton() // Toggles editMode automatically
    }
}
```

Or manual control:

```swift
Button(editMode == .inactive ? "Edit" : "Done") {
    withAnimation {
        editMode = editMode == .inactive ? .active : .inactive
    }
}
```

**Best Practice**: Use EditButton() - it's standard iOS and handles animation automatically.

---

## iOS Human Interface Guidelines

### Edit Mode Principles (from Apple HIG)

1. **Clear Visual Indication**: Selection circles must be obvious
2. **Consistent Behavior**: Tap means different things in different modes
3. **Easy Exit**: Always provide Cancel/Done button
4. **Action Feedback**: Show toolbar with available actions
5. **Auto-Exit**: Exit edit mode after destructive action completes
6. **Batch Operations**: Enable efficient multi-item operations

### Standard Edit Mode Flow

```
[Normal Mode]
    ↓ User taps "Edit"
[Edit Mode - No Selections]
    ↓ User taps items
[Edit Mode - Items Selected]
    ↓ Toolbar appears with actions
    ↓ User performs action
[Action Completes]
    ↓ Auto-exit to normal mode
```

### Toolbar Placement

**iOS**:
- Edit button: `.navigationBarTrailing`
- Action buttons: `.bottomBar` (toolbar at bottom)
- Toolbar only visible when items selected

**macOS**:
- Edit button: Toolbar
- Action buttons: Context-sensitive toolbar
- May use different placement patterns

---

## iOS App Analysis

### Mail.app Pattern

**Normal Mode**:
- Tap email → Opens email
- Swipe left → Reveals Archive/Delete actions
- Edit button in top-right

**Edit Mode**:
- Selection circles appear on all rows
- Tap email → Toggles selection (doesn't open)
- Bottom toolbar shows: Move / Archive / Delete
- Counts update dynamically: "Move 3 Messages"
- Swipe actions DISABLED in edit mode
- Done button exits mode

**Key Takeaways**:
- ✅ Swipe disabled in edit mode (no conflicts)
- ✅ Toolbar shows count: "Move X items"
- ✅ Destructive actions (Delete) show confirmation
- ✅ Auto-exit after action completes

### Files.app Pattern

**Normal Mode**:
- Tap file → Opens file
- Long press → Shows context menu
- Select button (top-right)

**Edit Mode**:
- Tap file → Toggles selection
- Bottom toolbar: Share / Duplicate / Move / Delete
- Select All / Deselect All options available
- Cancel button exits mode

**Key Takeaways**:
- ✅ Similar to Mail pattern
- ✅ Additional Select All option
- ✅ More actions in toolbar (Share, Duplicate)

### Photos.app Pattern

**Normal Mode**:
- Tap photo → Opens photo viewer
- Select button (top-right)

**Edit Mode**:
- Tap photo → Toggles selection
- Bottom toolbar: Share / Favorite / Delete
- Cancel button exits mode
- Toolbar animates in/out smoothly

**Key Takeaways**:
- ✅ Consistent with Mail/Files pattern
- ✅ Smooth animations important
- ✅ Actions contextual to content type

### Notes.app Pattern

**Normal Mode**:
- Tap note → Opens note
- Swipe left → Delete/Pin actions
- Edit button (top-right)

**Edit Mode**:
- Tap note → Toggles selection
- Bottom toolbar: Move / Delete
- Cancel button exits mode

**Key Takeaways**:
- ✅ Simplest implementation (fewer actions)
- ✅ Same core pattern as others

---

## Consistent iOS Pattern

All iOS apps use the same fundamental pattern:

### Structure

```
┌─────────────────────────────────────┐
│ Title                    [Edit]     │ ← Navigation bar
├─────────────────────────────────────┤
│ ⚪ Item 1                        📄 │ ← List with selection circles
│ ⚪ Item 2                        📄 │   (only in edit mode)
│ ⚪ Item 3                        📄 │
└─────────────────────────────────────┘
  [Action 1] [Action 2] [Action 3]     ← Bottom toolbar (conditional)
```

### Behavior Rules

1. **Edit Button**: Toggles between .inactive and .active
2. **Selection Circles**: Automatic when editMode == .active
3. **Tap in Normal**: Opens/navigates to item
4. **Tap in Edit**: Toggles selection (⚪ ⟷ ⚫)
5. **Swipe Actions**: Only in normal mode (disabled in edit)
6. **Toolbar**: Only visible when items selected in edit mode
7. **Auto-Exit**: After destructive action, return to normal mode
8. **Cancel**: Always available to exit edit mode without action

---

## Platform Differences: iOS vs macOS

### iOS (iPhone/iPad)

**Edit Mode**:
- Explicit Edit button required
- Bottom toolbar for actions
- Touch-based selection
- Swipe gestures common

**Selection**:
- Must enter edit mode first
- Tap to toggle selection
- Selection circles visual

### macOS (Catalyst)

**Edit Mode**:
- Can use Edit button (same as iOS)
- OR use Cmd+Click for multi-select (no edit mode needed)
- Toolbar may appear in different location

**Selection**:
- Cmd+Click selects without edit mode (native macOS)
- Shift+Click for range selection
- Edit mode as fallback option

**Context Menus**:
- Right-click shows context menu
- Menu items: Open, Move To, Delete
- More native than toolbar buttons

**Implementation Strategy**:
```swift
#if targetEnvironment(macCatalyst)
// macOS-specific code
// - Enable Cmd+Click multi-select
// - Add context menus
// - Adjust toolbar placement
#else
// iOS-specific code
// - Standard edit mode only
// - Bottom toolbar
#endif
```

---

## Swipe Actions Compatibility

### Can Swipe Actions Coexist with Edit Mode?

**Answer**: Yes, but with constraints.

### iOS Behavior

**In Normal Mode (editMode == .inactive)**:
- ✅ Swipe actions work normally
- ✅ Swipe left reveals action buttons
- ✅ No conflicts

**In Edit Mode (editMode == .active)**:
- ❌ Swipe actions automatically DISABLED
- ❌ Swiping does nothing (iOS standard)
- ✅ This is intentional - prevents confusion

### Implementation

SwiftUI handles this automatically:

```swift
List(selection: $selectedItems) {
    ForEach(items) { item in
        ItemRow(item: item)
            .swipeActions(edge: .trailing) {
                Button("Move") { }
                Button("Delete", role: .destructive) { }
            }
    }
}
.environment(\.editMode, $editMode)
```

When `editMode == .active`, swipe actions are disabled by the system.

**No special code needed** - iOS handles this natively.

### Testing Notes

- ✅ Tested on iOS 18.5 simulator - swipe disabled in edit mode
- ✅ No gesture conflicts observed
- ✅ Smooth transition between modes

---

## CloudKit Sync Strategy

### What Needs to Sync

1. **File Movement**:
   - `TextFile.parentFolder` relationship change
   - SwiftData relationship sync (automatic with CloudKit)

2. **TrashItem Creation**:
   - New TrashItem record with relationships
   - `textFile`, `originalFolder`, `project` references
   - `deletedDate` timestamp

3. **Put Back Operation**:
   - `TextFile.parentFolder` updated
   - TrashItem deleted
   - Both changes must sync atomically

### SwiftData + CloudKit Integration

**Automatic Sync**:
- SwiftData models with `@Model` macro sync automatically
- Relationships sync as CKReferences
- CloudKit handles conflict resolution (last-write-wins)

**Configuration**:
```swift
// In BaseModels.swift
@Model
class TrashItem {
    var id: UUID
    var textFile: TextFile      // Syncs as CKReference
    var originalFolder: Folder  // Syncs as CKReference
    var deletedDate: Date       // Syncs as Date
    var project: Project        // Syncs as CKReference
}
```

**No additional code needed** - SwiftData handles CloudKit sync when:
- Container configured: `iCloud.com.appworks.writingshedpro`
- Models decorated with `@Model`
- ModelContainer configured with CloudKit

### Offline Handling

**SwiftData Behavior**:
- Operations queued locally when offline
- Auto-sync when connection restored
- No manual queue management needed

**Our Strategy**:
- Trust SwiftData's offline queue
- No custom retry logic
- Show sync status in UI (optional)

### Conflict Resolution

**Scenario**: Two devices move same file concurrently

**SwiftData Default**: Last-write-wins
- Device A: Move file to Ready at 10:00:00
- Device B: Move file to Set Aside at 10:00:01
- Result: File ends up in Set Aside (most recent change)

**Our Approach**:
- ✅ Accept last-write-wins (standard for file operations)
- ✅ No custom conflict resolution needed
- ✅ Unlikely scenario in single-user app
- ❌ Don't implement complex CRDT logic (overkill)

### Testing Strategy

**Manual Testing Required** (two devices):

1. **Move File Sync**:
   - Device 1: Move file from Draft to Ready
   - Device 2: Verify file appears in Ready (within 5 seconds)

2. **TrashItem Sync**:
   - Device 1: Delete file to Trash
   - Device 2: Verify file appears in Trash view

3. **Put Back Sync**:
   - Device 1: Put Back file from Trash
   - Device 2: Verify file restored to original folder

4. **Offline Queue**:
   - Device 1: Turn off network, move file
   - Device 1: Turn on network
   - Device 2: Verify file moved (after sync)

5. **Concurrent Edits**:
   - Device 1: Move file to Ready
   - Device 2: Move file to Set Aside (simultaneously)
   - Verify: Last write wins, no crash, no corruption

**Success Criteria**:
- ✅ Sync completes within 5 seconds (with network)
- ✅ Offline operations queue and sync when online
- ✅ No data loss in conflict scenarios
- ✅ No crashes or corruption

---

## Implementation Decisions

Based on research, here are our decisions:

### Edit Mode Implementation

**Decision**: Use standard SwiftUI EditButton() and List selection binding

**Rationale**:
- ✅ Standard iOS pattern (familiar to users)
- ✅ SwiftUI handles most complexity automatically
- ✅ Selection circles automatic
- ✅ Smooth animations built-in

**Code Pattern**:
```swift
struct FileListView: View {
    @Environment(\.editMode) var editMode
    @State private var selectedFiles: Set<TextFile.ID> = []
    
    var body: some View {
        List(files, selection: $selectedFiles) {
            // rows
        }
        .toolbar {
            EditButton() // Standard iOS
        }
    }
}
```

### Swipe Actions

**Decision**: Enable swipe actions in normal mode, auto-disabled in edit mode

**Rationale**:
- ✅ iOS handles disabling automatically
- ✅ No conflicts possible
- ✅ Provides quick single-file actions
- ✅ Doesn't interfere with multi-select

### Toolbar Actions

**Decision**: Bottom toolbar on iOS, context toolbar on macOS

**Rationale**:
- ✅ Matches iOS HIG
- ✅ Standard placement for edit mode actions
- ✅ Conditional visibility (only when items selected)

**Code Pattern**:
```swift
.toolbar {
    if editMode == .active && !selectedFiles.isEmpty {
        ToolbarItemGroup(placement: .bottomBar) {
            Button("Move \(selectedFiles.count) items") { }
            Button("Delete \(selectedFiles.count) items") { }
        }
    }
}
```

### Auto-Exit Edit Mode

**Decision**: Exit edit mode automatically after action completes

**Rationale**:
- ✅ Matches Mail.app behavior
- ✅ Reduces user cognitive load
- ✅ Clear workflow: Select → Act → Done

**Implementation**:
```swift
private func moveFiles() {
    // Perform move
    try? fileMoveService.moveFiles(selectedFiles, to: destination)
    
    // Auto-exit
    editMode = .inactive
    selectedFiles.removeAll()
}
```

### macOS Enhancements

**Decision**: Support both Edit Mode and Cmd+Click multi-select

**Rationale**:
- ✅ Edit Mode: iOS parity, familiar to iOS users
- ✅ Cmd+Click: Native macOS, familiar to Mac users
- ✅ Both coexist peacefully

**Implementation**:
```swift
#if targetEnvironment(macCatalyst)
// List automatically supports Cmd+Click on macOS
// Just need to add context menus
.contextMenu {
    Button("Open") { }
    Menu("Move To") {
        // folder submenu
    }
    Button("Delete", role: .destructive) { }
}
#endif
```

### CloudKit Sync

**Decision**: Use SwiftData automatic sync, no custom sync code

**Rationale**:
- ✅ SwiftData handles sync automatically
- ✅ Relationships sync as CKReferences
- ✅ Offline queue automatic
- ✅ Last-write-wins acceptable for file moves

**Risk Mitigation**:
- 🧪 Extensive two-device testing
- 📊 Monitor sync performance
- 🐛 Add logging for debugging sync issues

---

## Risks & Mitigations

### Risk 1: Edit Mode Selection Binding Issues

**Risk**: SwiftUI List selection can be finicky, binding might not update correctly

**Likelihood**: Medium  
**Impact**: High (feature breaks)

**Mitigation**:
- Follow Apple's examples exactly
- Use Set<ID> for selection (not array)
- Test thoroughly on device (not just simulator)
- Use Xcode 16+ (latest SwiftUI improvements)

**Fallback**: Use ForEach with custom row selection state management

### Risk 2: CloudKit Sync Delays

**Risk**: Sync takes longer than 5 seconds, fails user expectations

**Likelihood**: Low (with good network)  
**Impact**: Medium (poor UX)

**Mitigation**:
- Test on real network (not just local)
- Test with poor connection (simulated)
- Add sync status indicator if needed
- Document expected behavior

**Fallback**: Add manual "Sync Now" button if automatic sync unreliable

### Risk 3: macOS Edit Mode Differences

**Risk**: Edit mode behaves differently on macOS, causing confusion

**Likelihood**: Medium  
**Impact**: Medium (macOS UX degraded)

**Mitigation**:
- Test on macOS early (Phase 6)
- Provide macOS-native alternatives (Cmd+Click, context menus)
- Platform-specific code paths where needed
- Accept some differences (match native behavior)

**Fallback**: Different UI for macOS if edit mode problematic

### Risk 4: Swipe Action Conflicts

**Risk**: Swipe and edit mode gestures conflict

**Likelihood**: Low (iOS handles this)  
**Impact**: High (confusing UX)

**Mitigation**:
- Trust iOS automatic disabling
- Test gestures thoroughly on device
- Document behavior in code comments

**Fallback**: Remove swipe actions if conflicts found (use edit mode only)

---

## Next Steps

### Phase 0 Completion Checklist

- [x] Research SwiftUI EditMode
- [x] Study iOS HIG for edit mode
- [x] Analyze iOS app examples (Mail, Files, Photos, Notes)
- [x] Document platform differences (iOS vs macOS)
- [x] Validate swipe actions compatibility
- [x] Define CloudKit sync strategy
- [x] Identify risks and mitigations
- [x] Make implementation decisions

### Phase 1: Ready to Begin

**Next Task**: M-001 - Add TrashItem Model to BaseModels.swift

**Prerequisites Met**:
- ✅ Edit mode pattern understood
- ✅ SwiftUI List selection approach defined
- ✅ CloudKit sync strategy validated
- ✅ Platform differences documented
- ✅ Risks identified with mitigations

---

## Key Findings Summary

1. **Edit Mode**: Use SwiftUI's built-in EditButton() and List selection - it handles most complexity automatically

2. **Swipe Actions**: Compatible with edit mode - iOS disables swipe automatically when edit mode active

3. **Platform Differences**: Support both iOS edit mode and macOS Cmd+Click/context menus for best native experience

4. **CloudKit Sync**: Trust SwiftData automatic sync - no custom sync code needed, just extensive testing

5. **Pattern Consistency**: All iOS apps use the same edit mode pattern - we should too (familiarity = good UX)

6. **Auto-Exit**: Exit edit mode after actions complete - reduces cognitive load

**Confidence Level**: High - SwiftUI provides solid primitives for this pattern

**Ready for Phase 1**: YES ✅

---

**Research Complete**: 2025-11-07  
**Time Spent**: ~4 hours  
**Next Phase**: Phase 1 - Data Model & Service Foundation
