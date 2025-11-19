# Feature 010: Paginated Document View - Data Model

## Overview
The pagination feature uses existing PageSetup models as the source of truth for page dimensions and formatting. New models track the pagination view state and manage virtual page rendering.

## Existing Models (Used by Pagination)

### PageSetup (Already Exists)
Located in: `Models/PageSetupModels.swift`

```swift
@Model
final class PageSetup {
    var paperName: String?           // Letter, Legal, A4, A5, Custom
    var orientation: Int16           // 0 = portrait, 1 = landscape
    var headers: Int16               // 0 = false, 1 = true
    var footers: Int16               // 0 = false, 1 = true
    var facingPages: Int16           // 0 = false, 1 = true
    
    // Margins (in points - 72 points = 1 inch)
    var marginTop: Double
    var marginBottom: Double
    var marginLeft: Double
    var marginRight: Double
    
    // Header/Footer depths (in points)
    var headerDepth: Double
    var footerDepth: Double
    
    var scaleFactor: Double          // For unit conversion
    
    // Relationship
    @Relationship(inverse: \Project.pageSetup)
    var project: Project?
}
```

**Usage in Pagination:**
- Source of truth for all page dimensions
- Used by `PageLayoutCalculator` to compute page rects, text areas, content areas
- Each Project has one PageSetup that applies to all files in that project
- Modified via `PageSetupForm` in ProjectItemView

### PaperSizes (Already Exists)
Located in: `Models/PageSetupTypes.swift`

```swift
enum PaperSizes: String, Codable, CaseIterable {
    case Letter  // 8.5" x 11" = 612 x 792 points
    case Legal   // 8.5" x 14" = 612 x 1008 points
    case A4      // 210mm x 297mm = 595 x 842 points
    case A5      // 148mm x 210mm = 420 x 595 points
    case Custom
    
    var dimensions: (width: Double, height: Double)
}
```

### Orientation (Already Exists)
```swift
enum Orientation: Int16, Codable, CaseIterable {
    case portrait = 0
    case landscape = 1
}
```

## New Models (For Pagination)

### ViewMode Enum
**Purpose:** Track whether user is in edit mode or pagination preview mode

```swift
enum ViewMode: String, Codable {
    case edit       // Normal editing mode (continuous text view)
    case paginated  // Paginated preview mode (page-by-page view)
}
```

**Storage:** 
- Stored in `@AppStorage` or `@State` per file
- Not persisted to database (UI state only)
- Default: `.edit`
- Toggled via toolbar button

**Behavior:**
- `.edit`: Show standard FileEditView with continuous text
- `.paginated`: Show PaginatedDocumentView with virtual page scrolling

### PaginationState (ObservableObject)
**Purpose:** Manage pagination view state, page tracking, and rendering

```swift
@Observable
class PaginationState {
    // View State
    var viewMode: ViewMode = .edit
    var currentPage: Int = 0           // Currently visible page (0-indexed)
    var totalPages: Int = 1            // Total page count
    var zoomScale: CGFloat = 1.0       // Zoom level (0.5 to 2.0)
    
    // Scroll State
    var scrollOffset: CGFloat = 0      // Current scroll Y position
    var visiblePageRange: Range<Int> = 0..<3  // Pages currently visible
    
    // Layout Cache
    var pageLayout: PageLayoutCalculator.PageLayout?
    var textHeight: CGFloat = 0        // Total laid-out text height
    var layoutValid: Bool = false      // Whether layout needs recalculation
    
    // Configuration
    let pageSpacing: CGFloat = 20      // Space between pages in points
    let bufferPages: Int = 2           // Pages to render above/below visible
    
    // Methods
    func invalidateLayout() {
        layoutValid = false
    }
    
    func updateVisibleRange(scrollY: CGFloat, viewportHeight: CGFloat, pageSetup: PageSetup) {
        // Calculate which pages are visible based on scroll position
    }
    
    func pageNumber(at yPosition: CGFloat, pageSetup: PageSetup) -> Int {
        // Convert Y coordinate to page number
    }
}
```

