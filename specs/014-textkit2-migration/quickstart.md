# TextKit 2 Migration - Quick Reference

**Feature**: 014-textkit2-migration  
**Status**: Ready to implement

## 🎯 Quick Start

```bash
# Create branch
git checkout -b 014-textkit2-migration

# Estimated time: ~15 hours (2 work days)
# Phases: 6 phases, each builds on previous
```

## 📋 Phase Checklist

- [ ] **Phase 1**: Setup & Infrastructure (1-2h)
- [ ] **Phase 2**: Layout & Positioning (2-3h)
- [ ] **Phase 3**: Image Attachments (2-3h)
- [ ] **Phase 4**: Selection & Cursor (1-2h)
- [ ] **Phase 5**: Text Storage (1-2h)
- [ ] **Phase 6**: Testing & Refinement (2-3h)

## 🔄 Common Conversions

### Layout Manager Access

```swift
// ❌ TextKit 1
textView.layoutManager.ensureLayout(for: textView.textContainer)

// ✅ TextKit 2
if let documentRange = textView.textLayoutManager?.documentRange {
    textView.textLayoutManager?.ensureLayout(for: documentRange)
}
```

### Bounding Rect Calculation

```swift
// ❌ TextKit 1
let glyphRange = textView.layoutManager.glyphRange(
    forCharacterRange: NSRange(location: pos, length: 1),
    actualCharacterRange: nil
)
let bounds = textView.layoutManager.boundingRect(
    forGlyphRange: glyphRange,
    in: textView.textContainer
)

// ✅ TextKit 2
var bounds = CGRect.zero
if let textLayoutManager = textView.textLayoutManager,
   let location = textLayoutManager.location(at: pos),
   let fragment = textLayoutManager.layoutFragment(at: location) {
    bounds = fragment.layoutFragmentFrame
}
```

### Hit Testing (Tap to Position)

```swift
// ❌ TextKit 1
let charIndex = textView.layoutManager.characterIndex(
    for: point,
    in: textView.textContainer,
    fractionOfDistanceBetweenInsertionPoints: nil
)

// ✅ TextKit 2
var charIndex = 0
if let textLayoutManager = textView.textLayoutManager,
   let documentRange = textLayoutManager.documentRange {
    let location = textLayoutManager.location(
        interactingAt: point,
        inContainerAt: documentRange.location
    )
    if let location = location {
        charIndex = textLayoutManager.offset(
            from: documentRange.location,
            to: location
        )
    }
}
```

### Invalidate Layout

```swift
// ❌ TextKit 1
textView.layoutManager.invalidateLayout(
    forCharacterRange: range,
    actualCharacterRange: nil
)
textView.layoutManager.invalidateDisplay(forCharacterRange: range)

// ✅ TextKit 2
if let textLayoutManager = textView.textLayoutManager,
   let textRange = textLayoutManager.textRange(from: range, in: ...) {
    textLayoutManager.invalidateLayout(for: textRange)
}
```

## 📁 Files to Modify

### Primary File
- `FormattedTextEditor.swift` (1,122 lines)
  - ~35 layoutManager/textStorage references
  - 6 phases of changes

### New File
- `TextLayoutManagerExtensions.swift`
  - Helper utilities
  - NSRange ↔ NSTextRange conversion
  - Offset ↔ NSTextLocation conversion

### No Changes Needed
- `FileEditView.swift` - Uses FormattedTextEditor, no direct TextKit
- `AttributedStringSerializer.swift` - RTF serialization unchanged
- `ImageAttachment.swift` - Attachments work in both TextKit 1 & 2
- All data models - Storage format unchanged

## 🧪 Test After Each Change

```swift
// Quick smoke test:
// 1. Open a file ✓
// 2. Type text ✓
// 3. Format text (bold) ✓
// 4. Insert image ✓
// 5. Tap image ✓
// 6. Save and reload ✓
```

## ⚠️ Common Gotchas

### 1. Layout Manager Creation
```swift
// ❌ DON'T access layoutManager - creates TextKit 1!
let layoutManager = textView.layoutManager

// ✅ DO access textLayoutManager instead
let textLayoutManager = textView.textLayoutManager
```

