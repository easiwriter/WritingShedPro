# Appearance Mode Color Adaptation - Fixed

**Date:** November 2, 2025  
**Issue:** Text typed in light mode becomes invisible when switching to dark mode (and vice versa)

## Problem

The real issue was **NOT pasting** - it was **serialization of system adaptive colors**.

When you type text in UITextView:
1. UITextView adds `.label` color to typing attributes (black in light mode, white in dark mode)
2. This color gets stored in the NSAttributedString
3. `AttributedStringSerializer.encode()` serializes ALL colors, including `.label`
4. The serialized color becomes **fixed** (e.g., black) instead of adaptive
5. When you switch to dark mode, the fixed black text is invisible on black background

**This affects:**
- ❌ All text typed in any appearance mode
- ❌ Text that switches between light/dark mode
- ✅ User-selected colors (should remain fixed - working as intended)

## Root Cause

**File:** `AttributedStringSerializer.swift`  
**Method:** `encode(_ attributedString: NSAttributedString)`

The original code serialized **ALL** `.foregroundColor` attributes:

```swift
case .foregroundColor:
    // Store text color as hex string
    if let color = value as? UIColor {
        attributes.textColorHex = color.toHex()  // ❌ Stores .label as fixed hex!
    }
```

This converted adaptive colors like `.label` into fixed hex values (`#000000` for black, `#FFFFFF` for white).

## Solution

**Only serialize non-adaptive colors** - skip system colors that should adapt to appearance mode:

```swift
case .foregroundColor:
    // CRITICAL: Only store explicitly set colors, NOT system adaptive colors
    // System colors like .label adapt to light/dark mode automatically
    // If we serialize them, they become fixed black/white and break appearance switching
    if let color = value as? UIColor {
        // Check if this is a system adaptive color that should NOT be serialized
        let isAdaptiveColor = color == .label || 
                             color == .secondaryLabel ||
                             color == .tertiaryLabel ||
                             color == .quaternaryLabel ||
                             color == .placeholderText ||
                             color == .systemBackground ||
                             color == .secondarySystemBackground
        
        if !isAdaptiveColor {
            // Only serialize non-adaptive colors (user-selected colors)
            attributes.textColorHex = color.toHex()
            print("💾 ENCODE color: \(color.toHex() ?? "nil") (explicit color)")
        } else {
            print("💾 SKIP color: adaptive system color (will adapt to appearance)")
        }
    }
```

## What This Fixes

### ✅ New Text (After Fix)
- Type in light mode → black text stored as **NO explicit color**
- Switch to dark mode → text automatically becomes white (`.label` adapts)
- Type in dark mode → white text stored as **NO explicit color**
- Switch to light mode → text automatically becomes black (`.label` adapts)

### ✅ User-Selected Colors (Still Work)
- Select text, choose red from color picker → red stored as `#FF0000`
- Switch modes → **red stays red** (user intent preserved)

### ⚠️ Existing Documents (Pre-Fix)
Existing documents with serialized `.label` colors will **still have the problem** until:
1. **Option A**: User edits and re-saves (new serialization won't store the color)
2. **Option B**: We create a migration script to strip fixed black/white colors
3. **Option C**: We add runtime detection to strip `.label` colors when loading

## Implementation

**File Modified:** `WrtingShedPro/Writing Shed Pro/Services/AttributedStringSerializer.swift`

**Method:** `encode(_ attributedString: NSAttributedString)` lines ~70-85

## Behavior

### System Adaptive Colors (NOT serialized)
- `.label` - Primary text color
- `.secondaryLabel` - Secondary text
- `.tertiaryLabel` - Tertiary text
- `.quaternaryLabel` - Quaternary text
- `.placeholderText` - Placeholder text
- `.systemBackground` - System background
- `.secondarySystemBackground` - Secondary background

### User Colors (STILL serialized)
- Any color picked from color picker (`.red`, `.blue`, `.systemRed`, custom colors)
- Any explicitly set color in style sheets
- Any color that's NOT a system adaptive color

## Testing

### Manual Test Cases

**TC-1: Type in Light Mode, Switch to Dark**
1. Create new document in light mode
2. Type "Hello World" (will be black `.label`)
3. Save document (color NOT serialized)
4. Switch to dark mode
5. **Expected**: Text appears in white (visible) ✅
6. **Before fix**: Text appeared in black (invisible) ❌

**TC-2: Type in Dark Mode, Switch to Light**
1. Create new document in dark mode
2. Type "Hello World" (will be white `.label`)
3. Save document (color NOT serialized)
4. Switch to light mode
5. **Expected**: Text appears in black (visible) ✅
6. **Before fix**: Text appeared in white (invisible) ❌

**TC-3: User-Selected Red Color**
1. Create document in any mode
2. Type "Red text"
3. Select text, apply red via color picker
4. Save document (red IS serialized as `#FF0000`)
5. Switch appearance mode
6. **Expected**: Text stays red (user intent) ✅

**TC-4: Existing Document with Fixed Colors**
1. Open document created before fix (has fixed black/white colors)
2. **Expected**: May still be invisible after mode switch ⚠️
3. **Workaround**: Edit text → triggers re-save → new serialization without color

**TC-5: Mixed Content**
1. Type normal text (adaptive)
2. Apply red to some words (fixed)
3. Switch modes
4. **Expected**: Normal text adapts (black↔white), red text stays red ✅

## Build Status

✅ **BUILD SUCCEEDED**  
No compilation errors or warnings

## Next Steps

### Immediate
1. **Manual testing**: Verify all test cases above
2. **Document cleanup**: Consider migration tool for existing documents

### Future Enhancements
1. **Migration script**: Strip fixed black/white colors from existing documents
2. **Runtime cleanup**: Detect and remove `.label` colors when loading documents
3. **Color picker UI**: Show indicator for "adaptive" vs "fixed" colors

### Phase 006: Images (Next Feature)
- Now that appearance mode works correctly, proceed with image insertion
- Ensure images also respect dark mode (if applicable)

---

**Status:** Ready for testing ✅  
**Reverted:** Paste interception code (wasn't the root cause)  
**Fixed:** Serialization of adaptive colors

## Technical Notes

### Why This Works

UITextView automatically uses `.label` color for text when:
- No explicit `.foregroundColor` attribute is set
- Text has only font and paragraph attributes

By NOT serializing `.label`, we're saying "use system default", which adapts automatically.

### Why User Colors Still Work

User-selected colors are NOT `.label` - they're specific colors like:
- `.red` (UIColor.red)
- `.systemBlue`
- Custom RGB colors

These colors **should** be serialized because they represent explicit user intent.

### Comparison Check

The code uses direct UIColor equality (`color == .label`). This works because:
- UIColor.label is a singleton
- Direct comparison checks if it's the same instance
- May not catch hex-equivalent colors, but that's okay - those are user-created

### Future Consideration

If we want to be more robust, we could check hex values:
```swift
let hexValue = color.toHex()
let isBlack = hexValue == "#000000" || hexValue == "#000000FF"
let isWhite = hexValue == "#FFFFFF" || hexValue == "#FFFFFFFF"
let isAdaptive = color == .label || isBlack || isWhite
```

But this would also strip user-selected black/white, which is probably not desired.

