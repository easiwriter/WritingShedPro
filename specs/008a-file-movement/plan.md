# Implementation Plan: File Movement System

**Branch**: `008a-file-movement` | **Date**: 2025-11-07 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/008a-file-movement/spec.md`

## Summary

Enable users to move text files between source folders (Draft, Ready, Set Aside) within Poetry and Short Story projects, with smart Trash functionality supporting restoration via "Put Back". Implements Edit Mode for multi-select and swipe actions for quick single-file operations.

**Technical Approach**: Extend existing Folder and TextFile models with TrashItem tracking model. Implement iOS-standard Edit Mode pattern for multi-selection. Use SwiftData relationships and CloudKit sync for seamless cross-device experience.

## Technical Context

**Storage**: SwiftData (local) + CloudKit (sync)

**Target Platform**: iOS 18.5+, macOS 14+ (via MacCatalyst)  
**Project Type**: Multiplatform (iOS + MacCatalyst)

```
WrtingShedPro/Writing Shed Pro/
├── Models/
│   └── BaseModels.swift         # Existing: Project, Folder, TextFile
│                                # New: TrashItem model
├── Services/
│   ├── FolderCapabilityService.swift  # Existing
│   └── FileMoveService.swift          # NEW: File movement logic
├── Views/
│   ├── FolderDetailView.swift   # Existing (to be modified)
│   ├── Components/
│   │   ├── FileListView.swift          # NEW: Reusable file list with edit mode
│   │   └── MoveDestinationPicker.swift # NEW: Folder picker sheet
│   └── Trash/
│       └── TrashView.swift             # NEW: Trash folder view
└── Extensions/
    └── Collection+Extensions.swift     # Helper for selections

WritingShedProTests/
├── FileMoveServiceTests.swift          # NEW: Movement logic tests
├── TrashItemTests.swift                # NEW: TrashItem model tests
└── FileListViewTests.swift             # NEW: Edit mode UI tests
```

**Structure Decision**: Use existing multiplatform Xcode app structure. New TrashItem model added to BaseModels.swift alongside existing models. FileMoveService encapsulates all movement logic (validation, TrashItem creation, folder updates). FileListView provides reusable edit mode UI for all folder views. Tests organized by feature area (model, service, UI).

**Scale/Scope**: 
- ~50-100 files per project (typical poetry collection)
- 10-20 projects per user
- Supports offline operation with sync when online
- Edit mode handles 100+ files efficiently (iOS standard pattern)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

✅ **Single Responsibility**: FileMoveService handles moves, TrashItem handles restoration metadata  
✅ **No Premature Abstraction**: Using concrete models, no generic "Item" or "Container" abstractions  
✅ **Fail Fast**: Movement validation throws errors early (cross-project moves blocked)  
✅ **Explicit over Implicit**: TrashItem.originalFolder explicit relationship (not inferred)  
✅ **Test First**: TDD approach - unit tests before implementation  
✅ **Minimize Dependencies**: Only depends on existing Project/Folder/TextFile models  

**No violations to justify.**

## Project Structure

### Documentation (this feature)

```
specs/008a-file-movement/
├── plan.md              # This file
├── spec.md              # Feature specification (complete)
├── checklists/          # TBD in Phase 1
├── contracts/           # TBD in Phase 1
├── data-model.md        # TBD in Phase 1
└── quickstart.md        # TBD in Phase 1
```

### Source Code (repository root)

```
WrtingShedPro/Writing Shed Pro/
├── Models/
│   └── BaseModels.swift
│       # Add TrashItem model:
│       # - id: UUID
│       # - textFile: TextFile
│       # - originalFolder: Folder
│       # - deletedDate: Date
│       # - project: Project
│
├── Services/
│   └── FileMoveService.swift              # NEW
│       # Core operations:
│       # - moveFile(_:to:) throws
│       # - moveFiles(_:to:) throws
│       # - deleteFile(_:) throws
│       # - deleteFiles(_:) throws
│       # - putBack(_:) throws
│       # - putBackMultiple(_:) throws
│       # - validateMove(_:to:) throws
│
├── Views/
│   ├── Components/
│   │   ├── FileListView.swift             # NEW
│   │   │   # Reusable file list with:
│   │   │   # - Edit mode support
│   │   │   # - Swipe actions
│   │   │   # - Selection state
│   │   │   # - Toolbar integration
│   │   │
│   │   └── MoveDestinationPicker.swift    # NEW
│   │       # Sheet showing:
│   │       # - Available destination folders
│   │       # - Filtered by project
│   │       # - Excludes current folder
│   │       # - Cancel/Done actions
│   │
│   ├── FolderDetailView.swift              # MODIFY
│   │   # Replace existing List with FileListView
│   │   # Add Edit button to toolbar
│   │   # Handle move/delete toolbar actions
│   │
│   └── Trash/
│       └── TrashView.swift                 # NEW
│           # Shows TrashItem list
│           # Displays "From: {folder}" labels
│           # Put Back button/action
│
└── Extensions/
    └── Collection+Extensions.swift         # NEW (if needed)
        # Helper methods for Set<UUID> selection handling

