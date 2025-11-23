# Feature 015: Footnotes - Phase 6 Implementation Plan

**Status:** Ready to implement  
**Date:** 23 November 2025  
**Prerequisites:** ✅ All unit tests passing, pagination system complete

## Overview

Integrate footnotes into the paginated document view so that footnotes appear at the bottom of pages (footnote mode) or at the document end (endnote mode).

## Current Status

### ✅ Already Complete
- FootnoteModel with SwiftData and CloudKit sync
- FootnoteManager with all CRUD operations
- FootnoteAttachment rendering superscript markers
- FootnoteInsertionHelper for document insertion
- FootnoteDetailView for editing
- FootnotesListView for management
- Auto-renumbering logic working
- All 100+ unit tests passing

### 🎯 Phase 6: Pagination Integration (THIS PHASE)

Goal: Display footnotes in paginated view according to professional typesetting standards.

## Implementation Tasks

### Task 1: Extend PaginatedTextLayoutManager (3-4 hours)

**File:** `Utilities/PaginatedTextLayoutManager.swift`

#### 1.1 Add Footnote Detection
```swift
/// Get all footnotes for a specific page
func getFootnotesForPage(_ pageNumber: Int, version: Version, context: ModelContext) -> [FootnoteModel] {
    // Get text range for this page
    let textRange = getTextRange(forPage: pageNumber)
    
    // Get all active footnotes for version
    let allFootnotes = FootnoteManager.shared.getActiveFootnotes(forVersion: version, context: context)
    
    // Filter to footnotes within this page's text range
    return allFootnotes.filter { footnote in
        textRange.contains(footnote.characterPosition)
    }
}
```

#### 1.2 Calculate Footnote Area Height
```swift
/// Calculate height needed for footnotes on a page
func calculateFootnoteHeight(for footnotes: [FootnoteModel], pageWidth: CGFloat) -> CGFloat {
    guard !footnotes.isEmpty else { return 0 }
    
    // Separator: 1.5-inch line + 10pt spacing = ~60pt
    let separatorHeight: CGFloat = 60
    
    // Each footnote: number + text (estimate ~20pt per line)
    let footnoteTextHeight = footnotes.reduce(0) { total, footnote in
        total + estimateTextHeight(footnote.text, width: pageWidth)
    }
    
    return separatorHeight + footnoteTextHeight
}
```

#### 1.3 Adjust Content Area
```swift
/// Get content area for page, accounting for footnotes
func getContentArea(forPage pageNumber: Int, version: Version, context: ModelContext) -> CGRect {
    let baseContentArea = pageLayoutCalculator.contentArea
    
    // Get footnotes for this page
    let footnotes = getFootnotesForPage(pageNumber, version: version, context: context)
    
    if footnotes.isEmpty {
        return baseContentArea
    }
    
    // Reduce content area height to make room for footnotes
    let footnoteHeight = calculateFootnoteHeight(for: footnotes, pageWidth: baseContentArea.width)
    
    return CGRect(
        x: baseContentArea.origin.x,
        y: baseContentArea.origin.y,
        width: baseContentArea.width,
        height: baseContentArea.height - footnoteHeight
    )
}
```

### Task 2: Create FootnoteRenderer (2-3 hours)

**New File:** `Views/Footnotes/FootnoteRenderer.swift`

```swift
import SwiftUI

/// Renders footnotes at bottom of paginated page
struct FootnoteRenderer: View {
    let footnotes: [FootnoteModel]
    let pageWidth: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Separator line (1.5 inches = ~108pt)
            Rectangle()
                .frame(width: 108, height: 1)
                .foregroundStyle(.secondary)
                .padding(.bottom, 10)
            
            // Footnote entries
            ForEach(footnotes) { footnote in
                HStack(alignment: .top, spacing: 8) {
                    // Superscript number
                    Text("\(footnote.number)")
                        .font(.system(size: 10))
                        .baselineOffset(4)
                    
                    // Footnote text
                    Text(footnote.text)
                        .font(.system(size: 10))
                        .lineSpacing(1.2)
                }
            }
        }
        .frame(width: pageWidth, alignment: .leading)
    }
}
```

