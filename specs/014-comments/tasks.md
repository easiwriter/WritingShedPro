# Feature 014: Comments - Task Breakdown

## Phase 1: Data Model & Manager (3 hours)

### Task 1.1: Create CommentModel Entity (45 min)
**Priority**: Critical  
**Dependencies**: None

**Steps**:
1. Create `Models/CommentModel.swift`
2. Define CommentModel class with all properties
3. Add to ModelContainer schema in app initialization
4. Build and verify compilation

**Files**:
- `NEW: Models/CommentModel.swift`
- `EDIT: WritingShedProApp.swift` (add to schema)

**Acceptance**:
- [ ] CommentModel compiles without errors
- [ ] Schema includes CommentModel
- [ ] App launches successfully

---

### Task 1.2: Create CommentManager (1 hour)
**Priority**: Critical  
**Dependencies**: Task 1.1

**Steps**:
1. Create `Managers/CommentManager.swift`
2. Implement singleton pattern
3. Add CRUD operation methods
4. Add position update logic
5. Add query methods

**Files**:
- `NEW: Managers/CommentManager.swift`

**Acceptance**:
- [ ] Manager is accessible as singleton
- [ ] All CRUD methods compile
- [ ] Query methods return correct types

---

### Task 1.3: Write Manager Unit Tests (1 hour)
**Priority**: High  
**Dependencies**: Task 1.2

**Steps**:
1. Create `WritingShedProTests/CommentManagerTests.swift`
2. Test comment creation
3. Test comment updates
4. Test deletion
5. Test position updates
6. Test queries

**Files**:
- `NEW: WritingShedProTests/CommentManagerTests.swift`

**Tests**:
```swift
func testCreateComment()
func testUpdateComment()
func testDeleteComment()
func testResolveComment()
func testFetchCommentsByFile()
func testPositionUpdateOnInsert()
func testPositionUpdateOnDelete()
func testDeleteCommentInDeletedText()
```

**Acceptance**:
- [ ] All tests pass
- [ ] Code coverage >80%

---

### Task 1.4: Test Database Persistence (15 min)
**Priority**: Medium  
**Dependencies**: Task 1.2

**Steps**:
1. Launch app
2. Create comment via manager
3. Force quit app
4. Relaunch and verify comment persists

**Acceptance**:
- [ ] Comments survive app restart
- [ ] No database errors in console

---

## Phase 2: Comment Attachment (3 hours)

### Task 2.1: Create CommentAttachment Class (1 hour)
**Priority**: Critical  
**Dependencies**: Task 1.1

**Steps**:
1. Create `Views/Comments/CommentAttachment.swift`
2. Subclass NSTextAttachment
3. Store commentID and isResolved
4. Implement init methods
5. Add NSCoding support

**Files**:
- `NEW: Views/Comments/CommentAttachment.swift`

**Acceptance**:
- [ ] Class compiles
- [ ] Can create instance with commentID
- [ ] NSCoding encode/decode works

---

### Task 2.2: Implement Custom Rendering (1.5 hours)
**Priority**: Critical  
**Dependencies**: Task 2.1

**Steps**:
1. Override `image(forBounds:textContainer:characterIndex:)` method
2. Use SF Symbol for speech bubble
3. Apply color based on resolved state
4. Test at different sizes
5. Test in light/dark mode

**Files**:
- `EDIT: Views/Comments/CommentAttachment.swift`

**Acceptance**:
- [ ] Comment indicator renders inline
- [ ] Active comments show blue
- [ ] Resolved comments show gray
- [ ] Looks good in both themes

---

### Task 2.3: Test Attachment in Text (30 min)
**Priority**: High  
**Dependencies**: Task 2.2

**Steps**:
1. Create test view/playground
2. Insert CommentAttachment into NSAttributedString
3. Display in UITextView
4. Verify rendering
5. Test at different zoom levels

**Acceptance**:
- [ ] Attachment appears in text flow
- [ ] No layout glitches
- [ ] Scales with zoom

---

