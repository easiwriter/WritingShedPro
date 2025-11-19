# Feature 010: Pagination - Implementation Tasks

**Status:** Not Started  
**Estimated Duration:** 12-16 days  
**Start Date:** TBD  
**Completion Date:** TBD  

---

## Task Breakdown

### Phase 1: Page Layout Calculator (2-3 days)

#### Task 1.1: Create PageLayoutCalculator Class
**Estimated Time:** 3-4 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Create a class that calculates page dimensions, margins, and text areas based on PageSetup model.

**Acceptance Criteria:**
- [ ] Class created in `Models/Pagination/PageLayoutCalculator.swift`
- [ ] Method `calculatePageRect(from: PageSetup) -> CGRect`
- [ ] Method `calculateTextRect(from: PageSetup) -> CGRect`
- [ ] Handles portrait and landscape orientations
- [ ] Accounts for header/footer reserved space
- [ ] Accounts for margins (top, bottom, left, right)
- [ ] Supports all paper sizes (Letter, Legal, A4, A5, Custom)

**Code Structure:**
```swift
class PageLayoutCalculator {
    func calculatePageRect(from setup: PageSetup) -> CGRect
    func calculateTextRect(from setup: PageSetup) -> CGRect
    func calculateHeaderRect(from setup: PageSetup) -> CGRect
    func calculateFooterRect(from setup: PageSetup) -> CGRect
}
```

**Dependencies:**
- PageSetup model (already exists)
- PageSetupTypes.swift (already exists)

---

#### Task 1.2: Add Unit Tests for Page Layout
**Estimated Time:** 2-3 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Write comprehensive unit tests for page dimension calculations.

**Acceptance Criteria:**
- [ ] Test file created: `WritingShedProTests/PageLayoutCalculatorTests.swift`
- [ ] Test all paper sizes (Letter, Legal, A4, A5)
- [ ] Test both orientations (portrait, landscape)
- [ ] Test with various margin configurations
- [ ] Test with headers enabled/disabled
- [ ] Test with footers enabled/disabled
- [ ] Test edge cases (zero margins, maximum margins)
- [ ] All tests pass

**Test Cases:**
```swift
func testLetterPortraitDimensions()
func testA4LandscapeDimensions()
func testMarginsCalculation()
func testHeaderFooterSpace()
func testCustomPaperSize()
```

---

### Phase 2: Virtual Scrolling Engine (3-4 days)

#### Task 2.1: Create TextLayoutManager
**Estimated Time:** 4-5 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Create a manager that uses NSLayoutManager to calculate total pages and text ranges per page.

**Acceptance Criteria:**
- [ ] Class created in `Models/Pagination/TextLayoutManager.swift`
- [ ] Method `calculateTotalPages() -> Int`
- [ ] Method `textRange(forPage:) -> NSRange`
- [ ] Method `pageIndex(forCharacterIndex:) -> Int`
- [ ] Handles empty documents (returns 1 page)
- [ ] Handles very long documents (500+ pages)
- [ ] Performance: <100ms for 100-page document

**Code Structure:**
```swift
class TextLayoutManager {
    let textStorage: NSTextStorage
    let layoutManager: NSLayoutManager
    let pageSetup: PageSetup
    
    func calculateTotalPages() -> Int
    func textRange(forPage pageIndex: Int) -> NSRange
    func pageIndex(forCharacterIndex index: Int) -> Int
}
```

**Dependencies:**
- PageLayoutCalculator (Task 1.1)
- NSTextStorage (TextKit)
- NSLayoutManager (TextKit)

---

#### Task 2.2: Create VirtualPageScrollView
**Estimated Time:** 6-8 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Create UIScrollView subclass that manages virtual page views (only renders visible pages).

**Acceptance Criteria:**
- [ ] Class created in `Views/Pagination/VirtualPageScrollView.swift`
- [ ] Implements UIScrollViewDelegate
- [ ] Property `visiblePageRange: Range<Int>`
- [ ] Property `pageViews: [Int: PageView]` (sparse dictionary)
- [ ] Method `updateVisiblePages()` called on scroll
- [ ] Buffer of 2 pages above/below viewport
- [ ] Removes page views when scrolled out of buffer
- [ ] Content size calculated for all pages
- [ ] Performance: Smooth 60fps scrolling