WritingShedProTests/
├── FileMoveServiceTests.swift              # NEW (~15 tests)
├── TrashItemTests.swift                    # NEW (~8 tests)
├── FileListEditModeTests.swift             # NEW (~10 tests)
└── MovePutBackIntegrationTests.swift       # NEW (~5 tests)
```

**Structure Decision**: Minimal new code - one new service (FileMoveService), one new model (TrashItem), and three new views (FileListView, MoveDestinationPicker, TrashView). Modification of existing FolderDetailView is minor (use new FileListView component). This approach maximizes code reuse and maintains consistency with existing patterns.

## Complexity Tracking

*No constitution violations - no complexity justification needed.*

---

## Edit Mode Pattern Explained

### How Edit Mode Serves Both Selection AND Actions

**Common Confusion**: "If Edit enables selection, how do I trigger Move/Delete?"

**Answer**: Edit Mode is a **mode shift** that changes the entire UI behavior:

```
┌─────────────────────────────────────────────────────────────┐
│                    NORMAL MODE                              │
├─────────────────────────────────────────────────────────────┤
│  Tap file       → Opens file for editing                    │
│  Swipe left     → Reveals Move/Delete buttons (single file) │
│  Edit button    → Switches to Edit Mode                     │
└─────────────────────────────────────────────────────────────┘

                            ↓ Tap "Edit"

