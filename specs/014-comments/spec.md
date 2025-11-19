# Feature 014: Comments System

**Status**: Planning  
**Priority**: High  
**Estimated Effort**: 18-21 hours (2-3 days)  
**Dependencies**: Feature 005 (Text Formatting), Feature 010 (Pagination)  
**Platform**: iOS 16+, macOS 13+

---

## Overview

Implement a robust commenting system for text documents using TextKit 1 with custom NSTextAttachment. Comments appear as inline indicators in the text flow, with full comment content displayed in a popover. Supports creation, editing, deletion, and resolution of comments.

### User Value

- **Collaborative Review**: Add feedback without modifying original text
- **Self-Review**: Leave notes for future revisions
- **Track Decisions**: Document why certain choices were made
- **Threaded Discussions**: Optional reply chains for complex feedback

---

## Technical Approach

### Architecture: Custom Text Attachments

Comments are implemented as **custom NSTextAttachment** objects that:
1. Render as small inline indicators (speech bubble icon)
2. Store reference to comment metadata (UUID)
3. Integrate seamlessly with TextKit 1 text layout
4. Preserve positions through undo/redo operations
5. Support export/import with document data

### Why TextKit 1 (Not TextKit 2)

**Decision Rationale**:
- TextKit 1 is proven, stable, and performant
- TextKit 2 migration encountered severe issues (memory leaks, complexity)
- Comments don't require TextKit 2 features
- Lower risk, faster delivery
- See `COMMENTS_WITHOUT_TEXTKIT2.md` for full analysis

---

## User Interface

### Comment Indicator

**Visual Design**:
- Small speech bubble icon (💬 style)
- 16x16pt at 100% zoom, scales with zoom level
- Color coding:
  - Blue: Active comment
  - Gray: Resolved comment
- Tappable/clickable to open comment
- Inline with text flow (zero-width attachment)

**Placement**:
- Inserted at current cursor position
- Appears between characters (not replacing text)
- Follows text if surrounding content edited

### Comment Popover

**Desktop (macOS)**:
- Popover anchored to comment indicator
- 300pt wide, auto height
- Arrow points to indicator
- Closes on outside click or Esc key

**Mobile (iOS)**:
- Sheet from bottom (compact)
- Popover on iPad (regular width)
- Swipe down to dismiss

**Content Structure**:
```
┌─────────────────────────────┐
│ [Author] • [Time]      [×]  │
├─────────────────────────────┤
│ Comment text content...     │
│ (multiple lines)            │
│                             │
├─────────────────────────────┤
│ [Reply] [Resolve] [Delete]  │
└─────────────────────────────┘
```

### Toolbar Integration

**New Button**: "Add Comment" 
- Icon: Speech bubble (SF Symbol: `bubble.left`)
- Keyboard shortcut: `⌘⇧C` (macOS), hidden on iOS
- Enabled only when document has text selection or cursor
- Disabled in read-only mode

**Menu Integration**:
- Insert > Add Comment
- Right-click context menu: "Add Comment"

### Comments List (Sidebar)

**Optional Phase 2**:
- Show all comments for current file
- Filter: All / Active / Resolved
- Sort: Position / Date / Author
- Click to jump to comment location
- Badge count showing total comments

---

## Data Model

### CommentModel (SwiftData)

```swift
@Model
final class CommentModel {
    // Identity
    @Attribute(.unique) var id: UUID
    var textFileID: UUID  // Foreign key to TextFile
    
    // Position tracking
    var characterPosition: Int  // Offset in NSAttributedString
    var attachmentID: UUID  // Links to NSTextAttachment
    
    // Content
    var text: String
    var author: String  // User's name or "Me"
    
    // Metadata
    var createdAt: Date
    var modifiedAt: Date?
    var resolvedAt: Date?  // nil = active, non-nil = resolved
    
    // Threading (optional Phase 7)
    var parentCommentID: UUID?  // nil = root comment
    var threadID: UUID  // Groups replies together
    
    // Computed
    var isResolved: Bool {
        resolvedAt != nil
    }
    
    var isReply: Bool {
        parentCommentID != nil
    }
    
    init(
        textFileID: UUID,
        characterPosition: Int,
        text: String,
        author: String = "Me"
    ) {
        self.id = UUID()
        self.textFileID = textFileID
        self.characterPosition = characterPosition
        self.attachmentID = UUID()
        self.text = text
        self.author = author
        self.createdAt = Date()
        self.threadID = UUID()
    }
}
```