## Phase 3: Comment Insertion UI (4 hours)

### Task 3.1: Add Toolbar Button (30 min)
**Priority**: Critical  
**Dependencies**: None

**Steps**:
1. Edit `Views/PaginatedDocumentView.swift`
2. Add "Add Comment" button to toolbar
3. Add keyboard shortcut (⌘⇧C)
4. Add state variable for sheet
5. Disable when no text selection

**Files**:
- `EDIT: Views/PaginatedDocumentView.swift`

**Acceptance**:
- [ ] Button appears in toolbar
- [ ] Keyboard shortcut works
- [ ] Button disabled appropriately

---

### Task 3.2: Create Add Comment Sheet (1 hour)
**Priority**: Critical  
**Dependencies**: None

**Steps**:
1. Create `Views/Comments/AddCommentSheet.swift`
2. Add TextEditor for comment input
3. Add Cancel/Add buttons
4. Handle empty text validation
5. Style appropriately for platform

**Files**:
- `NEW: Views/Comments/AddCommentSheet.swift`

**Acceptance**:
- [ ] Sheet displays on button click
- [ ] TextEditor accepts input
- [ ] Add button disabled when empty
- [ ] Cancel dismisses sheet

---

### Task 3.3: Implement Insertion Logic (1.5 hours)
**Priority**: Critical  
**Dependencies**: Task 1.2, 2.1, 3.2

**Steps**:
1. Edit `TextEditingCoordinator.swift`
2. Add `insertComment(text:)` method
3. Get current cursor position
4. Create CommentModel in database
5. Create CommentAttachment
6. Insert into NSAttributedString
7. Update cursor position

**Files**:
- `EDIT: Coordinators/TextEditingCoordinator.swift`

**Acceptance**:
- [ ] Comment inserted at cursor
- [ ] Attachment visible in text
- [ ] Database record created
- [ ] Cursor moves after attachment

---

### Task 3.4: Implement Undo/Redo (1 hour)
**Priority**: High  
**Dependencies**: Task 3.3

**Steps**:
1. Register undo operation in `insertComment`
2. Implement `removeComment` for undo
3. Test undo removes comment
4. Test redo restores comment
5. Handle database sync

**Files**:
- `EDIT: Coordinators/TextEditingCoordinator.swift`

**Acceptance**:
- [ ] Undo removes comment and attachment
- [ ] Redo restores both
- [ ] Database stays in sync
- [ ] No crashes on multiple undo/redo

---

## Phase 4: Comment Display (4 hours)

### Task 4.1: Create CommentPopoverView (1.5 hours)
**Priority**: Critical  
**Dependencies**: Task 1.1

**Steps**:
1. Create `Views/Comments/CommentPopoverView.swift`
2. Design layout (header, content, actions)
3. Add edit mode toggle
4. Add resolve/delete buttons
5. Style for 300pt width

**Files**:
- `NEW: Views/Comments/CommentPopoverView.swift`

**Acceptance**:
- [ ] View compiles and displays
- [ ] Layout looks good
- [ ] All buttons present
- [ ] Matches design mockup

---

### Task 4.2: Implement Tap Detection (1 hour)
**Priority**: Critical  
**Dependencies**: Task 2.1

**Steps**:
1. Edit `TextEditingCoordinator.swift`
2. Implement `textView(_:shouldInteractWith:...)` delegate
3. Check if attachment is CommentAttachment
4. Extract commentID
5. Fetch comment from database

**Files**:
- `EDIT: Coordinators/TextEditingCoordinator.swift`

**Acceptance**:
- [ ] Tapping comment triggers delegate
- [ ] CommentAttachment detected correctly
- [ ] Comment fetched from database
- [ ] Handles missing comment gracefully

---

### Task 4.3: Show Popover (macOS) (45 min)
**Priority**: High  
**Dependencies**: Task 4.1, 4.2

**Steps**:
1. Create NSPopover presentation logic
2. Anchor to attachment location
3. Handle dismiss on outside click
4. Handle Esc key dismiss

