# File Open Performance Fix - Toolbar Blur Resolution

**Date:** 2026-01-28  
**Issue:** Toolbar blur/stutter when opening files in FileEditView

## Problem

When navigating to FileEditView, the toolbar would appear blurry during the navigation animation. This was caused by synchronous work blocking the main thread during the iOS navigation animation (which uses Core Animation on the main thread).

## Root Causes Identified

1. **Synchronous work during navigation animation** (~26ms blocking main thread)
   - `performFullSetup()` loading content from database
   - `FormattedTextEditor.makeUIView` creating the text view
   - `updateUIView` applying content to the text view

2. **Unnecessary `reapplyAllStyles()` on every file open**
   - Was changing font from `TimesNewRomanPSMT` to `.SFNS-Regular` 400ms after navigation
   - Caused visible font flash/blur after content appeared

## Solution

### 1. Defer all setup work until after navigation animation completes

Changed `setupOnAppear()` to use `CATransaction.setCompletionBlock`:

```swift
private func setupOnAppear() {
    let appearTime = CFAbsoluteTimeGetCurrent()
    viewAppearTime = appearTime
    
    // PERFORMANCE: Delay ALL work until after navigation animation completes (~350ms)
    // iOS navigation uses Core Animation which runs on main thread - any work we do
    // during the animation blocks it and causes visible blur/stutter.
    CATransaction.begin()
    CATransaction.setCompletionBlock {
        self.performFullSetup()
    }
    CATransaction.commit()
}
```

### 2. Removed redundant `reapplyAllStyles()` on file open

The content loaded from database already has correct styles applied. Calling `reapplyAllStyles()` on every file open was:
- Unnecessary (styles already correct)
- Causing visible font changes 400ms after navigation
- Taking ~30ms of extra work

`reapplyAllStyles()` is still called when actually needed:
- When user clicks "Apply to All" in StylePickerSheet
- When `ProjectStyleSheetChanged` notification is received
- When `StyleSheetModified` notification is received

## Tradeoffs

| Before | After |
|--------|-------|
| Blurry navigation animation | Smooth navigation animation |
| Content visible immediately (but blurry) | Content appears ~300ms after navigation |
| ~26ms blocking main thread | 0ms blocking during animation |

## Performance Metrics

After fix:
- `performFullSetup`: 6.8ms (runs after animation)
- `updateUIView`: 8.7ms
- Navigation animation: Smooth, no blur

## Files Modified

- `WrtingShedPro/Writing Shed Pro/Views/FileEditView.swift`
  - `setupOnAppear()`: Added CATransaction deferral
  - Removed deferred `reapplyAllStyles()` call on file open

## Future Optimization Opportunities

1. **Pre-fetch content** when file list appears (before user taps)
2. **Show skeleton/placeholder** during the 300ms loading delay
3. **Reduce redundant view rebuilds** from CloudKit notifications (15+ `FileEditView.init()` calls per file open)

## Related

- Commit 6986253: Original fix that switched to native iOS back button
- `hasLoadedContent` flag: Defers toolbar computation until content loads