### Database Schema Changes

**ModelContainer Update**:
```swift
// In WritingShedProApp.swift or similar
var modelContainer: ModelContainer = {
    let schema = Schema([
        Project.self,
        TextFile.self,
        CommentModel.self  // ADD THIS
    ])
    // ... rest of configuration
}()
```

**Migration**: None required (new entity, no existing data)

---

## Implementation Components

### 1. CommentAttachment.swift

Custom NSTextAttachment that renders comment indicator.

```swift
final class CommentAttachment: NSTextAttachment {
    let commentID: UUID
    let isResolved: Bool
    
    init(commentID: UUID, isResolved: Bool = false) {
        self.commentID = commentID
        self.isResolved = isResolved
        super.init(data: nil, ofType: nil)
        
        // Set fixed size (will be scaled by zoom)
        self.bounds = CGRect(x: 0, y: -2, width: 16, height: 16)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Custom drawing
    override func image(
        forBounds imageBounds: CGRect,
        textContainer: NSTextContainer?,
        characterIndex: Int
    ) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: imageBounds)
        return renderer.image { context in
            // Draw speech bubble icon
            let color = isResolved ? UIColor.systemGray : UIColor.systemBlue
            color.setFill()
            
            // Simple circle with tail (speech bubble)
            let path = UIBezierPath(
                roundedRect: imageBounds.insetBy(dx: 1, dy: 1),
                cornerRadius: 3
            )
            path.fill()
        }
    }
}
```

**Alternative**: Use SF Symbol image instead of custom drawing:
```swift
override func image(
    forBounds imageBounds: CGRect,
    textContainer: NSTextContainer?,
    characterIndex: Int
) -> UIImage? {
    let config = UIImage.SymbolConfiguration(pointSize: 14)
    let image = UIImage(systemName: "bubble.left.fill", withConfiguration: config)
    return image?.withTintColor(
        isResolved ? .systemGray : .systemBlue,
        renderingMode: .alwaysOriginal
    )
}
```

### 2. CommentManager.swift

Singleton manager for comment operations.

```swift
@MainActor
final class CommentManager: ObservableObject {
    static let shared = CommentManager()
    
    @Published var activeCommentID: UUID?  // Currently viewing
    
    private init() {}
    
    // MARK: - CRUD Operations
    
    func createComment(
        in file: TextFile,
        at position: Int,
        text: String,
        context: ModelContext
    ) -> CommentModel {
        let comment = CommentModel(
            textFileID: file.id,
            characterPosition: position,
            text: text
        )
        context.insert(comment)
        return comment
    }
    
    func updateComment(
        _ comment: CommentModel,
        text: String,
        context: ModelContext
    ) {
        comment.text = text
        comment.modifiedAt = Date()
    }
    
    func resolveComment(
        _ comment: CommentModel,
        context: ModelContext
    ) {
        comment.resolvedAt = Date()
    }
    
    func unresolveComment(
        _ comment: CommentModel,
        context: ModelContext
    ) {
        comment.resolvedAt = nil
    }
    
    func deleteComment(
        _ comment: CommentModel,
        context: ModelContext
    ) {
        context.delete(comment)
    }
    
    // MARK: - Queries
    
    func fetchComments(
        for fileID: UUID,
        context: ModelContext
    ) -> [CommentModel] {
        let descriptor = FetchDescriptor<CommentModel>(
            predicate: #Predicate { $0.textFileID == fileID },
            sortBy: [SortDescriptor(\.characterPosition)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func fetchComment(
        byID id: UUID,
        context: ModelContext
    ) -> CommentModel? {
        let descriptor = FetchDescriptor<CommentModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }
    
    // MARK: - Position Management
    
    func updatePositions(
        for fileID: UUID,
        afterEdit range: NSRange,
        changeInLength delta: Int,
        context: ModelContext
    ) {
        let comments = fetchComments(for: fileID, context: context)
        
        for comment in comments {
            // If comment is after edit, adjust position
            if comment.characterPosition >= range.location + range.length {
                comment.characterPosition += delta
            }
            // If comment is within deleted range, mark for review
            else if delta < 0 && 
                    comment.characterPosition >= range.location &&
                    comment.characterPosition < range.location + range.length {
                // Comment was in deleted text - remove it
                context.delete(comment)
            }
        }
    }
}
```

