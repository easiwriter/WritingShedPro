# Feature 010: Pagination - Known Issues

**Date:** November 19, 2025  
**Status:** Post-Implementation Issues

---

## Issue 1: Pinch Zoom Not Working

**Reported:** November 19, 2025  
**Status:** ⏳ Deferred for future fix  
**Priority:** Low (Button zoom controls work)

### Description

Pinch-to-zoom gesture is not responding on iOS/iPad devices. The gesture is implemented but not triggering zoom changes.

### Current Behavior
- Pinch gesture on touch devices: No response
- Button zoom controls: ✅ Working perfectly
- Mac Catalyst: N/A (pinch not available, buttons work)

### Expected Behavior
- Two-finger pinch in/out should zoom the pagination view
- Should work smoothly like Photos app or Safari
- Should complement button controls

### Technical Details

**Implementation Location:**
- File: `PaginatedDocumentView.swift`
- Lines: ~40-60 (gesture modifier)

**Current Code:**
```swift
.gesture(
    MagnificationGesture()
        .updating($magnificationAmount) { value, state, _ in
            state = value.magnitude
        }
        .onEnded { value in
            let newScale = zoomScale * value.magnitude
            withAnimation(.easeInOut(duration: 0.2)) {
                zoomScale = min(max(newScale, 0.5), 2.0)
            }
        }
)
```

### Possible Causes

1. **Gesture Conflict**: UIScrollView's pan gesture may be preventing magnification gesture
2. **Gesture Priority**: Need to adjust gesture simultaneity
3. **View Hierarchy**: VirtualPageScrollView (UIScrollView) may be capturing touches
4. **Scale Effect**: `.scaleEffect()` on UIViewRepresentable might not trigger gesture

### Investigation Needed

- [ ] Check if gesture is being recognized at all (add debug prints)
- [ ] Test gesture priority with `.simultaneousGesture()` or `.highPriorityGesture()`
- [ ] Verify UIScrollView isn't capturing all touch events
- [ ] Consider implementing zoom at UIScrollView level instead of SwiftUI level
- [ ] Test on physical device (simulator touch gestures can be unreliable)

### Workarounds

**Current Workarounds (All Working):**
- ✅ Zoom in button (+)
- ✅ Zoom out button (-)
- ✅ Reset zoom button (↻)
- ✅ 25% increments, 50%-200% range
- ✅ Fully accessible with VoiceOver

### Alternative Solutions

**Option 1: UIScrollView Built-in Zoom**
- Use UIScrollView's native `minimumZoomScale` and `maximumZoomScale`
- Implement `viewForZooming(in:)` delegate method
- Pro: Native pinch support, smooth
- Con: More complex integration with virtual scrolling

**Option 2: Gesture Recognizer in UIKit**
- Add `UIPinchGestureRecognizer` directly to `VirtualPageScrollViewImpl`
- Handle zoom at UIKit level
- Pro: Direct control, no SwiftUI gesture conflicts
- Con: Need to coordinate with SwiftUI state

**Option 3: Fix SwiftUI Gesture**
- Debug gesture recognition
- Adjust gesture priorities
- Ensure gesture can coexist with scroll
- Pro: Keeps SwiftUI approach clean
- Con: May be tricky to diagnose

### Recommended Approach

**When Fixing:**
1. Start with Option 3 (debug current implementation)
2. Add gesture recognition logging
3. Test gesture simultaneity modifiers
4. If SwiftUI approach fails, move to Option 2 (UIKit gesture)
5. Option 1 (native zoom) is most complex but most robust

**Priority:**
- Low priority since button controls work perfectly
- Doesn't block any functionality
- Nice-to-have enhancement
- Can be addressed in v1.1

### Impact Assessment

**User Impact:**
- **Low**: Button controls provide full zoom functionality
- **Accessibility**: No impact (buttons are accessible)
- **Platform**: Only affects iOS/iPad (Mac doesn't have pinch anyway)
- **Workaround**: Immediate and easy (use buttons)

**Development Impact:**
- **Effort**: 1-2 hours investigation + 2-4 hours implementation
- **Risk**: Low (existing zoom works, won't break it)
- **Testing**: Requires physical device testing
- **Complexity**: Medium (gesture coordination tricky)

---

## Resolved Issues

### Issue: Pages Positioned Incorrectly ✅ FIXED
- **Fixed:** November 19, 2025 (commits 8f7f5a7, 3300133, 66a677b)
- **Root Causes:** 
  1. Used contentRect coordinates as insets (double margins)
  2. UITextView default lineFragmentPadding (5pt)
  3. No page repositioning on bounds/layout changes
- **Solutions:**
  1. Calculate insets from pageSetup margins directly
  2. Set lineFragmentPadding = 0
  3. Override layoutSubviews() to reposition pages

---

## Testing Notes

**Pinch Zoom Testing Checklist:**
- [ ] Test on iPhone (physical device)
- [ ] Test on iPad (physical device)
- [ ] Test in simulator (may not work reliably)
- [ ] Add debug prints to gesture handlers
- [ ] Check gesture recognizer states
- [ ] Test with different zoom levels
- [ ] Test gesture + scroll interaction
- [ ] Verify no gesture conflicts

---

*Document updated: November 19, 2025*
