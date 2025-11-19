# iPhone Version Toolbar Touch Issue Fix

## Date
November 19, 2025

## Problem
Version navigator buttons (< and >) in FileEditView were unresponsive on iPhone, but working fine on Mac Catalyst. The buttons worked in earlier versions of the app but broke recently.

## Root Cause
**Z-index layering issue with formatting toolbar overlay**

The `formattingToolbar()` function has divider overlays that extend across the full width with `.ignoresSafeArea(edges: .horizontal)`. On iPhone, these overlays were rendering on top of the version toolbar and intercepting touch events before they could reach the ToolbarView buttons.

```swift
.overlay(
    VStack(spacing: 0) {
        Divider()
            .ignoresSafeArea(edges: .horizontal)  // ← Extends over version toolbar!
        Spacer()
        Divider()
            .ignoresSafeArea(edges: .horizontal)
    }
)
```

### Why Mac Worked But iPhone Didn't
- **Mac**: Mouse clicks have precise hit testing, can penetrate overlays more easily
- **iPhone**: Touch events are more sensitive to layer ordering, blocked by overlays
- **Timing**: Recent `@Bindable` change caused more frequent view updates, making the layering issue more pronounced on iPhone

## Solution
Added explicit z-index to version toolbar to ensure it renders above any overlays:

```swift
private func versionToolbar() -> some View {
    // ... toolbar configuration ...
    .padding(.horizontal, 8)
    .padding(.top, 8)
    .padding(.bottom, 8)
    .zIndex(100)  // Ensure toolbar is above any overlays
}
```

## Why It Works
- `.zIndex(100)` explicitly sets the rendering order
- Higher z-index means rendered on top
- Touch events hit the top-most view first
- Toolbar buttons now receive touches before any overlays

## Impact
- ✅ Version navigation buttons now responsive on iPhone
- ✅ Still works on Mac Catalyst
- ✅ No visual changes, just proper layering
- ✅ Touch events properly handled

## Testing
On iPhone:
1. **Open a file** with multiple versions
2. **Tap < button** - should navigate to previous version immediately
3. **Tap > button** - should navigate to next version immediately
4. **Rapid tapping** - should respond to each tap
5. **Version label** - should update correctly

On Mac:
1. **Verify** buttons still work as before
2. **Check** no visual regressions

## Related Issues
- **@Bindable change**: Made view more reactive, exposing the layering issue
- **Overlay dividers**: Formatting toolbar overlays extending too far
- **Touch vs mouse**: Different hit-testing behavior between platforms

## Technical Note
This is a common iOS/SwiftUI issue where overlays with `.ignoresSafeArea()` can extend beyond their intended bounds and intercept touches meant for other views. Always use explicit `.zIndex()` for interactive elements that might be near overlays.

The issue was exacerbated by the `@Bindable` change because it caused more frequent view updates, which made the layering conflict more apparent on iPhone's touch-sensitive UI.

## Alternative Solutions Considered
1. **Remove overlay**: Would lose visual dividers
2. **Adjust overlay bounds**: Complex, might break on different screen sizes
3. **Add zIndex (chosen)**: Simple, explicit, works across all sizes