### 3. CommentPopoverView.swift

SwiftUI view for displaying comment content.

```swift
struct CommentPopoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let comment: CommentModel
    @State private var editedText: String
    @State private var isEditing: Bool = false
    
    init(comment: CommentModel) {
        self.comment = comment
        self._editedText = State(initialValue: comment.text)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(comment.author)
                    .font(.headline)
                Text("•")
                    .foregroundColor(.secondary)
                Text(comment.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Content
            if isEditing {
                TextEditor(text: $editedText)
                    .frame(minHeight: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
            } else {
                Text(comment.text)
                    .font(.body)
                    .textSelection(.enabled)
            }
            
            if let modifiedAt = comment.modifiedAt {
                Text("Edited \(modifiedAt, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Actions
            HStack(spacing: 12) {
                if isEditing {
                    Button("Cancel") {
                        editedText = comment.text
                        isEditing = false
                    }
                    Button("Save") {
                        CommentManager.shared.updateComment(
                            comment,
                            text: editedText,
                            context: modelContext
                        )
                        isEditing = false
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button {
                        if comment.isResolved {
                            CommentManager.shared.unresolveComment(
                                comment,
                                context: modelContext
                            )
                        } else {
                            CommentManager.shared.resolveComment(
                                comment,
                                context: modelContext
                            )
                        }
                        dismiss()
                    } label: {
                        Label(
                            comment.isResolved ? "Unresolve" : "Resolve",
                            systemImage: comment.isResolved ? "arrow.uturn.backward" : "checkmark"
                        )
                    }
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        CommentManager.shared.deleteComment(
                            comment,
                            context: modelContext
                        )
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .frame(width: 300)
    }
}
```

### 4. Integration with Document Editing

**PaginatedDocumentView.swift** - Add comment button to toolbar:

```swift
// In toolbar
ToolbarItem(placement: .primaryAction) {
    Menu {
        // Existing items...
        
        Divider()
        
        Button {
            showAddCommentSheet = true
        } label: {
            Label("Add Comment", systemImage: "bubble.left")
        }
        .keyboardShortcut("c", modifiers: [.command, .shift])
        .disabled(selectedRange == nil)
    }
}
```

**TextEditingCoordinator.swift** - Handle comment insertion:

```swift
extension TextEditingCoordinator {
    func insertComment(text: String) {
        guard let textView = textView,
              let file = textFile,
              let modelContext = modelContext else { return }
        
        let selectedRange = textView.selectedRange
        let position = selectedRange.location
        
        // Create comment in database
        let comment = CommentManager.shared.createComment(
            in: file,
            at: position,
            text: text,
            context: modelContext
        )
        
        // Create attachment
        let attachment = CommentAttachment(
            commentID: comment.id,
            isResolved: false
        )
        
        // Insert into attributed string
        let attachmentString = NSAttributedString(attachment: attachment)
        textStorage.insert(attachmentString, at: position)
        
        // Move cursor after attachment
        textView.selectedRange = NSRange(
            location: position + 1,
            length: 0
        )
        
        // Register undo
        undoManager?.registerUndo(withTarget: self) { target in
            target.removeComment(at: position, commentID: comment.id)
        }
    }
    
    private func removeComment(at position: Int, commentID: UUID) {
        guard let textView = textView,
              let file = textFile,
              let modelContext = modelContext else { return }
        
        // Remove from text
        textStorage.deleteCharacters(in: NSRange(location: position, length: 1))
        
        // Remove from database
        if let comment = CommentManager.shared.fetchComment(
            byID: commentID,
            context: modelContext
        ) {
            CommentManager.shared.deleteComment(comment, context: modelContext)
        }
        
        // Register redo
        undoManager?.registerUndo(withTarget: self) { target in
            // Would need to restore comment - complex, may skip for v1
        }
    }
}
```

