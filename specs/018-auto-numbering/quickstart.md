# Feature 018: Automatic Paragraph Numbering - Quick Start

## For Users

### Creating a Numbered List
1. Tap the **numbered list button** (list.number icon) in the toolbar
2. Type your first item
3. Press **Return** to create the next item
4. Press **Return twice** to exit the list

### Creating a Bulleted List
1. Tap the **bulleted list button** (list.bullet icon) in the toolbar
2. Type your first item
3. Press **Return** to create the next item
4. Press **Return twice** to exit the list

### Nesting Lists
1. Create a list
2. Press **Tab** to increase indent level
3. Press **Shift+Tab** to decrease indent level
4. Numbers/bullets update automatically

### Customizing Numbering for a Style
1. Open **Style Editor**
2. Select your paragraph style (e.g., "Title 1")
3. Enable **"Numbering"** toggle
4. Choose **Format**: Numeric, Alphabetic, Roman, or Bullet
5. Choose **Adornment**: Plain (1), Period (1.), Parentheses ((1)), etc.
6. Set **Starting Number** (default: 1)
7. See live **Preview** of formatting
8. Save style

### Hierarchical Numbering
1. Create styles with hierarchy:
   - Title 1: Format = Numeric, Adornment = Period → "1."
   - Title 2: Format = Numeric, Adornment = Plain → "1.1"
   - Title 3: Format = Numeric, Adornment = Plain → "1.1.1"
2. Apply styles to paragraphs
3. Numbering updates automatically with hierarchy

### Keyboard Shortcuts
- **Cmd+Shift+7**: Toggle numbered list
- **Cmd+Shift+8**: Toggle bulleted list
- **Tab**: Increase list indent
- **Shift+Tab**: Decrease list indent
- **Return Return**: Exit list

## For Developers

### Architecture Overview
```
NumberingManager (Singleton)
├── DocumentNumberingState (SwiftData)
│   └── Counter tracking per style/level
├── Format Converters
│   ├── toNumeric()
│   ├── toAlphabetic()
│   ├── toRoman()
│   └── bulletForLevel()
└── Adornment Formatter
    └── Apply prefix/suffix/wrapping
```

### Key Components
1. **NumberingManager**: Singleton managing all numbering operations
2. **NumberingSettings**: Configuration per paragraph style
3. **DocumentNumberingState**: SwiftData model tracking counters
4. **ParagraphNumberingInfo**: Runtime info per paragraph

### Quick Integration
```swift
// Enable numbering for a style
var style = ParagraphStyle.title1
style.numberingSettings = NumberingSettings(
    enabled: true,
    format: .numeric,
    adornment: .period,
    startingNumber: 1
)

// Get formatted number
let manager = NumberingManager.shared
let number = manager.formattedNumber(
    for: style,
    in: documentID,
    level: 0
)
// Returns: "1."

// Update numbering after edit
manager.updateNumbering(
    for: documentID,
    paragraphs: allParagraphs
)
```

### Number Format Conversion
```swift
// Numeric: 1, 2, 3...
NumberingFormat.numeric → "1", "2", "3"

// Alphabetic: A, B, C... Z, AA, AB...
NumberingFormat.alphabeticUpper → "A", "B", "C"
NumberingFormat.alphabeticLower → "a", "b", "c"

// Roman: I, II, III, IV...
NumberingFormat.romanUpper → "I", "II", "III"
NumberingFormat.romanLower → "i", "ii", "iii"

// Bullets: •, ◦, ▪...
NumberingFormat.bullet → "•", "◦", "▪"
```

### Adornment Examples
```swift
// Plain: 1
NumberingAdornment.plain.format("1") → "1"

// Period: 1.
NumberingAdornment.period.format("1") → "1."

// Parentheses: (1)
NumberingAdornment.parentheses.format("1") → "(1)"

// Right paren: 1)
NumberingAdornment.rightParen.format("1") → "1)"

// Dashes: -1-
NumberingAdornment.dashes.format("1") → "-1-"

// Custom: [1]
NumberingAdornment.custom.format("1", prefix: "[", suffix: "]") → "[1]"
```

### Hierarchical Numbering
```swift
// Track counters at multiple levels
var state = DocumentNumberingState(documentID: docID)

// Title 1 (level 0): 1, 2, 3...
state.incrementCounter(for: "title1", level: 0) // 1
state.incrementCounter(for: "title1", level: 0) // 2

// Title 2 (level 1): 1.1, 1.2, 2.1...
state.incrementCounter(for: "title2", level: 1) // 1.1
state.incrementCounter(for: "title2", level: 1) // 1.2
state.incrementCounter(for: "title1", level: 0) // 2
state.incrementCounter(for: "title2", level: 1) // 2.1
```