┌─────────────────────────────────────────────────────────────┐
│                    EDIT MODE                                │
├─────────────────────────────────────────────────────────────┤
│  Tap file       → Toggles selection (does NOT open)         │
│  Swipe          → Disabled (no swipe in edit mode)          │
│  Selection      → Shows ⚪ (unselected) or ⚫ (selected)     │
│  Toolbar        → Appears with "Move X" and "Delete X"      │
│  Cancel button  → Exits edit mode, clears selections        │
└─────────────────────────────────────────────────────────────┘
```

### Complete User Workflows

#### Workflow 1: Move Multiple Files (Edit Mode)
1. User taps **"Edit"** button → UI enters edit mode
2. Selection circles appear on all files (⚪ empty circles)
3. User taps 3 files → Circles fill (⚫) showing selection
4. Bottom toolbar appears showing **"Move 3 items"** and **"Delete 3 items"**
5. User taps **"Move 3 items"** → Destination picker sheet appears
6. User selects destination folder (e.g., "Ready")
7. Files move, sheet dismisses, edit mode auto-exits
8. Back in normal mode

#### Workflow 2: Delete Multiple Files (Edit Mode)
1. User taps **"Edit"** button → UI enters edit mode
2. User selects 5 files → ⚫⚫⚫⚫⚫
3. User taps **"Delete 5 items"** button in toolbar
4. Confirmation alert: "Delete 5 files?" with "Delete" / "Cancel"
5. User confirms → **Files move to Trash** (TrashItems created)
6. Edit mode auto-exits
7. Files no longer visible in current folder

#### Workflow 3: Quick Single File Action (Swipe - No Edit Mode)
1. User in normal mode (not edit mode)
2. User swipes left on one file
3. "Move" and "Delete" buttons appear (trailing swipe actions)
4. User taps "Move" → Destination picker appears
5. OR user taps "Delete" → Confirmation → **Moves to Trash**
6. Stays in normal mode (no edit mode needed)

### Why This Pattern Works

**Advantages:**
- ✅ **iOS Standard** - Used by Mail, Files, Photos, Notes
- ✅ **Familiar** - Users already know this pattern
- ✅ **Mode-appropriate** - Tap behavior changes based on context
- ✅ **Efficient** - Batch operations on many files
- ✅ **Safe** - Clear visual feedback (circles show selection state)
- ✅ **Flexible** - Swipe for quick single actions, Edit for batch

**Key Design Principles:**
1. **Edit Mode = Selection Mode** - Tapping selects, doesn't open
2. **Toolbar = Action Buttons** - Appears when items selected
3. **Auto-Exit** - Mode exits after action completes (less cognitive load)
4. **Visual Clarity** - Empty circles (⚪) vs filled circles (⚫)
5. **Cancel Escape** - Always provide way to exit without action

### Delete = Move to Trash (Not Permanent)

**IMPORTANT CLARIFICATION:**

Throughout this feature, **"Delete" always means "Move to Trash"**:

- ✅ Delete button in swipe actions → Moves to Trash
- ✅ Delete button in edit mode toolbar → Moves to Trash
- ✅ TrashItem created with originalFolder reference
- ✅ User can "Put Back" to restore
- ❌ **NO permanent deletion** in this feature

**Permanent Deletion** (future feature, not 008a):
- Empty Trash action (deferred)
- Delete from Trash (deferred)
- Auto-delete after 30 days (deferred)

---

## Implementation Phases

### Phase 0: Research & Planning (Day 1)
**Goal**: Understand iOS edit mode patterns and validate approach

#### 0.1 Research iOS Edit Mode Best Practices
- Study SwiftUI List selection modes (.inactive, .active, .transient)
- Review Apple Human Interface Guidelines for edit mode
- Examine Mail.app and Files.app edit mode patterns
- Document macOS differences (Cmd+Click vs Edit button)

#### 0.2 Validate SwipeActions Compatibility
- Test swipe actions work alongside edit mode
- Verify no conflicts when both enabled
- Document iOS standard behavior (swipe disabled in edit mode)

#### 0.3 CloudKit Sync Strategy
- Confirm SwiftData relationship sync works for TrashItem
- Test parentFolder changes sync reliably
- Plan offline handling (queue moves until online)

**Deliverables**:
- ✅ Research notes documenting iOS patterns
- ✅ CloudKit sync strategy documented
- ✅ Risks identified and mitigation planned

---

### Phase 1: Data Model & Service Foundation (Days 2-3)
**Goal**: Build data layer and core movement logic

#### 1.1 Add TrashItem Model
- Add to `BaseModels.swift`
- SwiftData @Model with CloudKit sync
- Relationships:
  - `textFile: TextFile` (one-to-one)
  - `originalFolder: Folder` (many-to-one)
  - `project: Project` (many-to-one)
- Properties:
  - `deletedDate: Date`
  - `id: UUID`
- Cascade delete rules (if TextFile deleted, TrashItem deleted)

#### 1.2 Create FileMoveService
- `FileMoveService.swift` in Services/
- Core methods:
  ```swift
  func moveFile(_ file: TextFile, to folder: Folder) throws
  func moveFiles(_ files: [TextFile], to folder: Folder) throws
  func deleteFile(_ file: TextFile) throws
  func deleteFiles(_ files: [TextFile]) throws
  func putBack(_ trashItem: TrashItem) throws
  func putBackMultiple(_ items: [TrashItem]) throws
  func validateMove(_ file: TextFile, to folder: Folder) throws
  ```
- Validation logic:
  - Same project check
  - Source folder detection (Draft/Ready/Set Aside)
  - Destination folder validation
- Trash folder detection (by name "Trash")

#### 1.3 Error Handling
- Define `FileMoveError` enum:
  - `.crossProjectMove`
  - `.invalidSourceFolder`
  - `.invalidDestinationFolder`
  - `.fileNotFound`
  - `.folderNotFound`
  - `.nameConflict(suggestedName: String)`
- Localized error descriptions

**Deliverables**:
- ✅ TrashItem model added to BaseModels.swift
- ✅ FileMoveService implemented
- ✅ FileMoveError enum defined
- ✅ Unit tests: TrashItemTests.swift (~8 tests)
- ✅ Unit tests: FileMoveServiceTests.swift (~15 tests)

**Tests to write**:
1. TrashItem creation with original folder
2. TrashItem deletion when TextFile deleted
3. moveFile updates parentFolder
4. moveFile throws on cross-project move
5. moveFiles handles multiple files atomically
6. deleteFile creates TrashItem
7. deleteFiles creates multiple TrashItems
8. putBack restores to originalFolder
9. putBack uses Draft fallback when originalFolder deleted
10. validateMove catches all error cases
11. Name conflict detection
12. Trash folder identification

---

### Phase 2: File List Component (Days 4-5)
**Goal**: Build reusable file list with edit mode

#### 2.1 Create FileListView Component
- `FileListView.swift` in Views/Components/
- Props:
  - `files: [TextFile]` - Files to display
  - `folder: Folder?` - Current folder context (optional)
  - `onFileSelected: (TextFile) -> Void` - Tap action
  - `onMoveRequested: ([TextFile]) -> Void` - Move action
  - `onDeleteRequested: ([TextFile]) -> Void` - Delete action
- State:
  - `@State private var editMode: EditMode = .inactive`
  - `@State private var selectedFiles: Set<TextFile.ID> = []`
  - `@State private var showMoveSheet = false`
  - `@State private var showDeleteConfirm = false`

#### 2.2 Implement Edit Mode UI
- Edit button in toolbar (when folder != nil)
- Selection circles (empty/filled) on each row
- Tap behavior:
  - Normal mode → Opens file (`onFileSelected`)
  - Edit mode → Toggles selection
- Cancel button (exits edit mode)
- Auto-exit edit mode after action completes

#### 2.3 Implement Swipe Actions
- Available in normal mode only
- Leading swipe: None (keep simple)
- Trailing swipe:
  - "Move" button → Shows move sheet
  - "Delete" button (destructive) → Shows confirmation → **Moves to Trash**
- Disable swipe actions when editMode == .active

#### 2.4 Implement Toolbar Actions (Edit Mode)
- Bottom toolbar (iOS) or context toolbar (macOS)
- Visible only when selectedFiles.count > 0 **in edit mode**
- Buttons:
  - "Move X items" → Triggers `onMoveRequested` → Shows destination picker
  - "Delete X items" → Triggers `onDeleteRequested` → Confirmation → **Moves to Trash**
- Update counts dynamically
- **Important**: Delete NEVER permanently deletes - always moves to Trash
- Permanent deletion not in scope for 008a (Trash management is future feature)

**Deliverables**:
- ✅ FileListView component complete
- ✅ Edit mode functional (tap toggles selection)
- ✅ Swipe actions work in normal mode
- ✅ Toolbar shows correct counts
- ✅ Auto-exit edit mode after actions
- ✅ Delete actions move to Trash (never permanent delete)
- ✅ UI tests: FileListEditModeTests.swift (~10 tests)

**Tests to write**:
1. Edit button appears when folder provided
2. Tapping Edit enters edit mode
3. Tapping Cancel exits edit mode
4. Tapping file in normal mode calls onFileSelected
5. Tapping file in edit mode toggles selection
6. Swipe actions appear in normal mode
7. Swipe actions hidden in edit mode
8. Toolbar appears when files selected
9. Move button triggers onMoveRequested with selected files
10. Selection clears after action completes

---

### Phase 3: Move Destination Picker (Day 6)
**Goal**: Build folder selection sheet

#### 3.1 Create MoveDestinationPicker Component
- `MoveDestinationPicker.swift` in Views/Components/
- Sheet presentation
- Props:
  - `project: Project` - Current project
  - `currentFolder: Folder` - Folder to exclude
  - `filesToMove: [TextFile]` - Files being moved (for context)
  - `onDestinationSelected: (Folder) -> Void` - Callback
- List of valid destination folders:
  - Draft, Ready, Set Aside only
  - Exclude currentFolder
  - Exclude Trash (can't manually move to Trash)

#### 3.2 Implement Folder List UI
- List with folder names
- Folder icons (match existing UI)
- Tap to select → calls `onDestinationSelected`
- Cancel button dismisses sheet

#### 3.3 Integrate with FileListView
- Present sheet when showMoveSheet = true
- Pass selected files to picker
- On destination selected:
  - Call FileMoveService.moveFiles
  - Dismiss sheet
  - Exit edit mode
  - Show success message/toast

**Deliverables**:
- ✅ MoveDestinationPicker component complete
- ✅ Folder filtering logic correct
- ✅ Integration with FileListView working
- ✅ Success/error handling implemented

---

### Phase 4: Trash View & Put Back (Day 7)
**Goal**: Implement Trash folder view and restoration

#### 4.1 Create TrashView
- `TrashView.swift` in Views/Trash/
- Fetch all TrashItems for current project:
  ```swift
  @Query(filter: #Predicate<TrashItem> { item in
      item.project.id == projectID
  }, sort: \.deletedDate, order: .reverse)
  var trashItems: [TrashItem]
  ```
- List of trashed files
- Show "From: {folder name}" label for each
- Show deleted date
- Edit mode for multi-select
- Put Back button/action

#### 4.2 Implement Put Back Logic
- Single file Put Back (swipe action)
- Multiple file Put Back (edit mode toolbar)
- Call FileMoveService.putBack or putBackMultiple
- Handle fallback to Draft:
  - Show notification: "Restored to Draft (original folder not found)"
- Success feedback
- Remove TrashItem after restoration

#### 4.3 Integrate with Folder Sidebar
- Add "Trash" folder to sidebar
- Use distinct icon (trash can)
- Show count of trashed items (optional)
- Navigate to TrashView on tap

**Deliverables**:
- ✅ TrashView component complete
- ✅ Put Back single file working
- ✅ Put Back multiple files working
- ✅ Fallback to Draft with notification
- ✅ Integration with sidebar complete

---

### Phase 5: Integration & Polish (Day 8)
**Goal**: Connect all pieces and refine UX

#### 5.1 Update FolderDetailView
- Replace existing file list with FileListView component
- Pass callbacks:
  - `onFileSelected`: Navigate to FileEditView
  - `onMoveRequested`: Use FileMoveService
  - `onDeleteRequested`: Use FileMoveService + create TrashItems
- Handle errors from FileMoveService
- Show success messages

#### 5.2 Add Confirmation Dialogs
- Delete confirmation:
  - "Delete {count} files?"
  - "Delete" (destructive) / "Cancel"
- Error alerts for invalid moves
- Success toasts (optional, can be subtle)

#### 5.3 CloudKit Sync Testing
- Test file movement syncs across devices
- Test TrashItem creation syncs
- Test Put Back syncs
- Test offline queue (moves queued until online)
- Handle conflict resolution (last-write-wins)

**Deliverables**:
- ✅ FolderDetailView fully integrated
- ✅ All confirmations working
- ✅ CloudKit sync verified
- ✅ Integration tests: MovePutBackIntegrationTests.swift (~5 tests)

**Integration tests to write**:
1. Full move workflow: Select → Move → Verify in destination
2. Full delete workflow: Select → Delete → Verify in Trash → Put Back → Verify restored
3. CloudKit sync: Move on device 1 → Verify on device 2
4. Fallback to Draft when original folder deleted
5. Concurrent moves (conflict resolution)

---

### Phase 6: Mac Catalyst Enhancements (Day 9-10)
**Goal**: Optimize for macOS

#### 6.1 Cmd+Click Multi-Select (macOS only)
- Detect platform with `#if targetEnvironment(macCatalyst)`
- Enable Cmd+Click for multi-select without edit mode
- Maintain Edit button as alternative
- Test modifier key detection

