# Feature 010 Pagination - Decisions Summary

**Date:** November 19, 2025  
**Status:** Specification Complete, Ready for Implementation

## Quick Reference

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Architecture** | Virtual scrolling | Memory efficiency for 200+ page novels |
| **View Mode** | Always start in edit mode | Simple, predictable |
| **Editing** | Read-only in paginated mode | Print preview, not editing mode |
| **Page Numbers** | In headers/footers (future) | Part of separate header/footer feature |
| **Performance** | Visible pages + 2-page buffer | Balance memory vs smoothness |
| **PageSetup** | Per-project (existing) | Already implemented in Project Details |
| **Headers/Footers** | Reserve space only | Content is separate feature |
| **Export Integration** | Yes - true print preview | WYSIWYG for export/print |
| **Transition** | Progress if >0.5s | Most documents instant |
| **Zoom Range** | 25% to 200% | Platform-specific defaults |

## Implementation Strategy

### Phase 1: Core Layout Calculator (2-3 days)
- Implement `PageLayoutCalculator` class
- Use NSLayoutManager to calculate total page count
- Calculate text range for each page
- Integrate with existing PageSetup model

**Key Files:**
- `Models/PageSetupModels.swift` (existing - use this)
- `Views/Pagination/PageLayoutCalculator.swift` (new)

### Phase 2: Virtual Scrolling Engine (3-4 days)
- Implement `VirtualPageScrollView` class
- Track visible page range as user scrolls
- Create/destroy page views dynamically
- Implement 2-page buffer above/below viewport

**Key Files:**
- `Views/Pagination/VirtualPageScrollView.swift` (new)
- `Views/Pagination/PageView.swift` (new)

### Phase 3: SwiftUI Integration (2-3 days)
- Create `PaginatedDocumentView` wrapper
- Add toolbar toggle button
- Show "Preview Mode" indicator
- Integrate with FileEditView

**Key Files:**
- `Views/Pagination/PaginatedDocumentView.swift` (new)
- `Views/Files/FileEditView.swift` (modify - add toggle)

### Phase 4: Zoom & Gestures (2 days)
- Implement pinch gesture support
- Add toolbar zoom controls
- Handle platform-specific defaults
- Maintain scroll position during zoom

**Key Files:**
- `Views/Pagination/ZoomControls.swift` (new)

### Phase 5: Page Separators (1 day)
- Draw dotted lines between pages
- Match Apple Pages style
- Handle zoom scaling

**Key Files:**
- `Views/Pagination/PageSeparatorView.swift` (new)

### Phase 6: Testing & Polish (2-3 days)
- Unit tests for page calculations
- Manual testing across platforms
- Performance optimization
- Dark mode support

**Total Estimate:** 12-16 days

## Critical Technical Details

### PageSetup Integration
```swift
// Access PageSetup from TextFile
let pageSetup = file.folder?.project?.pageSetup

// PageSetup provides:
- paperSize: PaperSizes (.Letter, .Legal, .A4, .A5)
- orientation: Orientation (.portrait, .landscape)
- marginTop/Bottom/Left/Right: Double (points)
- headerDepth, footerDepth: Double (points)
- hasHeaders, hasFooters: Bool
```

### Virtual Scrolling Pattern
```swift
// Only render visible pages + buffer
let visibleRect = scrollView.bounds
let firstVisiblePage = pageIndexAt(visibleRect.origin)
let lastVisiblePage = pageIndexAt(visibleRect.maxY)
let bufferPages = 2

let renderRange = max(0, firstVisiblePage - bufferPages)
                  ..<min(totalPages, lastVisiblePage + bufferPages + 1)

// Create views for pages in range
// Remove views for pages outside range
```

### Page Calculation Algorithm
```swift
func calculateTotalPages() -> Int {
    // Use NSLayoutManager to calculate layout
    layoutManager.glyphRange(for: textStorage)
    
    // Calculate how many containers needed
    let containerSize = calculateTextRect(from: pageSetup).size
    
    // Walk through glyphs, counting containers
    var pageCount = 0
    var glyphIndex = 0
    
    while glyphIndex < layoutManager.numberOfGlyphs {
        let container = NSTextContainer(size: containerSize)
        // Calculate glyphs that fit in this page...
        pageCount += 1
    }
    
    return max(pageCount, 1)
}
```

### Zoom Implementation
```swift
// Platform-specific defaults
#if targetEnvironment(macCatalyst)
    defaultZoom = 1.0  // 100%
#elseif os(iOS)
    if UIDevice.current.userInterfaceIdiom == .phone {
        defaultZoom = .fitWidth
    } else {
        defaultZoom = 1.0  // iPad
    }
#endif

// Range: 0.25 (25%) to 2.0 (200%)
```

## Testing Requirements

### Must Test
- [ ] 1-page document
- [ ] 10-page document
- [ ] 50-page document
- [ ] 100-page document
- [ ] 200+ page document (performance critical)
- [ ] Document with images
- [ ] Switch between Portrait/Landscape
- [ ] Different paper sizes (Letter, A4, Legal)
- [ ] Zoom in/out maintains position
- [ ] iPhone, iPad, Mac Catalyst
- [ ] Dark mode

### Performance Targets
- [ ] Switching to paginated mode: <0.5s for 50 pages
- [ ] Scrolling: 60fps
- [ ] Memory: <100MB increase for 200 pages
- [ ] Zoom: Smooth, no jank

## Open Questions (None - All Resolved)

All 9 original questions have been answered. Ready to proceed with implementation.

## Next Steps

1. ✅ Spec complete
2. ⏭️ Create `specs/010-pagination/tasks.md` breakdown
3. ⏭️ Implement Phase 1 (Page Layout Calculator)
4. ⏭️ Test Phase 1 thoroughly before Phase 2
5. ⏭️ Iterate through phases with testing after each

## References

- **PageSetup Model:** `WrtingShedPro/Writing Shed Pro/Models/PageSetupModels.swift`
- **PageSetup Types:** `WrtingShedPro/Writing Shed Pro/Models/PageSetupTypes.swift`
- **PageSetup Form:** `WrtingShedPro/Writing Shed Pro/Views/Forms/PageSetupForm.swift`
- **TextFile Model:** `WrtingShedPro/Writing Shed Pro/Models/BaseModels.swift`
- **FileEditView:** `WrtingShedPro/Writing Shed Pro/Views/Files/FileEditView.swift`

## Notes

- This is a **read-only preview** feature, not an editing mode
- Virtual scrolling is critical - don't try to render all pages at once
- PageSetup already exists and is configured per-project
- Header/footer content is a separate future feature
- Page numbers will appear when header/footer feature is implemented
- This pagination view should match export output exactly
