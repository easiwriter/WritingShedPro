# Feature 016: Auto-Numbering Architecture Redesign Required

## Current Status: FUNDAMENTALLY FLAWED

The current implementation stores paragraph numbers as literal text in the document with a `.paragraphNumber` attribute. This approach is architecturally unsound and causes persistent synchronization bugs.

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