**Storage:** 
- Created per FileEditView instance
- Lives in SwiftUI view hierarchy
- Recreated on view dismissal

**Lifecycle:**
1. Created when FileEditView appears
2. Updated as user scrolls or edits
3. Invalidated when text changes
4. Disposed when view disappears

### PageLayoutCalculator.PageLayout (Struct)
**Purpose:** Result of page layout calculation

```swift
struct PageLayout {
    let pageRect: CGRect       // Full page bounds
    let textRect: CGRect       // Page minus margins
    let contentRect: CGRect    // Text area minus header/footer
    let headerRect: CGRect?    // Header area (if enabled)
    let footerRect: CGRect?    // Footer area (if enabled)
    let paperSize: PaperSizes
    let orientation: Orientation
}
```

**Usage:**
- Computed from PageSetup via `PageLayoutCalculator.calculateLayout()`
- Cached in `PaginationState.pageLayout`
- Invalidated when PageSetup changes
- Used to position text containers and calculate page count

## Text Layout Models (TextKit 1)

### NSLayoutManager
**Purpose:** Manages text layout across multiple containers

```swift
// Created per document
let layoutManager = NSLayoutManager()
layoutManager.textStorage = textStorage  // Shared with edit view
layoutManager.allowsNonContiguousLayout = true  // For performance
```

**Key Properties:**
- `numberOfGlyphs`: Total glyphs in document
- `glyphRange(forBoundingRect:in:)`: Calculate which glyphs fit in a rect
- `usedRect(for:)`: Calculate actual text bounds in container

### NSTextContainer
**Purpose:** Represents the text area of one page

```swift
// Created per visible page
let container = NSTextContainer(size: pageLayout.contentRect.size)
container.widthTracksTextView = false
container.heightTracksTextView = false
container.lineFragmentPadding = 0  // No extra padding
```

**Per-Page Container:**
- One container per visible page (not all pages)
- Dynamically created/destroyed as user scrolls
- Recycled when possible
- Size from `PageLayout.contentRect`

### NSTextStorage
**Purpose:** Holds the attributed text (shared with edit view)

```swift
// Shared between edit mode and pagination mode
let textStorage = NSTextStorage(attributedString: fileContent)
```

**Key Point:** Same NSTextStorage used in both modes for consistency

## Virtual Scrolling Models

### VirtualPageView (Recyclable)
**Purpose:** Represents a single rendered page

```swift
struct VirtualPageView: Identifiable {
    let id: UUID = UUID()
    let pageIndex: Int               // Which page (0-indexed)
    let frame: CGRect                // Position in scroll view
    let textRange: NSRange           // Text range for this page
    var textView: UITextView?        // The actual text view (lazy)
}
```

**Lifecycle:**
1. Created when page enters visible range + buffer
2. UITextView created on-demand
3. Positioned in scroll view
4. Recycled or destroyed when page exits range + buffer

### PageViewCache (Performance)
**Purpose:** Reuse UITextView instances instead of recreating

```swift
class PageViewCache {
    private var availableViews: [UITextView] = []
    private let maxCacheSize: Int = 10
    
    func dequeueReusableView() -> UITextView? {
        return availableViews.popLast()
    }
    
    func enqueueView(_ view: UITextView) {
        guard availableViews.count < maxCacheSize else { return }
        view.text = ""  // Clear content
        availableViews.append(view)
    }
}
```

## View State Persistence

### Per-Session State (Not Persisted)
Stored in SwiftUI `@State` or `@AppStorage`:
- `viewMode`: Edit vs Paginated
- `zoomScale`: Current zoom level
- `currentPage`: Last viewed page

### Per-File Preferences (Optional Future Enhancement)
Could be added to TextFile model:
```swift
@Model
final class TextFile {
    // Existing properties...
    
    // Optional pagination preferences
    var preferredViewMode: String?    // "edit" or "paginated"
    var lastViewedPage: Int?          // Resume where user left off
}
```

