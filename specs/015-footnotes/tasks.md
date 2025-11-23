# Feature 015: Footnotes - Tasks

## Current Sprint

### Planning
- [x] Create feature specification structure
- [x] Document data model
- [x] Create implementation plan
- [x] Research footnote standards and implementations
- [ ] Complete spec.md with user requirements
- [ ] Review and approve technical approach

## Backlog

### Phase 1: Core Data Model
- [ ] Create FootnoteModel.swift
- [ ] Create FootnoteAttachment.swift
- [ ] Extend AttributedStringSerializer for footnotes
- [ ] Write unit tests for data model

### Phase 2: Business Logic
- [ ] Create FootnoteManager.swift
- [ ] Create FootnoteInsertionHelper.swift
- [ ] Implement auto-renumbering logic
- [ ] Write unit tests for manager

### Phase 3: UI Components
- [ ] Create FootnoteDetailView.swift
- [ ] Create FootnotesListView.swift
- [ ] Create footnote input dialog
- [ ] Test UI interactions

### Phase 4: Integration
- [ ] Add footnote button to toolbar
- [ ] Integrate with FileEditView
- [ ] Handle footnote marker taps
- [ ] Test end-to-end workflow

### Phase 5: Advanced Features
- [ ] Implement footnote renumbering
- [ ] Add footnote navigation
- [ ] Support pagination display
- [ ] Add export formatting

## Future Enhancements
- [ ] Custom footnote symbols (*, †, ‡)
- [ ] Footnote vs endnote toggle
- [ ] Per-page numbering option
- [ ] Footnote search functionality
- [ ] Footnote import from other formats

## Testing
- [ ] Unit tests for FootnoteModel
- [ ] Unit tests for FootnoteManager
- [ ] Unit tests for serialization
- [ ] Integration tests for workflow
- [ ] Manual UI testing
- [ ] Performance testing with many footnotes
- [ ] CloudKit sync testing

## Documentation
- [ ] Update user documentation
- [ ] Add code comments
- [ ] Create usage examples
- [ ] Document export behavior

## Notes

Based on Feature 014 (Comments) implementation, we have a proven pattern for:
- NSTextAttachment-based markers
- SwiftData persistence
- Serialization with AttributedStringSerializer
- UI patterns for detail views and lists
- Integration with FileEditView

The footnote implementation should follow these same patterns for consistency.
