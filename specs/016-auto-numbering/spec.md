# Feature 016: Automatic Paragraph Numbering

## Overview
Writing Shed Pro provides comprehensive automatic numbering for all paragraph styles, enabling structured documents like outlines, legal documents, technical manuals, and academic papers.

### Core Concepts

#### Hierarchical Numbering
All paragraph styles support automatic numbering with hierarchical nesting:
- **Title 1**: 1, 2, 3...
- **Title 2**: 1.1, 1.2, 1.3... (nested under Title 1)
- **Title 3**: 1.1.1, 1.1.2... (nested under Title 2)
- Each style maintains its own counter nested within parent style

#### Numbering Formats
Support multiple numbering formats per style:
- **Numeric**: 1, 2, 3...
- **Alphabetic (upper)**: A, B, C...
- **Alphabetic (lower)**: a, b, c...
- **Roman (upper)**: I, II, III...
- **Roman (lower)**: i, ii, iii...
- **Bullets**: •, ◦, ▪, -, *
- **None**: No numbering

#### Format Adornments
Customize number display with various adornments:
- **Plain**: `1`
- **Period**: `1.`
- **Parentheses**: `(1)`
- **Right paren**: `1)`
- **Dashes**: `-1-`
- **Custom**: User-defined prefix/suffix

### Style Sheet Integration
- Each paragraph style defines its numbering settings
- Settings include: format type, adornment, starting number, reset behavior
- Styles can inherit or override parent numbering
- "None" option disables numbering for a style

### List Support
Special handling for list paragraph styles:
- **Bulleted Lists**: Automatic bullet characters
- **Numbered Lists**: Sequential numbering
- **Multi-level Lists**: Nested list support
- **Custom Bullets**: User-defined bullet characters

### Automatic Behaviors
- **Auto-increment**: Creating new paragraph increments counter
- **Auto-reset**: Counters reset when parent level changes
- **Reordering**: Moving paragraphs updates numbering
- **Deletion**: Removing paragraphs renumbers remaining
- **Insertion**: Inserting paragraphs renumbers following

## User Stories

### As a writer, I want to...
1. Define numbering format for each paragraph style in my style sheet
2. Have paragraphs automatically numbered when I create them
3. See hierarchical numbering (1, 1.1, 1.1.1) for nested styles
4. Choose different numbering types (numeric, alphabetic, roman, bullets)
5. Customize number appearance with adornments (1., (1), etc.)
6. Have numbering update automatically when I add, delete, or reorder content
7. Disable numbering for specific styles (Body, Caption, etc.)
8. Create bulleted and numbered lists with automatic formatting
9. Control where numbering resets (per document, per section, per chapter)
10. Export documents with proper numbering preserved

## Technical Requirements

### Style Sheet Schema
Extend ParagraphStyle to include:
```swift
struct NumberingSettings {
    var enabled: Bool = false
    var format: NumberingFormat = .numeric
    var adornment: NumberingAdornment = .plain
    var startingNumber: Int = 1
    var resetBehavior: ResetBehavior = .never
    var customPrefix: String? = nil
    var customSuffix: String? = nil
    var indentLevel: Int = 0
}

enum NumberingFormat {
    case none
    case numeric           // 1, 2, 3...
    case alphabeticUpper  // A, B, C...
    case alphabeticLower  // a, b, c...
    case romanUpper       // I, II, III...
    case romanLower       // i, ii, iii...
    case bullet           // •, ◦, ▪...
}

enum NumberingAdornment {
    case plain            // 1
    case period           // 1.
    case parentheses      // (1)
    case rightParen       // 1)
    case dashes          // -1-
    case custom          // Uses customPrefix/Suffix
}

enum ResetBehavior {
    case never           // Never reset counter
    case onParentChange  // Reset when parent style changes
    case onSection       // Reset at section boundaries
    case onChapter       // Reset at chapter boundaries
}
```

### Numbering Engine
Create NumberingManager:
- Track counters for all styles and nesting levels
- Generate formatted numbers based on style settings
- Update numbering when document structure changes
- Handle hierarchical relationships between styles

### Document Structure
- Maintain paragraph hierarchy for proper nesting
- Track style relationships (parent/child)
- Update counters on document modifications
- Support style changes without losing numbering