### Task 3: Update VirtualPageScrollView (2-3 hours)

**File:** `Views/VirtualPageScrollView.swift`

#### 3.1 Add Footnote Support to Page View
```swift
class PageContentView: UIView {
    // ... existing properties ...
    private var footnoteView: UIHostingController<FootnoteRenderer>?
    
    func configure(
        pageNumber: Int,
        attributedText: NSAttributedString,
        pageSize: CGSize,
        footnotes: [FootnoteModel]  // NEW PARAMETER
    ) {
        // ... existing text rendering ...
        
        // Add footnote rendering if footnotes exist
        if !footnotes.isEmpty {
            renderFootnotes(footnotes, pageSize: pageSize)
        }
    }
    
    private func renderFootnotes(_ footnotes: [FootnoteModel], pageSize: CGSize) {
        // Remove existing footnote view
        footnoteView?.view.removeFromSuperview()
        
        // Create new footnote renderer
        let renderer = FootnoteRenderer(
            footnotes: footnotes,
            pageWidth: pageSize.width - 72  // Account for margins
        )
        
        let hosting = UIHostingController(rootView: renderer)
        footnoteView = hosting
        
        // Position at bottom of page
        let footnoteHeight = hosting.view.intrinsicContentSize.height
        hosting.view.frame = CGRect(
            x: 36,  // Left margin
            y: pageSize.height - footnoteHeight - 36,  // Bottom margin
            width: pageSize.width - 72,
            height: footnoteHeight
        )
        
        addSubview(hosting.view)
    }
}
```

#### 3.2 Pass Footnotes to Page Views
```swift
// In page view creation/recycling
private func configurePageView(_ pageView: PageContentView, forPage pageNumber: Int) {
    // ... existing code ...
    
    // Get footnotes for this page
    let footnotes = layoutManager.getFootnotesForPage(
        pageNumber,
        version: version,
        context: modelContext
    )
    
    pageView.configure(
        pageNumber: pageNumber,
        attributedText: textForPage,
        pageSize: pageSize,
        footnotes: footnotes  // NEW
    )
}
```

### Task 4: Add Endnote Mode Support (1-2 hours)

**File:** `Views/PaginatedDocumentView.swift`

```swift
struct PaginatedDocumentView: View {
    // ... existing properties ...
    @AppStorage("footnoteDisplayMode") private var footnoteMode: FootnoteDisplayMode = .pageBottom
    
    var body: some View {
        VStack(spacing: 0) {
            // ... existing pagination view ...
            
            // If endnote mode, show all footnotes at end
            if footnoteMode == .documentEnd {
                endnotesSection
            }
        }
    }
    
    private var endnotesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Endnotes")
                .font(.title2)
                .bold()
                .padding(.top, 32)
            
            FootnoteRenderer(
                footnotes: allFootnotes,
                pageWidth: UIScreen.main.bounds.width - 72
            )
        }
        .padding()
    }
    
    private var allFootnotes: [FootnoteModel] {
        guard let version = file.currentVersion else { return [] }
        return FootnoteManager.shared.getActiveFootnotes(
            forVersion: version,
            context: modelContext
        )
    }
}
```

### Task 5: Add Display Mode Toggle (1 hour)

**File:** `Views/FileEditView.swift`

```swift
// Add to toolbar
ToolbarItem(placement: .secondaryAction) {
    Menu {
        Picker("Footnote Display", selection: $footnoteMode) {
            Label("Bottom of Page", systemImage: "doc.text").tag(FootnoteDisplayMode.pageBottom)
            Label("End of Document", systemImage: "doc.append").tag(FootnoteDisplayMode.documentEnd)
        }
    } label: {
        Image(systemName: "number.circle")
    }
}
```

### Task 6: Handle Edge Cases (2-3 hours)

#### 6.1 Footnote Overflow
When footnotes don't fit on page:
- Ensure minimum 2 lines of body text
- Split long footnotes with continuation indicator
- Flow remainder to next page