#### 6.2 Right-Click Context Menu (macOS only)
- Add context menu to file rows:
  - "Open"
  - "Move To..." → Submenu with folders
  - "Delete" (destructive)
- Works on single file or selection
- Consistent with macOS conventions

#### 6.3 Drag & Drop (Future Enhancement - Optional)
- If time permits, add drag & drop:
  - Drag file to folder in sidebar
  - Uses FileMoveService same as other methods
- Otherwise, mark as future enhancement

**Deliverables**:
- ✅ Cmd+Click multi-select working on macOS
- ✅ Context menus functional on macOS
- ✅ Mac Catalyst tested and polished
- ⏸️ Drag & drop deferred to future (optional)

---

### Phase 7: Testing & Documentation (Day 11-12)
**Goal**: Comprehensive testing and user-facing docs

#### 7.1 Unit Test Coverage
- Achieve 90%+ coverage for:
  - FileMoveService
  - TrashItem model
  - FileListView logic
- Edge cases:
  - Name conflicts
  - Deleted folders
  - Concurrent operations
  - Very large selections (100+ files)

#### 7.2 UI Test Coverage
- Smoke tests for:
  - Edit mode activation
  - File selection
  - Move workflow
  - Delete workflow
  - Put Back workflow
  - Swipe actions
- Test on iOS and macOS

