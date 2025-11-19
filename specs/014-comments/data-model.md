# Feature 014: Comments - Data Model

## Overview

Comments are stored as SwiftData entities with references to their text file and position. Comment attachments (NSTextAttachment subclass) are embedded in the attributed string and linked to the comment entity via UUID.

---

## CommentModel Entity

### Schema

```swift
@Model
final class CommentModel {
    // MARK: - Identity
    
    /// Unique identifier for the comment
    @Attribute(.unique) var id: UUID
    
    /// Reference to the text file containing this comment
    var textFileID: UUID
    
    // MARK: - Position Tracking
    
    /// Character offset in the NSAttributedString where comment is located
    /// This is the position of the CommentAttachment in the text
    var characterPosition: Int
    
    /// Unique identifier for the NSTextAttachment
    /// Used to find and update the attachment when comment state changes
    var attachmentID: UUID
    
    // MARK: - Content
    
    /// The comment text content
    var text: String
    
    /// Display name of comment author
    /// For single-user app: "Me" or user's name from system
    /// For multi-user: actual user name or email
    var author: String
    
    // MARK: - Metadata
    
    /// When comment was created
    var createdAt: Date
    
    /// When comment was last edited (nil if never edited)
    var modifiedAt: Date?
    
    /// When comment was resolved (nil if still active)
    /// Resolved comments shown in gray and can be hidden
    var resolvedAt: Date?
    
    // MARK: - Threading (Optional - Phase 7)
    
    /// Parent comment ID if this is a reply (nil for root comments)
    var parentCommentID: UUID?
    
    /// Thread identifier - groups root comment with all replies
    /// Root comment and all replies share same threadID
    var threadID: UUID
    
    // MARK: - Computed Properties
    
    /// Whether this comment is resolved
    var isResolved: Bool {
        resolvedAt != nil
    }
    
    /// Whether this is a reply to another comment
    var isReply: Bool {
        parentCommentID != nil
    }
    
    // MARK: - Initialization
    
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
    
    // MARK: - Threading Support
    
    /// Create a reply to this comment
    func createReply(text: String, author: String = "Me") -> CommentModel {
        let reply = CommentModel(
            textFileID: self.textFileID,
            characterPosition: self.characterPosition,  // Same position as parent
            text: text,
            author: author
        )
        reply.parentCommentID = self.id
        reply.threadID = self.threadID  // Inherit thread ID
        return reply
    }
}
```

### Relationships

```
TextFile (1) ←→ (N) CommentModel
    └── textFileID foreign key

CommentModel (0..1) ←→ (N) CommentModel  [Threading]
    └── parentCommentID self-reference
    
CommentModel (1) ←→ (N) CommentModel  [Threading]
    └── threadID grouping
```

### Indexes

```swift
// In schema configuration
schema.addIndex(on: CommentModel.self, fields: [\.textFileID])
schema.addIndex(on: CommentModel.self, fields: [\.characterPosition])
schema.addIndex(on: CommentModel.self, fields: [\.threadID])
```

**Rationale**:
- `textFileID`: Most queries fetch all comments for a file
- `characterPosition`: Sorting by position is common
- `threadID`: Threading requires grouping by thread

---

## CommentAttachment Class

### NSTextAttachment Subclass

```swift
final class CommentAttachment: NSTextAttachment {
    // MARK: - Properties
    
    /// Reference to the comment entity
    let commentID: UUID
    
    /// Whether comment is resolved (affects visual appearance)
    var isResolved: Bool
    
    // MARK: - Initialization
    
    init(commentID: UUID, isResolved: Bool = false) {
        self.commentID = commentID
        self.isResolved = isResolved
        super.init(data: nil, ofType: nil)
        
        // Position slightly below baseline
        self.bounds = CGRect(x: 0, y: -2, width: 16, height: 16)
    }
    
    required init?(coder: NSCoder) {
        // For NSCoding support (undo/redo)
        guard let commentIDString = coder.decodeObject(forKey: "commentID") as? String,
              let commentID = UUID(uuidString: commentIDString) else {
            return nil
        }
        
        self.commentID = commentID
        self.isResolved = coder.decodeBool(forKey: "isResolved")
        
        super.init(coder: coder)
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(commentID.uuidString, forKey: "commentID")
        coder.encode(isResolved, forKey: "isResolved")
    }
    
    // MARK: - Rendering
    
    override func image(
        forBounds imageBounds: CGRect,
        textContainer: NSTextContainer?,
        characterIndex: Int
    ) -> UIImage? {
        let config = UIImage.SymbolConfiguration(
            pointSize: 14,
            weight: .regular
        )
        
        let symbolName = isResolved ? "bubble.left" : "bubble.left.fill"
        let color: UIColor = isResolved ? .systemGray : .systemBlue
        
        return UIImage(systemName: symbolName, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
    }
    
    // MARK: - Accessibility
    
    override var accessibilityLabel: String? {
        get {
            isResolved ? "Resolved comment" : "Active comment"
        }
        set { }
    }
}
```