### Text Insertion
- Automatically prepend formatted number to paragraphs
- Update number text when counter changes
- Handle number formatting and spacing
- Support manual override of auto-numbering

## Data Model

### NumberingState
Track numbering state per document:
```swift
@Model
class DocumentNumberingState {
    var documentID: UUID
    var styleCounters: [String: [Int]] // Style ID -> counter stack
    var lastUpdate: Date
}
```

### ParagraphNumbering
Store per-paragraph numbering info:
```swift
struct ParagraphNumberingInfo {
    var number: String        // Formatted number (e.g., "1.2.3")
    var rawValue: Int         // Actual counter value
    var level: Int            // Nesting level
    var styleID: String       // Associated style
    var isOverridden: Bool    // Manual override
}
```

## UI/UX Requirements

### Style Editor Enhancement
Add numbering configuration section:
- Enable/disable numbering toggle
- Format dropdown (numeric, alphabetic, roman, bullets)
- Adornment picker (plain, period, parentheses, etc.)
- Starting number field
- Reset behavior options
- Preview of formatted number

### Document Editing
- Numbers appear automatically with styled paragraphs
- Numbers visually separated from content (spacing/indent)
- Numbers update in real-time as document changes
- Option to manually override specific numbers
- Visual indicator for manual overrides

### List Creation
- Toolbar buttons for bulleted/numbered lists
- Keyboard shortcuts for quick list creation
- Tab to increase indent/nest level
- Shift+Tab to decrease indent level
- Automatic list continuation

## Implementation Plan

### Phase 1: Core Architecture (8-10 hours)
- [ ] Design numbering system architecture
- [ ] Create NumberingManager singleton
- [ ] Implement counter tracking and updates
- [ ] Add numbering settings to style sheet schema

### Phase 2: Number Generation (6-8 hours)
- [ ] Implement numeric formatting
- [ ] Implement alphabetic formatting
- [ ] Implement roman numeral formatting
- [ ] Implement adornment application
- [ ] Create format converter utilities

### Phase 3: Document Integration (8-10 hours)
- [ ] Hook into paragraph creation
- [ ] Update numbering on edits
- [ ] Handle style changes
- [ ] Implement auto-renumbering
- [ ] Add undo/redo support

### Phase 4: UI Components (6-8 hours)
- [ ] Add numbering controls to style editor
- [ ] Create number formatting preview
- [ ] Add list toolbar buttons
- [ ] Implement keyboard shortcuts
- [ ] Visual polish

### Phase 5: List Support (6-8 hours)
- [ ] Create list paragraph styles
- [ ] Implement bullet formatting
- [ ] Add indent/outdent functionality
- [ ] Handle list continuation
- [ ] Multi-level list support

### Phase 6: Export & Serialization (4-6 hours)
- [ ] Serialize numbering settings
- [ ] Export with proper formatting
- [ ] Handle pagination numbering
- [ ] Preserve in RTF/PDF exports

### Phase 7: Testing & Polish (6-8 hours)
- [ ] Unit tests for numbering logic
- [ ] Integration tests for document flow
- [ ] Performance optimization
- [ ] Edge case handling
- [ ] Documentation

**Total Estimate**: 44-58 hours

## Testing Requirements

### Unit Tests
- Number generation for all formats
- Hierarchical counter tracking
- Reset behavior logic
- Format conversion accuracy
- Adornment application

### Integration Tests
- Full document numbering
- Style changes and renumbering
- Insert/delete/move operations
- Undo/redo with numbering
- List creation and nesting

### Manual Tests
- Complex nested documents
- Performance with large documents
- Visual appearance across formats
- Export quality
- User workflows

## Dependencies

- Feature 005: Text Formatting (paragraph styles)
- Feature 003: Text File Creation (document structure)
- Feature 015: Footnotes (uses basic numbering)

## Related Features

- Feature 015: Footnotes (consumer of numbering system)
- Feature 019: Table of Contents (may use numbering)
- Feature 020: Outlining (benefits from hierarchical numbering)

## Status
**Planning** - Created 2025-11-21

## Notes

This is a foundational feature that enables multiple advanced capabilities:
- Legal document formatting
- Technical manual numbering
- Academic paper structure
- Outline creation
- List management

The complexity requires careful architecture and thorough testing, but provides significant value for professional writing workflows.