**Code Structure:**
```swift
class VirtualPageScrollView: UIScrollView, UIScrollViewDelegate {
    var visiblePageRange: Range<Int> = 0..<3
    var pageViews: [Int: PageView] = [:]
    let bufferPages = 2
    var totalPages: Int = 0
    
    func updateVisiblePages()
    func createPageView(for pageIndex: Int) -> PageView
    func removePageView(at pageIndex: Int)
    func pageIndexAt(point: CGPoint) -> Int
    func frameForPage(_ pageIndex: Int) -> CGRect
}
```

**Dependencies:**
- TextLayoutManager (Task 2.1)
- PageLayoutCalculator (Task 1.1)

---

#### Task 2.3: Create PageView Component
**Estimated Time:** 3-4 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Create a view that displays a single page (white background, shadow, text content).

**Acceptance Criteria:**
- [ ] Class created in `Views/Pagination/PageView.swift`
- [ ] UIView subclass with white background
- [ ] Drop shadow for depth perception
- [ ] Contains UITextView for text content
- [ ] UITextView is non-editable (read-only)
- [ ] UITextView is non-scrollable
- [ ] Shows page number badge (optional)
- [ ] Shows header/footer zones (gray areas)

**Code Structure:**
```swift
class PageView: UIView {
    let textView: UITextView
    let pageNumber: Int
    var showsHeaderFooterZones: Bool = true
    
    init(pageNumber: Int, textRange: NSRange, textStorage: NSTextStorage)
    func configureTextView()
    func addShadow()
    func drawHeaderFooterZones()
}
```

**Dependencies:**
- PageLayoutCalculator (Task 1.1)

---

#### Task 2.4: Test Virtual Scrolling Performance
**Estimated Time:** 2-3 hours  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Test virtual scrolling with various document sizes and measure performance.

**Acceptance Criteria:**
- [ ] Test with 1-page document
- [ ] Test with 10-page document
- [ ] Test with 50-page document
- [ ] Test with 100-page document
- [ ] Test with 500-page document
- [ ] Memory usage stays under 100MB for 500-page doc
- [ ] Scrolling maintains 60fps
- [ ] Page views correctly added/removed
- [ ] No memory leaks

**Performance Targets:**
```
Document Size | Memory Usage | Scroll FPS | Page Load Time
1 page        | <10MB        | 60fps      | <50ms
10 pages      | <15MB        | 60fps      | <50ms
50 pages      | <30MB        | 60fps      | <100ms
100 pages     | <50MB        | 60fps      | <150ms
500 pages     | <100MB       | 60fps      | <300ms
```

---

### Phase 3: SwiftUI Integration (2-3 days)

#### Task 3.1: Create PaginatedDocumentView (SwiftUI)
**Estimated Time:** 3-4 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Create main SwiftUI view that wraps the pagination system and provides toolbar.

**Acceptance Criteria:**
- [ ] File created: `Views/Pagination/PaginatedDocumentView.swift`
- [ ] Toggle button with `document.on.document` symbol
- [ ] State: `@State private var isPaginated: Bool = false`
- [ ] Shows "Preview Mode" text when paginated
- [ ] Zoom controls in toolbar (when paginated)
- [ ] Smooth transition between edit and paginated modes
- [ ] Preserves scroll position when toggling (stretch goal)

**Code Structure:**
```swift
struct PaginatedDocumentView: View {
    @Bindable var file: TextFile
    @State private var isPaginated: Bool = false
    @State private var zoomLevel: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            
            if isPaginated {
                VirtualPageScrollViewRepresentable(
                    file: file,
                    zoomLevel: $zoomLevel
                )
            } else {
                // Existing edit view
            }
        }
    }
}
```

**Dependencies:**
- VirtualPageScrollView (Task 2.2)
- FileEditView (existing)

---

#### Task 3.2: Create UIViewRepresentable Wrapper
**Estimated Time:** 2-3 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Create UIViewRepresentable to bridge VirtualPageScrollView to SwiftUI.

