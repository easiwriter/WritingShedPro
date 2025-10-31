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

## Future UI Issues
Add additional UI issues below as they are discovered...
