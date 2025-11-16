# Feature Specification: TextKit 2 Migration

**Feature Branch**: `014-textkit2-migration`  
**Created**: 2025-11-16  
**Status**: Specification Phase  
**Priority**: High (Foundation for Comments Feature)

## Overview

Migrate the text editing system from TextKit 1 to TextKit 2 to future-proof the app and enable advanced text features like comments, annotations, and improved performance. TextKit 2 provides better correctness, safety, and extensibility for complex text layouts.

## Motivation

### Why Migrate Now?

1. **Foundation for Comments**: The comments feature (inspired by WWDC 2021) requires modern TextKit 2 APIs
2. **Future-Proofing**: TextKit 1 is legacy; TextKit 2 is the future of text on iOS/macOS
3. **Better Performance**: TextKit 2 has improved layout performance and memory efficiency
4. **Improved Correctness**: Better handling of complex text scenarios (emoji, RTL, attachments)
5. **Modern APIs**: Access to new features like custom text attachments with ViewProvider

### Why It's Feasible

- **Well-Isolated Code**: 90% of TextKit usage is in `FormattedTextEditor.swift` (~35 references)
- **Clean Abstraction**: UIViewRepresentable wrapper provides migration boundary
- **Standard Patterns**: Using common TextKit 1 patterns with direct TextKit 2 equivalents
- **Same Data Model**: NSAttributedString remains the storage format
- **No Breaking Changes**: External APIs (SwiftUI views, data models) remain unchanged

---

## Scope

### In Scope

- [x] Migrate `FormattedTextEditor.swift` from TextKit 1 to TextKit 2
- [x] Update text layout and rendering code
- [x] Update coordinate/position calculations
- [x] Update image attachment positioning
- [x] Update selection and cursor handling
- [x] Maintain existing formatting functionality (bold, italic, etc.)
- [x] Maintain existing image insertion/editing
- [x] Maintain RTF serialization/deserialization
- [x] Test on iOS 16+ (TextKit 2 minimum requirement)

### Out of Scope

- New features (comments, annotations) - separate feature after migration
- UI changes - visual behavior stays the same
- Data model changes - NSAttributedString storage unchanged
- Formatting capabilities - same formatting options
- iOS 15 support - TextKit 2 requires iOS 16+

---

## Technical Analysis

### Current Architecture (TextKit 1)

```
UITextView (UIViewRepresentable)
    ↓
NSLayoutManager ← Layout calculations, glyph positioning
    ↓
NSTextContainer ← Text flow, line breaking
    ↓
NSTextStorage ← NSAttributedString storage, change tracking
```

**Key Classes Used:**
- `NSLayoutManager` - 17 references
- `NSTextStorage` - 18 references
- `NSRange` - Throughout (location + length)

### Target Architecture (TextKit 2)

```
UITextView (UIViewRepresentable)
    ↓
NSTextLayoutManager ← Modern layout engine
    ↓
NSTextContentStorage ← Modern storage with tracking
    ↓
NSTextStorage ← Still used, but accessed differently
```

**Key Classes to Use:**
- `NSTextLayoutManager` - Replaces NSLayoutManager
- `NSTextContentStorage` - Wraps NSTextStorage
- `NSTextLocation` - Replaces integer locations
- `NSTextRange` - Replaces NSRange
- `NSTextLayoutFragment` - Replaces glyph ranges

---

## API Migration Map

### Storage Access

```swift
// TextKit 1
textView.textStorage.setAttributedString(attributedText)
textView.textStorage.attribute(.attachment, at: position, effectiveRange: nil)

// TextKit 2
textView.textLayoutManager.textContentManager.performEditingTransaction {
    (textStorage as? NSTextContentStorage)?.attributedString = attributedText
}
// Attribute access stays the same via textStorage
```

### Layout Operations

```swift
// TextKit 1
textView.layoutManager.ensureLayout(for: textView.textContainer)
textView.layoutManager.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)

// TextKit 2
textView.textLayoutManager.ensureLayout(for: textRange)
textView.textLayoutManager.invalidateLayout(for: textRange)
```

### Position Calculations