#### 7.3 Manual Testing Checklist
- Test all user stories from spec.md
- Test edge cases:
  - Move file that doesn't exist
  - Move to current folder
  - Name conflicts
  - Very full Trash (1000+ items)
  - Offline operations
- Performance testing with large projects

#### 7.4 Create quickstart.md
- User-facing guide:
  - How to move files
  - How to use edit mode
  - How to use Trash and Put Back
  - Screenshots/GIFs

**Deliverables**:
- ✅ 90%+ unit test coverage
- ✅ All UI tests passing
- ✅ Manual testing complete (checklist filled)
- ✅ quickstart.md written
- ✅ All acceptance criteria from spec.md verified

---

## Timeline Summary

| Phase | Duration | Cumulative | Focus |
|-------|----------|------------|-------|
| 0. Research & Planning | 1 day | Day 1 | iOS patterns, CloudKit strategy |
| 1. Data Model & Service | 2 days | Days 2-3 | TrashItem, FileMoveService, tests |
| 2. File List Component | 2 days | Days 4-5 | Edit mode, swipe actions, toolbar |
| 3. Move Destination Picker | 1 day | Day 6 | Folder selection UI |
| 4. Trash View & Put Back | 1 day | Day 7 | TrashView, restoration logic |
| 5. Integration & Polish | 1 day | Day 8 | Connect pieces, CloudKit testing |
| 6. Mac Catalyst | 2 days | Days 9-10 | Cmd+Click, context menus |
| 7. Testing & Documentation | 2 days | Days 11-12 | Comprehensive testing, docs |
| **Total** | **12 days** | | **~2.5 weeks** |

