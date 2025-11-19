# Feature 010: Paginated Document View - Research

## Background
This feature aims to provide a paginated view of documents, similar to:
- Traditional word processors (Pages, Word)
- Writing Shed v1 on Mac
- Mac TextEdit sample code pagination implementation

**Key Insight:** Pagination is fundamentally a *display* feature, not an editing feature. The document remains a continuous flow of text; pagination is just a visual representation for preview and export.

## Key Technologies

### TextKit 1 vs TextKit 2

**Decision: Use TextKit 1** ✅

**Rationale:**
1. **Better documentation:** TextKit 1 has extensive documentation and examples
2. **Cross-platform:** Works on iOS, iPadOS, and Mac Catalyst
3. **Proven approach:** Used successfully in Pages, Word, and countless text editors
4. **Multiple containers:** Supports multiple NSTextContainer objects for multi-page layout
5. **Mature API:** Stable, well-understood, fewer edge cases

**TextKit 2 Limitations:**
- Less documentation for pagination use cases
- Different API surface (not backward compatible)
- Still evolving (iOS 15+)
- Unclear advantages for our use case

### NSTextView (Mac/Catalyst)
```objc
// Traditional Mac approach
NSTextView *textView = [[NSTextView alloc] initWithFrame:NSZeroRect];
NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
NSTextStorage *textStorage = [[NSTextStorage alloc] init];

[textStorage addLayoutManager:layoutManager];
[layoutManager addTextContainer:textView.textContainer];
```

**Key Features:**
- Multiple NSTextContainer objects for multi-page layout
- NSLayoutManager coordinates text flow
- One NSTextView per page
- Automatic text flow between containers

### UITextView (iOS/iPadOS)
```swift
// iOS approach (very similar)
let textView = UITextView(frame: .zero)
let layoutManager = NSLayoutManager()
let textStorage = NSTextStorage()

textStorage.addLayoutManager(layoutManager)
layoutManager.addTextContainer(textView.textContainer)
```

**Key Features:**
- Same TextKit 1 APIs as Mac
- UITextContainer configuration
- NSLayoutManager handles layout
- Custom page layout via scroll view
- Platform-specific gestures (pinch-to-zoom)

### TextKit 1 Architecture

```
NSTextStorage (model - attributed string)
    ↓
NSLayoutManager (controller - calculates layout)
    ↓
NSTextContainer(s) (geometry - defines shape)
    ↓
UITextView(s) (view - displays text)
```

**Multiple Containers = Multiple Pages:**
```swift
let layoutManager = NSLayoutManager()
textStorage.addLayoutManager(layoutManager)

// Add one container per page
for pageIndex in 0..<pageCount {
    let container = NSTextContainer(size: pageSize)
    layoutManager.addTextContainer(container)
    
    let textView = UITextView(frame: pageFrame, textContainer: container)
    // Position and add to view hierarchy
}
```

**Automatic Text Flow:**
- When container 1 fills up, text automatically flows to container 2
- No manual text splitting required
- TextKit handles line breaking, word wrapping, hyphenation
- Container boundaries = page boundaries

## Virtual Scrolling Strategy

### The Problem
Large documents (200+ pages) cannot render all pages at once:
- Memory: 200 pages × ~1MB per page = 200MB+ just for text views
- Performance: Creating 200 UITextView instances is slow
- Unnecessary: User only sees 1-3 pages at a time

### The Solution: Virtual Scrolling
Only render pages that are currently visible (or about to become visible)

**Inspired by:**
- UITableView cell reusing
- UICollectionView's dequeueReusableCell
- Virtual DOM in web frameworks
- Infinite scrolling in social media apps

### Implementation Strategy

**Step 1: Calculate Total Height**
```swift
func calculateTotalScrollHeight(pageCount: Int, pageHeight: CGFloat, spacing: CGFloat) -> CGFloat {
    return CGFloat(pageCount) * (pageHeight + spacing) - spacing
}
```

**Step 2: Size UIScrollView Content**
```swift
scrollView.contentSize = CGSize(
    width: pageWidth + (horizontalPadding * 2),
    height: calculateTotalScrollHeight(...)
)
```

