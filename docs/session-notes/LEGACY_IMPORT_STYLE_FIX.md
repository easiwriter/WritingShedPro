# Legacy Import Style Fix

## Issues Fixed

### Issue 1: Body Text Displaying as Title 2
Legacy Writing Shed 1.0 imports were displaying all body text as **Title 2** instead of **Body** style.

### Issue 2: Bold/Italic Traits Lost
Bold poem titles and italic text were losing their formatting after import.

## Root Cause Analysis

### Problem 1: Style Matching
1. **Legacy Mac fonts** used standard sizes (typically 12-13pt for body text)
2. **Font scaling** for iOS readability: `12pt × 1.8 = 21.6pt`
3. **Size-based style matching** in `TextFormatter.matchFontToStyle()`:
   - Body ≈ 17pt
   - Title2 ≈ 22pt
   - 21.6pt is closer to 22pt than 17pt → matched as Title2 ❌
4. **Legacy RTF** had no `.textStyle` attribute, so relied on font-size matching

### Problem 2: Trait Loss During Scaling
1. **RTF import** correctly preserved bold/italic traits
2. **`font.withSize(newSize)`** created new font **without preserving symbolic traits**
3. Result: All bold/italic formatting was lost during 1.8x scaling ❌

### Why 1.8x Scaling?
The 1.8x scale factor makes Mac text readable on iOS devices, but it's purely for **readability**, not **semantic meaning**. Body text should remain Body regardless of its displayed size.

## Solution

### Design Decision
**The scaling is purely for readability, not semantic meaning:**
- All imported text is marked as `.body` style regardless of final font size
- Bold/italic/underline traits are preserved in the UIFont
- The `.textStyle` attribute ensures text is treated as Body (not matched by size)

### Implementation
Modified `AttributedStringSerializer.scaleFonts()` to:
1. **Preserve symbolic traits** when scaling fonts
2. **Add `.textStyle = .body`** attribute for proper style classification

```swift
mutableString.enumerateAttribute(.font, in: range, options: []) { value, range, _ in
    if let font = value as? UIFont {
        let newSize = font.pointSize * scaleFactor
        
        // CRITICAL: Preserve symbolic traits (bold, italic) when scaling
        // UIFont.withSize() loses traits, so we must use the font descriptor
        let descriptor = font.fontDescriptor
        let scaledDescriptor = descriptor.withSize(newSize)
        let scaledFont = UIFont(descriptor: scaledDescriptor, size: newSize)
        
        mutableString.addAttribute(.font, value: scaledFont, range: range)
        
        // IMPORTANT: Set .textStyle = .body for all legacy imported text
        // The 1.8x scaling is purely for readability (Mac 12pt → iOS 21.6pt)
        // This should NOT affect semantic meaning - all body text should remain Body style
        // The .textStyle attribute takes priority over font-size-based style matching
        // Bold/italic/underline traits are preserved in the scaled font descriptor
        mutableString.addAttribute(.textStyle, value: UIFont.TextStyle.body.attributeValue, range: range)
    }
}
```

**Key Changes:**
- **Before:** `font.withSize(newSize)` ❌ Lost bold/italic traits
- **After:** `UIFont(descriptor: descriptor.withSize(newSize), size: newSize)` ✅ Preserves all traits

### Why This Works
`TextFormatter.currentTextStyle()` already prioritizes `.textStyle` attribute over size-based matching:

```swift
// First, try to get the stored text style attribute
if let styleValue = attributedText.attribute(.textStyle, at: checkLocation, effectiveRange: nil),
   let style = UIFont.TextStyle.from(attributeValue: styleValue) {
    return style  // ✅ Uses .textStyle if it exists
}

// Fallback: try to match font to style (for legacy or untagged text)
if let font = attributedText.attribute(.font, at: checkLocation, effectiveRange: nil) as? UIFont {
    return matchFontToStyle(font)  // ⚠️ Only called if .textStyle is missing
}
```

## Result
✅ Legacy imports now:
1. **Scale fonts by 1.8x** for readability (12pt → 21.6pt)
2. **Display as Body style** (not Title2) via `.textStyle` attribute
3. **Preserve bold/italic/underline traits** via font descriptor
4. **Maintain semantic correctness** while improving readability

## Files Modified
- `Writing Shed Pro/Services/AttributedStringSerializer.swift`
  - Modified `scaleFonts()` to add `.textStyle = .body` attribute
  - Updated documentation to explain design decision

## Testing
To verify:
1. Import a Writing Shed 1.0 database
2. Check that body text displays as Body (not Title2)
3. Verify bold/italic traits are preserved
4. Confirm text is readable (1.8x scaling applied)

## Related Documents
- `specs/009-database-import/` - Legacy import feature specification
- `REFACTOR_VERSION_CENTRIC_ANNOTATIONS.md` - Upcoming refactoring for Comments/Footnotes
