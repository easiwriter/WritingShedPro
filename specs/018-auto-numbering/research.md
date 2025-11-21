# Feature 018: Automatic Paragraph Numbering - Research

## Industry Standards

### Document Numbering Conventions

#### Legal Documents
- **Pattern**: Hierarchical with periods (1, 1.1, 1.1.1)
- **Adornment**: Typically period after number (1.)
- **Nesting**: Up to 5-6 levels common
- **Reset**: Never resets within document
- **Example**:
  ```
  1. Introduction
  1.1. Background
  1.2. Purpose
  2. Terms and Conditions
  2.1. Definitions
  2.1.1. "Agreement"
  2.1.2. "Party"
  ```

#### Technical Manuals
- **Pattern**: Hierarchical with periods or dashes
- **Adornment**: Various (1., 1-, 1), (1))
- **Nesting**: Often 4-5 levels
- **Reset**: May reset at chapters
- **Example**:
  ```
  1. Installation
  1-1. System Requirements
  1-2. Installation Steps
  2. Configuration
  2-1. Basic Setup
  ```

#### Academic Papers
- **Pattern**: Roman numerals for major sections, letters for subsections
- **Adornment**: Periods and parentheses
- **Nesting**: Typically 3 levels
- **Example**:
  ```
  I. Introduction
     A. Background
     B. Objectives
  II. Methodology
     A. Research Design
        1. Participants
        2. Materials
  ```

#### Outlines
- **Pattern**: Mixed formats per level
- **Format Sequence**: I, A, 1, a, i
- **Adornment**: Periods and parentheses
- **Example**:
  ```
  I. Main Topic
     A. Subtopic
        1. Detail
           a. Sub-detail
              i. Fine detail
  ```

### List Formatting Standards

#### Bulleted Lists
- **Level 1**: Filled circle (•)
- **Level 2**: Hollow circle (◦)
- **Level 3**: Filled square (▪)
- **Indentation**: 0.5 inches per level
- **Spacing**: Consistent with paragraph spacing

#### Numbered Lists
- **Level 1**: Arabic numerals (1, 2, 3)
- **Level 2**: Lowercase letters (a, b, c)
- **Level 3**: Lowercase roman (i, ii, iii)
- **Adornment**: Period after number/letter
- **Alignment**: Numbers right-aligned, text left-aligned

## Technical Implementation Research

### NSAttributedString List Support
iOS/macOS have built-in list support via NSParagraphStyle:

```swift
// NSParagraphStyle list properties
var textLists: [NSTextList]
var headIndent: CGFloat
var firstLineHeadIndent: CGFloat
var tabStops: [NSTextTab]

// NSTextList
class NSTextList {
    enum MarkerFormat {
        case box, check, circle, diamond, disc, hyphen, square, 
             decimal, lowercaseAlpha, uppercaseAlpha, 
             lowercaseRoman, uppercaseRoman
    }
    
    init(markerFormat: MarkerFormat, options: Int)
    
    func marker(forItemNumber itemNumber: Int) -> String
}
```

However, NSTextList has limitations:
- Fixed format per list
- No custom adornments
- Limited hierarchy support
- Not compatible with SwiftUI TextEditor

**Decision**: Build custom numbering system for full control and SwiftUI compatibility.

### Number Format Conversion Algorithms

#### Roman Numerals
Standard algorithm using subtraction rules:

```swift
func toRoman(_ value: Int) -> String {
    let romanMap: [(Int, String)] = [
        (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
        (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
        (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")
    ]
    
    var result = ""
    var remaining = value
    
    for (num, roman) in romanMap {
        while remaining >= num {
            result += roman
            remaining -= num
        }
    }
    
    return result
}
```

**Range**: Works for 1-3999 (standard roman numeral range)
**Performance**: O(1) constant time

#### Alphabetic Numbering
Excel-style column naming:

```swift
func toAlphabetic(_ value: Int) -> String {
    let offset = UnicodeScalar("A").value
    var result = ""
    var num = value - 1
    
    repeat {
        let char = UnicodeScalar(offset + UInt32(num % 26))!
        result = String(char) + result
        num = num / 26 - 1
    } while num >= 0
    
    return result
}
```

**Sequence**: A, B, C... Z, AA, AB, AC... ZZ, AAA...
**Performance**: O(log₂₆(n)) where n is the number

### State Management Patterns

#### Counter Tracking
Need to maintain counters for:
- Each paragraph style
- Each nesting level
- Per document

Options:
1. **Flat Dictionary**: `[String: Int]` - One counter per style
   - Simple but doesn't handle nesting
2. **Nested Dictionary**: `[String: [Int]]` - Array of counters per style
   - Handles nesting, chosen approach
3. **Tree Structure**: Full paragraph tree
   - Most powerful but complex

**Decision**: Nested dictionary (`[String: [Int]]`) - good balance of power and simplicity.

#### Update Triggers
Numbering must update when:
- New paragraph created
- Paragraph deleted
- Paragraph moved/reordered
- Style changed
- Numbering settings changed

**Strategy**: 
- Incremental updates for single changes
- Full renumbering for complex changes (moves, multiple deletes)
- Debounce rapid changes (100ms)

### Performance Considerations

#### Renumbering Cost
For a document with N paragraphs:
- **Full renumber**: O(N) - iterate all paragraphs
- **Incremental update**: O(k) where k = affected paragraphs
- **Target**: <16ms for 60fps smooth editing

**Optimization strategies**:
1. Only renumber visible paragraphs immediately
2. Batch renumber off-screen paragraphs
3. Cache formatted numbers
4. Invalidate cache only when needed