**Step 3: Track Visible Range**
```swift
func updateVisiblePages() {
    let visibleRect = scrollView.bounds
    
    // Calculate which pages are visible
    let firstVisiblePage = pageIndex(at: visibleRect.minY)
    let lastVisiblePage = pageIndex(at: visibleRect.maxY)
    
    // Add 2-page buffer above and below
    let bufferFirst = max(0, firstVisiblePage - 2)
    let bufferLast = min(totalPages - 1, lastVisiblePage + 2)
    let newRange = bufferFirst..<(bufferLast + 1)
    
    if newRange != currentVisibleRange {
        updateRenderedPages(newRange)
    }
}
```

**Step 4: Create/Destroy Pages Dynamically**
```swift
func updateRenderedPages(_ newRange: Range<Int>) {
    // Remove pages outside new range
    let pagesToRemove = Set(renderedPages.keys).subtracting(Set(newRange))
    for pageIndex in pagesToRemove {
        renderedPages[pageIndex]?.removeFromSuperview()
        renderedPages.removeValue(forKey: pageIndex)
    }
    
    // Add pages in new range
    for pageIndex in newRange where renderedPages[pageIndex] == nil {
        let pageView = createPageView(for: pageIndex)
        scrollView.addSubview(pageView)
        renderedPages[pageIndex] = pageView
    }
}
```

**Memory Profile:**
- Small document (5 pages): Renders all 5 pages (~5MB)
- Medium document (50 pages): Renders 5-7 pages at a time (~7MB)
- Large document (500 pages): Still renders 5-7 pages (~7MB)

**Performance:**
- Constant memory usage regardless of document size
- Smooth 60fps scrolling
- Pages render in <16ms (one frame)
- No perceptible lag

## Reference Implementations

### Writing Shed v1 (Mac)
**Key Learnings:**
- Used NSTextView with multiple NSTextContainer objects
- Rendered all pages (no virtual scrolling) - worked fine for novels (300-500 pages)
- Mac has more memory available than iOS
- Print preview = pagination view (WYSIWYG)

**What We'll Do Differently:**
- Add virtual scrolling for iOS memory constraints
- Better separation between edit and preview modes
- Modernize with SwiftUI wrapper

### Apple TextEdit Sample Code
**Key Insights:**
- Multiple text containers is the standard approach
- Page breaks via paragraph style attributes
- One NSLayoutManager per document (not per page)
- Text storage shared across all containers

**Code Pattern:**
```objc
// Create shared layout manager
NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
[textStorage addLayoutManager:layoutManager];

// Add containers for each page
for (NSInteger i = 0; i < pageCount; i++) {
    NSTextContainer *container = [[NSTextContainer alloc] initWithSize:pageSize];
    [layoutManager addTextContainer:container];
}
```

### Third-Party Solutions

**DTCoreText** (HTML → NSAttributedString)
- Demonstrates advanced TextKit usage
- Custom text containers for complex layouts
- Not needed for our use case (we already have attributed strings)

**YYText** (High-performance text framework)
- Shows optimization techniques
- Asynchronous rendering
- May be overkill for our needs

**Takeaway:** TextKit 1's built-in features are sufficient; no need for third-party frameworks

## Technical Challenges & Solutions

### Challenge 1: Text Flow Between Pages

**Problem:**
How to make text automatically flow from page 1 to page 2 to page 3, etc.?

**Solution:** ✅ NSLayoutManager with Multiple NSTextContainer Objects

TextKit automatically handles text flow:
1. Add multiple NSTextContainer objects to one NSLayoutManager
2. Each container represents one page's text area
3. When container fills up, text flows to next container
4. No manual text splitting required

```swift
let layoutManager = NSLayoutManager()
let textStorage = NSTextStorage(string: documentText)
textStorage.addLayoutManager(layoutManager)

// Add containers for pages 0, 1, 2...
for pageIndex in 0..<totalPages {
    let container = NSTextContainer(size: pageContentSize)
    layoutManager.addTextContainer(container)
}

// TextKit automatically flows text between containers!
```

