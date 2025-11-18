# Comments Feature - TextKit 1 Implementation Plan

**Date**: 2025-11-18  
**Status**: Planning  
**Priority**: High

## Decision: Abandon TextKit 2 Migration

### Background

We attempted a migration from TextKit 1 to TextKit 2 to enable a comments feature inspired by WWDC 2021. However, the migration encountered severe issues:

- **Memory leaks**: App consuming 2+ GB and being killed by OS
- **Performance problems**: Severe UI responsiveness issues
- **Complexity**: Multiple cascading bugs requiring extensive debugging
- **Time investment**: Exceeded planned timeline with unstable results

### Decision

**Abandon the TextKit 2 migration** and implement comments using TextKit 1 instead.

### Rationale

1. **Comments don't require TextKit 2**: While TextKit 2 has nice APIs for comments, comments can be implemented perfectly well with TextKit 1
2. **Stability**: Current TextKit 1 implementation is stable and performant
3. **Lower risk**: Incremental feature addition vs. complete architecture rewrite
4. **Time efficiency**: Can deliver comments sooner without migration overhead
5. **User value**: Users want comments, not TextKit 2

---

## TextKit 1 Comments Implementation Strategy

### Approach: Custom NSTextAttachment for Comments

Comments can be implemented as **custom text attachments** with associated metadata. This is a proven pattern that works perfectly with TextKit 1.

### Architecture

```
Comment Attachment (NSTextAttachment subclass)
    ↓
Comment View (UIView) - Shows comment indicator
    ↓
Comment Model (SwiftData) - Stores comment data
    ↓
Comment Manager - Handles CRUD operations
```

### Key Components

1. **CommentAttachment.swift**
   - Custom NSTextAttachment subclass
   - Renders as small icon/indicator in text flow
   - Contains reference to comment ID

2. **CommentModel.swift** (SwiftData)
   - `id: UUID`
   - `textFileID: UUID` - Which file
   - `position: Int` - Character position in document
   - `author: String`
   - `text: String` - Comment content
   - `createdAt: Date`
   - `resolvedAt: Date?` - Nil if still active
   - `threadID: UUID?` - For threaded replies

3. **CommentView.swift**
   - Floating popover showing comment content
   - Edit/delete/resolve controls
   - Reply threading support

4. **CommentManager.swift**
   - Insert comment at position
   - Delete comment
   - Resolve/unresolve comment
   - Query comments for file
   - Sync comment positions on text edits

### Implementation Steps

#### Phase 1: Data Model (2 hours)
- [ ] Create `CommentModel` SwiftData entity
- [ ] Add to modelContainer configuration
- [ ] Create database migration if needed
- [ ] Add sample data for testing

#### Phase 2: Comment Attachment (3 hours)
- [ ] Create `CommentAttachment` NSTextAttachment subclass
- [ ] Design comment indicator icon (small speech bubble)
- [ ] Implement custom drawing/rendering
- [ ] Test insertion into NSAttributedString

#### Phase 3: Comment Insertion (3 hours)
- [ ] Add "Add Comment" button to toolbar
- [ ] Implement comment insertion at cursor position
- [ ] Store comment in database
- [ ] Insert attachment in attributed text
- [ ] Handle undo/redo

#### Phase 4: Comment Display (4 hours)
- [ ] Detect tap on comment attachment
- [ ] Show comment popover
- [ ] Display comment content
- [ ] Show author and timestamp
- [ ] Handle dismiss

#### Phase 5: Comment Editing (3 hours)
- [ ] Edit comment text
- [ ] Delete comment (remove from DB and text)
- [ ] Resolve/unresolve toggle
- [ ] Visual indication of resolved comments

#### Phase 6: Position Management (3 hours)
- [ ] Track comment positions as text changes
- [ ] Update positions on insert/delete
- [ ] Handle comment in undo/redo operations
- [ ] Validate positions on file load

#### Phase 7: Thread Support (Optional - 3 hours)
- [ ] Reply to comments
- [ ] Show reply chain
- [ ] Collapse/expand threads

**Total Estimated Time**: 18-21 hours (2-3 days)

---

## Advantages of TextKit 1 Approach

### ✅ Proven Technology
- TextKit 1 is mature and stable
- Well-documented patterns
- Extensive community knowledge

### ✅ Lower Risk
- No architecture rewrite
- Incremental feature addition
- Easy to test and validate

### ✅ Better Performance
- No memory leaks from migration bugs
- Known performance characteristics
- Optimized over many iOS versions

### ✅ Backward Compatibility
- Works on iOS 16+ (our minimum)
- No new API requirements
- Consistent with existing code

---

## What We Learned from TextKit 2 Migration

### Issues Encountered

1. **Memory Management**: NSTextRange/NSTextLocation objects causing leaks
2. **SwiftUI Integration**: State updates triggering cascading refreshes
3. **Sheet Presentation**: Focus management conflicting with modal sheets
4. **Notification Loops**: Style change notifications causing infinite loops
5. **API Complexity**: Opaque location types harder to debug than integer offsets

### Key Takeaways

- **Don't migrate infrastructure for features**: Add features to existing stable infrastructure
- **New APIs have hidden costs**: Migration bugs can dwarf feature implementation time
- **Performance is paramount**: User experience > API elegance
- **Stability wins**: Working code > "modern" code

---

## Alternative: Consider TextKit 2 Later

If we *really* want TextKit 2 in the future, we can:

1. **Wait for maturity**: Let TextKit 2 mature another 1-2 years
2. **Learn from others**: See how other apps handle migration
3. **Dedicated effort**: Plan 1-2 week focused migration sprint
4. **Separate from features**: Never combine migration with feature work

**But for now**: Comments with TextKit 1 is the pragmatic choice.

---

## Next Steps

1. **Review this plan** - Confirm comments approach
2. **Create feature spec** - Detailed comments specification
3. **Start Phase 1** - Begin with data model
4. **Incremental development** - Test each phase thoroughly
5. **Ship comments** - Deliver value to users

---

## References

### TextKit 1 Resources
- [NSTextAttachment Documentation](https://developer.apple.com/documentation/uikit/nstextattachment)
- [Custom Text Attachments](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextAttachments/TextAttachments.html)
- [TextKit Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextArchitecture/TextArchitecture.html)

### Inspiration
- Microsoft Word comments (floating indicators)
- Google Docs comments (margin annotations)
- Notion comments (inline with threading)

---

## Conclusion

**TextKit 2 migration: Abandoned**  
**Next feature: Comments with TextKit 1**  
**Timeline: 2-3 days vs. unknown for TextKit 2**  
**Risk: Low vs. High**  
**Value: Same - users get comments either way**

The right technical choice is the one that delivers value efficiently and reliably. TextKit 1 comments wins on both counts.
