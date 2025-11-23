# Feature 015: Footnotes - Implementation Plan

## Phase 1: Core Data Model ✅ Planned

### 1.1 Create FootnoteModel
- [ ] Create `Models/FootnoteModel.swift`
- [ ] Add SwiftData @Model class with all properties
- [ ] Add initialization method
- [ ] Add update methods

### 1.2 Create FootnoteAttachment
- [ ] Create `Helpers/FootnoteAttachment.swift`
- [ ] Implement NSTextAttachment subclass
- [ ] Render superscript number badge
- [ ] Handle tap gestures

### 1.3 Extend Serialization
- [ ] Update `AttributedStringSerializer` to handle footnotes
- [ ] Add encode/decode for FootnoteAttachment
- [ ] Test serialization round-trip

## Phase 2: Footnote Manager

### 2.1 Create FootnoteManager
- [ ] Create `Managers/FootnoteManager.swift`
- [ ] Implement singleton pattern
- [ ] Add CRUD methods for footnotes
- [ ] Add footnote numbering logic

### 2.2 Footnote Insertion Helper
- [ ] Create `Helpers/FootnoteInsertionHelper.swift`
- [ ] Insert footnote at cursor position
- [ ] Create marker attachment
- [ ] Manage footnote numbering

## Phase 3: UI Components

### 3.1 Footnote Detail View
- [ ] Create `Views/Footnotes/FootnoteDetailView.swift`
- [ ] Display footnote content
- [ ] Edit footnote text
- [ ] Delete footnote
- [ ] Show footnote number

### 3.2 Footnotes List View
- [ ] Create `Views/Footnotes/FootnotesListView.swift`
- [ ] Display all footnotes for document
- [ ] Sort by document order
- [ ] Edit/delete actions
- [ ] Jump to footnote marker

### 3.3 New Footnote Dialog
- [ ] Create footnote input UI
- [ ] Validation
- [ ] Insert at cursor position

## Phase 4: FileEditView Integration

### 4.1 Add Footnote Actions
- [ ] Add footnote button to toolbar
- [ ] Handle footnote insertion
- [ ] Handle footnote marker taps
- [ ] Show footnote detail on tap

### 4.2 Footnote Display
- [ ] Present footnote detail sheet
- [ ] Present footnotes list sheet
- [ ] Handle footnote updates
- [ ] Handle footnote deletions

## Phase 5: Footnote Management

### 5.1 Renumbering Logic
- [ ] Auto-renumber when footnotes added/deleted
- [ ] Update all markers in document
- [ ] Maintain document order

### 5.2 Footnote Navigation
- [ ] Jump to footnote from marker
- [ ] Jump to marker from footnote list
- [ ] Scroll to position

## Phase 6: Export Support

### 6.1 Pagination Support
- [ ] Render footnotes in paginated view
- [ ] Display at bottom of page
- [ ] Format footnote section

### 6.2 Export Formatting
- [ ] Include footnotes in exports
- [ ] Format according to style guide
- [ ] Handle footnote references

## Testing Strategy

### Unit Tests
- FootnoteModel creation and updates
- Footnote numbering logic
- Serialization/deserialization
- Footnote insertion and deletion

### Integration Tests
- Footnote workflow end-to-end
- Multiple footnotes in document
- Footnote reordering
- Export with footnotes

### Manual Testing
- UI interactions
- Visual rendering
- CloudKit sync
- Performance with many footnotes

## Technical Considerations

1. **Numbering**: Auto-renumber when footnotes added/removed
2. **Positioning**: Track character positions, update when text changes
3. **Display**: Superscript markers in text, full view in detail sheet
4. **Export**: Format footnotes appropriately for different outputs
5. **Serialization**: Similar to comments, encode/decode attachments
6. **CloudKit**: Follow established patterns from comments feature

## Dependencies

- Feature 014: Comments (reference implementation)
- Feature 005: Text Formatting (text editing system)
- AttributedStringSerializer (extend for footnotes)

## Estimated Effort

- **Phase 1-2**: 4-6 hours (Core infrastructure)
- **Phase 3**: 3-4 hours (UI components)
- **Phase 4**: 2-3 hours (Integration)
- **Phase 5**: 2-3 hours (Management)
- **Phase 6**: 3-4 hours (Export)
- **Testing**: 2-3 hours

**Total**: 16-23 hours

## Success Criteria

- [ ] Users can insert footnotes at any position
- [ ] Footnotes show as superscript numbers
- [ ] Tapping marker shows footnote detail
- [ ] Footnotes auto-renumber correctly
- [ ] Footnotes persist across app sessions
- [ ] Footnotes sync via CloudKit
- [ ] Footnotes appear in paginated view
- [ ] Footnotes export correctly
