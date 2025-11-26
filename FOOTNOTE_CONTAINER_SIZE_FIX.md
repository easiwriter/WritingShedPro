# Critical Fix: Text Container Size Must Match Layout Calculation

## Issue Discovered

**User report:** "The 1st line of the 3rd paragraph should be on the second page, not half hidden by the footnote"

**Screenshot analysis:** Text was visibly overlapping the footnote area - the beginning of paragraph 3 appeared above the footnote separator line but was cut off.

## Root Cause

The system had a critical **mismatch** between layout calculation and rendering:

### Layout Calculation (PaginatedTextLayoutManager)
```swift
// Calculates page breaks with reduced container
let pageContainerSize = CGSize(
    width: 468,
    height: 518  // 648 - 130 = 518pt for page with footnote
)
```

**Result:** Layout manager determines text should stop after ~518pt worth of content

### Rendering (VirtualPageScrollView - BEFORE FIX)
```swift
// ❌ WRONG: Only adjusted insets, not container size
textView.textContainerInset = UIEdgeInsets(
    top: 72,
    left: 72,
    bottom: 202,  // 72 + 130
    right: 72
)
// Container size still default (full size)
// textView.textContainer.size = NOT SET!
```

**Result:** UITextView's text container was still **full height (648pt)**, so it laid out more text than the 518pt that the layout manager calculated!

## The Disconnect

1. **PaginatedTextLayoutManager** creates NSTextContainers with size 518pt during calculation
2. **VirtualPageScrollView** creates NEW UITextView with default full-size container (648pt)
3. Insets are adjusted, but **container size is not**
4. UITextView lays out ~648pt worth of text (full container)
5. Layout manager said "stop at 518pt" but view shows "648pt worth of text"
6. **Text overflows into footnote area** ❌

## The Fix

**Set the text container size to match the calculated size:**

```swift
// ✅ CORRECT: Set container size from layout calculation
let pageIndex = pageInfo.pageIndex
if pageIndex < layoutManager.layoutManager.textContainers.count {
    let calculatedContainer = layoutManager.layoutManager.textContainers[pageIndex]
    let calculatedSize = calculatedContainer.size  // 518pt for page with footnote!
    
    // Match the calculated size
    textView.textContainer.size = calculatedSize
    textView.textContainer.lineFragmentPadding = 0
}

// Then set insets for positioning
textView.textContainerInset = UIEdgeInsets(
    top: topInset,
    left: leftInset,
    bottom: adjustedBottomInset,  // Still needed for visual spacing
    right: rightInset
)
```

## Why Both Are Needed

### Container Size
- **Purpose:** Limit how much text fits
- **Effect:** Text stops after 518pt worth of content
- **Matches:** Layout calculation (518pt container)

### Container Insets
- **Purpose:** Position the text within the frame
- **Effect:** Adds padding/margins around the container
- **Needed for:** Visual spacing and footnote positioning

## Mathematical Proof

### BEFORE FIX (Broken)
- Layout calculates: "Text fits in 518pt container"
- View renders: Text in 648pt container = **130pt more text!**
- Result: Text overlaps footnote ❌

### AFTER FIX (Correct)
- Layout calculates: "Text fits in 518pt container"
- View renders: Text in 518pt container ✅
- Insets position it correctly within 792pt frame
- Result: Text stops exactly where footnote begins ✅

## Container Size vs Insets

**Container Size (textContainer.size):**
- Determines **how much** text can fit
- Affects **text wrapping** and **flow**
- Controls **where text breaks** between lines

**Container Insets (textContainerInset):**
- Determines **where** the container sits in the frame
- Adds **padding** around the container
- Does NOT affect text layout within the container

**Analogy:**
- Container size = Size of the box
- Insets = Space around the box
- You need BOTH to match layout calculation!

## Expected Console Output

```
📏 Base container size: 468.0 x 648.0
🔄 Footnote layout iteration 2
   📏 Page 0: 1 footnotes need 130.0pt
   📐 Container adjusted: 648.0pt - 130.0pt = 518.0pt
✅ Footnote layout converged after 3 iterations
📐 Final: Page 0 has 1 footnotes, reserved 130.0pt

   📦 Page 0 container size set to: 468.0 x 518.0  ← NEW LOG
📐 Text insets adjusted - bottom: 72.0pt + 130.0pt = 202.0pt
📄 Page 0: Found 1 footnotes
```

**Key:** Container size (518pt) now matches calculation!

## Visual Result

### BEFORE (Broken)
```
┌─────────────────────┐
│ Paragraph 1         │
│ Paragraph 2         │
│ Paragraph 3 start...│ ← Text overflows!
│─────────────────────│
│ 1. Footnote text... │ ← Overlaps paragraph 3
└─────────────────────┘
```

### AFTER (Fixed)
```
┌─────────────────────┐
│ Paragraph 1         │
│ Paragraph 2         │
│                     │ ← Text stops here
│─────────────────────│
│ 1. Footnote text... │ ← No overlap!
└─────────────────────┘

┌─────────────────────┐
│ Paragraph 3 start...│ ← Moved to page 2
│ Paragraph 3 cont... │
└─────────────────────┘
```

## Code Changes

**File:** `VirtualPageScrollView.swift`
**Method:** `renderPage(at pageIndex:)`
**Lines:** ~287-310

**Added:**
```swift
// Set the text view's container to match the calculated size
let pageIndex = pageInfo.pageIndex
if pageIndex < layoutManager.layoutManager.textContainers.count {
    let calculatedContainer = layoutManager.layoutManager.textContainers[pageIndex]
    let calculatedSize = calculatedContainer.size
    
    textView.textContainer.size = calculatedSize
    textView.textContainer.lineFragmentPadding = 0
    
    #if DEBUG
    print("   📦 Page \(pageIndex) container size set to: \(calculatedSize.width) x \(calculatedSize.height)")
    #endif
}
```

## Why This Wasn't Caught Earlier

1. **Console logs looked correct:** Container calculation showed 518pt
2. **Math checked out:** 648 - 130 = 518 ✅
3. **No error messages:** Code ran without crashes
4. **Subtle symptom:** Only visible with actual content and footnotes
5. **Hidden assumption:** Assumed insets would limit text (they don't!)

The bug was in the **assumption** that adjusting insets would limit text layout. In reality, UITextView's textContainer.size controls layout, and insets only control positioning.

## Testing

**Test:** View document with 3 paragraphs and 1 footnote (after paragraph 1 or 2)

**Expected:**
- ✅ Paragraph 3 should NOT appear above footnote
- ✅ Text should stop cleanly before footnote area
- ✅ Paragraph 3 should start on page 2
- ✅ No text overlap with footnote

**Console should show:**
```
📦 Page 0 container size set to: 468.0 x 518.0
```

## Related Issues

- **Fixes:** Text overlapping footnote (critical bug)
- **Depends on:** FOOTNOTE_ACTUAL_HEIGHT_FIX.md (correct height calculation)
- **Depends on:** FOOTNOTE_MISSING_PARAMETERS_FIX.md (parameters bug)
- **Depends on:** FOOTNOTE_ITERATIVE_CONVERGENCE.md (convergence algorithm)

## Date

2025-11-25

## Status

✅ **CRITICAL FIX APPLIED** - Text container size now matches layout calculation, preventing text overflow into footnote area.
