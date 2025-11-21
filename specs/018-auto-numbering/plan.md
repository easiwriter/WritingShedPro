# Feature 018: Automatic Paragraph Numbering - Implementation Plan

## Overview
This feature adds comprehensive automatic numbering to all paragraph styles, enabling hierarchical document structures, lists, and professional formatting.

**Total Estimate**: 44-58 hours
**Priority**: Medium - Advanced feature building on existing style system
**Dependencies**: Feature 005 (Text Formatting), Feature 003 (Text File Creation)

## Implementation Phases

### Phase 1: Core Architecture (8-10 hours)

#### Tasks
1. **Design numbering system architecture** (2 hours)
   - Review existing paragraph style system
   - Design NumberingManager singleton pattern
   - Plan counter tracking and state management
   - Define update triggers and invalidation

2. **Create NumberingManager** (3-4 hours)
   - Implement singleton with document state tracking
   - Add counter management methods
   - Create number generation pipeline
   - Add state persistence

3. **Extend ParagraphStyle schema** (2-3 hours)
   - Add NumberingSettings struct
   - Update style sheet storage
   - Modify style editor UI models
   - Add CloudKit sync support

4. **Create DocumentNumberingState model** (1 hour)
   - Define SwiftData model
   - Add counter tracking structures
   - Implement state queries
   - Add CloudKit integration

#### Success Criteria
- [ ] NumberingManager singleton created and tested
- [ ] ParagraphStyle extended with numbering settings
- [ ] DocumentNumberingState persists correctly
- [ ] Basic counter tracking works

---

### Phase 2: Number Generation (6-8 hours)

#### Tasks
1. **Implement numeric formatting** (1 hour)
   - Basic integer conversion
   - Multi-level hierarchical numbering (1, 1.1, 1.1.1)
   - Starting number support
   - Counter increment/reset logic

2. **Implement alphabetic formatting** (2-3 hours)
   - Uppercase conversion (A, B, C... Z, AA, AB...)
   - Lowercase conversion (a, b, c... z, aa, ab...)
   - Multi-level alphabetic (A, A.1, A.1.a)
   - Edge case handling (>26 items)

3. **Implement roman numeral formatting** (2-3 hours)
   - Uppercase romans (I, II, III, IV, V...)
   - Lowercase romans (i, ii, iii, iv, v...)
   - Value range validation (1-3999)
   - Conversion algorithm

4. **Implement adornment application** (1 hour)
   - Plain, period, parentheses, etc.
   - Custom prefix/suffix support
   - Spacing and formatting
   - Consistent styling

5. **Create format converter utilities** (1 hour)
   - toAlphabetic() function
   - toRoman() function
   - bulletForLevel() function
   - Format validation

#### Success Criteria
- [ ] All numbering formats generate correctly
- [ ] Adornments apply properly
- [ ] Edge cases handled (large numbers, invalid ranges)
- [ ] Performance acceptable for real-time use

---

### Phase 3: Document Integration (8-10 hours)

#### Tasks
1. **Hook into paragraph creation** (2-3 hours)
   - Detect when new paragraphs are created
   - Apply numbering automatically
   - Update counter state
   - Handle undo/redo

2. **Update numbering on edits** (3-4 hours)
   - Detect text changes requiring renumbering
   - Optimize update performance
   - Handle insertions/deletions
   - Batch updates efficiently

3. **Handle style changes** (2 hours)
   - Detect style switching
   - Renumber affected paragraphs
   - Update hierarchy
   - Preserve manual overrides

4. **Implement auto-renumbering** (1-2 hours)
   - Track document structure changes
   - Trigger renumbering when needed
   - Maintain counter consistency
   - Update UI efficiently

5. **Add undo/redo support** (1 hour)
   - Store numbering state in undo stack
   - Restore counters on undo
   - Handle complex undo scenarios
   - Test edge cases

#### Success Criteria
- [ ] Numbering updates automatically on edits
- [ ] Style changes trigger correct renumbering
- [ ] Undo/redo works correctly
- [ ] Performance remains smooth during editing

---

### Phase 4: UI Components (6-8 hours)

#### Tasks
1. **Add numbering controls to style editor** (3-4 hours)
   - Enable/disable toggle
   - Format picker (dropdown)
   - Adornment picker
   - Starting number field
   - Reset behavior options
   - Parent style selector (for hierarchical)

2. **Create number formatting preview** (1-2 hours)
   - Live preview of formatted number
   - Show examples with different values
   - Update on settings change
   - Clear visual feedback

3. **Add list toolbar buttons** (1 hour)
   - Bulleted list button
   - Numbered list button
   - SF Symbols icons
   - Keyboard shortcuts

4. **Implement keyboard shortcuts** (1 hour)
   - Cmd+Shift+7 for numbered list
   - Cmd+Shift+8 for bulleted list
   - Tab for indent
   - Shift+Tab for outdent

5. **Visual polish** (1 hour)
   - Consistent spacing
   - Clear visual hierarchy
   - Accessibility labels
   - Dark mode support

