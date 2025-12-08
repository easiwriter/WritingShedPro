# Context Menu Customization Issue

**Date:** 8 December 2025  
**Status:** 🔴 Not Working - Needs Fix  
**Priority:** Medium

## Problem

The text editor context menu (long-press menu) is not properly filtering items. Despite multiple attempts to customize it, unwanted items still appear.

### Current Behavior
The context menu shows:
- ✅ Cut
- ✅ Copy  
- ✅ Paste
- ❌ Search With Google
- ❌ Share...
- ❌ Spelling and Grammar
- ❌ Substitutions
- ❌ Transformations
- ❌ Speech
- ❌ AutoFill
- ❌ Services

### Desired Behavior
The context menu should **only** show:
1. Look Up (first)
2. Cut
3. Copy
4. Paste

## Attempted Solutions

### 1. `canPerformAction` Override
**File:** `FormattedTextEditor.swift` (line ~1240)
- Attempted to block unwanted actions by returning `false`
- **Result:** Only partially effective, some system menus still appear

### 2. `editMenu(for:suggestedActions:)` Override (iOS 16+)
**File:** `FormattedTextEditor.swift` (line ~1273)
- Recursively extracts actions from menu hierarchy
- Filters to allowed titles
- **Result:** Still showing unwanted items

### 3. `buildMenu(with:)` Override
- Attempted to remove system menus
- **Result:** Affects app menu bar, not context menu

## Technical Challenges

1. iOS provides edit menu items as nested `UIMenu` structures, not flat `UIAction` arrays
2. Some system menus (Search, Share, Services) appear to bypass standard filtering
3. Different iOS versions may handle context menus differently
4. Mac Catalyst may have additional menu handling

## Possible Solutions to Try

1. **Use UIEditMenuInteraction API directly** - Replace the default text interaction with custom edit menu interaction
2. **Override `buildMenuWithBuilder` more aggressively** - Try removing more system menu identifiers
3. **Disable system text interaction** - Use custom gesture recognizers instead
4. **Check for Mac Catalyst-specific menu handling** - May need `#if targetEnvironment(macCatalyst)` conditionals
5. **Research UITextViewDelegate methods** - May be other hooks for menu customization

## Files Involved

- `WrtingShedPro/Writing Shed Pro/Views/Components/FormattedTextEditor.swift`
  - Lines 1240-1270: `canPerformAction` override
  - Lines 1273-1305: `editMenu` override
  - Lines 1307-1315: `buildMenu` override

## Notes

- Cut, Copy, Paste are working correctly
- Look Up is missing despite being in the allowed list
- System service menus (Search, Share, Services) are the hardest to remove
- This is a UI polish issue, not a functional blocker

## References

- [Apple Documentation: UIResponder canPerformAction](https://developer.apple.com/documentation/uikit/uiresponder/1621105-canperformaction)
- [Apple Documentation: UITextView editMenu](https://developer.apple.com/documentation/uikit/uitextview/3975944-editmenu)
- [Apple Documentation: UIEditMenuConfiguration](https://developer.apple.com/documentation/uikit/uieditmenuinteraction)

---

**To fix this issue in the future:** Search for "CONTEXT MENU ISSUE" in the codebase to find related code sections.
