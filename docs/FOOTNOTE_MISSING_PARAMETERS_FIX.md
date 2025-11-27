# Critical Bug Fix: Footnote-Aware Layout Not Being Used

## Issue

Despite implementing the iterative convergence algorithm for footnote-aware pagination, the console output showed:
- ✅ `Layout calculated: 2 pages`
- ❌ **Missing:** `🔄 Footnote layout iteration` logs
- ❌ **Missing:** `✅ Footnote layout converged` message
- ❌ **Result:** Footnotes still appearing in wrong positions

This indicated that the footnote-aware layout algorithm wasn't being executed at all.

## Root Cause

**PaginatedDocumentView.swift** had two critical bugs:

### Bug 1: setupLayoutManager() - Line 236
```swift
// ❌ BEFORE - Missing version and context parameters
DispatchQueue.global(qos: .userInitiated).async {
    let _ = manager.calculateLayout()  // No parameters!
    print("   ✅ Layout calculated: \(manager.pageCount) pages")
```

### Bug 2: recalculateLayout() - Line 279
```swift
// ❌ BEFORE - Missing version and context parameters
DispatchQueue.global(qos: .userInitiated).async {
    let _ = existingManager.calculateLayout()  // No parameters!
    print("   ✅ Recalculated: \(existingManager.pageCount) pages")
```

When `calculateLayout()` is called without `version` and `context` parameters, this condition triggers:

```swift
// In PaginatedTextLayoutManager.swift
func calculateLayout(version: Version? = nil, context: ModelContext? = nil) -> LayoutResult {
    if version == nil || context == nil {
        return calculateSimpleLayout(...)  // ❌ Takes simple path
    }
    return calculateFootnoteAwareLayout(...)  // ✅ Never reached!
}
```

**Result:** Always used simple layout (no footnote adjustments), so the iterative convergence algorithm was never executed.

## Solution

Pass `version` and `context` to both `calculateLayout()` calls:

### Fix 1: setupLayoutManager()
```swift
// ✅ AFTER - Pass version and context
let version = textFile.currentVersion
let context = modelContext

DispatchQueue.global(qos: .userInitiated).async {
    let _ = manager.calculateLayout(version: version, context: context)
    print("   ✅ Layout calculated: \(manager.pageCount) pages")
```

### Fix 2: recalculateLayout()
```swift
// ✅ AFTER - Pass version and context
let version = textFile.currentVersion
let context = modelContext

DispatchQueue.global(qos: .userInitiated).async {
    let _ = existingManager.calculateLayout(version: version, context: context)
    print("   ✅ Recalculated: \(existingManager.pageCount) pages")
```

### Added Debug Logging
Also added debug logs to `calculateLayout()` to make path selection visible:

```swift
if version == nil || context == nil {
    #if DEBUG
    print("🔧 Using SIMPLE layout (no version/context)")
    #endif
    return calculateSimpleLayout(...)
}

#if DEBUG
print("🔧 Using FOOTNOTE-AWARE layout with version: \(version!.id.uuidString.prefix(8))")
#endif
return calculateFootnoteAwareLayout(...)
```

## Expected Console Output (After Fix)

When viewing paginated document, you should now see:

```
📱 PaginatedDocumentView appeared
   - currentVersionIndex: 0
🔧 setupLayoutManager called
   - currentVersionIndex: 0
   - currentVersion: 8EAC474D
   - content length: 2042
🔧 Using FOOTNOTE-AWARE layout with version: 8EAC474D
🔄 Footnote layout iteration 1
🔄 Footnote layout iteration 2
🔄 Footnote layout iteration 3
✅ Footnote layout converged after 3 iterations
📐 Final: Page 0 has 1 footnotes, reserved 250.0pt
📐 Final: Page 1 has no footnotes, full height
   ✅ Layout calculated: 2 pages
   ✅ Layout manager assigned
📄 Page 0: Found 1 footnotes
📏 Footnote height for page 0: 130.0pt
...
```

## Testing

**Before Fix:**
- Footnote appears in middle of page 2
- No iteration logs
- Simple layout always used

**After Fix:**
- Iteration logs appear (2-3 iterations)
- Convergence message appears
- Footnotes should be on correct pages
- Page 2 uses full height (no wasted space)

**Test Steps:**
1. Open document with 3 paragraphs and 1 footnote
2. Switch to pagination view
3. Check console for iteration logs
4. Verify footnote positioning:
   - Page 1: Text ends early, footnote at bottom
   - Page 2: Text starts at top (full height), no footnote

## Why This Wasn't Caught Earlier

1. **VirtualPageScrollView** was correctly passing version/context (lines 139, 183)
2. But **PaginatedDocumentView** creates the layout manager initially
3. Initial creation didn't pass parameters → simple layout used
4. VirtualPageScrollView's recalculations never triggered because layout was already "valid"

The bug was hidden because:
- Code compiled fine (parameters are optional with defaults)
- No obvious errors or crashes
- Only symptom: wrong footnote positions and missing debug logs

## Files Modified

1. **PaginatedDocumentView.swift**
   - `setupLayoutManager()`: Added version/context parameters (line ~231)
   - `recalculateLayout()`: Added version/context parameters (line ~275)

2. **PaginatedTextLayoutManager.swift**
   - `calculateLayout()`: Added debug logging to show path selection (line ~100)

## Related Issues

- **Depends on:** FOOTNOTE_ITERATIVE_CONVERGENCE.md (algorithm implementation)
- **Fixes:** Missing iteration logs and incorrect footnote positioning
- **Next:** Test the complete solution with real documents

## Date

2025-11-25
