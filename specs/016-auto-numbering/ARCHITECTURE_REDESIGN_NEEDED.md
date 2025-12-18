# Feature 016: Auto-Numbering Architecture - Dynamic Rendering Implementation

## Status: ✅ IMPLEMENTED

The auto-numbering feature has been redesigned with a proper architecture where numbers are rendered dynamically at display time, never stored in the document.

## Implementation Summary

### Core Architecture

**Numbers are VIRTUAL** - they exist only at render time, like line numbers in a code editor.

1. **Document Storage**: Contains only user text with style metadata (`.textStyle` attribute)
2. **Dynamic Rendering**: Custom `NumberingLayoutManager` draws numbers in the left margin
3. **No State Synchronization**: Numbers can't get out of sync because they're calculated from current document state

### Key Components

#### NumberingLayoutManager
Custom `NSLayoutManager` subclass that:
- Overrides `drawBackground(forGlyphRange:at:)` to draw paragraph numbers
- Analyzes paragraphs in visible range
- Counts paragraphs for each numbered style
- Formats and renders numbers in the left margin (60pt space)
- Uses existing `NumberFormat` enum from Phase 005

#### FormattedTextEditor Updates
- Creates text view with `NumberingLayoutManager` instead of default
- Passes `Project` reference to layout manager for style access
- Adds 60pt left inset to text container for number space

#### FileEditView Updates
- Passes `project` parameter to all `FormattedTextEditor` instances
- No other changes needed - numbers work automatically

### How It Works

1. **Paragraph Analysis**: Layout manager enumerates visible paragraphs
2. **Style Detection**: Checks `.textStyle` attribute to get paragraph style
3. **Number Format**: Uses `style.numberFormat` (from existing NumberFormat enum)
4. **Counter Management**: Maintains counters per style (reset for each render)
5. **Rendering**: Draws formatted numbers in left margin with right alignment

### Advantages

