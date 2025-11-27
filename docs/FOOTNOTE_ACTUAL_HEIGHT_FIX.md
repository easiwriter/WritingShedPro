# Footnote Height: Use Actual Height Instead of Fixed Reserve

## Issue

After fixing the missing parameters bug, the iterative convergence algorithm was running correctly, but **too much text was moving to page 2**.

**Console output revealed the problem:**
```
📏 Footnote height for page 0: 130.0pt      ← Actual footnote height
📐 Final: Page 0 has 1 footnotes, reserved 250.0pt  ← Fixed reserve amount
```

**The issue:**
- Actual footnote: **130pt**
- Reserved space: **250pt**
- **Wasted space: 120pt** (48% over-reservation!)

This caused the layout algorithm to reserve almost twice as much space as needed, pushing text unnecessarily to the next page.

## Root Cause

The iterative convergence algorithm was using a **fixed `maxFootnoteReserve = 250`** constant for all footnotes, regardless of their actual rendered height.

```swift
// ❌ BEFORE - Fixed reserve amount
let maxFootnoteReserve: CGFloat = 250

if hadFootnotesInPrevious {
    pageContainerSize = CGSize(
        width: containerSize.width,
        height: containerSize.height - maxFootnoteReserve  // Always 250pt!
    )
}
```

This fixed amount was:
- Too large for small footnotes (wasting space)
- Potentially too small for large footnotes (would cause overflow)
- Not accurate for the layout calculation

## Solution: Calculate Actual Footnote Height

Use the existing `calculateFootnoteHeight(for:pageWidth:)` method during iteration to determine the **exact** space needed for each page's footnotes.

### Changes Made

**1. During Iteration (lines ~240-280):**
```swift
// ✅ AFTER - Calculate actual height
let footnotesOnPreviousPage: [FootnoteModel]
if iteration == 1 || pageIndex >= currentPageInfos.count {
    footnotesOnPreviousPage = []
} else {
    let previousPageRange = currentPageInfos[pageIndex].characterRange
    footnotesOnPreviousPage = allFootnotes.filter { footnote in
        NSLocationInRange(footnote.characterPosition, previousPageRange)
    }
}

// Calculate actual footnote height for this page
let footnoteHeight: CGFloat
if !footnotesOnPreviousPage.isEmpty {
    footnoteHeight = calculateFootnoteHeight(
        for: footnotesOnPreviousPage,
        pageWidth: containerSize.width
    )
} else {
    footnoteHeight = 0
}

// Use actual height
let pageContainerSize: CGSize
if footnoteHeight > 0 {
    pageContainerSize = CGSize(
        width: containerSize.width,
        height: containerSize.height - footnoteHeight  // Exact amount!
    )
}
```

**2. Final Container Creation (lines ~330-365):**
```swift
// ✅ AFTER - Calculate actual height for final containers
let footnotesOnPage = allFootnotes.filter { footnote in
    NSLocationInRange(footnote.characterPosition, pageInfo.characterRange)
}

let footnoteHeight: CGFloat
if !footnotesOnPage.isEmpty {
    footnoteHeight = calculateFootnoteHeight(
        for: footnotesOnPage,
        pageWidth: containerSize.width
    )
} else {
    footnoteHeight = 0
}

let pageContainerSize: CGSize
if footnoteHeight > 0 {
    pageContainerSize = CGSize(
        width: containerSize.width,
        height: containerSize.height - footnoteHeight
    )
}
```

### Key Improvements

1. **Accurate Space Reservation:** Each page reserves exactly the space its footnotes need
2. **No Wasted Space:** Pages with small footnotes don't over-reserve
3. **Proper Overflow Handling:** Large footnotes get the space they need (up to container height)
4. **Dynamic Calculation:** Works correctly regardless of:
   - Number of footnotes per page
   - Font size
   - Line spacing
   - Footnote content length

## Expected Console Output

```
🔧 Using FOOTNOTE-AWARE layout with version: 8EAC474D
🔄 Footnote layout iteration 1
   📏 Page 0: 1 footnotes need 130.0pt           ← Actual height calculated
🔄 Footnote layout iteration 2
   📏 Page 0: 1 footnotes need 130.0pt
🔄 Footnote layout iteration 3
   📏 Page 0: 1 footnotes need 130.0pt
✅ Footnote layout converged after 3 iterations
📐 Final: Page 0 has 1 footnotes, reserved 130.0pt  ← Matches actual height!
📐 Final: Page 1 has no footnotes, full height
   ✅ Layout calculated: 2 pages
```

**Key difference:** Reserved space (130pt) now matches actual footnote height (130pt) ✅

## Testing

**Test Case 1: Small Footnote (~130pt)**
- Before: Reserved 250pt, wasted 120pt
- After: Reserved 130pt, perfect fit
- Expected: More text on page 1, less on page 2

**Test Case 2: Large Footnote (~200pt)**
- Before: Reserved 250pt, wasted 50pt
- After: Reserved 200pt, perfect fit
- Expected: Slightly more text on page 1

**Test Case 3: Multiple Footnotes**
- Before: Reserved 250pt total (not per footnote)
- After: Calculates sum of all footnote heights
- Expected: Accurate space for all footnotes

**Test Case 4: Very Long Footnote (> page height)**
- Before: Reserved 250pt, footnote overflows
- After: Reserved actual height, may still overflow
- Note: Overflow handling is Task 6 (future work)

## Visual Improvement

**Before (fixed 250pt):**
```
┌─────────────────┐
│ Lorem ipsum...  │  ← Less text on page 1
│ Paragraph 1     │     (250pt reserved)
│ Paragraph 2     │
│                 │  ← 120pt wasted space
│─────────────────│
│ 1. Footnote     │  ← Only needs 130pt
└─────────────────┘

┌─────────────────┐
│ Paragraph 3     │  ← More text on page 2
│ ...rest...      │     (pushed unnecessarily)
└─────────────────┘
```

**After (actual 130pt):**
```
┌─────────────────┐
│ Lorem ipsum...  │  ← More text on page 1
│ Paragraph 1     │     (130pt reserved)
│ Paragraph 2     │
│ + more text     │  ← No wasted space
│─────────────────│
│ 1. Footnote     │  ← Exactly 130pt
└─────────────────┘

┌─────────────────┐
│ Paragraph 3     │  ← Less text on page 2
│ (rest)          │     (optimal page break)
└─────────────────┘
```

## Performance Impact

**Minimal:** The `calculateFootnoteHeight()` method is already called for rendering, now also called during layout iteration. Since we typically converge in 2-3 iterations, this adds only 2-3 extra height calculations per page with footnotes.

## Files Modified

- **PaginatedTextLayoutManager.swift**
  - `calculateFootnoteAwareLayout()`: Use actual footnote height during iteration
  - `calculateFootnoteAwareLayout()`: Use actual footnote height for final containers
  - Removed `maxFootnoteReserve` constant
  - Added debug logging for footnote heights per iteration

## Related Issues

- **Fixes:** Over-reservation of footnote space (120pt wasted)
- **Depends on:** FOOTNOTE_MISSING_PARAMETERS_FIX.md (parameters bug)
- **Builds on:** FOOTNOTE_ITERATIVE_CONVERGENCE.md (convergence algorithm)
- **Pending:** Task 6 - Footnote overflow handling (footnotes > page height)

## Date

2025-11-25
