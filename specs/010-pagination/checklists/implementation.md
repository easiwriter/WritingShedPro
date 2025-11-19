# Feature 010: Paginated Document View - Implementation Checklist

## Phase 1: Foundation ✅ COMPLETE
- [x] Research existing PageSetup models and integration
- [x] Create PageLayoutCalculator utility class
- [x] Implement page dimension calculations
- [x] Implement margin and header/footer handling
- [x] Support all paper sizes (Letter, Legal, A4, A5)
- [x] Support both orientations (portrait, landscape)
- [x] Create comprehensive unit tests (30+ tests)
- [x] Document data models (data-model.md)
- [x] Document technical research (research.md)
- [x] Document implementation plan (plan.md)
- [x] All tests passing

### Deliverables Created
- `PageLayoutCalculator.swift` - Core calculation engine (270 lines)
- `PageLayoutCalculatorTests.swift` - Comprehensive test suite (30 tests)
- `data-model.md` - Complete data model documentation
- `research.md` - Technical research and decisions
- `plan.md` - Detailed 5-phase implementation plan

## Phase 2: Text Layout Engine (NEXT PHASE)
- [ ] Create PaginatedTextLayoutManager class
- [ ] Set up NSLayoutManager with NSTextStorage
- [ ] Implement page count calculation algorithm
- [ ] Map text ranges to page numbers
- [ ] Calculate which text appears on each page
- [ ] Handle empty documents (always 1 page minimum)
- [ ] Optimize for performance (<100ms for layout)
- [ ] Write unit tests for text layout
- [ ] Test with various document sizes (1-500 pages)
- [ ] Performance tests with large documents

## Phase 3: Virtual Scrolling Implementation
- [ ] Create VirtualPageScrollView (UIViewRepresentable)
- [ ] Implement UIScrollView subclass
- [ ] Calculate visible page range during scroll
- [ ] Implement 2-page buffer above/below visible area
- [ ] Create page view recycling system
- [ ] Dynamically create/destroy page views
- [ ] Position pages correctly in scroll view
- [ ] Track current visible page
- [ ] Memory leak testing
- [ ] Scroll performance testing (60fps target)

## Phase 4: UI Integration & Polish
- [ ] Create PaginatedDocumentView (SwiftUI)
- [ ] Implement view mode toggle (edit vs paginated)
- [ ] Add toolbar button (document.on.document symbols)
- [ ] Implement iOS/iPad pinch gesture zoom
- [ ] Implement Mac Catalyst zoom controls
- [ ] Add "Preview Mode" indicator
- [ ] Create PageSeparatorView (dotted lines)
- [ ] Integrate into FileEditView
- [ ] Maintain cursor position when switching modes
- [ ] Handle text changes while in paginated view
- [ ] Smooth transitions between modes
- [ ] Manual testing on all platforms

## Phase 5: Testing & Refinement
- [ ] Cross-platform testing (iPhone, iPad, Mac)
- [ ] Accessibility testing
- [ ] Performance profiling with Instruments
- [ ] Memory usage optimization
- [ ] Bug fixes from testing
- [ ] Edge case handling
- [ ] User-facing documentation
- [ ] Code documentation completion

---

## Core Functionality
- [x] Page layout calculator implemented ✅
- [ ] Text flows correctly between pages
- [ ] Page breaks work properly
- [ ] Page numbers display correctly (future enhancement)
- [ ] Zoom/scale functionality works

## User Interface
- [ ] View mode toggle (edit vs paginated)
- [ ] Page navigation controls
- [ ] Page display (single-page continuous)
- [ ] Zoom controls
- [ ] Page indicator

## Platform Support
- [ ] Works on iPhone
- [ ] Works on iPad
- [ ] Works on Mac Catalyst
- [ ] Platform-specific optimizations applied

## Performance
- [ ] Large documents render smoothly (200+ pages)
- [ ] Page scrolling is responsive (60fps)
- [ ] Memory usage acceptable (<50MB for pagination)
- [ ] Virtual page recycling implemented

## Integration
- [ ] Integrates with existing FileEditView
- [ ] Works with formatted text
- [ ] Works with images (NSTextAttachment)
- [ ] Works with styles (StyleSheet)
- [ ] Preserves version history

## Edge Cases
- [ ] Empty documents (shows 1 blank page)
- [ ] Single-line documents
- [ ] Very long documents (500+ pages)
- [ ] Documents with many images
- [x] Landscape vs portrait orientation ✅
- [x] All paper sizes (Letter, Legal, A4, A5) ✅
- [x] Zero margins ✅
- [x] Headers and footers ✅

## Testing
- [x] Unit tests written (PageLayoutCalculator) ✅
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Performance testing done
- [ ] All platforms tested

## Documentation
- [ ] User-facing documentation updated
- [x] Code documentation complete (Phase 1) ✅
- [x] Technical decisions documented ✅

---

## Known Issues / Future Enhancements

### Not Included in Phase 1
- Facing pages mode (side-by-side pages)
- Page numbers in header/footer
- Explicit page break insertion
- Widow/orphan control
- Editable pagination view
- Per-file pagination preferences

### Performance Optimization Ideas
- Background text layout calculation
- More aggressive page view caching
- Incremental layout updates on text changes
- GPU-accelerated rendering for page shadows

### Accessibility Enhancements
- VoiceOver support for page navigation
- Dynamic type support in paginated view
- High contrast mode for page separators

---

## Testing Coverage

### PageLayoutCalculator Tests ✅
- [x] Page rect calculation for all paper sizes
- [x] Portrait and landscape orientation
- [x] Text rect with various margins
- [x] Zero margins edge case
- [x] Asymmetric margins
- [x] Content rect with headers
- [x] Content rect with footers
- [x] Content rect with both headers and footers
- [x] Header rect positioning
- [x] Footer rect positioning
- [x] Complete layout integration
- [x] Convenience methods (contentWidth, contentHeight)
- [x] Page count estimation
- [x] Page position calculations
- [x] Page index calculations

### Future Test Coverage Needed
- Text layout manager tests
- Virtual scrolling tests
- UI integration tests
- Performance benchmarks
- Memory leak detection
- Cross-platform compatibility tests