#### Memory Usage
Per-paragraph numbering info:
```swift
struct ParagraphNumberingInfo {
    var formattedNumber: String        // ~8 bytes + string data
    var rawValue: Int                  // 8 bytes
    var level: Int                     // 8 bytes
    var styleID: String                // ~8 bytes + string data
    var isOverridden: Bool             // 1 byte
    var overrideValue: String?         // ~8 bytes + string data
}
// Total: ~41+ bytes per paragraph
```

For 10,000 paragraph document: ~410KB (acceptable)

### Export Format Support

#### RTF (Rich Text Format)
RTF has native list support:

```
{\pntext\f0 1.\tab}{\*\pn\pnlvlbody\pnf0\pnindent0\pnstart1\pndec}
\fi-360\li720 First item\par

{\pntext\f0 2.\tab}{\*\pn\pnlvlbody\pnf0\pnindent0\pnstart2\pndec}
\fi-360\li720 Second item\par
```

Can map our numbering to RTF list codes:
- `.numeric` → `\pndec`
- `.alphabeticUpper` → `\pnucrm`
- `.alphabeticLower` → `\pnlcrm`
- `.romanUpper` → `\pnucrm`
- `.romanLower` → `\pnlcrm`

#### PDF
PDF has no native numbering - numbers must be rendered as text.
Use existing PDF rendering pipeline.

#### HTML
Map to HTML list elements:

```html
<ol type="1">  <!-- Numeric -->
<ol type="A">  <!-- Uppercase alpha -->
<ol type="a">  <!-- Lowercase alpha -->
<ol type="I">  <!-- Uppercase roman -->
<ol type="i">  <!-- Lowercase roman -->
<ul>           <!-- Bullets -->
```

Custom adornments require CSS:
```css
ol {
    list-style: none;
    counter-reset: item;
}
ol li:before {
    content: counter(item) ") ";
    counter-increment: item;
}
```

## User Experience Research

### Common Workflows

#### Creating Numbered List
1. Select "Numbered List" from toolbar
2. Type item, press Return
3. Continue typing items
4. Press Return twice to exit list
5. Tab to increase indent
6. Shift+Tab to decrease indent

**Expectation**: Seamless, like Word/Google Docs

#### Applying Numbering to Existing Text
1. Select paragraphs
2. Choose "Apply Numbering" from menu
3. Numbers added automatically
4. Option to customize format

#### Customizing Numbering Format
1. Open style editor
2. Enable numbering
3. Choose format (numeric, alphabetic, etc.)
4. Choose adornment (period, parentheses, etc.)
5. Set starting number
6. Preview updates in real-time

### Keyboard Shortcuts

Industry standard shortcuts:
- **Cmd+Shift+7**: Toggle numbered list
- **Cmd+Shift+8**: Toggle bulleted list
- **Tab**: Increase indent (in list)
- **Shift+Tab**: Decrease indent (in list)
- **Return Return**: Exit list

### Visual Design

#### Number Appearance
- Slightly muted color (70% text color)
- Clear spacing from text (0.5em)
- Right-aligned before text
- Not selectable as text

#### Indentation
- 0.5 inches per level
- Consistent across all formats
- Visual hierarchy clear
- Numbers align vertically

## Competitive Analysis

### Microsoft Word
- **Strengths**: 
  - Extensive numbering options
  - Multi-level list templates
  - Restart numbering control
- **Weaknesses**:
  - Complex UI
  - Lists can break unexpectedly
  - Difficult to customize

### Google Docs
- **Strengths**:
  - Simple list creation
  - Good keyboard shortcuts
  - Reliable behavior
- **Weaknesses**:
  - Limited customization
  - No hierarchical numbering
  - Basic format options

### Pages
- **Strengths**:
  - Clean interface
  - Good default formatting
  - Reliable
- **Weaknesses**:
  - Limited options
  - No legal-style numbering
  - Simple hierarchical support

### Ulysses
- **Strengths**:
  - Markdown-based lists
  - Simple and clean
  - Fast
- **Weaknesses**:
  - Markdown-only (limited formatting)
  - No numbering customization

## Recommendations

### Implementation Priorities
1. **Phase 1**: Core numbering with numeric format
2. **Phase 2**: Alphabetic and roman formats
3. **Phase 3**: Adornment customization
4. **Phase 4**: List UI (toolbar buttons, shortcuts)
5. **Phase 5**: Export support

### Format Defaults
- **Title 1**: 1. (numeric, period)
- **Title 2**: 1.1 (numeric, hierarchical, plain)
- **Title 3**: 1.1.1 (numeric, hierarchical, plain)
- **Numbered List**: 1. (numeric, period)
- **Bulleted List**: • (bullet)

### User Options to Expose
- Format type (always)
- Adornment (always)
- Starting number (always)
- Reset behavior (advanced)
- Custom prefix/suffix (advanced)

Keep advanced options collapsed to avoid overwhelming users.

## Open Questions

1. **Should we support outline numbering (I, A, 1, a, i)?**
   - Requires defining sequence of formats
   - Complex but valuable for academic work
   - **Recommendation**: Add in Phase 2 as advanced feature

2. **How to handle numbered footnotes interaction?**
   - Feature 017 uses simple sequential numbering
   - Should share counter system or separate?
   - **Recommendation**: Keep separate for now, unify later

3. **Should list formats be separate from paragraph styles?**
   - Could have "List" type separate from styles
   - Or lists use special paragraph styles
   - **Recommendation**: Use paragraph styles (consistent architecture)

4. **Legal numbering with multiple adornments (1.1(a)(i))?**
   - Very complex, requires format stacking
   - High value for legal users
   - **Recommendation**: Phase 8+ future enhancement
