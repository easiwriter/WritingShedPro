# Feature 010: Paginated Document View

## Overview
The app should have an option to display a paginated view. That is a view that displays pages whose size is determined by the PageSetup model. This should include the space defined for headers/footers.

**Key Architecture Decision:** Virtual scrolling with on-demand page rendering (only visible pages + buffer are rendered). Critical for performance with large documents (200+ page novels).

## User Requirements
1. Pagination is accessed using a toolbar button - `document.on.document` symbol to turn it on and `document.on.document.fill` to turn it off
2. Pages are separated by a dotted line (or what Pages uses)
3. A zoom capability should be added (including pinch gesture)
4. **Read-only preview mode** - editing happens in edit mode, not paginated mode
5. Pagination view = print preview (what you see = what you export)
## Technical Approach

### Core Architecture
The pagination view will use **virtual scrolling** with **on-demand page rendering**. Only visible pages are rendered to conserve memory for large documents (200+ pages).

```
NSLayoutManager (calculates layout for entire document)
    └── Virtual page containers (calculated, not all rendered)

UIScrollView
    └── Content view (sized for all pages)
        └── Page views (only visible + buffer pages)
            └── UITextView per visible page
```

**Virtual Scrolling Benefits:**
- Memory efficient: Only 5-7 page views in memory at once
- Smooth scrolling: Pages render as needed
- Scalable: Handles 500+ page novels without performance issues
- Similar to UITableView/UICollectionView reuse strategy

### Key Components

1. **PaginatedDocumentView** (SwiftUI wrapper)
   - Manages view mode toggle (edit vs paginated)
   - Coordinates zoom/pinch gestures
   - Houses the UIKit pagination view
   - Shows "Preview Mode" indicator

2. **VirtualPageScrollView** (UIKit - UIViewRepresentable)
   - Manages UIScrollView with content sized for all pages
   - Calculates which pages are visible as user scrolls
   - Creates/removes page views dynamically
   - Maintains 2-page buffer above/below visible area
   - Recycles page views when possible

3. **PageLayoutCalculator**
   - Uses NSLayoutManager to calculate total page count
   - Calculates which text range belongs to each page
   - Derives page dimensions from PageSetup model
   - Handles header/footer reserved space
   - Calculates page positions in scroll view

4. **PageSeparatorView**
   - Draws dotted lines between pages
   - Matches Apple Pages style

### Text Flow Strategy
TextKit 1's NSLayoutManager automatically flows text between text containers:
- When a container fills up, text flows to the next container
- No manual text splitting required
- Page breaks happen naturally at container boundaries
- Can insert explicit page breaks via paragraph style attributes

### Zoom Implementation
- **iOS/iPad**: Use UIScrollView's built-in zoom with pinch gestures
- **Mac Catalyst**: Zoom controls in toolbar + pinch gesture support
- Zoom scales the entire page view hierarchy, not individual text

## Implementation Details

### Phase 1: Page Layout Engine

**PageSetup Model** (already exists?)
```swift
class PageSetup {
    var paperSize: PaperSize  // A4, Letter, etc.
    var orientation: Orientation  // Portrait, Landscape
    var margins: EdgeInsets  // Top, Bottom, Left, Right
    var headerHeight: CGFloat
    var footerHeight: CGFloat
}
```

**Page Dimensions**
```swift
func calculatePageRect(from setup: PageSetup) -> CGRect {
    let paperSize = setup.paperSize.size(for: setup.orientation)
    return CGRect(origin: .zero, size: paperSize)
}

func calculateTextRect(from setup: PageSetup) -> CGRect {
    let pageRect = calculatePageRect(from: setup)
    return pageRect.inset(by: setup.margins)
                    .inset(by: UIEdgeInsets(
                        top: setup.headerHeight,
                        left: 0,
                        bottom: setup.footerHeight,
                        right: 0
                    ))
}
```

### Phase 2: Text Container Creation

```swift
func createTextContainers(count: Int, setup: PageSetup) -> [NSTextContainer] {
    let textRect = calculateTextRect(from: setup)
    let textSize = textRect.size
    
    return (0..<count).map { _ in
        let container = NSTextContainer(size: textSize)
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        return container
    }
}
```

### Phase 3: NSLayoutManager Setup

```swift
class PaginatedLayoutManager {
    let layoutManager = NSLayoutManager()
    let textStorage: NSTextStorage
    var textContainers: [NSTextContainer] = []
    var textViews: [UITextView] = []
    
    func addPage(with setup: PageSetup) {
        let container = createTextContainer(from: setup)
        layoutManager.addTextContainer(container)
        textContainers.append(container)
        
        let textView = UITextView(frame: .zero, textContainer: container)
        textView.isScrollEnabled = false
        textView.isEditable = true  // Allow editing in paginated view
        textViews.append(textView)
    }
    
    func removeExtraPages() {
        // Remove empty pages at the end
        // Keep at least one page
    }
}
```

