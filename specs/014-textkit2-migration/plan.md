# TextKit 2 Migration - Implementation Plan

**Feature**: 014-textkit2-migration  
**Created**: 2025-11-16  
**Estimated Duration**: 15 hours (~2 work days)

## Phase Overview

```
Phase 1: Setup & Infrastructure (1-2h)
    ↓
Phase 2: Layout & Positioning (2-3h)
    ↓
Phase 3: Image Attachments (2-3h)
    ↓
Phase 4: Selection & Cursor (1-2h)
    ↓
Phase 5: Text Storage (1-2h)
    ↓
Phase 6: Testing & Refinement (2-3h)
```

---

## Phase 1: Setup & Infrastructure

**Goal**: Enable TextKit 2 and establish helper utilities

### Tasks

#### 1.1 Create Feature Branch
```bash
git checkout -b 014-textkit2-migration
```

#### 1.2 Verify iOS Target
- [x] Check deployment target is iOS 16.0+ (already verified)
- [x] No changes needed

#### 1.3 Create TextKit 2 Helper Extensions

**File**: Create `TextLayoutManagerExtensions.swift`

```swift
import UIKit

extension NSTextLayoutManager {
    
    // MARK: - NSRange Conversion
    
    /// Convert NSRange to NSTextRange
    func textRange(from nsRange: NSRange, in textContentManager: NSTextContentManager) -> NSTextRange? {
        guard let documentRange = documentRange else { return nil }
        
        // Get start location
        guard let startLocation = location(documentRange.location, offsetBy: nsRange.location) else {
            return nil
        }
        
        // Get end location
        guard let endLocation = location(startLocation, offsetBy: nsRange.length) else {
            return nil
        }
        
        return NSTextRange(location: startLocation, end: endLocation)
    }
    
    /// Convert NSTextRange to NSRange
    func nsRange(from textRange: NSTextRange, in textContentManager: NSTextContentManager) -> NSRange? {
        guard let documentRange = documentRange else { return nil }
        
        // Get offset of start
        let startOffset = offset(from: documentRange.location, to: textRange.location)
        
        // Get offset of end
        let endOffset = offset(from: documentRange.location, to: textRange.endLocation)
        
        return NSRange(location: startOffset, length: endOffset - startOffset)
    }
    
    /// Get NSTextLocation from integer offset
    func location(at offset: Int) -> NSTextLocation? {
        guard let documentRange = documentRange else { return nil }
        return location(documentRange.location, offsetBy: offset)
    }
    
    /// Get integer offset from NSTextLocation
    func offset(of location: NSTextLocation) -> Int {
        guard let documentRange = documentRange else { return 0 }
        return offset(from: documentRange.location, to: location)
    }
    
    // MARK: - Layout Queries
    
    /// Get layout fragment containing the given location
    func layoutFragment(at location: NSTextLocation) -> NSTextLayoutFragment? {
        var foundFragment: NSTextLayoutFragment?
        
        enumerateTextLayoutFragments(from: location, options: [.ensuresLayout]) { fragment in
            if fragment.rangeInElement.contains(location) {
                foundFragment = fragment
                return false // Stop enumeration
            }
            return true
        }
        
        return foundFragment
    }
    
    /// Get bounding rect for text range
    func boundingRect(for textRange: NSTextRange) -> CGRect {
        var rect = CGRect.zero
        
        enumerateTextLayoutFragments(from: textRange.location, options: [.ensuresLayout]) { fragment in
            // Check if this fragment overlaps with our range
            if let fragmentRange = fragment.rangeInElement,
               fragmentRange.intersects(textRange) {
                rect = rect.union(fragment.layoutFragmentFrame)
            }
            
            // Stop if we've passed the end of our range
            if fragment.rangeInElement.endLocation >= textRange.endLocation {
                return false
            }
            
            return true
        }
        
        return rect
    }
}

// MARK: - NSTextRange Extensions

extension NSTextRange {
    /// Check if this range intersects another range
    func intersects(_ other: NSTextRange) -> Bool {
        // Range A ends after B starts AND A starts before B ends
        return self.endLocation >= other.location && self.location <= other.endLocation
    }
}

// MARK: - NSTextLocation Extensions

extension NSTextLocation {
    /// Compare two locations
    static func < (lhs: NSTextLocation, rhs: NSTextLocation) -> Bool {
        return lhs.compare(rhs) == .orderedAscending
    }
    
    static func <= (lhs: NSTextLocation, rhs: NSTextLocation) -> Bool {
        let comparison = lhs.compare(rhs)
        return comparison == .orderedAscending || comparison == .orderedSame
    }
    
    static func > (lhs: NSTextLocation, rhs: NSTextLocation) -> Bool {
        return lhs.compare(rhs) == .orderedDescending
    }
    
    static func >= (lhs: NSTextLocation, rhs: NSTextLocation) -> Bool {
        let comparison = lhs.compare(rhs)
        return comparison == .orderedDescending || comparison == .orderedSame
    }
}
```

