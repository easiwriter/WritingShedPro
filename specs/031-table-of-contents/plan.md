# Feature 031: Table of Contents

## Overview

Automatic generation of a Table of Contents (TOC) in the Front Matter that lists headings from the manuscript with page numbers.

## User Requirements

1. **Style-based inclusion**: Heading styles have an "Include in TOC" option and a TOC level (for indentation)
2. **Auto-generation**: TOC is generated when the TOC file is opened
3. **Live page numbers**: Page numbers shown in editor based on current page setup
4. **Export support**: Page numbers recalculated for PDF/print export
5. **Non-editable**: TOC content is auto-generated, not user-editable
6. **Configurable settings**: Title, separator, and indent amount

## Data Model Changes

### TextStyleModel Additions

```swift
// Add to TextStyleModel
var includeInTOC: Bool = false    // Whether this style appears in TOC
var tocLevel: Int = 0             // Indent level (0-5), 0 = no indent
```

### TOCSettings Model

```swift
struct TOCSettings: Codable {
    var title: String = "Contents"           // Heading displayed at top
    var separator: String = "..."            // Between heading and page number
    var indentPoints: CGFloat = 20           // Indent per level in points
    var titleStyleName: String = "title"     // Style for TOC title
    var entryStyleName: String = "body"      // Style for TOC entries
}
```

Storage: Stored in the TOC TextFile's metadata (new `tocSettings` property on TextFile)

## Implementation Phases

### Phase 1: Data Model
- [ ] Add `includeInTOC` and `tocLevel` to TextStyleModel
- [ ] Add `tocSettings` property to TextFile
- [ ] Create TOCSettings Codable struct
- [ ] Update serialization for .wsp export/import

### Phase 2: Style Editor
- [ ] Add "Table of Contents" section to TextStyleEditorView
- [ ] Checkbox for "Include in Table of Contents"
- [ ] Stepper/picker for TOC Level (0-5)
- [ ] Only show for heading-category styles

### Phase 3: TOC Generation Service
- [ ] Create TOCGenerationService
- [ ] Scan manuscript files in order: Front Matter → Body → Back Matter
- [ ] Find paragraphs with TOC-enabled styles
- [ ] Extract heading text (first line or full paragraph?)
- [ ] Calculate page numbers using VirtualPageScrollView pagination

### Phase 4: TOC File Detection
- [ ] Detect "Table of Contents" or "Contents" file in Front Matter
- [ ] Mark file as TOC type (new TextFile property?)
- [ ] Trigger regeneration when file is opened

### Phase 5: TOC Rendering
- [ ] Generate attributed string with proper formatting
- [ ] Title line with configured style
- [ ] Entry lines: [indent][heading text][separator][page number]
- [ ] Right-align page numbers using paragraph tab stops
- [ ] Apply configured entry style

### Phase 6: Settings UI
- [ ] Add settings button/popover for TOC file
- [ ] Configure: title, separator, indent amount
- [ ] Preview of settings effect

### Phase 7: Export Integration
- [ ] Recalculate page numbers during PDF/print export
- [ ] Account for export-specific page setup

## TOC Entry Format

```
Contents

Chapter One.............................1
    Scene One...........................3
    Scene Two...........................7
Chapter Two............................15
    Scene One..........................17
```

- Left margin: Heading text with level-based indentation
- Right side: Page number, right-aligned
- Separator: Dots/dashes between text and number (configurable)

## Page Number Calculation

Use the existing pagination engine from VirtualPageScrollView:
1. Assemble full manuscript (Front Matter + Body + Back Matter)
2. Paginate using current page setup
3. Find page containing each heading's character position
4. Cache results for performance

## File Scanning Order

1. **Front Matter** (excluding TOC file itself to avoid circular reference)
2. **Body/Content folder** (All Poems, All Chapters, All Sections, etc.)
3. **Back Matter**

Files within each folder ordered by `userOrder`.

## Default Settings

- Title: "Contents"
- Separator: "." (repeated to fill space)
- Indent per level: 20 points
- Title style: "title" or first heading style
- Entry style: "body"

## Edge Cases

1. **No headings marked**: Show message "No headings configured for TOC"
2. **Empty manuscript**: Show just the title
3. **Very long headings**: Truncate or wrap appropriately
4. **Page numbers overflow**: Handle manuscripts with 1000+ pages

## UI/UX

- TOC file appears read-only (no editing cursor)
- "Refresh" button available if needed
- Settings accessible via toolbar or context menu
- Visual indicator that file is auto-generated

## Testing

- [ ] Test TOC generation with various heading configurations
- [ ] Test page number accuracy across different page setups
- [ ] Test .wsp export/import of TOC settings
- [ ] Test style changes trigger TOC update
- [ ] Performance test with large manuscripts

## Dependencies

- VirtualPageScrollView pagination engine
- ManuscriptAssemblyService for file ordering
- TextStyleModel and StyleSheet system

## Future Enhancements

### Front Matter Roman Numerals
When generating a complete document (PDF/print export), front matter pages should be numbered using **lowercase roman numerals** (i, ii, iii, iv, ...). The body content starts at page 1 with Arabic numerals. The TOC should reflect this:

```
Contents

Preface.............................iii
Acknowledgments......................iv

Chapter One...........................1
Chapter Two..........................15
```

Implementation notes:
- Page numbering style is a property of the manuscript section
- Front Matter = lowercase roman (i, ii, iii)
- Body = Arabic (1, 2, 3)
- Back Matter = continues Arabic numbering from body

### Back Matter in TOC
Back matter files (Endnotes, Glossary, Bibliography, Index) should:
1. **Appear in the Table of Contents** - scanned and included like body files
2. **Include page numbers** - calculated as part of complete manuscript pagination
3. Be listed after body content entries

The TOC generation should include Back Matter section when scanning for headings:
- Endnotes file (if exists and enabled)
- Glossary file (if exists and enabled)
- Bibliography/References file (if exists and enabled)
- Index file (if exists and enabled)

This means `calculatePageNumbers()` must assemble the complete manuscript including back matter to get accurate page positions for all entries.