**Handle tap on comment attachment**:

```swift
// In UITextViewDelegate extension
func textView(
    _ textView: UITextView,
    shouldInteractWith textAttachment: NSTextAttachment,
    in characterRange: NSRange,
    interaction: UITextItemInteraction
) -> Bool {
    if let commentAttachment = textAttachment as? CommentAttachment {
        // Show comment popover
        showCommentPopover(commentID: commentAttachment.commentID)
        return false  // Prevent default interaction
    }
    return true
}

private func showCommentPopover(commentID: UUID) {
    guard let modelContext = modelContext,
          let comment = CommentManager.shared.fetchComment(
              byID: commentID,
              context: modelContext
          ) else { return }
    
    CommentManager.shared.activeCommentID = commentID
    
    // Show popover (platform-specific)
    #if os(macOS)
    // Use NSPopover
    #else
    // Use Sheet or Popover
    presentingViewController?.present(
        UIHostingController(
            rootView: CommentPopoverView(comment: comment)
        ),
        animated: true
    )
    #endif
}
```

---

## Implementation Phases

### Phase 1: Data Model & Manager (3 hours)

**Tasks**:
- [ ] Create `CommentModel` SwiftData entity
- [ ] Add to ModelContainer schema
- [ ] Create `CommentManager` singleton
- [ ] Implement CRUD operations
- [ ] Write unit tests for manager

**Acceptance Criteria**:
- Comments can be created, read, updated, deleted via manager
- Database queries work correctly
- Position tracking updates properly

**Testing**:
```swift
func testCommentCreation() {
    let comment = manager.createComment(
        in: file,
        at: 100,
        text: "Test comment",
        context: context
    )
    XCTAssertEqual(comment.text, "Test comment")
    XCTAssertEqual(comment.characterPosition, 100)
}

func testPositionUpdate() {
    let comment = createComment(at: 100)
    
    // Insert 10 characters before comment
    manager.updatePositions(
        for: file.id,
        afterEdit: NSRange(location: 50, length: 0),
        changeInLength: 10,
        context: context
    )
    
    XCTAssertEqual(comment.characterPosition, 110)
}
```

### Phase 2: Comment Attachment (3 hours)

**Tasks**:
- [ ] Create `CommentAttachment` class
- [ ] Implement custom image rendering
- [ ] Test attachment in NSAttributedString
- [ ] Handle resolved state visual change
- [ ] Test at different zoom levels

**Acceptance Criteria**:
- Comment indicator renders correctly inline
- Active and resolved comments visually distinct
- Scales properly with zoom level
- Works in both light and dark modes

**Testing**:
```swift
func testAttachmentRendering() {
    let attachment = CommentAttachment(commentID: UUID())
    let image = attachment.image(
        forBounds: CGRect(x: 0, y: 0, width: 16, height: 16),
        textContainer: nil,
        characterIndex: 0
    )
    XCTAssertNotNil(image)
}
```

### Phase 3: Comment Insertion UI (4 hours)

**Tasks**:
- [ ] Add "Add Comment" toolbar button
- [ ] Create comment input sheet/popover
- [ ] Implement insertion logic
- [ ] Handle undo/redo
- [ ] Test on macOS and iOS

**Acceptance Criteria**:
- Button appears in toolbar
- Sheet/popover opens on button click
- Comment inserted at cursor position
- Undo removes comment
- Redo restores comment

