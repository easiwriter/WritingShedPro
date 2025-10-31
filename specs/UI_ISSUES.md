# UI Issues and Enhancements

## Issue: Manage Stylesheet Popup Background Transparency (Mac)

**Date Reported**: 2025-10-31  
**Platform**: macOS (Mac Catalyst)  
**Priority**: Low (Cosmetic)  

**Description**:
The Manage Stylesheet popup uses translucent/liquid glass effect on Mac, allowing text from the document behind it to show through. This can be confusing for users at first glance.

**Current Behavior**:
- Sheet presentation uses default system material
- Background is semi-transparent on macOS
- Document text visible behind the sheet

**Desired Behavior**:
- Use opaque background for stylesheet management sheet
- Or use stronger blur/material to make content less visible
- Make it clear this is a modal overlay

**Possible Solutions**:

1. **Disable transparency for this specific sheet**:
   ```swift
   .presentationBackground(.regularMaterial) // or .thickMaterial
   ```

2. **Use solid color background**:
   ```swift
   .presentationBackground(Color(UIColor.systemBackground))
   ```

3. **Platform-specific styling**:
   ```swift
   #if targetEnvironment(macCatalyst)
   .presentationBackground(Color(UIColor.systemBackground))
   #endif
   ```

**Affected Views**:
- `StyleSheetManagementView` (Settings → Manage Stylesheets)
- Possibly other sheet presentations that have similar issues

**Notes**:
- This is a SwiftUI default behavior on macOS
- May want to audit all sheet presentations for consistency
- Consider if this should apply to all sheets or just specific ones
- User to test after completing current stylesheet testing

**Related Files**:
- `/WrtingShedPro/Writing Shed Pro/Views/StyleSheetManagementView.swift`
- Potentially other views with `.sheet()` modifiers

---

## Issue: Italic Button in Style Editor Too Sensitive to Tap Position

**Date Reported**: 2025-10-31  
**Platform**: iOS/iPadOS  
**Priority**: Medium (Usability)  

**Description**:
The Italic button (I) in the TextStyleEditorView is very sensitive to tap position. Users need to tap precisely on the button for it to register, making it difficult to toggle italic formatting.

**Current Behavior**:
- Tap target seems smaller than visual button size
- Requires precise tapping to activate
- May miss taps that appear to be on the button

**Desired Behavior**:
- Button should respond to taps anywhere within its visual bounds
- Consistent hit target with other formatting buttons (B, U, S)
- Easy to tap without precision

**Possible Causes**:
1. Button frame size doesn't match visual size (50x44)
2. `.buttonStyle(.plain)` affecting hit testing
3. Overlap with adjacent buttons causing hit target conflicts
4. Missing `.contentShape(Rectangle())` modifier

**Possible Solutions**:

1. **Add explicit content shape**:
   ```swift
   Button(action: { style.isItalic.toggle() }) {
       // ... button content
   }
   .contentShape(Rectangle())
   .frame(width: 50, height: 44)
   ```

2. **Increase spacing between buttons**:
   ```swift
   HStack(spacing: 24) { // Increase from 20
       // ... buttons
   }
   ```

3. **Check for gesture conflicts** - Review if any overlapping views are capturing taps

4. **Ensure consistent button structure** - Compare with Bold button which likely works better

**Affected Views**:
- `TextStyleEditorView` → Font Settings section
- Specifically the Italic (I) button in the B/I/U/S button row

**Notes**:
- Other buttons (B, U, S) may have similar issues - needs testing
- This affects user experience when editing styles
- Quick fix: Add `.contentShape(Rectangle())` to all formatting buttons

**Related Files**:
- `/WrtingShedPro/Writing Shed Pro/Views/TextStyleEditorView.swift` (lines ~176-192)

**Related Code**:
```swift
Button(action: {
    style.isItalic.toggle()
    hasUnsavedChanges = true
}) {
    Text("I")
        .font(.system(size: 20, weight: .regular))
        .italic()
        .foregroundColor(style.isItalic ? .white : .accentColor)
        .frame(width: 50, height: 44)
        .background(style.isItalic ? Color.accentColor : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, lineWidth: 2)
        )
}
.buttonStyle(.plain)
```

---

## Future UI Issues
Add additional UI issues below as they are discovered...