*Note: Timeline assumes full-time development. Adjust for part-time or interrupted work.*

---

## Key Files to Create/Modify

### New Files (8 total)

**Models**:
- None (TrashItem added to existing BaseModels.swift)

**Services**:
- `Services/FileMoveService.swift` (~200 lines)

**Views**:
- `Views/Components/FileListView.swift` (~300 lines)
- `Views/Components/MoveDestinationPicker.swift` (~100 lines)
- `Views/Trash/TrashView.swift` (~150 lines)

**Extensions**:
- `Extensions/Collection+Extensions.swift` (~50 lines) - optional helpers

**Tests**:
- `WritingShedProTests/FileMoveServiceTests.swift` (~15 tests, ~300 lines)
- `WritingShedProTests/TrashItemTests.swift` (~8 tests, ~150 lines)
- `WritingShedProTests/FileListEditModeTests.swift` (~10 tests, ~200 lines)
- `WritingShedProTests/MovePutBackIntegrationTests.swift` (~5 tests, ~150 lines)

### Modified Files (2 total)

- `Models/BaseModels.swift` (~50 lines added for TrashItem model)
- `Views/FolderDetailView.swift` (~100 lines changed to use FileListView)

**Total New Code**: ~1,450 lines  
**Total Modified Code**: ~150 lines

