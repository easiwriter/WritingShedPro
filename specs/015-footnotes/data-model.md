# Feature 015: Footnotes - Data Model

## SwiftData Models

### FootnoteModel

```swift
@Model
final class FootnoteModel {
    /// Unique identifier
    var id: UUID = UUID()
    
    /// ID of the TextFile this footnote belongs to
    var textFileID: UUID = UUID()
    
    /// Character position in the document where the footnote marker appears
    var characterPosition: Int = 0
    
    /// ID of the NSTextAttachment for the marker
    var attachmentID: UUID = UUID()
    
    /// The footnote content/text
    var text: String = ""
    
    /// Footnote number (for display)
    var number: Int = 0
    
    /// Creation timestamp
    var createdAt: Date = Date()
    
    /// Last modified timestamp
    var modifiedAt: Date = Date()
    
    init(textFileID: UUID, characterPosition: Int, text: String, number: Int) {
        self.id = UUID()
        self.textFileID = textFileID
        self.characterPosition = characterPosition
        self.attachmentID = UUID()
        self.text = text
        self.number = number
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}
```

## NSTextAttachment

### FootnoteAttachment

```swift
final class FootnoteAttachment: NSTextAttachment {
    let footnoteID: UUID
    let number: Int
    
    init(footnoteID: UUID, number: Int) {
        self.footnoteID = footnoteID
        self.number = number
        super.init(data: nil, ofType: nil)
    }
    
    // Render as superscript number
    override func image(
        forBounds imageBounds: CGRect,
        textContainer: NSTextContainer?,
        characterIndex charIndex: Int
    ) -> UIImage? {
        // Create small superscript number badge
    }
}
```

## Serialization

Extend `AttributedStringSerializer` to handle footnotes:

```swift
struct AttributeValues: Codable {
    // ... existing properties ...
    
    // Footnote properties
    var isFootnoteAttachment: Bool?
    var footnoteID: String?
    var footnoteNumber: Int?
}
```

## Relationships

- **TextFile → FootnoteModel**: One-to-many relationship via `textFileID`
- **FootnoteModel → FootnoteAttachment**: One-to-one via `attachmentID`

## CloudKit Considerations

Following Feature 014 (Comments) patterns:
- All properties optional or have default values
- No unique constraints (CloudKit limitation)
- UUID-based relationships

## Migration Notes

Similar to comments, existing documents without footnotes will work seamlessly. Footnote data is stored separately in SwiftData and linked via attachments.