### Storage in NSAttributedString

Comments are stored as single-character attachments:

```swift
let attachment = CommentAttachment(commentID: comment.id)
let attachmentString = NSAttributedString(attachment: attachment)

// Insert at position
attributedString.insert(attachmentString, at: position)

// Result in string:
// "Hello <CommentAttachment> world"
//        ↑ position
```

### Attributes

Comment attachments have standard NSAttributedString attachment attributes:

```swift
[
    .attachment: CommentAttachment instance,
    .font: UIFont.systemFont(ofSize: 12),  // Inherited from context
    // Other attributes inherited from surrounding text
]
```

---

## Position Tracking

### Character Position Semantics

`characterPosition` represents the **character offset** in the NSAttributedString where the CommentAttachment is located.

```
Text:     "Hello world"
Indices:   0123456789...
Position:      ↑ 5

After comment insertion:
"Hello<📎>world"  (📎 = attachment character)
       ↑ 5
```

### Position Updates on Edits

When text is edited, comment positions must be updated:

**Insert before comment**:
```swift
Original: "Hello<📎>world"  // position = 5
Insert "beautiful " at 6:
Result:   "Hello<📎>beautiful world"  // position = 5 (unchanged)
```

**Insert after comment**:
```swift
Original: "Hello<📎>world"  // position = 5
Insert "beautiful " at 11:
Result:   "Hello<📎>world beautiful"  // position = 5 (unchanged)
```

**Delete before comment**:
```swift
Original: "Hello world<📎>end"  // position = 11
Delete "world " (6-12):
Result:   "Hello <📎>end"  // position = 6 (shifted left by 6)
```

**Delete including comment**:
```swift
Original: "Hello<📎>world"  // position = 5
Delete "o<📎>wo" (4-8):
Result:   "Hellrld"  // comment deleted from DB
```

### Update Algorithm

```swift
func updatePositions(
    for fileID: UUID,
    afterEdit range: NSRange,
    changeInLength delta: Int,
    context: ModelContext
) {
    let comments = fetchComments(for: fileID, context: context)
    
    for comment in comments {
        let pos = comment.characterPosition
        
        if delta > 0 {
            // Insertion
            if pos >= range.location {
                // Comment is after insertion point
                comment.characterPosition += delta
            }
        } else if delta < 0 {
            // Deletion
            let deleteEnd = range.location + range.length
            
            if pos >= deleteEnd {
                // Comment is after deleted range
                comment.characterPosition += delta  // delta is negative
            } else if pos >= range.location && pos < deleteEnd {
                // Comment is within deleted range - remove it
                context.delete(comment)
            }
        }
    }
}
```

---

## Database Queries

### Fetch All Comments for File

```swift
let descriptor = FetchDescriptor<CommentModel>(
    predicate: #Predicate { $0.textFileID == fileID },
    sortBy: [SortDescriptor(\.characterPosition)]
)
let comments = try context.fetch(descriptor)
```

### Fetch Active Comments Only

```swift
let descriptor = FetchDescriptor<CommentModel>(
    predicate: #Predicate { 
        $0.textFileID == fileID && $0.resolvedAt == nil 
    },
    sortBy: [SortDescriptor(\.characterPosition)]
)
let activeComments = try context.fetch(descriptor)
```

### Fetch Comment by ID

```swift
let descriptor = FetchDescriptor<CommentModel>(
    predicate: #Predicate { $0.id == commentID }
)
let comment = try context.fetch(descriptor).first
```

### Fetch Thread

```swift
let descriptor = FetchDescriptor<CommentModel>(
    predicate: #Predicate { $0.threadID == threadID },
    sortBy: [SortDescriptor(\.createdAt)]
)
let thread = try context.fetch(descriptor)
```

### Count Active Comments

```swift
let descriptor = FetchDescriptor<CommentModel>(
    predicate: #Predicate { 
        $0.textFileID == fileID && $0.resolvedAt == nil 
    }
)
let count = try context.fetchCount(descriptor)
```

---

## Data Migration

### Schema Version History

**Version 1.0** (Initial):
- Basic comment fields
- No threading support