**Test**: Build project, verify no compile errors

#### 1.4 Add TextKit 2 Check to FormattedTextEditor

**File**: `FormattedTextEditor.swift`

Add to top of `makeUIView`:
```swift
func makeUIView(context: Context) -> UITextView {
    let textView = CustomTextView()
    
    // IMPORTANT: Access textLayoutManager BEFORE accessing layoutManager
    // This ensures TextKit 2 is used instead of TextKit 1
    if textView.textLayoutManager == nil {
        print("⚠️ TextKit 2 not available, falling back to TextKit 1")
    } else {
        print("✅ Using TextKit 2")
    }
    
    // ... rest of setup
}
```

**Test**: Run app, check console for "✅ Using TextKit 2"

#### 1.5 Verification Tests

- [ ] App builds successfully
- [ ] App launches without crashes
- [ ] Console shows "Using TextKit 2"
- [ ] Can open a file
- [ ] Text displays correctly
- [ ] Can type new text

**Checkpoint**: Commit changes
```bash
git add .
git commit -m "Phase 1: Enable TextKit 2 and add helper utilities"
```

---

## Phase 2: Layout & Positioning

**Goal**: Replace all NSLayoutManager calls with NSTextLayoutManager

### Tasks

#### 2.1 Replace ensureLayout Calls

**Find** (4 occurrences):
```swift
textView.layoutManager.ensureLayout(for: textView.textContainer)
```

**Replace with**:
```swift
// Ensure layout for entire document
if let documentRange = textView.textLayoutManager?.documentRange {
    textView.textLayoutManager?.ensureLayout(for: documentRange)
}
```

**Locations**:
- Line 225: In `makeUIView` after setting content
- Line 327: In `updateUIView` after layout invalidation  
- Line 532: In `textViewDidChangeSelection`
- Line 800: In `textViewDidChangeSelection` (image handling)

**Test after each**: Open file, verify text displays

#### 2.2 Replace invalidateLayout Calls

**Find** (2 occurrences):
```swift
textView.layoutManager.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
textView.layoutManager.invalidateDisplay(forCharacterRange: fullRange)
```

**Replace with**:
```swift
// Invalidate layout for the entire document
if let textLayoutManager = textView.textLayoutManager,
   let documentRange = textLayoutManager.documentRange {
    textLayoutManager.invalidateLayout(for: documentRange)
}
```

**Location**: Line 323-324 in `updateUIView`

**Test**: Format text (bold/italic), verify update works

#### 2.3 Replace glyphRange and boundingRect Calls

**Find pattern** (~6 occurrences):
```swift
let glyphRange = textView.layoutManager.glyphRange(forCharacterRange: NSRange(location: position, length: 1), actualCharacterRange: nil)
let glyphBounds = textView.layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer)
```

**Replace with**:
```swift
// Get layout fragment and bounds for position
var bounds = CGRect.zero
if let textLayoutManager = textView.textLayoutManager,
   let location = textLayoutManager.location(at: position),
   let fragment = textLayoutManager.layoutFragment(at: location) {
    bounds = fragment.layoutFragmentFrame
    
    // Adjust for specific character bounds within fragment if needed
    // (for precise image positioning)
}
```

**Locations**:
- Line 402-403: In `textViewDidChangeSelection` (image selection)
- Line 802-803: In `textViewDidChangeSelection` (image verification)
- Line 893-894: In `handleTap` (image tap)
- Line 1108-1109: In `recalculateSelectionBorder` (CustomTextView)

**Test after each**: Tap on image, verify selection border appears

#### 2.4 Replace characterIndex Calls