### Phase 4: Virtual Scrolling Implementation

**Calculate Total Pages:**
```swift
func calculateTotalPages() -> Int {
    let textRect = calculateTextRect(from: pageSetup)
    let containerSize = textRect.size
    
    // Force layout for entire document
    layoutManager.glyphRange(for: textStorage)
    
    // Calculate how many pages needed
    var pageCount = 0
    var glyphIndex = 0
    
    while glyphIndex < layoutManager.numberOfGlyphs {
        let container = NSTextContainer(size: containerSize)
        let usedRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: layoutManager.numberOfGlyphs - glyphIndex),
            in: container
        )
        
        // This range fits in one page
        let glyphsInPage = layoutManager.glyphRange(forBoundingRect: usedRect, in: container).length
        glyphIndex += glyphsInPage
        pageCount += 1
    }
    
    return max(pageCount, 1)  // Always at least one page
}
```

**Track Visible Pages:**
```swift
class VirtualPageScrollView: UIScrollView, UIScrollViewDelegate {
    var visiblePageRange: Range<Int> = 0..<3
    var pageViews: [Int: UITextView] = [:]  // pageIndex -> view
    let bufferPages = 2
    var totalPages: Int = 0
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateVisiblePages()
    }
    
    func updateVisiblePages() {
        let visibleRect = bounds
        
        // Calculate which pages are visible
        let firstPage = pageIndexAt(point: visibleRect.origin)
        let lastPage = pageIndexAt(point: CGPoint(x: visibleRect.maxX, y: visibleRect.maxY))
        
        // Add buffer
        let newRange = max(0, firstPage - bufferPages)..<min(totalPages, lastPage + bufferPages + 1)
        
        if newRange != visiblePageRange {
            // Remove pages outside new range
            let pagesToRemove = Set(pageViews.keys).subtracting(Set(newRange))
            for page in pagesToRemove {
                pageViews[page]?.removeFromSuperview()
                pageViews.removeValue(forKey: page)
            }
            
            // Add pages in new range
            for page in newRange where pageViews[page] == nil {
                let pageView = createPageView(for: page)
                addSubview(pageView)
                pageViews[page] = pageView
            }
            
            visiblePageRange = newRange
        }
    }
    
    func createPageView(for pageIndex: Int) -> UITextView {
        let pageRect = frameForPage(pageIndex)
        let textView = UITextView(frame: pageRect)
        textView.isScrollEnabled = false
        textView.isEditable = false  // Read-only in paginated mode
        textView.backgroundColor = .white
        
        // Set text storage range for this page
        let textRange = textRangeForPage(pageIndex)
        // Configure text view with this range...
        
        return textView
    }
}
```

### Phase 5: SwiftUI Integration

```swift
struct PaginatedDocumentView: View {
    @State private var isPaginated: Bool = false
    @State private var scale: CGFloat = 1.0
    let file: TextFile
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Toggle button
                Button(action: { isPaginated.toggle() }) {
                    Label("Paginated View", systemImage: isPaginated ? "document.on.document.fill" : "document.on.document")
                }
                
                if isPaginated {
                    Spacer()
                    Text("Preview Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Zoom controls
                    zoomControls
                }
            }
            .padding()
            
            if isPaginated {
                VirtualPageScrollViewRepresentable(
                    file: file,
                    scale: $scale
                )
                    }
                    .frame(
                        width: pageWidth * scale,
                        height: pageHeight * scale
                    )
                    
                    if pageIndex < pageCount - 1 {
                        PageSeparator()
                    }
                }
            }
            .padding()
        }
    }
}
```

### Phase 6: Zoom Support

```swift
// iOS/iPadOS
ScrollView {
    // ... page content
}
.gesture(
    MagnificationGesture()
        .onChanged { value in
            scale = value
        }
)

// Toolbar zoom controls
Button("-") { scale = max(0.25, scale - 0.25) }
Text("\(Int(scale * 100))%")
Button("+") { scale = min(2.0, scale + 0.25) }
```

### Phase 7: Page Separators

Match Apple Pages style:
```swift
struct PageSeparator: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let y = geometry.size.height / 2
                var x: CGFloat = 0
                let dashLength: CGFloat = 5
                let gapLength: CGFloat = 5
                
                while x < geometry.size.width {
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + dashLength, y: y))
                    x += dashLength + gapLength
                }
            }
            .stroke(Color.gray, lineWidth: 1)
        }
        .frame(height: 1)
    }
}
```