✅ **No synchronization bugs** - Numbers always match current document state
✅ **Clean separation** - Editing never touches numbers (they don't exist in storage)
✅ **Simple implementation** - Leverages existing `NumberFormat` enum
✅ **Performance** - Only renders visible paragraphs
✅ **Copy/Paste** - Numbers automatically excluded (not in document)

### User Experience

- Numbers appear automatically for paragraphs with `numberFormat` != `.none`
- Numbers update instantly as you type/edit/delete
- Backspace/delete work normally - no special handling needed
- Numbers are dimmed (50% opacity) to distinguish from user content
- No cursor navigation issues (numbers aren't in the text)

### Current Limitations

1. **Simple counter only** - Each style counts from 1, no hierarchical numbering yet
2. **No reset behavior** - Counters don't reset based on context (feature for later)
3. **No custom start numbers** - Always starts at 1 (could add to style model)
4. **Basic formatting** - Uses existing NumberFormat enum formats only

### Future Enhancements

These can be added incrementally without architectural changes:

- **Starting numbers**: Add `startingNumber` property to TextStyleModel
- **Hierarchical numbering**: Track parent/child style relationships
- **Reset behavior**: Reset counters at chapter/section boundaries  
- **Custom adornments**: Extend NumberFormat or add formatting options
- **Multi-level lists**: Support nested counters (1.1, 1.1.1, etc.)

## Migration Notes

**No migration needed!** The system uses existing `numberFormat` property in `TextStyleModel`. Any paragraph with `numberFormat` != `.none` will automatically show numbers.

To enable numbering for a style:
```swift
style.numberFormat = .decimal  // Shows: 1. 2. 3...
// or .uppercaseRoman, .lowercaseLetter, .bulletSymbols, etc.
```

## Implementation Files

- `/WrtingShedPro/Writing Shed Pro/Views/Components/NumberingLayoutManager.swift` - New
- `/WrtingShedPro/Writing Shed Pro/Views/Components/FormattedTextEditor.swift` - Modified
- `/WrtingShedPro/Writing Shed Pro/Views/FileEditView.swift` - Modified

## Testing

To test:
1. Open any document
2. Set a paragraph style's `numberFormat` to `.decimal`
3. Type multiple paragraphs in that style
4. Numbers appear automatically in the left margin
5. Delete paragraphs - numbers renumber instantly
6. Copy text - numbers not included

## Comparison to Previous Attempt

| Aspect | Previous (Broken) | Current (Fixed) |
|--------|------------------|----------------|
| Storage | Numbers in document as text | No storage, rendered dynamically |
| Sync | Constant sync bugs | No sync needed |
| Editing | Special backspace handling | Normal editing works |
| Copy/Paste | Numbers included | Numbers excluded |
| Performance | Text manipulation overhead | Render-only, fast |
| Complexity | High (state management) | Low (pure rendering) |

---

*Document updated: December 18, 2025*
*Implementation complete - working dynamic numbering*

## Critical Problems

1. **Numbers stored as text** - "(1) ", "(2) " exist in the attributed string
2. **State synchronization** - Numbers can become stale/wrong after edits
3. **Unpredictable behavior** - Deletion, insertion, and style changes cause number drift
4. **Cannot be reliably cleaned up** - Once numbers are in the document, they persist incorrectly

## Required Architecture

### Numbers as Virtual/Rendered Content

Numbers should **NEVER** be stored in the document. Instead:

1. **Document stores only user content + style metadata**
   - Text: "one\ntwo\nthree"
   - Style attributes: `.textStyle = "Body"` (with numbering settings)
   
2. **Numbers generated at render time**
   - UITextView subclass overrides drawing
   - Calculates paragraph count for each numbered style
   - Renders numbers in the margin/gutter
   - OR: Inserts numbers temporarily in display layer only

3. **Counter management separate from document**
   - NumberingManager tracks counters per document/style
   - Counters reset/increment based on paragraph analysis
   - Never stored in attributed string

### Implementation Approaches

#### Option A: Margin/Gutter Rendering (Preferred)
- Custom UITextView subclass
- Override `draw(_:)` to render numbers in left margin
- Adjust `textContainerInset` to make space
- Numbers completely separate from text storage
- **Pros**: Clean separation, no text manipulation
- **Cons**: More complex rendering code

#### Option B: Temporary Display Insertion
- Numbers inserted in layout manager's display storage
- Never touch actual text storage
- Removed before any editing operations
- **Pros**: Uses existing text rendering
- **Cons**: Must carefully manage insertion/removal timing

#### Option C: Attributed String with Exclusion Paths
- Store minimal metadata in attributes
- Use text container exclusion paths for number space
- Render numbers as overlay views
- **Pros**: Flexible layout
- **Cons**: Complex coordinate management

## Migration Path

### Phase 1: Clean Up Current Implementation
1. Remove all existing numbers from documents
2. Keep only style metadata
3. Add migration code to strip numbers on load

### Phase 2: Implement Virtual Numbering
1. Create CustomTextView subclass with number rendering
2. Implement paragraph counting logic
3. Add number formatting and positioning

### Phase 3: Edit Behavior
1. Cursor navigation skips number area
2. Backspace/delete never touches numbers (they don't exist in storage)
3. Copy/paste excludes numbers

### Phase 4: Export
1. Generate numbers when exporting to RTF/PDF/HTML
2. Use proper list markup (`<ol>`, `<ul>`)

## Immediate Workaround (Not Recommended)

If virtual rendering is not feasible immediately:

1. **Always regenerate numbers after ANY edit**
   - Strip all existing numbers
   - Recalculate and reinsert fresh
   - Much higher performance cost

2. **Add validation on document load**
   - Check if numbers match expected values
   - Regenerate if mismatched

3. **Never allow manual editing of numbers**
   - Make number characters read-only
   - Force delete to remove entire number

## Recommendation

**Do not proceed with Phase 6 until architecture is redesigned.** The current approach will continue generating bugs indefinitely. Each fix creates new edge cases because the fundamental design is wrong.

A proper implementation with virtual numbers will:
- Be more reliable
- Perform better (no text manipulation)
- Be easier to maintain
- Support more advanced features (multi-level lists, etc.)

**Estimated effort**: 2-3 days for complete redesign with virtual rendering.

---

*Document created: December 17, 2025*
*After 4+ hours of attempting to fix a fundamentally broken architecture*