### 2. NSRange vs NSTextRange
```swift
// UITextView.selectedRange still uses NSRange (for backward compatibility)
// But internally need to convert to NSTextRange for layout queries

// Use helper methods:
let textRange = textLayoutManager.textRange(from: nsRange, in: ...)
```

### 3. Layout Fragment Enumeration
```swift
// TextKit 2 uses enumeration, not direct queries
textLayoutManager.enumerateTextLayoutFragments(from: location) { fragment in
    // Process fragment
    return true // Continue enumeration
}
```

### 4. Text Storage Access
```swift
// Can still access textStorage directly (for compatibility)
let attrs = textView.textStorage.attributes(at: position, effectiveRange: nil)

// But best practice for modifications:
textContentStorage.performEditingTransaction {
    // Make changes
}
```

## 🐛 Debugging Tips

### Enable TextKit 2 Logging
```swift
// In makeUIView:
print("✅ Using TextKit 2: \(textView.textLayoutManager != nil)")
print("Document range: \(textView.textLayoutManager?.documentRange)")
```

### Check Fragment Information
```swift
if let fragment = textLayoutManager.layoutFragment(at: location) {
    print("Fragment range: \(fragment.rangeInElement)")
    print("Fragment frame: \(fragment.layoutFragmentFrame)")
}
```

### Verify Layout State
```swift
textLayoutManager.enumerateTextLayoutFragments(from: nil) { fragment in
    print("Fragment at: \(fragment.layoutFragmentFrame)")
    return true
}
```

## 📊 Progress Tracking

### Phase 1: Setup ✓/✗
- [ ] Create feature branch
- [ ] Add TextLayoutManagerExtensions.swift
- [ ] Enable TextKit 2 in UITextView
- [ ] Verify basic text display
- [ ] Commit checkpoint

### Phase 2: Layout ✓/✗
- [ ] Replace ensureLayout (4 places)
- [ ] Replace invalidateLayout (2 places)
- [ ] Replace glyphRange/boundingRect (6 places)
- [ ] Replace characterIndex (1 place)
- [ ] Update configuration
- [ ] Commit checkpoint

### Phase 3: Images ✓/✗
- [ ] Update selectImage method
- [ ] Update handleTap method
- [ ] Update recalculateSelectionBorder
- [ ] Update updateUIView image handling
- [ ] Test all image operations
- [ ] Commit checkpoint

### Phase 4: Selection ✓/✗
- [ ] Verify textViewDidChangeSelection
- [ ] Test cursor navigation
- [ ] Test zero-width space handling
- [ ] Verify typing attributes
- [ ] Commit checkpoint

### Phase 5: Storage ✓/✗
- [ ] Verify textViewDidChange
- [ ] Review attribute access
- [ ] Test undo/redo
- [ ] Test persistence
- [ ] Commit checkpoint

### Phase 6: Testing ✓/✗
- [ ] Text entry tests
- [ ] Formatting tests
- [ ] Image tests
- [ ] Selection tests
- [ ] Complex document tests
- [ ] Performance tests
- [ ] Device tests
- [ ] Edge case tests
- [ ] Regression tests
- [ ] Final commit

## 🚀 Ready to Merge

### Pre-Merge Checklist
- [ ] All 6 phases complete
- [ ] All tests passed
- [ ] No compiler warnings
- [ ] No crashes
- [ ] Performance acceptable
- [ ] Documentation updated
- [ ] Copilot instructions updated

### Merge Command
```bash
git checkout main
git merge --no-ff 014-textkit2-migration
git push origin main
```

## 📚 Resources

- **Spec**: `specs/014-textkit2-migration/spec.md`
- **Plan**: `specs/014-textkit2-migration/plan.md`
- **Apple Docs**: https://developer.apple.com/documentation/uikit/nstextlayoutmanager
- **WWDC 2021**: Session 10061 - Meet TextKit 2

## 🎯 Success = Foundation for Comments

Once TextKit 2 is working, you can build:
- Comments feature (next)
- Annotations
- Collaboration
- Advanced text features

**This migration enables the future! 🚀**
