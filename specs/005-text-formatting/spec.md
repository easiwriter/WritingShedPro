# Phase 005: Text Formatting

**Status**: Planning  
**Created**: 2025-10-26  
**Updated**: 2025-10-26

## Overview

This phase will implement text formatting capabilities for the text editor in Writing Shed Pro.

## Goals

There are two classes of actions. 

First, and this is not really formatting, selecting some text, either by double clicking or dragging, should display an EditMenu containing the commands:

 - Cut
 - Copy
 - Paste
 - Select
 - Select Paragraph
 - Select All
 - Look Up
 - Translate
 - Search Web
 - Autofill
 - Share
 - divider
 - Edit Style

 Second, there should be a toolbar displayed above the keyboard containing the following commands:

 - Paragraph (represented by the paragraph character as in pages)
 - B for bold
 - I for italic
 - U (underlined) for underline
 - S (with a bar through it) for strike out
 - the symbol for a bulleted list
 - the symbol denoting insertion of such things as page break, footnote etc

 The paragraph command displays a popup list of NSFont.TextStyle constants. Choosing one of these formats the current paragraph according to the attributes of the selected text style. The default style for a new document is body, 

 The Edit Styles command displays a style editing view where all the attributes of the paragraph can be changed.

<img src="../../images/Paragraph%20Style%20Editor.png" alt="Style Editor Interface" width="30%">

*Figure 1: Style editor showing font, size, formatting options (Bold, Italic, Underline, Strikethrough), text color, text alignment, indentation, margins, and spacing controls.*

## Scope

### In Scope

**Edit Menu (Text Selection Actions)**
- Standard system actions: Cut, Copy, Paste, Select, Select All
- Extended selection: Select Paragraph
- System services: Look Up, Translate, Search Web, Autofill, Share
- Custom action: Edit Style

**Formatting Toolbar (Above Keyboard)**
- Paragraph style picker (UIFont.TextStyle options)
- Character formatting: Bold, Italic, Underline, Strikethrough
- List formatting: Bulleted lists
- Insertions: Page breaks, footnotes, etc.

**Style Editor**
- Font family and typeface selection
- Font size control
- Character attributes: Bold, Italic, Underline, Strikethrough
- Text color selection
- Paragraph alignment: Left, Center, Right, Justified
- First line indent
- Left and right margins
- Line spacing
- Space before/after paragraphs

**Text Styles**
- UIFont.TextStyle options:
  - Body (default)
  - Headline
  - Title 1, Title 2, Title 3
  - Subheadline
  - Callout
  - Caption 1, Caption 2
  - Footnote
  - Large Title

### Out of Scope

- Tables
- Images inline in text
- Custom fonts beyond system fonts
- Columns
- Track changes
- Comments/annotations
- Export to Word/PDF (future phase)

## Technical Approach

### Text Editor Component
- **Replace SwiftUI TextEditor** with UITextView wrapper
  - SwiftUI's TextEditor doesn't support NSAttributedString
  - Need UIViewRepresentable wrapper for UITextView
  - Maintain SwiftUI-like binding for formatted content

### Data Storage
- **NSAttributedString** for in-memory representation
- **Serialization Format**:
  - Option 1: NSKeyedArchiver (native, but binary)
  - Option 2: Custom JSON with format runs
  - Option 3: RTF (readable, widely supported)
- Store in Version model (new property: `formattedContent`)
- Maintain plain text `content` for backward compatibility

### Formatting Application
- **Character Attributes**: Apply to selected range
  - Bold: `.font` with bold trait
  - Italic: `.font` with italic trait
  - Underline: `.underlineStyle`
  - Strikethrough: `.strikethroughStyle`
  - Color: `.foregroundColor`

- **Paragraph Attributes**: Apply to entire paragraph(s)
  - Text style: `.font` (UIFont.TextStyle)
  - Alignment: `.paragraphStyle.alignment`
  - Indents: `.paragraphStyle.firstLineHeadIndent`, `.headIndent`, `.tailIndent`
  - Spacing: `.paragraphStyle.lineSpacing`, `.paragraphSpacing`, `.paragraphSpacingBefore`

### Undo/Redo Integration
- Use existing Command pattern
- `FormatApplyCommand`: Stores old/new attributed strings for range
- `FormatRemoveCommand`: Strips formatting from range
- Commands work with attributed text, not plain text