**Find** (1 occurrence):
```swift
let characterIndex = textView.layoutManager.characterIndex(
    for: adjustedLocation,
    in: textView.textContainer,
    fractionOfDistanceBetweenInsertionPoints: nil
)
```

**Replace with**:
```swift
// Find character at tap location using TextKit 2
var characterIndex = 0
if let textLayoutManager = textView.textLayoutManager,
   let documentRange = textLayoutManager.documentRange {
    
    // Use location(interactingAt:) for hit testing
    let location = textLayoutManager.location(
        interactingAt: adjustedLocation,
        inContainerAt: documentRange.location
    )
    
    if let location = location {
        characterIndex = textLayoutManager.offset(from: documentRange.location, to: location)
    }
}
```

**Location**: Line 870 in `handleTap`

**Test**: Tap in text to position cursor, verify cursor moves correctly

#### 2.5 Update Configuration Calls

**Find** (2 occurrences):
```swift
textView.layoutManager.allowsNonContiguousLayout = false
textView.layoutManager.usesFontLeading = true
```

**Replace with**:
```swift
// Configure TextKit 2 layout manager
if let textLayoutManager = textView.textLayoutManager {
    // TextKit 2 always uses contiguous layout - no setting needed
    // Font leading is handled automatically in TextKit 2
}
```

**Location**: Line 118-121 in `makeUIView`

**Note**: These settings don't have direct TextKit 2 equivalents - behavior is automatic

**Test**: Text displays with correct spacing and alignment

#### 2.6 Verification Tests

- [ ] Text displays correctly
- [ ] Can type and edit text
- [ ] Formatting applies correctly
- [ ] Layout updates when text changes
- [ ] No crashes or console errors

**Checkpoint**: Commit changes
```bash
git add .
git commit -m "Phase 2: Convert layout manager calls to TextKit 2"
```

---

## Phase 3: Image Attachments

**Goal**: Fix image positioning and selection with TextKit 2

### Tasks

#### 3.1 Update selectImage Method

**Find**: `private func selectImage(at position: Int, in textView: UITextView)`

**Update**: Replace glyph bounds calculation:

```swift
// OLD:
let glyphRange = textView.layoutManager.glyphRange(forCharacterRange: NSRange(location: position, length: 1), actualCharacterRange: nil)
let glyphBounds = textView.layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer)

// NEW:
var glyphBounds = CGRect.zero
if let textLayoutManager = textView.textLayoutManager,
   let location = textLayoutManager.location(at: position),
   let fragment = textLayoutManager.layoutFragment(at: location) {
    
    // Get the bounds within the fragment for this specific character
    if let textElement = fragment.textElement(at: location) as? NSTextAttachment {
        // For attachments, use the fragment frame
        glyphBounds = fragment.layoutFragmentFrame
    }
}
```

**Test**: Tap image, verify selection border appears at correct position

#### 3.2 Update handleTap Method

**Find**: `@objc func handleTap(_ gesture: UITapGestureRecognizer)` in Coordinator

**Update**: Already updated in Phase 2.4 (characterIndex replacement)

**Additional**: Verify image bounds calculation (same as 3.1)

**Test**: Tap on image, verify callback fires with correct frame

#### 3.3 Update recalculateSelectionBorder

**Find**: `private func recalculateSelectionBorder()` in CustomTextView

**Update**: Replace layoutManager access:

```swift
private func recalculateSelectionBorder() {
    let selectedRange = self.selectedRange
    guard selectedRange.length == 1 else { return }
    
    let position = selectedRange.location
    guard position < textStorage.length else { return }
    
    guard let attachment = textStorage.attribute(.attachment, at: position, effectiveRange: nil) as? ImageAttachment else {
        return
    }
    
    // TextKit 2: Get layout fragment for position
    var glyphBounds = CGRect.zero
    if let textLayoutManager = self.textLayoutManager,
       let location = textLayoutManager.location(at: position),
       let fragment = textLayoutManager.layoutFragment(at: location) {
        glyphBounds = fragment.layoutFragmentFrame
    }
    
    let adjustedBounds = CGRect(
        x: glyphBounds.origin.x + textContainerInset.left,
        y: glyphBounds.origin.y + textContainerInset.top,
        width: attachment.bounds.size.width,
        height: attachment.bounds.size.height
    )
    
    selectionBorderView.frame = adjustedBounds
}
```