**Key APIs:**
- `layoutManager.glyphRange(for: textContainer)` - which glyphs are in this container
- `layoutManager.textRange(for: textContainer)` - which characters are in this container
- `layoutManager.usedRect(for: textContainer)` - actual bounds of text in container

### Challenge 2: Performance with Large Documents

**Problem:**
- A 500-page novel has ~100,000 words, ~500,000 characters
- Creating 500 UITextView instances = slow, memory-intensive
- Laying out all text at once = UI freeze

**Solution 1:** ✅ Virtual Scrolling (Primary Solution)
Only render visible pages + small buffer (5-7 pages total)
- Described in detail above
- Constant memory usage
- Smooth scrolling

**Solution 2:** ✅ On-Demand Layout
```swift
layoutManager.allowsNonContiguousLayout = true
```
- Allows TextKit to layout text lazily
- Only lays out visible ranges
- Improves initial load time

**Solution 3:** ✅ Background Layout (Future Enhancement)
```swift
DispatchQueue.global(qos: .userInitiated).async {
    layoutManager.ensureLayout(for: textRange)
    DispatchQueue.main.async {
        // Update UI
    }
}
```

**Performance Targets:**
- Initial page calculation: <200ms for 500-page document
- Scroll response: 60fps (16ms per frame)
- Memory usage: <50MB for pagination view
- Page switching: <50ms

### Challenge 3: Edit vs Preview Modes

**Problem:**
Should users be able to edit in paginated view?

**Research Findings:**
- **Pages:** Editable in paginated view (complex implementation)
- **Word:** Editable in Print Layout view (default mode)
- **Google Docs:** Editable in paginated view
- **Writing Shed v1:** Read-only pagination (simpler)

**Decision:** ✅ Read-Only Preview Mode (Phase 1)

**Rationale:**
1. **Simpler implementation:** No cursor positioning across page breaks
2. **Clearer UX:** Edit mode = edit, Preview mode = preview
3. **Matches spec:** "Read-only preview mode - editing happens in edit mode"
4. **Future enhancement:** Can add editing later if needed

**User Flow:**
1. User edits in continuous edit mode
2. Toggles to pagination mode to preview
3. Sees exactly what will export/print
4. Toggles back to edit mode to make changes

### Challenge 4: Platform Differences (iOS vs Mac)

**Differences:**

| Feature | iOS/iPadOS | Mac Catalyst |
|---------|-----------|--------------|
| Text View | UITextView | UITextView (via Catalyst) |
| Zoom | Pinch gesture | Pinch gesture + toolbar controls |
| Scroll | Touch | Trackpad/mouse + touch |
| Memory | More constrained | More available |
| Screen Size | Smaller | Larger |

**Platform-Specific Handling:**

```swift
#if targetEnvironment(macCatalyst)
// Mac-specific: Add zoom controls to toolbar
toolbar {
    Button("-") { zoomOut() }
    Text("\(Int(zoomScale * 100))%")
    Button("+") { zoomIn() }
}
#else
// iOS: Rely on pinch gesture only
#endif
```

**Unified Approach:**
- Same core TextKit code for all platforms
- Platform-specific UI chrome (toolbars, gestures)
- Test on all three: iPhone, iPad, Mac

## Architectural Decisions

### Decision 1: TextKit 1 over TextKit 2
**Reason:** Better documentation, proven approach, cross-platform

### Decision 2: Virtual Scrolling
**Reason:** Essential for large document performance

### Decision 3: Read-Only Preview (Phase 1)
**Reason:** Simpler, clearer UX, matches spec

### Decision 4: UIKit for Core, SwiftUI for Wrapper
**Reason:** TextKit integrates naturally with UIKit, SwiftUI for modern UI

### Decision 5: Shared NSTextStorage
**Reason:** Consistency between edit and preview modes, single source of truth

### Decision 6: Project-Level PageSetup
**Reason:** Already implemented, applies to all files in project

### Decision 7: No Custom Text Rendering
**Reason:** TextKit handles everything (fonts, colors, alignment, images)