### CloudKit Sync
- Convert NSAttributedString to storable format (Data)
- Sync as separate property from plain content
- Conflict resolution: Most recent wins (by timestamp)

## User Interface

### Edit Menu (on Text Selection)
- Appears automatically when text is selected
- Custom action "Edit Style" added to system menu
- Uses `.textSelection()` or UIMenuController customization

### Formatting Toolbar
- **Position**: InputAccessoryView (above keyboard on iOS)
- **Layout**: Horizontal scroll if needed
- **Buttons**:
  1. **Paragraph Style** (¶ icon) → Shows style picker sheet
  2. **Bold** (B) → Toggle bold on selection
  3. **Italic** (I) → Toggle italic on selection
  4. **Underline** (U) → Toggle underline on selection
  5. **Strikethrough** (S̶) → Toggle strikethrough on selection
  6. **Bullet List** (•) → Toggle bullet list for paragraph
  7. **Insert** (+) → Show insertion menu

### Style Picker Sheet
- Modal sheet from bottom
- Lists all UIFont.TextStyle options
- Shows preview of each style
- Applies to current paragraph(s)

### Style Editor
- Full-screen modal (presented from Edit Menu)
- Sections:
  - Font & Size
  - Character Formatting
  - Text Color
  - Alignment
  - Indentation & Margins
  - Spacing
- Live preview at top
- Cancel/Done buttons

## Implementation Notes

### Key Challenges

1. **UITextView Wrapper**
   - Need to create robust SwiftUI wrapper
   - Handle delegate methods for text changes
   - Maintain undo/redo integration
   - Handle keyboard dismissal and focus

2. **Attributed String Persistence**
   - NSAttributedString isn't directly Codable
   - Need custom serialization
   - Consider RTF format for human-readability
   - Must work with SwiftData and CloudKit

3. **Typing Coalescing with Formatting**
   - Current undo system coalesces plain text typing
   - Need to preserve formatting during coalescing
   - Format changes should flush typing buffer

4. **Mac Catalyst Considerations**
   - InputAccessoryView behaves differently on Mac
   - May need alternative toolbar placement for Mac
   - Keyboard shortcuts (Cmd+B, Cmd+I, etc.)

### Dependencies on Existing Code

- **TextFileUndoManager**: Will need to work with NSAttributedString
- **FormatApplyCommand/FormatRemoveCommand**: Need full implementation
- **Version model**: Add formattedContent property
- **FileEditView**: Replace TextEditor with UITextView wrapper

### Backward Compatibility

- Existing files have plain `content` only
- New files will have both `content` (plain) and `formattedContent`
- On first edit, convert plain to attributed
- Always maintain plain text version for search/export

## Testing Strategy

### Unit Tests
- NSAttributedString serialization/deserialization
- Format application to text ranges
- Paragraph style application
- Format removal
- Undo/redo with formatted text

### Integration Tests
- Formatting + undo/redo system
- CloudKit sync with formatted content
- Backward compatibility (plain text files)
- Version model with formatted content

### UI Tests
- Toolbar button interactions
- Style picker selection
- Style editor changes
- Edit menu appearance and selection

### Manual Testing
- Type, format, undo, redo workflow
- Multiple devices sync
- Large documents with heavy formatting
- Performance with long documents

## Success Criteria

### Functional
- ✅ User can select text and see Edit Menu with custom "Edit Style" option
- ✅ Formatting toolbar appears above keyboard
- ✅ Bold, Italic, Underline, Strikethrough can be applied to selected text
- ✅ Paragraph styles can be applied from style picker
- ✅ Style editor allows full customization of paragraph formatting
- ✅ Formatted text persists across app restarts
- ✅ Formatted text syncs via CloudKit
- ✅ Formatting changes can be undone/redone
- ✅ Plain text files can be opened and formatted

### Performance
- ✅ No lag when typing in formatted documents
- ✅ Style application is immediate (< 100ms)
- ✅ Documents with 10,000+ words handle formatting smoothly

### Quality
- ✅ No data loss when syncing formatted content
- ✅ No crashes with heavily formatted text
- ✅ Formatting preserved during undo/redo
- ✅ All tests passing (unit, integration, UI)

## Dependencies

- Phase 004 (Undo/Redo System) - completed ✅
- Existing text editor infrastructure

## Notes

Phase specification to be completed with detailed requirements.