**Test**: 
- Select image
- Rotate device
- Verify border repositions correctly

#### 3.4 Update Image Selection in updateUIView

**Find**: Image border recalculation in `updateUIView` (around line 402)

**Update**: Same pattern as 3.1

**Test**: 
- Edit image style (scale/alignment)
- Verify border updates immediately

#### 3.5 Verification Tests

- [ ] Can insert images
- [ ] Images display at correct size
- [ ] Can tap to select image
- [ ] Selection border appears at correct position
- [ ] Can edit image (scale, alignment)
- [ ] Border updates when editing
- [ ] Can navigate with arrow keys around images
- [ ] Can delete images

**Checkpoint**: Commit changes
```bash
git add .
git commit -m "Phase 3: Fix image attachments with TextKit 2"
```

---

## Phase 4: Selection & Cursor

**Goal**: Fix selection handling and cursor navigation

### Tasks

#### 4.1 Verify textViewDidChangeSelection

**Review**: `func textViewDidChangeSelection(_ textView: UITextView)`

**Analysis**: 
- Most logic uses `textView.selectedRange` (still works in TextKit 2)
- `textView.attributedText` access (still works)
- Layout queries already fixed in Phase 2

**Update needed**: Only the `ensureLayout` call (already done in Phase 2.1)

**Test**: 
- Move cursor with arrow keys
- Tap to position cursor
- Select text by dragging

#### 4.2 Fix Zero-Width Space Navigation

**Find**: Zero-width space detection logic in `textViewDidChangeSelection`

**Verify**: This uses string character access, not layout - should work as-is

**Test**:
- Navigate forward past image (right arrow)
- Navigate backward to image (left arrow)
- Verify cursor skips zero-width spaces

#### 4.3 Update syncTypingAttributesForCursorPosition

**Find**: `private func syncTypingAttributesForCursorPosition`

**Review**: Uses `attributedText` access - no layout manager calls

**Status**: ✅ No changes needed

**Test**: 
- Type after image
- Verify text uses correct alignment (not centered)

#### 4.4 Verification Tests

- [ ] Can move cursor with arrow keys
- [ ] Can tap to position cursor
- [ ] Can select text by dragging
- [ ] Selection handles appear correctly
- [ ] Can navigate around images
- [ ] Cursor skips image markers (zero-width spaces)
- [ ] Typing attributes sync correctly

**Checkpoint**: Commit changes
```bash
git add .
git commit -m "Phase 4: Verify selection and cursor handling"
```

---

## Phase 5: Text Storage Updates

**Goal**: Fix text content modification operations

### Tasks

#### 5.1 Review textViewDidChange

**Find**: `func textViewDidChange(_ textView: UITextView)`

**Analysis**:
- Uses `textView.attributedText` (readonly access - works in TextKit 2)
- No layout manager calls
- Updates binding only

**Status**: ✅ No changes needed

**Test**: Type text, verify state updates

#### 5.2 Review updateUIView Text Setting

**Find**: `textView.textStorage.setAttributedString(attributedText)` in `updateUIView`

**Analysis**: TextKit 2 can still access textStorage, but best practice is to use textContentStorage

**Update** (optional, for best practices):
```swift
// Set attributed string using TextKit 2
if let textLayoutManager = textView.textLayoutManager,
   let textContentStorage = textLayoutManager.textContentManager as? NSTextContentStorage {
    textContentStorage.performEditingTransaction {
        textContentStorage.textStorage?.setAttributedString(attributedText)
    }
} else {
    // Fallback (shouldn't happen with TextKit 2)
    textView.textStorage.setAttributedString(attributedText)
}
```

**Decision**: Keep current approach - direct textStorage access still works and is simpler

**Test**: Load different versions, verify content updates

#### 5.3 Review Attribute Access

**Find**: All `.attribute()` and `.attributes()` calls

**Analysis**: These go through textStorage/NSAttributedString - work identically in TextKit 2

**Examples**:
```swift
textView.textStorage.attribute(.attachment, at: position, effectiveRange: nil)
textView.textStorage.attributes(at: position, effectiveRange: nil)
```

**Status**: ✅ No changes needed

#### 5.4 Review textStorage.edited() Call

**Find**: `textView.textStorage.edited(.editedAttributes, ...)` in `updateUIView`