**Files**:
- `EDIT: Coordinators/TextEditingCoordinator.swift`

**Acceptance**:
- [ ] Popover appears anchored to comment
- [ ] Arrow points to attachment
- [ ] Dismisses on outside click
- [ ] Esc key works

---

### Task 4.4: Show Sheet/Popover (iOS) (45 min)
**Priority**: High  
**Dependencies**: Task 4.1, 4.2

**Steps**:
1. Use sheet for compact size class
2. Use popover for regular size class
3. Handle swipe-to-dismiss
4. Test on iPhone and iPad

**Files**:
- `EDIT: Coordinators/TextEditingCoordinator.swift`
- `EDIT: Views/PaginatedDocumentView.swift`

**Acceptance**:
- [ ] Sheet on iPhone
- [ ] Popover on iPad
- [ ] Both dismiss correctly
- [ ] Content visible in both

---

## Phase 5: Comment Editing & Actions (3 hours)

### Task 5.1: Implement Edit Mode (1 hour)
**Priority**: High  
**Dependencies**: Task 4.1

**Steps**:
1. Edit `CommentPopoverView.swift`
2. Add edit state toggle
3. Show TextEditor when editing
4. Implement Save/Cancel
5. Update comment in database

**Files**:
- `EDIT: Views/Comments/CommentPopoverView.swift`

**Acceptance**:
- [ ] Edit button shows editor
- [ ] Text editable in editor
- [ ] Save updates database
- [ ] Cancel discards changes

---

### Task 5.2: Implement Resolve/Unresolve (45 min)
**Priority**: High  
**Dependencies**: Task 4.1

**Steps**:
1. Add resolve button handler
2. Call CommentManager.resolveComment
3. Update attachment appearance
4. Refresh text view
5. Test toggle

**Files**:
- `EDIT: Views/Comments/CommentPopoverView.swift`
- `EDIT: Coordinators/TextEditingCoordinator.swift`

**Acceptance**:
- [ ] Resolve button works
- [ ] Unresolve button works
- [ ] Attachment turns gray when resolved
- [ ] Attachment turns blue when unresolved

---

### Task 5.3: Implement Delete with Confirmation (45 min)
**Priority**: High  
**Dependencies**: Task 4.1

**Steps**:
1. Add delete button handler
2. Show confirmation alert
3. Delete from database
4. Remove attachment from text
5. Dismiss popover

**Files**:
- `EDIT: Views/Comments/CommentPopoverView.swift`
- `EDIT: Coordinators/TextEditingCoordinator.swift`

**Acceptance**:
- [ ] Confirmation alert appears
- [ ] Cancel keeps comment
- [ ] Delete removes comment and attachment
- [ ] No crashes

---

### Task 5.4: Update Attachment Appearance (30 min)
**Priority**: Medium  
**Dependencies**: Task 5.2

**Steps**:
1. Add method to refresh attachment
2. Find attachment in text storage
3. Update isResolved property
4. Trigger re-render
5. Test visual update

**Files**:
- `EDIT: Coordinators/TextEditingCoordinator.swift`

**Acceptance**:
- [ ] Attachment updates immediately
- [ ] No need to close/reopen popover
- [ ] Works for resolve and unresolve

---

## Phase 6: Position Management (3 hours)

### Task 6.1: Hook Text Editing Notifications (45 min)
**Priority**: Critical  
**Dependencies**: Task 1.2

**Steps**:
1. Edit `TextEditingCoordinator.swift`
2. Implement `textStorage(_:didProcessEditing:...)` delegate
3. Check for character edits
4. Extract edit range and delta
5. Call CommentManager.updatePositions

**Files**:
- `EDIT: Coordinators/TextEditingCoordinator.swift`

**Acceptance**:
- [ ] Delegate called on edits
- [ ] Character edits detected
- [ ] Correct range and delta extracted

---

### Task 6.2: Test Insert Before Comment (30 min)
**Priority**: High  
**Dependencies**: Task 6.1