```swift
// TextKit 1
let glyphRange = textView.layoutManager.glyphRange(
    forCharacterRange: NSRange(location: position, length: 1),
    actualCharacterRange: nil
)
let bounds = textView.layoutManager.boundingRect(
    forGlyphRange: glyphRange,
    in: textView.textContainer
)

// TextKit 2
let location = textView.textLayoutManager.location(
    textView.textLayoutManager.documentRange.location,
    offsetBy: position
)
let textRange = NSTextRange(location: location)!
let fragment = textView.textLayoutManager.textLayoutFragment(for: location)
let bounds = fragment?.layoutFragmentFrame ?? .zero
```

### Hit Testing (Tap to Position)

```swift
// TextKit 1
let characterIndex = textView.layoutManager.characterIndex(
    for: point,
    in: textView.textContainer,
    fractionOfDistanceBetweenInsertionPoints: nil
)

// TextKit 2
let location = textView.textLayoutManager.location(
    interactingAt: point,
    inContainerAt: textView.textLayoutManager.documentRange.location
)
let offset = textView.textLayoutManager.offset(
    from: textView.textLayoutManager.documentRange.location,
    to: location
)
```

### Selection Handling

```swift
// TextKit 1
textView.selectedRange = NSRange(location: position, length: length)

// TextKit 2
// UITextView still uses selectedRange, but need to work with NSTextRange internally
let startLocation = textView.textLayoutManager.location(
    textView.textLayoutManager.documentRange.location,
    offsetBy: position
)
let endLocation = textView.textLayoutManager.location(startLocation, offsetBy: length)
let textRange = NSTextRange(location: startLocation, end: endLocation)
// textView.selectedRange still works for UITextView
```

---

## Implementation Plan

### Phase 1: Setup & Infrastructure (1-2 hours)

**Goal**: Enable TextKit 2 and verify basic text display

1. **Update iOS deployment target** (if needed)
   - TextKit 2 requires iOS 16.0+
   - Current minimum: iOS 16.0 ✅ Already compatible

2. **Enable TextKit 2 in UITextView**
   ```swift
   // In makeUIView:
   textView.layoutManager // Don't access this - triggers TextKit 1 creation
   
   // Instead, check for TextKit 2:
   if textView.textLayoutManager == nil {
       // Force TextKit 2 by not accessing layoutManager
       // Access textLayoutManager instead
   }
   ```

3. **Add helper methods for NSRange ↔ NSTextRange conversion**
   ```swift
   extension NSTextLayoutManager {
       func textRange(from nsRange: NSRange) -> NSTextRange? { }
       func nsRange(from textRange: NSTextRange) -> NSRange? { }
       func location(at offset: Int) -> NSTextLocation? { }
       func offset(of location: NSTextLocation) -> Int? { }
   }
   ```

4. **Verify basic text display**
   - Load attributed string
   - Display text correctly
   - Basic typing works

### Phase 2: Layout & Positioning (2-3 hours)

**Goal**: Replace all layoutManager calls with textLayoutManager equivalents

**Files to Update:**
- `FormattedTextEditor.swift` (~17 layoutManager references)

**Operations to Convert:**
1. `ensureLayout(for:)` → `ensureLayout(for:)`
2. `invalidateLayout(forCharacterRange:)` → `invalidateLayout(for:)`
3. `invalidateDisplay(forCharacterRange:)` → `invalidateRenderingAttributes(for:)`
4. `glyphRange(forCharacterRange:)` → Get `NSTextLayoutFragment`
5. `boundingRect(forGlyphRange:)` → `layoutFragmentFrame`
6. `characterIndex(for:in:)` → `location(interactingAt:inContainerAt:)`

**Testing After Each Change:**
- Text displays correctly
- Layout updates on content change
- No crashes or layout glitches

### Phase 3: Image Attachments (2-3 hours)

**Goal**: Fix image positioning and tap handling

**Changes Needed:**
1. Update `handleTap` to use TextKit 2 hit testing
2. Update image frame calculation in `selectImage`
3. Update image selection border positioning
4. Test image insertion
5. Test image tap selection
6. Test image editing
7. Test cursor navigation around images

**Critical Areas:**
- `handleTap(_:)` - Convert hit testing
- `selectImage(at:in:)` - Convert bounds calculation
- `recalculateSelectionBorder()` - Convert layout queries
- Image tapped callback - Update frame calculations

