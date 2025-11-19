# Feature 010: Paginated Document View - Plan

## Phase 1: Research & Foundation (Current Phase)

### Goals
- Establish the foundation for pagination by understanding existing models and creating core calculation utilities
- Document technical approach and architectural decisions
- Create reusable components that later phases will build upon
- No UI changes in this phase - focus on infrastructure

### Tasks

#### 1. Research & Documentation (2 hours)
- ✅ Examine existing PageSetup models and their usage
- ✅ Document current PageSetup integration points
- ✅ Define data models needed for pagination state
- ✅ Research TextKit 1 pagination approach
- ✅ Document virtual scrolling strategy

**Deliverables:**
- Updated `data-model.md` with pagination state models
- Updated `research.md` with technical findings
- Clear understanding of PageSetup → Page Layout pipeline

#### 2. Core Calculation Engine (3 hours)
- Create `PageLayoutCalculator.swift` utility class
- Implement page dimension calculations from PageSetup
- Calculate text area (excluding margins, headers, footers)
- Handle orientation changes (portrait/landscape)
- Support all paper sizes (Letter, Legal, A4, A5, Custom)

**Deliverables:**
- `PageLayoutCalculator.swift` in Services folder
- Methods: `calculatePageRect()`, `calculateTextRect()`, `calculateContentArea()`
- Well-documented, reusable code

#### 3. Unit Testing (2 hours)
- Create `PageLayoutCalculatorTests.swift`
- Test page dimension calculations
- Test margin handling
- Test header/footer space calculations
- Test edge cases (zero margins, custom sizes)
- Test orientation switching

**Deliverables:**
- Comprehensive test coverage for PageLayoutCalculator
- All tests passing
- Edge cases documented

#### 4. Documentation Updates (1 hour)
- Update implementation checklist
- Document any discoveries or changes to approach
- Create code examples in documentation

**Deliverables:**
- Updated `checklists/implementation.md`
- Clear path forward to Phase 2

### Success Criteria
- ✅ PageLayoutCalculator correctly calculates page dimensions for all paper sizes
- ✅ All unit tests passing
- ✅ Documentation clearly explains the foundation
- ✅ No regressions in existing functionality
- ✅ Code is ready for Phase 2 (text layout implementation)

### Timeline
**Estimated Time:** 8 hours
**Status:** In Progress

---

## Phase 2: Text Layout Engine (Next)

### Goals
- Implement the core text layout system using TextKit 1
- Calculate how text flows across multiple pages
- Determine page count from document content
- Handle text wrapping and page boundaries

### Tasks

#### 1. Text Container Configuration (3 hours)
- Create `PaginatedTextLayoutManager.swift`
- Set up NSLayoutManager with NSTextStorage
- Calculate text ranges for each page
- Handle line breaking at page boundaries

#### 2. Page Count Calculator (2 hours)
- Implement algorithm to determine total page count
- Handle empty documents (always at least 1 page)
- Optimize for performance (cache results)
- Update when document changes

#### 3. Text Range Mapping (2 hours)
- Map text ranges to page numbers
- Calculate which page a given character/cursor position is on
- Handle explicit page breaks (if needed)

#### 4. Testing (2 hours)
- Unit tests for page count calculation
- Tests for text range mapping
- Performance tests with large documents (50k+ words)

### Deliverables
- `PaginatedTextLayoutManager.swift`
- Page count calculation working correctly
- Unit tests passing
- Performance acceptable for 200+ page documents

### Success Criteria
- Text layout correctly calculates page count
- Text ranges map to correct pages
- Performance is acceptable (<100ms for layout calculation)
- Memory usage is reasonable

### Timeline
**Estimated Time:** 9 hours

---

## Phase 3: Virtual Scrolling Implementation

### Goals
- Create the virtual scrolling view that only renders visible pages
- Implement page view recycling for memory efficiency
- Smooth scrolling with page rendering on-demand
- Handle 200+ page documents without performance issues

### Tasks

#### 1. Virtual Page Container (4 hours)
- Create `VirtualPageScrollView.swift` (UIViewRepresentable)
- Implement UIScrollView subclass
- Calculate visible page range during scrolling
- Implement 2-page buffer above/below visible area
- Page view recycling/reuse system

#### 2. Page View Management (3 hours)
- Create/destroy page views as needed
- Position pages correctly in scroll view
- Handle page transitions smoothly
- Memory management for page views

#### 3. Scroll State Management (2 hours)
- Track current visible page
- Maintain scroll position
- Handle zoom level changes
- Sync state with SwiftUI

#### 4. Testing (2 hours)
- Test virtual scrolling with various document sizes
- Memory leak testing
- Scroll performance testing
- Page visibility calculation tests

### Deliverables
- `VirtualPageScrollView.swift` working
- Smooth scrolling with on-demand rendering
- Memory usage stays constant regardless of document size
- Unit and integration tests passing

### Success Criteria
- Virtual scrolling works smoothly
- Only 5-7 page views in memory at once
- No memory leaks
- Performance acceptable for 500+ page documents