**UI Components**:
```swift
struct AddCommentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var commentText: String = ""
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $commentText)
                    .frame(minHeight: 100)
                    .padding()
            }
            .navigationTitle("Add Comment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(commentText)
                        dismiss()
                    }
                    .disabled(commentText.isEmpty)
                }
            }
        }
    }
}
```

### Phase 4: Comment Display (4 hours)

**Tasks**:
- [ ] Create `CommentPopoverView`
- [ ] Implement tap detection on attachments
- [ ] Show popover with comment content
- [ ] Handle macOS vs iOS presentation
- [ ] Test dismiss behaviors

**Acceptance Criteria**:
- Tapping comment shows popover
- Popover displays comment content
- Author and timestamp shown
- Popover closes appropriately
- Works on both platforms

### Phase 5: Comment Editing & Actions (3 hours)

**Tasks**:
- [ ] Implement edit mode in popover
- [ ] Add resolve/unresolve functionality
- [ ] Implement delete with confirmation
- [ ] Update attachment appearance on resolve
- [ ] Test all actions

**Acceptance Criteria**:
- Comment text can be edited
- Resolve toggles state and changes appearance
- Delete removes comment and attachment
- All changes persist to database
- UI updates reflect state changes

### Phase 6: Position Management (3 hours)

**Tasks**:
- [ ] Hook into text editing notifications
- [ ] Update comment positions on edits
- [ ] Handle comment deletion when text deleted
- [ ] Test edge cases (batch edits, undo/redo)
- [ ] Add position validation on file load

**Acceptance Criteria**:
- Comments stay with correct text location
- Positions update on insert/delete operations
- Comments removed if their text deleted
- Undo/redo maintains correct positions
- No orphaned comments after complex edits

**Integration**:
```swift
// In TextEditingCoordinator
func textStorage(
    _ textStorage: NSTextStorage,
    didProcessEditing editedMask: NSTextStorage.EditActions,
    range editedRange: NSRange,
    changeInLength delta: Int
) {
    guard editedMask.contains(.editedCharacters),
          let file = textFile else { return }
    
    // Update comment positions
    CommentManager.shared.updatePositions(
        for: file.id,
        afterEdit: editedRange,
        changeInLength: delta,
        context: modelContext
    )
    
    // Existing pagination update logic...
}
```

### Phase 7: Comments List Sidebar (Optional - 4 hours)

**Tasks**:
- [ ] Create comments list view
- [ ] Add filter controls (all/active/resolved)
- [ ] Implement click to jump to comment
- [ ] Add badge counts
- [ ] Test list updates

**Acceptance Criteria**:
- Sidebar shows all comments for file
- Filters work correctly
- Clicking comment scrolls to position
- Badge shows active comment count
- List updates when comments change

**UI Design**:
```swift
struct CommentsListView: View {
    @Query private var comments: [CommentModel]
    @State private var filter: CommentFilter = .active
    
    enum CommentFilter {
        case all, active, resolved
    }
    
    var filteredComments: [CommentModel] {
        switch filter {
        case .all: return comments
        case .active: return comments.filter { !$0.isResolved }
        case .resolved: return comments.filter { $0.isResolved }
        }
    }
    
    var body: some View {
        VStack {
            Picker("Filter", selection: $filter) {
                Text("All").tag(CommentFilter.all)
                Text("Active").tag(CommentFilter.active)
                Text("Resolved").tag(CommentFilter.resolved)
            }
            .pickerStyle(.segmented)
            .padding()
            
            List(filteredComments) { comment in
                CommentRowView(comment: comment)
            }
        }
    }
}
```

### Phase 8: Threading Support (Optional - 3 hours)

**Tasks**:
- [ ] Add reply functionality
- [ ] Show reply chains in popover
- [ ] Implement collapse/expand
- [ ] Update data model relationships
- [ ] Test nested replies

**Acceptance Criteria**:
- Users can reply to comments
- Replies shown in thread
- Threads can collapse/expand
- Thread relationships maintained
- Deleting parent handles replies gracefully