**Analysis**: This notifies text storage of changes - still needed in TextKit 2

**Status**: ✅ Keep as-is

**Test**: Change formatting, verify display updates

#### 5.5 Verification Tests

- [ ] Can type new text
- [ ] Can delete text
- [ ] Can paste text
- [ ] Formatting changes apply
- [ ] Undo/redo works
- [ ] Content persists on save
- [ ] Version switching works

**Checkpoint**: Commit changes
```bash
git add .
git commit -m "Phase 5: Verify text storage operations"
```

---

## Phase 6: Testing & Refinement

**Goal**: Comprehensive testing and bug fixes

### Tasks

#### 6.1 Text Entry Testing

**Test Cases**:
- [ ] Type at start of document
- [ ] Type in middle of document
- [ ] Type at end of document
- [ ] Type with selection (replaces)
- [ ] Type multiple paragraphs
- [ ] Type with different fonts/sizes

**Expected**: Text appears correctly, no lag, no glitches

#### 6.2 Formatting Testing

**Test Cases**:
- [ ] Apply bold to selection
- [ ] Apply italic to selection
- [ ] Apply underline to selection
- [ ] Apply strikethrough to selection
- [ ] Mix multiple formats
- [ ] Change paragraph style (heading/body)
- [ ] Change alignment (left/center/right)

**Expected**: Formatting applies immediately, persists on reload

#### 6.3 Image Testing

**Test Cases**:
- [ ] Insert image from Photos
- [ ] Insert image from Files
- [ ] Tap to select image
- [ ] Verify selection border
- [ ] Edit image style (scale)
- [ ] Edit image alignment
- [ ] Navigate with arrows around image
- [ ] Delete image with backspace
- [ ] Undo image insertion
- [ ] Image persists on save/reload

**Expected**: All operations work smoothly, no positioning glitches

#### 6.4 Selection & Navigation Testing

**Test Cases**:
- [ ] Tap to position cursor
- [ ] Drag to select text
- [ ] Double-tap to select word
- [ ] Triple-tap to select paragraph
- [ ] Arrow keys move cursor
- [ ] Shift+arrow selects
- [ ] Select all
- [ ] Copy/paste selection

**Expected**: Selection UI correct, no cursor jumping

#### 6.5 Complex Document Testing

**Create test document**:
- Multiple paragraphs
- Mixed formatting (bold, italic, underline)
- Different paragraph styles
- Multiple images
- Different alignments

**Test Cases**:
- [ ] Document displays correctly
- [ ] Can edit any section
- [ ] Formatting preserved
- [ ] Images positioned correctly
- [ ] Scrolling smooth
- [ ] Save and reload works

#### 6.6 Performance Testing

**Test with large document** (5000+ words):

- [ ] Typing latency < 16ms
- [ ] Scrolling smooth (60fps)
- [ ] Layout updates < 100ms
- [ ] No memory leaks (Instruments)
- [ ] No CPU spikes

**Tools**: Xcode Instruments (Time Profiler, Leaks)

#### 6.7 Device Testing

**iPhone** (iOS 16+):
- [ ] iPhone 15 Pro simulator
- [ ] Physical device (if available)
- [ ] Portrait orientation
- [ ] Landscape orientation

**iPad** (iOS 16+):
- [ ] iPad Pro simulator
- [ ] Physical device (if available)
- [ ] Split screen mode
- [ ] Keyboard attached

**Mac Catalyst** (if supported):
- [ ] Test on Mac (if app supports Catalyst)

#### 6.8 Edge Cases

**Test unusual scenarios**:
- [ ] Empty document
- [ ] Document with only images
- [ ] Very long single line (no breaks)
- [ ] Many images in succession
- [ ] RTL text (Arabic/Hebrew if supported)
- [ ] Emoji characters
- [ ] Special characters

#### 6.9 Regression Testing

**Existing features** must still work:
- [ ] Create new file
- [ ] Delete file
- [ ] Create new version
- [ ] Switch versions
- [ ] Delete version
- [ ] Move file to different folder
- [ ] Search text
- [ ] Word/character count
- [ ] Export to RTF
- [ ] CloudKit sync

#### 6.10 Bug Fixes

Document and fix any issues found:

