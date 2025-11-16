# TextKit 2 Migration - Complete Specification

**Created**: 2025-11-16  
**Status**: ✅ Specification Phase Complete - Ready to Implement

## 📦 What's Been Created

### Documentation Files

1. **`spec.md`** - Comprehensive feature specification (600+ lines)
   - Overview and motivation
   - Technical analysis (TextKit 1 vs TextKit 2)
   - API migration map
   - 6-phase implementation plan
   - Risk assessment
   - Success criteria
   - Timeline estimates (~15 hours)

2. **`plan.md`** - Detailed implementation plan (900+ lines)
   - Phase-by-phase task breakdown
   - Code examples for each conversion
   - Testing checklists for each phase
   - Verification procedures
   - Commit checkpoints
   - Merge procedures
   - Rollback plan

3. **`quickstart.md`** - Quick reference guide (300+ lines)
   - Common conversion patterns
   - Phase checklist
   - Files to modify
   - Debugging tips
   - Progress tracking
   - Success metrics

4. **Updated `.github/copilot-instructions.md`**
   - Added Feature 014 as active feature
   - Added text editing architecture section
   - Critical TextKit 2 patterns documented
   - Deferred Feature 008b status updated

## 🎯 Why This Migration?

### The Vision: Comments Feature

You want to implement Word-style comments inspired by WWDC 2021 TextKit 2 session. That feature requires:
- Modern text layout APIs (TextKit 2)
- Custom text attachments with ViewProvider
- NSTextLocation for precise positioning
- Advanced text range manipulation

### The Foundation: Future-Proofing

TextKit 1 is legacy technology. TextKit 2 provides:
- ✅ Better performance and memory efficiency
- ✅ Improved correctness (especially with emoji, RTL, complex layouts)
- ✅ Modern APIs for advanced features
- ✅ Active development and support from Apple
- ✅ Foundation for collaboration features

## 📊 Migration Scope

### What Changes

**One Primary File**:
- `FormattedTextEditor.swift` (~35 layoutManager/textStorage references)

**One New File**:
- `TextLayoutManagerExtensions.swift` (helper utilities)

### What Stays the Same

- ✅ Data models (NSAttributedString storage)
- ✅ RTF serialization format
- ✅ FileEditView.swift (uses FormattedTextEditor wrapper)
- ✅ All other features (formatting, images, versions, etc.)
- ✅ User-facing behavior (looks identical)

### API Conversions

```swift
// Layout
layoutManager.ensureLayout() → textLayoutManager.ensureLayout()

// Positioning
layoutManager.glyphRange() → textLayoutManager.layoutFragment()

// Hit Testing
layoutManager.characterIndex() → textLayoutManager.location(interactingAt:)

// Bounds
layoutManager.boundingRect() → layoutFragment.layoutFragmentFrame
```

## 📅 Implementation Timeline

### 6 Phases (2 work days estimated)

| Phase | Focus | Duration | Key Deliverable |
|-------|-------|----------|-----------------|
| 1 | Setup | 1-2h | TextKit 2 enabled, helpers created |
| 2 | Layout | 2-3h | All layout calls converted |
| 3 | Images | 2-3h | Image positioning fixed |
| 4 | Selection | 1-2h | Cursor navigation verified |
| 5 | Storage | 1-2h | Text modifications verified |
| 6 | Testing | 2-3h | Comprehensive testing complete |

**Total**: ~15 hours

### Incremental Approach

Each phase:
1. Makes specific changes
2. Tests immediately
3. Commits checkpoint
4. Moves to next phase

Benefits:
- Early issue detection
- Stable checkpoints
- Easy rollback if needed
- Clear progress tracking

## 🎓 What You'll Learn

### TextKit 2 Concepts

1. **NSTextLayoutManager** - Modern layout engine
2. **NSTextLocation** - Opaque position markers (not integers)
3. **NSTextRange** - Modern range representation
4. **NSTextLayoutFragment** - Layout unit (replaces glyph ranges)
5. **NSTextContentStorage** - Modern storage wrapper

### Migration Patterns

- Converting integer-based positions to opaque locations
- Using fragment enumeration instead of direct queries
- Working with modern text layout APIs
- Maintaining backward compatibility in public APIs

## 🚀 What Comes Next

### After Migration

1. **Immediate**: Comments feature becomes feasible
   - Can use NSTextAttachment with ViewProvider
   - Can use NSTextLocation for precise comment anchoring
   - Can use TextKit 2's advanced rendering

2. **Future**: More advanced features
   - Annotations and highlights
   - Collaboration (track changes)
   - Advanced accessibility
   - Custom text rendering

### Comments Feature (Next)

Once TextKit 2 is working, you can implement:
- Comment markers in text (visual indicators)
- Comment data model (SwiftData)
- Comment popover UI (add/edit/delete)
- Comment persistence (CloudKit sync)
- Comment navigation (jump between comments)

## ✅ Ready to Start

### Checklist Before Beginning

- [x] Specification complete
- [x] Implementation plan detailed
- [x] Quick reference created
- [x] Copilot instructions updated
- [x] User approves approach
- [x] Time allocated (~2 days)

### Next Command

```bash
git checkout -b 014-textkit2-migration
```

Then start with Phase 1 (Setup & Infrastructure).

## 📚 Resources Available

### Local Documentation
- `specs/014-textkit2-migration/spec.md` - Full specification
- `specs/014-textkit2-migration/plan.md` - Detailed plan
- `specs/014-textkit2-migration/quickstart.md` - Quick reference

### Apple Documentation
- [TextKit 2 Overview](https://developer.apple.com/documentation/UIKit/textkit)
- [NSTextLayoutManager](https://developer.apple.com/documentation/uikit/nstextlayoutmanager)
- [Using TextKit 2 to Interact with Text](https://developer.apple.com/documentation/UIKit/using-textkit-2-to-interact-with-text)

### WWDC Sessions
- **WWDC 2021 Session 10061**: Meet TextKit 2
- **WWDC 2022 Session 10090**: What's new in TextKit and text views

## 🎉 Success Metrics

Migration is successful when:

- ✅ All existing features work identically
- ✅ No performance degradation
- ✅ No crashes or layout glitches
- ✅ All tests pass
- ✅ Code is clean and documented
- ✅ Ready for comments feature development

## 💡 Key Insights

### Why Migration is Feasible

1. **Well-Isolated Code**: 90% of TextKit usage is in one file
2. **Clean Abstraction**: UIViewRepresentable provides clear boundary
3. **Standard Patterns**: Using common patterns with direct equivalents
4. **Same Storage**: Data format doesn't change
5. **No Breaking Changes**: External APIs remain the same

### Why Migration is Important

1. **Foundation**: Required for comments feature
2. **Future-Proofing**: TextKit 1 is legacy, TextKit 2 is the future
3. **Quality**: Better performance and correctness
4. **Capabilities**: Enables advanced text features
5. **Support**: Active development from Apple

## 🎯 The Big Picture

```
Current State (TextKit 1)
    ↓
TextKit 2 Migration (2 days) ← YOU ARE HERE
    ↓
Comments Feature (enabled by TextKit 2)
    ↓
Advanced Text Features (annotations, collaboration)
```

This migration is the foundation for the next generation of Writing Shed Pro's text editing capabilities.

---

**Next Step**: Review specifications, then create feature branch and start Phase 1! 🚀