**Acceptance Criteria:**
- [ ] File created: `Views/Pagination/VirtualPageScrollViewRepresentable.swift`
- [ ] Conforms to UIViewRepresentable protocol
- [ ] Creates VirtualPageScrollView in makeUIView
- [ ] Updates on file content changes
- [ ] Updates on zoom level changes
- [ ] Properly handles lifecycle (appear/disappear)
- [ ] Cleans up resources on dismount

**Code Structure:**
```swift
struct VirtualPageScrollViewRepresentable: UIViewRepresentable {
    let file: TextFile
    @Binding var zoomLevel: CGFloat
    
    func makeUIView(context: Context) -> VirtualPageScrollView
    func updateUIView(_ uiView: VirtualPageScrollView, context: Context)
    func makeCoordinator() -> Coordinator
    
    class Coordinator: NSObject {
        // Manage state between SwiftUI and UIKit
    }
}
```

**Dependencies:**
- VirtualPageScrollView (Task 2.2)
- PaginatedDocumentView (Task 3.1)

---

#### Task 3.3: Integrate into FileEditView
**Estimated Time:** 2-3 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Replace or wrap existing FileEditView with PaginatedDocumentView.

**Acceptance Criteria:**
- [ ] Modify `Views/FileEditView.swift`
- [ ] Add pagination toggle capability
- [ ] Preserve all existing edit functionality
- [ ] Toolbar button in correct position
- [ ] State managed correctly
- [ ] No breaking changes to existing features
- [ ] Works on iPhone, iPad, and Mac Catalyst

**Implementation Note:**  
May need to refactor FileEditView to separate edit mode into its own component.

**Dependencies:**
- PaginatedDocumentView (Task 3.1)
- FileEditView (existing)

---

### Phase 4: Zoom & Gestures (2 days)

#### Task 4.1: Implement Pinch Zoom (iOS/iPadOS)
**Estimated Time:** 3-4 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Add pinch gesture support for zooming in paginated view.

**Acceptance Criteria:**
- [ ] Pinch gesture recognizer added to VirtualPageScrollView
- [ ] Zoom range: 25% to 200%
- [ ] Smooth zoom animation
- [ ] Maintains center point during zoom
- [ ] Updates page layout after zoom
- [ ] Works on iPhone and iPad
- [ ] Does not interfere with scrolling

**Code Structure:**
```swift
class VirtualPageScrollView: UIScrollView {
    let pinchGesture = UIPinchGestureRecognizer()
    var currentZoom: CGFloat = 1.0
    
    func handlePinchGesture(_ gesture: UIPinchGestureRecognizer)
    func setZoom(_ zoom: CGFloat, animated: Bool)
}
```

**Dependencies:**
- VirtualPageScrollView (Task 2.2)

---

#### Task 4.2: Implement Toolbar Zoom Controls
**Estimated Time:** 2-3 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Add zoom buttons to toolbar (+, -, fit width, 100%).

**Acceptance Criteria:**
- [ ] Zoom in button (+)
- [ ] Zoom out button (-)
- [ ] 100% button (reset to actual size)
- [ ] Fit width button (zoom to fit page width)
- [ ] Current zoom percentage display
- [ ] Buttons disabled when at limits
- [ ] Keyboard shortcuts (Mac): Cmd+Plus, Cmd+Minus, Cmd+0

**UI Layout:**
```
[Edit | Paginated] --- [Preview Mode] --- [-] [100%] [+] [Fit Width]
```

**Dependencies:**
- PaginatedDocumentView (Task 3.1)
- VirtualPageScrollView zoom methods (Task 4.1)

---

#### Task 4.3: Platform-Specific Zoom Defaults
**Estimated Time:** 1-2 hours  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Set appropriate default zoom levels for each platform.

**Acceptance Criteria:**
- [ ] iPhone: Default to "Fit Width"
- [ ] iPad: Default to 100%
- [ ] Mac Catalyst: Default to 100%
- [ ] Zoom preference saved per platform
- [ ] Smooth transition when changing devices (iCloud sync)

**Code Structure:**
```swift
enum ZoomDefault {
    static func forCurrentDevice() -> CGFloat {
        #if targetEnvironment(macCatalyst)
            return 1.0  // 100%
        #else
            if UIDevice.current.userInterfaceIdiom == .phone {
                return .fitWidth
            } else {
                return 1.0  // 100%
            }
        #endif
    }
}
```

