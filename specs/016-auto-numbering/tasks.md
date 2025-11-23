# Feature 016: Automatic Paragraph Numbering - Development Tasks

## Backlog

### Phase 1: Core Architecture
- [ ] Review existing ParagraphStyle and StyleSheet implementations
- [ ] Design NumberingManager singleton architecture
- [ ] Create NumberingSettings struct with all properties
- [ ] Create NumberingFormat, NumberingAdornment, ResetBehavior enums
- [ ] Extend ParagraphStyle to include NumberingSettings
- [ ] Create DocumentNumberingState SwiftData model
- [ ] Add CloudKit sync support for DocumentNumberingState
- [ ] Implement NumberingManager.shared singleton
- [ ] Add document state tracking dictionary
- [ ] Create counter management methods (get, increment, reset)
- [ ] Write unit tests for counter tracking
- [ ] Test state persistence and CloudKit sync

### Phase 2: Number Generation
- [ ] Implement numeric format conversion (1, 2, 3...)
- [ ] Implement multi-level hierarchical formatting (1.1, 1.1.1)
- [ ] Create toAlphabetic() utility (A, B, C... Z, AA, AB...)
- [ ] Implement uppercase alphabetic formatting
- [ ] Implement lowercase alphabetic formatting
- [ ] Create toRoman() utility for roman numerals
- [ ] Implement uppercase roman formatting (I, II, III...)
- [ ] Implement lowercase roman formatting (i, ii, iii...)
- [ ] Create bulletForLevel() utility
- [ ] Implement bullet formatting with level support
- [ ] Create adornment formatting (plain, period, parentheses, etc.)
- [ ] Implement custom prefix/suffix support
- [ ] Add format validation (roman range 1-3999)
- [ ] Write unit tests for all format conversions
- [ ] Write unit tests for adornment application
- [ ] Performance test number generation

### Phase 3: Document Integration
- [ ] Hook into paragraph creation in FileEditView
- [ ] Detect when new paragraphs are created
- [ ] Apply numbering automatically to styled paragraphs
- [ ] Update DocumentNumberingState on paragraph creation
- [ ] Implement incremental renumbering on text edits
- [ ] Detect paragraphs requiring renumbering
- [ ] Optimize update performance (debouncing, batching)
- [ ] Handle paragraph insertions
- [ ] Handle paragraph deletions with renumbering
- [ ] Implement paragraph reordering with full renumbering
- [ ] Detect style changes on paragraphs
- [ ] Trigger renumbering on style changes
- [ ] Update counter hierarchy on style changes
- [ ] Preserve manual numbering overrides
- [ ] Implement full document renumbering
- [ ] Add undo/redo support for numbering changes
- [ ] Store numbering state in undo stack
- [ ] Restore counters and formatted numbers on undo
- [ ] Test undo/redo with complex scenarios
- [ ] Write integration tests for document editing flow
- [ ] Performance test with large documents (1000+ paragraphs)

### Phase 4: UI Components
- [ ] Add numbering section to StyleEditorView
- [ ] Create enable/disable numbering toggle
- [ ] Add format picker dropdown (Numeric, Alphabetic, Roman, Bullet)
- [ ] Add adornment picker (Plain, Period, Parentheses, etc.)
- [ ] Add starting number text field
- [ ] Add reset behavior picker
- [ ] Add custom prefix text field
- [ ] Add custom suffix text field
- [ ] Create live number preview component
- [ ] Show formatted number examples (1, 2, 3... or A, B, C...)
- [ ] Update preview on settings change
- [ ] Add "Numbered List" toolbar button
- [ ] Add "Bulleted List" toolbar button
- [ ] Use SF Symbols icons (list.number, list.bullet)
- [ ] Implement Cmd+Shift+7 shortcut (numbered list)
- [ ] Implement Cmd+Shift+8 shortcut (bulleted list)
- [ ] Visual polish: spacing, hierarchy, colors
- [ ] Add accessibility labels to all controls
- [ ] Test in dark mode
- [ ] Write UI tests for style editor
- [ ] Manual testing of all UI flows