```swift
func distributeFootnotes(
    _ footnotes: [FootnoteModel],
    availableHeight: CGFloat
) -> (currentPage: [FootnoteModel], overflow: [FootnoteModel]) {
    var currentPage: [FootnoteModel] = []
    var overflow: [FootnoteModel] = []
    var usedHeight: CGFloat = 60  // Separator
    
    for footnote in footnotes {
        let footnoteHeight = estimateTextHeight(footnote.text, width: pageWidth)
        
        if usedHeight + footnoteHeight <= availableHeight {
            currentPage.append(footnote)
            usedHeight += footnoteHeight
        } else {
            overflow.append(footnote)
        }
    }
    
    return (currentPage, overflow)
}
```

#### 6.2 Empty Pages
- Display "No footnotes on this page" placeholder
- Or simply hide footnote section

#### 6.3 Page Breaks
- Ensure footnote sections don't create orphan pages
- Maintain proper spacing

## Testing Plan

### Unit Tests (1-2 hours)

**File:** `WritingShedProTests/FootnoteRenderingTests.swift`

```swift
func testFootnoteDetectionForPage() {
    // Create document with footnotes across multiple pages
    // Verify correct footnotes returned for each page
}

func testFootnoteHeightCalculation() {
    // Test height calculation with varying footnote counts
    // Verify separator and text heights
}

func testFootnoteOverflowHandling() {
    // Test when footnotes exceed available space
    // Verify split and continuation
}

func testEndnoteMode() {
    // Verify all footnotes appear at document end
    // Verify proper formatting
}
```

### Manual Testing (1 hour)

1. **Basic Display**
   - [ ] Footnotes appear at bottom of correct pages
   - [ ] Separator line renders correctly
   - [ ] Footnote numbers match markers in text

2. **Multiple Footnotes**
   - [ ] Multiple footnotes stack vertically
   - [ ] Proper spacing between footnotes
   - [ ] All footnotes visible

3. **Page Overflow**
   - [ ] Long footnotes handle gracefully
   - [ ] Minimum body text maintained
   - [ ] Continuation indicators work

4. **Endnote Mode**
   - [ ] Toggle switches modes
   - [ ] All footnotes at document end
   - [ ] Proper "Endnotes" heading

5. **Edge Cases**
   - [ ] Pages without footnotes
   - [ ] Single very long footnote
   - [ ] Many short footnotes
   - [ ] Empty document

## Documentation Updates

### User Guide (30 minutes)
Update `specs/010-pagination/USER_GUIDE.md`:
- Add section on footnote display
- Explain footnote vs endnote mode
- Document toggle location

### Technical Docs (30 minutes)
Create `specs/015-footnotes/PAGINATION_INTEGRATION.md`:
- Architecture overview
- Implementation details
- Edge case handling
- Performance considerations

## Success Criteria

- [ ] Footnotes display at bottom of paginated pages
- [ ] Separator line matches typography standards (1.5 inch line)
- [ ] Footnote text is properly formatted (10pt font)
- [ ] Endnote mode displays all footnotes at document end
- [ ] Toggle between modes works smoothly
- [ ] No performance degradation with many footnotes
- [ ] All edge cases handled gracefully
- [ ] Unit tests pass
- [ ] Manual testing complete
- [ ] Documentation updated

## Time Estimate

| Task | Estimated Time |
|------|----------------|
| 1. Extend PaginatedTextLayoutManager | 3-4 hours |
| 2. Create FootnoteRenderer | 2-3 hours |
| 3. Update VirtualPageScrollView | 2-3 hours |
| 4. Add Endnote Mode Support | 1-2 hours |
| 5. Add Display Mode Toggle | 1 hour |
| 6. Handle Edge Cases | 2-3 hours |
| Testing | 2-3 hours |
| Documentation | 1 hour |
| **Total** | **14-20 hours** |

## Dependencies

- ✅ Feature 010: Pagination (complete)
- ✅ Feature 015: Footnotes Phases 1-5 (complete)
- ✅ All unit tests passing

## Next Steps After Completion

1. Export support (include footnotes in PDF/RTF)
2. Advanced pagination features (headers/footers)
3. Feature 016: Advanced numbering formats
4. Print preview integration

---

**Ready to Begin:** ✅  
**Blocking Issues:** None