### Updating Numbering
```swift
// Automatic update on paragraph creation
func didCreateParagraph(_ paragraph: Paragraph, in document: Document) {
    guard let style = paragraph.style, style.hasNumbering else { return }
    
    let manager = NumberingManager.shared
    manager.incrementCounter(for: style.id, in: document.id)
    
    // Get formatted number
    if let number = manager.formattedNumber(for: style, in: document.id) {
        paragraph.prependNumber(number)
    }
}

// Full document renumbering
func didReorderParagraphs(in document: Document) {
    let manager = NumberingManager.shared
    manager.updateNumbering(
        for: document.id,
        paragraphs: document.paragraphs
    )
}
```

### Style Editor Integration
```swift
// Add numbering controls to style editor
struct StyleEditorView: View {
    @State var style: ParagraphStyle
    @State var numberingEnabled = false
    @State var selectedFormat: NumberingFormat = .numeric
    @State var selectedAdornment: NumberingAdornment = .period
    
    var body: some View {
        Form {
            Section("Numbering") {
                Toggle("Enable Numbering", isOn: $numberingEnabled)
                
                if numberingEnabled {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(NumberingFormat.allCases, id: \.self) { format in
                            Text(format.displayName)
                        }
                    }
                    
                    Picker("Adornment", selection: $selectedAdornment) {
                        ForEach(NumberingAdornment.allCases, id: \.self) { adorn in
                            Text(adorn.displayName)
                        }
                    }
                    
                    NumberPreview(
                        format: selectedFormat,
                        adornment: selectedAdornment
                    )
                }
            }
        }
    }
}
```

### Testing Examples
```swift
// Unit test for number generation
func testNumericFormatting() {
    let manager = NumberingManager.shared
    XCTAssertEqual(manager.toNumeric(1), "1")
    XCTAssertEqual(manager.toNumeric(42), "42")
}

func testAlphabeticFormatting() {
    let manager = NumberingManager.shared
    XCTAssertEqual(manager.toAlphabetic(1, uppercase: true), "A")
    XCTAssertEqual(manager.toAlphabetic(26, uppercase: true), "Z")
    XCTAssertEqual(manager.toAlphabetic(27, uppercase: true), "AA")
}

func testRomanFormatting() {
    let manager = NumberingManager.shared
    XCTAssertEqual(manager.toRoman(1), "I")
    XCTAssertEqual(manager.toRoman(4), "IV")
    XCTAssertEqual(manager.toRoman(9), "IX")
    XCTAssertEqual(manager.toRoman(1994), "MCMXCIV")
}

// Integration test for full workflow
func testFullDocumentNumbering() {
    let document = createTestDocument()
    let manager = NumberingManager.shared
    
    // Add numbered paragraphs
    addParagraph(style: .title1) // Should be "1"
    addParagraph(style: .title2) // Should be "1.1"
    addParagraph(style: .title2) // Should be "1.2"
    addParagraph(style: .title1) // Should be "2"
    
    // Verify numbering
    XCTAssertEqual(document.paragraphs[0].number, "1")
    XCTAssertEqual(document.paragraphs[1].number, "1.1")
    XCTAssertEqual(document.paragraphs[2].number, "1.2")
    XCTAssertEqual(document.paragraphs[3].number, "2")
}
```

## Common Tasks

### Add Numbering to Existing Style
1. Locate style in `StyleSheet.default.paragraphStyles`
2. Create `NumberingSettings` with desired format
3. Set `style.numberingSettings`
4. Save style sheet

### Create Custom Number Format
1. Add new case to `NumberingFormat` enum
2. Implement conversion in `NumberingManager.convertNumber()`
3. Add display name to `NumberingFormat.displayName`
4. Test conversion logic

### Debug Numbering Issues
1. Check `DocumentNumberingState` for counter values
2. Verify style has `NumberingSettings` configured
3. Confirm paragraph has correct style applied
4. Test number generation with known values
5. Check for counter reset triggers

## Resources

- **Data Model**: `specs/018-auto-numbering/data-model.md`
- **Implementation Plan**: `specs/018-auto-numbering/plan.md`
- **Research**: `specs/018-auto-numbering/research.md`
- **Full Specification**: `specs/018-auto-numbering/spec.md`

## Status
**Planning** - Feature not yet implemented
