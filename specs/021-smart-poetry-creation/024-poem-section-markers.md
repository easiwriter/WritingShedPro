# Feature 024: Poem Section Markers

## Overview

Poetry files often contain more than just the poem body. A typical poem file may include:
- **Title** - The poem's title (not analyzed)
- **Epigraph** - A quotation or dedication (not analyzed)
- **Poem Body** - The actual poem (analyzed for metrics)
- **Stanza Numbers** - Optional numbering (not analyzed)
- **Signature** - Author attribution (not analyzed)

Currently, the poetry metrics dashboard analyzes ALL text in a file. This leads to incorrect syllable counts, line counts, and form validation because non-poem text is included.

## Solution: Section Type Attributes

Add a custom NSAttributedString attribute to mark different section types. Text without a section marker (or with `.poem` type) is treated as poem body and included in analysis.

## Data Model

### PoemSectionType Enum

```swift
/// Types of sections that can appear in a poetry file
enum PoemSectionType: String, Codable, CaseIterable {
    case poem         // Default - included in analysis
    case title        // Excluded from analysis, rendered as heading
    case epigraph     // Excluded, rendered in italics
    case signature    // Excluded, rendered smaller/right-aligned
    case stanzaNumber // Excluded, rendered as small centered number
    case dedication   // Excluded, rendered similar to epigraph
}
```

### NSAttributedString.Key Extension

```swift
extension NSAttributedString.Key {
    /// Custom attribute for poem section type
    static let poemSectionType = NSAttributedString.Key("WritingShedPro.PoemSectionType")
}
```

### AttributeValues Extension (Serialization)

```swift
// Add to AttributeValues struct
var poemSectionType: String?
```

## Implementation

### Phase 1: Core Infrastructure

1. **PoemSectionType enum** - Define section types
2. **NSAttributedString.Key extension** - Add `.poemSectionType` key
3. **AttributedStringSerializer updates** - Encode/decode section markers
4. **Unit tests** for serialization round-trip

### Phase 2: Poetry Analysis Updates

1. **PoetryValidator.validate()** - Filter out non-poem sections before analysis
2. **PoetryMetricsDashboard** - Only show poem body in analysis
3. **SyllableCounter** - Already line-based, no changes needed
4. **StressAnalyzer** - Already line-based, no changes needed

Filter logic:
```swift
/// Extract only poem body text, excluding title/epigraph/signature
func extractPoemBody(from attributedText: NSAttributedString) -> String {
    var poemLines: [String] = []
    
    attributedText.enumerateAttribute(.poemSectionType, in: NSRange(location: 0, length: attributedText.length)) { value, range, _ in
        let sectionType = (value as? String).flatMap { PoemSectionType(rawValue: $0) } ?? .poem
        
        if sectionType == .poem {
            let substring = attributedText.attributedSubstring(from: range).string
            poemLines.append(substring)
        }
    }
    
    return poemLines.joined()
}
```

### Phase 3: UI - Mark Sections

1. **Context menu** - "Mark as Title/Epigraph/Signature/Stanza Number"
2. **Format menu item** - Add "Section Type" submenu to insert menu
3. **Visual feedback** - Dimmed or styled text for non-poem sections
4. **Clear marking** - "Mark as Poem" to remove section type (restore default)

UI options:
- Quick toolbar button (new icon) with section type picker
- Long-press on format button
- Context menu on selection

### Phase 4: Visual Styling

Section-specific styling (optional visual cues):
```swift
switch sectionType {
case .title:
    // Larger font, bold, no analysis
    return [.font: UIFont.preferredFont(forTextStyle: .title1)]
case .epigraph:
    // Italic, dimmed, indented
    return [.font: UIFont.italicSystemFont(ofSize: baseSize), 
            .foregroundColor: UIColor.secondaryLabel]
case .signature:
    // Smaller, right-aligned
    return [.paragraphStyle: rightAlignedStyle]
case .stanzaNumber:
    // Small, centered
    return [.font: UIFont.preferredFont(forTextStyle: .caption1)]
case .dedication:
    // Similar to epigraph
    return [.font: UIFont.italicSystemFont(ofSize: baseSize)]
case .poem:
    // Normal formatting, no overrides
    return [:]
}
```

### Phase 5: PDF Export Integration

Update PDF rendering to respect section types:
- Title rendered prominently at top
- Epigraph rendered in italics
- Poem body rendered normally
- Signature rendered at bottom

## UI Flow

### Marking a Section

1. User selects text (e.g., poem title)
2. Opens context menu or uses toolbar
3. Selects "Mark as Title"
4. Text gets `.poemSectionType: "title"` attribute
5. Visual styling updates (optional)
6. Poetry metrics exclude this text

### Clearing a Section Marker

1. User selects marked text
2. Context menu shows "Mark as Poem" or "Clear Section Marker"
3. Attribute removed, text analyzed normally again

## Visual Indicators

In edit mode, marked sections could show:
- Subtle background tint (very light gray for non-poem)
- Small icon in margin indicating section type
- Different text color (secondary label)

These should be subtle so they don't distract from writing.

## Edge Cases

1. **Empty selection** - Show alert: "Select text to mark as a section"
2. **Selection spans multiple sections** - Apply new type to entire selection
3. **Partial line selection** - Extend to full lines? Or allow inline?
4. **Stanza numbers in middle of text** - Allow inline marking

Recommendation: Section markers apply to **complete lines** to avoid fragmentation. If selection doesn't span complete lines, auto-extend to line boundaries.

## Serialization

### Encode
```swift
if let sectionType = attributes[.poemSectionType] as? String {
    attributeValues.poemSectionType = sectionType
}
```

### Decode
```swift
if let sectionType = jsonAttributes.poemSectionType {
    attributes[.poemSectionType] = sectionType
}
```

## Testing

1. **Unit tests** - Serialization round-trip
2. **Unit tests** - extractPoemBody() filtering
3. **Integration** - Mark section → metrics exclude it
4. **UI tests** - Context menu appears, marking works

## Future Enhancements

1. **Auto-detect title** - First line before blank line could be title
2. **Auto-detect epigraph** - Lines in quotes before poem
3. **Template presets** - "Apply standard poem layout"
4. **Section statistics** - Show separate counts for each section

## Dependencies

- Feature 005: Text Formatting (NSAttributedString system)
- Feature 014: Comments (attribute pattern)
- Feature 021: Smart Poetry (metrics dashboard)
- AttributedStringSerializer

## Files to Modify

1. `Models/PoemSectionType.swift` (new)
2. `Models/TextStyle.swift` or new file for key extension
3. `Services/AttributedStringSerializer.swift`
4. `Services/PoetryValidator.swift`
5. `Views/Poetry/PoetryMetricsDashboard.swift`
6. `Views/FileEditView.swift` (context menu)

## Complexity Estimate

- Phase 1 (Core): ~3 hours
- Phase 2 (Analysis): ~2 hours
- Phase 3 (UI): ~4 hours
- Phase 4 (Styling): ~2 hours
- Phase 5 (Export): ~2 hours

**Total: ~13 hours**

## Success Criteria

1. User can mark text as Title/Epigraph/Signature
2. Poetry metrics only analyze poem body
3. Marked sections persist across save/load
4. Visual feedback shows which text is excluded
5. Works with all poetry forms