---

## Risk Assessment

### High Risk

1. **Edit Mode Complexity with SwiftUI List**
   - **Risk**: SwiftUI List selection binding can be finicky, especially with EditMode state
   - **Mitigation**: 
     - Follow Apple's List selection examples closely
     - Test thoroughly on iOS 18.5+
     - Use @State properly for editMode binding
     - Handle edge cases (empty selections, all selected)
   - **Fallback**: Use ForEach with custom row views if List selection fails

2. **CloudKit Sync Reliability**
   - **Risk**: TrashItem relationships might not sync correctly, especially originalFolder reference
   - **Mitigation**:
     - Test relationship sync extensively
     - Verify SwiftData @Model CloudKit integration
     - Handle orphaned TrashItems (originalFolder deleted on another device)
     - Add sync validation logic
   - **Fallback**: Store originalFolderName as String instead of relationship if needed

3. **Performance with Large Trash**
   - **Risk**: Trash with 1000+ items could be slow to load/render
   - **Mitigation**:
     - Use SwiftData @Query with pagination if needed
     - Lazy loading in List
     - Add "Empty Trash" feature for cleanup (future)
     - Test with large datasets early
   - **Fallback**: Limit Trash display to recent 100 items, with "Show More" button

### Medium Risk

1. **Name Conflicts on Move**
   - **Risk**: Moving file to folder with same-named file causes conflict
   - **Mitigation**:
     - Auto-rename with (2), (3), etc. suffix (iOS standard)
     - Validate before move
     - Show warning to user
   - **Fallback**: Prompt user to rename manually

2. **Swipe Actions Conflicting with Edit Mode**
   - **Risk**: Swipe gestures might interfere with edit mode selection
   - **Mitigation**:
     - Disable swipe actions when editMode == .active (iOS standard)
     - Test thoroughly on device (not just simulator)
     - Follow Apple's patterns from Mail/Files apps
   - **Fallback**: Remove swipe actions entirely, rely on edit mode only

3. **Mac Catalyst Differences**
   - **Risk**: Edit mode UI behaves differently on macOS
   - **Mitigation**:
     - Test on Mac early (Phase 6)
     - Provide macOS-specific alternatives (Cmd+Click, context menu)
     - Use platform checks `#if targetEnvironment(macCatalyst)`
   - **Fallback**: Different UI for macOS if needed

### Low Risk

1. **Offline Operation Queueing**
   - **Risk**: Moves performed offline might not sync correctly
   - **Mitigation**:
     - SwiftData handles this automatically with CloudKit
     - Test offline → online transitions
     - Verify queue flushing
   - **Fallback**: Block operations when offline (show error)

