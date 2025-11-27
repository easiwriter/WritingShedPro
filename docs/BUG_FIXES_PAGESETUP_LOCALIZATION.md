# Bug Fixes: Page Setup Sync & Stylesheet Localization

**Date:** 24 November 2025  
**Issues Fixed:** 2

---

## Issue 1: Page Setup Changes Not Persisting ❌→✅

### Problem
When opening the Page Setup dialog, changing values (e.g., paper size A4→Letter), closing, and reopening, the changes were lost. Values reverted to original state.

### Root Cause
The `PageSetupForm` was comparing edited values against **current** preference values (which may have been synced from iCloud) instead of the **original** values captured when the form opened.

**Example flow that failed:**
1. Form opens → captures `originalPaperName = "A4"` and `paperName = "A4"`
2. User changes to Letter → `paperName = "Letter"`
3. iCloud sync updates prefs → `prefs.paperName` is now something else
4. User taps Done → compares `paperName != prefs.paperName` (true because prefs changed)
5. Writes "Letter" to prefs
6. But the comparison logic was wrong - it would fail to detect actual user changes

The real issue was simpler: we weren't tracking the original values properly, so changes weren't being saved at all.

### Solution
**File:** `PageSetupForm.swift`

1. **Track Original Values** - Added state variables to capture all original values:
```swift
@State private var originalPaperName: String = ""
@State private var originalOrientation: Int16 = 0
@State private var originalHeaders: Bool = false
// ... all 13 properties
```

2. **Load Values in onAppear** - Changed from init-time loading to onAppear:
```swift
private func loadValues() {
    // Load current values from preferences
    paperName = prefs.paperName
    orientation = prefs.orientation.rawValue
    // ... load all values
    
    // Remember original values to detect changes
    originalPaperName = paperName
    originalOrientation = orientation
    // ... capture all originals
}
```

3. **Compare Against Originals** - Fixed savePageSetup() to compare against original values:
```swift
private func savePageSetup() {
    // BEFORE: if paperName != prefs.paperName { ... }
    // AFTER:  if paperName != originalPaperName { ... }
    
    if paperName != originalPaperName {
        print("[PageSetupForm] Paper name changed: \(originalPaperName) → \(paperName)")
        prefs.setPaperName(paperName)
    }
    // ... same for all 13 properties
}
```

### Result
✅ Changes now persist correctly  
✅ Only modified values are written to iCloud  
✅ No accidental overwrites of synced values

---

## Issue 2: Stylesheet Editor Showing Localization Keys ❌→✅

### Problem
The stylesheet detail view was displaying raw localization keys like `"styleSheetDetail.previewText"` instead of the actual localized text.

### Root Cause
Text() views were using string literals instead of `NSLocalizedString()` function calls.

**Example:**
```swift
// WRONG:
Text("styleSheetDetail.previewText")

// CORRECT:
Text(NSLocalizedString("styleSheetDetail.previewText", comment: "Preview text for style"))
```

### Solution
**File:** `StyleSheetDetailView.swift`

Fixed all localization issues in the file:

1. **Section Headers:**
   - `"styleSheetDetail.textStyles"` → `NSLocalizedString("styleSheetDetail.textStyles", ...)`
   - `"styleSheetDetail.listStyles"` → `NSLocalizedString("styleSheetDetail.listStyles", ...)`
   - `"styleSheetDetail.imageStyles"` → `NSLocalizedString("styleSheetDetail.imageStyles", ...)`

2. **Labels:**
   - `"styleSheetDetail.name"` → `NSLocalizedString("styleSheetDetail.name", ...)`
   - `"styleSheetDetail.stylesCount"` → `NSLocalizedString("styleSheetDetail.stylesCount", ...)`
   - `"styleSheetDetail.bold"` → `NSLocalizedString("styleSheetDetail.bold", ...)`
   - `"styleSheetDetail.italic"` → `NSLocalizedString("styleSheetDetail.italic", ...)`
   - `"styleSheetDetail.previewText"` → `NSLocalizedString("styleSheetDetail.previewText", ...)`
   - `"styleSheetDetail.noImageStyles"` → `NSLocalizedString("styleSheetDetail.noImageStyles", ...)`
   - `"styleSheetDetail.noCaption"` → `NSLocalizedString("styleSheetDetail.noCaption", ...)`

3. **Alignment Names:**
   - Hard-coded "Left", "Center", etc. → `NSLocalizedString("styleSheetDetail.alignment.left", ...)`
   - Added for: left, center, right, justified, natural, inline

4. **Buttons:**
   - `"styleSheetDetail.newStyle"` → `NSLocalizedString("styleSheetDetail.newStyle", ...)`
   - Accessibility labels also fixed

### Result
✅ All text displays properly localized  
✅ Consistent with rest of app  
✅ Ready for future translations

---

## Files Modified

1. **`Views/Forms/PageSetupForm.swift`**
   - Added 12 @State variables to track original values
   - Modified `loadValues()` to capture originals
   - Fixed `savePageSetup()` to compare against originals
   - Added logging for debugging

2. **`Views/StyleSheetDetailView.swift`**
   - Fixed 14+ Text() calls to use NSLocalizedString()
   - Localized all section headers
   - Localized alignment names in both text and image style rows
   - Added proper comment strings for translators

---

## Testing Recommendations

### Page Setup Sync
1. ✅ Change paper size on iPhone → verify persists on reopen
2. ✅ Change margins on Mac → verify persists on reopen
3. ✅ Open form without changes → verify doesn't trigger writes
4. ✅ Test iCloud sync between devices
5. ✅ Verify logging shows correct "changed" messages

### Stylesheet Localization
1. ✅ Open stylesheet detail view → verify no raw keys visible
2. ✅ Check all sections: Text Styles, List Styles, Image Styles
3. ✅ Verify alignment names display correctly
4. ✅ Check bold/italic labels
5. ✅ Verify preview text label

---

## Related Issues

This completes the Page Setup sync work from Feature 019. Previous fixes:
- ✅ Migration to NSUbiquitousKeyValueStore (iCloud sync)
- ✅ Change detection to prevent unnecessary writes
- ✅ Live updates via notification listener
- ✅ **NEW:** Proper original value tracking for persistence

---

## Notes

The Page Setup issue was subtle - the form was receiving values correctly, but wasn't saving user changes because it lacked proper change detection against original values. This is now fixed with comprehensive original value tracking.

The stylesheet localization issue was straightforward - simple oversight where Text() was used instead of NSLocalizedString(). All instances are now fixed.