---

## Testing Strategy

### Unit Tests

1. **CommentModel Tests**
   - CRUD operations
   - Position tracking
   - Resolution state
   - Thread relationships

2. **CommentManager Tests**
   - Database queries
   - Position updates
   - Batch operations
   - Edge cases

3. **CommentAttachment Tests**
   - Rendering
   - Serialization
   - State changes

### Integration Tests

1. **Comment Insertion**
   - Via toolbar button
   - Via context menu
   - With text selection
   - At various positions

2. **Comment Display**
   - Popover presentation
   - Content rendering
   - Platform-specific behavior

3. **Position Tracking**
   - Insert before comment
   - Insert after comment
   - Delete around comment
   - Undo/redo sequences

### Manual Testing Checklist

- [ ] Create comment at start of document
- [ ] Create comment at end of document
- [ ] Create comment in middle of word
- [ ] Edit comment text
- [ ] Resolve/unresolve comment
- [ ] Delete comment
- [ ] Insert text before comment
- [ ] Insert text after comment
- [ ] Delete text containing comment
- [ ] Undo comment insertion
- [ ] Redo comment insertion
- [ ] Zoom in/out with comments visible
- [ ] Switch between light/dark mode
- [ ] Test on macOS
- [ ] Test on iOS
- [ ] Test on iPad

---

## Edge Cases & Error Handling

### Position Tracking Issues

**Problem**: Comment position becomes invalid after complex edits

**Solutions**:
1. Validate positions on file load
2. Remove orphaned comments
3. Log warnings for investigation
4. Provide "fix positions" tool for debugging

### Concurrent Edits

**Problem**: Multiple users editing same document (future)

**Current Approach**: Single user only (v1)

**Future**: 
- Use CRDTs or OT for conflict resolution
- CloudKit sync with change tokens
- Position anchors instead of integer offsets

### Export/Import

**Problem**: Comments lost when exporting to plain text

**Solutions**:
1. Export formats:
   - **Plain Text**: Strip comments
   - **Markdown**: Convert to HTML comments `<!-- Comment: text -->`
   - **RTF/RTFD**: Preserve as text attachments
   - **PDF**: Show as margin annotations

2. Import formats:
   - Parse HTML comments back to attachments
   - Detect RTFD attachments
   - Ignore in plain text

### Performance

**Problem**: Many comments (100+) slow down rendering

**Solutions**:
1. Lazy load comment content
2. Cache rendered attachment images
3. Limit visible comments (paginate sidebar)
4. Optimize database queries (index on fileID)

### Memory Management

**Problem**: Comment popovers retain strong references

**Solutions**:
1. Use weak references in coordinators
2. Properly dismiss popovers
3. Clear activeCommentID on dismiss
4. Monitor for leaks in testing

---

## Future Enhancements

### Phase 9: Advanced Features (Post-MVP)

1. **Comment Search**
   - Search comment text
   - Filter by author
   - Filter by date range

2. **Comment Export**
   - Generate comment report
   - Export as PDF with annotations
   - Export as spreadsheet

3. **Comment Analytics**
   - Total comments by author
   - Resolution rate
   - Average time to resolve
   - Comment density heatmap

4. **Rich Text Comments**
   - Bold, italic in comment text
   - Add links in comments
   - Add images in comments

5. **Collaborative Features**
   - Real-time comment sync (CloudKit)
   - @mentions
   - Email notifications
   - Comment assignments

6. **Voice Comments**
   - Record audio comment
   - Playback in popover
   - Transcribe to text

---

## Accessibility

### VoiceOver Support

- [ ] Comment indicators have accessibility labels
- [ ] Popovers announce content
- [ ] Actions have accessibility hints
- [ ] Keyboard navigation works

### Keyboard Shortcuts