**Dependencies:**
- Platform detection
- User preferences (optional)

---

### Phase 5: Page Separators (1 day)

#### Task 5.1: Implement Dotted Line Separator
**Estimated Time:** 2-3 hours  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Add dotted lines between pages matching Apple Pages style.

**Acceptance Criteria:**
- [ ] Dotted line appears between each page
- [ ] Matches Apple Pages separator style
- [ ] Adapts to zoom level (line width consistent)
- [ ] Light/dark mode support
- [ ] Optional: Page count label ("Page 2 of 5")

**Code Structure:**
```swift
class PageSeparatorView: UIView {
    let pageNumber: Int
    let totalPages: Int
    var showsPageCount: Bool = true
    
    override func draw(_ rect: CGRect) {
        // Draw dotted line
        // Draw page count label (optional)
    }
}
```

**Reference:**  
Check Apple Pages for exact separator style.

**Dependencies:**
- VirtualPageScrollView (Task 2.2)

---

#### Task 5.2: Add Header/Footer Zone Indicators
**Estimated Time:** 1-2 hours  
**Priority:** Low  
**Status:** ⬜ Not Started

**Description:**  
Show gray areas or subtle borders for header/footer zones (space reservation).

**Acceptance Criteria:**
- [ ] Light gray background for header zone (if hasHeaders)
- [ ] Light gray background for footer zone (if hasFooters)
- [ ] Subtle border or dashed outline
- [ ] Only shows when zones are configured in PageSetup
- [ ] Adapts to light/dark mode
- [ ] Optional: "Header" / "Footer" label

**Visual Design:**
```
┌─────────────────────────────┐
│ [Header Zone - Light Gray]  │ ← headerDepth
├─────────────────────────────┤
│                             │
│   Text Content Area         │
│                             │
├─────────────────────────────┤
│ [Footer Zone - Light Gray]  │ ← footerDepth
└─────────────────────────────┘
```

**Dependencies:**
- PageView (Task 2.3)
- PageSetup model

---

### Phase 6: Testing & Polish (2-3 days)

#### Task 6.1: Manual Testing - All Platforms
**Estimated Time:** 3-4 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Comprehensive manual testing on all platforms and configurations.

**Test Checklist:**

**iPhone:**
- [ ] Toggle to paginated view works
- [ ] Pages display correct size
- [ ] Pinch zoom works smoothly
- [ ] Default zoom is "Fit Width"
- [ ] Scrolling is smooth (60fps)
- [ ] Portrait orientation
- [ ] Landscape orientation
- [ ] Dark mode appearance

**iPad:**
- [ ] Toggle to paginated view works
- [ ] Pages display at readable size
- [ ] Pinch zoom works smoothly
- [ ] Default zoom is 100%
- [ ] Scrolling is smooth (60fps)
- [ ] Portrait orientation
- [ ] Landscape orientation
- [ ] Split view mode
- [ ] Dark mode appearance

**Mac Catalyst:**
- [ ] Toggle to paginated view works
- [ ] Pages display correctly
- [ ] Toolbar zoom controls work
- [ ] Keyboard shortcuts work (Cmd+Plus, Cmd+Minus, Cmd+0)
- [ ] Trackpad pinch works (if available)
- [ ] Window resize doesn't break layout
- [ ] Dark mode appearance

**All Platforms:**
- [ ] Empty document shows 1 blank page
- [ ] 1-page document displays correctly
- [ ] 10-page document displays correctly
- [ ] 50-page document displays correctly
- [ ] 100-page document displays correctly
- [ ] Document with images works
- [ ] Text flows correctly between pages
- [ ] No text clipping or overlap
- [ ] Page separators visible
- [ ] Header/footer zones visible (if configured)
- [ ] Memory usage acceptable
- [ ] No crashes or hangs

---

#### Task 6.2: Performance Testing
**Estimated Time:** 2-3 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Measure and optimize performance for various document sizes.

**Performance Tests:**
- [ ] Measure memory usage for 1, 10, 50, 100, 500 page docs
- [ ] Profile scroll performance (Instruments - FPS)
- [ ] Profile page load time (Time Profiler)
- [ ] Profile zoom performance
- [ ] Identify and fix bottlenecks
- [ ] Verify virtual scrolling working (max 7 page views in memory)

