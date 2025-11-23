# What's Next - Writing Shed Pro Roadmap

**Date:** November 2, 2025  
**Current Status:** Phase 005 Complete (Text Formatting) ✅  
**Tests Passing:** 253/253 ✅

---

## 🎉 Current Achievement

### Phase 005: Text Formatting - COMPLETE
- ✅ Rich text editing (bold, italic, underline, strikethrough)
- ✅ Database-driven paragraph style system
- ✅ Style sheet management (create, edit, duplicate, delete)
- ✅ Cross-platform (iOS, iPadOS, macOS Catalyst)
- ✅ CloudKit sync for formatted content
- ✅ Basic undo/redo integration
- ✅ Comprehensive test coverage (~1,870 new test lines)
- ✅ All 253 tests passing

### Previous Phases Complete
- ✅ Phase 001: Project Management
- ✅ Phase 002: Folder/File Creation  
- ✅ Phase 003: Text File Creation
- ✅ Phase 004: Undo/Redo System
- ✅ Phase 005: Text Formatting

---

## 🔄 Immediate Next Steps (Phase 005 Refinement)

### 1. Complete Phase 6: Undo/Redo Polish (1-2 days)

**Current Status:** Basic undo/redo works, but typing coalescing needs refinement

**Tasks:**
- [ ] Fix typing coalescing with format preservation
  - Detect format changes during typing
  - Flush typing buffer on format change
  - Test type→format→type→undo scenario
- [ ] Expand UndoRedoTests for formatting coverage
- [ ] Test undo/redo with style changes
- [ ] Performance testing with large documents

**Files to Update:**
- `Services/TextFileUndoManager.swift` - Add format change detection
- `WritingShedProTests/UndoRedoTests.swift` - Add formatting scenarios
- `WritingShedProTests/TypingCoalescingTests.swift` - Already created, verify coverage

**Documentation:**
- Update `specs/005-text-formatting/checklists/requirements.md`
- Mark typing coalescing complete

---

### 2. Performance & Scale Testing (1 day)

**Goal:** Verify app handles production workloads

**Tests Needed:**
- [ ] Large document testing (10,000+ words)
- [ ] Heavily formatted text (multiple styles, colors)
- [ ] Memory usage profiling
- [ ] RTF serialization performance
- [ ] Style reapplication performance

**Create:**
- `WritingShedProTests/PerformanceTests.swift` - Already exists, verify coverage
- Manual test documents with realistic content

---

### 3. User Documentation (1 day)

**Create User-Facing Guides:**
- [ ] User guide for formatting features
  - How to apply character formatting
  - How to use paragraph styles
  - How to manage stylesheets
- [ ] Style management guide
  - Creating custom styles
  - Duplicating and editing styles
  - Best practices for style organization
- [ ] Known limitations guide
  - Cursor positioning behavior
  - Platform-specific quirks

**Location:** `/docs/user-guides/`

---

## 🚀 Next Major Features

### Option A: Phase 006 - Advanced Text Features (2-3 weeks)

**Features:**
- Lists (ordered/unordered)
- Tables (basic grid)
- Images (insertion, sizing, alignment)
- Hyperlinks
- Comments/annotations
- Find & Replace

**Priority:** HIGH - These are core writing features
**Complexity:** MEDIUM - Build on existing text infrastructure

---

### Option B: Phase 007 - Export & Publishing (1-2 weeks)

**Features:**
- Export to PDF
- Export to DOCX
- Export to Markdown
- Print support
- Share sheet integration
- Template system for export formats

**Priority:** HIGH - Users need to get work out
**Complexity:** MEDIUM - Use existing serialization

---

### Option C: Phase 008 - Writing Tools (1-2 weeks)

**Features:**
- Word count (characters, words, pages)
- Reading time estimate
- Writing goals (daily targets)
- Writing statistics dashboard
- Progress tracking
- Focus mode (distraction-free)

**Priority:** MEDIUM - Nice to have, differentiates app
**Complexity:** LOW - Mostly UI and counting

