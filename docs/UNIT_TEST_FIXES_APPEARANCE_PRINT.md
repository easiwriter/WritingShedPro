# Unit Test Fixes - Appearance Mode and Print Service

**Date:** November 27, 2025  
**Status:** ✅ COMPLETE

## Issues Fixed

### 1. AppearanceModeColorTests (9 test failures)

**Root Cause:** Tests were checking that `stripAdaptiveColors()` removes colors and leaves `nil`, but the actual implementation replaces adaptive colors with `UIColor.label` for proper dark mode support.

**Failed Tests:**
- `testStripAdaptiveColors_RemovesBlackColor()`
- `testStripAdaptiveColors_RemovesWhiteColor()`
- `testStripAdaptiveColors_RemovesGrayColor()`
- `testStripAdaptiveColors_HandlesMultipleRanges()`
- `testEncode_DoesNotSaveBlackColor()`
- `testEncode_DoesNotSaveWhiteColor()`
- `testEncode_DoesNotSaveGrayColor()`
- `testEncode_PreservesBoldAndStripsBlackColor()`
- `testDecode_StripsAdaptiveColorsFromOldDocuments()`

**Expected Behavior (from implementation):**

The `AttributedStringSerializer.stripAdaptiveColors()` function:
1. Removes black/white/gray `.foregroundColor` attributes
2. **Adds `.label` color** to those ranges for adaptive appearance support
3. Preserves custom colors (red, blue, cyan, etc.)

From `AttributedStringSerializer.swift` line 156:
```swift
// Add .label color to ranges that have no color or had adaptive colors removed
// This ensures UITextView uses adaptive color instead of defaulting to black
for range in rangesToAddLabel {
    mutableString.addAttribute(.foregroundColor, value: UIColor.label, range: range)
    print("🧹 Added .label color for adaptive dark mode at range...")
}
```

**Solution:** Updated all assertions to check for `UIColor.label` instead of `nil`:

```swift
// Before (incorrect):
XCTAssertNil(color, "Black color should be stripped")

// After (correct):
XCTAssertEqual(color, UIColor.label, "Black color should be replaced with .label for adaptive behavior")
```

### 2. PrintServiceTests (1 test failure)

**Test:** `testPrintError_Failed_HasCorrectDescription()`

**Root Cause:** The `NSLocalizedString` calls in `PrintError.errorDescription` were missing default `value` parameters. When no localized string file exists, `NSLocalizedString` returns just the key (e.g., "print.error.failed") instead of a useful message. This caused `String(format:)` to fail because the key didn't contain the "%@" placeholder.

**Original Implementation:**
```swift
case .failed(let message):
    return String(format: NSLocalizedString("print.error.failed", comment: "Print failed: %@"), message)
```

When no Localizable.strings exists:
- `NSLocalizedString("print.error.failed", comment: ...)` returns "print.error.failed"
- `String(format: "print.error.failed", "Test failure")` returns "print.error.failed" (no %@ placeholder!)

**Solution:** Added `value` parameter to provide default English text:

```swift
case .failed(let message):
    return String(format: NSLocalizedString("print.error.failed", value: "Print failed: %@", comment: "Print failed: %@"), message)
```

Now when no localization exists:
- `NSLocalizedString(..., value: "Print failed: %@", ...)` returns "Print failed: %@"
- `String(format: "Print failed: %@", "Test failure")` returns "Print failed: Test failure" ✅

**Files Modified:**
- `PrintService.swift` - Added `value` parameter to all 4 error descriptions
  - `noContent`: "No content to print"
  - `notAvailable`: "Printing is not available"
  - `cancelled`: "Printing was cancelled"
  - `failed`: "Print failed: %@"

## Why .label Instead of nil?

The design decision to add `.label` instead of leaving color as `nil` is intentional:

**Problem with nil:**
- UITextView defaults to black when no `.foregroundColor` is set
- In dark mode, black text on dark background is invisible
- Old documents lose text visibility when switching to dark mode

**Solution with .label:**
- `.label` is a dynamic system color that adapts to appearance mode
- Light mode: `.label` = black
- Dark mode: `.label` = white
- Text remains visible in both modes
- Old documents with baked-in black/white colors get fixed automatically

## Files Modified

1. **AppearanceModeColorTests.swift**
   - Updated 9 test assertions to expect `.label` instead of `nil`
   - Tests now correctly validate adaptive color behavior

2. **PrintServiceTests.swift**
   - Enhanced error message validation test
   - Added better diagnostics for test failures

## Validation

✅ All compilation errors resolved  
✅ All test logic updated to match implementation behavior  
✅ No other errors in project  
✅ Tests now correctly validate:
- Adaptive color stripping replaces with `.label`
- Custom colors are preserved
- Encode/decode cycle maintains adaptive behavior
- Print errors include descriptive messages

## Related Documentation

- `/docs/session-notes/APPEARANCE_MODE_FIX_COMPLETE.md` - Complete dark mode fix documentation
- `/docs/session-notes/DARK_MODE_PASTE_FIX.md` - Original dark mode paste issue
- `AttributedStringSerializer.swift` lines 31-165 - Adaptive color helpers and stripping logic
- `FormattedTextEditor.swift` lines 120-165, 295-335 - Typing attributes filtering

## Impact

**No Breaking Changes:**
- Test fixes align with actual implementation
- Behavior remains correct for dark mode support
- Old documents continue to be fixed on load
- Custom colors remain preserved

**Test Coverage:**
- 9 appearance mode color tests now passing
- 1 print service error test now passing
- All tests validate correct adaptive behavior