## Data Flow

### Edit Mode → Paginated Mode Transition
1. User taps pagination toggle button
2. `ViewMode` changes from `.edit` to `.paginated`
3. SwiftUI shows `PaginatedDocumentView` instead of standard editor
4. `PageLayoutCalculator` computes layout from `Project.pageSetup`
5. `PaginationState` calculates total page count
6. Virtual scroll view renders visible pages

### Text Changes in Edit Mode
1. User edits text in edit mode
2. Changes saved to `Version.content`
3. If switching to paginated mode:
   - `PaginationState.invalidateLayout()` called
   - Page count recalculated
   - Layout updated

### PageSetup Changes
1. User modifies PageSetup via `PageSetupForm`
2. Changes saved to `Project.pageSetup`
3. If pagination view is active:
   - `PaginationState.pageLayout` invalidated
   - Layout recalculated with new dimensions
   - Virtual scroll view updates page sizes

### Scroll State Management
```
User scrolls → UIScrollViewDelegate.scrollViewDidScroll
           → PaginationState.updateVisibleRange()
           → Calculate new visible page range
           → Remove off-screen page views
           → Create new on-screen page views
           → Update currentPage indicator
```

## Memory Management Strategy

### For Small Documents (<10 pages)
- Render all pages
- No virtual scrolling needed
- Simple page stack in ScrollView

### For Large Documents (10-200+ pages)
- Virtual scrolling essential
- Only render visible pages + 2-page buffer
- Typical memory: 5-7 page views × ~1MB each = 5-7MB
- Aggressive cleanup of off-screen views

### Page View Lifecycle
```
Page enters buffer range (visible + 2 pages)
    → Create VirtualPageView
    → Create UITextView if needed (or reuse from cache)
    → Configure text container
    → Position in scroll view
    → Add to hierarchy

Page exits buffer range
    → Remove from hierarchy
    → Return UITextView to cache (if cache not full)
    → Destroy VirtualPageView
```

## Relationship to Existing Models

### Project
- Has one `PageSetup`
- PageSetup applies to all files in project
- Changing PageSetup affects all paginated views

### TextFile
- Content displayed in pagination view
- Uses parent Project's PageSetup
- No direct pagination settings on file

### Version
- `content` property is the text to paginate
- Same NSTextStorage used in edit and paginated modes
- Version changes invalidate pagination layout

### StyleSheet / TextStyleModel
- Text formatting preserved in pagination view
- Fonts, colors, alignment all rendered
- No special handling needed (TextKit handles it)

## Testing Considerations

### Unit Tests
- `PageLayoutCalculator` tests (already created ✅)
- `PaginationState` state management tests
- Virtual scrolling range calculations
- Page view recycling logic

### Integration Tests
- Mode switching (edit ↔ paginated)
- Text editing in edit mode → correct pagination
- PageSetup changes → layout updates
- Large document handling (performance)

### Manual Testing
- Visual inspection of page layout
- Margin/header/footer positioning
- Different paper sizes and orientations
- Zoom behavior
- Smooth scrolling

## Future Enhancements (Out of Scope for Phase 1)

### Page Numbers
Add to PageSetup or PaginationState:
```swift
var showPageNumbers: Bool
var pageNumberPosition: PageNumberPosition  // top/bottom, left/center/right
var pageNumberFormat: String  // "Page {n}" or "{n}" or "Page {n} of {total}"
```

### Facing Pages Mode
```swift
var displayMode: DisplayMode
enum DisplayMode {
    case singlePage
    case facingPages    // Show 2 pages side-by-side
    case continuous     // Continuous scroll
}
```

### Explicit Page Breaks
Add paragraph style attribute:
```swift
let pageBreakStyle = NSParagraphStyle()
pageBreakStyle.pageBreakBefore = true
```

### Widow/Orphan Control
Prevent single lines at top/bottom of pages (advanced TextKit feature)
