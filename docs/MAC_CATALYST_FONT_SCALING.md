# Mac Catalyst Font Scaling

**Date:** 26 November 2025  
**Issue:** Text appears too small on Mac Catalyst compared to native Mac apps  
**Solution:** Platform-specific font scaling for Mac desktop viewing distances

---

## Problem

When running Writing Shed Pro via Mac Catalyst:
- iOS Dynamic Type `.body` = 17pt looks appropriate on iPhone/iPad
- Same 17pt looks **too small** on Mac at typical desktop viewing distances
- Users expect Mac-like typography closer to Pages/TextEdit sizing
- Professional documents need larger text for comfortable desktop reading

### Root Cause

**Viewing Distance Differences:**
- **iPhone/iPad:** Held 12-18 inches from face → 17pt is comfortable
- **Mac Desktop:** Screen 20-30 inches from face → 17pt feels small
- **Typography Standard:** Mac apps typically use 12-14pt fonts, but appear larger due to screen size/resolution

---

## Solution

### Platform-Specific Scaling at Render Time

Modified `TextStyleModel.generateFont()` to apply **1.5x scaling** for Mac Catalyst at render time.

**File:** `Models/StyleSheetModels.swift`

```swift
/// Generate a UIFont from this style's attributes
/// Applies platform-specific scaling for Mac Catalyst
func generateFont() -> UIFont {
    // Apply platform scaling for Mac Catalyst
    #if targetEnvironment(macCatalyst)
    let platformScaleFactor: CGFloat = 1.3  // 30% larger on Mac
    #else
    let platformScaleFactor: CGFloat = 1.0  // Standard size on iOS/iPadOS
    #endif
    
    let baseSize = fontSize * platformScaleFactor
    // ... rest of font generation
}
```

### Font Size Comparison

| Style | iOS/iPadOS | Mac Catalyst | Notes |
|-------|------------|--------------|-------|
| Body | 17pt | 22.1pt | Base reading text |
| Body 1 (Callout) | 16pt | 20.8pt | Slightly smaller |
| Body 2 (Subheadline) | 14pt | 18.2pt | Compact text |
| Headline | 17pt (bold) | 22.1pt (bold) | Section headers |
| Title 1 | 28pt | 36.4pt | Major headings |
| Title 2 | 22pt | 28.6pt | Subheadings |
| Title 3 | 20pt | 26pt | Minor headings |
| Large Title | 34pt | 44.2pt | Document titles |
| Footnote | 13pt | 16.9pt | Footnotes/annotations |
| Caption 1 | 12pt | 15.6pt | Small text |
| Caption 2 | 11pt | 14.3pt | Smallest text |

### List Styles
All list styles (numbered, bullet, letter) also scaled by 1.3x on Mac Catalyst:
- Base: 17pt → 22.1pt

---

## Implementation Details

### Where Scaling is Applied

**At render time in generateFont():**
```swift
let baseSize = fontSize * platformScaleFactor
```

**Applies to:**
1. ✅ All system text styles (Body, Headline, Titles, etc.)
2. ✅ All list styles (numbered, bullet, letter)
3. ✅ **All user-created custom styles** (NEW!)
4. ✅ Any style rendered through TextStyleModel.generateFont()

### When Scaling Takes Effect

- ✅ **New documents** - Use scaled fonts immediately
- ✅ **Existing documents** - Use scaled fonts when opening
- ✅ **User custom styles** - Automatically scaled on Mac
- ✅ **Style reapplication** - Fonts update to scaled sizes
- ✅ **Runtime switching** - Works if user changes stylesheet

### Why Render-Time Scaling?

**Benefits:**
- User creates style with 18pt on iOS → stores as 18pt in database
- Same style renders as 18pt on iOS, 27pt (18 × 1.5) on Mac
- Database values are platform-agnostic
- Documents fully portable between iOS/Mac

### What's NOT Scaled

- ❌ **Pagination/Print Preview** - Shows actual print size (scaling removed for accuracy)
- ❌ **Legacy imported documents** - Have separate 1.8x scaling for readability

### Pagination View Exception

**Problem:** The 1.3x Mac Catalyst scaling made pagination view show fonts larger than their actual print size.

**Solution:** `PaginatedDocumentView` removes Mac Catalyst scaling before rendering:
```swift
/// Remove Mac Catalyst 1.3x scaling for print-accurate pagination view
private func removePlatformScaling(from attributedString: NSAttributedString) -> NSAttributedString {
    #if targetEnvironment(macCatalyst)
    let scaleFactor: CGFloat = 1.0 / 1.3  // Undo editor scaling
    // ... scale fonts back to actual size
    #else
    return attributedString  // No adjustment needed on iOS
    #endif
}
```