**Steps**:
1. Create comment at position 100
2. Insert text at position 50
3. Verify comment position unchanged
4. Insert text at position 100
5. Verify comment shifts right

**Acceptance**:
- [ ] Position correct after insert before
- [ ] Position updates after insert at same location

---

### Task 6.3: Test Delete Around Comment (30 min)
**Priority**: High  
**Dependencies**: Task 6.1

**Steps**:
1. Create comment at position 100
2. Delete text before (range 50-60)
3. Verify comment shifts left
4. Delete text including comment (range 95-105)
5. Verify comment deleted from database

**Acceptance**:
- [ ] Position shifts on delete before
- [ ] Comment removed when deleted

---

### Task 6.4: Test Undo/Redo Position Tracking (45 min)
**Priority**: High  
**Dependencies**: Task 6.1, 3.4

**Steps**:
1. Insert comment at 100
2. Insert text at 50
3. Undo text insertion
4. Verify comment position back to 100
5. Redo text insertion
6. Verify comment position 110

**Acceptance**:
- [ ] Positions track through undo
- [ ] Positions track through redo
- [ ] No duplicate comments
- [ ] No orphaned positions

---

### Task 6.5: Add Position Validation (30 min)
**Priority**: Medium  
**Dependencies**: Task 6.1

**Steps**:
1. Add validation method to CommentManager
2. Check all comment positions on file load
3. Remove comments with invalid positions
4. Log warnings for debugging
5. Add to file opening flow

**Files**:
- `EDIT: Managers/CommentManager.swift`
- `EDIT: Views/PaginatedDocumentView.swift`

**Acceptance**:
- [ ] Invalid positions detected
- [ ] Orphaned comments removed
- [ ] Warnings logged
- [ ] File still opens successfully

---

## Phase 7: Comments List Sidebar (Optional - 4 hours)

### Task 7.1: Create CommentsListView (2 hours)
**Priority**: Low  
**Dependencies**: Task 1.2

**Steps**:
1. Create `Views/Comments/CommentsListView.swift`
2. Add @Query for comments
3. Implement list with rows
4. Add filter picker (all/active/resolved)
5. Add badge count

**Files**:
- `NEW: Views/Comments/CommentsListView.swift`

**Acceptance**:
- [ ] List shows all comments
- [ ] Filter works
- [ ] Badge shows count
- [ ] List updates on changes

---

### Task 7.2: Implement Jump to Comment (1 hour)
**Priority**: Low  
**Dependencies**: Task 7.1

**Steps**:
1. Add tap handler on row
2. Calculate scroll position
3. Scroll to comment position
4. Optionally highlight briefly

**Files**:
- `EDIT: Views/Comments/CommentsListView.swift`
- `EDIT: Views/PaginatedDocumentView.swift`

**Acceptance**:
- [ ] Tapping row scrolls to comment
- [ ] Correct page shown
- [ ] Comment visible on screen

---

### Task 7.3: Integrate Sidebar (1 hour)
**Priority**: Low  
**Dependencies**: Task 7.1

**Steps**:
1. Add sidebar toggle to toolbar
2. Show/hide CommentsListView
3. Test on macOS and iPad
4. Handle narrow screens

**Files**:
- `EDIT: Views/PaginatedDocumentView.swift`

**Acceptance**:
- [ ] Sidebar toggles
- [ ] Layout adapts
- [ ] Works on all platforms

---

## Phase 8: Threading Support (Optional - 3 hours)

### Task 8.1: Update Data Model for Threads (45 min)
**Priority**: Low  
**Dependencies**: Task 1.1

**Steps**:
1. Ensure parentCommentID and threadID in model
2. Add thread query methods to manager
3. Test thread relationships

**Files**:
- `EDIT: Models/CommentModel.swift`
- `EDIT: Managers/CommentManager.swift`

**Acceptance**:
- [ ] Thread fields present
- [ ] Queries return threads correctly

---

### Task 8.2: Add Reply UI (1.5 hours)
**Priority**: Low  
**Dependencies**: Task 8.1, 4.1

