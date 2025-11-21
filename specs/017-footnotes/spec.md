# Feature 017: Footnotes

## Overview
Writing Shed Pro supports basic footnotes with simple sequential numbering.

### Core Functionality
- **Numbering**: Sequential integers (1, 2, 3...) starting from 1 at document start
- **Display**: Superscript numbers in text that look like tappable buttons
- **Insertion**: Toolbar button with `number.circle` icon opens text editor
- **Editing**: Tapping a footnote marker shows editing dialog
- **List Access**: "Footnotes..." menu item (with ellipsis) shows all footnotes
- **Endnote Mode**: Document-level setting to display all footnotes at document end

### Pagination Mode
- **Footnote Mode**: Display at bottom of page where referenced
- **Endnote Mode**: Display at document end
- **Separator**: Standard industry separator (1.5-inch line, 10pt space above)
- **Overflow**: Professional typesetting rules when footnotes fill page:
  - Minimum 2 lines of body text above footnotes
  - Split long footnotes to next page with continuation indicator
  - Maintain proper spacing and formatting

### Deferred to Feature 018
Advanced numbering formats (1., (1), bullets, alphabetic) will be part of the comprehensive auto-numbering system in Feature 018.

## User Stories

### As a writer, I want to...
1. Insert footnotes at any point in my document to add references or explanatory notes
2. See footnotes numbered automatically (1, 2, 3...) so I don't have to track numbering
3. Have footnotes renumber automatically when I add or delete them
4. Tap a footnote marker to edit its content
5. See all footnotes in a list view to review and manage them
6. Choose between footnotes (bottom of page) and endnotes (end of document)
7. See footnotes properly formatted at page bottom in pagination mode
8. Export documents with correctly formatted footnotes

## Technical Requirements

### Core Components
- FootnoteModel (SwiftData) - stores footnote content
- FootnoteAttachment (NSTextAttachment) - superscript markers
- FootnoteManager - CRUD operations and numbering logic
- FootnoteInsertionHelper - insert/update markers
- FootnoteDetailView - edit single footnote
- FootnotesListView - view all footnotes

### Numbering Logic
- Sequential numbering: 1, 2, 3...
- Auto-renumber on insert/delete
- Maintain document order
- Update all markers when numbering changes

### Pagination Requirements
- Render footnotes at page bottom (footnote mode) or document end (endnote mode)
- Standard separator: 1.5-inch horizontal line, 10pt space above
- Professional overflow handling:
  - Minimum 2 lines of body text above footnotes
  - Split long footnotes with "(continued)" indicator
  - Proper spacing and formatting

### Serialization
- Extend AttributedStringSerializer for FootnoteAttachment
- Store footnote ID and number in attributes
- Preserve footnotes across save/load cycles

## Data Model
See `data-model.md`

## UI/UX Requirements

### Toolbar Button
- Icon: `number.circle`
- Action: Opens footnote text editor
- Position: In "Insert" menu alongside images and comments

### Menu Item
- Label: "Footnotes..." (with ellipsis)
- Action: Shows list of all footnotes
- Position: Replace current footnote command in formatting toolbar

### In-Text Marker
- Display: Superscript number (¹, ², ³...)
- Style: Button-like appearance (rounded background, subtle shadow)
- Color: Blue to indicate interactivity
- Tap Action: Opens editing dialog

### Editing Dialog
- Text editor for footnote content
- Save/Cancel buttons
- Delete option
- Shows footnote number

### Footnotes List
- All footnotes in document order
- Shows number, preview text, and location
- Swipe actions: Edit, Delete
- Tap to jump to marker in text

### Pagination Display
- **Footnote Mode**:
  - Separator line above footnotes
  - Footnotes at bottom of page
  - Proper spacing from body text
- **Endnote Mode**:
  - "Endnotes" heading
  - All footnotes at document end
  - Grouped by chapter/section (future)

## Implementation Plan
See `plan.md` (updated to reflect simplified scope)

## Testing Requirements

### Unit Tests
- FootnoteModel creation and CRUD operations
- Auto-renumbering logic (insert, delete, reorder)
- FootnoteAttachment rendering
- Serialization/deserialization round-trip
- FootnoteManager operations

### Integration Tests
- Insert footnote → marker appears → tap marker → edit dialog
- Delete footnote → renumbering occurs → markers update
- Multiple footnotes → correct sequential numbering
- Footnote/endnote mode switching
- Export with footnotes

### Manual Testing
- Visual appearance of markers (button-like)
- Pagination display with various footnote counts
- Overflow handling (long footnotes, many footnotes)
- Performance with 50+ footnotes
- CloudKit sync

### Edge Cases
- Footnote at document start/end
- Very long footnote text (multiple paragraphs)
- Footnote page overflow scenarios
- Rapid add/delete operations
- Undo/redo with footnotes

## Open Questions

### Resolved
1. ✅ Numbering format: Simple 1, 2, 3... (advanced formats in Feature 018)
2. ✅ Endnote option: Document-level setting
3. ✅ Marker display: Superscript numbers with button styling
4. ✅ Overflow rules: Professional typesetting standards
5. ✅ Separator: Industry standard (1.5-inch line, 10pt space)

### Resolved in V1
6. ✅ Rich text formatting: Yes, support bold, italic, and other text formatting in footnote content
7. ✅ Maximum length: No imposed limit - writers should be sensible
8. ✅ Image support: Text only in V1 (images can be future enhancement)
9. ✅ Keyboard shortcut: Not needed for V1
10. ✅ Delete behavior: Footnotes go to Trash and can be restored, marked as footnotes in Trash view

## Related Features
- Feature 014: Comments (similar attachment-based system)
- Feature 005: Text Formatting
- Feature 003: Text File Creation

## Status
**Planning** - Created 2025-11-21

## Notes
[Add implementation notes here]