**Result:**
- **Edit View (Mac):** Text at 1.3x (22.1pt) - comfortable for editing
- **Edit View (iOS):** Text at 1.0x (17pt) - standard iOS size  
- **Pagination View (All Platforms):** Text at 1.0x (17pt) - accurate print preview
- **Print Output:** Matches pagination view exactly on all platforms

**Important:** Pagination view shows the SAME font sizes on Mac, iPad, and iPhone for print accuracy. Use the zoom controls if you want larger/smaller preview.

---

## Testing

### Manual Testing Checklist

- [ ] Create new document on Mac → Text should be ~22pt for Body
- [ ] Create new document on iPad → Text should be 17pt for Body
- [ ] Open existing document on Mac → Should use scaled fonts
- [ ] Apply paragraph styles on Mac → Should use scaled fonts
- [ ] Switch between iOS and Mac → Fonts adjust appropriately
- [ ] Import legacy database → Should maintain separate 1.8x scaling

### Verification

**On Mac Catalyst:**
```swift
// Check font size in document
let bodyStyle = defaultStyleSheet.style(named: "body")
print("Body font size on Mac: \(bodyStyle?.fontSize ?? 0)")
// Should print: Body font size on Mac: 22.1
```

**On iOS:**
```swift
// Same check on iOS
print("Body font size on iOS: \(bodyStyle?.fontSize ?? 0)")
// Should print: Body font size on iOS: 17.0
```

---

## Design Rationale

### Why 1.3x Scaling?

**Considered Options:**
- **1.2x (20.4pt):** Felt slightly small for desktop viewing
- **1.3x (22.1pt):** ✅ Good balance - comfortable without being excessive
- **1.5x (25.5pt):** Too large - text overwhelms page layout
- **2.0x (34pt):** Way too large - wastes screen space

**Decision:** 1.3x provides:
- ✅ Comfortable reading at desktop distances
- ✅ Professional document appearance
- ✅ Matches expectations from Mac applications
- ✅ Efficient use of screen space
- ✅ Similar to Pages default sizing

### Platform Philosophy

**iOS/iPadOS:**
- Optimized for handheld/touch usage
- Closer viewing distances
- Dynamic Type respects accessibility
- Standard 17pt body text

**Mac Catalyst:**
- Desktop environment expectations
- Farther viewing distances
- Larger screens need proportional text
- Professional document editing focus

---

## Backward Compatibility

### Existing Documents
✅ **Safe change** - Only affects font rendering, not stored data  
✅ **Cross-platform** - Documents created on iOS open correctly on Mac and vice versa  
✅ **Reversible** - Can adjust scaling factor if needed  
✅ **No migration needed** - Scaling applied at runtime

### Stylesheet Updates
- System stylesheet recreated with new sizes on first launch after update
- Custom user stylesheets remain unchanged
- No data loss or corruption

### Legacy Imports
- Legacy imports (Writing Shed 1.0) maintain separate 1.8x scaling
- This scaling is independent and cumulative
- Mac Catalyst: 1.8x (legacy) applied first, then uses scaled system styles

---

## Future Enhancements

### User Preference (Optional)
Could add setting for Mac text size preference:
```swift
enum MacFontScale: CGFloat {
    case compact = 1.2    // Closer to iOS size
    case comfortable = 1.3 // Default
    case large = 1.5      // Maximum readability
}
```

### Per-Document Scale
Could remember user's preferred zoom per document:
```swift
class TextFile {
    var macFontScale: CGFloat = 1.3  // Override default
}
```

### Adaptive Scaling
Could detect display size and adjust:
```swift
let displaySize = NSScreen.main?.frame.size ?? .zero
let scaleFactor = displaySize.width > 2000 ? 1.4 : 1.3
```

---

## Related Files

**Modified:**
- `Models/StyleSheetModels.swift` - Added platform scaling in `generateFont()` method
- `Services/StyleSheetService.swift` - Removed scaling from creation time (now at render time)
- `Views/PaginatedDocumentView.swift` - Added `removePlatformScaling()` for print-accurate preview

**Related:**
- `Services/TextFormatter.swift` - Style application logic (uses generateFont())
- `Services/AttributedStringSerializer.swift` - Legacy import scaling (separate 1.8x)

---

## Notes

- This is a **viewing/rendering change only** - no document format changes
- Scaling is **transparent** to users - just looks better on Mac
- Compatible with **all existing features** (pagination, footnotes, styles, etc.)
- Can be **fine-tuned** in future if 1.3x isn't optimal

---

## See Also

- `LEGACY_IMPORT_STYLE_FIX.md` - Separate 1.8x scaling for imported documents
- `PAGINATION_BASE_SCALING.md` - Previous pagination scaling (removed)
- `specs/005-text-formatting/` - Text style system documentation