**Performance Targets:**
```
Metric                    | Target      | Measured | Status
--------------------------|-------------|----------|--------
Memory (500 pages)        | <100MB      |          | ⬜
Scroll FPS                | 60fps       |          | ⬜
Page switch time          | <50ms       |          | ⬜
Zoom animation            | <200ms      |          | ⬜
Mode toggle time          | <300ms      |          | ⬜
```

**Tools:**
- Xcode Instruments (Allocations, Time Profiler, Core Animation)
- Manual observation and timing

---

#### Task 6.3: Edge Case Testing
**Estimated Time:** 2-3 hours  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Test edge cases and unusual scenarios.

**Edge Cases:**
- [ ] Empty document (zero characters)
- [ ] Very long single paragraph (spans 20+ pages)
- [ ] Document with only images
- [ ] Document with mixed formatting (bold, italic, colors)
- [ ] Document with very large images
- [ ] Switch PageSetup while in paginated mode
- [ ] Switch between Letter, A4, Legal, A5 paper sizes
- [ ] Switch between portrait and landscape
- [ ] Change margins while viewing
- [ ] Very narrow margins
- [ ] Very wide margins
- [ ] Custom paper size
- [ ] File with no project (fallback PageSetup)
- [ ] Rapid toggling between edit/paginated modes

**Acceptance Criteria:**
- [ ] No crashes
- [ ] Graceful handling of all cases
- [ ] Appropriate fallbacks for missing data

---

#### Task 6.4: Unit Tests for New Components
**Estimated Time:** 3-4 hours  
**Priority:** High  
**Status:** ⬜ Not Started

**Description:**  
Write unit tests for all new pagination components.

**Test Files to Create:**
- [ ] `PageLayoutCalculatorTests.swift` (see Task 1.2)
- [ ] `TextLayoutManagerTests.swift`
- [ ] `VirtualPageScrollViewTests.swift`
- [ ] `PageViewTests.swift`

**Test Coverage Target:** >80%

**Key Tests:**
```swift
// TextLayoutManager
func testCalculateTotalPages_EmptyDocument()
func testCalculateTotalPages_SinglePage()
func testCalculateTotalPages_MultiPage()
func testTextRange_FirstPage()
func testTextRange_LastPage()
func testPageIndex_StartOfDocument()
func testPageIndex_EndOfDocument()

// VirtualPageScrollView
func testVisiblePageRange_InitialLoad()
func testVisiblePageRange_AfterScroll()
func testPageViewCreation()
func testPageViewRemoval()
func testBufferPages()

// PageView
func testPageViewInit()
func testTextViewConfiguration()
func testHeaderFooterZones()
```

---

#### Task 6.5: UI Polish
**Estimated Time:** 2-3 hours  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Polish the UI for professional appearance.

