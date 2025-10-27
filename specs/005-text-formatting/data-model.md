# Phase 005: Text Formatting - Data Model

**Status**: Ready for Implementation  
**Created**: 2025-10-26  
**Updated**: 2025-10-27

## Overview

Phase 005 adds text formatting capabilities to Writing Shed Pro. This requires storing formatted content as NSAttributedString while maintaining backward compatibility with plain text.

## Data Structures

### Version Model Extension

```swift
@Model
final class Version {
    // Existing properties
    var content: String?  // Plain text (maintained for compatibility)
    var createdDate: Date?
    var modifiedDate: Date?
    
    // NEW: Formatted content
    var formattedContent: Data?  // RTF data from NSAttributedString
    
    // NEW: Computed property for working with attributed strings
    var attributedContent: NSAttributedString? {
        get {
            guard let data = formattedContent else {
                // Fall back to plain text if no formatted content
                return content.map { NSAttributedString(string: $0) }
            }
            return try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
        }
        set {
            if let attributed = newValue {
                // Store as RTF data
                let range = NSRange(location: 0, length: attributed.length)
                formattedContent = try? attributed.data(
                    from: range,
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                )
                // Also update plain text for search/compatibility
                content = attributed.string
            } else {
                formattedContent = nil
            }
        }
    }
    
    // Existing relationships
    var file: File?
}
```

### NumberFormat Enum

```swift
/// Represents the numbering/bullet format for a paragraph
enum NumberFormat: String, Codable {
    case none                // No numbering (default)
    case decimal             // 1, 2, 3, 4...
    case lowercaseRoman      // i, ii, iii, iv...
    case uppercaseRoman      // I, II, III, IV...
    case lowercaseLetter     // a, b, c, d...
    case uppercaseLetter     // A, B, C, D...
    case footnoteSymbols     // *, †, ‡, §, ¶
    case bulletSymbols       // •, ◦, ▪, ▫, ▸
    
    /// The actual character/string to display for a given index
    func symbol(for index: Int) -> String {
        switch self {
        case .none:
            return ""
        case .decimal:
            return "\(index + 1)."
        case .lowercaseRoman:
            return romanNumeral(index + 1, uppercase: false)
        case .uppercaseRoman:
            return romanNumeral(index + 1, uppercase: true)
        case .lowercaseLetter:
            return letter(index, uppercase: false)
        case .uppercaseLetter:
            return letter(index, uppercase: true)
        case .footnoteSymbols:
            let symbols = ["*", "†", "‡", "§", "¶"]
            return symbols[index % symbols.count]
        case .bulletSymbols:
            let symbols = ["•", "◦", "▪", "▫", "▸"]
            return symbols[index % symbols.count]
        }
    }
    
    // Helper methods...
    private func romanNumeral(_ num: Int, uppercase: Bool) -> String { /* ... */ }
    private func letter(_ index: Int, uppercase: Bool) -> String { /* ... */ }
}

/// Custom NSAttributedString attribute key for number format
extension NSAttributedString.Key {
    static let numberFormat = NSAttributedString.Key("WritingShedPro.NumberFormat")
}
```

## Storage Considerations

### RTF Format Choice

**Why RTF?**
- ✅ Text-based format (human-readable)
- ✅ Wide platform support
- ✅ Preserves most formatting attributes
- ✅ Smaller than some binary formats
- ✅ Apple native support (NSAttributedString)

**Limitations:**
- ❌ Custom attributes need special handling
- ❌ Some advanced formatting may be lost
- ❌ File size larger than plain text

**Alternatives Considered:**
- NSKeyedArchiver: Binary, not human-readable, Apple-specific
- Custom JSON: More work, need custom parser
- HTML: Overkill, harder to parse reliably

### CloudKit Sync Strategy

```swift
// SwiftData automatically handles Data properties
// formattedContent syncs as binary blob

// Conflict resolution (in CloudKit):
// - Use modifiedDate to determine most recent
// - Most recent version wins
// - No automatic merging (would corrupt formatting)
```

### Storage Size Estimates

| Document Size | Plain Text | RTF | Ratio |
|---------------|-----------|-----|-------|
| 1,000 words | ~6 KB | ~15 KB | 2.5x |
| 10,000 words | ~60 KB | ~150 KB | 2.5x |
| 50,000 words | ~300 KB | ~750 KB | 2.5x |

*With heavy formatting, RTF can be 3-5x larger*

## Integration with Existing Models

### File Model
No changes needed. File → Version relationship already exists.

```swift
@Model
final class File {
    // Existing properties
    var name: String?
    var parentFolder: Folder?
    
    // Computed properties (existing)
    var currentVersion: Version? {
        versions?.sorted(by: { 
            ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast) 
        }).first
    }
    
    // Relationships
    var versions: [Version]?
    
    // Undo/redo properties (existing from Phase 004)
    var undoStackData: Data?
    var redoStackData: Data?
    // ...
}
```

### Undo/Redo System Integration

The existing undo system needs to work with NSAttributedString:

