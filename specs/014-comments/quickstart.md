# Feature 014: Comments - Quick Start Guide

## 🎯 Goal

Add inline commenting system to text documents using TextKit 1 custom attachments.

## ⚡ Quick Implementation

### 1. Data Model (30 min)

```swift
@Model
final class CommentModel {
    @Attribute(.unique) var id: UUID
    var textFileID: UUID
    var characterPosition: Int
    var attachmentID: UUID
    var text: String
    var author: String
    var createdAt: Date
    var resolvedAt: Date?
    
    var isResolved: Bool { resolvedAt != nil }
}
```

Add to ModelContainer schema.

### 2. Comment Attachment (30 min)

```swift
final class CommentAttachment: NSTextAttachment {
    let commentID: UUID
    let isResolved: Bool
    
    override func image(forBounds imageBounds: CGRect, ...) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 14)
        return UIImage(systemName: "bubble.left.fill", withConfiguration: config)?
            .withTintColor(isResolved ? .systemGray : .systemBlue)
    }
}
```

### 3. Comment Manager (45 min)

```swift
@MainActor
final class CommentManager: ObservableObject {
    static let shared = CommentManager()
    
    func createComment(in file: TextFile, at position: Int, text: String, context: ModelContext) -> CommentModel
    func updateComment(_ comment: CommentModel, text: String, context: ModelContext)
    func deleteComment(_ comment: CommentModel, context: ModelContext)
    func resolveComment(_ comment: CommentModel, context: ModelContext)
    func fetchComments(for fileID: UUID, context: ModelContext) -> [CommentModel]
    func updatePositions(for fileID: UUID, afterEdit range: NSRange, changeInLength: Int, context: ModelContext)
}
```

### 4. Insert Comment (1 hour)

**Add toolbar button:**
```swift
Button {
    showAddCommentSheet = true
} label: {
    Label("Add Comment", systemImage: "bubble.left")
}
.keyboardShortcut("c", modifiers: [.command, .shift])
```

**Insertion logic:**
```swift
func insertComment(text: String) {
    let position = textView.selectedRange.location
    let comment = CommentManager.shared.createComment(
        in: file, at: position, text: text, context: modelContext
    )
    let attachment = CommentAttachment(commentID: comment.id, isResolved: false)
    textStorage.insert(NSAttributedString(attachment: attachment), at: position)
}
```

### 5. Display Comment (1 hour)

```swift
func textView(_ textView: UITextView, shouldInteractWith textAttachment: NSTextAttachment, ...) -> Bool {
    if let commentAttachment = textAttachment as? CommentAttachment {
        showCommentPopover(commentID: commentAttachment.commentID)
        return false
    }
    return true
}
```

**Popover View:**
```swift
struct CommentPopoverView: View {
    let comment: CommentModel
    @State private var editedText: String
    @State private var isEditing = false
    
    var body: some View {
        VStack {
            // Header with author, time
            // Content (text or editor)
            // Actions (edit, resolve, delete)
        }
        .frame(width: 300)
    }
}
```

### 6. Update Positions (30 min)

```swift
func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: ..., range: NSRange, changeInLength delta: Int) {
    CommentManager.shared.updatePositions(
        for: file.id,
        afterEdit: range,
        changeInLength: delta,
        context: modelContext
    )
}
```

## 📋 Phases

1. **Data Model** (30 min) → Database & manager
2. **Attachment** (30 min) → Visual indicator
3. **Insertion** (1 hour) → UI to add comments
4. **Display** (1 hour) → Popover to view/edit
5. **Actions** (45 min) → Edit, resolve, delete
6. **Positions** (30 min) → Track edits

**Total**: ~4.5 hours for MVP

## ✅ Testing Checklist

- [ ] Create comment at cursor
- [ ] Display comment on tap
- [ ] Edit comment text
- [ ] Resolve/unresolve comment
- [ ] Delete comment
- [ ] Insert text before comment → position updates
- [ ] Delete text with comment → comment removed
- [ ] Undo comment insertion → comment removed
- [ ] Redo comment insertion → comment restored
- [ ] Test on macOS and iOS

## 🚀 Next Steps

1. Implement Phases 1-6
2. Test thoroughly
3. Add to toolbar
4. Ship MVP
5. Optional: Comments list sidebar
6. Optional: Threading support

## 📚 References

- Full spec: `spec.md`
- Data model: `data-model.md`
- Tasks: `tasks.md`
- Decision rationale: `../COMMENTS_WITHOUT_TEXTKIT2.md`
