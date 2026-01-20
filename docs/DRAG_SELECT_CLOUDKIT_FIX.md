# Drag Select CloudKit Corruption Fix

## Problem
During shift-select (drag selection) operations, text content was being replaced by CloudKit sync events, causing visible text to disappear or become corrupted. This was not a reference-related issue but a text synchronization problem.

**Symptoms:**
- User drags to select text
- During selection, CloudKit sends sync notifications
- Text in the selection gets replaced with shorter/different content
- Visual result: Large gaps appear in the text, content vanishes

**Console Evidence:**
```
🔄 [CloudKit] Remote change notification received
🔄 [CloudKit] Remote change notification received  (during shift-select)
📝 Strings match: false                             (text content actually changed!)
📝 Attributes changed: true
📝 textViewDidChange called - text: 'Curabitur non quam finibus, facilisis ex et, laore'
```

## Root Cause
1. During a drag selection operation, `textViewDidChangeSelection` fires repeatedly
2. SwiftUI binding updates `attributedText` when CloudKit sync events occur
3. Previously we checked "only selection changed" but didn't prevent the update
4. `updateUIView()` would execute, replacing the local text with CloudKit version
5. If CloudKit had an older/different version, the visible text would change mid-selection

## Solution
Added two-layer protection in FormattedTextEditor.swift:

### Layer 1: Track Active Selection
**In `Coordinator` class init:**
```swift
var isSelectionActive = false  // Flag to prevent text updates during active selection/drag
var selectionResetTimer: Timer?  // Timer to reset selection flag after interaction ends
```

**In `textViewDidChangeSelection` method:**
```swift
// CRITICAL: Track when user is making a selection (length > 0 = drag select)
// This prevents CloudKit sync from replacing text during active drag operations
if newRange.length > 0 {
    isSelectionActive = true
    // Reset timer if already running
    selectionResetTimer?.invalidate()
    // Set timer to reset flag after selection ends (300ms debounce)
    selectionResetTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
        self?.isSelectionActive = false
    }
}
```

### Layer 2: Reject Updates During Active Selection
**In `updateUIView` method (early exit):**
```swift
// CRITICAL: Skip ALL updates if user is actively making a drag selection
// This prevents CloudKit sync from replacing text during shift-select operations
if context.coordinator.isSelectionActive {
    #if DEBUG
    print("⚠️ Selection active - SKIPPING updateUIView to prevent CloudKit corruption")
    #endif
    return
}
```

## How It Works
1. When user starts dragging (shift-click and drag), `textViewDidChangeSelection` detects `length > 0`
2. Sets `isSelectionActive = true` and starts a 300ms debounce timer
3. While selection is active, `updateUIView` is skipped entirely - NO text updates allowed
4. When mouse is released and selection ends, selection resets to `length = 0`
5. Timer continues for 300ms more to handle trailing CloudKit events
6. After timer expires, `isSelectionActive = false` and normal updates resume

## What's Protected
- ✅ Text content during drag selection - won't be replaced by CloudKit versions
- ✅ References - won't disappear due to text replacement
- ✅ User editing operations - won't be interrupted by sync events
- ✅ Formatting - preserved while selecting (no attribute updates either)

## What Still Happens
- ✅ Selection visual feedback continues working (textViewDidChangeSelection still fires)
- ✅ Typing attributes get synced for next character
- ✅ After selection ends, CloudKit updates resume normally
- ✅ No data loss - CloudKit changes are applied after selection completes

## Testing
1. Open a document with multiple paragraphs
2. Position cursor at a character position
3. Hold shift and click/drag to select multiple lines
4. Verify: Selected text remains visible and doesn't change
5. Release: Selection completes normally
6. Verify: Text remains correct (CloudKit sync resumes after 300ms)

## Related Files
- `FormattedTextEditor.swift` - Coordinator class with selection tracking
- Lines modified:
  - 691-695: Added instance variables for selection tracking
  - 1023-1037: Updated `textViewDidChangeSelection` to set flag
  - 343-357: Updated `updateUIView` to check selection flag

## Performance Impact
- Minimal: Only adds boolean check during text updates
- No new timers during normal typing/editing
- Timer only active during shift-select operations
- 300ms debounce prevents unnecessary waiting

## Notes
- This fix complements the existing "only selection changed" check that skips redundant rendering
- The 300ms debounce gives CloudKit time to finish propagating changes after selection ends
- Does not affect paste operations or other text modifications
- Preserves all undo/redo functionality