## UI/UX Design

### Toolbar Button
- **Icon**: `document.on.document` (off state), `document.on.document.fill` (on state)
- **Location**: FileEditView toolbar, near formatting controls
- **Toggle behavior**: Switches between edit mode and paginated view
- **State preservation**: Remember user's last choice per file?

### Paginated View Layout
```
┌─────────────────────────────────────┐
│  Toolbar (Zoom controls)            │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │  Page 1 Content             │   │
│  │                             │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│  ············dotted line···········  │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │  Page 2 Content             │   │
│  │                             │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

### Zoom Controls
**iPad/iPhone:**
- Pinch gesture (standard iOS behavior)
- Optional: Zoom buttons in toolbar (- 100% +)

**Mac Catalyst:**
- Zoom buttons in toolbar (required)
- Pinch gesture on trackpad (if available)
- Keyboard shortcuts: Cmd+Plus, Cmd+Minus, Cmd+0 (reset)

### Edit vs Paginated Mode

**Edit Mode** (current):
- Single continuous text view
- Scrolls naturally
- Full editing capabilities
- Formatting toolbar visible

**Paginated Mode** (new):
- Multiple page views
- Shows page boundaries
- Editing still allowed (important!)
- Zoom controls visible
- Can see document structure

### Transition Animation
Smooth transition when toggling:
- Fade/crossfade between modes
- Preserve scroll position (go to same text location)
- Duration: ~0.3 seconds

## Platform Considerations

### iOS (iPhone)
**Challenges:**
- Small screen - pages will be zoomed out
- Must feel natural despite page view

**Solutions:**
- Default zoom to fit width
- Generous spacing between pages
- Smooth scrolling
- Consider: Portrait pages work better on phone

### iPadOS
**Optimal platform:**
- Large screen shows full pages at readable size
- Pinch zoom works perfectly
- Split view could show edit + paginated side-by-side (future)

### Mac Catalyst
**Considerations:**
- Mouse interaction instead of touch
- Keyboard shortcuts important
- Can show larger zoom range
- Trackpad gestures if available

### Universal Considerations
- Page shadow for depth perception
- White page on gray/colored background
- Smooth scroll performance (use UIScrollView optimization)
- Memory management for very long documents (100+ pages)

## Dependencies

### System Frameworks
- **UIKit**: NSLayoutManager, NSTextStorage, NSTextContainer, UITextView
- **SwiftUI**: For wrapping UIKit components
- **Foundation**: For text handling

### Internal Models
- **PageSetup**: Paper size, margins, orientation (verify if exists)
- **TextFile**: Current document model
- **Version**: Current version system

### Existing Features Required
- ✅ Text editing system (BaseModels.swift - TextFile)
- ✅ Version management (TextFile+Versions.swift)
- ✅ Formatting system (Feature 005)
- ❓ PageSetup model (needs verification)

### New Components to Create
1. **PaginatedDocumentView** - Main SwiftUI view
2. **PaginatedTextView** - UIViewRepresentable wrapper
3. **PageLayoutEngine** - Calculates page dimensions
4. **PageContainerManager** - Manages NSTextContainer instances
5. **PageSeparatorView** - Draws dotted lines between pages

## Testing Requirements

### Unit Tests
**Page Layout Calculations:**
- Test page dimension calculations for different paper sizes
- Verify margin calculations
- Test header/footer space allocation
- Edge cases: zero margins, full-bleed

**Text Container Management:**
- Test container creation/removal
- Verify text flows to next page when container fills
- Test empty page removal
- Test page count accuracy

### Integration Tests
**Text Flow:**
- Add text and verify new pages created
- Delete text and verify pages removed
- Test with formatted text (bold, italic, etc.)
- Test with images

**Zoom Functionality:**
- Test zoom in/out maintains text location
- Test zoom limits (min/max)
- Test zoom reset to 100%

### Manual Testing Checklist
**Core Functionality:**
- [ ] Toggle to paginated view
- [ ] Pages display correct size
- [ ] Text flows between pages
- [ ] Can edit in paginated mode (if implemented)
- [ ] Dotted lines appear between pages
- [ ] Can scroll through document

**Zoom:**
- [ ] Pinch gesture works (iOS/iPadOS)
- [ ] Zoom buttons work
- [ ] Keyboard shortcuts work (Mac)
- [ ] Maintains scroll position when zooming

**Performance:**
- [ ] Test with 1-page document
- [ ] Test with 10-page document
- [ ] Test with 50-page document
- [ ] Test with 100-page document
- [ ] Test with images in document
- [ ] Memory usage acceptable
- [ ] Scroll performance smooth

**Edge Cases:**
- [ ] Empty document (show one blank page)
- [ ] Very long single paragraph (spans multiple pages)
- [ ] Document with only images
- [ ] Switch between different PageSetup sizes
- [ ] Rotate device (iOS/iPadOS)

**Platform-Specific:**
- [ ] iPhone portrait/landscape
- [ ] iPad portrait/landscape
- [ ] iPad Split View
- [ ] Mac Catalyst window resize
- [ ] Dark mode appearance

## ✅ DECISIONS MADE

### 1. State Preservation
**Decision:** ✅ Always start in edit mode
- Simple, predictable behavior
- User explicitly toggles to paginated view when needed

---

### 2. Edit Capabilities in Paginated Mode
**Decision:** ✅ Read-only preview mode
- Paginated view is for "what will this look like printed"
- Show "Preview Mode" indicator in toolbar
- To edit, user switches back to edit mode

---

### 3. Page Number Display
**Decision:** ✅ Page numbers will be shown in headers/footers
- Configured separately in Header/Footer feature (future)
- Pagination feature doesn't render header/footer content
- Just reserves space defined in PageSetup model

---

### 4. Performance for Large Documents
**Decision:** ✅ Virtual scrolling - only render visible pages
- More complex but necessary for scalability
- Render visible pages + buffer (e.g., 2 pages above/below viewport)
- Dispose of off-screen page views to conserve memory
- Critical for 200+ page novels

**Implementation Strategy:**
```swift
// Track which pages are visible
var visiblePageRange: Range<Int> = 0..<3
let bufferPages = 2

