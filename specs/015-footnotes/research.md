# Feature 015: Footnotes - Research

## Academic/Technical Writing Standards

### Footnote Formats

1. **Chicago Style**: Superscript numbers, footnotes at page bottom
2. **MLA**: Endnotes section, numbered sequentially
3. **APA**: Rarely uses footnotes (prefers in-text citations)

### Common Implementations

- **Microsoft Word**: Superscript numbers, auto-renumbering, view at page bottom
- **Pages**: Similar to Word, automatic footnote management
- **Scrivener**: Inline markers, compiled to proper format on export
- **LaTeX**: `\footnote{text}` command, automatic formatting

## Technical Considerations

### NSTextAttachment Rendering

```swift
// Superscript number rendering
- Small font size (typically 70% of body text)
- Baseline offset (raise above normal text)
- Different color (optional, often same as text)
- Clickable/tappable area
```

### Auto-Numbering Algorithms

1. **Sequential**: Number based on order in document
2. **Restart per page**: Reset numbering on each page (pagination mode)
3. **Per section**: Optional restart at section boundaries

### Position Tracking Challenges

- Character positions change as text is edited
- Need to update footnote positions on text changes
- Similar to comment position tracking (solved in Feature 014)

### Rendering Strategies

**In-Line Markers**:
- Superscript numbers in the flow of text
- Non-breaking to prevent line wrapping issues

**Display Options**:
1. Bottom of page (pagination mode)
2. Sidebar (editing mode)
3. Popup/sheet on tap
4. Dedicated footnotes section

## iOS Text System

### UIFont and Superscript

```swift
// Create superscript effect
let baseFont = UIFont.preferredFont(forTextStyle: .body)
let superscriptFont = baseFont.withSize(baseFont.pointSize * 0.7)

let attributes: [NSAttributedString.Key: Any] = [
    .font: superscriptFont,
    .baselineOffset: baseFont.pointSize * 0.4
]
```

### Attachment Cell Sizing

- Custom attachment cell for precise positioning
- Match baseline of surrounding text
- Handle different font sizes

## User Experience Patterns

### Creation Patterns

1. **Cursor-based**: Insert at current cursor position
2. **Selection-based**: Attach to selected text range
3. **Automatic**: Parse special syntax (e.g., `[^1]`)

### Editing Patterns

1. **Inline editing**: Edit directly where displayed
2. **Modal editing**: Edit in separate dialog/sheet
3. **Inspector panel**: Edit in sidebar

### Navigation Patterns

1. **Jump to footnote**: From marker to content
2. **Jump to marker**: From content back to text
3. **Next/previous**: Navigate between footnotes

## Implementation Decisions

Based on research, recommended approach:

✅ **Use NSTextAttachment** for markers (proven in comments)
✅ **Superscript numbers** (industry standard)
✅ **Auto-renumbering** (essential UX)
✅ **Modal detail view** (consistent with comments)
✅ **Bottom-of-page rendering** (pagination mode only)
✅ **Simple sequential numbering** (start with basics)

Future enhancements:
- Per-page numbering in pagination mode
- Export to different formats
- Custom footnote symbols (*, †, ‡)
- Footnote/endnote toggle

## Similar Features in Other Apps

### Bear
- Uses hash tags and internal links
- No formal footnote support

### Ulysses
- Markdown-style footnotes: `[^1]`
- Compiled to proper format on export

### iA Writer
- Markdown footnote syntax
- Preview shows formatted footnotes

### Notion
- Inline comments (like our Feature 014)
- No formal footnote system

## References

- [Chicago Manual of Style - Footnotes](https://www.chicagomanualofstyle.org/book/ed17/part3/ch14/psec001.html)
- [Apple TextKit Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextArchitecture/Introduction/Introduction.html)
- [NSTextAttachment Documentation](https://developer.apple.com/documentation/uikit/nstextattachment)
