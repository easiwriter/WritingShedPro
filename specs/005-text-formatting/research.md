# Phase 005: Text Formatting - Research

**Status**: Planning  
**Created**: 2025-10-26

## Text Formatting Approaches

### Option 1: Attributed Strings
- Native iOS/macOS approach
- NSAttributedString
- Pros: Native, well-supported, rich formatting
- Cons: Complex to serialize, version control challenges

### Option 2: Markdown
- Plain text with markup
- Pros: Simple, version control friendly, portable
- Cons: Limited formatting options, conversion overhead

### Option 3: Custom Format Model
- Custom data structure for formatting
- Pros: Full control, optimized for use case
- Cons: More implementation work, custom serialization

## Existing Infrastructure

### Command Pattern
Already have placeholder commands:
- `FormatApplyCommand.swift`
- `FormatRemoveCommand.swift`

### Text Editor
Currently using SwiftUI `TextEditor` which has limited formatting support out of the box.

## Questions to Answer

1. What formatting features are needed? (bold, italic, underline, etc.)
2. How should formatting be stored and synced via CloudKit?
3. Should we use `UITextView` instead of `TextEditor` for more control?
4. How does formatting interact with undo/redo?
5. How should formatted text be exported?

## References

[To be added as research progresses]