### Phase 4: Selection & Cursor (1-2 hours)

**Goal**: Fix selection change handling and cursor positioning

**Changes Needed:**
1. Update `textViewDidChangeSelection` for TextKit 2
2. Fix cursor navigation (forward/backward)
3. Fix zero-width space handling (image markers)
4. Fix typing attributes synchronization
5. Test selection UI (no visible changes to user)

**Edge Cases to Test:**
- Cursor before/after images
- Selection across formatted text
- Arrow key navigation
- Tap to position cursor
- Drag to select text

### Phase 5: Text Storage Updates (1-2 hours)

**Goal**: Fix text content modifications

**Changes Needed:**
1. Update `textViewDidChange` handling
2. Update `updateUIView` text storage updates
3. Use `performEditingTransaction` for modifications
4. Maintain attribute preservation
5. Test undo/redo still works

**Testing:**
- Type new text
- Delete text
- Format existing text
- Undo/redo operations
- Paste text

### Phase 6: Testing & Refinement (2-3 hours)

**Goal**: Comprehensive testing across all features

**Test Matrix:**

| Feature | Test Case | Expected Result |
|---------|-----------|-----------------|
| **Text Entry** | Type new text | Text appears correctly |
| | Type at different positions | Cursor behavior correct |
| | Type with formatting | Formatting applies |
| **Formatting** | Apply bold/italic/underline | Visual formatting correct |
| | Change paragraph style | Alignment changes |
| | Mix multiple formats | Compound formatting works |
| **Images** | Insert image | Image displays inline |
| | Tap image | Selection border appears |
| | Edit image style | Scale/alignment updates |
| | Navigate with arrows | Cursor skips image correctly |
| **Selection** | Tap to position | Cursor moves correctly |
| | Drag to select | Text highlights |
| | Select across images | Selection handles correctly |
| **Persistence** | Save and reload | Content preserved |
| | Undo/redo | Operations work |
| | Version switching | Versions load correctly |

**Devices to Test:**
- iPhone (iOS 16+)
- iPad (iOS 16+)
- Mac Catalyst (if supported)

---

## Risks & Mitigation

### Risk 1: Performance Regression
**Impact**: Medium  
**Likelihood**: Low  
**Mitigation**: 
- TextKit 2 is generally faster
- Profile before/after with large documents
- Monitor layout performance in Instruments

### Risk 2: Breaking Existing Formatting
**Impact**: High  
**Likelihood**: Low  
**Mitigation**:
- Comprehensive test suite
- Test with existing documents from production
- Validate RTF serialization unchanged

### Risk 3: Image Attachment Behavior Changes
**Impact**: Medium  
**Likelihood**: Medium  
**Mitigation**:
- NSTextAttachment still works in TextKit 2
- Test image positioning extensively
- Validate selection border rendering

### Risk 4: Hidden Edge Cases
**Impact**: Medium  
**Likelihood**: Medium  
**Mitigation**:
- Extensive manual testing
- Test with complex documents (mixed formatting, multiple images)
- Beta test with real user workflows

---

## Success Criteria

### Functional Requirements

- ✅ All existing text editing features work identically
- ✅ Bold, italic, underline, strikethrough formatting works
- ✅ Paragraph styles (alignment, heading levels) work
- ✅ Image insertion and editing works
- ✅ Image selection and navigation works
- ✅ Cursor positioning and selection works
- ✅ Undo/redo operations work
- ✅ Text persistence (save/load) works
- ✅ Version switching works
- ✅ RTF import/export works

### Performance Requirements

- ✅ No noticeable performance degradation
- ✅ Typing latency < 16ms (60fps)
- ✅ Layout updates < 100ms for typical documents
- ✅ Scrolling remains smooth

### Quality Requirements

- ✅ No crashes or exceptions
- ✅ No memory leaks
- ✅ No layout glitches
- ✅ VoiceOver accessibility maintained
- ✅ All existing unit tests pass

---

## Dependencies

### Prerequisites
- iOS 16.0+ deployment target ✅ Already set
- Xcode 14.0+ (for TextKit 2 APIs)
- Understanding of TextKit 2 architecture