| Action | macOS | iOS |
|--------|-------|-----|
| Add Comment | ⌘⇧C | - |
| Next Comment | ⌘] | - |
| Previous Comment | ⌘[ | - |
| Resolve Comment | ⌘⏎ | - |
| Delete Comment | ⌘⌫ | - |

### Color Contrast

- Active comment color meets WCAG AA (4.5:1)
- Resolved comment distinguishable from text
- Works in light and dark modes

---

## Documentation

### User-Facing

1. **Help Article**: "Using Comments"
   - How to add comments
   - How to view comments
   - How to resolve comments
   - Comment keyboard shortcuts

2. **Video Tutorial**
   - 2-minute overview
   - Shows common workflows

### Developer

1. **Architecture Document**
   - Comment system overview
   - Data flow diagrams
   - API reference

2. **Integration Guide**
   - How to add comment support to new views
   - How to extend comment functionality
   - How to customize appearance

---

## Success Criteria

### Functional

✅ Users can add comments to any text position  
✅ Comments display correctly inline  
✅ Comments can be edited and deleted  
✅ Comments can be resolved/unresolved  
✅ Comment positions track with text edits  
✅ Undo/redo works with comments  
✅ Works on both macOS and iOS  

### Performance

✅ Comment insertion < 50ms  
✅ Popover display < 100ms  
✅ Position updates < 10ms per comment  
✅ Smooth scrolling with 50+ comments  

### Quality

✅ Zero data loss in normal operations  
✅ No memory leaks  
✅ Consistent UI across platforms  
✅ Accessible to VoiceOver users  

---

## Timeline

**Total Estimated Effort**: 18-21 hours

### Week 1 (MVP)
- Day 1: Phases 1-2 (Data model + Attachments)
- Day 2: Phases 3-4 (Insertion + Display)
- Day 3: Phases 5-6 (Editing + Position tracking)

### Week 2 (Polish)
- Testing and bug fixes
- Performance optimization
- Documentation

### Future (Optional)
- Phase 7: Comments list sidebar
- Phase 8: Threading support
- Phase 9: Advanced features

---

## Risks & Mitigation

### Risk 1: Position Tracking Complexity

**Impact**: High  
**Likelihood**: Medium

**Mitigation**:
- Start with simple offset tracking
- Add comprehensive tests
- Use existing NSTextStorage notifications
- Reference NSAttributedString best practices

### Risk 2: Cross-Platform UI Differences

**Impact**: Medium  
**Likelihood**: Medium

**Mitigation**:
- Use SwiftUI for maximum code reuse
- Accept platform-specific differences
- Test on both platforms early
- Use #if os() conditionals when needed

### Risk 3: Undo/Redo Interaction

**Impact**: High  
**Likelihood**: Low

**Mitigation**:
- Leverage existing undo system
- Test undo/redo extensively
- May need custom undo operations
- Document any limitations

---

## Conclusion

The comments feature using TextKit 1 provides a pragmatic, low-risk approach to adding collaborative review capabilities. By using proven NSTextAttachment patterns, we avoid the complexity and instability of TextKit 2 migration while delivering full comment functionality.

**Key Advantages**:
- ✅ Stable implementation on proven technology
- ✅ Fast development timeline (2-3 days)
- ✅ Low risk of regression
- ✅ Full feature parity with TextKit 2 approach
- ✅ Foundation for future enhancements

**Next Steps**:
1. Review and approve this spec
2. Begin Phase 1 implementation
3. Iterative development with testing
4. Ship MVP in Week 1
5. Gather user feedback for Phase 7-9

---

## References

### Apple Documentation
- [NSTextAttachment](https://developer.apple.com/documentation/uikit/nstextattachment)
- [TextKit Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextArchitecture/TextArchitecture.html)
- [Custom Text Attachments](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextAttachments/TextAttachments.html)

### Related Specs
- Feature 005: Text Formatting (attributed string handling)
- Feature 010: Pagination (text layout integration)
- `COMMENTS_WITHOUT_TEXTKIT2.md` (decision rationale)

### Design Inspiration
- Microsoft Word (inline indicators)
- Google Docs (margin annotations)
- Notion (clean comment threading)
- Bear (simple, elegant UI)