func updateVisiblePages(scrollView: UIScrollView) {
    let visibleRect = scrollView.bounds
    let firstPage = pageAtLocation(visibleRect.origin)
    let lastPage = pageAtLocation(CGPoint(x: visibleRect.maxX, y: visibleRect.maxY))
    
    // Add buffer
    let newRange = max(0, firstPage - bufferPages)..<min(totalPages, lastPage + bufferPages + 1)
    
    if newRange != visiblePageRange {
        // Remove old pages outside range
        // Add new pages in range
        visiblePageRange = newRange
    }
}
```

---

### 5. PageSetup Integration
**Status:** ✅ PageSetup exists in `Models/PageSetupModels.swift`
**Scope:** Per-project configuration (accessed via Project Details view)

**PageSetup Properties Used:**
```swift
- paperSize: PaperSizes (.Letter, .Legal, .A4, .A5, .Custom)
- orientation: Orientation (.portrait, .landscape)
- marginTop, marginBottom, marginLeft, marginRight: Double (in points)
- headerDepth, footerDepth: Double (in points)
- hasHeaders, hasFooters: Bool
```

**Integration:**
- Each TextFile belongs to a Project
- Project has one PageSetup
- Pagination uses `file.folder?.project?.pageSetup` to get dimensions

---

### 6. Header/Footer Content
**Decision:** ✅ Reserve space only (no content rendering)
- PageSetup defines headerDepth and footerDepth
- Show gray areas or leave blank for header/footer zones
- Actual header/footer content is separate feature (later)
- Page numbers will appear here once header/footer feature exists

---

### 7. Export/Print Integration
**Decision:** ✅ Yes - paginated view is print preview
- What you see = what you get when exporting
- Consider adding "Export PDF" button to paginated toolbar
- Page breaks, margins, headers/footers all match export

---

### 8. Transition Performance
**Question:** What happens while switching to paginated mode for large document?

**Options:**
- A) Block UI with progress indicator
- B) Show partial pages as they render
- C) Pre-calculate in background when file opens

**Recommendation:** Option A for simplicity. NSLayoutManager is fast - most documents will switch instantly. Add progress bar only if it takes >0.5 seconds.

---

### 9. Zoom Range
**Decision:** ✅ As recommended
- **iPhone default:** Fit to width (pages small on phone)
- **iPad default:** 100% (readable at actual size)
- **Mac default:** 100%
- **Range:** 25% to 200%

**Zoom Levels:**
```swift
enum ZoomLevel {
    case fitWidth
    case fitPage
    case custom(percent: Double)
    
    static let minimum: Double = 0.25  // 25%
    static let maximum: Double = 2.0   // 200%
}
```

## References
- Old TextEdit sample code (Mac)
- Writing Shed v1 pagination implementation
- NSTextView pagination APIs
- UITextView layout manager

## Notes
[To be filled in: Additional context or considerations]
