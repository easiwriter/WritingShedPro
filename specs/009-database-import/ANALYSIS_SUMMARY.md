# Feature 009 - Database Import: Ready for Implementation Planning

**Date**: 12 November 2025  
**Status**: Analysis Complete - Awaiting Implementation Decisions

---

## What We've Discovered

### Legacy Core Data Model
✅ **18 entities** analyzed and documented
✅ **Entity relationships** mapped
✅ **Data flows** identified
✅ **Key transformations** identified

### Legacy to New Model Mapping
✅ **Project** → Project (with type mapping)
✅ **Text (file)** → TextFile
✅ **Version** → Version (including locked status)
✅ **TextString (content)** → Version.content (NSAttributedString)
✅ **Collection** → Submission (publication=nil)
✅ **CollectedVersion** → SubmittedFile
✅ **CollectionSubmission** → Publication Submission
✅ **SceneComponent, Character, Location** → Future phases (skip for now)

### Critical Technical Questions
⚠️ **AttributedString Compatibility**: NSAttributedString transfer between old and new needs verification
⚠️ **Database Location**: Where is legacy Writing Shed Core Data stored? (Need user answer)
⚠️ **Data Integrity Strategy**: How strict vs lenient should import be?
⚠️ **Submission Mapping**: Duplicate Submissions or different approach?

---

## Documentation Created

1. **LEGACY_MODEL_ANALYSIS.md** (4,500+ words)
   - Complete entity documentation
   - Relationship diagrams (text)
   - Mapping specifications
   - Import challenges and solutions
   - Data validation checklist

2. **IMPLEMENTATION_DECISIONS.md** (2,000+ words)
   - 8 key implementation decisions
   - Options for each with pros/cons
   - Recommendations
   - Critical questions needing user input

3. **spec.md** (existing)
   - Already has high-level architecture and user flow

---

## Ready-to-Use Artifacts

### Entity Mapping Functions (Ready to implement)
```swift
// Examples from LEGACY_MODEL_ANALYSIS.md
func mapProject(_ legacy: WS_Project_Entity) -> Project
func mapTextFile(_ legacy: WS_Text_Entity) -> TextFile  
func mapVersion(_ legacy: WS_Version_Entity) -> Version
func mapCollection(_ legacy: WS_Collection_Entity) -> Submission
```

### Import Order (Documented)
1. Discover legacy database
2. Fetch projects
3. For each project: texts → versions → collections
4. Map all objects
5. Save to SwiftData

### Error Handling Patterns (Identified)
- Invalid UUID handling
- Missing content recovery
- Corrupted data strategy
- Relationship integrity validation

---

## Next Steps Before Implementation

### 📋 You Must Answer (8 Key Questions)

1. **Folder mapping**: Auto-create from groupName (A) or single import folder (B)?
2. **Scene components**: Skip (A) or convert to notes (B)?
3. **Submission duplication**: OK to have duplicate Submissions? Other approach?
4. **Data integrity**: Strict (fail on error), Lenient (skip bad items), or Hybrid (warn)?
5. **AttributedString**: Should we test compatibility first before full implementation?
6. **Import location**: First launch (A), Settings menu (B), or Both (C)?
7. **Database location**: **WHERE** is Writing Shed Core Data stored on your machine?
8. **Test data**: Can we use your actual Writing Shed database for testing?

### 🔧 Technical Verification Needed

- [ ] Find legacy Writing Shed Core Data file location
- [ ] Verify AttributedString can be read from legacy format
- [ ] Check sandbox access permissions for legacy database
- [ ] Test UUID conversion compatibility

---

## Implementation Timeline (Estimated)

| Phase | Days | Status |
|-------|------|--------|
| Core Data reader service | 1-2 | Awaiting decisions |
| Mapping functions | 1-2 | Awaiting decisions |
| Import engine | 2-3 | Awaiting decisions |
| UI/UX | 1-2 | Awaiting decisions |
| Testing | 2-3 | Awaiting decisions |
| **Total** | **9-12** | **Decisions needed** |

---

## Risk Assessment

### Low Risk ✅
- Text/Version mapping (straightforward)
- Collection to Submission mapping (well-defined)
- Project type mapping (simple enum conversion)
- UUID conversion (standard)

### Medium Risk ⚠️
- AttributedString format compatibility (needs testing)
- Folder structure inference from groupName (ambiguity)
- Data integrity handling (many edge cases)

### High Risk 🔴
- Database file location (blocking issue)
- Submission data structure (complex mapping)
- Scene component exclusion (data loss concern)

---

## Ready to Start?

**YES** - We have:
✅ Complete legacy model analysis
✅ Entity mapping specifications
✅ Import architecture designed
✅ Error handling strategies identified
✅ Implementation decisions documented

**NEED** - From you:
❌ Answer 8 key implementation questions
❌ Location of legacy Writing Shed database
❌ Decision on what to import/skip
❌ Test data (your actual Writing Shed app data)

---

## Files Ready for Implementation

Once you answer the key questions, we can immediately start:
- Creating `LegacyDatabaseService.swift` (reads Core Data)
- Creating `DataMapper.swift` (maps entities)
- Creating `ImportEngine.swift` (orchestrates import)
- Creating `ImportUI/ImportProgressView.swift` (user interface)
- Creating `ImportTests.swift` (comprehensive tests)

---

## Recommendations

1. **First**: Answer the 8 questions above
2. **Second**: Locate your Writing Shed database file
3. **Third**: Test AttributedString compatibility with real data
4. **Fourth**: Review LEGACY_MODEL_ANALYSIS.md for details
5. **Fifth**: Start implementation with core data reader

---

## Questions for You Now

**Please reply with**:
1. Answer to each of the 8 key questions
2. Path to your Writing Shed Core Data database
3. Any other concerns or considerations
4. Preferred import approach (if you have thoughts)

Once we have these answers, we can lock down the technical approach and start building! 🚀