### Timeline
**Estimated Time:** 11 hours

---

## Phase 4: UI Integration & Polish

### Goals
- Integrate pagination view into FileEditView
- Add toolbar toggle button
- Implement zoom/pinch gestures
- Add "Preview Mode" indicator
- Page separator visual (dotted line)

### Tasks

#### 1. SwiftUI Wrapper (3 hours)
- Create `PaginatedDocumentView.swift`
- Implement view mode toggle
- Add toolbar button (document.on.document symbols)
- Connect to VirtualPageScrollView

#### 2. Zoom Implementation (3 hours)
- iOS/iPad pinch gesture support
- Mac Catalyst zoom controls
- Zoom level persistence
- Constrain zoom range (50%-200%)

#### 3. Visual Polish (2 hours)
- Page separator component
- "Preview Mode" indicator
- Page shadows/borders
- Smooth transitions between modes

#### 4. Integration (3 hours)
- Integrate into FileEditView
- Maintain cursor position when switching modes
- Handle text changes while in paginated view
- Sync with existing editor features

#### 5. Testing (3 hours)
- Manual testing on all platforms
- Integration tests
- User interaction tests
- Edge case testing

### Deliverables
- Complete pagination UI integrated
- Works on iPhone, iPad, and Mac
- Zoom functionality working
- Polish and visual refinements complete

### Success Criteria
- Pagination toggle works smoothly
- Zoom/pinch gestures work correctly
- Visual design matches spec
- No regressions in edit mode
- All platforms work correctly

### Timeline
**Estimated Time:** 14 hours

---

## Phase 5: Testing & Refinement

### Goals
- Comprehensive testing across all platforms
- Performance optimization
- Bug fixes
- Documentation completion

### Tasks

#### 1. Cross-Platform Testing (4 hours)
- iPhone testing (various sizes)
- iPad testing (portrait/landscape)
- Mac Catalyst testing
- Accessibility testing

#### 2. Performance Optimization (3 hours)
- Profile with Instruments
- Optimize page rendering
- Reduce memory usage
- Improve scroll performance

#### 3. Bug Fixes (4 hours)
- Fix any issues discovered in testing
- Handle edge cases
- Improve error handling

#### 4. Documentation (2 hours)
- Complete all documentation
- Add code comments
- Update user-facing docs
- Document known limitations

### Deliverables
- All tests passing
- Performance optimized
- Documentation complete
- Feature ready for production

### Success Criteria
- Zero critical bugs
- Performance meets targets
- Works correctly on all platforms
- Documentation is complete

### Timeline
**Estimated Time:** 13 hours

---

## Overall Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| Phase 1: Research & Foundation | 8 hours | 🔄 In Progress |
| Phase 2: Text Layout Engine | 9 hours | ⏳ Pending |
| Phase 3: Virtual Scrolling | 11 hours | ⏳ Pending |
| Phase 4: UI Integration | 14 hours | ⏳ Pending |
| Phase 5: Testing & Refinement | 13 hours | ⏳ Pending |
| **Total** | **55 hours** | |

---

## Overall Success Criteria

### Functionality
- ✅ Pagination view displays document pages correctly
- ✅ Pages sized according to PageSetup model
- ✅ Smooth scrolling through documents
- ✅ Zoom functionality works on all platforms
- ✅ Mode toggle works reliably
- ✅ Preview mode is read-only

### Performance
- ✅ 200+ page documents render smoothly
- ✅ Memory usage stays under 100MB for large documents
- ✅ Scroll performance is 60fps
- ✅ Mode switching is instantaneous (<200ms)

### Quality
- ✅ All unit tests passing
- ✅ All integration tests passing
- ✅ Zero critical bugs
- ✅ Works on iPhone, iPad, and Mac
- ✅ Code is well-documented
- ✅ User documentation complete

### User Experience
- ✅ Intuitive toggle between edit and preview modes
- ✅ Visual design matches Apple Pages style
- ✅ Page separators are clear
- ✅ Zoom gestures feel natural
- ✅ Preview matches export output

---

## Notes & Decisions

### Key Architectural Decisions
1. **TextKit 1 over TextKit 2**: Better documentation, more control, proven approach
2. **Virtual Scrolling**: Essential for performance with large documents
3. **Read-Only Preview**: Simplifies implementation, clearer UX (edit vs preview)
4. **UIKit for Pagination**: Better control over text layout than pure SwiftUI

### Dependencies
- Existing PageSetup models
- NSLayoutManager/NSTextStorage from TextKit 1
- UIScrollView for virtual scrolling
- SwiftUI for overall UI structure

### Risks & Mitigation
- **Risk**: Performance with very large documents (500+ pages)
  - **Mitigation**: Virtual scrolling, aggressive page recycling, lazy loading
- **Risk**: Memory usage
  - **Mitigation**: Only render visible pages, aggressive cleanup
- **Risk**: Platform differences (iOS vs Mac)
  - **Mitigation**: Platform-specific testing, conditional code where needed