### Blocking Dependencies
- None (independent feature)

### Dependent Features
- **Comments Feature**: Will build on TextKit 2 foundation
- **Advanced Annotations**: Future features requiring TextKit 2

---

## Documentation Updates

### Code Documentation
- [ ] Add inline comments explaining TextKit 2 patterns
- [ ] Document NSTextRange/NSTextLocation conversions
- [ ] Document TextKit 2 gotchas and workarounds

### Development Guidelines
- [ ] Update `.github/copilot-instructions.md` with TextKit 2 standards
- [ ] Add TextKit 2 architecture notes
- [ ] Document migration decisions

---

## Rollback Plan

**If Migration Fails:**

1. **Revert Branch**: Switch back to previous commit
2. **Branch Strategy**: Keep `main` stable, work in feature branch
3. **Testing Period**: Allow 1-2 days of testing before merging
4. **Fallback Option**: Can maintain TextKit 1 if critical issues found

**TextKit 1 Code Preservation:**
- Create `FormattedTextEditor_TextKit1.swift` backup before starting
- Keep in repo commented out for reference
- Document why migration was needed

---

## Related Resources

### Apple Documentation
- [TextKit 2 Overview](https://developer.apple.com/documentation/UIKit/textkit)
- [Using TextKit 2 to Interact with Text](https://developer.apple.com/documentation/UIKit/using-textkit-2-to-interact-with-text)
- [NSTextLayoutManager](https://developer.apple.com/documentation/uikit/nstextlayoutmanager)
- [NSTextContentStorage](https://developer.apple.com/documentation/uikit/nstextcontentstorage)

### WWDC Sessions
- **WWDC 2021**: Meet TextKit 2 (Session 10061)
- **WWDC 2022**: What's new in TextKit and text views (Session 10090)

### Key Files
- `FormattedTextEditor.swift` - Main text view wrapper (1,122 lines)
- `FileEditView.swift` - Parent view managing editor
- `AttributedStringSerializer.swift` - RTF serialization (unchanged)
- `ImageAttachment.swift` - Custom attachment (minimal changes)

---

## Timeline Estimate

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 1: Setup | 1-2 hours | 2 hours |
| Phase 2: Layout | 2-3 hours | 5 hours |
| Phase 3: Images | 2-3 hours | 8 hours |
| Phase 4: Selection | 1-2 hours | 10 hours |
| Phase 5: Storage | 1-2 hours | 12 hours |
| Phase 6: Testing | 2-3 hours | 15 hours |
| **Total** | **~15 hours** | **~2 work days** |

**Recommended Schedule:**
- Day 1: Phases 1-3 (Setup through Images)
- Day 2: Phases 4-6 (Selection through Testing)
- Day 3: Buffer for issues and refinement

---

## Next Steps

1. **Review & Approve Spec** ← Current step
2. **Create Feature Branch**: `014-textkit2-migration`
3. **Start Phase 1**: Enable TextKit 2 and verify basic display
4. **Incremental Implementation**: Complete one phase at a time with testing
5. **Final Testing**: Comprehensive test across all features
6. **Merge to Main**: After successful testing period
7. **Begin Comments Feature**: Build on TextKit 2 foundation

---

## Notes

### Why This Approach?

**Incremental Migration**: Each phase delivers working code before moving to the next. This reduces risk and allows early detection of issues.

**Testing-Focused**: Heavy emphasis on testing at each phase ensures no regressions.

**Well-Scoped**: Migration is isolated to text editing components. No ripple effects to data models, sync, or other features.

**Foundation for Future**: TextKit 2 enables modern text features (comments, annotations, collaboration) that aren't possible with TextKit 1.

### Key Decisions

1. **NSRange Compatibility**: Keep NSRange in public APIs where possible (e.g., `selectedRange` binding) for compatibility. Convert to NSTextRange internally.

2. **Storage Format**: Continue using NSAttributedString serialized to RTF. No changes to data persistence.

3. **iOS 16+ Only**: TextKit 2 requires iOS 16. Already our minimum deployment target, so no compatibility concerns.

4. **Phased Approach**: Complete migration before adding new features. Don't mix migration with feature work.