2. **Put Back Fallback to Draft**
   - **Risk**: Users might not notice notification about Draft fallback
   - **Mitigation**:
     - Clear notification message
     - Visual highlight in UI (e.g., badge on restored file)
     - Log for debugging
   - **Fallback**: Always ask user where to restore if originalFolder missing

---

## Success Criteria

### Functional (from spec.md)
- ✅ Users can move single file in under 3 taps (swipe → Move → destination)
- ✅ Users can move 10 files together in under 10 seconds (Edit → select → Move)
- ✅ Put Back succeeds for 95%+ of files (restored to original folder)
- ✅ Edit mode clearly distinguishes selected vs unselected files
- ✅ File moves sync across devices within 5 seconds
- ✅ Zero data loss during move operations
- ✅ Selection state is obvious (user never confused about what's selected)

### Technical
- ✅ 90%+ unit test coverage for FileMoveService and TrashItem
- ✅ All 38 acceptance scenarios from spec.md pass
- ✅ CloudKit sync verified with two-device testing
- ✅ Performance: Handles 100+ file selections smoothly (60fps)
- ✅ Performance: Trash with 500 items loads in < 1 second
- ✅ Mac Catalyst: Cmd+Click and context menus work

### User Experience
- ✅ Edit mode behaves like iOS Mail/Files apps (familiar pattern)
- ✅ Swipe actions are discoverable and responsive
- ✅ Error messages are clear and actionable
- ✅ Confirmation dialogs prevent accidental deletions
- ✅ Put Back is obvious and reliable
- ✅ No crashes or data corruption under any tested scenario

---

## Open Questions

### Before Starting Phase 0:
1. ❓ Should we show Trash count badge in sidebar? (Like macOS Trash)
   - **Research**: Check iOS Files app, Mail app patterns
   - **Decision needed by**: Day 1 (Phase 0)

2. ❓ Should Trash auto-delete items after 30 days? (Like macOS)
   - **Impact**: Adds complexity (background task, notifications)
   - **Decision**: Defer to future feature (keep simple for 008a)
   - **Document in**: Out of Scope

### Before Starting Phase 1:
3. ❓ Name conflict strategy: Auto-rename or prompt user?
   - **Research**: Check iOS Files app behavior
   - **Decision needed by**: Day 2 (Phase 1)
   - **Recommendation**: Auto-rename (less friction)

### Before Starting Phase 4:
4. ❓ Empty Trash feature needed now or later?
   - **Impact**: Permanent deletion requires careful UX (confirmation, etc.)
   - **Decision**: Defer to future feature (just Put Back for 008a)
   - **Document in**: Out of Scope

---

## Dependencies

### Internal (WritingShedPro)
- ✅ Feature 001: Project model (exists)
- ✅ Feature 002: Folder structure (exists)
- ✅ Feature 003: TextFile model (exists)
- ⚠️ Feature 004: Undo/redo system (exists, may need updates)
  - **Question**: Should file moves be undoable?
  - **Decision**: No - file moves are permanent (like iOS Files app)

### External (Apple Frameworks)
- ✅ SwiftUI (iOS 18.5+, macOS 14+)
- ✅ SwiftData (for models and relationships)
- ✅ CloudKit (for sync)
- ✅ UIKit (for UITextView wrapper if needed - unlikely for this feature)

### Blockers
- **None** - Can start immediately

---

## Phase 0 Deliverables (Next Steps)

When moving to Phase 0 (Research & Planning), create:

1. **research.md** - iOS edit mode patterns, CloudKit sync strategy
2. **data-model.md** - TrashItem model detailed design, relationships diagram
3. **contracts/** - API contracts for FileMoveService methods
4. **quickstart.md** - User guide (defer to Phase 7, but stub now)

Use `/speckit.plan` workflow to generate these files.

---

**Status**: 📋 Ready to Begin Phase 0  
**Next Action**: Start research on iOS edit mode patterns and CloudKit relationship sync  
**Estimated Completion**: ~12 days (2.5 weeks) from start of Phase 1
