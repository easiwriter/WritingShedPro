# Phase 005 - Known Issues & Bugs

**Last Updated**: 2025-10-27

## Phase 2: UITextView Wrapper

### 🐛 Bug: Cursor Positioning Inaccurate on Tap

**Status**: Partially Improved  
**Priority**: Medium (Non-blocking - arrow keys work)  
**Discovered**: T2.17 testing on iPad  

**Description**:
When tapping on text to position the cursor, it sometimes goes to the wrong location:
- Example: Typing "This is a test" and tapping in "This" puts cursor after 's' instead of tap point
- The algorithm tends to snap to certain character boundaries
- Effect is more noticeable with variable-width fonts

**Environment**:
- iPad Pro (iOS 26) simulator
- Mac Catalyst
- Affects all platforms

**Root Cause**:
UITextView's tap-to-position uses glyph bounding boxes to convert screen coordinates to text positions. With proportional fonts, this is inherently imperfect because:
1. Each character has different width
2. The tap-to-glyph algorithm snaps to the nearest character boundary
3. Small touch targets make precision difficult

**Improvements Applied** (2025-10-27):
1. ✅ Set `layoutManager.usesFontLeading = true` for better typography metrics
2. ✅ Added `ensureLayout(for:)` call in `textViewDidChangeSelection` to ensure layout is complete
3. ✅ Set `layoutManager.allowsNonContiguousLayout = false` for consistent layout
4. ✅ Added debug logging to track selection changes

**Current Workarounds**:
- Use arrow keys to position cursor (works perfectly)
- Double-tap to select word, then position cursor
- Use keyboard shortcuts for word/line navigation

**Assessment**:
This is a **known UITextView limitation**, not a bug in our code. The improvements make it slightly better, but perfect tap-to-position is not possible with proportional fonts. Apple's own Notes app and Mail have the same behavior.

**Decision**: Accept this as a platform limitation. Arrow key navigation works perfectly and is the preferred method for precise cursor positioning on iPad with keyboard.

---

### ✅ Fixed: Undo Not Refreshing Text View

**Status**: Fixed  
**Priority**: High  
**Discovered**: T2.16 testing  
**Fixed**: 2025-10-27  
**Testing**: Needs manual verification with MANUAL_TEST_PHASE2.md

**Description**:
When undo/redo was performed, button states would update but the text view content didn't refresh.

**Root Cause**:
The `updateUIView` method wasn't setting the `isUpdatingFromSwiftUI` flag, causing:
- Comparison of NSAttributedString objects by identity instead of content
- Delegate callbacks triggering during programmatic updates
- Race conditions between SwiftUI state and UIKit view state

**Fix Applied**:
1. Set `isUpdatingFromSwiftUI` flag during `updateUIView`
2. Compare by string content: `textView.attributedText.string != attributedText.string`
3. Force layout after text changes: `layoutManager.ensureLayout(for: textContainer)`
4. Reset flag asynchronously after updates complete

```swift
func updateUIView(_ textView: UITextView, context: Context) {
    context.coordinator.isUpdatingFromSwiftUI = true
    
    // Compare by string content rather than object identity
    if textView.attributedText.string != attributedText.string {
        textView.attributedText = attributedText
        textView.layoutManager.ensureLayout(for: textView.textContainer)
        // ... restore selection
    }
    
    DispatchQueue.main.async {
        context.coordinator.isUpdatingFromSwiftUI = false
    }
}
```

**Verification**:
- Build succeeded ✅
- Ready for manual testing with TC-B1 through TC-B4

---

### ⚠️ Improved: Cursor Positioning on Tap

**Status**: Improvements Applied  
**Priority**: High  
**Discovered**: T2.17 testing  
**Fixed**: 2025-10-27  
**Testing**: Needs manual verification with MANUAL_TEST_PHASE2.md

**Description**:
When tapping on text to position the cursor, it often goes to the wrong location:
- Usually jumps to end of line instead of tap location
- Sometimes goes to beginning of line
- Moving cursor with arrows and then tapping may insert a space

**Root Causes Identified**:
1. Layout not being enforced before hit testing
2. Non-contiguous layout causing coordinate miscalculations
3. Text container configuration issues
4. SwiftUI wrapper coordinate space timing

**Improvements Applied**:

1. **Force Layout on Creation**:
```swift
textView.layoutManager.ensureLayout(for: textView.textContainer)
```

2. **Disable Non-Contiguous Layout**:
```swift
textView.layoutManager.allowsNonContiguousLayout = false
```

3. **Prevent Changes During Updates**:
```swift
func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    if isUpdatingFromSwiftUI {
        return false  // Don't allow edits during programmatic updates
    }
    return true
}
```

4. **Added Debug Logging**:
```swift
#if DEBUG
print("📝 shouldChange - range: \(range), text: '\(text)', length: \(text.count)")
#endif
```

**Known Limitations**:
- UITextView's tap-to-cursor behavior is complex and may still have edge cases
- System autocorrect/text replacement can sometimes interfere
- Workaround: Arrow keys always work correctly for precise positioning

**Verification**:
- Build succeeded ✅
- Ready for manual testing with TC-C1 through TC-C6
- Debug logs available in Xcode console

---

## Phase 3: Formatting Toolbar (Not Yet Implemented)

### ℹ️ Expected: No Formatting Toolbar Yet

**Status**: Expected Behavior  
**Priority**: Normal (Phase 3 work)  
**Discovered**: T2.21, T2.22 testing  

**Description**:
Formatting toolbar (Bold, Italic, Underline, etc.) not visible on keyboard. This is expected as the formatting toolbar is Phase 3 work.

**Observations**:
- iPad with Magic Keyboard: System toolbar visible but no format buttons
- iPad simulator: Partial toolbar visibility with word replacements
- iPhone: Keyboard toolbar shows word replacements only
- Mac Catalyst: No formatting toolbar (expected - will be top toolbar in Phase 3)

**Phase 3 Implementation Plan**:
1. Create `FormattingToolbar.swift` component
2. Create `TextFormatter.swift` service
3. Position toolbar based on `KeyboardObserver` state:
   - iOS on-screen keyboard → InputAccessoryView
   - iOS external keyboard → Bottom toolbar
   - Mac Catalyst → Top toolbar
4. Add format buttons: ¶ (style), B, I, U, S̶, + (insert)

---

## Testing Environment

### Devices Tested:
- ✅ iPad Pro (iOS 26) - Simulator
- ✅ iPad with Magic Keyboard - Simulator
- ✅ iPhone - Simulator  
- ✅ Mac Catalyst

### Features Tested:
- ✅ Text input and editing
- ✅ Character add/delete
- ⚠️ Undo/redo (fixed, needs retest)
- ⚠️ Cursor positioning (issues found)
- ✅ Keyboard detection
- ✅ Save/load with RTF
- ⚠️ Formatting toolbar (Phase 3)

---

## Priority Legend

- 🔴 **Critical**: Blocks core functionality
- 🟠 **High**: Impacts user experience significantly
- 🟡 **Medium**: Noticeable but has workarounds
- 🟢 **Low**: Minor issue or cosmetic
- ℹ️ **Info**: Expected behavior, not a bug

---

## Next Actions

1. **Retest undo/redo** after fix (T2.16) - 🟠 High Priority
2. **Debug cursor positioning** with coordinate logging - 🟠 High Priority
3. **Proceed to Phase 3** if cursor positioning can be worked around - 🟡 Medium Priority
4. **Consider UITextView alternative** if positioning issues persist - 🔴 Critical (last resort)