## Implementation Approach (Validated)

### Phase 1: Foundation ✅ (CURRENT)
- [x] PageLayoutCalculator utility
- [x] Unit tests for page calculations
- [x] Documentation (data-model.md, research.md)
- [x] Understanding of existing PageSetup models

### Phase 2: Text Layout Engine (NEXT)
- [ ] PaginatedTextLayoutManager class
- [ ] Page count calculation
- [ ] Text range mapping (which text on which page)
- [ ] Integration with NSLayoutManager

### Phase 3: Virtual Scrolling
- [ ] VirtualPageScrollView (UIViewRepresentable)
- [ ] Visible range tracking
- [ ] Page view creation/destruction
- [ ] Page view recycling

### Phase 4: UI Integration
- [ ] PaginatedDocumentView (SwiftUI)
- [ ] View mode toggle
- [ ] Zoom controls
- [ ] Integration with FileEditView

### Phase 5: Polish & Testing
- [ ] Cross-platform testing
- [ ] Performance optimization
- [ ] Bug fixes
- [ ] Documentation completion

## Open Questions (Resolved)

### ~~Q1: Should pagination be editable?~~
**A:** No, read-only preview for Phase 1. Can enhance later if needed.

### ~~Q2: How to handle images in paginated view?~~
**A:** TextKit handles NSTextAttachment automatically. Images flow with text.

### ~~Q3: Should we support facing pages mode?~~
**A:** Not in Phase 1. Single-page continuous scroll only. Future enhancement.

### ~~Q4: How to handle very long documents (1000+ pages)?~~
**A:** Virtual scrolling handles it. No upper limit on page count.

### ~~Q5: Should page count be calculated eagerly or lazily?~~
**A:** Eagerly on mode switch (one-time cost), lazily update on text changes.

## Remaining Questions

### Q1: Should we cache page layouts between mode switches?
**Consideration:** If user toggles edit → paginated → edit → paginated frequently, should we keep the layout manager alive?
**Tradeoff:** Memory vs recalculation time
**Decision:** Phase 2 - measure performance and decide

### Q2: How to handle cursor position when switching modes?
**Scenario:** User has cursor at character 50,000 in edit mode. Switches to paginated mode. Should we scroll to the page containing that character?
**Decision:** Phase 4 - nice-to-have feature, not essential

### Q3: Should zoom level persist per-file or globally?
**Options:** 
- Global: All files use same zoom (simpler)
- Per-file: Each file remembers its zoom (better UX)
**Decision:** Phase 4 - start with global, consider per-file

## References

### Apple Documentation
- [NSTextContainer Documentation](https://developer.apple.com/documentation/appkit/nstextcontainer)
- [NSLayoutManager Documentation](https://developer.apple.com/documentation/appkit/nslayoutmanager)
- [Text Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextArchitecture/Introduction/Introduction.html)
- [NSTextStorage Documentation](https://developer.apple.com/documentation/uikit/nstextstorage)

### WWDC Sessions
- WWDC 2013: "Advanced Text Layouts and Effects with Text Kit"
- WWDC 2018: "TextKit Best Practices"
- WWDC 2021: "What's New in TextKit 2"

### Third-Party Resources
- [objc.io: TextKit](https://www.objc.io/issues/5-ios7/getting-to-know-textkit/)
- [Ray Wenderlich: TextKit Tutorial](https://www.raywenderlich.com/books/ios-apprentice)
- [NSHipster: NSTextContainer](https://nshipster.com/nstextcontainer/)

## Success Metrics

### Phase 1 (Foundation) - COMPLETE ✅
- [x] PageLayoutCalculator correctly calculates all dimensions
- [x] Unit tests pass for all paper sizes and orientations
- [x] Documentation clearly explains architecture
- [x] Foundation ready for Phase 2

### Future Phases
- Phase 2: Page count calculation works for 500+ page documents
- Phase 3: Virtual scrolling maintains 60fps with smooth scrolling
- Phase 4: Mode toggle is instantaneous (<200ms)
- Phase 5: Zero critical bugs, works on all platforms