### Phase 5: List Support
- [ ] Create "Numbered List" paragraph style
- [ ] Create "Bulleted List" paragraph style
- [ ] Create "List Level 2" style (indented)
- [ ] Create "List Level 3" style (more indented)
- [ ] Set default numbering settings for list styles
- [ ] Implement level-based bullet selection (•, ◦, ▪)
- [ ] Add custom bullet character support
- [ ] Implement consistent list indentation (0.5" per level)
- [ ] Add proper spacing between list items
- [ ] Implement Tab key handling (increase indent)
- [ ] Implement Shift+Tab key handling (decrease indent)
- [ ] Update paragraph nesting level on indent change
- [ ] Trigger renumbering on level change
- [ ] Provide visual feedback during indent/outdent
- [ ] Implement list continuation on Return
- [ ] Exit list on empty Return (Return twice)
- [ ] Maintain numbering sequence across list items
- [ ] Preserve formatting in continued lists
- [ ] Implement nested lists
- [ ] Support different formats per nesting level
- [ ] Handle proper indentation in nested lists
- [ ] Maintain counter hierarchy in nested lists
- [ ] Write unit tests for list creation
- [ ] Write integration tests for indent/outdent
- [ ] Test list continuation behavior
- [ ] Test nested list scenarios
- [ ] Manual testing of all list workflows

### Phase 6: Export & Serialization
- [ ] Update StyleSheet serialization to include NumberingSettings
- [ ] Ensure all numbering properties are stored
- [ ] Add backward compatibility for old style sheets
- [ ] Validate numbering settings on load
- [ ] Include formatted numbers in RTF export
- [ ] Map numbering formats to RTF list codes
- [ ] Test RTF import/export fidelity
- [ ] Include numbers in PDF export
- [ ] Ensure proper rendering of numbered paragraphs in PDF
- [ ] Test PDF export with various numbering formats
- [ ] Generate HTML with proper list elements (<ol>, <ul>)
- [ ] Apply CSS for custom adornments
- [ ] Test HTML export
- [ ] Implement pagination numbering display
- [ ] Handle page breaks in numbered lists
- [ ] Maintain consistency across pages
- [ ] Test interaction with Feature 015 footnotes
- [ ] Write unit tests for serialization
- [ ] Write integration tests for export formats
- [ ] Manual testing of all export formats

### Phase 7: Testing & Polish
- [ ] Write unit tests for numeric format conversion
- [ ] Write unit tests for alphabetic conversion
- [ ] Write unit tests for roman numeral conversion
- [ ] Write unit tests for bullet selection
- [ ] Write unit tests for adornment application
- [ ] Write unit tests for counter increment/reset
- [ ] Write unit tests for hierarchical numbering
- [ ] Write unit tests for format validation
- [ ] Write integration test for full document numbering
- [ ] Write integration test for style changes
- [ ] Write integration test for insertions/deletions
- [ ] Write integration test for paragraph reordering
- [ ] Write integration test for undo/redo
- [ ] Write integration test for CloudKit sync
- [ ] Profile numbering update performance
- [ ] Optimize hot paths in number generation
- [ ] Batch renumbering operations where possible
- [ ] Reduce memory allocations in formatting
- [ ] Test with very large documents (10,000+ paragraphs)
- [ ] Test with deeply nested structures (5+ levels)
- [ ] Test rapid editing scenarios
- [ ] Test concurrent changes (if applicable)
- [ ] Handle edge cases (empty paragraphs, style deletion)
- [ ] Update user guide with numbering documentation
- [ ] Add code documentation to all public APIs
- [ ] Create example documents showcasing numbering
- [ ] Update README with feature description
- [ ] Create video tutorial (optional)

## Completed
_No tasks completed yet_

## Notes

### Dependencies
- **Feature 005**: Text Formatting - paragraph style system
- **Feature 003**: Text File Creation - document structure
- **Feature 015**: Footnotes - consumer of basic numbering

### Testing Strategy
- Unit tests for all format conversions and logic
- Integration tests for full workflows
- Performance benchmarks for large documents
- Manual testing for user experience
- Export validation for all formats

### Performance Targets
- **Numbering update**: <16ms (60fps)
- **Full renumber (1000 para)**: <100ms
- **Memory per paragraph**: <50 bytes
- **Cold start**: <500ms

### Risk Areas
- Performance with very large documents
- Complexity of hierarchical numbering
- Export format compatibility
- CloudKit sync conflicts
- Undo/redo edge cases

### Future Enhancements
- Section/chapter-based reset
- Legal-style numbering (1.1(a)(i))
- Cross-references to numbered paragraphs
- Table of contents integration
- Locale-based number formatting
