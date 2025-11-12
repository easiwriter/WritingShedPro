# Feature 009 - Database Import: Implementation Planning

**Date**: 12 November 2025  
**Status**: Planning - Key Decisions Needed  
**Scope**: Import Writing Shed (legacy) data to Writing Shed Pro

---

## Key Implementation Decisions

### Decision 1: Folder Structure Mapping

**Problem**: Legacy uses `groupName` string for organization, new uses folder hierarchy

**Options**:

**A. Create folders from groupName**
- Auto-detect unique groupName values from texts
- Create corresponding folders in new project
- Map texts to matching folder
- **Pros**: Preserves user's organization
- **Cons**: Some texts might not have groupName; what to do with them?
- **Recommendation**: ✅ **Best option**

**B. Dump all into one folder**
- Put all texts in a default import folder
- User manually reorganizes
- **Pros**: Simple, no ambiguity
- **Cons**: Loses user's organization

**C. Create folder tree from legacy hierarchy**
- (Legacy doesn't have folder hierarchy, so N/A)

**YOUR CHOICE NEEDED**: Option A or B?

---

### Decision 2: What to Import

**Question**: Should we skip scene components (Characters, Locations)?

**Current Plan**: Yes, skip them (they're novel/script focused)

**Options**:

**A. Skip scene components** (current plan)
- Only import texts, versions, collections
- Skip WS_Character_Entity, WS_Location_Entity
- **Pros**: Simpler, focuses on poetry/short story
- **Cons**: User loses this data

**B. Try to import them as text notes**
- Convert character/location data to text notes or metadata
- Store in project/file descriptions
- **Pros**: Preserves data
- **Cons**: Requires mapping to something, might not fit

**C. Create new note fields**
- Add character/location storage to new models
- Preserve data exactly
- **Pros**: Perfect preservation
- **Cons**: Out of scope for current work

**YOUR CHOICE NEEDED**: A, B, or C?

---

### Decision 3: Submission Data Mapping

**Problem**: Legacy tracks collection submissions differently than new

**Legacy Structure**:
```
Collection → submitted to → Publication
            (WS_CollectionSubmission_Entity tracks this)
```

**New Structure**:
```
Submission (publication set) contains SubmittedFiles
```

**Current Plan**:
- Import collection as Submission (publication=nil)
- Import collection's texts as SubmittedFiles in that collection
- If collection was submitted, create NEW Submission with publication set
- Copy SubmittedFiles from collection to new publication submission

**Example**:
```
LEGACY:
  Collection "Spring Contest" (poetry_texts)
    → CollectionSubmission to "Poetry Magazine"
    
IMPORTED AS:
  Submission "Spring Contest" (publication=nil)  
    - SubmittedFile: poem1.v2
    - SubmittedFile: poem2.v3
  
  + Submission to "Poetry Magazine" (publication=Poetry Magazine)
    - SubmittedFile: poem1.v2  
    - SubmittedFile: poem2.v3
```

**Issue**: This creates duplicate submission records. Is that OK?

**YOUR CHOICE NEEDED**:
- Keep this approach (creates duplicates)?
- OR: Only create publication submission if collection was actually submitted?
- OR: Different mapping?

---

### Decision 4: Data Integrity Approach

**How to handle data issues?**

**Options**:

**A. Strict mode** (fail on any issue)
- Invalid UUID? Skip entire project
- Missing content? Skip file
- Corrupted attributed string? Fail import
- **Pros**: Data integrity guaranteed
- **Cons**: User loses everything if one file is corrupted

**B. Lenient mode** (skip problematic items)
- Invalid UUID? Skip just that file
- Missing content? Create empty file with note
- Corrupted attributed string? Try to recover or use plain text
- **Pros**: Maximum data recovery
- **Cons**: Data might not be perfect

**C. Hybrid mode** (warn user, then continue)
- Report all issues found
- Give user choice to continue or abort
- Show detailed import report after
- **Pros**: User informed and has choice
- **Cons**: More complex UX

**YOUR CHOICE NEEDED**: A, B, or C?

---

### Decision 5: AttributedString Compatibility

**Problem**: Old NSAttributedString vs new NSAttributedString compatibility

**Challenge**: 
- Legacy stored AttributedString as transformable blob
- New model also uses AttributedString
- Need to verify they're compatible

**Questions**:
1. Do we just try to decode it directly, or do we need special handling?
2. What if AttributedString format has changed between iOS versions?
3. Should we test with real legacy data first?

**Recommended Approach**:
1. ✅ (Already have the schema) Extract a test WS_TextString from legacy database
2. ✅ Try to deserialize it as NSAttributedString
3. ✅ If successful, create Version with it
4. ✅ Display in Text view to verify formatting preserved

**YOUR CHOICE NEEDED**:
- Should we test this first BEFORE implementation?
- Have you tested whether AttributedString transfers between old and new?

---

### Decision 6: Import Workflow Location

**Where should import happen?**

**Options**:

**A. On first launch**
- Detect legacy database
- Show import prompt
- Run import before normal app startup
- **Pros**: Natural first experience
- **Cons**: Blocks app startup

**B. From Settings**
- Add "Import Data" button to settings
- User triggers manually
- Can be done anytime
- **Pros**: Optional, non-blocking
- **Cons**: User might miss it

**C. Both** (best)
- Offer on first launch
- Also available in Settings for "import more"
- **Pros**: Best user experience
- **Cons**: More code

**YOUR CHOICE NEEDED**: A, B, or C?

---

### Decision 7: File Storage Location

**Where is legacy Core Data database located?**

**✅ CONFIRMED**: Writing Shed stores its database at:

```
~/Library/Application Support/{bundle-identifier}/Writing-Shed.sqlite
```

**Location Computation Code**:
```swift
let storeDirectoryURL = FileManager.default.urls(
    for: .applicationSupportDirectory,
    in: .userDomainMask
)[0]
.appending(component: bundleIdentifier)
.appending(component: "Writing-Shed.sqlite")
```

**Storage Details**:
- Filename: `Writing-Shed.sqlite`
- Parent directory: `~/Library/Application Support/{bundle-identifier}/`
- Bundle identifier: Retrieved from target's bundle configuration
- Direct file access: Core Data persistent store at this path

**Implementation**:
- Use `FileManager.default.urls(for:in:)[0]` to get Application Support directory
- Append bundle identifier as subfolder
- Append "Writing-Shed.sqlite" filename
- File is directly accessible from app sandbox (own app's Application Support is always readable)

---

### Decision 8: Test Data

**Do we have test/sample data?**

**Options**:
1. ✅ Create synthetic test data from schema
2. ✅ Use your own Writing Shed database
3. ❌ Create mock data in unit tests

**For realistic testing**, we should import your actual Writing Shed database

**QUESTION FOR YOU**:
- Can we use your Writing Shed database as test data?
- Where is it located on your machine?

---

## Summary: Required Decisions

| Decision | Options | Recommendation | YOUR CHOICE |
|----------|---------|-----------------|------------|
| 1. Folder mapping | A: Create from groupName, B: Dump in one | **A** | ? |
| 2. Scene components | A: Skip, B: Convert to notes, C: Create fields | **A** | ? |
| 3. Submission mapping | Keep duplicates vs other approach | Needs discussion | ? |
| 4. Data integrity | A: Strict, B: Lenient, C: Hybrid | **C** | ? |
| 5. AttributedString | Test first vs implement blind? | **Test first** | ? |
| 6. Import workflow | A: First launch, B: Settings, C: Both | **C** | ? |
| 7. Database location | ✅ **RESOLVED**: `~/Library/Application Support/{bundle-id}/Writing-Shed.sqlite` | Direct file access | ✅ **KNOWN** |
| 8. Test data | Use your actual database? | **Yes** | ? |

---

## Next Steps (Pending Your Answers)

1. **Decide above 8 questions**
2. **Locate legacy database file** (for Decision 7)
3. **Test AttributedString compatibility** (for Decision 5)
4. **Create LegacyDatabaseService** to read Core Data
5. **Implement mapping functions**
6. **Build import UI with progress**
7. **Write comprehensive tests**

---

## Timeline Estimate

Once decisions are made:
- **Core Data reader**: 1-2 days
- **Mapping functions**: 1-2 days
- **Import engine**: 2-3 days
- **UI/UX**: 1-2 days
- **Testing**: 2-3 days
- **Total**: ~9-12 days

---

## Questions for You

**Please answer**:
1. Which folder mapping approach? A - the group name maps onto the Project Type
2. Skip scene components? Probably C. SceneComponents are related to Scenes. A Scene is a subclass of WS_Text_Entity. Though I don't think SwiftData supports inheritance. Scenes are needed for Novel & Script projects.
3. Data integrity approach? (A or B or C) C
4. Import workflow location? (A or B or C)  C but discuss details
5. **WHERE is the legacy Writing Shed Core Data database located?** ⚠️ CRITICAL I thought we'd covered this
6. Can we use your Writing Shed database for testing? Yes
7. Have you tested AttributedString compatibility already? The textString holds a standard NSAttributedString
8. Any other considerations for import? No, but I'll need to check how you map entities from the legacy system to the new one

Once answered, we can finalize the implementation plan!