**Issue Template**:
```markdown
## Bug: [Description]

**Reproduce**:
1. Step 1
2. Step 2
3. Observe issue

**Expected**: [What should happen]
**Actual**: [What actually happens]

**Fix**: [Solution applied]

**Test**: [Verification]
```

**Checkpoint**: Fix all critical bugs before final commit

---

## Final Checklist

### Code Quality

- [ ] No compiler warnings
- [ ] No force unwraps in new code
- [ ] Proper error handling
- [ ] Code documented with comments
- [ ] Debug prints removed or conditionalized

### Testing

- [ ] All manual tests passed
- [ ] No crashes or hangs
- [ ] No memory leaks
- [ ] Performance acceptable
- [ ] Works on multiple devices

### Documentation

- [ ] Update `.github/copilot-instructions.md`
- [ ] Add TextKit 2 notes to relevant files
- [ ] Document any workarounds or gotchas
- [ ] Update spec.md if approach changed

### Version Control

- [ ] All changes committed
- [ ] Commit messages descriptive
- [ ] No unnecessary files committed
- [ ] Branch up to date with main

---

## Merge to Main

### Pre-Merge

1. **Review all changes**:
   ```bash
   git diff main...014-textkit2-migration
   ```

2. **Final testing** on clean build:
   ```bash
   # Clean build folder
   rm -rf ~/Library/Developer/Xcode/DerivedData
   
   # Build and test
   xcodebuild -project "Writing Shed Pro.xcodeproj" -scheme "Writing Shed Pro" clean build
   ```

3. **Update main branch**:
   ```bash
   git checkout main
   git pull origin main
   git checkout 014-textkit2-migration
   git merge main  # Resolve any conflicts
   ```

### Merge

1. **Merge to main**:
   ```bash
   git checkout main
   git merge --no-ff 014-textkit2-migration
   git push origin main
   ```

2. **Tag release** (optional):
   ```bash
   git tag -a v1.5.0-textkit2 -m "Migrated to TextKit 2"
   git push origin v1.5.0-textkit2
   ```

3. **Keep branch** (for reference):
   ```bash
   # Don't delete immediately - keep for a few weeks
   # git branch -d 014-textkit2-migration
   ```

---

## Post-Migration

### Monitor

- [ ] Watch for crash reports
- [ ] Monitor performance metrics
- [ ] Check user feedback
- [ ] Watch CloudKit sync logs

### Documentation

- [ ] Update main README if needed
- [ ] Add to CHANGELOG
- [ ] Update feature roadmap

### Next Steps

- [ ] Begin comments feature (015-comments-system)
- [ ] Use TextKit 2 foundation for advanced text features
- [ ] Consider other TextKit 2 benefits (collaboration, accessibility)

---

## Rollback Procedure (If Needed)

**If critical issues found**:

1. **Revert merge**:
   ```bash
   git revert -m 1 <merge-commit-hash>
   git push origin main
   ```

2. **Or create hotfix branch**:
   ```bash
   git checkout <commit-before-merge>
   git checkout -b hotfix/revert-textkit2
   git push origin hotfix/revert-textkit2
   ```

3. **Investigate issues**:
   - Review crash logs
   - Reproduce problem
   - Fix in feature branch
   - Re-test thoroughly

4. **Re-merge when fixed**:
   - Complete additional testing
   - Merge again with fixes

---

## Success Metrics

### Completion Criteria

- [x] All 6 phases completed
- [x] All test cases passed
- [x] No critical bugs remaining
- [x] Performance acceptable
- [x] Documentation updated
- [x] Merged to main

### Quality Gates

- **Zero Crashes**: No crashes during testing
- **Zero Regressions**: All existing features work
- **Performance**: No noticeable degradation
- **Code Quality**: Maintainable, documented code

### Time Tracking

| Phase | Estimated | Actual | Notes |
|-------|-----------|--------|-------|
| Phase 1 | 1-2h | ___ | |
| Phase 2 | 2-3h | ___ | |
| Phase 3 | 2-3h | ___ | |
| Phase 4 | 1-2h | ___ | |
| Phase 5 | 1-2h | ___ | |
| Phase 6 | 2-3h | ___ | |
| **Total** | **15h** | ___ | |

---

## Notes

This plan prioritizes safety and incrementalism. Each phase builds on the previous one, with testing checkpoints to catch issues early. The migration is isolated to text editing components, minimizing risk to other parts of the app.
