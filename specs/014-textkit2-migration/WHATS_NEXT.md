# What's Next: TextKit 2 Migration → Comments Feature

**Current Status**: TextKit 2 specification complete ✅  
**Next Actions**: Two-phase approach

---

## Phase 1: TextKit 2 Migration (Foundation)

**Status**: 📋 Ready to implement  
**Branch**: `014-textkit2-migration`  
**Duration**: ~15 hours (2 work days)

### Start When Ready

```bash
git checkout -b 014-textkit2-migration
```

Then follow: `specs/014-textkit2-migration/plan.md`

### What Gets Done

- Migrate `FormattedTextEditor.swift` to TextKit 2
- Add `TextLayoutManagerExtensions.swift` helper utilities
- Update all layout/positioning code
- Fix image attachments
- Comprehensive testing
- No user-facing changes (works identically)

---

## Phase 2: Comments Feature (Goal)

**Status**: ⏳ Waiting for TextKit 2 migration  
**Branch**: `015-comments-system` (future)  
**Duration**: TBD (needs separate spec)

### What You Want

From WWDC 2021 TextKit 2 demo:
- Add comments to selected text
- Visual indicators (highlights, margin markers)
- Tap to view/edit comments
- Comment persistence across versions
- CloudKit sync for comments

### UI Integration Plan

Once TextKit 2 is done, add **Comment command** to:

#### 1. Formatting Toolbar (FileEditView)

```swift
// In FormattingAction enum:
enum FormattingAction {
    case paragraphStyle
    case bold
    case italic
    case underline
    case strikethrough
    case imageStyle
    case insert
    case addComment      // NEW: Add comment to selection
}
```

#### 2. Context Menu (on text selection)

```swift
// In FormattedTextEditor or FileEditView:
.contextMenu {
    if selectedRange.length > 0 {
        Button(action: { showAddComment() }) {
            Label("Add Comment", systemImage: "text.bubble")
        }
    }
    // ... existing menu items
}
```

#### 3. Menu Bar Command

```swift
// In main menu (for Mac):
.commands {
    CommandMenu("Insert") {
        Button("Add Comment") {
            // Trigger comment UI
        }
        .keyboardShortcut("k", modifiers: [.command, .option])
    }
}
```

---

## Why Wait for TextKit 2?

### Comments Need TextKit 2 Because:

1. **NSTextLocation** - Precise comment anchoring
   - Comments need to stay attached to text even when edits happen
   - TextKit 2's opaque locations handle this correctly
   - TextKit 1's integer offsets break easily

2. **Custom Attachments with ViewProvider**
   - WWDC demo uses custom attachments for comment markers
   - ViewProvider pattern (TextKit 2 only) for custom rendering
   - Better visual integration

3. **Layout Fragments**
   - Modern layout queries for comment positioning
   - Better performance with large documents
   - Correct handling of complex layouts

### Example: Why TextKit 1 Comments Would Be Harder

```swift
// TextKit 1 approach (fragile):
struct Comment {
    var range: NSRange  // ❌ Breaks when text before it changes
    var text: String
}

// User types "Hello" before comment at position 100
// Comment position is now wrong (should be 105, still says 100)
// Need complex offset tracking logic

// TextKit 2 approach (robust):
struct Comment {
    var location: NSTextLocation  // ✅ Automatically adjusts
    var text: String
}

// Location is opaque - TextKit 2 manages it
// Automatically handles insertions/deletions
```

---

## Recommended Timeline

### Option A: Sequential (Safer)

```
Week 1: TextKit 2 Migration
  ├─ Phase 1-3: Setup, Layout, Images (Day 1)
  ├─ Phase 4-6: Selection, Storage, Testing (Day 2)
  └─ Buffer/Polish (Day 3)

Week 2: Comments Specification
  ├─ Design comment data model
  ├─ Design comment UI
  ├─ Plan persistence strategy
  └─ Create implementation spec

Week 3-4: Comments Implementation
  └─ Build comments feature on TextKit 2 foundation
```

### Option B: Parallel Spec Work

```
Week 1: TextKit 2 Migration + Comments Spec
  ├─ Implement TextKit 2 (Days 1-2)
  └─ While testing, write Comments spec (Day 3)

Week 2-3: Comments Implementation
  └─ Build on completed TextKit 2
```

---

## The Big Picture

```
Current State
    ↓
TextKit 2 Migration (Phase 1) ← DO THIS FIRST
    ↓
Comments Spec (Phase 2a)
    ↓
Comments Implementation (Phase 2b) ← YOUR GOAL
    ↓
Advanced Features (Phase 3+)
  - Annotations
  - Track changes
  - Collaboration
```

---

## Decision Point

### Do you want to:

**A) Start TextKit 2 migration now**
- Creates foundation
- Takes ~2 work days
- No visible changes yet
- Required for comments

**B) Spec out comments feature first**
- Clarifies requirements
- Shows end goal
- Can be done in parallel
- Still requires TextKit 2 to implement

**C) Do something else first**
- Fix collection imports (from TODO list)
- Other feature work
- Come back to TextKit 2 later

---

## If You Choose A (TextKit 2 Migration)

### Immediate Next Steps:

1. **Create branch**:
   ```bash
   git checkout -b 014-textkit2-migration
   ```

2. **Start Phase 1** (Setup):
   - Create `TextLayoutManagerExtensions.swift`
   - Enable TextKit 2 in `FormattedTextEditor.swift`
   - Test basic text display
   - See: `specs/014-textkit2-migration/plan.md` Phase 1

3. **Work incrementally**:
   - One phase at a time
   - Test after each change
   - Commit checkpoints

---

## If You Choose B (Comments Spec First)

I can create a comments feature specification that:
- Defines data model (Comment entity)
- Designs UI/UX (how users add/view/edit comments)
- Plans persistence (SwiftData + CloudKit)
- Shows integration points (toolbar, context menu)
- Estimates implementation time

This gives you the complete picture before starting TextKit 2.

---

## If You Choose C (Other Work)

We can:
- Fix collection import issues (from TODO)
- Work on other features
- Schedule TextKit 2 for later

---

## My Recommendation

**Start with TextKit 2 migration** because:
- ✅ Specification is complete and detailed
- ✅ Well-scoped, low-risk work
- ✅ Clear path forward
- ✅ Foundation for your actual goal (comments)
- ✅ Future-proofs the app
- ✅ ~2 days of focused work

Then immediately follow with comments feature while TextKit 2 knowledge is fresh.

---

## What Do You Want to Do Next?

Let me know:
- **"Start TextKit 2"** → I'll guide you through Phase 1
- **"Spec comments first"** → I'll create the comments feature specification
- **"Fix imports instead"** → I'll help with collection/submission import issues
- **Something else** → Just let me know!

The foundation is ready. What's your priority? 🚀