```swift
// FormatApplyCommand
class FormatApplyCommand: UndoableCommand {
    let range: NSRange
    let oldAttributedString: NSAttributedString  // Store old
    let newAttributedString: NSAttributedString  // Store new
    weak var targetFile: File?
    
    func execute() {
        // Apply new formatting
        targetFile?.currentVersion?.attributedContent = newAttributedString
    }
    
    func undo() {
        // Restore old formatting
        targetFile?.currentVersion?.attributedContent = oldAttributedString
    }
}
```

### Migration Strategy

```swift
// When opening a file:
if file.currentVersion?.formattedContent == nil {
    // Old file (plain text only)
    if let plainText = file.currentVersion?.content {
        // Convert to attributed string
        let attributed = NSAttributedString(string: plainText)
        file.currentVersion?.attributedContent = attributed
        // This sets formattedContent automatically
    }
}
```

## NSAttributedString Attributes Used

### Character-Level Attributes

```swift
// Font (includes bold, italic)
.font: UIFont
// Example: UIFont.preferredFont(forTextStyle: .body).withTraits([.traitBold])

// Underline
.underlineStyle: NSUnderlineStyle
// Example: .single, .double, .thick

// Strikethrough
.strikethroughStyle: NSUnderlineStyle

// Text Color
.foregroundColor: UIColor
```

### Paragraph-Level Attributes

```swift
// Paragraph Style (contains most paragraph formatting)
.paragraphStyle: NSMutableParagraphStyle

// Within NSMutableParagraphStyle:
- alignment: .left, .center, .right, .justified
- firstLineHeadIndent: CGFloat (points)
- headIndent: CGFloat (left margin)
- tailIndent: CGFloat (right margin)
- lineSpacing: CGFloat (extra space between lines)
- paragraphSpacing: CGFloat (space after paragraph)
- paragraphSpacingBefore: CGFloat (space before paragraph)
```

### Custom Attributes

```swift
// Number Format (Phase 005: stored only, not applied)
.numberFormat: NumberFormat
// Note: Actual numbering happens in Phase 006
```

## Serialization Service

```swift
struct AttributedStringSerializer {
    /// Convert NSAttributedString to RTF Data
    static func toRTF(_ attributedString: NSAttributedString) -> Data? {
        let range = NSRange(location: 0, length: attributedString.length)
        return try? attributedString.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }
    
    /// Convert RTF Data to NSAttributedString
    static func fromRTF(_ data: Data) -> NSAttributedString? {
        return try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }
    
    /// Extract plain text from NSAttributedString
    static func toPlainText(_ attributedString: NSAttributedString) -> String {
        return attributedString.string
    }
    
    /// Get file size estimate for attributed string
    static func estimatedSize(_ attributedString: NSAttributedString) -> Int {
        return toRTF(attributedString)?.count ?? 0
    }
}
```

## Performance Considerations

### Memory Usage
- NSAttributedString more memory-intensive than String
- Store one instance in Version model, not multiple copies
- Release large documents when not in view

### Rendering Performance
- UITextView handles rendering efficiently
- Layout calculation can be slow for very long documents
- Consider pagination for documents > 50,000 words

### Serialization Performance
- RTF conversion: ~0.1ms per 1,000 words
- Acceptable for auto-save (< 100ms total)
- May need background thread for very large documents

## Data Flow

```
User Types
    ↓
UITextView (NSAttributedString)
    ↓
Binding Update
    ↓
FileEditView
    ↓
Version.attributedContent setter
    ↓
Convert to RTF Data
    ↓
Version.formattedContent (stored)
    ↓
SwiftData Persistence
    ↓
CloudKit Sync
```

## Testing Strategy

### Unit Tests
```swift
// AttributedStringSerializerTests.swift
- testRoundTripConversion()
- testBoldFormatting()
- testItalicFormatting()
- testParagraphStyles()
- testCustomAttributes()
- testLargeDocument()

// NumberFormatTests.swift
- testAllFormatTypes()
- testSymbolGeneration()
- testCodable()
```

### Integration Tests
```swift
// FormattedContentPersistenceTests.swift
- testSaveAndLoadFormattedText()
- testCloudKitSync()
- testConflictResolution()
- testBackwardCompatibility()
```

## Known Limitations

1. **Custom Attributes in RTF**
   - NumberFormat stored as custom attribute
   - RTF may not preserve custom attributes perfectly
   - May need custom serialization layer later

2. **Font Availability**
   - System fonts guaranteed available
   - Custom fonts not supported in Phase 005
   - Font substitution if font missing

3. **Complex Formatting**
   - Tables not supported
   - Images not supported
   - Columns not supported
   - These are future phases

4. **Document Size**
   - Performance tested up to 50,000 words
   - Larger documents may need optimization
   - Consider warning user for very large files

## Future Enhancements (Phase 006+)

- Automatic list numbering based on NumberFormat
- List level tracking (nested lists)
- Style inheritance
- Named styles (paragraph styles)
- Format painter
- Markdown import/export
- Track changes data structure