**Steps**:
1. Add "Reply" button to CommentPopoverView
2. Show reply input sheet
3. Create reply comment
4. Link to parent
5. Display in thread

**Files**:
- `EDIT: Views/Comments/CommentPopoverView.swift`
- `NEW: Views/Comments/CommentThreadView.swift`

**Acceptance**:
- [ ] Reply button works
- [ ] Reply created with correct parent
- [ ] Replies shown under parent

---

### Task 8.3: Implement Thread Display (45 min)
**Priority**: Low  
**Dependencies**: Task 8.2

**Steps**:
1. Create CommentThreadView
2. Show parent and replies
3. Add collapse/expand
4. Style with indentation

**Files**:
- `EDIT: Views/Comments/CommentThreadView.swift`

**Acceptance**:
- [ ] Thread displays correctly
- [ ] Collapse/expand works
- [ ] Visual hierarchy clear

---

## Testing Phase (Ongoing)

### Manual Testing Checklist

**Phase 1-2 Testing**:
- [ ] Create comment
- [ ] View comment in database tool
- [ ] Comment persists after restart
- [ ] Attachment renders correctly

**Phase 3-4 Testing**:
- [ ] Add comment via toolbar
- [ ] Add comment via keyboard shortcut
- [ ] Tap comment shows popover
- [ ] Popover displays content

**Phase 5 Testing**:
- [ ] Edit comment text
- [ ] Resolve comment
- [ ] Unresolve comment
- [ ] Delete comment
- [ ] Visual updates work

**Phase 6 Testing**:
- [ ] Insert text before comment
- [ ] Insert text after comment
- [ ] Delete text with comment
- [ ] Undo comment insertion
- [ ] Redo comment insertion
- [ ] Complex edit sequences

**Cross-Platform Testing**:
- [ ] Test on macOS
- [ ] Test on iPhone
- [ ] Test on iPad
- [ ] Test in light mode
- [ ] Test in dark mode

**Zoom Testing**:
- [ ] Comments visible at 50% zoom
- [ ] Comments visible at 100% zoom
- [ ] Comments visible at 200% zoom
- [ ] No layout issues

---

## Time Estimates Summary

| Phase | Hours | Priority |
|-------|-------|----------|
| Phase 1: Data Model | 3 | Critical |
| Phase 2: Attachment | 3 | Critical |
| Phase 3: Insertion UI | 4 | Critical |
| Phase 4: Display | 4 | Critical |
| Phase 5: Editing | 3 | High |
| Phase 6: Positions | 3 | Critical |
| **MVP Total** | **20** | - |
| Phase 7: Sidebar | 4 | Optional |
| Phase 8: Threading | 3 | Optional |
| **Full Total** | **27** | - |

---

## Dependencies Graph

```
Phase 1 (Data Model)
    └─> Phase 2 (Attachment)
            └─> Phase 3 (Insertion)
                    └─> Phase 4 (Display)
                            ├─> Phase 5 (Editing)
                            └─> Phase 6 (Positions)
                                    └─> Phase 7 (Sidebar)
                                            └─> Phase 8 (Threading)
```

---

## Risk Mitigation

**High Risk Tasks**:
- Task 3.4: Undo/Redo (complex integration)
- Task 6.4: Position tracking with undo/redo
- Task 4.3/4.4: Platform-specific presentation

**Mitigation**:
- Allocate extra buffer time
- Test incrementally
- Have fallback plans (skip undo for v1 if needed)
- Accept platform differences

---

## Definition of Done

Each task is complete when:
- [ ] Code written and compiles
- [ ] Unit tests pass (if applicable)
- [ ] Manual testing confirms functionality
- [ ] Code reviewed (self or peer)
- [ ] Committed to version control
- [ ] Documentation updated (if needed)

---

## Next Steps

1. Review this task breakdown
2. Confirm priorities and time estimates
3. Start with Phase 1, Task 1.1
4. Work sequentially through phases
5. Test after each phase before proceeding
6. Ship MVP after Phase 6
7. Evaluate user feedback before optional phases