---

### Option D: Phase 009 - Collaboration Features (3-4 weeks)

**Features:**
- Share projects with collaborators
- Real-time editing (operational transforms)
- Comments and suggestions
- Version history
- Change tracking
- Merge conflict resolution

**Priority:** MEDIUM - Advanced feature
**Complexity:** HIGH - Requires complex CloudKit integration

---

### Option E: Phase 010 - Mobile Optimization (1 week)

**Features:**
- iPhone-specific UI improvements
- Gesture-based formatting
- Dictation integration
- Handwriting support (iPad + Pencil)
- Reading mode
- Night mode enhancements

**Priority:** MEDIUM - Polish for mobile
**Complexity:** LOW-MEDIUM - Mostly UI work

---

## 📊 Recommended Priority Order

### Short Term (Next 2 Weeks)
1. **Complete Phase 005 Refinement** (typing coalescing, testing, docs)
2. **Start Phase 006: Advanced Text Features** (lists first, then images)

### Medium Term (Next 2 Months)
3. **Phase 007: Export & Publishing** (PDF, DOCX)
4. **Phase 008: Writing Tools** (word count, goals, statistics)

### Long Term (Next 6 Months)
5. **Phase 010: Mobile Optimization**
6. **Phase 009: Collaboration Features** (if needed)

---

## 🎯 Success Criteria

### Before Moving to Next Phase
- [ ] All Phase 005 tests passing (✅ DONE - 253/253)
- [ ] Typing coalescing with formatting complete
- [ ] Performance tested with large documents
- [ ] User documentation complete
- [ ] No known critical bugs

### Beta Release Readiness
- All Phases 001-007 complete
- Comprehensive test coverage (>90%)
- User documentation complete
- Performance validated
- Cross-platform tested

---

## 💡 Strategic Considerations

### What Makes Sense Next?

**Arguments for Advanced Text Features (Phase 006):**
- Natural progression from text formatting
- Users expect lists and images in writing app
- Builds on existing TextFormatter infrastructure
- High user value

**Arguments for Export (Phase 007):**
- Users need to get work OUT of app
- Without export, content is "trapped"
- Relatively quick to implement
- Critical for user confidence

**Arguments for Writing Tools (Phase 008):**
- Differentiates from generic text editors
- Quick wins for user satisfaction
- Low risk, high visibility
- Can be done in parallel with other work

### Recommended: Hybrid Approach

**Week 1-2:** Complete Phase 005 refinement + Start Phase 006 (Lists)
**Week 3-4:** Phase 007 basics (PDF export, Print)
**Week 5-6:** Phase 006 continued (Images) + Phase 008 (Word count)

This gives users both core features (lists) AND the ability to get work out (export) while adding polish (writing tools).

---

## 🧪 Quality Standards

### Before Each Phase Completion
- All tests passing
- Code coverage >85%
- No compiler warnings
- Documentation updated
- Manual testing on all platforms
- Performance benchmarks met

### Testing Requirements Per Phase
- Unit tests for all new services
- Integration tests for workflows
- UI tests for critical paths
- Performance tests for scalability
- Manual testing checklist

---

## 📝 Next Actions (Today)

1. ✅ **Review test results** - All 253 passing
2. **Update Phase 005 status** - Mark complete in requirements.md
3. **Create Phase 006 spec** - If going with Advanced Text Features
4. **Or Create Phase 007 spec** - If going with Export first
5. **Update README.md** - Reflect Phase 005 completion

---

## 🤔 Decision Point: Which Phase Next?

**Question for Product Owner:** 
Which would provide more value to users right now?

**Option 1:** Lists & Images (richer content creation)  
**Option 2:** Export to PDF/DOCX (get work out of app)  
**Option 3:** Word count & Writing goals (writer-focused tools)

All three are valuable. The choice depends on:
- Current user feedback/needs
- Time to market goals
- Competitive positioning

---

**Status:** Ready to start next phase  
**Blockers:** None  
**Team:** Ready  
**Last Updated:** November 2, 2025
