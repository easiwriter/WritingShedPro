# What's Next - Writing Shed Pro Roadmap

**Date:** November 28, 2025  
**Current Status:** Phase 015 (Footnotes) Complete + Phase 019 (Settings/Import) Complete ✅  
**Tests Passing:** All integration tests passing ✅  
**Latest Work:** Legacy database import filtering (Nov 28, 2025)

---

## 🎉 Current Achievement

### Phase 015: Footnotes - COMPLETE ✅
- ✅ Insert/edit/delete footnotes at any character position
- ✅ Auto-numbering and renumbering
- ✅ Footnote display at bottom of page with separator
- ✅ Accurate pagination with footnote height calculation
- ✅ Full undo/redo integration
- ✅ CloudKit sync for footnotes
- ✅ Cross-platform support (iOS, iPadOS, macOS Catalyst)
- ✅ Comprehensive integration tests
- ✅ See: `FOOTNOTES_FEATURE_COMPLETE.md`

### Phase 019: Settings Menu & Smart Import - COMPLETE ✅
- ✅ Legacy database detection (Writing Shed app)
- ✅ Smart import flow with project preview
- ✅ Selective project import
- ✅ JSON import fallback
- ✅ "No Projects" storyboard placeholder filtering (Nov 28)
- ✅ Project import status tracking
- ✅ User-friendly import dialogs

### Previous Phases Complete
- ✅ Phase 001: Project Management
- ✅ Phase 002: Folder/File Creation  
- ✅ Phase 003: Text File Creation
- ✅ Phase 004: Undo/Redo System
- ✅ Phase 005: Text Formatting
- ✅ Phase 006-014: Various features (collections, comments, etc.)

---

## 📋 Recent Fixes (November 2025)

### November 28 - Legacy Import Enhancement
- ✅ Identified "No Projects" as legacy app storyboard placeholder
- ✅ Added filtering to exclude from import picker
- ✅ Improved UX: Shows "0 projects available" instead of hiding button
- ✅ Clear messaging: "No Writing Shed projects to import"
- ✅ Also filters empty project names (corrupted entries)

### November 27 - Collections Sheet Bug Fix
- ✅ Fixed empty sheet on first tap of "show versions"
- ✅ Switched from `.sheet(isPresented:)` to `.sheet(item:)`
- ✅ Added atomic state management with `EditVersionItem` struct
- ✅ Verified fix on new and existing collections

---

## 🔄 Immediate Next Steps

### 1. Collections Feature Refinement (Optional)
**Status:** Working, but could be enhanced

**Optional Improvements:**
- [ ] Sort collections by date or name
- [ ] Filter collections by status
- [ ] Bulk operations on collections
- [ ] Archive old collections

**Priority:** LOW - Feature is functional
**Complexity:** LOW - UI only

---

### 2. Comments Feature Completion (Optional)
**Status:** Partially implemented

**Current State:**
- Comments are stored in SwiftData
- Comments can be added/edited/deleted
- Version-aware (comments tied to versions)

**Optional Enhancements:**
- [ ] Comment threading/replies
- [ ] Comment search
- [ ] Comment export
- [ ] Comment filtering

**Priority:** MEDIUM - Useful for collaboration
**Complexity:** MEDIUM

---

## 🚀 Next Major Features to Consider

### Option A: Phase 020 - Export & Publishing (2-3 weeks)

**Features:**
- Export to PDF (with footnotes)
- Export to DOCX
- Export to Markdown
- Print support (with footnotes)
- Share sheet integration
- Template system

**Priority:** HIGH - Core user need
**Complexity:** MEDIUM
**Dependencies:** Footnotes (✅ complete), formatting (✅ complete)

---

### Option B: Phase 021 - Advanced Text Features (3-4 weeks)

**Features:**
- Lists (ordered/unordered)
- Tables (basic grid)
- Images (insertion, sizing, alignment)
- Hyperlinks
- Find & Replace

**Priority:** HIGH - Standard writing features
**Complexity:** MEDIUM-HIGH
**Dependencies:** None blocking

---

### Option C: Phase 022 - Writing Tools (1-2 weeks)

**Features:**
- Word count (characters, words, pages)
- Reading time estimate
- Writing goals (daily targets)
- Writing statistics dashboard
- Progress tracking
- Focus mode (distraction-free)

**Priority:** MEDIUM - Differentiator
**Complexity:** LOW-MEDIUM

---

### Option D: Phase 023 - Collaboration (3-4 weeks)

**Features:**
- Share projects with collaborators
- Real-time editing
- Comments and suggestions
- Version history browser
- Change tracking
- Conflict resolution

**Priority:** MEDIUM-HIGH - Advanced feature
**Complexity:** HIGH - Complex CloudKit work

---

## 📊 App Stability Status

### ✅ Core Features (Stable)
- Project management
- File creation and editing
- Text formatting
- Footnotes (NEW in Phase 015)
- Collections/submissions
- Comments (partial)
- Undo/Redo
- CloudKit sync

### ⚠️ Known Limitations
- Export to PDF not yet implemented
- List formatting not yet implemented
- Table support not yet implemented
- Image support not yet implemented

### 🔧 Recent Fixes
- Collections sheet timing issue (Nov 27)
- Legacy import placeholder filtering (Nov 28)
- Footnote undo/redo integration (Nov 27)

---

## 💡 Development Notes

### Current Architecture Strengths
1. SwiftUI + SwiftData foundation is solid
2. CloudKit sync working reliably
3. Undo/redo system properly integrated
4. Model structure supports extensions
5. Test coverage improving steadily

### Build on Success
- Phase 020 can leverage existing export patterns
- Phase 021 can build on formatting infrastructure
- Phase 023 can enhance existing sync system

---

## Recommendation

### For Next Work

**Suggested Priority Order:**
1. **Phase 020 (Export)** - Highest user value, medium complexity
2. **Phase 021 (Advanced Text)** - Core features users expect
3. **Phase 022 (Writing Tools)** - Unique selling point
4. **Phase 023 (Collaboration)** - Advanced feature for later

**Why:** Export is the immediate user need (get work out). Advanced text features expand usability. Writing tools differentiate the app. Collaboration can follow later.

---

## 🏁 Conclusion

**The app is in excellent shape.** Core functionality is solid, Footnotes are complete and tested, and recent bug fixes (collections sheet, legacy import) have improved stability. Ready to proceed with next major feature (Export recommended).

**Next decision:** Choose which feature to implement next from the options above.

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