#### Success Criteria
- [ ] Style editor has complete numbering UI
- [ ] Preview shows accurate formatting
- [ ] Toolbar buttons work correctly
- [ ] Keyboard shortcuts function properly
- [ ] UI passes accessibility review

---

### Phase 5: List Support (6-8 hours)

#### Tasks
1. **Create list paragraph styles** (2 hours)
   - Define "Bulleted List" style
   - Define "Numbered List" style
   - Multi-level list styles
   - Default settings

2. **Implement bullet formatting** (2-3 hours)
   - Level-based bullet selection (•, ◦, ▪)
   - Custom bullet characters
   - Consistent indentation
   - Proper spacing

3. **Add indent/outdent functionality** (2-3 hours)
   - Tab key handling
   - Shift+Tab handling
   - Update nesting level
   - Renumber on level change
   - Visual feedback

4. **Handle list continuation** (1 hour)
   - Pressing Return continues list
   - Empty Return exits list
   - Maintain numbering sequence
   - Preserve formatting

5. **Multi-level list support** (1 hour)
   - Nested lists
   - Different formats per level
   - Proper indentation
   - Counter hierarchy

#### Success Criteria
- [ ] List styles work correctly
- [ ] Tab/Shift+Tab indent/outdent
- [ ] List continuation feels natural
- [ ] Multi-level lists render properly
- [ ] Edge cases handled (empty paragraphs, style mixing)

---

### Phase 6: Export & Serialization (4-6 hours)

#### Tasks
1. **Serialize numbering settings** (1-2 hours)
   - Store in style sheet JSON
   - Include all settings
   - Backward compatibility
   - Validation on load

2. **Export with proper formatting** (2-3 hours)
   - Include numbers in exported text
   - RTF format support
   - PDF preservation
   - HTML export

3. **Handle pagination numbering** (1 hour)
   - Ensure numbers appear on all pages
   - Handle page breaks mid-list
   - Maintain consistency
   - Test with Feature 017 footnotes

4. **Preserve in RTF/PDF exports** (1 hour)
   - Map to RTF list codes
   - PDF rendering
   - Format fidelity
   - Test exports

#### Success Criteria
- [ ] Settings serialize/deserialize correctly
- [ ] Exports include proper numbering
- [ ] RTF and PDF maintain formatting
- [ ] Pagination works correctly

---

### Phase 7: Testing & Polish (6-8 hours)

#### Tasks
1. **Unit tests for numbering logic** (2-3 hours)
   - Test all number formats
   - Test adornments
   - Test counter tracking
   - Test format conversion

2. **Integration tests for document flow** (2-3 hours)
   - Test full document numbering
   - Test style changes
   - Test insertions/deletions
   - Test undo/redo

3. **Performance optimization** (1 hour)
   - Profile numbering updates
   - Optimize hot paths
   - Batch operations
   - Reduce allocations

4. **Edge case handling** (1 hour)
   - Very large documents
   - Complex nesting
   - Rapid edits
   - Concurrent changes

5. **Documentation** (1 hour)
   - Update user guide
   - Add code documentation
   - Create examples
   - Update README

#### Success Criteria
- [ ] All tests passing
- [ ] Performance meets targets (<16ms updates)
- [ ] Edge cases handled gracefully
- [ ] Documentation complete

---

## Testing Strategy

### Unit Tests
- Number format conversions (numeric, alphabetic, roman)
- Adornment application
- Counter increment/reset logic
- Hierarchical numbering
- Format validation

### Integration Tests
- Full document numbering workflow
- Style sheet integration
- Undo/redo with numbering
- Export with numbering
- CloudKit sync of numbering state

### Manual Testing
- Create complex nested document
- Test all numbering formats
- Verify visual appearance
- Test keyboard shortcuts
- Test list workflows
- Export to various formats
- Performance with large documents

## Risk Mitigation

### Performance Concerns
- **Risk**: Renumbering large documents on every edit
- **Mitigation**: Batch updates, incremental renumbering, debouncing

### Complexity
- **Risk**: Feature is complex with many edge cases
- **Mitigation**: Incremental implementation, thorough testing, phased rollout

### Backward Compatibility
- **Risk**: Existing documents without numbering settings
- **Mitigation**: Default to disabled, graceful migration, validation

### CloudKit Sync
- **Risk**: Counter conflicts across devices
- **Mitigation**: Timestamp-based conflict resolution, full document regeneration

## Future Enhancements

### Phase 8+ (Future)
- Section-based numbering (restart at sections)
- Chapter-based numbering (restart at chapters)
- Custom numbering patterns (legal style: 1.1(a)(i))
- Numbered headings in table of contents
- Cross-references to numbered paragraphs
- Number formatting based on locale
- Right-to-left language support

## Success Metrics
- All paragraph styles support numbering
- Performance: <16ms for renumbering operations
- Zero numbering errors in common workflows
- Positive user feedback on list creation
- Exports maintain formatting fidelity