**Polish Items:**
- [ ] Page shadow looks natural (not too harsh)
- [ ] Page background is true white (#FFFFFF)
- [ ] Separator lines are subtle but visible
- [ ] Spacing between pages feels right (20-30pt)
- [ ] Zoom controls are intuitive
- [ ] "Preview Mode" indicator is visible but not distracting
- [ ] Toolbar layout is balanced
- [ ] Icons are correct size and color
- [ ] Transitions are smooth (no jank)
- [ ] Dark mode looks good (white pages on dark background)
- [ ] Loading spinner appears for large documents
- [ ] Progress indicator position is centered

**Reference:**  
Compare to Apple Pages pagination view for inspiration.

---

#### Task 6.6: Documentation
**Estimated Time:** 2-3 hours  
**Priority:** Medium  
**Status:** ⬜ Not Started

**Description:**  
Document the pagination system for future developers.

**Documentation to Create:**
- [ ] Code comments on all public APIs
- [ ] Architecture diagram (ASCII or image)
- [ ] Performance characteristics documented
- [ ] Known limitations documented
- [ ] Future enhancement ideas documented
- [ ] Update main README if needed

**Files to Create/Update:**
- [ ] `specs/010-pagination/IMPLEMENTATION_NOTES.md`
- [ ] `specs/010-pagination/ARCHITECTURE.md`
- [ ] Update `specs/010-pagination/spec.md` with "Implemented" status

---

## Phase 7: Future Enhancements (Not in Scope)

These are ideas for future iterations, not part of initial implementation:

### Enhancement 7.1: Editing in Paginated Mode
**Estimated Time:** 5-7 days  
**Status:** Future

**Description:**  
Allow users to edit text directly in paginated view.

**Challenges:**
- Cursor positioning across page boundaries
- Selection spanning multiple pages
- Formatting toolbar in paginated context
- Undo/redo with pagination
- Performance impact

---

### Enhancement 7.2: Header/Footer Content
**Estimated Time:** 8-10 days  
**Status:** Future (possibly Feature 011)

**Description:**  
Allow users to define header/footer content with page numbers, titles, etc.

**Scope:**
- Header/footer text editor
- Variables: page number, total pages, title, author, date
- Different first page
- Different odd/even pages
- Font/style customization

---

### Enhancement 7.3: Print/Export Integration
**Estimated Time:** 3-5 days  
**Status:** Future

**Description:**  
Add "Export PDF" button to paginated toolbar that uses pagination layout.

**Scope:**
- PDF generation matching paginated view exactly
- Print dialog integration
- Page range selection
- Print settings

---

### Enhancement 7.4: Custom Page Breaks
**Estimated Time:** 3-4 days  
**Status:** Future

**Description:**  
Allow users to insert manual page breaks in edit mode.

**Scope:**
- "Insert Page Break" menu item
- Visual indicator in edit mode
- Respect breaks in paginated view
- Export honors breaks

---

## Success Metrics

**Definition of Done:**
- [ ] All Phase 1-6 tasks completed
- [ ] All unit tests pass
- [ ] All manual tests pass
- [ ] Performance targets met
- [ ] No known critical bugs
- [ ] Code reviewed and approved
- [ ] Documentation complete
- [ ] Feature demoed to stakeholders

**Performance Targets Met:**
- [ ] Memory usage <100MB for 500-page document
- [ ] Smooth 60fps scrolling
- [ ] Page load time <50ms for typical page
- [ ] Mode toggle <300ms

**Platform Support:**
- [ ] Works on iPhone (iOS 17+)
- [ ] Works on iPad (iOS 17+)
- [ ] Works on Mac Catalyst (macOS 14+)

**Quality:**
- [ ] No crashes in testing
- [ ] No memory leaks
- [ ] Code coverage >80%
- [ ] All edge cases handled

---

## Notes

### Known Limitations (Initial Release)
1. **Read-only mode** - cannot edit text in paginated view (by design)
2. **No page numbers** - reserved space shown, but no content yet
3. **No headers/footers** - reserved space shown, but no content yet
4. **No manual page breaks** - only automatic page breaks
5. **No print/export** - just preview (export is separate feature)

### Technical Debt to Address Later
1. Consider page view recycling pool (like UITableView cell reuse)
2. Consider lazy layout calculation (calculate pages on-demand)
3. Consider caching layout information for frequently viewed docs
4. Consider background pre-calculation of page layout

### Performance Notes
- Virtual scrolling is critical for scalability
- NSLayoutManager calculation is fast but can be optimized with caching
- Page view creation is the bottleneck (UITextView allocation)
- Consider reusing UITextViews from a pool

### Testing Notes
- Test on real devices, not just simulator
- Test with real user documents (various sizes and formats)
- Performance profile on oldest supported device (iPhone SE?)
- Memory test on device with lowest RAM

---

## Task Summary

**Total Tasks:** 21  
**Estimated Days:** 12-16 days  

**By Phase:**
- Phase 1 (Layout): 2 tasks, 2-3 days
- Phase 2 (Virtual Scrolling): 4 tasks, 3-4 days
- Phase 3 (SwiftUI): 3 tasks, 2-3 days
- Phase 4 (Zoom): 3 tasks, 2 days
- Phase 5 (Separators): 2 tasks, 1 day
- Phase 6 (Testing): 6 tasks, 2-3 days

**By Priority:**
- High: 13 tasks
- Medium: 6 tasks
- Low: 1 task

**Future Enhancements:** 4 ideas (not in scope)