**Version 2.0** (Threading - Optional):
- Add `parentCommentID`
- Add `threadID`

### Migration Strategy

Since this is a **new entity**, no migration needed for initial release.

For future threading support:
```swift
// Migration from 1.0 to 2.0
for comment in oldComments {
    comment.threadID = comment.id  // Each comment is its own thread initially
    comment.parentCommentID = nil  // All are root comments
}
```

---

## Export/Import Format

### JSON Representation

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "textFileID": "650e8400-e29b-41d4-a716-446655440001",
  "characterPosition": 125,
  "text": "This needs clarification",
  "author": "John Doe",
  "createdAt": "2025-11-19T10:30:00Z",
  "modifiedAt": null,
  "resolvedAt": null,
  "parentCommentID": null,
  "threadID": "550e8400-e29b-41d4-a716-446655440000"
}
```

### Export to Markdown

```markdown
<!-- Comment by John Doe (2025-11-19):
This needs clarification
-->
```

### Import from Markdown

Parse HTML comments:
```swift
let pattern = #"<!--\s*Comment by (.+?) \((.+?)\):\s*(.+?)\s*-->"#
// Extract author, date, text
// Create CommentModel
// Insert CommentAttachment
```

---

## Performance Considerations

### Query Optimization

1. **Index on textFileID**: O(log n) lookup instead of O(n)
2. **Batch updates**: Update all positions in single transaction
3. **Lazy loading**: Don't load comment text until popover shown
4. **Cache active count**: Update badge without full query

### Memory Management

1. **CommentAttachment is lightweight**: Only stores UUID + bool
2. **Comment text loaded on demand**: From database when popover opens
3. **Popover dismissed releases memory**: No retained references
4. **Position updates efficient**: Simple arithmetic, no string scanning

### Scalability

**Expected usage**:
- Typical file: 10-50 comments
- Heavy review: 100-200 comments
- Maximum supported: 1000+ comments

**Performance targets**:
- Fetch all comments: < 10ms
- Update positions: < 5ms
- Display popover: < 50ms

---

## Testing Data

### Sample Comments

```swift
// Phase 1: Simple comment
CommentModel(
    textFileID: file.id,
    characterPosition: 100,
    text: "Great opening paragraph!"
)

// Phase 2: Resolved comment
let resolved = CommentModel(
    textFileID: file.id,
    characterPosition: 250,
    text: "Fixed typo here"
)
resolved.resolvedAt = Date()

// Phase 7: Reply
let parent = CommentModel(
    textFileID: file.id,
    characterPosition: 500,
    text: "This section is confusing"
)
let reply = parent.createReply(text: "Agreed, needs rewrite")
```

### Edge Cases

```swift
// Comment at position 0 (start of document)
CommentModel(textFileID: file.id, characterPosition: 0, text: "Title comment")

// Comment at end of document
let endPos = textStorage.length
CommentModel(textFileID: file.id, characterPosition: endPos, text: "End note")

// Multiple comments at same position (threading)
let pos = 100
CommentModel(textFileID: file.id, characterPosition: pos, text: "First")
CommentModel(textFileID: file.id, characterPosition: pos, text: "Second")
```

---

## Validation Rules

### On Creation

- `text` must not be empty
- `characterPosition` must be within document bounds (0...textStorage.length)
- `textFileID` must reference existing TextFile
- `author` must not be empty

### On Update

- Position updates must maintain order (no negative positions)
- Resolved comments cannot be unresolved after >30 days (optional business rule)
- Thread relationships must be valid (no circular references)

### On Deletion

- Cascade delete replies when parent deleted (optional)
- Remove CommentAttachment from text
- Cannot delete if part of active thread (optional - make parent instead)

---

## Future Enhancements

### Rich Text Comments

Add `NSAttributedString` support:
```swift
var attributedText: NSAttributedString?  // Instead of plain text
```

### Attachments in Comments

Add media support:
```swift
var attachments: [UUID]?  // References to image/audio files
```

### Categories/Tags

Add classification:
```swift
var category: String?  // "typo", "question", "suggestion", etc.
var tags: [String]?
```

### Priority

Add urgency indicator:
```swift
enum Priority: String, Codable {
    case low, normal, high, urgent
}
var priority: Priority = .normal
```

---

## References

- [SwiftData Schema Documentation](https://developer.apple.com/documentation/swiftdata/schema)
- [NSTextAttachment Documentation](https://developer.apple.com/documentation/uikit/nstextattachment)
- [Predicate Documentation](https://developer.apple.com/documentation/foundation/predicate)
